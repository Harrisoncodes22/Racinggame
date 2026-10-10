-- TrackMath: turns a track's control points into an evenly spaced centre line,
-- plus side routes (shortcuts and alternate roads) that branch off and rejoin it.
-- Used by the server (building, lap counting, bots, items) and by players
-- (minimap, resetting a stuck vehicle, autopilot after the finish).

local TrackMath = {}
local UP = Vector3.new(0, 1, 0)

local function wrap(i, n)
	return ((i - 1) % n) + 1
end
TrackMath.wrap = wrap

local function knot(ti, a, b)
	return ti + math.sqrt(math.max((b - a).Magnitude, 1e-4))
end

-- centripetal Catmull-Rom between p1 and p2
local function crPoint(p0, p1, p2, p3, t)
	local t0 = 0
	local t1 = knot(t0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	local tt = t1 + (t2 - t1) * t
	local a1 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	local a2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	local a3 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	local b1 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	local b2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))
end

-- samples a chain of control points (closed loop or open path) into n evenly spaced points
local function sampleChain(ctrl, closed, n)
	local m = #ctrl
	local dense, lens = {}, {}
	local STEPS = 48
	local total = 0
	local segs = closed and m or (m - 1)
	for i = 1, segs do
		local p0, p1, p2, p3
		if closed then
			p0, p1, p2, p3 = ctrl[wrap(i - 1, m)], ctrl[i], ctrl[wrap(i + 1, m)], ctrl[wrap(i + 2, m)]
		else
			p1, p2 = ctrl[i], ctrl[i + 1]
			p0 = ctrl[i - 1] or (p1 * 2 - p2)
			p3 = ctrl[i + 2] or (p2 * 2 - p1)
		end
		for s = 0, STEPS - 1 do
			local pt = crPoint(p0, p1, p2, p3, s / STEPS)
			if #dense > 0 then total = total + (pt - dense[#dense]).Magnitude end
			dense[#dense + 1] = pt
			lens[#lens + 1] = total
		end
	end
	if closed then
		total = total + (dense[1] - dense[#dense]).Magnitude
	else
		local last = ctrl[m]
		total = total + (last - dense[#dense]).Magnitude
		dense[#dense + 1] = last
		lens[#lens + 1] = total
	end
	if not n then n = math.max(8, math.floor(total / 4 + 0.5)) end
	local P = {}
	local j = 1
	local count = closed and n or n
	for i = 1, count do
		local target
		if closed then target = total * (i - 1) / n else target = total * (i - 1) / (n - 1) end
		while j < #dense and lens[j + 1] < target do j = j + 1 end
		local a, b = dense[j], dense[j + 1] or dense[1]
		local la, lb = lens[j], lens[j + 1] or total
		local f = 0
		if lb > la then f = (target - la) / (lb - la) end
		P[i] = a + (b - a) * math.clamp(f, 0, 1)
	end
	return P, total
end

local function tangents(P, closed)
	local n = #P
	local T, S = {}, {}
	for i = 1, n do
		local a, b
		if closed then
			a, b = P[wrap(i - 2, n)], P[wrap(i + 2, n)]
		else
			a, b = P[math.max(1, i - 2)], P[math.min(n, i + 2)]
		end
		local d = b - a
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude < 1e-4 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit
		T[i] = flat
		S[i] = flat:Cross(UP) -- right-hand side of the driving direction
	end
	return T, S
end

local function nearestIndex(P, pos)
	local best, bi = math.huge, 1
	for i = 1, #P do
		local dx, dz = pos.X - P[i].X, pos.Z - P[i].Z
		local q = dx * dx + dz * dz
		if q < best then best = q; bi = i end
	end
	return bi, math.sqrt(best)
end
TrackMath.nearestIndex = nearestIndex

local cache = {}

-- offset (optional Vector3) moves the whole track, so several races can run at once
function TrackMath.build(def, K, N, offset)
	offset = offset or Vector3.new()
	local key = def.id .. "@" .. math.floor(offset.X) .. "," .. math.floor(offset.Z)
	if cache[key] then return cache[key] end
	local sc = def.scale * K
	local function world(p) return Vector3.new(p[1] * sc + offset.X, (p[3] or 0) * K + offset.Y, p[2] * sc + offset.Z) end
	local ctrl = {}
	for i, p in ipairs(def.points) do ctrl[i] = world(p) end
	local P, total = sampleChain(ctrl, true, N)
	local T, S = tangents(P, true)
	local tr = {
		def = def, P = P, T = T, S = S, N = N,
		length = total, seg = total / N,
		W = def.W, SH = def.SH, HALF = def.W / 2 + def.SH,
		routes = {},
	}
	-- side routes
	for ri, r in ipairs(def.routes or {}) do
		local a = nearestIndex(P, world(r.a))
		local b = nearestIndex(P, world(r.b))
		local A, B = P[a], P[b]
		local chord = (B - A).Magnitude
		local handle = math.min(chord * 0.16, 70)
		local pts = { A, A + T[a] * handle }
		local nv = #(r.via or {})
		for k, v in ipairs(r.via or {}) do
			local f = k / (nv + 1)
			local w = world(v)
			pts[#pts + 1] = Vector3.new(w.X, A.Y + (B.Y - A.Y) * f + (v[3] or 0) * K, w.Z)
		end
		pts[#pts + 1] = B - T[b] * handle
		pts[#pts + 1] = B
		local rP, rLen = sampleChain(pts, false, nil)
		-- Where the route overlaps or runs beside the main road, match the main
		-- road's height exactly, then blend to the route's own height further out.
		-- (Without this the route road can poke up through the main road.)
		local hint = a
		for j = 1, #rP do
			local p = rP[j]
			local best, bi = math.huge, hint
			for i = 1, N do
				local dx, dz = p.X - P[i].X, p.Z - P[i].Z
				local q = dx * dx + dz * dz
				if q < best then best = q; bi = i end
			end
			local i2 = wrap(bi + 1, N)
			local seg = P[i2] - P[bi]
			local f = 0
			local segLen2 = seg.X * seg.X + seg.Z * seg.Z
			if segLen2 > 0 then f = math.clamp(((p.X - P[bi].X) * seg.X + (p.Z - P[bi].Z) * seg.Z) / segLen2, -1, 1) end
			local mainY = P[bi].Y + seg.Y * f
			local d = math.sqrt(best)
			local halfMain = def.W / 2 + def.SH
			local w = math.clamp((d - halfMain) / 70, 0, 1)
			w = w * w * (3 - 2 * w)
			rP[j] = Vector3.new(p.X, mainY + (p.Y - mainY) * w, p.Z)
		end
		local rT, rS = tangents(rP, false)
		local W = r.W or math.floor(def.W * 0.7)
		local SHr = r.SH or 6
		tr.routes[ri] = {
			id = ri, name = r.name or ("Route " .. ri), kind = r.kind or "shortcut",
			surface = r.surface or "Road",
			P = rP, T = rT, S = rS, M = #rP, length = rLen,
			from = a, to = b, span = (b - a) % N,
			W = W, SH = SHr, HALF = W / 2 + SHr,
			pads = r.pads or {}, boxes = r.boxes or {}, open = r.open, cave = r.cave,
		}
	end
	local x0, x1, z0, z1, ymin = math.huge, -math.huge, math.huge, -math.huge, math.huge
	local function grow(p)
		x0 = math.min(x0, p.X); x1 = math.max(x1, p.X)
		z0 = math.min(z0, p.Z); z1 = math.max(z1, p.Z)
		ymin = math.min(ymin, p.Y)
	end
	for i = 1, N do grow(P[i]) end
	for _, r in ipairs(tr.routes) do
		for j = 1, r.M do grow(r.P[j]) end
	end
	tr.bounds = { x0 = x0, x1 = x1, z0 = z0, z1 = z1, ymin = ymin }
	tr.offset = offset
	cache[key] = tr
	return tr
end

-- route sample j -> equivalent main-line index (so laps count correctly on shortcuts)
function TrackMath.routeToMain(tr, route, j)
	local f = (j - 1) / math.max(1, route.M - 1)
	return wrap(route.from + math.floor(route.span * f + 0.5), tr.N)
end

-- nearest point on the main line only. Returns index, sideways offset, distance along.
function TrackMath.locate(tr, pos, hint)
	local P, N = tr.P, tr.N
	local best, bi = math.huge, 1
	if hint then
		for k = -45, 45 do
			local i = wrap(hint + k, N)
			local dx, dz = pos.X - P[i].X, pos.Z - P[i].Z
			local q = dx * dx + dz * dz
			if q < best then best = q; bi = i end
		end
	end
	if not hint or best > (tr.HALF * 2.5) ^ 2 then
		best = math.huge
		for i = 1, N do
			local dx, dz = pos.X - P[i].X, pos.Z - P[i].Z
			local q = dx * dx + dz * dz
			if q < best then best = q; bi = i end
		end
	end
	local p, S, T = P[bi], tr.S[bi], tr.T[bi]
	local d = pos - p
	return bi, d.X * S.X + d.Z * S.Z, d.X * T.X + d.Z * T.Z, best
end

-- nearest point on the main line or any route.
-- Returns a table: idx (main-line equivalent), lat, T (direction), route (or nil), j (route sample)
function TrackMath.locateAll(tr, pos, hint, routeHint, jHint)
	local idx, lat, along, d2 = TrackMath.locate(tr, pos, hint)
	local res = { idx = idx, lat = lat, T = tr.T[idx], route = nil, j = nil, d2 = d2 }
	for _, r in ipairs(tr.routes) do
		local best, bj = math.huge, 1
		local lo, hi, step = 1, r.M, 1
		if r == routeHint and jHint then
			lo, hi = math.max(1, jHint - 30), math.min(r.M, jHint + 30)
		end
		for j = lo, hi, step do
			local p = r.P[j]
			local dx, dz = pos.X - p.X, pos.Z - p.Z
			local q = dx * dx + dz * dz
			if q < best then best = q; bj = j end
		end
		if best < res.d2 and best < (r.HALF + 6) ^ 2 then
			local p, S = r.P[bj], r.S[bj]
			local d = pos - p
			res = { idx = TrackMath.routeToMain(tr, r, bj), lat = d.X * S.X + d.Z * S.Z, T = r.T[bj], route = r, j = bj, d2 = best }
		end
	end
	return res
end

-- the straightest spot near a fraction of the lap (for pads, ramps and item boxes)
function TrackMath.straightIndex(tr, frac, ahead)
	local N, T = tr.N, tr.T
	local base = math.floor(frac * N + 0.5)
	local best, bv = wrap(base, N), math.huge
	for k = -90, 90, 3 do
		local i = wrap(base + k, N)
		if i > 30 and i < N - 30 then
			local dv = (1 - T[i]:Dot(T[wrap(i + ahead, N)])) + (1 - T[wrap(i - 25, N)]:Dot(T[i]))
			if dv < bv then bv = dv; best = i end
		end
	end
	return best
end

-- Where the jumps are on the main line: water gaps, the ramps (and the full-width
-- ramp before each gap) and "no respawn" zones covering each ramp and gap.
-- TrackBuilder places the ramps from this, and recovery uses the zones, so the
-- two always agree. Cached on the track.
TrackMath.RAMP_LEN = 28
function TrackMath.jumps(tr)
	if tr.jumpInfo then return tr.jumpInfo end
	local def, N = tr.def, tr.N
	local info = { gaps = {}, ramps = {}, zones = {} }
	for _, g in ipairs(def.gaps or {}) do
		local i0 = TrackMath.straightIndex(tr, g[1], 60)
		info.gaps[#info.gaps + 1] = { i0 = i0, n = math.floor(g[2] / tr.seg + 0.5) }
	end
	local function inGap(i)
		for _, g in ipairs(info.gaps) do
			if (i - g.i0) % N < g.n then return true end
		end
		return false
	end
	-- keep pads, ramps and item boxes away from where routes split off or rejoin
	local function clearOfRoutes(i)
		for _, r in ipairs(tr.routes) do
			for _, e in ipairs({ r.from, r.to }) do
				local ahead, behind = (i - e) % N, (e - i) % N
				if ahead < 45 or behind < 30 then return false end
			end
		end
		return true
	end
	local function safeIndex(i)
		for _ = 1, 12 do
			if clearOfRoutes(i) and not inGap(i) then return i end
			i = wrap(i + 15, N)
		end
		return i
	end
	info.safeIndex = safeIndex
	info.inGap = inGap
	local rampN = math.ceil(TrackMath.RAMP_LEN / tr.seg)
	for _, rp in ipairs(def.ramps or {}) do
		local i = safeIndex(TrackMath.straightIndex(tr, rp[1], 70))
		info.ramps[#info.ramps + 1] = { i = i, lat = rp[2], full = false }
		-- plain ramp with road underneath: respawn just before it
		info.zones[#info.zones + 1] = { a = i, n = rampN, respawn = "before" }
	end
	for _, g in ipairs(info.gaps) do
		local i = wrap(g.i0 - math.ceil(24 / tr.seg), N)
		info.ramps[#info.ramps + 1] = { i = i, lat = 0, full = true }
		-- ramp + open water: respawn on the far side, since a standing start
		-- before the ramp could never clear the gap
		info.zones[#info.zones + 1] = { a = i, n = (g.i0 - i) % N + g.n, respawn = "after" }
	end
	tr.jumpInfo = info
	return info
end

-- moves a main-line respawn index out of any ramp/gap zone
-- (before a plain ramp, after a jump over water)
function TrackMath.safeRespawnIndex(tr, i)
	local N = tr.N
	local info = TrackMath.jumps(tr)
	local before = math.ceil(16 / tr.seg) -- leave room for the car's nose
	local after = math.ceil(16 / tr.seg)
	for _ = 1, 4 do
		local moved = false
		for _, z in ipairs(info.zones) do
			local d = (i - (z.a - before)) % N
			if d > 0 and d < before + z.n + after then
				if z.respawn == "after" then
					i = wrap(z.a + z.n + after, N)
				else
					i = wrap(z.a - before, N)
				end
				moved = true
			end
		end
		if not moved then break end
	end
	return i
end

-- smooth point along the main line at a fractional index
function TrackMath.pointAt(tr, f)
	local N = tr.N
	local i = math.floor(f)
	local t = f - i
	local a, b = tr.P[wrap(i, N)], tr.P[wrap(i + 1, N)]
	return a + (b - a) * t, tr.T[wrap(i, N)], tr.S[wrap(i, N)]
end

return TrackMath
