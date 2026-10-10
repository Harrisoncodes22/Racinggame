-- DataService: saves each player's coins, shop unlocks and equipped skin/trail,
-- and keeps a top-50 fastest-lap leaderboard per track.
--
-- Safety rules (see notes/Systems/Data and Saving.md):
--   * a profile that failed to load is never saved (so a DataStore outage can't wipe anyone)
--   * a session lock stops two servers from overwriting each other's copy of a profile
--   * saves are batched (one write every few seconds at most) to stay inside DataStore limits
--
-- Uses Roblox DataStores. In Studio they only work after the place is published
-- and "Enable Studio Access to API Services" is on (Home > Game Settings > Security).
-- Without that, everything still works for the session but nothing is saved.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
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

-- Session locking: while a server has a player's profile open it stamps a lock on it,
-- so a second server (player rejoins fast, or teleports) waits for the first one to
-- finish saving instead of loading stale data and overwriting newer progress.
local LOCK_TIMEOUT = 150   -- seconds before an un-refreshed lock counts as abandoned (crashed server)
local AUTOSAVE_EVERY = 60  -- also refreshes the lock, so it must stay well under LOCK_TIMEOUT
local SAVE_GAP = 7         -- DataStores allow about one write per key every 6 seconds

local profiles = {}
local meta = {}           -- plr -> { key, loaded, dirty, pending, lastSave }
local memoryBoards = {}   -- trackId -> { [userId] = { ms = n, name = s } }
local boardCache = {}     -- trackId -> { t = clock, rows = {...} }
local boardLoading = {}   -- trackId -> true while a refresh is in flight
local nameCache = {}
local tempVehicles = {}   -- plr -> { id = true } (Studio test unlocks, never saved)

local function default()
	return {
		coins = Config.START_COINS,
		skins = { factory = true }, trails = { none = true }, vehicles = {},
		skin = "factory", trail = "none", best = {},
	}
end

-- turns whatever came out of the DataStore into a valid profile
local function sanitize(saved)
	local d = default()
	if type(saved) ~= "table" then return d end
	for k, v in pairs(saved) do
		if k ~= "lock" then d[k] = v end
	end
	if type(d.coins) ~= "number" or d.coins ~= d.coins then d.coins = Config.START_COINS end
	d.coins = math.max(0, math.floor(d.coins))
	for _, k in ipairs({ "skins", "trails", "vehicles", "best" }) do
		if type(d[k]) ~= "table" then d[k] = {} end
	end
	d.skins.factory = true
	d.trails.none = true
	if type(d.skin) ~= "string" or not d.skins[d.skin] then d.skin = "factory" end
	if type(d.trail) ~= "string" or not d.trails[d.trail] then d.trail = "none" end
	if d.lastSpin ~= nil and type(d.lastSpin) ~= "number" then d.lastSpin = nil end
	return d
end

local function lockedByOther(old)
	if type(old) ~= "table" or type(old.lock) ~= "table" then return false end
	return old.lock.job ~= game.JobId and os.time() - (tonumber(old.lock.t) or 0) < LOCK_TIMEOUT
end

local function call(fn)
	if not DS.online then return false end
	local okc, res = pcall(fn)
	if not okc then
		local msg = tostring(res)
		if string.find(msg, "API") or string.find(msg, "publish") or string.find(msg, "403") then
			DS.online = false
			warn("Velocity Cup: saving is off in this session (" .. msg .. ")")
		else
			warn("Velocity Cup: DataStore error (" .. msg .. ")")
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
	local m = meta[plr]
	plr:SetAttribute("Saving", DS.online and m ~= nil and m.loaded)
	local day = math.floor(os.time() / 86400)
	plr:SetAttribute("SpinReady", (d.lastSpin or -1) < day)
	plr:SetAttribute("NextSpin", (day + 1) * 86400)
end

-- writes the profile now. release = true also drops the session lock (player leaving).
local function writeProfile(plr, release)
	local d, m = profiles[plr], meta[plr]
	if not d or not m or not m.loaded or not profileStore then return false end
	m.dirty = false
	m.lastSave = os.clock()
	local lost = false
	local good = call(function()
		profileStore:UpdateAsync(m.key, function(old)
			if m.released and not release then return nil end -- a late autosave must not re-lock
			if lockedByOther(old) then
				lost = true
				return nil -- another server owns this profile now; don't overwrite its data
			end
			local out = table.clone(d)
			if not release then out.lock = { job = game.JobId, t = os.time() } end
			return out
		end)
	end)
	if lost then
		warn("Velocity Cup: " .. plr.Name .. "'s profile is open on another server; this server stopped saving it")
		m.loaded = false
		publish(plr)
		return false
	end
	if not good then m.dirty = true end
	return good
end

function DS.load(plr)
	local m = { key = "u_" .. plr.UserId, loaded = false, dirty = false, pending = false, lastSave = -math.huge }
	meta[plr] = m
	local d = default()
	if profileStore and DS.online then
		local attempts, maxAttempts = 0, 8
		while attempts < maxAttempts and plr.Parent do
			attempts = attempts + 1
			-- after waiting ~25 s for another server to let go, take the profile over anyway
			-- (its owner most likely crashed; at worst it loses its last minute of progress)
			local force = attempts >= 6
			local result, saved = nil, nil
			local good = call(function()
				profileStore:UpdateAsync(m.key, function(old)
					if not force and lockedByOther(old) then
						result = "locked"
						return nil
					end
					result, saved = "ok", old
					local new = (type(old) == "table") and table.clone(old) or default()
					new.lock = { job = game.JobId, t = os.time() }
					return new
				end)
			end)
			if good and result == "ok" then
				d = sanitize(saved)
				m.loaded = true
				break
			elseif not DS.online then
				break
			end
			task.wait(result == "locked" and 5 or 2)
		end
		if not m.loaded and DS.online then
			-- Never save over data we could not read: this session simply won't be saved.
			warn("Velocity Cup: could not load " .. plr.Name .. "'s profile; progress this session will not be saved")
		end
	else
		m.loaded = true -- nothing to protect (offline / no DataStore)
	end
	profiles[plr] = d
	meta[plr] = m
	publish(plr)
	if not plr.Parent then
		-- left while we were loading: hand the lock straight back
		DS.release(plr)
	end
	return d
end

-- asks for a save soon. Many calls in a row turn into a single write.
function DS.save(plr)
	local m = meta[plr]
	if not m or not m.loaded or not profileStore then return end
	m.dirty = true
	if m.pending then return end
	m.pending = true
	task.spawn(function()
		local wait = SAVE_GAP - (os.clock() - m.lastSave)
		if wait > 0 then task.wait(wait) end
		m.pending = false
		if meta[plr] == m and m.dirty then writeProfile(plr, false) end
	end)
end

function DS.get(plr) return profiles[plr] end

function DS.release(plr)
	local m = meta[plr]
	if m then
		m.released = true
		writeProfile(plr, true)
	end
	profiles[plr] = nil
	meta[plr] = nil
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
	if not temporary then DS.save(plr) end
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
	DS.save(plr)
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

-- looks up display names for many players in one web request
local function fetchNames(userIds)
	local missing = {}
	for _, uid in ipairs(userIds) do
		if not nameCache[uid] then
			local plr = Players:GetPlayerByUserId(uid)
			if plr then nameCache[uid] = plr.DisplayName else missing[#missing + 1] = uid end
		end
	end
	if #missing > 0 then
		local okn, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync(missing) end)
		if okn and type(infos) == "table" then
			for _, info in ipairs(infos) do nameCache[info.Id] = info.DisplayName end
		end
	end
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
					if type(old) ~= "number" or ms < old then return ms end
					return nil
				end)
			end)
		end
	end)
	DS.save(plr)
	return true
