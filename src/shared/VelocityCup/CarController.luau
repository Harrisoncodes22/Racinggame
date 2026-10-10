-- CarController: arcade driving physics shared by players (on their own device)
-- and AI bots (on the server). The vehicle hovers on a downward ray, so it
-- never snags on bumps, and we steer its velocity directly for a kart feel.

local Config = require(script.Parent:WaitForChild("RaceConfig"))
local TrackMath = require(script.Parent:WaitForChild("TrackMath"))

local C = {}
local UP = Vector3.new(0, 1, 0)
local AIR_GRAVITY = 75     -- studs/s^2 while airborne (floatier than Roblox default)
C.DEFAULT_RIDE = 1.35

local function clamp(v, a, b)
	if v < a then return a elseif v > b then return b end
	return v
end
local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then return Vector3.new(0, 0, -1) end
	return f.Unit
end
local function setEnabled(obj, on)
	if obj and obj.Enabled ~= on then obj.Enabled = on end
end

function C.new(model, vdef, trackDef)
	local body = model:WaitForChild("Body")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local carsFolder = workspace:FindFirstChild("VCCars")
	params.FilterDescendantsInstances = { carsFolder or model }
	params.RespectCanCollide = true
	pcall(function() params.CollisionGroup = "VCRay" end)
	local st = {
		model = model, body = body, def = vdef, trackDef = trackDef,
		ride = (model.GetAttribute and model:GetAttribute("Ride")) or C.DEFAULT_RIDE,
		twoWheel = (model.GetAttribute and model:GetAttribute("TwoWheel")) or false,
		ray = params, fwd = flat(body.CFrame.LookVector), up = UP,
		align = body:FindFirstChild("Align"), lift = body:FindFirstChild("Lift"),
		fire = body:FindFirstChild("BoostFire", true),
		sparks = { body:FindFirstChild("SparkL", true), body:FindFirstChild("SparkR", true) },
		splashFx = body:FindFirstChild("Splash", true),
		boost = 0, drifting = false, driftDir = 0, driftCharge = 0, driftYaw = 0,
		air = false, airT = 0, trick = false, spin = 0, lastSurface = "", surface = "",
		fs = 0, skill = 1, idx = nil, ice = false, off = false,
		stunT = 0, stunKind = nil, stunSpin = 0, stuckT = 0, liftT = 0, onToast = nil,
		freezeT = 0, lastGood = nil, offT = 0,
		route = nil, j = nil, routeChoice = {}, lane = (math.random() - 0.5) * trackDef.W * 0.42,
		laneCur = 0, padPref = math.random() < 0.6,
	}
	st.laneCur = st.lane
	return st
end

local function toast(st, text)
	if st.onToast then st.onToast(text) end
end

function C.boost(st, dur)
	st.boost = math.max(st.boost, dur)
end

-- kind: "stun" (spin out), "knockout" (flipped, longer), "blast" (thrown up), "splash" (water)
function C.stun(st, dur, kind)
	dur = dur * (st.def.stunResist or 1)
	if dur <= 0 then return end
	st.stunT = math.max(st.stunT, dur)
	st.stunKind = kind or "stun"
	st.drifting = false
	st.driftCharge = 0
	st.boost = 0
	if kind == "knockout" or kind == "blast" then
		local v = st.body.AssemblyLinearVelocity
		st.body.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, (kind == "blast") and 45 or 30, v.Z * 0.3)
		st.spin = math.pi * 2
	end
end

function C.push(st, vec)
	st.body.AssemblyLinearVelocity = st.body.AssemblyLinearVelocity + vec
end

-- press drift while airborne for a trick (boost on landing)
function C.hop(st)
	if st.air and st.airT > 0.08 and not st.trick and st.stunT <= 0 then
		st.trick = true
		st.spin = math.pi * 2
	end
end

