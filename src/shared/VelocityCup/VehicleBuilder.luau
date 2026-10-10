-- VehicleBuilder: builds every vehicle type out of plain parts (no uploaded models),
-- then applies the driver's skin and trail. Used by the server for racing and by
-- the player's screen for the 3D preview in the garage and shop.
--
-- The invisible "Body" part is the only part with physics; everything you see is
-- welded onto it. Parts that take the skin are marked with the "Paint" attribute.

local Config = require(script.Parent:WaitForChild("RaceConfig"))

local VB = {}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function mat(name)
	local ok, m = pcall(function() return Enum.Material[name] end)
	return ok and m or Enum.Material.SmoothPlastic
end

-- hitbox size, ride height (body centre above ground), seat or stand point
VB.TYPES = {
	car        = { size = Vector3.new(5.1, 1.2, 11.25), ride = 1.35 },
	kart       = { size = Vector3.new(4.4, 0.7, 7.2),   ride = 0.95 },
	bicycle    = { size = Vector3.new(1.6, 1.6, 6),     ride = 1.9, twoWheel = true },
	motorcycle = { size = Vector3.new(2, 1.6, 8),       ride = 1.9, twoWheel = true },
	truck      = { size = Vector3.new(6, 2.6, 15),      ride = 2.3 },
	monster    = { size = Vector3.new(6.6, 2.2, 12),    ride = 4.6 },
	skateboard = { size = Vector3.new(2.2, 0.5, 5.6),   ride = 0.85, stand = true },
	atv        = { size = Vector3.new(4.4, 1.4, 7),     ride = 1.7 },
}

local DARK = Color3.fromRGB(22, 23, 27)
local TIRE = Color3.fromRGB(17, 18, 20)
local RIM = Color3.fromRGB(185, 189, 196)
local GLASS = Color3.fromRGB(20, 26, 36)
local HEAD = Color3.fromRGB(255, 246, 214)
local TAIL = Color3.fromRGB(255, 26, 26)

-- everything except the skateboard is built bigger than the base measurements
function VB.scaleOf(vdef)
	if vdef.type == "skateboard" then return 1 end
	return Config.VEHICLE_SCALE or 1
end
function VB.rideOf(vdef)
	return (VB.TYPES[vdef.type] or VB.TYPES.car).ride * VB.scaleOf(vdef)
end

