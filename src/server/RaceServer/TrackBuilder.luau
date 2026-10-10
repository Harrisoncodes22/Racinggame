-- TrackBuilder: builds the whole circuit from parts, straight from RaceConfig:
-- main road, side routes (shortcuts / alternate roads), kerbs, walls with openings
-- for the routes, boost pads, ramps, jump gaps over water, item boxes, ice,
-- water cannons with their operators, scenery and lighting.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VelocityCup")
local TrackMath = require(Shared:WaitForChild("TrackMath"))

local TrackBuilder = {}
local UP = Vector3.new(0, 1, 0)

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local made = 0
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then p.Shape = props.Shape end
	for k, v in pairs(props) do
		if k ~= "Shape" then p[k] = v end
	end
	p.Parent = parent
	made = made + 1
	if made % 250 == 0 then task.wait() end
	return p
end
local function deco(props, parent)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	if props.CastShadow == nil then props.CastShadow = true end
	return part(props, parent)
end
local function mat(name)
	local ok, m = pcall(function() return Enum.Material[name] end)
	return ok and m or Enum.Material.SmoothPlastic
end

local function tiles(folder, cx, cz, extent, y, color, material, thick, name, transparency)
	local n = math.max(1, math.ceil(extent * 2 / 2000))
	local size = extent * 2 / n
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			part({
				Name = name or "Ground",
				Size = Vector3.new(size + 1, thick, size + 1),
				Position = Vector3.new(cx - extent + size * (ix + 0.5), y - thick / 2, cz - extent + size * (iz + 0.5)),
				Color = color, Material = material, Transparency = transparency or 0,
			}, folder)
		end
	end
end

-- a simple blocky person (used for the water-cannon crews and spectators)
local function person(parent, cf, shirt)
	local skin = Color3.fromRGB(234, 184, 146)
	deco({ Name = "Legs", Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 1, 0), Color = Color3.fromRGB(40, 50, 90) }, parent)
	deco({ Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 3, 0), Color = shirt }, parent)
	for _, s in ipairs({ -1, 1 }) do
		deco({ Name = "Arm", Size = Vector3.new(1, 2, 1), CFrame = cf * CFrame.new(s * 1.5, 3.2, -0.6) * CFrame.Angles(math.rad(70), 0, 0), Color = skin }, parent)
	end
	deco({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(0, 4.7, 0), Color = skin }, parent)
	deco({ Name = "Cap", Size = Vector3.new(1.5, 0.4, 1.6), CFrame = cf * CFrame.new(0, 5.35, -0.15), Color = shirt }, parent)
end

function TrackBuilder.clear(folderName)
	local old = workspace:FindFirstChild(folderName or "VCTrack")
	if old then old:Destroy() end
end

