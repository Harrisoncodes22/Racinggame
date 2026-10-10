-- HubBuilder: the server room everyone spawns into.
--   Front:  spawn point and the big sign
--   Left:   RACE BOTS kiosk (solo race against 7 bots, pick any map)
--   Right:  RACE PLAYERS kiosk (create or join a waiting room)
--   Centre: showroom with every vehicle on a pedestal (walk up to pick one),
--           and the Robux vehicle on a spotlight stage in the middle
--   Corners: shop counter and leaderboard wall
--   Back:   4 glass waiting rooms where groups wait until everyone is ready

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))

local HubBuilder = {}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

function HubBuilder.build()
	local hp = Config.HUB_POSITION
	local O = CFrame.new(hp[1], hp[2], hp[3])
	local folder = Instance.new("Folder")
	folder.Name = "VCServerRoom"

	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		if props.Shape then p.Shape = props.Shape end
		for k, v in pairs(props) do
			if k ~= "Shape" and k ~= "At" then p[k] = v end
		end
		if props.At then p.CFrame = O * props.At end
		p.Parent = folder
		return p
	end
	local function sign(p, face, text, color, size)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = size or Vector2.new(800, 160)
		g.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = color or Color3.fromRGB(255, 210, 31)
		t.Text = text
		t.Parent = g
		g.Parent = p
		return t
	end
	local function prompt(p, action, object, attrs, dist)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = action
		pr.ObjectText = object
		pr.HoldDuration = 0
		pr.MaxActivationDistance = dist or 12
		pr.RequiresLineOfSight = false
		for k, v in pairs(attrs) do pr:SetAttribute(k, v) end
		pr.Parent = p
		return pr
	end

	local WALL = Color3.fromRGB(28, 32, 44)
	local YELLOW = Color3.fromRGB(255, 210, 31)
	local X, Z, H = 140, 110, 46

	-- shell
	part({ Name = "Floor", Size = Vector3.new(X * 2 + 4, 2, Z * 2 + 4), At = CFrame.new(0, -1, 0), Color = Color3.fromRGB(34, 38, 50), Material = Enum.Material.Concrete })
	part({ Name = "Roof", Size = Vector3.new(X * 2 + 4, 2, Z * 2 + 4), At = CFrame.new(0, H + 1, 0), Color = Color3.fromRGB(20, 23, 32) })
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Wall", Size = Vector3.new(X * 2 + 4, H, 2), At = CFrame.new(0, H / 2, s * (Z + 1)), Color = WALL })
		part({ Name = "Wall", Size = Vector3.new(2, H, Z * 2 + 4), At = CFrame.new(s * (X + 1), H / 2, 0), Color = WALL })
		part({ Name = "Trim", Size = Vector3.new(X * 2, 0.6, 0.4), At = CFrame.new(0, 12, s * (Z - 0.2)), Color = YELLOW, Material = Enum.Material.Neon, CanCollide = false })
		part({ Name = "Trim", Size = Vector3.new(0.4, 0.6, Z * 2), At = CFrame.new(s * (X - 0.2), 12, 0), Color = YELLOW, Material = Enum.Material.Neon, CanCollide = false })
	end
	for ix = -2, 2 do
		for iz = -1, 1 do
			local lamp = part({ Name = "Lamp", Size = Vector3.new(26, 0.4, 8), At = CFrame.new(ix * 55, H - 0.3, iz * 65), Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.Neon, CanCollide = false })
			local l = Instance.new("PointLight")
			l.Range = 60
			l.Brightness = 1.3
			l.Parent = lamp
		end
	end
	-- checker stripe down the middle
	for n = -12, 12 do
		part({ Name = "Checker", Size = Vector3.new(4, 0.05, 4), At = CFrame.new(n * 4, 0.03, 60 + ((n % 2 == 0) and 0 or 4)), Color = Color3.new(0.92, 0.92, 0.92), CanCollide = false })
	end
	local banner = part({ Name = "Banner", Size = Vector3.new(120, 16, 1), At = CFrame.new(0, 28, Z - 0.6), Color = Color3.fromRGB(13, 16, 23) })
	sign(banner, Enum.NormalId.Front, "VELOCITY CUP  ·  SERVER ROOM", YELLOW)

	-- decoration: pillars with neon, plants, benches, trophies, carpet, logo ring
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -70, -20, 30, 80 }) do
			part({ Name = "Pillar", Size = Vector3.new(5, H, 5), At = CFrame.new(sx * (X - 3.5), H / 2, z), Color = Color3.fromRGB(44, 48, 62), Material = Enum.Material.Concrete })
			part({ Name = "PillarNeon", Size = Vector3.new(5.2, 0.6, 5.2), At = CFrame.new(sx * (X - 3.5), 6, z), Color = YELLOW, Material = Enum.Material.Neon, CanCollide = false })
			part({ Name = "PillarNeon", Size = Vector3.new(5.2, 0.6, 5.2), At = CFrame.new(sx * (X - 3.5), 30, z), Color = Color3.fromRGB(60, 150, 255), Material = Enum.Material.Neon, CanCollide = false })
		end
		for _, z in ipairs({ -45, 5, 55 }) do
			part({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4, 4), At = CFrame.new(sx * (X - 9), 1.5, z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 80, 50) })
			for n = 0, 2 do
				part({ Name = "Plant", Shape = Enum.PartType.Ball, Size = Vector3.new(5 - n, 5 - n, 5 - n), At = CFrame.new(sx * (X - 9) + (n - 1) * 0.8, 4.5 + n * 1.6, z + (n % 2) * 0.6), Color = Color3.fromRGB(50, 140 + n * 15, 60), Material = Enum.Material.Grass, CanCollide = false })
			end
			part({ Name = "Bench", Size = Vector3.new(4, 1.2, 12), At = CFrame.new(sx * (X - 16), 1.2, z + 14), Color = Color3.fromRGB(40, 44, 56), Material = Enum.Material.Wood })
			part({ Name = "BenchBack", Size = Vector3.new(0.6, 2.5, 12), At = CFrame.new(sx * (X - 14.2), 2.6, z + 14), Color = Color3.fromRGB(40, 44, 56), Material = Enum.Material.Wood })
		end
	end
	part({ Name = "Carpet", Size = Vector3.new(16, 0.06, 80), At = CFrame.new(0, 0.04, 55), Color = Color3.fromRGB(150, 30, 40), Material = Enum.Material.Fabric, CanCollide = false })
	part({ Name = "LogoRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 30, 30), At = CFrame.new(0, 0.05, 80) * CFrame.Angles(0, 0, math.pi / 2), Color = YELLOW, Material = Enum.Material.Neon, CanCollide = false })
	part({ Name = "LogoInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 27, 27), At = CFrame.new(0, 0.06, 80) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(20, 23, 32), CanCollide = false })
	-- trophy cabinet under the banner
	part({ Name = "TrophyShelf", Size = Vector3.new(40, 6, 5), At = CFrame.new(0, 3, Z - 3), Color = Color3.fromRGB(30, 34, 46), Material = Enum.Material.Wood })
	for n = -2, 2 do
		local hgt = (n == 0) and 5 or (math.abs(n) == 1 and 4 or 3)
		local col = (n == 0) and YELLOW or (math.abs(n) == 1 and Color3.fromRGB(200, 205, 215) or Color3.fromRGB(205, 130, 60))
		part({ Name = "TrophyBase", Size = Vector3.new(2.4, 1, 2.4), At = CFrame.new(n * 7, 6.5, Z - 3), Color = Color3.fromRGB(20, 20, 24) })
		part({ Name = "TrophyStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(hgt, 0.7, 0.7), At = CFrame.new(n * 7, 7 + hgt / 2, Z - 3) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Foil, Reflectance = 0.4 })
		part({ Name = "TrophyCup", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), At = CFrame.new(n * 7, 7.6 + hgt, Z - 3), Color = col, Material = Enum.Material.Foil, Reflectance = 0.4 })
	end
	-- live screen showing how many races are running
	local screen = part({ Name = "LiveScreen", Size = Vector3.new(36, 10, 1), At = CFrame.new(0, 16, -Z + 0.6), Color = Color3.fromRGB(13, 16, 23) })
	local liveText = sign(screen, Enum.NormalId.Back, "NO RACES RUNNING", Color3.fromRGB(80, 230, 140))
	-- the back screen sits above the waiting rooms, so lift it
	screen.CFrame = O * CFrame.new(0, 34, -Z + 0.6)

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = O * CFrame.new(0, 0.5, 80) * CFrame.Angles(0, 0, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	-- kiosks
	local function kiosk(x, z, color, title, sub, menu, action)
		local base = CFrame.new(x, 0, z)
		part({ Name = "KioskPad", Size = Vector3.new(18, 0.2, 18), At = base * CFrame.new(0, 0.1, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "KioskPost", Size = Vector3.new(1.6, 18, 1.6), At = base * CFrame.new(s * 10, 9, 0), Color = color, Material = Enum.Material.Neon })
		end
		local beam = part({ Name = "KioskSign", Size = Vector3.new(22, 5, 1.2), At = base * CFrame.new(0, 20, 0), Color = Color3.fromRGB(13, 16, 23) })
		sign(beam, Enum.NormalId.Front, title, color)
		sign(beam, Enum.NormalId.Back, title, color)
		local console = part({ Name = "Console", Size = Vector3.new(6, 4, 3), At = base * CFrame.new(0, 2, -3), Color = Color3.fromRGB(40, 44, 56), Material = Enum.Material.Metal })
		local screen = part({ Name = "Screen", Size = Vector3.new(5, 2.4, 0.2), At = base * CFrame.new(0, 4.6, -3) * CFrame.Angles(math.rad(-20), 0, 0), Color = color, Material = Enum.Material.Neon })
		sign(screen, Enum.NormalId.Front, sub, Color3.new(1, 1, 1), Vector2.new(400, 190))
		prompt(console, action, title, { Menu = menu }, 14)
	end
	kiosk(-75, 32, Color3.fromRGB(255, 70, 60), "RACE BOTS", "Solo race vs 7 bots", "bots", "Race bots")
	kiosk(75, 32, Color3.fromRGB(60, 150, 255), "RACE PLAYERS", "Race friends and other players", "players", "Race players")

	-- shop counter
	local shop = part({ Name = "ShopCounter", Size = Vector3.new(22, 4, 6), At = CFrame.new(-112, 2, 86), Color = Color3.fromRGB(40, 170, 100), Material = Enum.Material.SmoothPlastic })
	local shopSign = part({ Name = "ShopSign", Size = Vector3.new(22, 5, 1), At = CFrame.new(-112, 12, 92), Color = Color3.fromRGB(13, 16, 23) })
	sign(shopSign, Enum.NormalId.Front, "SHOP  ·  SKINS & TRAILS", Color3.fromRGB(80, 230, 140))
	prompt(shop, "Open shop", "Skins & trails", { Menu = "shop" }, 14)

	-- leaderboard wall
	local board = part({ Name = "Leaderboard", Size = Vector3.new(26, 16, 1), At = CFrame.new(112, 10, 92), Color = Color3.fromRGB(13, 16, 23) })
	sign(board, Enum.NormalId.Front, "FASTEST LAPS\nTOP 50", Color3.fromRGB(190, 130, 255))
	local lbStand = part({ Name = "LeaderboardStand", Size = Vector3.new(8, 3, 3), At = CFrame.new(112, 1.5, 84), Color = Color3.fromRGB(110, 70, 200) })
	prompt(lbStand, "View", "Leaderboard", { Menu = "board" }, 14)

	-- vehicle showroom
	local showCenter = CFrame.new(0, 0, -18)
	local ring = Config.freeVehicles()
	local nV = #ring
	for i, v in ipairs(ring) do
		local a = (i - 1) / nV * math.pi * 2
		local pos = showCenter * CFrame.new(math.sin(a) * 60, 0, math.cos(a) * 28)
		local ped = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 17, 17), At = pos * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(44, 48, 62), Material = Enum.Material.Metal })
		part({ Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.25, 17.6, 17.6), At = pos * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(v.color), Material = Enum.Material.Neon, CanCollide = false })
		local face = O * pos * CFrame.new(0, 1.2 + VehicleBuilder.rideOf(v), 0) * CFrame.Angles(0, a + math.pi * 0.75, 0)
		local m = VehicleBuilder.build(v, face, v.name, folder, { preview = true })
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide = false end
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(200, 44)
		tag.StudsOffset = Vector3.new(0, 7, 0)
		tag.MaxDistance = 90
		tag.Adornee = ped
		local l1 = Instance.new("TextLabel")
		l1.Size = UDim2.new(1, 0, 0.6, 0)
		l1.BackgroundTransparency = 1
		l1.Font = Enum.Font.GothamBlack
		l1.TextScaled = true
		l1.TextColor3 = Color3.new(1, 1, 1)
		l1.TextStrokeTransparency = 0.4
		l1.Text = v.name
		l1.Parent = tag
		local l2 = l1:Clone()
		l2.Position = UDim2.fromScale(0, 0.6)
		l2.Size = UDim2.new(1, 0, 0.4, 0)
		l2.Font = Enum.Font.GothamBold
		l2.TextColor3 = YELLOW
		l2.Text = string.upper(v.class)
		l2.Parent = tag
		tag.Parent = ped
		prompt(ped, "Choose", v.name, { Vehicle = v.id }, 14)
	end

	-- Robux vehicles: a raised spotlight stage in the middle of the showroom
	local premium = {}
	for _, v in ipairs(Config.VEHICLES) do
		if v.robux then premium[#premium + 1] = v end
	end
	for k, v in ipairs(premium) do
		local pos = showCenter * CFrame.new((k - (#premium + 1) / 2) * 26, 0, 0)
		local glow = rgb(v.glow or v.accent)
		local stage = part({ Name = "PremiumStage", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 24, 24), At = pos * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(18, 18, 26), Material = Enum.Material.Metal })
		part({ Name = "PremiumRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.45, 24.8, 24.8), At = pos * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = glow, Material = Enum.Material.Neon, CanCollide = false })
		part({ Name = "PremiumStep", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 28, 28), At = pos * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(30, 32, 44), Material = Enum.Material.Metal })
		-- spotlight rig above it
		local rig = part({ Name = "PremiumSpot", Size = Vector3.new(6, 1, 6), At = pos * CFrame.new(0, 30, 0), Color = Color3.fromRGB(20, 20, 26), Material = Enum.Material.Metal, CanCollide = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 40
		spot.Range = 40
		spot.Brightness = 4
		spot.Color = glow
		spot.Parent = rig
		for n = 0, 5 do
			local a = n / 6 * math.pi * 2
			part({ Name = "PremiumPost", Size = Vector3.new(0.6, 6, 0.6), At = pos * CFrame.new(math.sin(a) * 13.2, 3, math.cos(a) * 13.2), Color = glow, Material = Enum.Material.Neon, CanCollide = false })
		end
		local face = O * pos * CFrame.new(0, 2.4 + VehicleBuilder.rideOf(v), 0) * CFrame.Angles(0, math.pi * 0.8, 0)
		local m = VehicleBuilder.build(v, face, v.name, folder, { preview = true })
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide = false end
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(240, 66)
		tag.StudsOffset = Vector3.new(0, 9, 0)
		tag.MaxDistance = 110
		tag.Adornee = stage
		local l1 = Instance.new("TextLabel")
		l1.Size = UDim2.new(1, 0, 0.5, 0)
		l1.BackgroundTransparency = 1
		l1.Font = Enum.Font.GothamBlack
		l1.TextScaled = true
		l1.TextColor3 = Color3.new(1, 1, 1)
		l1.TextStrokeTransparency = 0.4
		l1.Text = v.name
		l1.Parent = tag
		local l2 = l1:Clone()
		l2.Position = UDim2.fromScale(0, 0.5)
		l2.Size = UDim2.new(1, 0, 0.25, 0)
		l2.Font = Enum.Font.GothamBold
		l2.TextColor3 = glow
		l2.Text = "ROBUX EXCLUSIVE · BEST STATS"
		l2.Parent = tag
		local l3 = l2:Clone()
		l3.Position = UDim2.fromScale(0, 0.75)
		l3.TextColor3 = Color3.fromRGB(80, 230, 140)
		l3.Text = "R$ " .. v.robux
		l3.Parent = tag
		tag.Parent = stage
		prompt(stage, "Choose / Buy", v.name, { Vehicle = v.id }, 18)
	end

	-- waiting rooms along the back wall
	local booths = {}
	local bw, bd = 60, 38
	for k = 1, Config.MAX_ROOMS do
		local cx = -102 + (k - 1) * 68
		local back = -Z
		local front = back + bd
		local mid = (back + front) / 2
		local col = ({ Color3.fromRGB(255, 70, 60), Color3.fromRGB(60, 150, 255), Color3.fromRGB(80, 220, 120), Color3.fromRGB(255, 180, 40) })[(k - 1) % 4 + 1]
		part({ Name = "BoothFloor", Size = Vector3.new(bw, 0.2, bd), At = CFrame.new(cx, 0.1, mid), Color = Color3.fromRGB(24, 27, 36), CanCollide = false })
		part({ Name = "BoothEdge", Size = Vector3.new(bw, 0.25, 0.8), At = CFrame.new(cx, 0.12, front - 0.4), Color = col, Material = Enum.Material.Neon, CanCollide = false })
		for _, s in ipairs({ -1, 1 }) do
			part({ Name = "BoothSide", Size = Vector3.new(1, 16, bd), At = CFrame.new(cx + s * (bw / 2 + 0.5), 8, mid), Color = Color3.fromRGB(150, 190, 230), Material = Enum.Material.Glass, Transparency = 0.6 })
		end
		part({ Name = "BoothGlass", Size = Vector3.new(bw + 2, 16, 1), At = CFrame.new(cx, 8, front + 0.5), Color = Color3.fromRGB(150, 190, 230), Material = Enum.Material.Glass, Transparency = 0.75 })
		part({ Name = "BoothCap", Size = Vector3.new(bw + 2, 1, bd + 2), At = CFrame.new(cx, 16.5, mid), Color = Color3.fromRGB(150, 190, 230), Material = Enum.Material.Glass, Transparency = 0.8 })
		-- little start grid inside
		for g = 0, 3 do
			for s = -1, 1, 2 do
				part({ Name = "GridMark", Size = Vector3.new(8, 0.06, 0.6), At = CFrame.new(cx + s * 12, 0.25, back + 6 + g * 7), Color = Color3.new(0.9, 0.9, 0.9), CanCollide = false })
			end
		end
		local board2 = part({ Name = "BoothSign", Size = Vector3.new(bw, 9, 1), At = CFrame.new(cx, 22, front + 0.5), Color = Color3.fromRGB(13, 16, 23) })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.CanvasSize = Vector2.new(600, 90)
		g.LightInfluence = 0
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.55, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextColor3 = col
		title.Text = "ROOM " .. k .. "  ·  OPEN"
		title.Parent = g
		local status = title:Clone()
		status.Position = UDim2.fromScale(0, 0.55)
		status.Size = UDim2.new(1, 0, 0.45, 0)
		status.Font = Enum.Font.GothamBold
		status.TextColor3 = Color3.new(1, 1, 1)
		status.Text = "Use RACE PLAYERS to start a room"
		status.Parent = g
		g.Parent = board2
		booths[k] = { spot = O * CFrame.new(cx, 3.5, mid - 4), title = title, status = status, color = col }
	end

	folder.Parent = workspace
	return {
		folder = folder,
		spawnCF = O * CFrame.new(0, 4, 80),
		booths = booths,
		liveText = liveText,
	}
end

return HubBuilder