-- inp = { throttle = 0..1, brake = 0..1, steer = -1..1, drift = bool }
function C.step(st, inp, dt)
	local body = st.body
	if not body or not body.Parent or body.Anchored then return end
	local K = Config.K * (Config.SPEED_SCALE or 1)
	local def, td = st.def, st.trackDef
	local pos = body.Position
	local RIDE = st.ride

	st.liftT = st.liftT - dt
	if st.lift and st.liftT <= 0 then
		st.liftT = 1
		st.lift.Force = Vector3.new(0, body.AssemblyMass * math.max(0, workspace.Gravity - AIR_GRAVITY), 0)
	end

	local stunned = st.stunT > 0
	if stunned then
		st.stunT = st.stunT - dt
		inp = { throttle = 0, brake = 0, steer = 0, drift = false }
	end
	local frozen = st.freezeT > 0
	if frozen then
		-- just put back on the track: hold still for a moment
		st.freezeT = st.freezeT - dt
		inp = { throttle = 0, brake = 0, steer = 0, drift = false }
		st.boost = 0
	end

	local hit = workspace:Raycast(pos, Vector3.new(0, -(RIDE + 6), 0), st.ray)
	local gap = hit and (pos.Y - hit.Position.Y) or math.huge
	local grounded = gap < RIDE + 1.4
	local surface = hit and hit.Instance.Name or ""
	st.surface = grounded and surface or ""

	local v = body.AssemblyLinearVelocity
	local fwd = st.fwd
	local right = fwd:Cross(UP)
	local fs, ls, vy = v:Dot(fwd), v:Dot(right), v.Y
	if frozen then fs, ls = 0, 0 end

	-- surface slowdown, softened by the vehicle's off-road skill
	local factor = 1
	local offSkill = def.offroad or 0
	if grounded then
		if surface == "Shoulder" then
			factor = 1 - (1 - td.offTop) * (1 - offSkill)
		elseif Config.SURFACES[surface] then
			local f = Config.SURFACES[surface]
			local soften = (surface == "Water") and 0.6 or 1
			factor = 1 - (1 - f) * (1 - offSkill * soften)
		end
	end
	st.off = factor < 0.99
	st.ice = grounded and surface == "Ice"
	local top = def.top * K * st.skill * factor
	if st.boost > 0 then top = def.top * K * 1.38 end
	local steer = inp.steer

	if grounded then
		if st.air then
			st.air = false
			if surface == "Water" and st.splashFx then st.splashFx:Emit(40) end
			if st.trick then
				C.boost(st, 0.9 * (def.trick or 1))
				toast(st, "Trick boost!")
			end
			st.trick = false
		end
		local acc = def.accel * K * (st.off and 0.75 or 1)
		if inp.throttle > 0 and fs < top then
			fs = fs + acc * inp.throttle * dt * (1 - 0.55 * clamp(fs / top, 0, 1))
		end
		if st.boost > 0 and fs < top then fs = math.min(top, fs + 75 * K * dt) end
		if inp.brake > 0 then
			if fs > 1 then fs = fs - 58 * K * dt * inp.brake
			else fs = math.max(-18 * K, fs - 24 * K * dt * inp.brake) end
		end
		if fs > top then fs = fs - (fs - top) * (st.off and 3.2 or 1.6) * dt end
		if inp.throttle <= 0 and inp.brake <= 0 and st.boost <= 0 then
			local dec = (stunned and 45 or (st.off and 20 or 7)) * K * dt
			if fs > 0 then fs = math.max(0, fs - dec) else fs = math.min(0, fs + dec) end
		end

		-- drifting: hold drift while turning, release for a mini-turbo
		local want = inp.drift and math.abs(steer) > 0.2 and fs > 17 * K
		if want and not st.drifting then
			st.drifting = true
			st.driftDir = steer > 0 and 1 or -1
			st.driftCharge = 0
		end
		if st.drifting and ((not inp.drift) or fs < 12 * K) then
			if st.driftCharge > 2.3 then
				C.boost(st, 1.3); toast(st, "Super drift boost!")
			elseif st.driftCharge > 1.1 then
				C.boost(st, 0.7); toast(st, "Drift boost")
			end
			st.drifting = false
			st.driftCharge = 0
		end
		if st.drifting then
			local raw = steer
			steer = st.driftDir * 0.55 + raw * 0.6
			local same = (raw > 0 and 1 or -1) == st.driftDir
			st.driftCharge = st.driftCharge + dt * (0.75 + math.abs(raw) * 0.5 + (same and 0.3 or 0))
		end

		local grip = (st.drifting and 2.6 or 8.5) * td.grip * (st.ice and 0.28 or 1) * (surface == "Water" and 0.7 or 1)
		ls = ls * math.exp(-grip * dt)

		local horiz = fwd * fs + right * ls
		local n = hit.Normal
		local vyPlane = 0
		if n.Y > 0.3 then vyPlane = -(n.X * horiz.X + n.Z * horiz.Z) / n.Y end
		if stunned and (st.stunKind == "knockout" or st.stunKind == "blast") and vy > 5 then
			-- still flying from the hit; let gravity bring it down
		else
			vy = vyPlane + ((hit.Position.Y + RIDE) - pos.Y) * 12
		end
		body.AssemblyLinearVelocity = horiz + Vector3.new(0, vy, 0)

		local sf = clamp(fs / (10 * K), -1, 1)
		local turn = def.turn * (st.drifting and 1.28 or 1) * (1 - 0.3 * clamp(math.abs(fs) / (90 * K), 0, 1))
		st.fwd = flat(CFrame.Angles(0, -steer * turn * sf * dt, 0) * fwd)
		st.up = n
		if st.lastSurface ~= "Water" and surface == "Water" and st.splashFx and math.abs(fs) > 20 then st.splashFx:Emit(15) end
		st.lastSurface = surface
	else
		if not st.air then
			st.air = true
			st.airT = 0
			if st.lastSurface == "Ramp" then
				vy = 2.5 * K + math.max(fs, 0) * 0.13
				body.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
			end
			st.lastSurface = ""
		end
		st.airT = st.airT + dt
		if st.drifting then st.drifting = false; st.driftCharge = 0 end
		st.fwd = flat(CFrame.Angles(0, -steer * 0.55 * dt, 0) * fwd)
		st.up = UP
	end
	st.fs = fs
	st.steerVis = steer
	if st.boost > 0 then st.boost = st.boost - dt end

	-- orientation
	st.driftYaw = st.driftYaw + ((st.drifting and -st.driftDir * 0.42 or 0) - st.driftYaw) * (1 - math.exp(-8 * dt))
	if stunned and st.stunKind ~= "splash" then
		st.stunSpin = st.stunSpin + dt * 11
	else
		st.stunSpin = 0
	end
	local look = CFrame.Angles(0, st.driftYaw + st.stunSpin, 0) * st.fwd
	local up = st.up
	if st.air then look = (look + UP * clamp(vy * 0.004, -0.35, 0.3)).Unit end
	local lookP = look - up * look:Dot(up)
	if lookP.Magnitude < 0.01 then lookP = look end
	local cf = CFrame.lookAt(Vector3.new(), lookP.Unit, up)
	local roll = 0
	if st.twoWheel then
		roll = -steer * clamp(math.abs(fs) / (40 * K), 0, 1) * 0.38
	else
		roll = steer * clamp(math.abs(fs) / (60 * K), 0, 1) * 0.05
	end
	if st.spin > 0 then
		st.spin = math.max(0, st.spin - dt * (stunned and 7 or 14))
		roll = roll + st.spin
	end
	if roll ~= 0 then cf = cf * CFrame.Angles(0, 0, roll) end
	if st.align then st.align.CFrame = cf end

	-- effects
	setEnabled(st.fire, st.boost > 0)
	local showSparks = st.drifting and st.driftCharge > 0.25
	local col = st.driftCharge > 2.3 and Color3.fromRGB(255, 138, 28)
		or (st.driftCharge > 1.1 and Color3.fromRGB(79, 179, 255) or Color3.fromRGB(255, 242, 192))
	for _, sp in ipairs(st.sparks) do
		if sp then
			setEnabled(sp, showSparks)
			if showSparks and st.sparkCol ~= col then sp.Color = ColorSequence.new(col) end
		end
	end
	st.sparkCol = col