-- folderName lets several tracks exist at once (one per race in progress)
function TrackBuilder.build(def, tr, folderName)
	folderName = folderName or "VCTrack"
	TrackBuilder.clear(folderName)
	made = 0
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder:SetAttribute("Theme", def.theme)
	local function sub(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
		return f
	end
	local roadF, padF, boxF, decoF, hazF = sub("Road"), sub("Pads"), sub("ItemBoxes"), sub("Scenery"), sub("Hazards")
	folder.Parent = workspace

	local P, T, S, N = tr.P, tr.T, tr.S, tr.N
	local W, HALF = tr.W, tr.HALF
	local wrap = TrackMath.wrap
	local b = tr.bounds
	local water = def.theme == "water"
	local groundY = water and -0.5 or (b.ymin - 2)
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	local extent = math.max(b.x1 - b.x0, b.z1 - b.z0) / 2 + 450

	-- ground
	if def.theme == "coast" then
		tiles(folder, cx, cz, extent, groundY, rgb(def.ground), mat(def.groundMat), 4)
		tiles(folder, cx, cz, extent + 2048, groundY - 3, Color3.fromRGB(31, 127, 180), Enum.Material.Glass, 4, "Ocean")
	elseif water then
		tiles(folder, cx, cz, extent + 1500, groundY, Color3.fromRGB(38, 132, 196), Enum.Material.Glass, 6, "Water", 0.05)
		tiles(folder, cx, cz, extent + 1500, groundY - 12, Color3.fromRGB(194, 178, 128), Enum.Material.Sand, 4, "SeaBed")
	else
		tiles(folder, cx, cz, extent + 1024, groundY, rgb(def.ground), mat(def.groundMat), 4)
	end

	-- jump gaps (open water) on the main line, ramps and no-respawn zones
	-- (shared with the cars' recovery code through TrackMath.jumps)
	local J = TrackMath.jumps(tr)
	local gapRanges = J.gaps
	local inGap = J.inGap

	-- keep pads, ramps and item boxes away from the places where routes split off or rejoin
	local function clearOfRoutes(i)
		for _, r in ipairs(tr.routes) do
			for _, e in ipairs({ r.from, r.to }) do
				local ahead, behind = (i - e) % N, (e - i) % N
				if ahead < 45 or behind < 30 then return false end
			end
		end
		return true
	end
	local safeIndex = J.safeIndex

	-- is a point inside a route's road area? (used to open walls)
	local function nearRoute(pos, pad)
		for _, r in ipairs(tr.routes) do
			for j = 1, r.M, 2 do
				local p = r.P[j]
				local dx, dz = pos.X - p.X, pos.Z - p.Z
				if dx * dx + dz * dz < (r.HALF + pad) ^ 2 then return r end
			end
		end
		return nil
	end

	-- ---------- main road ----------
	local STEP = 4
	local roadCol, shCol = rgb(def.road), rgb(def.shoulder)
	local kA, kB, bA, bB = rgb(def.kerbA), rgb(def.kerbB), rgb(def.barA), rgb(def.barB)
	local shMat = mat(def.shoulderMat)
	local barMat = def.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local k = 0
	for i = 1, N, STEP do
		k = k + 1
		local a, c = P[i], P[wrap(i + STEP, N)]
		if not inGap(i) then
			local len = (c - a).Magnitude
			local mid = (a + c) / 2
			local cf = CFrame.lookAt(mid, c)
			local turnA = math.acos(math.clamp(T[i]:Dot(T[wrap(i + STEP, N)]), -1, 1))
			local extra = HALF * turnA * 1.3 + 1.2
			part({ Name = "Road", Size = Vector3.new(W, 1, len + extra * 0.7), CFrame = cf * CFrame.new(0, -0.5, 0),
				Color = roadCol, Material = mat(def.roadMat or "Asphalt") }, roadF)
			if not water then
				local thick = math.max(2, mid.Y - groundY + 2)
				part({ Name = "Shoulder", Size = Vector3.new(HALF * 2, thick, len + extra), CFrame = cf * CFrame.new(0, -0.06 - thick / 2, 0),
					Color = shCol, Material = shMat }, roadF)
			end
			local kc = (k % 2 == 0) and kA or kB
			local bc = (k % 2 == 0) and bA or bB
			for _, s in ipairs({ -1, 1 }) do
				part({ Name = "Road", Size = Vector3.new(2.6, 1, len + extra * 0.35), CFrame = cf * CFrame.new(s * (W / 2 - 1.3), -0.47, 0), Color = kc }, roadF)
				local bpos = mid + S[i] * (s * (HALF + 0.8))
				local nr = nearRoute(bpos, 4)
				if not nr then
					part({ Name = "Barrier", Size = Vector3.new(1.8, 6, len + extra), CFrame = cf * CFrame.new(s * (HALF + 0.9), 2.95, 0),
						Color = bc, Material = barMat }, roadF)
				elseif nr.kind == "shortcut" then
					-- secret entrance: looks exactly like the wall, but you can drive straight through
					deco({ Name = "SecretWall", Size = Vector3.new(1.8, 6, len + extra), CFrame = cf * CFrame.new(s * (HALF + 0.9), 2.95, 0),
						Color = bc:Lerp(Color3.new(0, 0, 0), 0.08), Material = barMat }, roadF)
				end
			end
			if k % 2 == 1 then
				deco({ Name = "Line", Size = Vector3.new(0.7, 0.05, len * 0.55), CFrame = cf * CFrame.new(0, 0.01, 0),
					Color = Color3.fromRGB(240, 236, 226), CastShadow = false }, roadF)
			end
		end
	end

	-- ---------- side routes ----------
	local surfaceLook = {
		Road  = { color = roadCol, material = Enum.Material.Asphalt, transparency = 0 },
		Dirt  = { color = Color3.fromRGB(146, 104, 64), material = Enum.Material.Ground, transparency = 0 },
		Ice   = { color = Color3.fromRGB(191, 230, 255), material = Enum.Material.Ice, transparency = 0.1 },
		Water = { color = Color3.fromRGB(70, 170, 220), material = Enum.Material.Glass, transparency = 0.35 },
	}
	for _, r in ipairs(tr.routes) do
		local look = surfaceLook[r.surface] or surfaceLook.Road
		local RS = 3
		local kk = 0
		for j = 1, r.M - 1, RS do
			kk = kk + 1
			local a, c = r.P[j], r.P[math.min(r.M, j + RS)]
			local len = (c - a).Magnitude
			if len > 0.5 then
				local mid = (a + c) / 2
				local cf = CFrame.lookAt(mid, c)
				local ta, tb = r.T[j], r.T[math.min(r.M, j + RS)]
				local turnA = math.acos(math.clamp(ta:Dot(tb), -1, 1))
				local extra = r.HALF * turnA * 1.3 + 1.2
				local _, mlat = TrackMath.locate(tr, mid, r.from)
				local insideMain = math.abs(mlat) < HALF + 2
				-- where the route overlaps the main road, tuck it just under the main surface
				local overlap = 1 - math.clamp((math.abs(mlat) - W / 2) / (r.W * 0.75), 0, 1)
				local surfY = (r.surface == "Water") and -0.2 or (-0.04 - 0.3 * overlap)
				part({ Name = r.surface, Size = Vector3.new(r.W, 1, len + extra * 0.7), CFrame = cf * CFrame.new(0, surfY - 0.5, 0),
					Color = look.color, Material = look.material, Transparency = look.transparency }, roadF)
				if not water and not insideMain then
					local thick = math.max(2, mid.Y - groundY + 2)
					part({ Name = "Shoulder", Size = Vector3.new(r.HALF * 2, thick, len + extra), CFrame = cf * CFrame.new(0, -0.1 - thick / 2, 0),
						Color = shCol, Material = shMat }, roadF)
				end
				local fj = (j - 1) / math.max(1, r.M - 1)
				local inCave = r.cave and fj > 0.1 and fj < 0.9
				if inCave then
					-- rock tunnel: walls and a ceiling, lit by glowing mushrooms
					local rock = Color3.fromRGB(78, 70, 62)
					for _, s in ipairs({ -1, 1 }) do
						part({ Name = "CaveWall", Size = Vector3.new(3, 18, len + extra), CFrame = cf * CFrame.new(s * (r.W / 2 + 2.5), 8.5, 0), Color = rock, Material = Enum.Material.Slate }, roadF)
					end
					part({ Name = "CaveRoof", Size = Vector3.new(r.W + 8, 3, len + extra), CFrame = cf * CFrame.new(0, 18.5, 0), Color = rock:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Slate }, roadF)
					if kk % 5 == 0 then
						for _, s in ipairs({ -1, 1 }) do
							local m = deco({ Name = "Mushroom", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = cf * CFrame.new(s * (r.W / 2 + 0.6), 3 + (kk % 3), 0),
								Color = (kk % 2 == 0) and Color3.fromRGB(80, 255, 200) or Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon, CastShadow = false }, decoF)
							if s == 1 then
								local l = Instance.new("PointLight")
								l.Range = 26
								l.Brightness = 1.6
								l.Color = m.Color
								l.Parent = m
							end
						end
					end
				elseif not r.open then
					for _, s in ipairs({ -1, 1 }) do
						local bpos = mid + r.S[j] * (s * (r.HALF + 0.8))
						local _, blat = TrackMath.locate(tr, bpos, r.from)
						if math.abs(blat) > HALF + 3 then
							part({ Name = "Barrier", Size = Vector3.new(1.8, 6, len + extra), CFrame = cf * CFrame.new(s * (r.HALF + 0.9), 2.95, 0),
								Color = (kk % 2 == 0) and bA or bB, Material = barMat }, roadF)
						end
					end
				end
			end
		end
		if r.cave then
			-- a mountain on top of the tunnel (hollow inside, so you only see it from outside)
			for j = math.floor(r.M * 0.15), math.floor(r.M * 0.85), 14 do
				local p = r.P[j]
				local _, mlat = TrackMath.locate(tr, p, r.from)
				local room = math.abs(mlat) - HALF - 12
				local rad = math.clamp(room, 30, 95)
				deco({ Name = "Mountain", Shape = Enum.PartType.Ball, Size = Vector3.new(rad * 2, rad * 2, rad * 2), Position = p + UP * (rad * 0.05),
					Color = Color3.fromRGB(70 + (j % 3) * 8, 92, 52), Material = Enum.Material.Grass, CastShadow = false }, decoF)
			end
			-- stone archways at both ends, hidden behind hanging vines
			for _, fj in ipairs({ 0.1, 0.9 }) do
				local j = math.floor(r.M * fj)
				local p, t, sd = r.P[j], r.T[j], r.S[j]
				local cf = CFrame.lookAt(p, p + t)
				for _, s in ipairs({ -1, 1 }) do
					part({ Name = "ArchPillar", Size = Vector3.new(5, 22, 5), CFrame = cf * CFrame.new(s * (r.W / 2 + 4), 11, 0), Color = Color3.fromRGB(120, 112, 96), Material = Enum.Material.Cobblestone }, roadF)
				end
				part({ Name = "ArchTop", Size = Vector3.new(r.W + 14, 5, 5), CFrame = cf * CFrame.new(0, 22, 0), Color = Color3.fromRGB(120, 112, 96), Material = Enum.Material.Cobblestone }, roadF)
				for v = -r.W / 2 + 1, r.W / 2 - 1, 2.2 do
					deco({ Name = "Vine", Size = Vector3.new(0.5, 10 + (v * 7) % 6, 0.5), CFrame = cf * CFrame.new(v, 14, -1), Color = Color3.fromRGB(50, 120, 40), Material = Enum.Material.Grass, CastShadow = false }, decoF)
				end
			end
		end
		-- signs only for alternate routes; shortcuts are secret
		local e = r.P[math.min(r.M, 6)]
		if r.kind ~= "shortcut" then
		local sign = deco({ Name = "RouteSign", Size = Vector3.new(16, 4, 0.5), CFrame = CFrame.lookAt(e + UP * 10, e + UP * 10 - r.T[1]), Color = Color3.fromRGB(17, 17, 17) }, decoF)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.CanvasSize = Vector2.new(400, 100)
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBlack
		tl.TextScaled = true
		tl.TextColor3 = Color3.fromRGB(255, 210, 31)
		tl.Text = string.upper(r.name) .. ((r.kind == "shortcut") and "  ›  SHORTCUT" or "  ›  ALT ROUTE")
		tl.Parent = g
		g.Parent = sign
		for _, sd in ipairs({ -1, 1 }) do
			deco({ Name = "SignPost", Size = Vector3.new(0.6, 10, 0.6), Position = e + r.S[1] * (sd * 7.5) + UP * 5, Color = Color3.fromRGB(60, 60, 60) }, decoF)
		end
		end
	end

	-- ---------- start line and gantry ----------
	do
		local p, t = P[1], T[1]
		local cf = CFrame.lookAt(p, p + t)
		local sq = W / 12
		for col = 0, 11 do
			for row = 0, 1 do
				deco({ Name = "Checker", Size = Vector3.new(sq, 0.06, sq), CFrame = cf * CFrame.new(-W / 2 + sq * (col + 0.5), 0.02, (row - 0.5) * sq),
					Color = ((col + row) % 2 == 0) and Color3.new(0.95, 0.95, 0.95) or Color3.new(0.07, 0.07, 0.07), CastShadow = false }, roadF)
			end
		end
		local post = Color3.fromRGB(42, 45, 53)
		for _, sd in ipairs({ -1, 1 }) do
			part({ Name = "GantryPost", Size = Vector3.new(2, 24, 2), CFrame = cf * CFrame.new(sd * (HALF + 3), 12, 0), Color = post, Material = Enum.Material.Metal }, roadF)
		end
		local beam = part({ Name = "Gantry", Size = Vector3.new(HALF * 2 + 8, 4.5, 1.6), CFrame = cf * CFrame.new(0, 22, 0), Color = Color3.fromRGB(17, 17, 17) }, roadF)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.CanvasSize = Vector2.new(1000, 56)
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.Font = Enum.Font.GothamBlack
			tl.TextScaled = true
			tl.TextColor3 = Color3.fromRGB(255, 210, 31)
			tl.Text = "VELOCITY CUP  ·  " .. string.upper(def.name)
			tl.Parent = g
			g.Parent = beam
		end
	end

	-- ---------- boost pads ----------
	local pads, padInfo = {}, {}
	local function makePad(pos, dir, idx, lat)
		local cf = CFrame.lookAt(pos, pos + dir)
		local pad = deco({ Name = "BoostPad", Size = Vector3.new(14, 0.2, 26), CFrame = cf, Color = Color3.fromRGB(255, 176, 0),
			Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false }, padF)
		pad:SetAttribute("Index", idx)
		pad:SetAttribute("Lat", lat)
		for n = -1, 1 do
			for _, sd in ipairs({ -1, 1 }) do
				deco({ Name = "Chevron", Size = Vector3.new(0.8, 0.22, 4.6), CFrame = cf * CFrame.new(sd * 2.1, 0.03, n * 7) * CFrame.Angles(0, sd * math.rad(-50), 0),
					Color = Color3.fromRGB(255, 245, 190), Material = Enum.Material.Neon, CastShadow = false }, padF)
			end
		end
		pads[#pads + 1] = pad
		if idx then padInfo[#padInfo + 1] = { i = idx, lat = lat } end
	end
	for _, pd in ipairs(def.pads) do
		local i = safeIndex(TrackMath.straightIndex(tr, pd[1], 30))
		if not inGap(i) then makePad(P[i] + S[i] * pd[2] + UP * 0.14, T[i], i, pd[2]) end
	end
	for _, r in ipairs(tr.routes) do
		for _, f in ipairs(r.pads) do
			local j = math.clamp(math.floor(f * r.M + 0.5), 2, r.M - 1)
			makePad(r.P[j] + UP * 0.12, r.T[j], nil, 0)
		end
	end

	-- ---------- ramps (a tilted slab whose top surface is the ramp) ----------
	local function makeRamp(start, dir, width)
		local base = CFrame.lookAt(start, start + dir)
		local angle = math.atan(4.5 / 22.5)
		local Lr = TrackMath.RAMP_LEN
		part({ Name = "Ramp", Size = Vector3.new(width, 1.5, Lr), CFrame = base * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -0.75, -Lr / 2),
			Color = Color3.fromRGB(255, 210, 31), Material = Enum.Material.DiamondPlate }, roadF)
		for _, sd in ipairs({ -1, 1 }) do
			deco({ Name = "RampStripe", Size = Vector3.new(1.2, 0.06, Lr), CFrame = base * CFrame.Angles(angle, 0, 0) * CFrame.new(sd * (width / 2 - 1.5), 0.02, -Lr / 2),
				Color = Color3.fromRGB(20, 20, 20), CastShadow = false }, roadF)
		end
	end
	for _, rp in ipairs(J.ramps) do
		-- (full = the full-width ramp right before open water)
		if rp.full then
			makeRamp(P[rp.i], T[rp.i], W)
		else
			makeRamp(P[rp.i] + S[rp.i] * rp.lat, T[rp.i], 34)
		end
	end
	for _, g in ipairs(gapRanges) do
		-- buoys marking the gap
		for n = 0, g.n, 3 do
			local q = wrap(g.i0 + n, N)
			for _, sd in ipairs({ -1, 1 }) do
				deco({ Name = "Buoy", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = P[q] + S[q] * (sd * (HALF + 1)) + UP * 0.2,
					Color = (n % 6 == 0) and Color3.fromRGB(230, 60, 50) or Color3.fromRGB(250, 250, 250) }, decoF)
			end
		end
	end

	-- ---------- item boxes ----------
	local boxes = {}
	local function makeBox(pos)
		local box = deco({ Name = "ItemBox", Size = Vector3.new(4.6, 4.6, 4.6), CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(20), math.rad(45), 0),
			Color = Color3.fromRGB(140, 100, 255), Material = Enum.Material.Glass, Transparency = 0.3, CastShadow = false }, boxF)
		local core = deco({ Name = "ItemCore", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = box.CFrame, Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false }, box)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Mark"
		bb.Size = UDim2.fromScale(3, 3)
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBlack
		tl.TextScaled = true
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.3
		tl.Text = "?"
		tl.Parent = bb
		bb.Parent = box
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(180, 140, 255)
		light.Range = 12
		light.Parent = box
		boxes[#boxes + 1] = { part = box, core = core, gui = bb, light = light, active = true, t = 0 }
	end
	for _, f in ipairs(def.boxes) do
		local i = safeIndex(TrackMath.straightIndex(tr, f, 20))
		if not inGap(i) then
			for _, lf in ipairs({ -0.3, -0.1, 0.1, 0.3 }) do
				makeBox(P[i] + S[i] * (lf * W) + UP * 3.2)
			end
		end
	end
	for _, r in ipairs(tr.routes) do
		for _, f in ipairs(r.boxes) do
			local j = math.clamp(math.floor(f * r.M + 0.5), 2, r.M - 1)
			for _, lf in ipairs({ -0.25, 0.25 }) do
				makeBox(r.P[j] + r.S[j] * (lf * r.W) + UP * 3.2)
			end
		end
	end

	-- ---------- ice patches ----------
	for _, ice in ipairs(def.ice or {}) do
		local i0 = math.floor(ice[1] * N + 0.5)
		local n = math.floor(ice[3] / tr.seg + 0.5)
		for j = 0, n - 1, 3 do
			local a, c = P[wrap(i0 + j, N)], P[wrap(i0 + j + 3, N)]
			local mid = (a + c) / 2
			local sMid = S[wrap(i0 + j, N)]
			local w = ice[4] * (0.7 + 0.3 * math.sin(j / n * math.pi))
			local pos = mid + sMid * ice[2]
			local cf = CFrame.lookAt(pos, pos + (c - a))
			part({ Name = "Ice", Size = Vector3.new(w, 0.12, (c - a).Magnitude + 1), CFrame = cf * CFrame.new(0, 0.07, 0),
				Color = Color3.fromRGB(191, 230, 255), Material = Enum.Material.Ice, Transparency = 0.15, CastShadow = false }, roadF)
		end
	end

	-- ---------- trees standing in the road (obstacles to dodge) ----------
	local obstacles = {}
	local function jungleTree(pos, h, collide)
		local trunkProps = { Name = "TreeTrunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 4.2, 4.2), CFrame = CFrame.new(pos + UP * (h / 2)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(96, 70, 44), Material = Enum.Material.Wood }
		if collide then part(trunkProps, roadF) else deco(trunkProps, decoF) end
		for n = 0, 2 do
			local r = 12 - n * 2.5
			deco({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = pos + UP * (h - 1 + n * 3) + Vector3.new((n - 1) * 3, 0, ((n * 7) % 3 - 1) * 3),
				Color = Color3.fromRGB(40 + n * 12, 110 + n * 14, 36), Material = Enum.Material.Grass }, decoF)
		end
		deco({ Name = "Roots", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 2.4, 6), Position = pos + UP * 0.3, Color = Color3.fromRGB(80, 60, 38), Material = Enum.Material.Wood, CastShadow = false }, decoF)
	end
	local function nearItems(pos)
		for _, pd in ipairs(pads) do if (pd.Position - pos).Magnitude < 26 then return true end end
		for _, bx in ipairs(boxes) do if (bx.part.Position - pos).Magnitude < 20 then return true end end
		return false
	end
	for _, tdef in ipairs(def.trees or {}) do
		local i0, i1, every = math.floor(tdef[1] * N), math.floor(tdef[2] * N), tdef[3]
		local n = 0
		for i = i0, i1, every do
			n = n + 1
			local ii = wrap(i, N)
			local lat = ({ -0.28, 0.28, 0, 0.28, -0.28, 0.12 })[(n - 1) % 6 + 1] * W
			local pos = P[ii] + S[ii] * lat
			if clearOfRoutes(ii) and not nearItems(pos) then
				jungleTree(pos, 26, true)
				obstacles[#obstacles + 1] = { i = ii, lat = lat }
			end
		end
	end
	if def.theme == "jungle" then
		-- trees all along the roadside too (hit them if you cut the corners)
		for i = 1, N, 22 do
			local sd = (math.floor(i / 22) % 2 == 0) and 1 or -1
			local lat = sd * (W / 2 + 5 + (i % 7))
			local pos = P[i] + S[i] * lat
			if clearOfRoutes(i) and not nearRoute(pos, 6) then
				jungleTree(pos, 24 + (i % 9), true)
				obstacles[#obstacles + 1] = { i = i, lat = lat }
			end
		end
	end

	-- ---------- water cannons ----------
	local cannons = {}
	for _, cdef in ipairs(def.cannons or {}) do
		local base = math.floor(cdef[1] * N + 0.5)
		for kc = 0, cdef[2] - 1 do
			local i = wrap(base + kc * cdef[3], N)
			local side = (kc % 2 == 0) and 1 or -1
			local p, t, s = P[i], T[i], S[i]
			local dockPos = p + s * (side * (HALF + 9))
			local face = CFrame.lookAt(dockPos, dockPos - s * side)
			part({ Name = "Dock", Size = Vector3.new(12, 1, 12), CFrame = face * CFrame.new(0, -0.3, 0), Color = Color3.fromRGB(140, 100, 64), Material = Enum.Material.WoodPlanks }, hazF)
			for _, px in ipairs({ -5, 5 }) do
				for _, pz in ipairs({ -5, 5 }) do
					deco({ Name = "Pile", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 1, 1), CFrame = face * CFrame.new(px, -3, pz) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(100, 72, 48) }, hazF)
				end
			end
			local shirt = ({ Color3.fromRGB(230, 60, 50), Color3.fromRGB(255, 200, 40), Color3.fromRGB(40, 160, 90) })[(kc % 3) + 1]
			person(hazF, face * CFrame.new(1.8, 0.2, 2.5), shirt)
			deco({ Name = "CannonBase", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = face * CFrame.new(-1.5, 1.4, -0.5), Color = Color3.fromRGB(60, 64, 72), Material = Enum.Material.Metal }, hazF)
			local barrel = deco({ Name = "Cannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.6, 1.6), CFrame = face * CFrame.new(-1.5, 3.2, -2.5) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(200, 205, 212), Material = Enum.Material.Metal }, hazF)
			local tip = deco({ Name = "Nozzle", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = face * CFrame.new(-1.5, 3.2, -5), Color = Color3.fromRGB(60, 160, 255), Material = Enum.Material.Neon, CastShadow = false }, hazF)
			-- the jet itself: a cylinder across the road (hidden until it fires)
			local center = p + UP * 2.6
			local jetCF = CFrame.lookAt(center, center + t)
			local jet = deco({ Name = "WaterJet", Shape = Enum.PartType.Cylinder, Size = Vector3.new(HALF * 2 + 14, 5, 5), CFrame = jetCF,
				Color = Color3.fromRGB(140, 210, 255), Material = Enum.Material.Glass, Transparency = 1, CastShadow = false }, hazF)
			local ea = Instance.new("Attachment")
			ea.Parent = tip
			local spray = Instance.new("ParticleEmitter")
			spray.Name = "Spray"
			spray.Rate = 160
			spray.Lifetime = NumberRange.new(0.5, 0.8)
			spray.Speed = NumberRange.new(60, 80)
			spray.SpreadAngle = Vector2.new(6, 6)
			spray.EmissionDirection = Enum.NormalId.Front
			spray.Size = NumberSequence.new(1.6, 3)
			spray.Transparency = NumberSequence.new(0.2, 1)
			spray.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
			spray.Enabled = false
			spray.Parent = ea
			ea.CFrame = CFrame.new(Vector3.new(), tip.CFrame:VectorToObjectSpace(-s * side))
			cannons[#cannons + 1] = { i = i, side = side, jet = jet, nozzle = tip, spray = spray, barrel = barrel, phase = kc * 0.55, hit = {} }
		end
		-- warning sign before the cannon section
		local wi = wrap(base - 40, N)
		local sp = P[wi] + UP * 12
		local sign = deco({ Name = "WarnSign", Size = Vector3.new(26, 4, 0.5), CFrame = CFrame.lookAt(sp, sp - T[wi]), Color = Color3.fromRGB(230, 60, 50) }, decoF)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.CanvasSize = Vector2.new(520, 80)
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBlack
		tl.TextScaled = true
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.Text = "WATER CANNONS AHEAD · DODGE!"
		tl.Parent = g
		g.Parent = sign
	end

	-- ---------- track dressing: grandstand, start lights, billboards, tyre walls, lamps ----------
	local dressF = sub("Dressing")
	local startLights = {}
	do
		local p0, t0 = P[1], T[1]
		local base = CFrame.lookAt(p0, p0 + t0)
		-- start lights hanging under the gantry, facing the grid
		for n = 1, 5 do
			local lamp = deco({ Name = "StartLight", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = base * CFrame.new((n - 3) * 3.2, 18.8, 0.9),
				Color = Color3.fromRGB(60, 10, 10), Material = Enum.Material.SmoothPlastic, CastShadow = false }, dressF)
			startLights[n] = lamp
			deco({ Name = "LightBox", Size = Vector3.new(2.8, 3, 1), CFrame = base * CFrame.new((n - 3) * 3.2, 18.8, 0.2), Color = Color3.fromRGB(20, 20, 24) }, dressF)
		end
		-- grandstand with a crowd beside the start line
		local side = -1
		if nearRoute(p0 + S[1] * (side * (HALF + 12)), 20) then side = 1 end
		local gs = base * CFrame.new(side * (HALF + 9), 0, 0)
		local crowd = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(40, 120, 230), Color3.fromRGB(255, 210, 40), Color3.fromRGB(40, 180, 90), Color3.fromRGB(240, 240, 240), Color3.fromRGB(170, 70, 220) }
		for tier = 0, 4 do
			local tcf = gs * CFrame.new(side * tier * 5, tier * 2.2 + 1.1, 0)
			part({ Name = "Grandstand", Size = Vector3.new(5, 2.2 + tier * 4.4, 70), CFrame = tcf * CFrame.new(0, -tier * 2.2, 0), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.Concrete }, dressF)
			for k = 0, 11 do
				deco({ Name = "Fan", Size = Vector3.new(1.2, 2.4, 1.2), CFrame = tcf * CFrame.new(0, 2.3, -30 + k * 5.4 + (tier % 2) * 2), Color = crowd[((k + tier * 3) % #crowd) + 1] }, dressF)
				deco({ Name = "FanHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = tcf * CFrame.new(0, 4, -30 + k * 5.4 + (tier % 2) * 2), Color = Color3.fromRGB(234, 184, 146) }, dressF)
			end
		end
		part({ Name = "StandRoof", Size = Vector3.new(30, 1, 74), CFrame = gs * CFrame.new(side * 10, 20, 0), Color = Color3.fromRGB(230, 60, 50) }, dressF)
		for _, z in ipairs({ -34, 0, 34 }) do
			part({ Name = "RoofPost", Size = Vector3.new(1, 20, 1), CFrame = gs * CFrame.new(side * 23, 10, z), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal }, dressF)
		end
	end
	-- billboards along the straights
	local ads = { { "VELOCITY CUP", Color3.fromRGB(255, 210, 31), Color3.fromRGB(17, 17, 17) }, { "TURBO OIL", Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 30, 30) },
		{ "DRIFT KING TYRES", Color3.fromRGB(20, 20, 20), Color3.fromRGB(255, 200, 40) }, { "SPEEDY BURGERS", Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 140, 60) },
		{ "NITRO COLA", Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 90, 220) }, { "FAST LANE PIZZA", Color3.fromRGB(255, 240, 200), Color3.fromRGB(160, 50, 30) } }
	local adN = 0
	for i = 60, N - 60, 150 do
		local sd = (math.floor(i / 150) % 2 == 0) and 1 or -1
		local pos = P[i] + S[i] * (sd * (HALF + 9))
		if clearOfRoutes(i) and not nearRoute(pos, 16) then
			adN = adN + 1
			local ad = ads[(adN - 1) % #ads + 1]
			local cf = CFrame.lookAt(pos + UP * 9, pos + UP * 9 - S[i] * sd)
			local board = part({ Name = "Billboard", Size = Vector3.new(30, 9, 1), CFrame = cf, Color = ad[3] }, dressF)
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.CanvasSize = Vector2.new(600, 180)
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.Font = Enum.Font.GothamBlack
			tl.TextScaled = true
			tl.TextColor3 = ad[2]
			tl.Text = ad[1]
			tl.Parent = g
			g.Parent = board
			for _, x in ipairs({ -12, 12 }) do
				part({ Name = "BillboardPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(x, -9, 0.6), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal }, dressF)
			end
		end
	end
	-- tyre stacks on the outside of the sharp corners
	local stacks = 0
	for i = 1, N, 9 do
		local a2 = T[wrap(i + 14, N)]
		local bend = 1 - T[i]:Dot(a2)
		if bend > 0.025 and stacks < 40 and clearOfRoutes(i) then
			local outer = (T[i]:Cross(a2).Y > 0) and 1 or -1
			local pos = P[i] + S[i] * (outer * (HALF + 2.6))
			if not nearRoute(pos, 6) then
				stacks = stacks + 1
				for h2 = 0, 2 do
					deco({ Name = "Tyre", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3, 3), CFrame = CFrame.new(pos + UP * (0.6 + h2 * 1.2)) * CFrame.Angles(0, 0, math.pi / 2),
						Color = (h2 == 1) and Color3.fromRGB(230, 230, 230) or Color3.fromRGB(25, 25, 28) }, dressF)
				end
			end
		end
	end
	-- lamp posts (they light up on the dark maps)
	local lit = def.theme == "city" or def.theme == "lava" or def.theme == "jungle"
	for i = 30, N, 70 do
		local sd = (math.floor(i / 70) % 2 == 0) and -1 or 1
		local pos = P[i] + S[i] * (sd * (HALF + 4.5))
		if clearOfRoutes(i) and not nearRoute(pos, 6) then
			part({ Name = "LampPost", Size = Vector3.new(0.7, 18, 0.7), CFrame = CFrame.new(pos + UP * 9), Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Metal }, dressF)
			deco({ Name = "LampArm", Size = Vector3.new(0.4, 0.4, 5), CFrame = CFrame.lookAt(pos + UP * 17.8 - S[i] * sd * 2.3, pos + UP * 17.8 - S[i] * sd * 5), Color = Color3.fromRGB(70, 72, 80) }, dressF)
			local head = deco({ Name = "LampHead", Size = Vector3.new(1.6, 0.4, 2.4), CFrame = CFrame.lookAt(pos + UP * 17.5 - S[i] * sd * 4.6, pos + UP * 17.5 - S[i] * sd * 6), Color = Color3.fromRGB(255, 244, 210), Material = Enum.Material.Neon, CastShadow = false }, dressF)
			if lit then
				local l = Instance.new("SpotLight")
				l.Face = Enum.NormalId.Bottom
				l.Range = 40
				l.Angle = 70
				l.Brightness = 2
				l.Color = Color3.fromRGB(255, 236, 200)
				l.Parent = head
			end
		end
	end
	-- corner arrow boards and skid marks on the sharp bends
	local boards = 0
	for i = 1, N, 13 do
		local a2 = T[wrap(i + 14, N)]
		local bend = 1 - T[i]:Dot(a2)
		if bend > 0.03 and boards < 26 and clearOfRoutes(i) then
			local outer = (T[i]:Cross(a2).Y > 0) and 1 or -1
			local pos = P[i] + S[i] * (outer * (HALF + 7))
			if not nearRoute(pos, 8) then
				boards = boards + 1
				local cf = CFrame.lookAt(pos + UP * 4.5, pos + UP * 4.5 - T[i])
				local b2 = deco({ Name = "ArrowBoard", Size = Vector3.new(9, 3.5, 0.4), CFrame = cf, Color = Color3.fromRGB(255, 210, 31) }, dressF)
				local g = Instance.new("SurfaceGui")
				g.Face = Enum.NormalId.Front
				g.CanvasSize = Vector2.new(300, 110)
				local tl = Instance.new("TextLabel")
				tl.Size = UDim2.fromScale(1, 1)
				tl.BackgroundTransparency = 1
				tl.Font = Enum.Font.GothamBlack
				tl.TextScaled = true
				tl.TextColor3 = Color3.fromRGB(20, 20, 20)
				tl.Text = (outer > 0) and "<<<" or ">>>"
				tl.Parent = g
				g.Parent = b2
				for _, x in ipairs({ -3.5, 3.5 }) do
					deco({ Name = "BoardLeg", Size = Vector3.new(0.4, 3, 0.4), CFrame = cf * CFrame.new(x, -3.2, 0), Color = Color3.fromRGB(60, 60, 66) }, dressF)
				end
				-- rubber laid down through the corner
				for k = -1, 1 do
					local q = wrap(i + k * 3, N)
					deco({ Name = "SkidMark", Size = Vector3.new(0.9, 0.04, 10), CFrame = CFrame.lookAt(P[q] + S[q] * (-outer * W * 0.18) + UP * 0.03, P[q] + S[q] * (-outer * W * 0.18) + UP * 0.03 + T[q]) * CFrame.Angles(0, k * 0.12, 0),
						Color = Color3.fromRGB(28, 28, 30), Transparency = 0.35, CastShadow = false }, dressF)
				end
			end
		end
	end
	-- flags on poles along the walls
	local flagCols = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(255, 210, 31), Color3.fromRGB(40, 120, 230), Color3.fromRGB(240, 240, 240) }
	for i = 20, N, 48 do
		local sd = (math.floor(i / 48) % 2 == 0) and 1 or -1
		local pos = P[i] + S[i] * (sd * (HALF + 3))
		if clearOfRoutes(i) and not nearRoute(pos, 6) then
			deco({ Name = "FlagPole", Size = Vector3.new(0.35, 14, 0.35), Position = pos + UP * 7, Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }, dressF)
			deco({ Name = "Flag", Size = Vector3.new(0.08, 2.6, 4), CFrame = CFrame.lookAt(pos + UP * 12.6, pos + UP * 12.6 + T[i]) * CFrame.new(0, 0, 2) * CFrame.Angles(0, math.pi / 2, 0),
				Color = flagCols[(math.floor(i / 48) % #flagCols) + 1], Material = Enum.Material.Fabric, CastShadow = false }, dressF)
		end
	end
	-- sponsor arches over the road at one third and two thirds of the lap
	for _, f in ipairs({ 0.33, 0.66 }) do
		local i = safeIndex(TrackMath.straightIndex(tr, f, 20))
		local p2, t2 = P[i], T[i]
		local cf = CFrame.lookAt(p2, p2 + t2)
		for _, sd in ipairs({ -1, 1 }) do
			part({ Name = "ArchPost", Size = Vector3.new(2.4, 30, 2.4), CFrame = cf * CFrame.new(sd * (HALF + 4), 15, 0), Color = Color3.fromRGB(30, 32, 40), Material = Enum.Material.Metal }, dressF)
		end
		local beam = part({ Name = "ArchBanner", Size = Vector3.new(HALF * 2 + 10, 5, 1.2), CFrame = cf * CFrame.new(0, 28, 0), Color = Color3.fromRGB(230, 60, 50) }, dressF)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.CanvasSize = Vector2.new(900, 60)
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.Font = Enum.Font.GothamBlack
			tl.TextScaled = true
			tl.TextColor3 = Color3.new(1, 1, 1)
			tl.Text = (f < 0.5) and "TURBO OIL  ·  GO FASTER" or "DRIFT KING TYRES  ·  HOLD THAT LINE"
			tl.Parent = g
			g.Parent = beam
		end
	end
	-- catch fence along the start straight
	for i = N - 60, N + 40, 6 do
		local q = wrap(i, N)
		for _, sd in ipairs({ -1, 1 }) do
			local pos = P[q] + S[q] * (sd * (HALF + 1.9))
			if not nearRoute(pos, 6) then
				deco({ Name = "FencePost", Size = Vector3.new(0.3, 12, 0.3), Position = pos + UP * 6, Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, CastShadow = false }, dressF)
				deco({ Name = "Fence", Size = Vector3.new(0.1, 7, 6 * tr.seg), CFrame = CFrame.lookAt(pos + UP * 8, pos + UP * 8 + T[q]), Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.DiamondPlate, Transparency = 0.6, CastShadow = false }, dressF)
			end
		end
	end
	-- a few theme props right next to the track
	local function nearSpot(n, gapSamples, extra)
		local out = {}
		for i = 40, N - 40, gapSamples do
			if #out >= n then break end
			local sd = (math.floor(i / gapSamples) % 2 == 0) and 1 or -1
			local pos = P[i] + S[i] * (sd * (HALF + extra))
			if clearOfRoutes(i) and not nearRoute(pos, 10) then out[#out + 1] = { pos = pos, i = i, sd = sd } end
		end
		return out
	end
	if def.theme == "coast" then
		for k, sp in ipairs(nearSpot(14, 110, 14)) do
			local base2 = sp.pos
			deco({ Name = "UmbrellaPole", Size = Vector3.new(0.4, 8, 0.4), Position = base2 + UP * 4, Color = Color3.fromRGB(240, 240, 240) }, dressF)
			deco({ Name = "Umbrella", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9, 9), CFrame = CFrame.new(base2 + UP * 8) * CFrame.Angles(0, 0, math.pi / 2),
				Color = ({ Color3.fromRGB(230, 60, 50), Color3.fromRGB(40, 140, 230), Color3.fromRGB(255, 210, 40) })[(k % 3) + 1] }, dressF)
			deco({ Name = "Towel", Size = Vector3.new(3, 0.1, 5), CFrame = CFrame.new(base2 + Vector3.new(3, 0.1, 2)) * CFrame.Angles(0, k, 0), Color = Color3.fromRGB(255, 120, 180) }, dressF)
		end
	elseif def.theme == "frost" then
		for _, sp in ipairs(nearSpot(10, 140, 13)) do
			for n, r in ipairs({ 4, 3, 2.2 }) do
				deco({ Name = "Snowman", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = sp.pos + UP * (({ 2, 5.2, 7.6 })[n]), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow }, dressF)
			end
			deco({ Name = "Carrot", Size = Vector3.new(0.3, 0.3, 1.2), CFrame = CFrame.lookAt(sp.pos + UP * 7.6, sp.pos + UP * 7.6 - S[sp.i] * sp.sd) * CFrame.new(0, 0, -1.4), Color = Color3.fromRGB(255, 130, 30) }, dressF)
			deco({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1.6, 1.6), CFrame = CFrame.new(sp.pos + UP * 9.3) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(20, 20, 24) }, dressF)
		end
	elseif def.theme == "city" then
		for _, sp in ipairs(nearSpot(10, 150, 6)) do
			deco({ Name = "SignalPole", Size = Vector3.new(0.6, 12, 0.6), Position = sp.pos + UP * 6, Color = Color3.fromRGB(40, 40, 46) }, dressF)
			local box = deco({ Name = "Signal", Size = Vector3.new(1.4, 4, 1.2), CFrame = CFrame.lookAt(sp.pos + UP * 12, sp.pos + UP * 12 - S[sp.i] * sp.sd), Color = Color3.fromRGB(30, 30, 34) }, dressF)
			for n, col in ipairs({ Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 190, 30), Color3.fromRGB(40, 230, 90) }) do
				deco({ Name = "SignalLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = box.CFrame * CFrame.new(0, 1.3 - (n - 1) * 1.3, -0.6), Color = col, Material = Enum.Material.Neon, CastShadow = false }, dressF)
			end
		end
	elseif def.theme == "lava" then
		for k, sp in ipairs(nearSpot(18, 80, 16)) do
			deco({ Name = "LavaCrack", Size = Vector3.new(1.2, 0.2, 18), CFrame = CFrame.new(sp.pos + UP * 0.1) * CFrame.Angles(0, k * 0.7, 0), Color = Color3.fromRGB(255, 110, 20), Material = Enum.Material.Neon, CastShadow = false }, dressF)
		end
	elseif def.theme == "jungle" then
		for k, sp in ipairs(nearSpot(8, 190, 15)) do
			for n = 0, 3 do
				deco({ Name = "Totem", Size = Vector3.new(3, 3.4, 3), CFrame = CFrame.new(sp.pos + UP * (1.7 + n * 3.4)) * CFrame.Angles(0, n * 0.4, 0),
					Color = ({ Color3.fromRGB(160, 90, 50), Color3.fromRGB(60, 140, 120), Color3.fromRGB(200, 160, 60), Color3.fromRGB(150, 50, 40) })[n + 1], Material = Enum.Material.Wood }, dressF)
			end
		end
	end

	-- ---------- scenery ----------
	local rng = Random.new(#def.id * 977 + 13)
	local function nearTrack(x, z)
		local m = math.huge
		for i = 1, N, 8 do
			local dx, dz = x - P[i].X, z - P[i].Z
			local q = dx * dx + dz * dz
			if q < m then m = q end
		end
		for _, r in ipairs(tr.routes) do
			for j = 1, r.M, 6 do
				local dx, dz = x - r.P[j].X, z - r.P[j].Z
				local q = dx * dx + dz * dz - (HALF - r.HALF) ^ 2
				if q < m then m = q end
			end
		end
		return math.sqrt(math.max(0, m))
	end
	local function scatter(count, clear, margin)
		local out, tries = {}, 0
		while #out < count and tries < count * 30 do
			tries = tries + 1
			local x = rng:NextNumber(b.x0 - margin, b.x1 + margin)
			local z = rng:NextNumber(b.z0 - margin, b.z1 + margin)
			local d = nearTrack(x, z)
			if d > clear then out[#out + 1] = { x = x, z = z, d = d } end
		end
		return out
	end
	local gy = groundY
	local function palm(x, z, y)
		local h = rng:NextNumber(16, 26)
		local lean = CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15))
		local root = CFrame.new(x, y, z) * lean
		deco({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = root * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(138, 100, 64), Material = Enum.Material.Wood }, decoF)
		for f = 0, 5 do
			deco({ Name = "Frond", Size = Vector3.new(1.6, 0.4, 11), CFrame = root * CFrame.new(0, h, 0) * CFrame.Angles(0, f * math.pi / 3, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -5),
				Color = Color3.fromRGB(47, 138, 60), Material = Enum.Material.Grass }, decoF)
		end
	end
	if def.theme == "coast" then
		for _, s in ipairs(scatter(110, HALF + 14, 300)) do palm(s.x, s.z, gy) end
		for _, s in ipairs(scatter(35, HALF + 10, 250)) do
			local r = rng:NextNumber(4, 12)
			deco({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = Vector3.new(s.x, gy, s.z), Color = Color3.fromRGB(165, 143, 120), Material = Enum.Material.Slate }, decoF)
		end
		-- spectators on the beach shortcut
		for _, r in ipairs(tr.routes) do
			for j = 10, r.M - 10, 12 do
				for _, sd in ipairs({ -1, 1 }) do
					local p = r.P[j] + r.S[j] * (sd * (r.HALF + 6))
					if nearTrack(p.X, p.Z) > HALF * 0.5 then
						person(decoF, CFrame.lookAt(Vector3.new(p.X, gy, p.Z), Vector3.new(r.P[j].X, gy, r.P[j].Z)), Color3.fromRGB(rng:NextInteger(60, 255), rng:NextInteger(60, 255), rng:NextInteger(60, 255)))
					end
				end
			end
		end
	elseif def.theme == "city" then
		local neon = { Color3.fromRGB(255, 43, 214), Color3.fromRGB(34, 230, 255), Color3.fromRGB(255, 210, 120) }
		for _, s in ipairs(scatter(130, HALF + 40, 300)) do
			local w = math.min(rng:NextNumber(24, 70), (s.d - HALF - 10) * 1.2)
			local d = rng:NextNumber(24, 70)
			local hgt = rng:NextNumber(40, 300)
			local cf = CFrame.new(s.x, gy + hgt / 2, s.z) * CFrame.Angles(0, rng:NextNumber(0, 0.4), 0)
			deco({ Name = "Building", Size = Vector3.new(w, hgt, d), CFrame = cf,
				Color = Color3.fromRGB(rng:NextInteger(28, 52), rng:NextInteger(28, 45), rng:NextInteger(45, 70)), Material = Enum.Material.Glass, Reflectance = 0.2 }, decoF)
			local nc = neon[rng:NextInteger(1, #neon)]
			for _, fy in ipairs({ 0.25, 0.6 }) do
				deco({ Name = "Neon", Size = Vector3.new(w + 0.4, 1.2, d + 0.4), CFrame = cf * CFrame.new(0, hgt * (fy - 0.5), 0), Color = nc, Material = Enum.Material.Neon, CastShadow = false }, decoF)
			end
		end
		for i = 1, N, 40 do
			for _, sd in ipairs({ -1, 1 }) do
				local p = P[i] + S[i] * (sd * (HALF + 4))
				if not nearRoute(p, 2) then
					deco({ Name = "NeonPost", Size = Vector3.new(0.8, 16, 0.8), Position = p + UP * 8, Color = sd < 0 and neon[1] or neon[2], Material = Enum.Material.Neon, CastShadow = false }, decoF)
				end
			end
		end
	elseif def.theme == "frost" then
		for _, s in ipairs(scatter(120, HALF + 14, 320)) do
			local sc = rng:NextNumber(0.8, 1.6)
			local root = CFrame.new(s.x, gy, s.z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			deco({ Name = "Trunk", Size = Vector3.new(1.5, 5, 1.5) * sc, CFrame = root * CFrame.new(0, 2.5 * sc, 0), Color = Color3.fromRGB(90, 62, 43), Material = Enum.Material.Wood }, decoF)
			for tt = 0, 2 do
				local w = (12 - tt * 3.4) * sc
				deco({ Name = "Pine", Size = Vector3.new(w, 4.5 * sc, w), CFrame = root * CFrame.new(0, (5 + tt * 4) * sc, 0) * CFrame.Angles(0, math.rad(45 * tt), 0),
					Color = Color3.fromRGB(31, 77, 58), Material = Enum.Material.Grass }, decoF)
			end
			deco({ Name = "SnowCap", Size = Vector3.new(3.4, 2, 3.4) * sc, CFrame = root * CFrame.new(0, 16.5 * sc, 0), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow }, decoF)
		end
		for m = 1, 12 do
			local a = m / 12 * math.pi * 2 + rng:NextNumber(0, 0.3)
			local dist = extent + rng:NextNumber(150, 500)
			local r = rng:NextNumber(500, 1100)
			deco({ Name = "Mountain", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = Vector3.new(cx + math.cos(a) * dist, gy - r * 0.15, cz + math.sin(a) * dist),
				Color = Color3.fromRGB(233, 238, 245), Material = Enum.Material.Snow, CastShadow = false }, decoF)
		end
	elseif def.theme == "lava" then
		for _, s in ipairs(scatter(110, HALF + 14, 320)) do
			local hgt = rng:NextNumber(18, 60)
			local w = rng:NextNumber(6, 14)
			local root = CFrame.new(s.x, gy, s.z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			deco({ Name = "Spire", Size = Vector3.new(w, hgt, w), CFrame = root * CFrame.new(0, hgt / 2, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)),
				Color = Color3.fromRGB(46, 32, 29), Material = Enum.Material.Basalt }, decoF)
			deco({ Name = "SpireTop", Size = Vector3.new(w * 0.6, hgt * 0.35, w * 0.6), CFrame = root * CFrame.new(0, hgt + hgt * 0.15, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color = Color3.fromRGB(56, 38, 34), Material = Enum.Material.Basalt }, decoF)
		end
		for _, s in ipairs(scatter(40, HALF + 40, 260)) do
			local r = rng:NextNumber(14, 40)
			deco({ Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, r, r), CFrame = CFrame.new(s.x, gy + 0.1, s.z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(255, 90, 18), Material = Enum.Material.Neon, CastShadow = false }, decoF)
		end
		local vpos = Vector3.new(cx + extent + 400, gy, cz - 300)
		deco({ Name = "Volcano", Shape = Enum.PartType.Ball, Size = Vector3.new(1400, 1400, 1400), Position = vpos - UP * 350, Color = Color3.fromRGB(42, 26, 22), Material = Enum.Material.Basalt, CastShadow = false }, decoF)
		deco({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 260, 260), CFrame = CFrame.new(vpos + UP * 352) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 106, 26), Material = Enum.Material.Neon, CastShadow = false }, decoF)
	elseif def.theme == "jungle" then
		for _, sp in ipairs(scatter(220, HALF + 10, 320)) do
			jungleTree(Vector3.new(sp.x, gy, sp.z), rng:NextNumber(22, 46), false)
		end
		for _, sp in ipairs(scatter(120, HALF + 6, 260)) do
			local r = rng:NextNumber(5, 12)
			deco({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r * 0.8, r), Position = Vector3.new(sp.x, gy + r * 0.25, sp.z),
				Color = Color3.fromRGB(rng:NextInteger(40, 70), rng:NextInteger(100, 140), 40), Material = Enum.Material.Grass }, decoF)
		end
		-- old temple ruins
		for _, sp in ipairs(scatter(26, HALF + 30, 260)) do
			local cf = CFrame.new(sp.x, gy, sp.z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			for n = 0, rng:NextInteger(1, 3) do
				deco({ Name = "Ruin", Size = Vector3.new(10 - n * 2, 5, 10 - n * 2), CFrame = cf * CFrame.new(rng:NextNumber(-1, 1), 2.5 + n * 5, 0) * CFrame.Angles(0, n * 0.3, 0),
					Color = Color3.fromRGB(128, 120, 102), Material = Enum.Material.Cobblestone }, decoF)
			end
		end
		local tp = Vector3.new(cx, gy, b.z0 - 260)
		for n = 0, 6 do
			local w = 140 - n * 18
			deco({ Name = "Temple", Size = Vector3.new(w, 12, w), Position = tp + UP * (6 + n * 12), Color = Color3.fromRGB(118 + n * 3, 112, 94), Material = Enum.Material.Cobblestone }, decoF)
		end
	elseif water then
		-- sandy islands with palms
		for _, s in ipairs(scatter(26, HALF + 60, 400)) do
			local r = rng:NextNumber(40, 110)
			deco({ Name = "Island", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = Vector3.new(s.x, gy - r * 0.42, s.z), Color = Color3.fromRGB(230, 205, 150), Material = Enum.Material.Sand }, decoF)
			for _ = 1, math.floor(r / 30) + 1 do
				local a = rng:NextNumber(0, 6.28)
				local rr = rng:NextNumber(0, r * 0.18)
				palm(s.x + math.cos(a) * rr, s.z + math.sin(a) * rr, gy + r * 0.08)
			end
		end
		-- boats
		for _, s in ipairs(scatter(22, HALF + 30, 350)) do
			local cf = CFrame.new(s.x, gy + 0.6, s.z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local hull = Color3.fromRGB(rng:NextInteger(180, 255), rng:NextInteger(60, 240), rng:NextInteger(40, 220))
			deco({ Name = "Hull", Size = Vector3.new(8, 3, 22), CFrame = cf, Color = hull }, decoF)
			deco({ Name = "Deck", Size = Vector3.new(7.4, 0.4, 20), CFrame = cf * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(200, 160, 110), Material = Enum.Material.WoodPlanks }, decoF)
			deco({ Name = "Cabin", Size = Vector3.new(6, 4, 7), CFrame = cf * CFrame.new(0, 3.8, 2), Color = Color3.fromRGB(245, 245, 245) }, decoF)
			deco({ Name = "Mast", Size = Vector3.new(0.6, 16, 0.6), CFrame = cf * CFrame.new(0, 9, -4), Color = Color3.fromRGB(110, 80, 50) }, decoF)
		end
		-- lighthouse
		local lp = Vector3.new(b.x1 + 120, gy, cz)
		deco({ Name = "Rocks", Shape = Enum.PartType.Ball, Size = Vector3.new(60, 60, 60), Position = lp - UP * 20, Color = Color3.fromRGB(120, 116, 110), Material = Enum.Material.Slate }, decoF)
		for n = 0, 5 do
			deco({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 14 - n, 14 - n), CFrame = CFrame.new(lp + UP * (12 + n * 10)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = (n % 2 == 0) and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(220, 50, 45) }, decoF)
		end
		local lamp = deco({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = lp + UP * 72, Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon }, decoF)
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Brightness = 3
		pl.Parent = lamp
	end

	-- ---------- extra theme detail close to the road ----------
	if def.theme == "coast" then
		for _, sp in ipairs(nearSpot(14, 95, 22)) do palm(sp.pos.X, sp.pos.Z, gy) end
		for k, sp in ipairs(nearSpot(10, 160, 30)) do
			deco({ Name = "Surfboard", Size = Vector3.new(0.4, 7, 2), CFrame = CFrame.new(sp.pos + UP * 3) * CFrame.Angles(0.15, k, 0.1),
				Color = ({ Color3.fromRGB(255, 120, 60), Color3.fromRGB(60, 200, 230), Color3.fromRGB(255, 230, 80) })[(k % 3) + 1] }, decoF)
		end
		for k, sp in ipairs(nearSpot(3, 400, 40)) do
			local cf = CFrame.lookAt(Vector3.new(sp.pos.X, gy, sp.pos.Z), Vector3.new(P[sp.i].X, gy, P[sp.i].Z))
			deco({ Name = "Hut", Size = Vector3.new(12, 8, 10), CFrame = cf * CFrame.new(0, 4, 0), Color = Color3.fromRGB(240, 220, 170), Material = Enum.Material.WoodPlanks }, decoF)
			deco({ Name = "HutRoof", Size = Vector3.new(14, 1.5, 12), CFrame = cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0.1, 0, 0), Color = Color3.fromRGB(200, 60, 50) }, decoF)
			deco({ Name = "HutSign", Size = Vector3.new(8, 2, 0.3), CFrame = cf * CFrame.new(0, 6, -5.2), Color = Color3.fromRGB(40, 140, 230) }, decoF)
		end
	elseif def.theme == "city" then
		local carCols = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 90, 200), Color3.fromRGB(230, 230, 230), Color3.fromRGB(30, 30, 34), Color3.fromRGB(240, 200, 40) }
		for k, sp in ipairs(nearSpot(14, 100, 14)) do
			local cf = CFrame.lookAt(sp.pos, sp.pos + T[sp.i])
			deco({ Name = "ParkedCar", Size = Vector3.new(6, 2, 13), CFrame = cf * CFrame.new(0, 1.6, 0), Color = carCols[(k % #carCols) + 1] }, decoF)
			deco({ Name = "ParkedRoof", Size = Vector3.new(5.4, 1.6, 6), CFrame = cf * CFrame.new(0, 3.4, 0.6), Color = Color3.fromRGB(30, 36, 48), Material = Enum.Material.Glass }, decoF)
			for _, wz in ipairs({ -4.2, 4.2 }) do
				for _, wx in ipairs({ -3, 3 }) do
					deco({ Name = "ParkedWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.2, 2.2), CFrame = cf * CFrame.new(wx, 1.1, wz), Color = Color3.fromRGB(20, 20, 22) }, decoF)
				end
			end
		end
		for _, sp in ipairs(nearSpot(10, 140, 9)) do
			deco({ Name = "Hydrant", Size = Vector3.new(1, 2.2, 1), Position = sp.pos + UP * 1.1, Color = Color3.fromRGB(220, 40, 40) }, decoF)
			deco({ Name = "HydrantCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Position = sp.pos + UP * 2.3, Color = Color3.fromRGB(220, 40, 40) }, decoF)
		end
		-- zebra crossing after the start line
		local zi = wrap(30, N)
		for n = -5, 5 do
			deco({ Name = "Crossing", Size = Vector3.new(2.5, 0.05, 7), CFrame = CFrame.lookAt(P[zi] + S[zi] * (n * 5) + UP * 0.03, P[zi] + S[zi] * (n * 5) + UP * 0.03 + T[zi]), Color = Color3.fromRGB(240, 240, 240), CastShadow = false }, roadF)
		end
	elseif def.theme == "frost" then
		for _, sp in ipairs(nearSpot(24, 60, 8)) do
			local r = 5 + (sp.i % 4)
			deco({ Name = "SnowPile", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 1.6, r, r * 1.6), Position = sp.pos, Color = Color3.fromRGB(245, 248, 252), Material = Enum.Material.Snow }, decoF)
		end
		for k, sp in ipairs(nearSpot(12, 120, 26)) do
			local sc = 1.2
			local root = CFrame.new(sp.pos.X, gy, sp.pos.Z)
			deco({ Name = "Trunk", Size = Vector3.new(1.5, 5, 1.5) * sc, CFrame = root * CFrame.new(0, 2.5 * sc, 0), Color = Color3.fromRGB(90, 62, 43), Material = Enum.Material.Wood }, decoF)
			for tt = 0, 2 do
				local w = (12 - tt * 3.4) * sc
				deco({ Name = "Pine", Size = Vector3.new(w, 4.5 * sc, w), CFrame = root * CFrame.new(0, (5 + tt * 4) * sc, 0) * CFrame.Angles(0, math.rad(45 * tt + k), 0), Color = Color3.fromRGB(31, 77, 58), Material = Enum.Material.Grass }, decoF)
			end
		end
	elseif def.theme == "lava" then
		for _, f in ipairs({ 0.2, 0.75 }) do
			local i = safeIndex(TrackMath.straightIndex(tr, f, 20))
			local cf = CFrame.lookAt(P[i], P[i] + T[i])
			for _, sd in ipairs({ -1, 1 }) do
				part({ Name = "RockArch", Size = Vector3.new(10, 40, 10), CFrame = cf * CFrame.new(sd * (HALF + 8), 20, 0) * CFrame.Angles(0, 0, sd * 0.08), Color = Color3.fromRGB(52, 36, 32), Material = Enum.Material.Basalt }, dressF)
			end
			deco({ Name = "RockArchTop", Size = Vector3.new(HALF * 2 + 30, 10, 12), CFrame = cf * CFrame.new(0, 42, 0), Color = Color3.fromRGB(48, 34, 30), Material = Enum.Material.Basalt }, dressF)
			deco({ Name = "LavaDrip", Size = Vector3.new(2, 14, 2), CFrame = cf * CFrame.new(6, 31, 0), Color = Color3.fromRGB(255, 110, 20), Material = Enum.Material.Neon, CastShadow = false }, dressF)
		end
		for _, sp in ipairs(nearSpot(6, 250, 34)) do
			local pool = deco({ Name = "SmokePool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16, 16), CFrame = CFrame.new(sp.pos + UP * 0.1) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 90, 18), Material = Enum.Material.Neon, CastShadow = false }, decoF)
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(70, 60, 60)
			smoke.Opacity = 0.25
			smoke.RiseVelocity = 6
			smoke.Size = 6
			smoke.Parent = pool
		end
	elseif water then
		for _, sp in ipairs(nearSpot(16, 90, 1.2)) do
			deco({ Name = "Lifebuoy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.8, 2.8), CFrame = CFrame.lookAt(sp.pos + UP * 3.4, sp.pos + UP * 3.4 + S[sp.i]) * CFrame.Angles(0, math.pi / 2, 0),
				Color = Color3.fromRGB(255, 110, 30) }, decoF)
		end
		for k, sp in ipairs(nearSpot(5, 300, 60)) do
			deco({ Name = "Raft", Size = Vector3.new(14, 1, 14), Position = Vector3.new(sp.pos.X, gy + 0.3, sp.pos.Z), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks }, decoF)
			deco({ Name = "RaftFlag", Size = Vector3.new(0.3, 8, 0.3), Position = Vector3.new(sp.pos.X, gy + 4.5, sp.pos.Z), Color = Color3.fromRGB(240, 240, 240) }, decoF)
			deco({ Name = "RaftCloth", Size = Vector3.new(0.1, 2.4, 3.4), Position = Vector3.new(sp.pos.X, gy + 7.5, sp.pos.Z + 1.7), Color = flagCols[(k % #flagCols) + 1], Material = Enum.Material.Fabric }, decoF)
		end
	elseif def.theme == "jungle" then
		for _, f in ipairs({ 0.15, 0.5 }) do
			local i = safeIndex(TrackMath.straightIndex(tr, f, 20))
			local cf = CFrame.lookAt(P[i], P[i] + T[i])
			deco({ Name = "CanopyBranch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(HALF * 2 + 20, 3, 3), CFrame = cf * CFrame.new(0, 30, 0), Color = Color3.fromRGB(96, 70, 44), Material = Enum.Material.Wood }, dressF)
			for v = -HALF, HALF, 3.5 do
				deco({ Name = "HangingVine", Size = Vector3.new(0.4, 4 + (math.abs(v) * 1.7) % 6, 0.4), CFrame = cf * CFrame.new(v, 27, (v * 3) % 2 - 1), Color = Color3.fromRGB(50, 130, 40), Material = Enum.Material.Grass, CastShadow = false }, dressF)
			end
		end
		for _, sp in ipairs(nearSpot(14, 110, 10)) do
			for n = 0, 2 do
				deco({ Name = "Mushroom", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4 - n * 0.5, 1.2, 2.4 - n * 0.5), Position = sp.pos + Vector3.new(n * 1.5, 1.4 - n * 0.3, n), Color = Color3.fromRGB(220, 60, 50) }, decoF)
				deco({ Name = "MushroomStem", Size = Vector3.new(0.5, 1.4 - n * 0.3, 0.5), Position = sp.pos + Vector3.new(n * 1.5, 0.7 - n * 0.15, n), Color = Color3.fromRGB(240, 230, 210) }, decoF)
			end
		end
	end

	return { folder = folder, pads = pads, padInfo = padInfo, boxes = boxes, cannons = cannons, obstacles = obstacles, startLights = startLights, groundY = groundY }
end

return TrackBuilder
