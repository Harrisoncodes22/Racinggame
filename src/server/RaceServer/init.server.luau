-- RaceServer: the server room, waiting rooms and every race in progress.
--
-- How a player gets into a race:
--   * RACE BOTS:    pick a map -> a race starts right away against 7 bots.
--   * RACE PLAYERS: create a waiting room (pick the map) or join one. Everyone in the
--                   room waits in its glass booth. When everyone has pressed Ready,
--                   the host presses Start. After the race the group returns to the booth.
-- Several races can run on one server at the same time; each gets its own copy of
-- the track far away from the others ("track slots").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))
local TrackMath = require(Shared:WaitForChild("TrackMath"))
local Controller = require(Shared:WaitForChild("CarController"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))
local TrackBuilder = require(script:WaitForChild("TrackBuilder"))
local ItemFactory = require(script:WaitForChild("ItemServer"))
local Hazards = require(script:WaitForChild("HazardServer"))
local Data = require(script:WaitForChild("DataService"))
local HubBuilder = require(script:WaitForChild("HubBuilder"))

local UP = Vector3.new(0, 1, 0)
local K, N, LAPS = Config.K, Config.SAMPLES, Config.LAPS
local BOT_NAMES = { "Vega", "Okafor", "Lindqvist", "Morales", "Tanaka", "Rossi", "Kowalski", "Nguyen" }

-- collision groups: drivers never bump their own vehicle, and the hover ray ignores vehicles
local function group(name)
	pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
end
group("VCCars"); group("VCDrivers"); group("VCRay")
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("VCCars", "VCDrivers", false)
	PhysicsService:CollisionGroupSetCollidable("VCDrivers", "VCDrivers", false)
	PhysicsService:CollisionGroupSetCollidable("VCRay", "VCDrivers", false)
	PhysicsService:CollisionGroupSetCollidable("VCRay", "VCCars", false)
end)

-- ---------- shared folders ----------
local HubState = Instance.new("Folder")
HubState.Name = "VCHub"
HubState:SetAttribute("Rooms", "[]")
HubState.Parent = ReplicatedStorage
local SessionsF = Instance.new("Folder")
SessionsF.Name = "VCSessions"
SessionsF.Parent = ReplicatedStorage

local remotes = Instance.new("Folder")
remotes.Name = "VCRemotes"
local function remote(name, class)
	local r = Instance.new(class or "RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local R = {
	ChooseCar = remote("ChooseCar"), StartSolo = remote("StartSolo"),
	CreateRoom = remote("CreateRoom"), JoinRoom = remote("JoinRoom"), LeaveRoom = remote("LeaveRoom"),
	RoomReady = remote("RoomReady"), RoomSetTrack = remote("RoomSetTrack"), RoomSetBots = remote("RoomSetBots"),
	RoomStart = remote("RoomStart"), UseItem = remote("UseItem"), Effect = remote("Effect"),
	Shop = remote("Shop", "RemoteFunction"), GetLeaderboard = remote("GetLeaderboard", "RemoteFunction"),
	DailySpin = remote("DailySpin", "RemoteFunction"),
}
remotes.Parent = ReplicatedStorage

local carsRoot = Instance.new("Folder")
carsRoot.Name = "VCCars"
carsRoot.Parent = workspace

local hub = HubBuilder.build()

-- ---------- helpers ----------
local function validVehicle(id)
	for _, c in ipairs(Config.VEHICLES) do if c.id == id then return true end end
	return false
end
local function validTrack(id)
	for _, t in ipairs(Config.TRACKS) do if t.id == id then return true end end
	return false
end
-- simple per-player rate limit for remotes that cost the server real work
local lastCall = {}
local function throttled(plr, key, gap)
	local t = lastCall[plr]
	if not t then t = {}; lastCall[plr] = t end
	local now = os.clock()
	if t[key] and now - t[key] < gap then return true end
	t[key] = now
	return false
end
local function teleport(plr, cf)
	local char = plr.Character
	if char and char.PrimaryPart then char:PivotTo(cf) end
