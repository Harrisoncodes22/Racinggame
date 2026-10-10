-- RaceClient: runs on each player's device. Shows the server-room screens and the
-- race HUD, reads the controls, drives your own vehicle and runs the chase camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))
local TrackMath = require(Shared:WaitForChild("TrackMath"))
local Themes = require(Shared:WaitForChild("Themes"))
local C = require(Shared:WaitForChild("CarController"))
local UI = require(script:WaitForChild("UIKit"))
local Hub = require(script:WaitForChild("Hub"))
local Hud = require(script:WaitForChild("Hud"))
local HubState = ReplicatedStorage:WaitForChild("VCHub")
local SessionsF = ReplicatedStorage:WaitForChild("VCSessions")
local remotesF = ReplicatedStorage:WaitForChild("VCRemotes")
local remotes = {}
for _, n in ipairs({ "ChooseCar", "StartSolo", "CreateRoom", "JoinRoom", "LeaveRoom", "RoomReady", "RoomSetTrack",
	"RoomSetBots", "RoomStart", "UseItem", "Effect", "Shop", "GetLeaderboard", "DailySpin" }) do
	remotes[n] = remotesF:WaitForChild(n)
end
local carsRoot = workspace:WaitForChild("VCCars")
local camera = workspace.CurrentCamera

local K, N = Config.K, Config.SAMPLES
local UP = Vector3.new(0, 1, 0)

local controls = nil
task.spawn(function()
	local ok, pm = pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) end)
	if ok and pm then controls = pm:GetControls() end
end)