end

-- boost pads: thin parts named BoostPad
function C.checkPads(st, pads)
	if st.air or st.stunT > 0 then return false end
	local pos = st.body.Position
	for _, pad in ipairs(pads) do
		local lp = pad.CFrame:PointToObjectSpace(pos)
		if math.abs(lp.X) < pad.Size.X / 2 + 1 and math.abs(lp.Z) < pad.Size.Z / 2 + 2 and lp.Y > -1 and lp.Y < 7 then
			if st.boost < 0.95 then
				st.boost = 1.15
				return true
			end
		end
	end
	return false
end

-- keeps st.idx / st.route / st.j up to date; returns the locate result
function C.track(st, tr)
	local res = TrackMath.locateAll(tr, st.body.Position, st.idx, st.route, st.j)
	st.idx = res.idx
	st.route = res.route
	st.j = res.j
	st.lat = res.lat
	st.dir = res.T
	-- remember the last spot where we were properly on the road
	local half = res.route and res.route.W / 2 or tr.W / 2
	if not st.air and st.surface ~= "" and st.surface ~= "Shoulder" and st.stunT <= 0 and st.freezeT <= 0
		and math.abs(res.lat) < half - 2 then
		st.lastGood = { idx = res.idx, route = res.route, j = res.j, lat = res.lat }
	end
	return res