function VB.build(vdef, cframe, driverName, parent, opts)
	opts = opts or {}
	local t = VB.TYPES[vdef.type] or VB.TYPES.car
	local SC = VB.scaleOf(vdef)
	-- all the numbers below are in base units; scaled(...) turns them into real studs
	local function scaled(cf) return (cf - cf.Position) + cf.Position * SC end
	local size = t.size
	local L, Wd = size.Z, size.X
	local G = -t.ride -- ground level relative to the body centre

	local model = Instance.new("Model")
	model.Name = "Vehicle_" .. driverName
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size * SC
	body.Transparency = 1
	body.CustomPhysicalProperties = PhysicalProperties.new(0.7 * (vdef.weight or 1), 0, 0.2, 100, 1)
	body.CFrame = cframe
	body.Anchored = true
	body.RootPriority = 10
	if not opts.preview then body.CollisionGroup = "VCCars" end
	body.Parent = model
	model.PrimaryPart = body

	local paint, accent = rgb(vdef.color), rgb(vdef.accent)

	local function add(name, sz, offset, color, material, shape, transparency, isPaint)
		local p = Instance.new("Part")
		p.Name = name
		if shape then p.Shape = shape end
		p.Size = sz * SC
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Transparency = transparency or 0
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = cframe * scaled(offset)
		if isPaint then
			p:SetAttribute("Paint", true)
			p.Reflectance = 0.12
		end
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
		return p
	end
	local function P(name, sz, offset) return add(name, sz, offset, paint, nil, nil, nil, true) end
	local function A(name, sz, offset) return add(name, sz, offset, accent) end
	local function D(name, sz, offset) return add(name, sz, offset, DARK) end
	-- a thin bar between two points (bike frames, forks, roll bars)
	local function bar(name, a, b, thick, color, isPaint)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		return add(name, Vector3.new(thick, thick, len), cf, color, Enum.Material.Metal, nil, nil, isPaint)
	end
	local function wheel(x, z, radius, width)
		local y = G + radius
		local vt = vdef.type
		add("Tire", Vector3.new(width, radius * 2, radius * 2), CFrame.new(x, y, z), TIRE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		add("Rim", Vector3.new(width + 0.05, radius * 1.2, radius * 1.2), CFrame.new(x, y, z), RIM, Enum.Material.Metal, Enum.PartType.Cylinder)
		add("HubCap", Vector3.new(width + 0.1, radius * 0.38, radius * 0.38), CFrame.new(x, y, z), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- spokes on the outer face (both faces for bikes)
		local faces = (x == 0) and { -1, 1 } or { (x > 0) and 1 or -1 }
		for _, side in ipairs(faces) do
			for k = 0, 4 do
				add("Spoke", Vector3.new(0.06, radius * 0.5, 0.15), CFrame.new(x + side * (width / 2 + 0.04), y, z) * CFrame.Angles(k * math.pi * 2 / 5, 0, 0) * CFrame.new(0, radius * 0.33, 0), RIM, Enum.Material.Metal)
			end
		end
		if vt == "car" then
			local side = (x > 0) and 1 or -1
			add("Caliper", Vector3.new(0.16, radius * 0.45, radius * 0.32), CFrame.new(x - side * 0.05, y + radius * 0.32, z + radius * 0.22), Color3.fromRGB(210, 30, 30))
		end
		if vt == "monster" or vt == "atv" then
			-- chunky off-road tread blocks
			for k = 1, 12 do
				add("Tread", Vector3.new(width * 0.92, 0.32, radius * 0.38), CFrame.new(x, y, z) * CFrame.Angles(k * math.pi * 2 / 12, 0, 0) * CFrame.new(0, radius + 0.05, 0), TIRE)
			end
		end
	end
	local function plateText(part, text, face)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(120, 40)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(20, 20, 30)
		t.Text = text
		t.Parent = g
		g.Parent = part
	end
	local PLATE = Color3.fromRGB(240, 240, 232)
	local CHROME = Color3.fromRGB(215, 220, 228)
	local function lights(y, headX, tailX, frontZ, rearZ)
		for _, s in ipairs({ -1, 1 }) do
			add("HeadLight", Vector3.new(headX, 0.25, 0.1), CFrame.new(s * Wd * 0.3, y, frontZ), HEAD, Enum.Material.Neon)
			add("TailLight", Vector3.new(tailX, 0.22, 0.1), CFrame.new(s * Wd * 0.3, y + 0.1, rearZ), TAIL, Enum.Material.Neon)
		end
	end

	local seatCF, standCF
	local ty = vdef.type
	local h = 0 -- height of the top of the vehicle above body centre (for name tag and trail)

	if ty == "car" then
		P("Lower", Vector3.new(Wd, 1.2, L), CFrame.new())
		local cabZ = -(vdef.cabinZ or 0) * L
		local cabLen = vdef.cabinLen or 0.36
		P("Upper", Vector3.new(Wd * 0.98, 0.5, L * 0.72), CFrame.new(0, 0.85, L * 0.08))
		P("Hood", Vector3.new(Wd * 0.96, 0.35, L * 0.22), CFrame.new(0, 0.62, -L * 0.37) * CFrame.Angles(math.rad(-8 * (vdef.nose or 0.6)), 0, 0))
		add("Cabin", Vector3.new(Wd * 0.76, 1.0, L * cabLen), CFrame.new(0, 1.6, cabZ), GLASS, Enum.Material.Glass, nil, 0.35)
		P("Roof", Vector3.new(Wd * 0.72, 0.18, L * cabLen * 0.7), CFrame.new(0, 2.15, cabZ + 0.3))
		add("Windshield", Vector3.new(Wd * 0.74, 0.15, 1.9), CFrame.new(0, 1.55, cabZ - L * cabLen / 2 - 0.55) * CFrame.Angles(math.rad(38), 0, 0), GLASS, Enum.Material.Glass, nil, 0.3)
		add("RearGlass", Vector3.new(Wd * 0.72, 0.15, 1.6), CFrame.new(0, 1.5, cabZ + L * cabLen / 2 + 0.5) * CFrame.Angles(math.rad(-30), 0, 0), GLASS, Enum.Material.Glass, nil, 0.3)
		for _, s in ipairs({ -1, 1 }) do
			A("Skirt", Vector3.new(0.15, 0.35, L * 0.55), CFrame.new(s * (Wd / 2 + 0.05), -0.45, 0))
			if vdef.twoTone then add("TwoTone", Vector3.new(0.12, 0.8, L * 0.35), CFrame.new(s * (Wd / 2 + 0.06), 0.2, -L * 0.1), rgb(vdef.twoTone)) end
			for _, z in ipairs({ -L / 2 + 2.2, L / 2 - 2.1 }) do wheel(s * (Wd / 2 - 0.25), z, 1.05, 0.9) end
		end
		A("Splitter", Vector3.new(Wd * 0.9, 0.12, 0.6), CFrame.new(0, -0.55, -L / 2 - 0.1))
		local rearTop = 0.9
		if vdef.wing == "wing" then
			A("Wing", Vector3.new(Wd * 0.95, 0.15, 1.2), CFrame.new(0, 1.95, L / 2 - 0.7))
			for _, s in ipairs({ -1, 1 }) do A("WingPost", Vector3.new(0.2, 0.85, 0.3), CFrame.new(s * 1.3, 1.45, L / 2 - 0.7)) end
		elseif vdef.wing == "lip" then
			A("Lip", Vector3.new(Wd * 0.9, 0.2, 0.5), CFrame.new(0, rearTop + 0.3, L / 2 - 0.3))
		end
		lights(0.25, 1.1, 1.2, -L / 2 - 0.03, L / 2 + 0.03)
		-- details: mirrors, door lines, handles, intakes, grille, plates, exhausts, diffuser, interior
		local front = cabZ - L * cabLen / 2
		for _, s in ipairs({ -1, 1 }) do
			P("Mirror", Vector3.new(0.45, 0.32, 0.6), CFrame.new(s * (Wd * 0.41 + 0.45), 1.45, front + 0.35))
			D("MirrorStalk", Vector3.new(0.45, 0.08, 0.12), CFrame.new(s * (Wd * 0.39 + 0.1), 1.38, front + 0.4))
			D("DoorLine", Vector3.new(0.04, 0.85, 0.06), CFrame.new(s * (Wd / 2 + 0.01), 0.3, front))
			D("DoorLine", Vector3.new(0.04, 0.85, 0.06), CFrame.new(s * (Wd / 2 + 0.01), 0.3, cabZ + L * cabLen / 2))
			add("Handle", Vector3.new(0.06, 0.1, 0.45), CFrame.new(s * (Wd / 2 + 0.03), 0.55, cabZ + 0.4), CHROME, Enum.Material.Metal)
			D("Intake", Vector3.new(0.06, 0.45, 1.3), CFrame.new(s * (Wd / 2 + 0.02), 0.2, cabZ + L * cabLen / 2 + 0.95))
			add("ExhaustTip", Vector3.new(0.45, 0.36, 0.36), CFrame.new(s * 0.75, -0.35, L / 2 + 0.12) * CFrame.Angles(0, math.pi / 2, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
			D("LampHousing", Vector3.new(1.3, 0.36, 0.06), CFrame.new(s * Wd * 0.3, 0.25, -L / 2 - 0.005))
			D("WheelArch", Vector3.new(0.12, 0.25, 2.5), CFrame.new(s * (Wd / 2 + 0.04), 0.48, -L / 2 + 2.2))
			D("WheelArch", Vector3.new(0.12, 0.25, 2.5), CFrame.new(s * (Wd / 2 + 0.04), 0.48, L / 2 - 2.1))
		end
		D("Grille", Vector3.new(Wd * 0.5, 0.42, 0.08), CFrame.new(0, -0.15, -L / 2 - 0.02))
		for n = -1, 1 do add("Slat", Vector3.new(Wd * 0.48, 0.05, 0.06), CFrame.new(0, -0.15 + n * 0.13, -L / 2 - 0.07), CHROME, Enum.Material.Metal) end
		local rp = add("Plate", Vector3.new(1.3, 0.38, 0.05), CFrame.new(0, -0.08, L / 2 + 0.04), PLATE)
		plateText(rp, "VC " .. string.upper(string.sub(vdef.id, 1, 3)), Enum.NormalId.Back)
		add("Plate", Vector3.new(1.3, 0.34, 0.05), CFrame.new(0, -0.46, -L / 2 - 0.12), PLATE)
		for n = -2, 2 do D("Fin", Vector3.new(0.06, 0.32, 0.55), CFrame.new(n * 0.55, -0.5, L / 2 - 0.15)) end
		D("SeatBack", Vector3.new(1.5, 1.0, 0.3), CFrame.new(0, 1.25, cabZ + 1.35))
		D("Dash", Vector3.new(Wd * 0.7, 0.25, 0.6), CFrame.new(0, 1.2, front + 0.5))
		add("SteeringWheel", Vector3.new(0.08, 0.75, 0.75), CFrame.new(0, 1.42, front + 0.95) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(-35)), DARK, nil, Enum.PartType.Cylinder)
		if vdef.wing == "wing" then A("RoofScoop", Vector3.new(0.8, 0.3, 1.1), CFrame.new(0, 2.3, cabZ + 0.7)) end
		-- extra trim: window frames, hood vents, fog lamps, lip, antenna, brake light
		for _, s in ipairs({ -1, 1 }) do
			D("WindowFrame", Vector3.new(0.08, 0.1, L * cabLen), CFrame.new(s * Wd * 0.38, 2.1, cabZ))
			D("Pillar", Vector3.new(0.1, 1.0, 0.12), CFrame.new(s * Wd * 0.37, 1.6, front + 0.05))
			D("HoodVent", Vector3.new(0.5, 0.05, 1.0), CFrame.new(s * 0.7, 0.82, -L * 0.33))
			add("FogLamp", Vector3.new(0.35, 0.35, 0.1), CFrame.new(s * Wd * 0.38, -0.35, -L / 2 - 0.1), Color3.fromRGB(255, 240, 190), Enum.Material.Neon, Enum.PartType.Ball)
			if vdef.wing == "wing" then A("Endplate", Vector3.new(0.12, 0.6, 1.3), CFrame.new(s * Wd * 0.48, 1.85, L / 2 - 0.7)) end
		end
		A("FrontLip", Vector3.new(Wd * 0.95, 0.08, 0.3), CFrame.new(0, -0.62, -L / 2 - 0.3))
		add("BrakeLight", Vector3.new(1.2, 0.1, 0.1), CFrame.new(0, 1.95, cabZ + L * cabLen / 2 + 0.85), TAIL, Enum.Material.Neon)
		add("TailBar", Vector3.new(Wd * 0.35, 0.08, 0.06), CFrame.new(0, 0.5, L / 2 + 0.04), TAIL, Enum.Material.Neon)
		D("Antenna", Vector3.new(0.05, 0.9, 0.05), CFrame.new(Wd * 0.25, 2.6, cabZ + 0.9))
		if vdef.style == "stealth" then
			-- Nightshade X: faceted armour panels, glowing accent lines, quad exhaust, underglow
			local GLOW = vdef.glow and rgb(vdef.glow) or accent
			local ARMOR = Color3.fromRGB(46, 48, 58)
			for _, s in ipairs({ -1, 1 }) do
				-- angled side armour over the doors and sharp front fenders
				P("SideArmor", Vector3.new(0.2, 0.75, L * 0.5), CFrame.new(s * (Wd / 2 + 0.12), 0.35, 0.1) * CFrame.Angles(0, 0, s * math.rad(12)))
				P("Fender", Vector3.new(0.9, 0.35, 2.6), CFrame.new(s * (Wd / 2 - 0.35), 0.95, -L / 2 + 2.2) * CFrame.Angles(math.rad(-6), 0, s * math.rad(-14)))
				P("Fender", Vector3.new(0.9, 0.4, 2.6), CFrame.new(s * (Wd / 2 - 0.35), 1.0, L / 2 - 2.1) * CFrame.Angles(math.rad(5), 0, s * math.rad(-14)))
				add("GlowLine", Vector3.new(0.08, 0.1, L * 0.8), CFrame.new(s * (Wd / 2 + 0.24), -0.05, 0), GLOW, Enum.Material.Neon)
				add("HoodGlow", Vector3.new(0.1, 0.06, L * 0.24), CFrame.new(s * 0.45, 0.86, -L * 0.36) * CFrame.Angles(math.rad(-8), s * math.rad(8), 0), GLOW, Enum.Material.Neon)
				add("EyeLight", Vector3.new(1.0, 0.1, 0.1), CFrame.new(s * Wd * 0.3, 0.48, -L / 2 - 0.06) * CFrame.Angles(0, 0, s * math.rad(-10)), GLOW, Enum.Material.Neon)
				add("ArmorPlate", Vector3.new(0.5, 0.06, 1.6), CFrame.new(s * 1.1, 2.24, cabZ + 0.2), ARMOR, Enum.Material.DiamondPlate)
				for k = 0, 1 do
					add("QuadExhaust", Vector3.new(0.5, 0.3, 0.3), CFrame.new(s * (0.45 + k * 0.45), -0.32, L / 2 + 0.15) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
					add("ExhaustGlow", Vector3.new(0.06, 0.2, 0.2), CFrame.new(s * (0.45 + k * 0.45), -0.32, L / 2 + 0.4) * CFrame.Angles(0, math.pi / 2, 0), GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
				end
				add("WingGlow", Vector3.new(0.14, 0.62, 0.14), CFrame.new(s * Wd * 0.48, 1.85, L / 2 - 1.35), GLOW, Enum.Material.Neon)
			end
			add("ArmorBumper", Vector3.new(Wd * 1.02, 0.5, 0.5), CFrame.new(0, -0.3, -L / 2 - 0.35) * CFrame.Angles(math.rad(-20), 0, 0), ARMOR, Enum.Material.DiamondPlate)
			add("NoseBlade", Vector3.new(Wd * 0.5, 0.14, 1.4), CFrame.new(0, 0.78, -L / 2 + 0.6) * CFrame.Angles(math.rad(-12), 0, 0), ARMOR, Enum.Material.Metal)
			add("RoofIntake", Vector3.new(0.9, 0.4, 1.5), CFrame.new(0, 2.35, cabZ + 0.9), ARMOR, Enum.Material.Metal)
			add("IntakeGlow", Vector3.new(0.6, 0.18, 0.06), CFrame.new(0, 2.35, cabZ + 0.13), GLOW, Enum.Material.Neon)
			add("Diffuser", Vector3.new(Wd * 0.85, 0.3, 0.9), CFrame.new(0, -0.6, L / 2 - 0.2) * CFrame.Angles(math.rad(14), 0, 0), DARK, Enum.Material.Metal)
			add("RearGlowBar", Vector3.new(Wd * 0.8, 0.1, 0.06), CFrame.new(0, 0.62, L / 2 + 0.05), GLOW, Enum.Material.Neon)
			local under = add("Underglow", Vector3.new(Wd * 0.8, 0.06, L * 0.75), CFrame.new(0, -0.66, 0), GLOW, Enum.Material.Neon, nil, 0.35)
			local ul = Instance.new("PointLight")
			ul.Color = GLOW
			ul.Range = 14
			ul.Brightness = 1.6
			ul.Parent = under
		end
		seatCF = CFrame.new(0, 0.75, cabZ + 0.6)
		h = 2.3
	elseif ty == "kart" then
		D("Floor", Vector3.new(Wd * 0.8, 0.25, L), CFrame.new(0, -0.55, 0))
		for _, s in ipairs({ -1, 1 }) do P("SidePod", Vector3.new(0.8, 0.55, L * 0.5), CFrame.new(s * (Wd / 2 - 0.5), -0.3, 0.3)) end
		P("Nose", Vector3.new(Wd * 0.55, 0.45, 1.8), CFrame.new(0, -0.32, -L / 2 + 0.9) * CFrame.Angles(math.rad(-6), 0, 0))
		A("Bumper", Vector3.new(Wd * 0.9, 0.3, 0.4), CFrame.new(0, -0.6, -L / 2))
		A("SeatBack", Vector3.new(1.6, 1.2, 0.4), CFrame.new(0, 0.2, 1.6))
		add("Wheel", Vector3.new(0.12, 1.0, 1.0), CFrame.new(0, 0.55, -0.7) * CFrame.Angles(math.rad(60), 0, math.pi / 2), DARK, nil, Enum.PartType.Cylinder)
		add("Engine", Vector3.new(1.6, 0.9, 1.2), CFrame.new(0, -0.15, L / 2 - 1.1), Color3.fromRGB(120, 124, 130), Enum.Material.Metal)
		for _, s in ipairs({ -1, 1 }) do
			add("Pipe", Vector3.new(1.0, 0.3, 0.3), CFrame.new(s * 0.45, 0.25, L / 2 - 0.3) * CFrame.Angles(0, math.pi / 2, 0), RIM, Enum.Material.Metal, Enum.PartType.Cylinder)
			A("WingPost", Vector3.new(0.15, 0.8, 0.2), CFrame.new(s * 1.2, 0.35, L / 2 - 0.4))
			for _, z in ipairs({ -L / 2 + 1.1, L / 2 - 1.1 }) do wheel(s * (Wd / 2), z, 0.62, z > 0 and 1.15 or 0.9) end
		end
		P("Wing", Vector3.new(Wd * 0.85, 0.15, 0.8), CFrame.new(0, 0.8, L / 2 - 0.4))
		lights(-0.3, 0.6, 0.6, -L / 2 - 0.25, L / 2 + 0.05)
		local np = add("NumberPlate", Vector3.new(1.5, 0.9, 0.1), CFrame.new(0, 0.05, -L / 2 + 0.55) * CFrame.Angles(math.rad(-35), 0, 0), PLATE)
		plateText(np, tostring((#vdef.id * 7) % 90 + 10), Enum.NormalId.Front)
		for _, s in ipairs({ -1, 1 }) do
			bar("Nerf", Vector3.new(s * (Wd / 2 + 0.05), -0.45, -1.6), Vector3.new(s * (Wd / 2 + 0.05), -0.45, 1.6), 0.22, accent)
			bar("Brace", Vector3.new(s * 0.5, -0.4, -1.0), Vector3.new(s * 0.2, 0.45, -0.7), 0.12, DARK)
		end
		D("Headrest", Vector3.new(0.9, 0.5, 0.3), CFrame.new(0, 0.95, 1.65))
		add("Airbox", Vector3.new(0.9, 0.5, 0.5), CFrame.new(0.6, 0.25, L / 2 - 1.5), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
		for _, s in ipairs({ -1, 1 }) do
			A("Sticker", Vector3.new(0.05, 0.25, L * 0.4), CFrame.new(s * (Wd / 2 - 0.08), -0.15, 0.3))
		end
		bar("FrontBumperBar", Vector3.new(-Wd * 0.4, -0.55, -L / 2 - 0.2), Vector3.new(Wd * 0.4, -0.55, -L / 2 - 0.2), 0.18, CHROME)
		bar("RearBumperBar", Vector3.new(-Wd * 0.45, -0.4, L / 2 + 0.15), Vector3.new(Wd * 0.45, -0.4, L / 2 + 0.15), 0.18, CHROME)
		bar("Column", Vector3.new(0, -0.3, -1.5), Vector3.new(0, 0.5, -0.75), 0.12, DARK)
		seatCF = CFrame.new(0, -0.35, 0.9)
		h = 1.5
	elseif ty == "bicycle" then
		local r = 1.3
		for _, z in ipairs({ -2.0, 2.0 }) do wheel(0, z, r, 0.22) end
		local hub = G + r
		local crank = Vector3.new(0, hub + 0.1, 0.2)
		local head = Vector3.new(0, 0.9, -1.4)
		local seatP = Vector3.new(0, 0.8, 0.7)
		bar("TopTube", head, seatP, 0.28, paint, true)
		bar("DownTube", head, crank, 0.3, paint, true)
		bar("SeatTube", seatP, crank, 0.28, paint, true)
		bar("ChainStay", crank, Vector3.new(0, hub, 2.0), 0.2, paint, true)
		bar("SeatStay", seatP, Vector3.new(0, hub, 2.0), 0.2, paint, true)
		bar("Fork", Vector3.new(0, 1.3, -1.55), Vector3.new(0, hub, -2.0), 0.2, accent)
		add("Handlebar", Vector3.new(2.0, 0.18, 0.18), CFrame.new(0, 1.35, -1.6), accent, Enum.Material.Metal)
		D("Saddle", Vector3.new(0.5, 0.2, 0.9), CFrame.new(0, 0.95, 0.75))
		add("Chainring", Vector3.new(0.12, 1.0, 1.0), CFrame.new(0.2, crank.Y, crank.Z), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		for _, s in ipairs({ -1, 1 }) do
			bar("Crank", Vector3.new(s * 0.3, crank.Y, crank.Z), Vector3.new(s * 0.35, crank.Y - s * 0.6, crank.Z + s * 0.3), 0.12, DARK)
			D("Pedal", Vector3.new(0.5, 0.1, 0.35), CFrame.new(s * 0.55, crank.Y - s * 0.6, crank.Z + s * 0.3))
			add("Grip", Vector3.new(0.35, 0.26, 0.26), CFrame.new(s * 1.0, 1.35, -1.6), DARK, nil, Enum.PartType.Cylinder)
		end
		bar("Chain", Vector3.new(0.25, crank.Y, crank.Z), Vector3.new(0.25, hub, 2.0), 0.08, DARK)
		add("RearReflector", Vector3.new(0.3, 0.2, 0.06), CFrame.new(0, 0.7, 1.3), TAIL, Enum.Material.Neon)
		add("FrontReflector", Vector3.new(0.3, 0.2, 0.06), CFrame.new(0, 1.15, -1.75), HEAD, Enum.Material.Neon)
		add("NumberBoard", Vector3.new(0.9, 0.7, 0.05), CFrame.new(0, 1.55, -1.7) * CFrame.Angles(math.rad(10), 0, 0), PLATE)
		seatCF = CFrame.new(0, 0.9, 0.6)
		h = 3.5
	elseif ty == "motorcycle" then
		local r = 1.25
		for _, z in ipairs({ -2.7, 2.7 }) do wheel(0, z, r, 0.6) end
		P("Fairing", Vector3.new(1.4, 1.1, 3.4), CFrame.new(0, -0.15, -0.3))
		P("Tank", Vector3.new(1.25, 0.6, 1.6), CFrame.new(0, 0.6, -0.6))
		P("Nose", Vector3.new(1.3, 0.9, 1.5), CFrame.new(0, 0.45, -2.05) * CFrame.Angles(math.rad(25), 0, 0))
		add("Screen", Vector3.new(1.1, 0.1, 0.9), CFrame.new(0, 1.05, -2.3) * CFrame.Angles(math.rad(50), 0, 0), GLASS, Enum.Material.Glass, nil, 0.3)
		D("Saddle", Vector3.new(1.0, 0.3, 1.9), CFrame.new(0, 0.6, 0.9))
		P("Tail", Vector3.new(0.9, 0.45, 1.5), CFrame.new(0, 0.65, 2.1) * CFrame.Angles(math.rad(-12), 0, 0))
		A("Belly", Vector3.new(1.0, 0.4, 2.2), CFrame.new(0, -0.85, 0))
		bar("Fork", Vector3.new(0, 1.1, -2.2), Vector3.new(0, G + r, -2.7), 0.25, RIM)
		add("Handlebar", Vector3.new(1.9, 0.16, 0.16), CFrame.new(0, 1.2, -1.75), DARK, Enum.Material.Metal)
		add("Exhaust", Vector3.new(1.8, 0.35, 0.35), CFrame.new(0.55, -0.3, 1.8) * CFrame.Angles(0, math.pi / 2, math.rad(-10)), RIM, Enum.Material.Metal, Enum.PartType.Cylinder)
		add("HeadLight", Vector3.new(0.6, 0.3, 0.1), CFrame.new(0, 0.55, -2.75), HEAD, Enum.Material.Neon)
		add("TailLight", Vector3.new(0.6, 0.2, 0.1), CFrame.new(0, 0.7, 2.85), TAIL, Enum.Material.Neon)
		for _, s in ipairs({ -1, 1 }) do
			bar("MirrorStalk", Vector3.new(s * 0.8, 1.2, -1.75), Vector3.new(s * 1.0, 1.65, -1.85), 0.08, DARK)
			P("Mirror", Vector3.new(0.4, 0.25, 0.1), CFrame.new(s * 1.05, 1.72, -1.86))
			add("Footpeg", Vector3.new(0.5, 0.1, 0.15), CFrame.new(s * 0.75, -0.55, 0.6), CHROME, Enum.Material.Metal)
		end
		add("BrakeDisc", Vector3.new(0.08, 1.4, 1.4), CFrame.new(0.38, G + 1.25, -2.7), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		bar("Chain", Vector3.new(-0.38, -0.55, 0.2), Vector3.new(-0.38, G + 1.25, 2.7), 0.1, DARK)
		P("RearFender", Vector3.new(0.7, 0.12, 1.4), CFrame.new(0, G + 2.65, 2.9) * CFrame.Angles(math.rad(-25), 0, 0))
		local mp = add("Plate", Vector3.new(0.8, 0.45, 0.05), CFrame.new(0, 0.3, 3.0) * CFrame.Angles(math.rad(-20), 0, 0), PLATE)
		plateText(mp, "V1000", Enum.NormalId.Back)
		D("Gauge", Vector3.new(0.6, 0.35, 0.2), CFrame.new(0, 1.3, -2.0) * CFrame.Angles(math.rad(30), 0, 0))
		for _, s in ipairs({ -1, 1 }) do
			bar("ForkTube", Vector3.new(s * 0.32, 1.0, -2.15), Vector3.new(s * 0.32, G + 1.25, -2.65), 0.18, CHROME)
			add("NumberBoard", Vector3.new(0.05, 0.6, 0.9), CFrame.new(s * 0.52, 0.55, 2.2), PLATE)
			A("Stripe", Vector3.new(0.05, 0.15, 3.0), CFrame.new(s * 0.71, 0.1, -0.3))
		end
		D("Radiator", Vector3.new(1.0, 0.7, 0.15), CFrame.new(0, -0.2, -1.95))
		seatCF = CFrame.new(0, 0.75, 0.7)
		h = 3.5
	elseif ty == "truck" then
		local cabZ = -L / 2 + 2.3
		P("Cab", Vector3.new(Wd, 3.2, 4.2), CFrame.new(0, 0.7, cabZ))
		add("Windshield", Vector3.new(Wd * 0.9, 1.3, 0.12), CFrame.new(0, 1.5, cabZ - 2.12), GLASS, Enum.Material.Glass, nil, 0.25)
		for _, s in ipairs({ -1, 1 }) do
			add("SideWindow", Vector3.new(0.12, 1.2, 1.8), CFrame.new(s * (Wd / 2 + 0.03), 1.5, cabZ - 0.7), GLASS, Enum.Material.Glass, nil, 0.25)
			add("Stack", Vector3.new(4.2, 0.45, 0.45), CFrame.new(s * (Wd / 2 - 0.4), 3.1, cabZ + 2.3) * CFrame.Angles(0, 0, math.pi / 2), RIM, Enum.Material.Metal, Enum.PartType.Cylinder)
			for _, z in ipairs({ -L / 2 + 2.4, L / 2 - 2.6, L / 2 - 5.4 }) do wheel(s * (Wd / 2 - 0.35), z, 1.4, 1.0) end
		end
		A("Grille", Vector3.new(Wd * 0.7, 1.2, 0.15), CFrame.new(0, -0.2, -L / 2 - 0.05))
		A("Bumper", Vector3.new(Wd * 1.02, 0.5, 0.5), CFrame.new(0, -0.95, -L / 2))
		D("Chassis", Vector3.new(Wd * 0.8, 0.6, L), CFrame.new(0, -1.1, 0))
		P("Cargo", Vector3.new(Wd, 4.2, 9.6), CFrame.new(0, 1.2, L / 2 - 4.8))
		A("CargoTrim", Vector3.new(Wd + 0.1, 0.35, 9.7), CFrame.new(0, -0.8, L / 2 - 4.8))
		lights(-0.4, 1.0, 0.9, -L / 2 - 0.1, L / 2 + 0.03)
		for n = -2, 2 do add("GrilleSlat", Vector3.new(Wd * 0.68, 0.1, 0.08), CFrame.new(0, -0.2 + n * 0.22, -L / 2 - 0.12), CHROME, Enum.Material.Metal) end
		add("ChromeBumper", Vector3.new(Wd * 1.04, 0.2, 0.55), CFrame.new(0, -0.62, -L / 2 - 0.02), CHROME, Enum.Material.Metal)
		for _, s in ipairs({ -1, 1 }) do
			add("FuelTank", Vector3.new(2.6, 1.1, 1.1), CFrame.new(s * (Wd / 2 - 0.2), -0.9, cabZ + 1.0) * CFrame.Angles(0, math.pi / 2, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
			bar("MirrorArm", Vector3.new(s * (Wd / 2), 1.6, cabZ - 1.6), Vector3.new(s * (Wd / 2 + 0.9), 1.9, cabZ - 1.7), 0.12, DARK)
			D("Mirror", Vector3.new(0.2, 1.2, 0.5), CFrame.new(s * (Wd / 2 + 0.95), 1.9, cabZ - 1.7))
			D("MudFlap", Vector3.new(1.1, 1.2, 0.08), CFrame.new(s * (Wd / 2 - 0.35), -1.2, L / 2 - 0.3))
			D("Step", Vector3.new(0.4, 0.15, 1.2), CFrame.new(s * (Wd / 2 + 0.1), -1.0, cabZ - 0.6))
		end
		for n = -1, 1 do add("Marker", Vector3.new(0.4, 0.2, 0.2), CFrame.new(n * 1.2, 2.4, cabZ - 2.05), Color3.fromRGB(255, 170, 30), Enum.Material.Neon) end
		local tp = add("Plate", Vector3.new(1.4, 0.4, 0.05), CFrame.new(0, -0.7, L / 2 + 0.04), PLATE)
		plateText(tp, "HAUL", Enum.NormalId.Back)
		P("RoofFairing", Vector3.new(Wd * 0.95, 1.2, 2.4), CFrame.new(0, 2.9, cabZ + 0.7) * CFrame.Angles(math.rad(-12), 0, 0))
		for _, s in ipairs({ -1, 1 }) do
			add("Horn", Vector3.new(1.4, 0.3, 0.3), CFrame.new(s * 0.6, 2.45, cabZ - 1.0) * CFrame.Angles(0, math.pi / 2, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
			for n = 0, 2 do add("RearLamp", Vector3.new(0.35, 0.35, 0.08), CFrame.new(s * (Wd / 2 - 0.4), -0.5 + n * 0.45, L / 2 + 0.05), TAIL, Enum.Material.Neon) end
			for n = 0, 3 do add("Reflector", Vector3.new(0.06, 0.2, 0.3), CFrame.new(s * (Wd / 2 + 0.03), -0.6, L / 2 - 1.5 - n * 2.4), Color3.fromRGB(255, 170, 30), Enum.Material.Neon) end
		end
		D("DoorSeam", Vector3.new(0.08, 3.9, 0.05), CFrame.new(0, 1.2, L / 2 + 0.03))
		add("DoorHandle", Vector3.new(0.12, 1.6, 0.1), CFrame.new(0.5, 1.0, L / 2 + 0.07), CHROME, Enum.Material.Metal)
		seatCF = CFrame.new(-0.9, 0.1, cabZ + 0.2)
		h = 3.6
	elseif ty == "monster" then
		local r = 2.6
		for _, s in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -3.8, 3.8 }) do
				wheel(s * (Wd / 2 + 0.5), z, r, 2.2)
				bar("Shock", Vector3.new(s * (Wd / 2 - 0.8), 0.2, z), Vector3.new(s * (Wd / 2 + 0.2), G + r, z), 0.45, accent)
			end
		end
		P("Lower", Vector3.new(Wd * 0.86, 1.5, L * 0.95), CFrame.new(0, 0.4, 0))
		P("Cab", Vector3.new(Wd * 0.8, 1.9, 4.0), CFrame.new(0, 2.1, -0.6))
		add("Windshield", Vector3.new(Wd * 0.72, 1.2, 0.12), CFrame.new(0, 2.3, -2.62), GLASS, Enum.Material.Glass, nil, 0.25)
		for _, s in ipairs({ -1, 1 }) do
			add("SideWindow", Vector3.new(0.12, 1.1, 2.6), CFrame.new(s * (Wd * 0.4 + 0.03), 2.3, -0.6), GLASS, Enum.Material.Glass, nil, 0.25)
			P("BedWall", Vector3.new(0.25, 0.9, 4.4), CFrame.new(s * (Wd * 0.43 - 0.1), 1.6, 3.4))
		end
		bar("RollBar", Vector3.new(-Wd * 0.38, 3.3, 1.6), Vector3.new(Wd * 0.38, 3.3, 1.6), 0.35, accent)
		add("LightBar", Vector3.new(Wd * 0.6, 0.3, 0.3), CFrame.new(0, 3.2, -1.2), HEAD, Enum.Material.Neon)
		A("FrontBumper", Vector3.new(Wd * 0.95, 0.6, 0.6), CFrame.new(0, -0.3, -L / 2))
		A("RearBumper", Vector3.new(Wd * 0.95, 0.6, 0.6), CFrame.new(0, -0.3, L / 2))
		lights(0.4, 0.9, 0.9, -L / 2 * 0.95 - 0.03, L / 2 * 0.95 + 0.03)
		for _, s in ipairs({ -1, 1 }) do
			bar("NerfBar", Vector3.new(s * (Wd * 0.45), -0.4, -2.0), Vector3.new(s * (Wd * 0.45), -0.4, 2.0), 0.3, CHROME)
			add("Stack", Vector3.new(2.2, 0.4, 0.4), CFrame.new(s * (Wd * 0.3), 3.0, 1.4) * CFrame.Angles(0, 0, math.pi / 2), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
			D("Mirror", Vector3.new(0.2, 0.5, 0.6), CFrame.new(s * (Wd * 0.42 + 0.3), 2.3, -2.4))
		end
		for n = -1.5, 1.5 do add("RoofLight", Vector3.new(0.45, 0.45, 0.3), CFrame.new(n * 0.9, 3.25, -1.36), HEAD, Enum.Material.Neon) end
		A("Hood", Vector3.new(Wd * 0.7, 0.2, 2.6), CFrame.new(0, 1.25, -4.0))
		add("SpareTire", Vector3.new(1.4, 3.2, 3.2), CFrame.new(0, 2.4, 3.4) * CFrame.Angles(0, 0, math.pi / 2), TIRE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for _, s in ipairs({ -1, 1 }) do
			bar("CageBar", Vector3.new(s * Wd * 0.38, 3.3, 1.6), Vector3.new(s * Wd * 0.38, 1.6, 4.9), 0.3, accent)
			A("SideStripe", Vector3.new(0.06, 0.3, L * 0.85), CFrame.new(s * (Wd * 0.43 + 0.02), 0.7, 0))
		end
		seatCF = CFrame.new(-0.9, 1.3, -0.5)
		h = 4
	elseif ty == "skateboard" then
		P("Deck", Vector3.new(2.0, 0.22, 4.4), CFrame.new(0, -0.2, 0))
		P("NoseKick", Vector3.new(2.0, 0.22, 0.8), CFrame.new(0, -0.08, -2.5) * CFrame.Angles(math.rad(18), 0, 0))
		P("TailKick", Vector3.new(2.0, 0.22, 0.8), CFrame.new(0, -0.08, 2.5) * CFrame.Angles(math.rad(-18), 0, 0))
		D("Grip", Vector3.new(1.9, 0.04, 4.3), CFrame.new(0, -0.07, 0))
		for _, z in ipairs({ -1.7, 1.7 }) do
			add("Truck", Vector3.new(1.6, 0.18, 0.4), CFrame.new(0, -0.4, z), RIM, Enum.Material.Metal)
			for _, s in ipairs({ -1, 1 }) do
				add("Wheel", Vector3.new(0.35, 0.6, 0.6), CFrame.new(s * 0.85, G + 0.3, z), accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			end
		end
		A("DeckStripe", Vector3.new(0.5, 0.03, 4.2), CFrame.new(0, -0.05, 0))
		for _, z in ipairs({ -1.7, 1.7 }) do
			for _, s in ipairs({ -1, 1 }) do D("Bolt", Vector3.new(0.12, 0.05, 0.12), CFrame.new(s * 0.35, -0.06, z)) end
		end
		standCF = CFrame.new(0, -0.09 + 3.0, 0.1) * CFrame.Angles(0, math.pi / 2, 0)
		h = 5
	elseif ty == "atv" then
		for _, s in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -2.4, 2.4 }) do wheel(s * (Wd / 2), z, 1.0, 1.2) end
		end
		P("Chassis", Vector3.new(2.4, 1.0, 4.4), CFrame.new(0, -0.1, 0))
		P("FrontFender", Vector3.new(Wd * 0.95, 0.4, 1.9), CFrame.new(0, 0.4, -2.3))
		P("RearFender", Vector3.new(Wd * 0.95, 0.4, 1.9), CFrame.new(0, 0.4, 2.3))
		D("Saddle", Vector3.new(1.2, 0.4, 2.0), CFrame.new(0, 0.6, 0.6))
		add("Handlebar", Vector3.new(2.4, 0.18, 0.18), CFrame.new(0, 1.25, -1.2), DARK, Enum.Material.Metal)
		bar("Steer", Vector3.new(0, 0.4, -1.0), Vector3.new(0, 1.25, -1.2), 0.25, DARK)
		A("FrontRack", Vector3.new(Wd * 0.7, 0.12, 1.2), CFrame.new(0, 0.75, -2.4))
		A("RearRack", Vector3.new(Wd * 0.7, 0.12, 1.4), CFrame.new(0, 0.75, 2.4))
		lights(0.35, 0.6, 0.5, -3.25, 3.25)
		add("HeadlightPod", Vector3.new(0.9, 0.45, 0.3), CFrame.new(0, 0.85, -3.1), HEAD, Enum.Material.Neon)
		add("Exhaust", Vector3.new(1.4, 0.32, 0.32), CFrame.new(0.9, 0.1, 2.9) * CFrame.Angles(0, math.pi / 2, math.rad(15)), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		for _, s in ipairs({ -1, 1 }) do
			D("Footrest", Vector3.new(0.9, 0.12, 1.4), CFrame.new(s * 1.45, -0.55, 0.4))
			bar("RackBar", Vector3.new(s * 1.4, 0.85, 1.7), Vector3.new(s * 1.4, 0.85, 3.1), 0.12, DARK)
			add("Grip", Vector3.new(0.35, 0.28, 0.28), CFrame.new(s * 1.25, 1.25, -1.2), DARK, nil, Enum.PartType.Cylinder)
		end
		local nb = add("NumberBoard", Vector3.new(1.2, 0.8, 0.06), CFrame.new(0, 0.55, -3.0) * CFrame.Angles(math.rad(-15), 0, 0), PLATE)
		plateText(nb, "4X4", Enum.NormalId.Front)
		add("Winch", Vector3.new(1.4, 0.45, 0.45), CFrame.new(0, -0.15, -3.05) * CFrame.Angles(0, 0, 0), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		for _, s in ipairs({ -1, 1 }) do
			D("MudGuard", Vector3.new(0.5, 0.6, 0.08), CFrame.new(s * 1.9, -0.1, 3.3))
		end
		seatCF = CFrame.new(0, 0.75, 0.6)
		h = 3.3
	end

	model:SetAttribute("VehicleId", vdef.id)
	model:SetAttribute("CarId", vdef.id)
	model:SetAttribute("CarName", vdef.name)
	model:SetAttribute("DriverName", driverName)
	model:SetAttribute("Ride", t.ride * SC)
	model:SetAttribute("Scale", SC)
	model:SetAttribute("TwoWheel", t.twoWheel == true)

	VB.applySkin(model, body, opts.skin or "factory")

	-- trail attachment points (always made so a trail can be added)
	local tb = Instance.new("Attachment")
	tb.Name = "TrailBottom"
	tb.Position = Vector3.new(0, G + 0.4, L / 2) * SC
	tb.Parent = body
	local tt = Instance.new("Attachment")
	tt.Name = "TrailTop"
	tt.Position = Vector3.new(0, G + 2.4, L / 2) * SC
	tt.Parent = body
	VB.applyTrail(model, body, opts.trail or "none")

	if opts.preview then
		body.Anchored = true
		model.Parent = parent
		return model, body, nil
	end

	local seat = nil
	if seatCF then
		seat = Instance.new("Seat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.CFrame = cframe * scaled(seatCF)
		seat.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = seat
		w.Parent = seat
	end
	if standCF then
		local sp = Instance.new("Attachment")
		sp.Name = "StandPoint"
		sp.CFrame = scaled(standCF)
		sp.Parent = body
	end

	-- physics helpers used by CarController
	local core = Instance.new("Attachment")
	core.Name = "Core"
	core.Parent = body
	local align = Instance.new("AlignOrientation")
	align.Name = "Align"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = core
	align.Responsiveness = 50
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.RigidityEnabled = false
	align.CFrame = cframe - cframe.Position
	align.Parent = body
	local lift = Instance.new("VectorForce")
	lift.Name = "Lift"
	lift.Attachment0 = core
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = Vector3.new()
	lift.Parent = body

	-- effects
	local exhaust = Instance.new("Attachment")
	exhaust.Name = "Exhaust"
	exhaust.Position = Vector3.new(0, G + 1.2, L / 2 + 0.4) * SC
	exhaust.Parent = body
	local fire = Instance.new("Fire")
	fire.Name = "BoostFire"
	fire.Size = 3
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 138, 42)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
	fire.Enabled = false
	fire.Parent = exhaust
	for _, s in ipairs({ -1, 1 }) do
		local a = Instance.new("Attachment")
		a.Name = s < 0 and "SparkPointL" or "SparkPointR"
		a.Position = Vector3.new(s * (Wd / 2), G + 0.25, L / 2 - 1) * SC
		a.Parent = body
		local pe = Instance.new("ParticleEmitter")
		pe.Name = s < 0 and "SparkL" or "SparkR"
		pe.Rate = 70
		pe.Lifetime = NumberRange.new(0.2, 0.4)
		pe.Speed = NumberRange.new(8, 16)
		pe.SpreadAngle = Vector2.new(35, 35)
		pe.EmissionDirection = Enum.NormalId.Back
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.5, 0)
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 242, 192))
		pe.Enabled = false
		pe.Parent = a
	end
	local sa = Instance.new("Attachment")
	sa.Name = "SplashPoint"
	sa.Position = Vector3.new(0, G + 0.2, 0) * SC
	sa.Parent = body
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Rate = 0
	splash.Lifetime = NumberRange.new(0.5, 0.9)
	splash.Speed = NumberRange.new(18, 34)
	splash.SpreadAngle = Vector2.new(60, 60)
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Acceleration = Vector3.new(0, -60, 0)
	splash.Size = NumberSequence.new(1.1, 0)
	splash.Transparency = NumberSequence.new(0.2, 1)
	splash.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
	splash.Parent = sa
	local stunA = Instance.new("Attachment")
	stunA.Name = "StunPoint"
	stunA.Position = Vector3.new(0, h + 1.5, 0) * SC
	stunA.Parent = body
	local stars = Instance.new("ParticleEmitter")
	stars.Name = "StunStars"
	stars.Rate = 12
	stars.Lifetime = NumberRange.new(0.6, 0.9)
	stars.Speed = NumberRange.new(3, 5)
	stars.SpreadAngle = Vector2.new(180, 20)
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(0.7, 0)
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80))
	stars.Enabled = false
	stars.Parent = stunA

	-- floating name tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	-- sized in studs (not pixels) so it shrinks with distance instead of
	-- covering the road; small, a bit see-through, and hidden past 110 studs
	tag.Size = UDim2.fromScale(4.5, 0.75)
	tag.StudsOffset = Vector3.new(0, h * SC + 1.6, 0)
	tag.MaxDistance = 110
	tag.AlwaysOnTop = false
	tag.LightInfluence = 0
	tag.Adornee = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.15
	label.TextStrokeTransparency = 0.55
	label.Text = driverName
	label.Parent = tag
	tag.Parent = body

	model.Parent = parent
	return model, body, seat
end

-- recolors every "Paint" part. Skins come from Config.SKINS.
function VB.applySkin(model, body, skinId)
	local skin = Config.getSkin(skinId)
	if not skin or skin.id == "factory" then return end
	local biggest, bigVol = nil, 0
	local paints = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Paint") then paints[#paints + 1] = p end
	end
	for _, p in ipairs(paints) do
		p.Color = rgb(skin.color)
		p.Material = mat(skin.material or "SmoothPlastic")
		p.Reflectance = skin.reflectance or 0
		if skin.transparency then p.Transparency = skin.transparency end
		local vol = p.Size.X * p.Size.Y * p.Size.Z
		if vol > bigVol then bigVol = vol; biggest = p end
		if skin.camo then
			-- scatter camo blotches over the top and sides
			local rnd = Random.new(#p.Name * 31 + math.floor(vol * 10))
			local sz = p.Size
			local count = math.clamp(math.floor((sz.X * sz.Z + sz.Y * sz.Z) / 3), 2, 14)
			for k = 1, count do
				local col = rgb(skin.camo[rnd:NextInteger(1, #skin.camo)])
				local face = rnd:NextInteger(1, 3)
				local off, psz
				local bz = math.min(sz.Z * 0.95, rnd:NextNumber(0.25, 0.45) * sz.Z + 0.4)
				if face == 1 then
					local bx = math.min(sz.X * 0.95, rnd:NextNumber(0.25, 0.5) * sz.X + 0.3)
					psz = Vector3.new(bx, 0.05, bz)
					off = CFrame.new(rnd:NextNumber(-1, 1) * (sz.X - bx) / 2, sz.Y / 2 + 0.02, rnd:NextNumber(-1, 1) * (sz.Z - bz) / 2)
				else
					local by = math.min(sz.Y * 0.95, rnd:NextNumber(0.4, 0.8) * sz.Y)
					local sgn = face == 2 and 1 or -1
					psz = Vector3.new(0.05, by, bz)
					off = CFrame.new(sgn * (sz.X / 2 + 0.02), rnd:NextNumber(-1, 1) * (sz.Y - by) / 2, rnd:NextNumber(-1, 1) * (sz.Z - bz) / 2)
				end
				local b = Instance.new("Part")
				b.Name = "Camo"
				b.Size = psz
				b.Color = col
				b.Material = Enum.Material.Fabric
				b.CanCollide = false
				b.CanQuery = false
				b.CanTouch = false
				b.Massless = true
				b.CFrame = p.CFrame * off
				b.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = b
				w.Parent = b
			end
		end
	end
	-- patterned skins: tiles welded onto the largest painted panels
	local function weldPiece(name, size, cf, color, material, refl)
		local t = Instance.new("Part")
		t.Name = name
		t.Size = size
		t.Color = color
		t.Material = material
		t.Reflectance = refl or 0
		t.CanCollide = false
		t.CanQuery = false
		t.CanTouch = false
		t.Massless = true
		t.CastShadow = false
		t.CFrame = cf
		t.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = t
		w.Parent = t
	end
	table.sort(paints, function(x, y) return x.Size.X * x.Size.Y * x.Size.Z > y.Size.X * y.Size.Y * y.Size.Z end)
	if skin.pattern == "scales" or skin.pattern == "facets" then
		local tileSize = (skin.pattern == "scales") and 0.5 or 0.75
		local gapSize = (skin.pattern == "scales") and 0.7 or 1.0
		local tmat = (skin.pattern == "scales") and Enum.Material.Slate or Enum.Material.Glass
		local refl = (skin.pattern == "scales") and 0 or 0.9
		local n = 0
		for pi = 1, math.min(2, #paints) do
			local p = paints[pi]
			local sz = p.Size
			local count = 0
			-- top face
			for ix = -sz.X / 2 + gapSize / 2, sz.X / 2 - gapSize / 2, gapSize do
				for iz = -sz.Z / 2 + gapSize / 2, sz.Z / 2 - gapSize / 2, gapSize do
					if count < 40 then
						count = count + 1
						n = n + 1
						weldPiece("Tile", Vector3.new(tileSize, 0.04, tileSize), p.CFrame * CFrame.new(ix, sz.Y / 2 + 0.02, iz) * CFrame.Angles(0, math.rad(45), 0),
							rgb(skin.tiles[(n % #skin.tiles) + 1]), tmat, refl)
					end
				end
			end
			-- side faces
			for _, side in ipairs({ -1, 1 }) do
				local c2 = 0
				for iy = -sz.Y / 2 + gapSize / 2, sz.Y / 2 - gapSize / 2 + 0.01, gapSize do
					for iz = -sz.Z / 2 + gapSize / 2, sz.Z / 2 - gapSize / 2, gapSize do
						if c2 < 16 then
							c2 = c2 + 1
							n = n + 1
							weldPiece("Tile", Vector3.new(0.04, tileSize, tileSize), p.CFrame * CFrame.new(side * (sz.X / 2 + 0.02), iy, iz) * CFrame.Angles(math.rad(45), 0, 0),
								rgb(skin.tiles[(n % #skin.tiles) + 1]), tmat, refl)
						end
					end
				end
			end
		end
	elseif skin.pattern == "flames" then
		-- glowing flame tongues licking back along both sides
		local flameCols = { Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 30), Color3.fromRGB(230, 50, 20) }
		for pi = 1, math.min(2, #paints) do
			local p = paints[pi]
			local sz = p.Size
			for _, side in ipairs({ -1, 1 }) do
				for k = 1, 5 do
					local len = sz.Z * (0.25 + 0.12 * ((k * 3) % 4))
					local y = -sz.Y / 2 + sz.Y * (k / 6)
					local z = -sz.Z / 2 + len / 2 + 0.2
					weldPiece("Flame", Vector3.new(0.05, math.max(0.12, sz.Y * 0.14), len), p.CFrame * CFrame.new(side * (sz.X / 2 + 0.03), y, z) * CFrame.Angles(math.rad(-8 + k * 3), 0, 0),
						flameCols[(k % 3) + 1], Enum.Material.Neon)
				end
			end
			for k = 1, 4 do
				weldPiece("Flame", Vector3.new(sz.X * 0.12, 0.05, sz.Z * 0.35), p.CFrame * CFrame.new(-sz.X * 0.3 + k * sz.X * 0.12, sz.Y / 2 + 0.03, -sz.Z * 0.25),
					flameCols[(k % 3) + 1], Enum.Material.Neon)
			end
		end
	end
	if skin.sparkle and biggest then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = rgb(skin.sparkle)
		sp.Parent = biggest
	end
	if skin.glow and biggest then
		local l = Instance.new("PointLight")
		l.Name = "SkinGlow"
		l.Color = rgb(skin.glow)
		l.Range = 16
		l.Brightness = 2.5
		l.Parent = biggest
		-- glowing underbody strip
		local sz = biggest.Size
		weldPiece("UnderGlow", Vector3.new(sz.X * 0.8, 0.06, sz.Z * 0.8), biggest.CFrame * CFrame.new(0, -sz.Y / 2 - 0.05, 0), rgb(skin.glow), Enum.Material.Neon)
	end
end

function VB.applyTrail(model, body, trailId)
	local old = body:FindFirstChild("VCTrail")
	if old then old:Destroy() end
	local tdef = Config.getTrail(trailId)
	if not tdef or not tdef.colors then return end
	local a0, a1 = body:FindFirstChild("TrailBottom"), body:FindFirstChild("TrailTop")
	if not a0 or not a1 then return end
	a1.Position = a0.Position + Vector3.new(0, (tdef.width or 2) * (model:GetAttribute("Scale") or 1), 0)
	local keys = {}
	local n = #tdef.colors
	for i, c in ipairs(tdef.colors) do
		local tpos = (n == 1) and 0 or (i - 1) / (n - 1)
		keys[#keys + 1] = ColorSequenceKeypoint.new(tpos, rgb(c))
	end
	if n == 1 then keys[2] = ColorSequenceKeypoint.new(1, rgb(tdef.colors[1])) end
	local trail = Instance.new("Trail")
	trail.Name = "VCTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keys)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.7
	trail.LightEmission = tdef.light or 0
	trail.MinLength = 0.2
	trail.WidthScale = NumberSequence.new(1, 0.35)
	trail.Parent = body
	if tdef.sparkle then
		local old2 = a0:FindFirstChild("TrailStars")
		if old2 then old2:Destroy() end
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "TrailStars"
		pe.Rate = 30
		pe.Lifetime = NumberRange.new(0.6, 1.2)
		pe.Speed = NumberRange.new(1, 4)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.6, 0)
		pe.Color = ColorSequence.new(keys)
		pe.Parent = a0
	end
end

return VB