-- ---------- screens ----------
local gui = UI.make("ScreenGui", { Name = "VelocityCupUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local uiScale = UI.make("UIScale", { Parent = gui })
local function rescale()
	local v = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(v.X / 1200, v.Y / 760), 0.5, 1.15)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
local hub = Hub.create(gui, remotes, HubState)
local hud = Hud.create(gui, nil)

-- ---------- race state ----------
local session = nil          -- my session folder (nil while in the server room)
local sessionConns = {}
local carsFolder = nil
local myModel, st, tr, trackDef = nil, nil, nil, nil
local pads, padInfo = {}, {}
local steerIn, driftHeld, wrongT = 0, false, 0
local lastReset = -math.huge
local RESET_COOLDOWN = 3 -- seconds between manual resets (stops reset-spamming through the track)
local driving = false
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function phaseIs(p) return session ~= nil and session:GetAttribute("Phase") == p end
local function trackFolder()
	return session and workspace:FindFirstChild(session:GetAttribute("TrackFolder") or "")
end

local function gatherTrack()
	pads, padInfo = {}, {}
	local trk = trackFolder()
	local pf = trk and trk:FindFirstChild("Pads")
	if pf then
		for _, p in ipairs(pf:GetChildren()) do
			if p.Name == "BoostPad" then
				pads[#pads + 1] = p
				local i = p:GetAttribute("Index")
				if i then padInfo[#padInfo + 1] = { i = i, lat = p:GetAttribute("Lat") or 0 } end
			end
		end
	end
end

local function resetCar()
	if st and tr then
		lastReset = os.clock()
		C.recover(st, tr, 2)
		hud.toast("Back on track")
	end
end

local function onDrift(_, s)
	if s == Enum.UserInputState.Begin then
		driftHeld = true
		if st then C.hop(st) end
	elseif s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
		driftHeld = false
	end
	return Enum.ContextActionResult.Sink
end
local function onItem(_, s)
	if s == Enum.UserInputState.Begin and phaseIs("Race") and myModel and myModel:GetAttribute("Item") then
		remotes.UseItem:FireServer()
	end
	return Enum.ContextActionResult.Sink
end
local function onReset(_, s)
	if s == Enum.UserInputState.Begin and phaseIs("Race") and st and st.freezeT <= 0 then
		if os.clock() - lastReset < RESET_COOLDOWN then
			hud.toast("Wait a moment before resetting again")
		else
			resetCar()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function startDriving(model)
	myModel = model
	-- you don't need to see your own name over your car
	local ownTag = model:FindFirstChild("Body") and model.Body:FindFirstChild("NameTag")
	if ownTag then ownTag.Enabled = false end
	trackDef =Config.getTrack(session:GetAttribute("TrackId"))
	tr = TrackMath.build(trackDef, K, N, session:GetAttribute("Offset"))
	st = C.new(model, Config.getVehicle(model:GetAttribute("VehicleId")), trackDef)
	st.onToast = hud.toast
	C.track(st, tr)
	gatherTrack()
	hud.setTrack(tr)
	driving = true
	steerIn, driftHeld, wrongT = 0, false, 0
	lastReset = -math.huge
	local pri = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority("VCDrift", onDrift, true, pri, Enum.KeyCode.Space, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1)
	ContextActionService:BindActionAtPriority("VCItem", onItem, true, pri, Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:BindActionAtPriority("VCReset", onReset, true, pri, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("VCDrift", "Drift")
	ContextActionService:SetTitle("VCItem", "Item")
	ContextActionService:SetTitle("VCReset", "Reset")
	ContextActionService:SetPosition("VCDrift", UDim2.new(1, -140, 1, -150))
	ContextActionService:SetPosition("VCItem", UDim2.new(1, -240, 1, -110))
	ContextActionService:SetPosition("VCReset", UDim2.new(1, -110, 1, -250))
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end
	camera.CameraType = Enum.CameraType.Scriptable
	hud.hint(not isTouch)
	hud.setResetHint(isTouch and "TAP RESET" or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and "PRESS Y TO RESET") or "PRESS R TO RESET")
	hud.show(true)
end

local function stopDriving()
	if not driving and not myModel then return end
	driving = false
	myModel, st = nil, nil
	ContextActionService:UnbindAction("VCDrift")
	ContextActionService:UnbindAction("VCItem")
	ContextActionService:UnbindAction("VCReset")
	hud.show(false)
	hud.setWrongWay(false)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		camera.CameraSubject = hum
	end
end

local function checkForMyCar(model)
	if model:GetAttribute("OwnerUserId") == player.UserId then
		task.defer(function()
			model:WaitForChild("Body", 5)
			if model.Parent and not driving and session then startDriving(model) end
		end)
	end
end

-- ---------- phases ----------
local finishedShown = false
local function onPhase()
	if not session then return end
	local phase = session:GetAttribute("Phase")
	hud.hideResults()
	hud.infoLabel.Text = ""
	if phase == "Loading" then
		hud.center("")
		hud.infoLabel.Text = "Building " .. Config.getTrack(session:GetAttribute("TrackId")).name .. "..."
	elseif phase == "Race" then
		if driving then
			hud.center("GO!", 1)
			gatherTrack()
		end
	elseif phase == "Results" then
		hud.center("")
		hud.show(false)
		hud.showResults()
	end
end

local function enterHub()
	for _, c in ipairs(sessionConns) do c:Disconnect() end
	sessionConns = {}
	session, carsFolder = nil, nil
	stopDriving()
	hud.hideResults()
	hud.center("")
	hud.infoLabel.Text = ""
	finishedShown = false
	Themes.apply("hub")
	hub.setVisible(true)
	hub.refresh()
end

local function enterSession(id)
	local f = SessionsF:WaitForChild(id, 10)
	if not f or player:GetAttribute("Session") ~= id then return end
	session = f
	hud.setState(f)
	hub.setVisible(false)
	finishedShown = false
	Themes.apply(Config.getTrack(f:GetAttribute("TrackId")).theme)
	sessionConns[#sessionConns + 1] = f:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	sessionConns[#sessionConns + 1] = f:GetAttributeChangedSignal("Countdown"):Connect(function()
		local c = f:GetAttribute("Countdown") or 0
		if c > 0 and driving then hud.center(tostring(c)) end
	end)
	task.spawn(function()
		local cf = carsRoot:WaitForChild(id, 30)
		if not cf or session ~= f then return end
		carsFolder = cf
		sessionConns[#sessionConns + 1] = cf.ChildAdded:Connect(checkForMyCar)
		sessionConns[#sessionConns + 1] = cf.ChildRemoved:Connect(function(m)
			if m == myModel then stopDriving() end
		end)
		for _, m in ipairs(cf:GetChildren()) do checkForMyCar(m) end
	end)
	onPhase()
end

local function onSessionAttr()
	local id = player:GetAttribute("Session")
	if id then
		if not session or session.Name ~= id then
			for _, c in ipairs(sessionConns) do c:Disconnect() end
			sessionConns = {}
			stopDriving()
			task.spawn(enterSession, id)
		end
	else
		enterHub()
	end
end
player:GetAttributeChangedSignal("Session"):Connect(onSessionAttr)

-- messages from the server: boosts, hits, water jets, notices
remotes.Effect.OnClientEvent:Connect(function(kind, a, b)
	if kind == "toast" then
		if session then hud.toast(tostring(a)) else hub.toast(tostring(a)) end
	elseif st then
		if kind == "boost" then
			C.boost(st, a or 1.5)
			hud.toast("Turbo!")
		elseif kind == "stun" then
			C.stun(st, a or 1.5, b or "stun")
		elseif kind == "push" and typeof(a) == "Vector3" then
			C.push(st, a)
		end
	end
end)

local function readInput(dt)
	local steer, thr, brk = 0, 0, 0
	local kd = function(k) return UserInputService:IsKeyDown(k) end
	if kd(Enum.KeyCode.A) or kd(Enum.KeyCode.Left) then steer = steer - 1 end
	if kd(Enum.KeyCode.D) or kd(Enum.KeyCode.Right) then steer = steer + 1 end
	if kd(Enum.KeyCode.W) or kd(Enum.KeyCode.Up) then thr = 1 end
	if kd(Enum.KeyCode.S) or kd(Enum.KeyCode.Down) then brk = 1 end
	if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then thr = 1 end
	if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2) then brk = 1 end
	if controls then
		local mv = controls:GetMoveVector()
		if math.abs(mv.X) > math.abs(steer) then steer = math.clamp(mv.X, -1, 1) end
		if mv.Z < -0.3 then thr = 1 end
		if mv.Z > 0.5 then brk = 1 end
	end
	if isTouch and brk == 0 then thr = 1 end
	steerIn = steerIn + (steer - steerIn) * (1 - math.exp(-11 * dt))
	return { throttle = thr, brake = brk, steer = steerIn, drift = driftHeld }
end

RunService.Heartbeat:Connect(function(dt)
	if driving and myModel and myModel:GetAttribute("Finished") and not finishedShown then
		finishedShown = true
		local p = myModel:GetAttribute("Place") or 1
		hud.center(p == 1 and "WINNER!" or UI.ord(p), 4)
	end
	if not driving or not st or not st.body.Parent then return end
	if not phaseIs("Race") then return end
	local inp
	if myModel:GetAttribute("Finished") then
		inp = C.aiInput(st, tr, padInfo)
		inp.throttle = inp.throttle * 0.6
	else
		inp = readInput(dt)
	end
	C.step(st, inp, dt)
	if C.checkPads(st, pads) then hud.toast("Boost!") end
	local res = C.track(st, tr)
	if res.route and res.route.kind == "shortcut" and hud.revealRoute(res.route) then
		hud.toast("Secret shortcut found: " .. res.route.name .. "!")
	end
	if #pads == 0 then gatherTrack() end
	-- knocked or launched off the track: back to the last spot on the road, 2 second pause
	if st.freezeT <= 0 and C.offTrack(st, tr, res, dt) then resetCar() end
	local dot = st.fwd:Dot(res.T)
	if dot < -0.35 and math.abs(st.fs) > 4 * K then wrongT = wrongT + dt else wrongT = 0 end
	hud.setWrongWay(wrongT > 1.1)
end)

-- chase camera + HUD + spinning item boxes
RunService:BindToRenderStep("VCCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local trk = trackFolder()
	local bf = trk and trk:FindFirstChild("ItemBoxes")
	if bf then
		for _, box in ipairs(bf:GetChildren()) do
			box.CFrame = box.CFrame * CFrame.Angles(0, dt * 1.4, 0)
			local core = box:FindFirstChild("ItemCore")
			if core then core.CFrame = box.CFrame end
		end
	end
	if carsFolder then hud.update(dt, st, myModel, carsFolder) end
	if not driving or not st or not st.body.Parent then return end
	local body = st.body
	local pos = body.Position
	local fwd = st.fwd
	local fs = st.fs
	if body.Anchored then fwd = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit end
	local look = CFrame.Angles(0, st.driftYaw * 0.5, 0) * fwd
	local size = body.Size
	local scale = math.clamp(math.max(size.Z / 11, 0.75), 0.75, 1.4)
	local dist = (23 + math.clamp(fs / K, 0, 100) * 0.055) * scale
	local want = pos - look * dist + UP * (9 * scale + st.ride * 0.4)
	if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
	local cur = camera.CFrame.Position
	if (cur - want).Magnitude > 200 then cur = want end
	local newPos = cur:Lerp(want, 1 - math.exp(-7 * dt))
	if newPos.Y < pos.Y + 4 then newPos = Vector3.new(newPos.X, pos.Y + 4, newPos.Z) end
	camera.CFrame = CFrame.lookAt(newPos, pos + look * 15 + UP * 3)
	local fov = 70 + math.clamp(fs / K, 0, 110) * 0.13 + (st.boost > 0 and 7 or 0)
	camera.FieldOfView = camera.FieldOfView + (fov - camera.FieldOfView) * (1 - math.exp(-4 * dt))
end)

gui.Parent = player:WaitForChild("PlayerGui")
onSessionAttr()
