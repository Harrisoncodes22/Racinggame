-- DataService: saves each player's coins, shop unlocks and equipped skin/trail,
-- and keeps a top-50 fastest-lap leaderboard per track.
--
-- Uses Roblox DataStores. In Studio they only work after the place is published
-- and "Enable Studio Access to API Services" is on (Home > Game Settings > Security).
-- Without that, everything still works for the session but nothing is saved.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))

local DS = {}
DS.online = true

local profileStore = nil
local ok = pcall(function()
	profileStore = DataStoreService:GetDataStore("VelocityCup_Profiles_v1")
end)
if not ok then DS.online = false end

local profiles = {}
local memoryBoards = {}   -- trackId -> { [userId] = { ms = n, name = s } }
local boardCache = {}     -- trackId -> { t = clock, rows = {...} }
local nameCache = {}
local tempVehicles = {}   -- plr -> { id = true } (Studio test unlocks, never saved)

local function default()
	return {
		coins = Config.START_COINS,
		skins = { factory = true }, trails = { none = true }, vehicles = {},
		skin = "factory", trail = "none", best = {},
	}
end

local function call(fn)
	if not DS.online then return false end
	local okc, res = pcall(fn)
	if not okc then
		local msg = tostring(res)
		if string.find(msg, "API") or string.find(msg, "publish") or string.find(msg, "403") then
			DS.online = false
			warn("Velocity Cup: saving is off in this session (" .. msg .. ")")
		end
		return false, res
	end
	return true, res
end