end

local sessions = {}      -- id -> session
local slotsUsed = {}     -- slot -> session id
local sessionCount = 0
local rooms = {}         -- room number -> room

local function inSession(plr) return plr:GetAttribute("Session") ~= nil end

-- ---------- waiting rooms ----------
local function roomOf(plr)
	for _, room in pairs(rooms) do
		for _, m in ipairs(room.members) do
			if m == plr then return room end
		end
	end
	return nil
end

local function canStart(room)
	if room.status ~= "open" then return false, "Race in progress" end
	if #room.members < 2 and not room.fillBots then return false, "Need 2 players (or turn on bots)" end
	for _, m in ipairs(room.members) do
		if not room.ready[m] then return false, "Waiting for everyone to be ready" end
	end
	return true, "Everyone is ready"
end

local function publishRooms()
	local list = {}
	for k = 1, Config.MAX_ROOMS do
		local room = rooms[k]
		local booth = hub.booths[k]
		if room then
			local members = {}
			for _, m in ipairs(room.members) do
				members[#members + 1] = { userId = m.UserId, name = m.DisplayName, ready = room.ready[m] == true, host = (m == room.host) }
			end
			local ok, why = canStart(room)
			list[#list + 1] = { id = k, host = room.host.DisplayName, hostId = room.host.UserId, track = room.track,
				fillBots = room.fillBots, status = room.status, members = members, canStart = ok, why = why }
			booth.title.Text = "ROOM " .. k .. "  ·  " .. string.upper(Config.getTrack(room.track).name)
			booth.status.Text = (room.status == "racing" and "Racing now" or (#room.members .. "/" .. Config.ROOM_SIZE .. " players  ·  " .. why))
		else
			booth.title.Text = "ROOM " .. k .. "  ·  OPEN"
			booth.status.Text = "Use RACE PLAYERS to start a room"
		end
	end
	HubState:SetAttribute("Rooms", HttpService:JSONEncode(list))
end

local function sendToBooth(plr, k)
	local booth = hub.booths[k]
	if booth then teleport(plr, booth.spot * CFrame.new(math.random(-18, 18), 0, math.random(-8, 8))) end
end

local function leaveRoom(plr, keepPosition)
	local room = roomOf(plr)
	if not room then return end
	for i, m in ipairs(room.members) do
		if m == plr then table.remove(room.members, i); break end
	end
	room.ready[plr] = nil
	plr:SetAttribute("Room", nil)
	if #room.members == 0 then
		rooms[room.id] = nil
	elseif room.host == plr then
		room.host = room.members[1]
	end
	if not keepPosition and not inSession(plr) then teleport(plr, hub.spawnCF) end
	publishRooms()
end

local function joinRoom(plr, k)
	if inSession(plr) then return end
	local room = rooms[k]
	if not room or room.status ~= "open" or #room.members >= Config.ROOM_SIZE then return end
	if roomOf(plr) == room then return end
	leaveRoom(plr, true)
	room.members[#room.members + 1] = plr
	room.ready[plr] = false
	plr:SetAttribute("Room", k)
	sendToBooth(plr, k)
	publishRooms()
end

local function createRoom(plr, trackId)
	if inSession(plr) or not validTrack(trackId) then return end
	local free = nil
	for k = 1, Config.MAX_ROOMS do
		if not rooms[k] then free = k; break end
	end
	if not free then
		R.Effect:FireClient(plr, "toast", "All waiting rooms are busy. Join one instead!")
		return
	end
	leaveRoom(plr, true)
	rooms[free] = { id = free, host = plr, members = {}, ready = {}, track = trackId, fillBots = false, status = "open" }
	joinRoom(plr, free)
end

-- ---------- races ----------
local startSession -- defined below

R.ChooseCar.OnServerEvent:Connect(function(plr, id)
	if type(id) ~= "string" or not validVehicle(id) then return end
	local vdef = Config.getVehicle(id)
	if not Data.canDrive(plr, vdef) then
		R.Effect:FireClient(plr, "toast", vdef.name .. " is a Robux vehicle. Get it in the Shop > ROBUX tab")
		return
	end
	plr:SetAttribute("Car", id)
end)
R.StartSolo.OnServerEvent:Connect(function(plr, trackId)
	if inSession(plr) or type(trackId) ~= "string" or not validTrack(trackId) then return end
	leaveRoom(plr, true)
	startSession({ plr }, trackId, true, nil)
end)
R.CreateRoom.OnServerEvent:Connect(function(plr, trackId)
	if type(trackId) == "string" then createRoom(plr, trackId) end
end)
R.JoinRoom.OnServerEvent:Connect(function(plr, k)
	if type(k) == "number" and k == math.floor(k) and k >= 1 and k <= Config.MAX_ROOMS then joinRoom(plr, k) end
end)
R.LeaveRoom.OnServerEvent:Connect(function(plr) leaveRoom(plr, false) end)
R.RoomReady.OnServerEvent:Connect(function(plr, ready)
	local room = roomOf(plr)
	if room and room.status == "open" then
		room.ready[plr] = ready == true
		publishRooms()
	end
end)
R.RoomSetTrack.OnServerEvent:Connect(function(plr, trackId)
	local room = roomOf(plr)
	if room and room.host == plr and room.status == "open" and type(trackId) == "string" and validTrack(trackId) then
		room.track = trackId
		publishRooms()
	end
end)
R.RoomSetBots.OnServerEvent:Connect(function(plr, on)
	local room = roomOf(plr)
	if room and room.host == plr and room.status == "open" then
		room.fillBots = on == true
		publishRooms()
	end
end)
R.RoomStart.OnServerEvent:Connect(function(plr)
	local room = roomOf(plr)
	if not room or room.host ~= plr then return end
	local ok, why = canStart(room)
	if not ok then
		R.Effect:FireClient(plr, "toast", why)
		return
	end
	room.status = "racing"
	publishRooms()
	local members = {}
	for _, m in ipairs(room.members) do members[#members + 1] = m end
	startSession(members, room.track, room.fillBots, room)
end)
R.Shop.OnServerInvoke = function(plr, action, kind, id)
	if throttled(plr, "shop", 0.25) then return false, "Slow down a little" end
	if type(kind) ~= "string" or type(id) ~= "string" then return false, "Bad request" end
	if kind ~= "skin" and kind ~= "trail" then return false, "Bad request" end
	if action == "buy" then return Data.buy(plr, kind, id) end
	if action == "equip" then return Data.equip(plr, kind, id), "" end
	return false, "Bad request"
end
R.DailySpin.OnServerInvoke = function(plr)
	if throttled(plr, "spin", 1) then return { ok = false, msg = "Slow down a little" } end
	return Data.spin(plr)
end
R.GetLeaderboard.OnServerInvoke = function(plr, trackId)
	if throttled(plr, "board", 0.5) then return {} end
	if type(trackId) ~= "string" or not validTrack(trackId) then return {} end
	return Data.getBoard(trackId)
end
R.UseItem.OnServerEvent:Connect(function(plr)
	local s = sessions[plr:GetAttribute("Session") or ""]
	if not s or not s.items or s.folder:GetAttribute("Phase") ~= "Race" then return end
	for _, r in ipairs(s.racers) do
		if r.player == plr and not r.gone then s.items.use(r) end
	end
end)

local function slotOffset(k)
	local col = (k - 1) % 3
	local row = math.floor((k - 1) / 3)
	return Vector3.new((col - 1) * 10000, 0, (row - 1) * 10000)
end

local function standingsOf(s)
	local list = {}
	for _, r in ipairs(s.racers) do
		if not r.gone then list[#list + 1] = r end
	end
	table.sort(list, function(a, b)
		if a.finished and b.finished then return a.finishTime < b.finishTime end
		if a.finished ~= b.finished then return a.finished end
		return a.total > b.total
	end)
	return list
end

local function effect(r, kind, a, b)
	if r.player and r.player.Parent then R.Effect:FireClient(r.player, kind, a, b) end
end

local function seatPlayer(r)
	local char = r.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not hrp then return false end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CollisionGroup = "VCDrivers"
		end
	end
	local stand = r.body:FindFirstChild("StandPoint")
	if stand then
		hum.PlatformStand = true
		hrp.CFrame = r.body.CFrame * stand.CFrame
		local w = Instance.new("Weld")
		w.Name = "RiderWeld"
		w.Part0 = r.body
		w.Part1 = hrp
		w.C0 = stand.CFrame
		w.C1 = CFrame.new()
		w.Parent = r.body
	elseif r.seat then
		char:PivotTo(r.seat.CFrame + UP * 3)
		r.seat:Sit(hum)
	end
	return true
end

local function removeRacer(r)
	if r.gone then return end
	r.gone = true
	if r.model then r.model:Destroy() end
end

local function runRace(s)
	local def = Config.getTrack(s.trackId)
	local id = s.id
	local folder = s.folder
	local tr = TrackMath.build(def, K, N, s.offset)
	local built = TrackBuilder.build(def, tr, "VCTrack_" .. id)
	s.built = built
	folder:SetAttribute("TrackFolder", built.folder.Name)
	local cars = Instance.new("Folder")
	cars.Name = id
	cars.Parent = carsRoot
	s.cars = cars

	local humans = {}
	for _, plr in ipairs(s.players) do
		local hum = plr.Parent and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			humans[#humans + 1] = plr
		elseif plr.Parent then
			-- no living character to put in a car: send them back instead of leaving them stuck
			plr:SetAttribute("Session", nil)
		end
	end
	local total = s.fillBots and Config.MAX_RACERS or #humans
	total = math.max(total, #humans)
	local nBots = total - #humans
	local gap = math.max(3, math.floor(27 / tr.seg + 0.5))
	local slots = {}
	for k = 0, total - 1 do
		local row = math.floor(k / 2)
		local side = (k % 2 == 0) and -1 or 1
		slots[#slots + 1] = { idx = TrackMath.wrap(N - 4 - row * gap - (k % 2) * math.floor(gap / 2), N), lat = side * tr.W * 0.22 }
	end
	local botSkills = { 0.9, 0.93, 0.95, 0.97, 0.985, 0.96, 0.94, 0.92 }
	local botPool = {}
	-- bots only drive the free vehicles (never the Robux ones)
	for i, v in ipairs(Config.freeVehicles()) do botPool[i] = v end
	for i = #botPool, 2, -1 do
		local j = math.random(1, i)
		botPool[i], botPool[j] = botPool[j], botPool[i]
	end
	s.racers = {}
	for k = 1, total do
		local slot = slots[k]
		local plr = (k > nBots) and humans[k - nBots] or nil
		local vdef, skin, trail
		if plr then
			vdef = Config.getVehicle(plr:GetAttribute("Car"))
			if not Data.canDrive(plr, vdef) then vdef = Config.VEHICLES[2] end
			skin = plr:GetAttribute("Skin") or "factory"
			trail = plr:GetAttribute("Trail") or "none"
		else
			vdef = botPool[((k - 1) % #botPool) + 1]
			skin = (math.random() < 0.3) and Config.SKINS[math.random(2, #Config.SKINS)].id or "factory"
			local coinTrails = {}
			for _, t in ipairs(Config.TRAILS) do
				if t.colors and not t.robux then coinTrails[#coinTrails + 1] = t.id end
			end
			trail = (math.random() < 0.4) and coinTrails[math.random(1, #coinTrails)] or "none"
		end
		local name = plr and plr.DisplayName or BOT_NAMES[k]
		local ride = VehicleBuilder.rideOf(vdef)
		local pos = tr.P[slot.idx] + tr.S[slot.idx] * slot.lat + UP * (ride + 0.2)
		local cf = CFrame.lookAt(pos, pos + tr.T[slot.idx])
		local model, body, seat = VehicleBuilder.build(vdef, cf, name, cars, { skin = skin, trail = trail })
		local r = {
			model = model, body = body, seat = seat, player = plr, name = name, vdef = vdef,
			idx = slot.idx, lastIdx = slot.idx, total = slot.idx - N, lapsDone = -1, lapStart = 0,
			lapTimes = {}, finished = false, finishTime = 0, gone = false, hits = 0, lat = slot.lat,
			trail = trail, dropT = 0,
		}
		if plr then
			model:SetAttribute("OwnerUserId", plr.UserId)
			-- anti-cheat: the player's own device runs their car's physics, so the server
			-- only lets lap progress grow as fast as this vehicle could possibly drive
			r.maxSpeed = vdef.top * K * (Config.SPEED_SCALE or 1) * 1.38 * 1.25 -- boosted top speed + margin for corner-cutting
			r.allow = r.maxSpeed * 0.5
			if not seatPlayer(r) then
				removeRacer(r)
				plr:SetAttribute("Session", nil)
				task.spawn(function() plr:LoadCharacter() end)
			end
			if seat then
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					if seat.Occupant == nil and not r.gone then
						task.wait(0.3)
						if not r.gone and seat.Parent and seat.Occupant == nil then seatPlayer(r) end
					end
				end)
			end
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					removeRacer(r)
					if plr.Parent then plr:SetAttribute("Session", nil) end
				end)
			end
		else
			r.st = Controller.new(model, vdef, def)
			r.st.base = botSkills[k] or 0.95
			r.st.skill = r.st.base
		end
		s.racers[#s.racers + 1] = r
	end

	local function applyBoost(r, dur)
		if r.st then Controller.boost(r.st, dur) else effect(r, "boost", dur) end
	end
	local function applyStun(r, dur, kind, by)
		if r.gone or r.finished then return end
		local now = os.clock()
		if r.immuneUntil and now < r.immuneUntil then return end
		local d = dur * (r.vdef.stunResist or 1)
		r.stunUntil = now + d
		r.immuneUntil = now + d + 1
		if r.st then Controller.stun(r.st, dur, kind) else effect(r, "stun", dur, kind) end
		local stars = r.body:FindFirstChild("StunStars", true)
		if stars and kind ~= "splash" then
			stars.Enabled = true
			task.delay(d, function() if stars.Parent then stars.Enabled = false end end)
		end
		if by and by ~= r then
			by.hits = (by.hits or 0) + 1
			effect(by, "toast", "Hit " .. r.name .. "!")
			effect(r, "toast", "Hit by " .. by.name .. "!")
		end
	end
	local items = ItemFactory.new()
	s.items = items
	items.start({
		tr = tr, folderName = "VCProjectiles_" .. id,
		getRacers = function() return s.racers end,
		standings = function() return standingsOf(s) end,
		applyStun = applyStun, applyBoost = applyBoost,
		notify = function(r, text) effect(r, "toast", text) end,
	})
	Hazards.reset(built.cannons)

	task.wait(1.5)
	folder:SetAttribute("Phase", "Countdown")
	local function lights(n, color)
		for k, lamp in ipairs(built.startLights or {}) do
			local on = k <= n
			lamp.Color = on and color or Color3.fromRGB(60, 10, 10)
			lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	for c = 3, 1, -1 do
		folder:SetAttribute("Countdown", c)
		lights(({ 5, 3, 1 })[c] or 0, Color3.fromRGB(255, 40, 30))
		task.wait(1)
	end
	lights(5, Color3.fromRGB(40, 255, 90))
	for _, r in ipairs(s.racers) do
		if not r.gone and r.body.Parent then
			r.body.Anchored = false
			pcall(function() r.body:SetNetworkOwner(r.player) end)
		end
	end
	folder:SetAttribute("Countdown", 0)
	folder:SetAttribute("StartTime", workspace:GetServerTimeNow())
	folder:SetAttribute("Phase", "Race")
	local raceStart = os.clock()
	local firstHumanFinish = nil
	local placeT = 0

	local function splash(r, vec)
		applyStun(r, 0.6, "splash", nil)
		if r.st then Controller.push(r.st, vec) else effect(r, "push", vec) end
		effect(r, "toast", "Soaked!")
	end

	local conn = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local raceTime = now - raceStart
		local lead = nil
		for _, r in ipairs(s.racers) do
			if r.player and not r.gone and (not lead or r.total > lead.total) then lead = r end
		end
		for _, r in ipairs(s.racers) do
			if not r.gone and r.body.Parent then
				local res = TrackMath.locateAll(tr, r.body.Position, r.idx, r.route, r.j)
				if r.st then
					local st = r.st
					st.idx, st.route, st.j = res.idx, res.route, res.j
					if lead then
						local g = (r.total - lead.total) / N
						st.skill = st.base + math.clamp(-g * 1.6, -1, 1) * 0.06
					end
					local inp = Controller.aiInput(st, tr, built.padInfo, built.obstacles)
					if r.finished then inp.throttle = 0.5; inp.brake = 0 end
					Controller.step(st, inp, dt)
					Controller.checkPads(st, built.pads)
					items.botThink(r, dt)
					Controller.track(st, tr)
					if math.abs(st.fs) < 6 * K and st.stunT <= 0 and st.freezeT <= 0 then st.stuckT = st.stuckT + dt else st.stuckT = 0 end
					if st.stuckT > 3 or Controller.offTrack(st, tr, res, dt) then
						Controller.recover(st, tr, 2)
					end
				end
				r.route, r.j, r.lat = res.route, res.j, res.lat
				local idx = res.idx
				local d = idx - r.lastIdx
				if d < -N / 2 then d = d + N elseif d > N / 2 then d = d - N end
				if r.maxSpeed then
					-- speed budget (refills over time, so bursty network updates are fine)
					r.allow = math.min(r.allow + r.maxSpeed * dt, r.maxSpeed * 2.5)
					if d > 0 then
						local ratio = res.route and res.route.mainPerStud or 1
						local cost = d * tr.seg / ratio
						if cost > r.allow then
							local kept = math.floor(r.allow * ratio / tr.seg)
							if not r.flagged and (d - kept) * tr.seg > 120 then
								r.flagged = true
								warn(("Velocity Cup: %s moved faster than their vehicle allows (ignored)"):format(r.name))
							end
							d = kept
							cost = d * tr.seg / ratio
						end
						r.allow = r.allow - cost
					end
				end
				if math.abs(d) < 150 then r.total = r.total + d end
				r.lastIdx = idx
				r.idx = idx
				local done = math.floor(r.total / N)
				if done > r.lapsDone then
					r.lapsDone = done
					if done >= 1 then
						local lt = raceTime - r.lapStart
						r.lapTimes[#r.lapTimes + 1] = lt
						if r.player and Data.recordLap(r.player, s.trackId, lt) then
							effect(r, "toast", "New personal best lap!")
						end
					end
					r.lapStart = raceTime
					if done >= LAPS and not r.finished then
						r.finished = true
						r.finishTime = raceTime
						r.item = nil
						r.model:SetAttribute("Item", nil)
						r.model:SetAttribute("Finished", true)
						r.model:SetAttribute("FinishTime", raceTime)
						if r.player and not firstHumanFinish then firstHumanFinish = raceTime end
					elseif r.player and done >= 1 then
						effect(r, "toast", (done == LAPS - 1) and "Final lap!" or ("Lap " .. (done + 1)))
					end
				end
			end
		end
		-- Meme Poop trail: little poops plop out behind the vehicle
		for _, r in ipairs(s.racers) do
			if r.trail == "poop" and not r.gone and r.body.Parent and not r.body.Anchored then
				r.dropT = r.dropT - dt
				if r.dropT <= 0 then
					r.dropT = 0.28
					local back = r.body.CFrame * CFrame.new(0, -r.body.Size.Y / 2, r.body.Size.Z / 2 + 1.5)
					local m = Instance.new("Model")
					m.Name = "Poop"
					for n, sz in ipairs({ 1.6, 1.15, 0.7 }) do
						local b = Instance.new("Part")
						b.Shape = Enum.PartType.Ball
						b.Size = Vector3.new(sz, sz * 0.8, sz)
						b.Anchored = true
						b.CanCollide = false
						b.CanQuery = false
						b.CanTouch = false
						b.CastShadow = false
						b.Color = Color3.fromRGB(120 - n * 8, 74 - n * 4, 34)
						b.Position = back.Position + Vector3.new(0, (n - 1) * 0.55, 0)
						b.Parent = m
					end
					m.Parent = built.folder
					Debris:AddItem(m, 3)
				end
			end
		end
		items.updateBoxes(built.boxes, dt)
		items.update(dt)
		Hazards.update(built.cannons, tr, s.racers, now, splash)
		placeT = placeT - dt
		if placeT <= 0 then
			placeT = 0.2
			for i, r in ipairs(standingsOf(s)) do
				r.model:SetAttribute("Place", i)
				r.model:SetAttribute("Lap", math.clamp(r.lapsDone + 1, 1, LAPS))
			end
		end
	end)

	while true do
		task.wait(0.25)
		local raceTime = os.clock() - raceStart
		local nh, nd = 0, 0
		for _, r in ipairs(s.racers) do
			if r.player and not r.gone then
				nh = nh + 1
				if r.finished then nd = nd + 1 end
			end
		end
		if nh == 0 then break end
		if nd == nh then task.wait(2.5); break end
		if firstHumanFinish and raceTime - firstHumanFinish > Config.FINISH_GRACE then break end
		if raceTime > Config.MAX_RACE_TIME then break end
	end
	conn:Disconnect()
	items.stop()

	local raceTime = os.clock() - raceStart
	local out = {}
	for i, r in ipairs(standingsOf(s)) do
		local t, projected = r.finishTime, false
		if not r.finished then
			local remain = (LAPS * N - r.total) * tr.seg
			t = raceTime + remain / math.max(30 * K, r.vdef.top * K * 0.75)
			projected = true
		end
		local bestLap = nil
		for _, lt in ipairs(r.lapTimes) do
			if not bestLap or lt < bestLap then bestLap = lt end
		end
		local coins = 0
		if r.player and r.player.Parent then
			-- no place coins for parking on the grid: you have to finish at least one lap
			local placeCoins = (r.finished or r.lapsDone >= 1) and (Config.PLACE_COINS[i] or 30) or 0
			coins = placeCoins + (r.hits or 0) * Config.HIT_COINS
			Data.addCoins(r.player, coins)
			task.spawn(Data.save, r.player)
		end
		out[#out + 1] = { place = i, name = r.name, car = r.vdef.name, time = t, projected = projected,
			bot = r.player == nil, userId = r.player and r.player.UserId or 0, bestLap = bestLap or 0, coins = coins, hits = r.hits or 0 }
	end
	folder:SetAttribute("Results", HttpService:JSONEncode(out))
	folder:SetAttribute("Phase", "Results")
	task.wait(Config.RESULTS_TIME)
end

local function updateLive()
	local n, racers = 0, 0
	for _, s in pairs(sessions) do
		n = n + 1
		racers = racers + #s.players
	end
	if hub.liveText then
		hub.liveText.Text = (n == 0) and "NO RACES RUNNING" or (n .. (n == 1 and " RACE" or " RACES") .. " RUNNING  ·  " .. racers .. " PLAYERS ON TRACK")
	end
end

local function endSession(s)
	if s.ended then return end
	s.ended = true
	if s.items then pcall(s.items.stop) end
	for _, r in ipairs(s.racers or {}) do removeRacer(r) end
	if s.cars then s.cars:Destroy() end
	TrackBuilder.clear("VCTrack_" .. s.id)
	-- send everyone home: back to their waiting room if they came from one
	for _, plr in ipairs(s.players) do
		if plr.Parent and plr:GetAttribute("Session") == s.id then
			plr:SetAttribute("Session", nil)
			task.spawn(function() plr:LoadCharacter() end)
		end
	end
	if s.room and rooms[s.room.id] == s.room then
		s.room.status = "open"
		for m in pairs(s.room.ready) do s.room.ready[m] = false end
		publishRooms()
	end
	slotsUsed[s.slot] = nil
	sessions[s.id] = nil
	updateLive()
	task.delay(2, function() s.folder:Destroy() end)
end

startSession = function(players, trackId, fillBots, room)
	local slot = nil
	for k = 1, Config.TRACK_SLOTS do
		if not slotsUsed[k] then slot = k; break end
	end
	if not slot then
		for _, plr in ipairs(players) do R.Effect:FireClient(plr, "toast", "All tracks are busy. Try again in a minute!") end
		if room then room.status = "open"; publishRooms() end
		return
	end
	sessionCount = sessionCount + 1
	local id = "S" .. sessionCount
	local folder = Instance.new("Folder")
	folder.Name = id
	folder:SetAttribute("Phase", "Loading")
	folder:SetAttribute("TrackId", trackId)
	folder:SetAttribute("Offset", slotOffset(slot))
	folder:SetAttribute("Laps", LAPS)
	folder:SetAttribute("Countdown", 0)
	folder:SetAttribute("StartTime", 0)
	folder:SetAttribute("Results", "[]")
	folder:SetAttribute("Mode", room and "players" or "bots")
	folder.Parent = SessionsF
	local s = { id = id, slot = slot, offset = slotOffset(slot), trackId = trackId, fillBots = fillBots, room = room,
		players = players, folder = folder, racers = {} }
	sessions[id] = s
	slotsUsed[slot] = id
	for _, plr in ipairs(players) do plr:SetAttribute("Session", id) end
	updateLive()
	task.spawn(function()
		local ok, err = pcall(runRace, s)
		if not ok then warn("Velocity Cup race error: " .. tostring(err)) end
		endSession(s)
	end)
end

-- ---------- players ----------
local function onJoin(plr)
	if not plr:GetAttribute("Car") then plr:SetAttribute("Car", Config.VEHICLES[2].id) end
	plr.CharacterAdded:Connect(function()
		local k = plr:GetAttribute("Room")
		if k and not inSession(plr) then
			task.wait(0.3)
			sendToBooth(plr, k)
		end
	end)
	task.spawn(function()
		Data.load(plr)
		-- Robux trails and vehicles the player already owns
		for _, it in ipairs(Config.robuxItems()) do
			if (it.gamePassId or 0) > 0 then
				local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, it.gamePassId) end)
				if ok and owns then Data.grant(plr, it.shopKind, it.id) end
			end
			-- Studio play tests: try the Robux vehicles for free (not saved)
			if it.shopKind == "vehicle" and Config.UNLOCK_ROBUX_VEHICLES_IN_STUDIO and RunService:IsStudio() then
				Data.grant(plr, "vehicle", it.id, true)
			end
		end
	end)
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
	if not purchased then return end
	for _, it in ipairs(Config.robuxItems()) do
		if it.gamePassId == passId then
			if it.shopKind == "vehicle" then
				Data.grant(plr, "vehicle", it.id)
				plr:SetAttribute("Car", it.id)
				task.spawn(Data.save, plr)
				R.Effect:FireClient(plr, "toast", "Thanks! " .. it.name .. " unlocked. It's your ride now")
			else
				Data.grant(plr, "trail", it.id)
				Data.equip(plr, "trail", it.id)
				R.Effect:FireClient(plr, "toast", "Thanks! " .. it.name .. " trail unlocked")
			end
		end
	end
end)
Players.PlayerAdded:Connect(onJoin)
for _, plr in ipairs(Players:GetPlayers()) do onJoin(plr) end

Players.PlayerRemoving:Connect(function(plr)
	leaveRoom(plr, true)
	local s = sessions[plr:GetAttribute("Session") or ""]
	if s then
		for _, r in ipairs(s.racers) do
			if r.player == plr then removeRacer(r) end
		end
	end
	lastCall[plr] = nil
	Data.release(plr)
end)

publishRooms()