end

-- true when the vehicle has been knocked or launched off the track
function C.offTrack(st, tr, res, dt)
	local half = (res.route and res.route.HALF or tr.HALF) + 4
	local out = res.d2 > half * half
		or st.body.Position.Y < tr.bounds.ymin - 30
		or (st.air and st.airT > 3)
	if out then st.offT = st.offT + dt else st.offT = 0 end
	return st.offT > 0.3
end

-- put the vehicle back where it last was on the road, then pause 2 seconds
function C.recover(st, tr, pause)
	local g = st.lastGood
	if not g then
		local res = TrackMath.locateAll(tr, st.body.Position, st.idx, st.route, st.j)
		g = { idx = res.idx, route = res.route, j = res.j, lat = 0 }
	end
	if g.route then
		C.resetTo(st, tr, g.idx, g.route, g.j, g.lat)
	else
		-- never on a ramp: just before a ramp, or past a jump over water
		local i = TrackMath.safeRespawnIndex(tr, g.idx)
		C.resetTo(st, tr, i, nil, nil, g.lat)
		st.idx = i
	end
	st.offT = 0
	st.stuckT = 0
	st.freezeT = pause or 2
end

-- AI driving. padInfo = list of {i = sampleIndex, lat = sideOffset}
function C.aiInput(st, tr, padInfo, obstacles)
	local N, P, S, T = tr.N, tr.P, tr.S, tr.T
	local wrap = TrackMath.wrap
	local idx = st.idx or 1
	local pos = st.body.Position
	local target, aheadDir

	-- decide whether to take an upcoming route (once per pass)
	if not st.route then
		for _, r in ipairs(tr.routes) do
			local dd = (r.from - idx) % N
			if dd > 4 and dd < 70 then
				if st.routeChoice[r.id] == nil then
					local chance = (r.kind == "shortcut") and 0.45 or 0.35
					if (st.def.offroad or 0) > 0.5 then chance = chance + 0.25 end
					st.routeChoice[r.id] = math.random() < chance
				end
				if st.routeChoice[r.id] then st.planned = r end
			elseif dd > N / 2 and st.routeChoice[r.id] ~= nil and (idx - r.to) % N > 30 and (idx - r.to) % N < N / 2 then
				st.routeChoice[r.id] = nil -- passed it; decide again next lap
				if st.planned == r then st.planned = nil end
			end
		end
	end

	local look = 9 + math.floor(math.max(0, st.fs) * 0.44 / tr.seg)
	local r = st.route or st.planned
	if r and st.route == nil then
		-- heading for the route entrance
		local dd = (r.from - idx) % N
		if dd > N / 2 and (idx - r.from) % N > 25 then
			st.planned = nil -- missed the entrance, stay on the main road
			local i2 = wrap(idx + look, N)
			target = P[i2] + S[i2] * st.laneCur
		elseif dd > N / 2 or dd < 2 then
			target = r.P[math.min(r.M, 1 + look)]
		else
			local i2 = wrap(idx + look, N)
			local f = clamp(1 - dd / 60, 0, 1)
			local mainT = P[i2] + S[i2] * st.laneCur
			local entry = r.P[math.min(r.M, look)]
			target = mainT + (entry - mainT) * f
		end
		aheadDir = r.T[1]
	elseif r then
		local j = st.j or 1
		local jj = math.min(r.M, j + math.max(4, math.floor(look * tr.seg / 4)))
		if jj >= r.M - 1 then
			local i2 = wrap(r.to + 8, N)
			target = P[i2]
			st.planned = nil
		else
			target = r.P[jj]
		end
		aheadDir = r.T[math.min(r.M, jj + 10)]
	else
		local laneT = st.lane
		if st.padPref then
			for _, p in ipairs(padInfo) do
				local dd = (p.i - idx) % N
				if dd < 90 then laneT = p.lat; break end
			end
		end
		-- swerve around trees standing in the road
		local rate = 0.02
		for _, o in ipairs(obstacles or {}) do
			local dd = (o.i - idx) % N
			if dd > 0 and dd < 110 and math.abs(o.lat) < tr.W / 2 and math.abs(st.laneCur - o.lat) < 11 then
				local away = (o.lat > 0.5) and -1 or ((o.lat < -0.5) and 1 or ((st.laneCur >= 0) and 1 or -1))
				laneT = o.lat + away * 13
				rate = 0.12
				break
			end
		end
		st.laneCur = st.laneCur + (laneT - st.laneCur) * rate
		local i2 = wrap(idx + look, N)
		target = P[i2] + S[i2] * st.laneCur
	end

	local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if dir.Magnitude < 0.1 then dir = st.fwd end
	dir = dir.Unit
	local a = math.atan2(st.fwd:Cross(dir).Y, st.fwd:Dot(dir))
	local steer = clamp(-a * 2.4, -1, 1)
	local cv
	if aheadDir then
		cv = 1 - st.fwd:Dot(aheadDir) * 0.5 - dir:Dot(aheadDir) * 0.5
	else
		cv = 1 - T[wrap(idx + 18, N)]:Dot(T[wrap(idx + 60, N)])
	end
	local want = st.def.top * Config.K * (Config.SPEED_SCALE or 1) * st.skill * (1 - math.min(cv * 1.25, 0.5))
	if st.air and not st.trick and st.airT > 0.15 and math.random() < 0.03 then C.hop(st) end
	return {
		throttle = st.fs < want and 1 or 0,
		brake = st.fs > want + 8 * Config.K and 1 or 0,
		steer = steer, drift = false,
	}
end

-- puts the vehicle back on the centre line (main line, or route sample j)
function C.resetTo(st, tr, i, route, j, lat)
	local p, t, s, w
	if route and j then
		p, t, s, w = route.P[j], route.T[j], route.S[j], route.W
	else
		p, t, s, w = tr.P[i], tr.T[i], tr.S[i], tr.W
	end
	p = p + s * math.clamp(lat or 0, -w / 2 + 4, w / 2 - 4)
	local pos = p + UP * (st.ride + 1.5)
	st.body.AssemblyLinearVelocity = Vector3.new()
	st.body.AssemblyAngularVelocity = Vector3.new()
	st.body.CFrame = CFrame.lookAt(pos, pos + t)
	st.fwd = t
	st.drifting = false
	st.driftCharge = 0
	st.boost = 0
	st.air = false
	st.stunT = 0
end

return C