local function publish(plr)
	local d = profiles[plr]
	if not d then return end
	plr:SetAttribute("Coins", d.coins)
	plr:SetAttribute("Skin", d.skin)
	plr:SetAttribute("Trail", d.trail)
	local owned = { skins = {}, trails = {} }
	for id in pairs(d.skins) do owned.skins[#owned.skins + 1] = id end
	for id in pairs(d.trails) do owned.trails[#owned.trails + 1] = id end
	owned.vehicles = {}
	for id in pairs(d.vehicles or {}) do owned.vehicles[#owned.vehicles + 1] = id end
	for id in pairs(tempVehicles[plr] or {}) do
		if not (d.vehicles or {})[id] then owned.vehicles[#owned.vehicles + 1] = id end
	end
	plr:SetAttribute("Owned", HttpService:JSONEncode(owned))
	plr:SetAttribute("Saving", DS.online)
	local day = math.floor(os.time() / 86400)
	plr:SetAttribute("SpinReady", (d.lastSpin or -1) < day)
	plr:SetAttribute("NextSpin", (day + 1) * 86400)
end

function DS.load(plr)
	local d = default()
	if profileStore then
		local good, saved = false, nil
		for _ = 1, 3 do
			good, saved = call(function() return profileStore:GetAsync("u_" .. plr.UserId) end)
			if good or not DS.online then break end
			task.wait(1)
		end
		if good and type(saved) == "table" then
			for k, v in pairs(saved) do d[k] = v end
			d.skins = d.skins or { factory = true }
			d.trails = d.trails or { none = true }
			d.vehicles = d.vehicles or {}
			d.best = d.best or {}
		end
	end
	profiles[plr] = d
	publish(plr)
	return d
end

function DS.save(plr)
	local d = profiles[plr]
	if not d or not profileStore then return end
	call(function() profileStore:SetAsync("u_" .. plr.UserId, d) end)
end

function DS.get(plr) return profiles[plr] end

function DS.release(plr)
	DS.save(plr)
	profiles[plr] = nil
	tempVehicles[plr] = nil
end

function DS.addCoins(plr, n)
	local d = profiles[plr]
	if not d then return end
	d.coins = d.coins + n
	publish(plr)
end

-- kind = "skin" or "trail"
function DS.buy(plr, kind, id)
	local d = profiles[plr]
	if not d then return false, "Still loading your profile" end
	local item = (kind == "skin") and Config.getSkin(id) or Config.getTrail(id)
	if not item or item.id ~= id then return false, "Unknown item" end
	if item.robux then return false, item.name .. " is bought with Robux" end
	if item.spin then return false, item.name .. " can only be won on the daily spin" end
	local owned = (kind == "skin") and d.skins or d.trails
	if owned[id] then return false, "You already own " .. item.name end
	if d.coins < item.price then return false, "You need " .. (item.price - d.coins) .. " more coins" end
	d.coins = d.coins - item.price
	owned[id] = true
	if kind == "skin" then d.skin = id else d.trail = id end
	publish(plr)
	task.spawn(DS.save, plr)
	return true, "Bought " .. item.name
end

-- unlocks an item without coins (Robux game passes). kind = "skin", "trail" or "vehicle".
-- temporary = true unlocks it for this session only (Studio tests) and never saves it.
function DS.grant(plr, kind, id, temporary)
	local d = profiles[plr]
	if not d then return end
	if kind == "vehicle" then
		if temporary then
			tempVehicles[plr] = tempVehicles[plr] or {}
			tempVehicles[plr][id] = true
		else
			d.vehicles = d.vehicles or {}
			d.vehicles[id] = true
		end
	else
		local owned = (kind == "skin") and d.skins or d.trails
		owned[id] = true
	end
	publish(plr)
end

-- can this player drive this vehicle? (Robux vehicles need the Game Pass)
function DS.canDrive(plr, vdef)
	if not vdef.robux then return true end
	local d = profiles[plr]
	if d and d.vehicles and d.vehicles[vdef.id] then return true end
	local t = tempVehicles[plr]
	return t ~= nil and t[vdef.id] == true
end

function DS.equip(plr, kind, id)
	local d = profiles[plr]
	if not d then return false end
	local owned = (kind == "skin") and d.skins or d.trails
	if not owned[id] then return false end
	if kind == "skin" then d.skin = id else d.trail = id end
	publish(plr)
	return true
end

-- ---------- daily spin ----------
function DS.spin(plr)
	local d = profiles[plr]
	if not d then return { ok = false, msg = "Still loading your profile" } end
	local day = math.floor(os.time() / 86400)
	if (d.lastSpin or -1) >= day then
		return { ok = false, msg = "Come back tomorrow for your next spin", next = (day + 1) * 86400 }
	end
	local total = 0
	for _, t in ipairs(Config.SPIN_TIERS) do total = total + t.chance end
	local roll = math.random() * total
	local tier = Config.SPIN_TIERS[1]
	for _, t in ipairs(Config.SPIN_TIERS) do
		roll = roll - t.chance
		if roll <= 0 then tier = t; break end
	end
	d.lastSpin = day
	local dupe = d.skins[tier.skin] == true
	local coins = 0
	if dupe then
		coins = tier.dupeCoins
		d.coins = d.coins + coins
	else
		d.skins[tier.skin] = true
	end
	publish(plr)
	task.spawn(DS.save, plr)
	return { ok = true, tier = tier.id, skin = tier.skin, dupe = dupe, coins = coins, next = (day + 1) * 86400 }
end

-- ---------- leaderboard ----------
local function lapStore(trackId)
	local s = nil
	call(function() s = DataStoreService:GetOrderedDataStore("VelocityCup_Laps_v1_" .. trackId) end)
	return s
end

local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then nameCache[userId] = plr.DisplayName; return plr.DisplayName end
	local okn, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	if okn and n then nameCache[userId] = n; return n end
	return "Player " .. tostring(userId)
end

-- returns true if this is the player's new personal best on this track
function DS.recordLap(plr, trackId, seconds)
	local d = profiles[plr]
	if not d or seconds <= 1 then return false end
	local ms = math.floor(seconds * 1000 + 0.5)
	local prev = d.best[trackId]
	if prev and prev <= ms then return false end
	d.best[trackId] = ms
	memoryBoards[trackId] = memoryBoards[trackId] or {}
	memoryBoards[trackId][plr.UserId] = { ms = ms, name = plr.DisplayName }
	nameCache[plr.UserId] = plr.DisplayName
	boardCache[trackId] = nil
	task.spawn(function()
		local store = lapStore(trackId)
		if store then
			call(function()
				store:UpdateAsync(tostring(plr.UserId), function(old)
					if old == nil or ms < old then return ms end
					return nil
				end)
			end)
		end
		DS.save(plr)
	end)
	return true
end

function DS.getBoard(trackId)
	local c = boardCache[trackId]
	if c and os.clock() - c.t < 30 then return c.rows end
	local merged = {}
	local store = lapStore(trackId)
	if store then
		local good, pages = call(function() return store:GetSortedAsync(true, Config.LEADERBOARD_SIZE) end)
		if good and pages then
			for _, e in ipairs(pages:GetCurrentPage()) do
				local uid = tonumber(e.key)
				if uid then merged[uid] = { ms = e.value, name = nil } end
			end
		end
	end
	for uid, e in pairs(memoryBoards[trackId] or {}) do
		if not merged[uid] or e.ms < merged[uid].ms then merged[uid] = { ms = e.ms, name = e.name } end
	end
	local rows = {}
	for uid, e in pairs(merged) do rows[#rows + 1] = { userId = uid, ms = e.ms, name = e.name } end
	table.sort(rows, function(a, b) return a.ms < b.ms end)
	local out = {}
	for i = 1, math.min(#rows, Config.LEADERBOARD_SIZE) do
		local e = rows[i]
		out[i] = { rank = i, name = e.name or nameOf(e.userId), time = e.ms / 1000, userId = e.userId }
	end
	boardCache[trackId] = { t = os.clock(), rows = out }
	return out
end

-- save everyone when the server shuts down
game:BindToClose(function()
	for plr in pairs(profiles) do DS.save(plr) end
	task.wait(1)
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(90)
		for plr in pairs(profiles) do DS.save(plr) end
	end
end)

return DS