end

function DS.getBoard(trackId)
	local c = boardCache[trackId]
	if c and os.clock() - c.t < 30 then return c.rows end
	if boardLoading[trackId] then
		-- someone else is already fetching this board: wait for their result
		local t0 = os.clock()
		while boardLoading[trackId] and os.clock() - t0 < 15 do task.wait(0.2) end
		c = boardCache[trackId]
		return c and c.rows or {}
	end
	boardLoading[trackId] = true
	local okb, rows = pcall(DS.buildBoard, trackId)
	boardLoading[trackId] = nil
	if not okb then
		warn("Velocity Cup: leaderboard error (" .. tostring(rows) .. ")")
		return c and c.rows or {}
	end
	return rows
end

function DS.buildBoard(trackId)
	local merged = {}
	local store = lapStore(trackId)
	if store then
		local good, pages = call(function() return store:GetSortedAsync(true, Config.LEADERBOARD_SIZE) end)
		if good and pages then
			for _, e in ipairs(pages:GetCurrentPage()) do
				local uid = tonumber(e.key)
				if uid and type(e.value) == "number" then merged[uid] = { ms = e.value, name = nil } end
			end
		end
	end
	for uid, e in pairs(memoryBoards[trackId] or {}) do
		if not merged[uid] or e.ms < merged[uid].ms then merged[uid] = { ms = e.ms, name = e.name } end
	end
	local rows = {}
	for uid, e in pairs(merged) do rows[#rows + 1] = { userId = uid, ms = e.ms, name = e.name } end
	table.sort(rows, function(a, b) return a.ms < b.ms end)
	local count = math.min(#rows, Config.LEADERBOARD_SIZE)
	local ids = {}
	for i = 1, count do
		if not rows[i].name then ids[#ids + 1] = rows[i].userId end
	end
	fetchNames(ids)
	local out = {}
	for i = 1, count do
		local e = rows[i]
		out[i] = { rank = i, name = e.name or nameCache[e.userId] or ("Player " .. tostring(e.userId)), time = e.ms / 1000, userId = e.userId }
	end
	boardCache[trackId] = { t = os.clock(), rows = out }
	return out
end

-- save everyone when the server shuts down (in parallel: Roblox only gives us ~30 seconds)
game:BindToClose(function()
	local left = 0
	for plr in pairs(profiles) do
		left = left + 1
		task.spawn(function()
			pcall(DS.release, plr)
			left = left - 1
		end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
end)

-- autosave (this also keeps each session lock fresh)
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for plr, m in pairs(meta) do
			if m.loaded and profiles[plr] then task.spawn(writeProfile, plr, false) end
		end
	end
end)

return DS
