-- Hub: screens for the server room. Bottom bar (Race bots, Race players,
-- Garage, Shop, Leaderboard), the map picker for bot races, the room list,
-- the waiting-room panel (ready up / host starts), garage with 3D preview,
-- the item shop (coins and Robux) and the fastest-lap leaderboard.
-- Walking up to a kiosk or vehicle pedestal and pressing E opens the same screens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent:WaitForChild("UIKit"))
local Shared = ReplicatedStorage:WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))
local VehicleBuilder = require(Shared:WaitForChild("VehicleBuilder"))

local player = Players.LocalPlayer
local make, label, button = UI.make, UI.label, UI.button

local Hub = {}

function Hub.create(gui, remotes, HubState)
	local self = {}
	local root = make("Frame", { Name = "Hub", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	self.root = root
	local panels = {}
	local function closeAll()
		for _, p in pairs(panels) do p.Visible = false end
	end
	local openSpin -- set further down

	-- what this player owns: { skin = {id=true}, trail = {...}, vehicle = {...} }
	local function owned()
		local okj, o = pcall(function() return HttpService:JSONDecode(player:GetAttribute("Owned") or "{}") end)
		local set = { skin = {}, trail = {}, vehicle = {} }
		if okj and type(o) == "table" then
			for _, id in ipairs(o.skins or {}) do set.skin[id] = true end
			for _, id in ipairs(o.trails or {}) do set.trail[id] = true end
			for _, id in ipairs(o.vehicles or {}) do set.vehicle[id] = true end
		end
		set.skin.factory = true
		set.trail.none = true
		for _, v in ipairs(Config.VEHICLES) do
			if not v.robux then set.vehicle[v.id] = true end
		end
		return set
	end
	-- opens the Roblox purchase window for a Robux item; returns false if its pass isn't set up
	local function promptPass(it)
		if (it.gamePassId or 0) > 0 then
			pcall(function() MarketplaceService:PromptGamePassPurchase(player, it.gamePassId) end)
			return true
		end
		return false
	end
	local NOT_SET_UP = "This Robux item isn't set up yet. The game owner needs to add its Game Pass ID (see README)."
	-- pick a vehicle, or offer to buy it if it's a Robux vehicle you don't own
	local function chooseVehicle(v, toastFn)
		if v.robux and not owned().vehicle[v.id] then
			if not promptPass(v) then toastFn(NOT_SET_UP) end
			return false
		end
		remotes.ChooseCar:FireServer(v.id)
		return true
	end

	-- ---------- header ----------
	label({ Parent = root, Text = "VELOCITY CUP", Font = Enum.Font.GothamBlack, TextSize = 40, TextColor3 = UI.YELLOW,
		Position = UDim2.fromOffset(24, 50), Size = UDim2.fromOffset(500, 44), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	label({ Parent = root, Text = "SERVER ROOM", Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(26, 92), Size = UDim2.fromOffset(300, 16), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	local coinPill = make("Frame", { Parent = root, Position = UDim2.fromOffset(26, 116), Size = UDim2.fromOffset(170, 34), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.2 }, { UI.corner(17), UI.stroke(UI.YELLOW, 1) })
	make("Frame", { Parent = coinPill, Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = UI.YELLOW }, { UI.corner(10) })
	local coinLabel = label({ Parent = coinPill, Text = "0 COINS", Font = Enum.Font.GothamBlack, TextSize = 16, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local carLabel = label({ Parent = root, Text = "", Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(26, 156), Size = UDim2.fromOffset(420, 16), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	local saveNote = label({ Parent = root, Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(26, 176), Size = UDim2.fromOffset(420, 14), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.7 })
	local toastLabel = label({ Parent = root, Text = "", Font = Enum.Font.GothamBlack, TextSize = 24, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(800, 34), TextStrokeTransparency = 0.4 })
	local toastT = 0
	function self.toast(text) toastLabel.Text = text; toastT = 3 end
	RunService.RenderStepped:Connect(function(dt)
		if toastT > 0 then
			toastT = toastT - dt
			if toastT <= 0 then toastLabel.Text = "" end
		end
	end)

	-- ---------- bottom bar ----------
	local bar = make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(660, 76), BackgroundTransparency = 1 },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function barButton(order, text, sub, color, textColor)
		local b = button({ Parent = bar, LayoutOrder = order, Size = UDim2.fromOffset(152, 64), Text = "", BackgroundColor3 = color })
		label({ Parent = b, Text = text, Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = textColor or Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 22) })
		local subL = label({ Parent = b, Text = sub, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = textColor or Color3.fromRGB(235, 235, 235), Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 16) })
		return b, subL
	end
	local spinBtn, spinSub = barButton(1, "DAILY SPIN", "Win a skin", Color3.fromRGB(150, 70, 230))
	local garageBtn = barButton(3, "GARAGE", "Pick your ride", UI.CARD)
	local shopBtn = barButton(4, "SHOP", "Skins & trails", UI.CARD)
	local boardBtn = barButton(5, "LEADERBOARD", "Fastest laps", UI.CARD)
	for _, b in ipairs({ garageBtn, shopBtn, boardBtn }) do UI.stroke(UI.YELLOW, 1).Parent = b end
	label({ Parent = root, Text = "Walk to the RED arch to race bots or the BLUE arch to race players, and press E", Font = Enum.Font.GothamMedium, TextSize = 13,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -98), Size = UDim2.fromOffset(700, 16), TextStrokeTransparency = 0.5 })

	local function overlay(name, w, h, title)
		local p = UI.panel({ Parent = gui, Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(w, h), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
		UI.pad(18).Parent = p
		label({ Parent = p, Text = title, Font = Enum.Font.GothamBlack, TextSize = 30, Size = UDim2.new(1, -110, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		local close = button({ Parent = p, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(96, 32), Text = "CLOSE", BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
		close.MouseButton1Click:Connect(function() p.Visible = false end)
		panels[name] = p
		return p
	end

	-- ---------- garage ----------
	local garage = overlay("Garage", 900, 540, "GARAGE")
	local vp = make("ViewportFrame", { Parent = garage, Position = UDim2.fromOffset(0, 46), Size = UDim2.fromOffset(300, 240), BackgroundColor3 = UI.CARD, Ambient = Color3.fromRGB(150, 150, 160), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -2, -1), ZIndex = 5 }, { UI.corner(4) })
	local vpCam = make("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = vpCam
	local gName = label({ Parent = garage, Text = "", Font = Enum.Font.GothamBlack, TextSize = 22, Position = UDim2.fromOffset(0, 294), Size = UDim2.fromOffset(300, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local gKind = label({ Parent = garage, Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 322), Size = UDim2.fromOffset(300, 40), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
	local gStats = make("Frame", { Parent = garage, Position = UDim2.fromOffset(0, 368), Size = UDim2.fromOffset(300, 120), BackgroundTransparency = 1, ZIndex = 5 })
	local gMsg = label({ Parent = garage, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = UI.GREEN, Position = UDim2.fromOffset(0, 470), Size = UDim2.fromOffset(300, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
	local function garageMsg(text) gMsg.Text = text end
	local vGrid = make("ScrollingFrame", { Parent = garage, Position = UDim2.fromOffset(316, 46), Size = UDim2.new(1, -316, 1, -46), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5 },
		{ make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 74), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local vCards = {}
	local vBadges = {}
	local refreshPreview      -- defined below
	local previewVid = nil    -- a Robux vehicle you're looking at but don't own yet
	for i, v in ipairs(Config.VEHICLES) do
		local b = make("TextButton", { Parent = vGrid, LayoutOrder = i, BackgroundColor3 = UI.CARD, Text = "", AutoButtonColor = true, ZIndex = 5 }, { UI.corner(4) })
		local st = UI.stroke(); st.Parent = b
		make("Frame", { Parent = b, Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = UI.rgb(v.color), BorderSizePixel = 0, ZIndex = 5 }, { UI.corner(2) })
		label({ Parent = b, Text = string.upper(v.class), TextSize = 10, TextColor3 = UI.YELLOW, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -24, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		label({ Parent = b, Text = v.name, Font = Enum.Font.GothamBlack, TextSize = 16, Position = UDim2.fromOffset(16, 26), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
		label({ Parent = b, Text = v.kind, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -24, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
		vCards[v.id] = st
		if v.robux then
			-- Robux vehicle: green badge with the price (or OWNED once bought)
			st.Color = UI.GREEN
			local badge = make("TextLabel", { Parent = b, Name = "Badge", Text = "R$ " .. v.robux, Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = UI.INK, BackgroundColor3 = UI.GREEN,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(58, 16), ZIndex = 6 }, { UI.corner(3) })
			vBadges[v.id] = badge
		end
		b.MouseButton1Click:Connect(function()
			gMsg.Text = ""
			local locked = v.robux and not owned().vehicle[v.id]
			previewVid = locked and v.id or nil
			refreshPreview()
			if locked then gMsg.Text = "Robux vehicle: R$ " .. v.robux .. ". Buy it in the window that pops up." end
			chooseVehicle(v, garageMsg)
		end)
	end
	local previewModel, previewKey, rot = nil, nil, 0
	local function stat(parent, name, v, y)
		label({ Parent = parent, Text = name, TextSize = 11, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(80, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		local bg = make("Frame", { Parent = parent, Position = UDim2.fromOffset(86, y + 4), Size = UDim2.fromOffset(200, 7), BackgroundColor3 = Color3.fromRGB(45, 49, 60), BorderSizePixel = 0, ZIndex = 5 })
		make("Frame", { Parent = bg, Size = UDim2.fromScale(math.clamp(v, 0.06, 1), 1), BackgroundColor3 = UI.FG, BorderSizePixel = 0, ZIndex = 5 })
	end
	refreshPreview = function()
		if previewVid and owned().vehicle[previewVid] then previewVid = nil end
		local vid = previewVid or player:GetAttribute("Car") or Config.VEHICLES[2].id
		local skin = player:GetAttribute("Skin") or "factory"
		local trail = player:GetAttribute("Trail") or "none"
		local key = vid .. "|" .. skin .. "|" .. trail
		local vdef = Config.getVehicle(vid)
		local driving = Config.getVehicle(player:GetAttribute("Car") or Config.VEHICLES[2].id)
		carLabel.Text = "Driving: " .. driving.name .. "  ·  " .. driving.class
		if key == previewKey then return end
		previewKey = key
		if previewModel then previewModel:Destroy() end
		previewModel = VehicleBuilder.build(vdef, CFrame.new(), "Preview", vp, { preview = true, skin = skin, trail = trail })
		local _, size = previewModel:GetBoundingBox()
		local dist = math.max(size.X, size.Y, size.Z) * 1.55 + 4
		vpCam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.62, dist * 0.32, dist * 0.72), Vector3.new(0, -0.3, 0))
		gName.Text = previewVid and (vdef.name .. "  (preview)") or vdef.name
		gKind.Text = string.upper(vdef.class) .. "  ·  " .. vdef.kind
		for _, ch in ipairs(gStats:GetChildren()) do ch:Destroy() end
		stat(gStats, "SPEED", (vdef.top - 54) / 28, 0)
		stat(gStats, "ACCEL", (vdef.accel - 22) / 24, 20)
		stat(gStats, "HANDLING", (vdef.turn - 1.6) / 1.45, 40)
		stat(gStats, "OFF-ROAD", vdef.offroad or 0, 60)
		stat(gStats, "WEIGHT", (vdef.weight or 1) / 2.4, 80)
	end
	RunService.RenderStepped:Connect(function(dt)
		if previewModel and garage.Visible then
			rot = rot + dt * 0.5
			previewModel:PivotTo(CFrame.Angles(0, rot, 0))
		end
	end)

	-- ---------- map picker (race bots) ----------
	local maps = overlay("Maps", 900, 470, "RACE BOTS  ·  PICK A MAP")
	local mapsMode = "solo"
	local mapsTitle = maps:FindFirstChildOfClass("TextLabel")
	label({ Parent = maps, Text = "3 laps against 7 bots. Shortcuts are hidden: look for walls you can drive through.", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local mGrid = make("ScrollingFrame", { Parent = maps, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5 },
		{ make("UIGridLayout", { CellSize = UDim2.fromOffset(276, 170), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local mapButtons = {}
	for i, t in ipairs(Config.TRACKS) do
		local card = make("Frame", { Parent = mGrid, LayoutOrder = i, BackgroundColor3 = UI.CARD, ZIndex = 5 }, { UI.corner(4), UI.stroke() })
		label({ Parent = card, Text = t.name, Font = Enum.Font.GothamBlack, TextSize = 19, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		label({ Parent = card, Text = t.blurb, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 50), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
		local secrets = 0
		for _, r in ipairs(t.routes or {}) do if r.kind == "shortcut" then secrets = secrets + 1 end end
		label({ Parent = card, Text = string.upper(t.theme == "water" and "water map" or t.theme) .. "  ·  " .. secrets .. " SECRET SHORTCUT" .. (secrets == 1 and "" or "S"),
			TextSize = 11, TextColor3 = UI.YELLOW, Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		local go = button({ Parent = card, Position = UDim2.new(0, 12, 1, -48), Size = UDim2.new(1, -24, 0, 36), Text = "RACE HERE", ZIndex = 5 })
		mapButtons[#mapButtons + 1] = go
		go.MouseButton1Click:Connect(function()
			if mapsMode == "solo" then
				remotes.StartSolo:FireServer(t.id)
				self.toast("Loading " .. t.name .. "...")
			else
				remotes.CreateRoom:FireServer(t.id)
			end
			closeAll()
		end)
	end
	local function openMaps(mode)
		mapsMode = mode
		mapsTitle.Text = (mode == "solo") and "RACE BOTS  ·  PICK A MAP" or "NEW ROOM  ·  PICK A MAP"
		for _, b in ipairs(mapButtons) do b.Text = (mode == "solo") and "RACE HERE" or "CREATE ROOM" end
		closeAll()
		maps.Visible = true
	end

	-- ---------- rooms list (race players) ----------
	local roomsP = overlay("Rooms", 760, 500, "RACE PLAYERS")
	label({ Parent = roomsP, Text = "Join a waiting room, or make your own and invite friends. The race starts when everyone is ready and the host presses Start.",
		Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
	local createBtn = button({ Parent = roomsP, Position = UDim2.fromOffset(0, 84), Size = UDim2.fromOffset(200, 38), Text = "CREATE A ROOM", ZIndex = 5 })
	local inviteBtn = button({ Parent = roomsP, Position = UDim2.fromOffset(212, 84), Size = UDim2.fromOffset(200, 38), Text = "INVITE FRIENDS", BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
	UI.stroke(UI.YELLOW, 1).Parent = inviteBtn
	local roomList = make("ScrollingFrame", { Parent = roomsP, Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 1, -136), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5 },
		{ make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	createBtn.MouseButton1Click:Connect(function() openMaps("room") end)
	local function invite()
		local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
		if ok and can then
			pcall(function() SocialService:PromptGameInvite(player) end)
		else
			self.toast("Invites work once the game is published on Roblox")
		end
	end
	inviteBtn.MouseButton1Click:Connect(invite)

	local function getRooms()
		local ok, list = pcall(function() return HttpService:JSONDecode(HubState:GetAttribute("Rooms") or "[]") end)
		if ok and type(list) == "table" then return list end
		return {}
	end
	local function renderRooms()
		for _, ch in ipairs(roomList:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		local list = getRooms()
		if #list == 0 then
			local f = make("Frame", { Parent = roomList, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = UI.CARD, ZIndex = 5 }, { UI.corner(4) })
			label({ Parent = f, Text = "No rooms yet. Create one and your friends can join it.", TextSize = 15, TextColor3 = UI.MUTED, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
		end
		for _, room in ipairs(list) do
			local f = make("Frame", { Parent = roomList, LayoutOrder = room.id, Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = UI.CARD, ZIndex = 5 }, { UI.corner(4) })
			label({ Parent = f, Text = "ROOM " .. room.id .. "  ·  " .. Config.getTrack(room.track).name, Font = Enum.Font.GothamBlack, TextSize = 17, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
			label({ Parent = f, Text = "Host " .. room.host .. "  ·  " .. #room.members .. "/" .. Config.ROOM_SIZE .. " players" .. (room.fillBots and "  ·  bots on" or "") .. "  ·  " .. (room.status == "racing" and "racing now" or "waiting"),
				Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -170, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
			local open = room.status == "open" and #room.members < Config.ROOM_SIZE
			local j = button({ Parent = f, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 38), Text = open and "JOIN" or (room.status == "racing" and "RACING" or "FULL"),
				BackgroundColor3 = open and UI.BLUE or Color3.fromRGB(70, 70, 76), TextColor3 = open and UI.INK or UI.MUTED, ZIndex = 5 })
			j.MouseButton1Click:Connect(function()
				if open then
					remotes.JoinRoom:FireServer(room.id)
					closeAll()
				end
			end)
		end
	end
	HubState:GetAttributeChangedSignal("Rooms"):Connect(function()
		if roomsP.Visible then renderRooms() end
		self.refreshRoom()
	end)

	-- ---------- waiting room panel ----------
	local roomPanel = UI.panel({ Parent = root, Name = "RoomPanel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.45, 0), Size = UDim2.fromOffset(330, 470), Visible = false, BackgroundTransparency = 0.08 })
	UI.pad(16).Parent = roomPanel
	local rpTitle = label({ Parent = roomPanel, Text = "ROOM", Font = Enum.Font.GothamBlack, TextSize = 26, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	local rpMap = label({ Parent = roomPanel, Text = "", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = UI.YELLOW, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
	local hostBox = make("Frame", { Parent = roomPanel, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1 })
	label({ Parent = hostBox, Text = "MAP (HOST PICKS)", TextSize = 11, TextColor3 = UI.MUTED, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left })
	local mapRow = make("Frame", { Parent = hostBox, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 },
		{ make("UIGridLayout", { CellSize = UDim2.fromOffset(96, 20), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local mapPick = {}
	for i, t in ipairs(Config.TRACKS) do
		local b = button({ Parent = mapRow, LayoutOrder = i, Text = t.name, TextSize = 10, BackgroundColor3 = UI.CARD, TextColor3 = UI.FG })
		mapPick[t.id] = b
		b.MouseButton1Click:Connect(function() remotes.RoomSetTrack:FireServer(t.id) end)
	end
	local botsToggle = button({ Parent = hostBox, Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 26), Text = "FILL EMPTY SPOTS WITH BOTS: OFF", TextSize = 12, BackgroundColor3 = UI.CARD, TextColor3 = UI.FG })
	local members = make("Frame", { Parent = roomPanel, Position = UDim2.fromOffset(0, 162), Size = UDim2.new(1, 0, 0, 8 * 24), BackgroundTransparency = 1 },
		{ make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local rpStatus = label({ Parent = roomPanel, Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.new(0, 0, 1, -142), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local readyB = button({ Parent = roomPanel, Position = UDim2.new(0, 0, 1, -106), Size = UDim2.new(0.5, -4, 0, 40), Text = "READY" })
	local startB = button({ Parent = roomPanel, Position = UDim2.new(0.5, 4, 1, -106), Size = UDim2.new(0.5, -4, 0, 40), Text = "START RACE", BackgroundColor3 = UI.GREEN, TextColor3 = UI.FG })
	local inviteB = button({ Parent = roomPanel, Position = UDim2.new(0, 0, 1, -58), Size = UDim2.new(0.5, -4, 0, 34), Text = "INVITE", TextSize = 13, BackgroundColor3 = UI.CARD, TextColor3 = UI.FG })
	local leaveB = button({ Parent = roomPanel, Position = UDim2.new(0.5, 4, 1, -58), Size = UDim2.new(0.5, -4, 0, 34), Text = "LEAVE ROOM", TextSize = 13, BackgroundColor3 = UI.CARD, TextColor3 = UI.RED })
	inviteB.MouseButton1Click:Connect(invite)
	leaveB.MouseButton1Click:Connect(function() remotes.LeaveRoom:FireServer() end)
	local myReady, isHost, botsOn = false, false, false
	readyB.MouseButton1Click:Connect(function() remotes.RoomReady:FireServer(not myReady) end)
	startB.MouseButton1Click:Connect(function() remotes.RoomStart:FireServer() end)
	botsToggle.MouseButton1Click:Connect(function() if isHost then remotes.RoomSetBots:FireServer(not botsOn) end end)

	function self.refreshRoom()
		local k = player:GetAttribute("Room")
		local room = nil
		if k then
			for _, r in ipairs(getRooms()) do
				if r.id == k then room = r end
			end
		end
		roomPanel.Visible = room ~= nil and root.Visible
		if not room then return end
		isHost = room.hostId == player.UserId
		botsOn = room.fillBots
		rpTitle.Text = "ROOM " .. room.id .. (room.status == "racing" and "  ·  RACING" or "")
		rpMap.Text = Config.getTrack(room.track).name
		hostBox.Visible = true
		for id, b in pairs(mapPick) do
			b.BackgroundColor3 = (id == room.track) and UI.YELLOW or UI.CARD
			b.TextColor3 = (id == room.track) and UI.INK or (isHost and UI.FG or UI.MUTED)
			b.AutoButtonColor = isHost
		end
		botsToggle.Text = "FILL EMPTY SPOTS WITH BOTS: " .. (room.fillBots and "ON" or "OFF")
		botsToggle.TextColor3 = isHost and UI.FG or UI.MUTED
		for _, ch in ipairs(members:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		myReady = false
		for i, m in ipairs(room.members) do
			if m.userId == player.UserId then myReady = m.ready end
			local f = make("Frame", { Parent = members, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = UI.CARD }, { UI.corner(3) })
			label({ Parent = f, Text = m.name .. (m.host and "  (host)" or ""), TextSize = 13, TextColor3 = (m.userId == player.UserId) and UI.YELLOW or UI.FG, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -80, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			label({ Parent = f, Text = m.ready and "READY" or "not ready", Font = m.ready and Enum.Font.GothamBlack or Enum.Font.Gotham, TextSize = 12, TextColor3 = m.ready and UI.GREEN or UI.MUTED, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(70, 22), TextXAlignment = Enum.TextXAlignment.Right })
		end
		readyB.Text = myReady and "NOT READY" or "READY"
		readyB.BackgroundColor3 = myReady and UI.CARD or UI.YELLOW
		readyB.TextColor3 = myReady and UI.FG or UI.INK
		startB.Visible = isHost
		startB.BackgroundColor3 = room.canStart and UI.GREEN or Color3.fromRGB(70, 70, 76)
		if room.status == "racing" then
			rpStatus.Text = "Race in progress"
		elseif isHost then
			rpStatus.Text = room.canStart and "Everyone is ready. Press Start!" or room.why
		else
			rpStatus.Text = room.canStart and "Everyone is ready. Waiting for the host to start." or room.why
		end
	end
	player:GetAttributeChangedSignal("Room"):Connect(self.refreshRoom)

	-- ---------- shop ----------
	local shop = UI.panel({ Parent = gui, Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 520), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	UI.pad(18).Parent = shop
	label({ Parent = shop, Text = "ITEM SHOP", Font = Enum.Font.GothamBlack, TextSize = 32, Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local shopCoins = label({ Parent = shop, Text = "", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = UI.YELLOW, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 6), Size = UDim2.fromOffset(200, 24), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	local closeShop = button({ Parent = shop, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(96, 32), Text = "CLOSE", BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
	local tabSkins = button({ Parent = shop, Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(120, 32), Text = "SKINS", ZIndex = 5 })
	local tabTrails = button({ Parent = shop, Position = UDim2.fromOffset(130, 48), Size = UDim2.fromOffset(120, 32), Text = "TRAILS", BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
	local tabRobux = button({ Parent = shop, Position = UDim2.fromOffset(260, 48), Size = UDim2.fromOffset(120, 32), Text = "ROBUX", BackgroundColor3 = UI.CARD, TextColor3 = UI.GREEN, ZIndex = 5 })
	local shopMsg = label({ Parent = shop, Text = "Earn coins by racing: better finishes and item hits pay more.", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(392, 48), Size = UDim2.new(1, -392, 0, 32), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	panels.Shop = shop
	local grid = make("ScrollingFrame", { Parent = shop, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -92), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5 },
		{ make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local shopKind = "skin"

	local function renderShop()
		for _, ch in ipairs(grid:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		tabSkins.BackgroundColor3 = shopKind == "skin" and UI.YELLOW or UI.CARD
		tabSkins.TextColor3 = shopKind == "skin" and UI.INK or UI.FG
		tabTrails.BackgroundColor3 = shopKind == "trail" and UI.YELLOW or UI.CARD
		tabTrails.TextColor3 = shopKind == "trail" and UI.INK or UI.FG
		tabRobux.BackgroundColor3 = shopKind == "robux" and UI.GREEN or UI.CARD
		tabRobux.TextColor3 = shopKind == "robux" and UI.INK or UI.GREEN
		local kindKey = (shopKind == "skin") and "skin" or "trail"
		local list
		if shopKind == "skin" then
			list = Config.SKINS
		elseif shopKind == "robux" then
			list = Config.robuxItems()
		else
			list = {}
			for _, t in ipairs(Config.TRAILS) do
				if not t.robux then list[#list + 1] = t end
			end
		end
		local allOwned = owned()
		local equippedBy = { skin = player:GetAttribute("Skin") or "factory", trail = player:GetAttribute("Trail") or "none", vehicle = player:GetAttribute("Car") }
		local coins = player:GetAttribute("Coins") or 0
		shopCoins.Text = tostring(coins) .. " COINS"
		for i, it in ipairs(list) do
			local itKind = it.shopKind or kindKey -- Robux tab mixes vehicles and trails
			local mine = allOwned[itKind]
			local equipped = equippedBy[itKind]
			local tile = make("Frame", { Parent = grid, LayoutOrder = i, BackgroundColor3 = UI.CARD, ZIndex = 5 }, { UI.corner(4) })
			local st = UI.stroke(it.id == equipped and UI.YELLOW or UI.LINE, it.id == equipped and 2 or 1)
			st.Parent = tile
			local sw = make("Frame", { Parent = tile, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 58), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, { UI.corner(3) })
			if shopKind == "skin" then
				if it.id == "factory" then
					local v = Config.getVehicle(player:GetAttribute("Car"))
					UI.gradient({ v.color, v.accent }).Parent = sw
				elseif it.camo then
					sw.BackgroundColor3 = UI.rgb(it.color)
					for n = 1, 7 do
						local c = it.camo[(n % #it.camo) + 1]
						make("Frame", { Parent = sw, BackgroundColor3 = UI.rgb(c), BorderSizePixel = 0, ZIndex = 5,
							Position = UDim2.fromScale(((n * 37) % 80) / 100, ((n * 53) % 60) / 100), Size = UDim2.fromScale(0.22, 0.34) }, { UI.corner(8) })
					end
				else
					local c = it.color
					local hi = { math.min(255, c[1] + 70), math.min(255, c[2] + 70), math.min(255, c[3] + 70) }
					UI.gradient({ hi, c, { math.floor(c[1] * 0.6), math.floor(c[2] * 0.6), math.floor(c[3] * 0.6) } }).Parent = sw
				end
			elseif itKind == "vehicle" then
				UI.gradient({ it.glow or it.accent, it.color, it.color }).Parent = sw
				label({ Parent = sw, Text = "VEHICLE", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = UI.rgb(it.glow or it.accent), Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.5, ZIndex = 5 })
			else
				if it.colors then
					UI.gradient(it.colors).Parent = sw
				else
					sw.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
					label({ Parent = sw, Text = "NONE", TextSize = 14, TextColor3 = UI.MUTED, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
				end
			end
			label({ Parent = tile, Text = it.name, Font = Enum.Font.GothamBlack, TextSize = 15, Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
			local have = mine[it.id]
			local btnText, btnColor, txtColor
			if it.id == equipped then btnText, btnColor, txtColor = (itKind == "vehicle") and "DRIVING" or "EQUIPPED", UI.GREEN, UI.FG
			elseif have then btnText, btnColor, txtColor = (itKind == "vehicle") and "DRIVE" or "EQUIP", UI.CARD, UI.FG
			elseif it.robux then btnText, btnColor, txtColor = "R$ " .. it.robux, UI.GREEN, UI.INK
			elseif it.spin then btnText, btnColor, txtColor = "WIN ON DAILY SPIN", UI.rgb(Config.spinTier(it.spin).color), UI.INK
			else btnText, btnColor, txtColor = "BUY  " .. it.price, (coins >= it.price) and UI.YELLOW or Color3.fromRGB(70, 70, 76), UI.INK end
			if it.spin then
				local tier = Config.spinTier(it.spin)
				label({ Parent = tile, Text = string.upper(tier.name) .. " · DAILY SPIN", TextSize = 10, TextColor3 = UI.rgb(tier.color), Position = UDim2.fromOffset(10, 94), Size = UDim2.new(1, -20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
			end
			if it.robux then
				label({ Parent = tile, Text = (itKind == "vehicle") and "ROBUX VEHICLE · BEST STATS" or "ROBUX ITEM", TextSize = 10, TextColor3 = UI.GREEN, Position = UDim2.fromOffset(10, 94), Size = UDim2.new(1, -20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
			end
			local b = button({ Parent = tile, Position = UDim2.new(0, 10, 1, -42), Size = UDim2.new(1, -20, 0, 32), Text = btnText, BackgroundColor3 = btnColor, TextColor3 = txtColor, ZIndex = 5 })
			if have and it.id ~= equipped then UI.stroke(UI.LINE, 1).Parent = b end
			b.MouseButton1Click:Connect(function()
				if it.id == equipped then return end
				if it.spin and not have then
					if openSpin then openSpin() end
					return
				end
				if it.robux and not have then
					if not promptPass(it) then
						shopMsg.Text = NOT_SET_UP
						shopMsg.TextColor3 = UI.RED
					end
					return
				end
				if itKind == "vehicle" then
					remotes.ChooseCar:FireServer(it.id)
					shopMsg.Text = "You're driving the " .. it.name
					shopMsg.TextColor3 = UI.GREEN
					return
				end
				local action = have and "equip" or "buy"
				local okc, okRes, msg = pcall(function() return remotes.Shop:InvokeServer(action, itKind, it.id) end)
				if okc then
					shopMsg.Text = (msg and msg ~= "") and msg or (okRes and "Equipped " .. it.name or "Could not do that")
					shopMsg.TextColor3 = okRes and UI.GREEN or UI.RED
				end
			end)
		end
	end
	local function openShop() closeAll(); shop.Visible = true; renderShop() end
	shopBtn.MouseButton1Click:Connect(openShop)
	tabRobux.MouseButton1Click:Connect(function() shopKind = "robux"; renderShop() end)
	closeShop.MouseButton1Click:Connect(function() shop.Visible = false end)
	tabSkins.MouseButton1Click:Connect(function() shopKind = "skin"; renderShop() end)
	tabTrails.MouseButton1Click:Connect(function() shopKind = "trail"; renderShop() end)

	-- ---------- leaderboard ----------
	local board = UI.panel({ Parent = gui, Name = "Leaderboard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 540), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	UI.pad(18).Parent = board
	label({ Parent = board, Text = "FASTEST LAPS", Font = Enum.Font.GothamBlack, TextSize = 32, Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local closeBoard = button({ Parent = board, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(96, 32), Text = "CLOSE", BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
	local tabs = make("Frame", { Parent = board, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 5 },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local boardNote = label({ Parent = board, Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local list = make("ScrollingFrame", { Parent = board, Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -108), BackgroundTransparency = 1, ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 5 },
		{ make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local boardTrack = Config.TRACKS[1].id
	local tabBtns = {}
	local function loadBoard()
		for id, b in pairs(tabBtns) do
			b.BackgroundColor3 = id == boardTrack and UI.YELLOW or UI.CARD
			b.TextColor3 = id == boardTrack and UI.INK or UI.FG
		end
		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		boardNote.Text = "Loading..."
		local want = boardTrack
		task.spawn(function()
			local okc, rows = pcall(function() return remotes.GetLeaderboard:InvokeServer(want) end)
			if want ~= boardTrack then return end
			if not okc or type(rows) ~= "table" then rows = {} end
			local saving = player:GetAttribute("Saving")
			boardNote.Text = (#rows == 0 and "No laps yet. Set the first time!" or ("Top " .. Config.LEADERBOARD_SIZE .. " on " .. Config.getTrack(want).name))
				.. (saving == false and "  ·  Saving is off in this test session" or "")
			for _, e in ipairs(rows) do
				local me = e.userId == player.UserId
				local f = make("Frame", { Parent = list, LayoutOrder = e.rank, Size = UDim2.new(1, -8, 0, 32), BackgroundColor3 = me and Color3.fromRGB(60, 52, 15) or UI.CARD, ZIndex = 5 }, { UI.corner(3) })
				local col = me and UI.YELLOW or ((e.rank <= 3) and UI.FG or Color3.fromRGB(210, 210, 210))
				label({ Parent = f, Text = "#" .. e.rank, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = e.rank <= 3 and UI.YELLOW or col, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(50, 32), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
				label({ Parent = f, Text = tostring(e.name), TextSize = 15, TextColor3 = col, Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -200, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
				label({ Parent = f, Text = UI.fmt(e.time), TextSize = 15, TextColor3 = col, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(110, 32), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
			end
		end)
	end
	for i, t in ipairs(Config.TRACKS) do
		local b = button({ Parent = tabs, LayoutOrder = i, Size = UDim2.fromOffset(112, 28), Text = string.upper(t.name), TextSize = 11, BackgroundColor3 = UI.CARD, TextColor3 = UI.FG, ZIndex = 5 })
		tabBtns[t.id] = b
		b.MouseButton1Click:Connect(function() boardTrack = t.id; loadBoard() end)
	end
	local function openBoard()
		closeAll()
		board.Visible = true
		loadBoard()
	end
	boardBtn.MouseButton1Click:Connect(openBoard)
	panels.Board = board
	closeBoard.MouseButton1Click:Connect(function() board.Visible = false end)


	-- ---------- daily spin wheel ----------
	local spinP = overlay("Spin", 560, 640, "DAILY SPIN")
	label({ Parent = spinP, Text = "One free spin every day. Win a skin for your vehicle!", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local wheel = make("Frame", { Parent = spinP, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(360, 360), BackgroundColor3 = Color3.fromRGB(20, 22, 30), ZIndex = 5 },
		{ UI.corner(180), UI.stroke(UI.YELLOW, 4) })
	local spinner = make("Frame", { Parent = wheel, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = 0, ZIndex = 6 })
	local layout = { "uncommon", "rare", "uncommon", "rare", "uncommon", "epic", "uncommon", "rare", "uncommon", "legendary", "uncommon", "rare", "uncommon", "mythic", "uncommon", "rare" }
	for k, tid in ipairs(layout) do
		local tier = Config.spinTier(tid)
		local a = (k - 1) / #layout * math.pi * 2
		local x, y = 180 + math.sin(a) * 138, 180 - math.cos(a) * 138
		local slot = make("Frame", { Parent = spinner, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = UI.rgb(tier.color), Rotation = math.deg(a), ZIndex = 7 },
			{ UI.corner(29), UI.stroke(Color3.new(0, 0, 0), 2) })
		label({ Parent = slot, Text = string.upper(string.sub(tier.name, 1, 4)), Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Size = UDim2.fromScale(1, 1), ZIndex = 8 })
		-- spoke from the centre to the slot
		make("Frame", { Parent = spinner, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(180, 180), Size = UDim2.fromOffset(3, 110), BackgroundColor3 = UI.rgb(tier.color), BackgroundTransparency = 0.5, BorderSizePixel = 0, Rotation = math.deg(a), ZIndex = 6 })
	end
	make("Frame", { Parent = spinP, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = UI.YELLOW, Rotation = 45, ZIndex = 9 }, { UI.stroke(Color3.new(0, 0, 0), 2) })
	local spinGo = button({ Parent = wheel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120), Text = "SPIN!", TextSize = 26, ZIndex = 10 })
	spinGo:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 60)
	-- chances in RaceConfig are weights, so show each one as its real percentage
	local oddsText = {}
	local weightSum = 0
	for _, t in ipairs(Config.SPIN_TIERS) do weightSum = weightSum + t.chance end
	for _, t in ipairs(Config.SPIN_TIERS) do
		local pct = t.chance / weightSum * 100
		local pctText = (pct >= 1) and string.format("%.0f", pct) or string.format("%.1f", pct)
		oddsText[#oddsText + 1] = '<font color="#' .. string.format("%02X%02X%02X", t.color[1], t.color[2], t.color[3]) .. '">' .. t.name .. " " .. pctText .. "%</font>"
	end
	label({ Parent = spinP, Text = table.concat(oddsText, "   "), RichText = true, TextSize = 13, Position = UDim2.fromOffset(0, 458), Size = UDim2.new(1, 0, 0, 18), ZIndex = 5 })
	local prizeText = {}
	for _, t in ipairs(Config.SPIN_TIERS) do prizeText[#prizeText + 1] = t.name .. ": " .. Config.getSkin(t.skin).name end
	label({ Parent = spinP, Text = table.concat(prizeText, "  ·  "), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 480), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, ZIndex = 5 })
	local result = label({ Parent = spinP, Text = "", Font = Enum.Font.GothamBlack, TextSize = 22, Position = UDim2.fromOffset(0, 516), Size = UDim2.new(1, 0, 0, 30), ZIndex = 5 })
	local resultSub = label({ Parent = spinP, Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 548), Size = UDim2.new(1, 0, 0, 18), ZIndex = 5 })
	local equipWon = button({ Parent = spinP, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 570), Size = UDim2.fromOffset(200, 34), Text = "EQUIP IT", Visible = false, ZIndex = 5 })
	local spinning, wonSkin = false, nil
	local function timeLeftText()
		local left = (player:GetAttribute("NextSpin") or 0) - os.time()
		if left <= 0 then return "now" end
		return string.format("%dh %02dm", math.floor(left / 3600), math.floor(left % 3600 / 60))
	end
	local function refreshSpin()
		local ready = player:GetAttribute("SpinReady") == true
		spinSub.Text = ready and "Spin is ready!" or ("Next in " .. timeLeftText())
		spinBtn.BackgroundColor3 = ready and Color3.fromRGB(170, 80, 255) or Color3.fromRGB(80, 60, 110)
		if not spinning then
			spinGo.Text = ready and "SPIN!" or "DONE"
			spinGo.BackgroundColor3 = ready and UI.YELLOW or Color3.fromRGB(70, 70, 76)
			if not ready and result.Text == "" then
				result.Text = "Come back tomorrow"
				resultSub.Text = "Next spin in " .. timeLeftText()
			end
		end
	end
	openSpin = function() closeAll(); spinP.Visible = true; refreshSpin() end
	spinGo.MouseButton1Click:Connect(function()
		if spinning or player:GetAttribute("SpinReady") ~= true then return end
		spinning = true
		result.Text = "Spinning..."
		resultSub.Text = ""
		equipWon.Visible = false
		local ok, res = pcall(function() return remotes.DailySpin:InvokeServer() end)
		if not ok or type(res) ~= "table" or not res.ok then
			spinning = false
			result.Text = (ok and type(res) == "table" and res.msg) or "Could not spin right now"
			refreshSpin()
			return
		end
		local choices = {}
		for k, tid in ipairs(layout) do if tid == res.tier then choices[#choices + 1] = k end end
		local k = choices[math.random(1, math.max(1, #choices))] or 1
		local slotAngle = (k - 1) / #layout * 360
		local cur = spinner.Rotation % 360
		local final = spinner.Rotation + 360 * 6 + ((-slotAngle - cur) % 360)
		local tw = TweenService:Create(spinner, TweenInfo.new(4.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = final })
		tw:Play()
		tw.Completed:Connect(function()
			spinning = false
			local tier = Config.spinTier(res.tier)
			local skin = Config.getSkin(res.skin)
			result.Text = string.upper(tier.name) .. "!  " .. skin.name
			result.TextColor3 = UI.rgb(tier.color)
			if res.dupe then
				resultSub.Text = "You already have it, so you get " .. tostring(res.coins) .. " coins"
			else
				resultSub.Text = "New skin unlocked. Come back tomorrow for another spin"
				wonSkin = res.skin
				equipWon.Visible = true
			end
			refreshSpin()
		end)
	end)
	equipWon.MouseButton1Click:Connect(function()
		if wonSkin then
			pcall(function() remotes.Shop:InvokeServer("equip", "skin", wonSkin) end)
			equipWon.Visible = false
			self.toast("Skin equipped!")
		end
	end)
	player:GetAttributeChangedSignal("SpinReady"):Connect(function()
		refreshSpin()
		if player:GetAttribute("SpinReady") == true and root.Visible then self.toast("Your daily spin is ready! Press DAILY SPIN") end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			refreshSpin()
		end
	end)
	refreshSpin()

	-- ---------- open screens ----------
	local function openGarage() closeAll(); previewVid = nil; gMsg.Text = ""; garage.Visible = true; refreshPreview() end
	local function openRooms() closeAll(); roomsP.Visible = true; renderRooms() end
	spinBtn.MouseButton1Click:Connect(function() openSpin() end)
	garageBtn.MouseButton1Click:Connect(openGarage)

	-- kiosks and pedestals in the server room (press E)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if not root.Visible then return end
		local menu = prompt:GetAttribute("Menu")
		local vid = prompt:GetAttribute("Vehicle")
		if vid then
			local v = Config.getVehicle(vid)
			if chooseVehicle(v, self.toast) then self.toast("You picked the " .. v.name) end
		elseif menu == "bots" then openMaps("solo")
		elseif menu == "players" then openRooms()
		elseif menu == "shop" then openShop()
		elseif menu == "board" then openBoard()
		end
	end)

	-- ---------- refresh ----------
	function self.refresh()
		local mine = player:GetAttribute("Car")
		local have = owned().vehicle
		for id, st in pairs(vCards) do
			local v = Config.getVehicle(id)
			st.Color = (id == mine) and UI.YELLOW or (v.robux and UI.GREEN or UI.LINE)
			st.Thickness = (id == mine) and 2 or 1
		end
		for id, badge in pairs(vBadges) do
			badge.Text = have[id] and "OWNED" or ("R$ " .. Config.getVehicle(id).robux)
		end
		coinLabel.Text = tostring(player:GetAttribute("Coins") or 0) .. " COINS"
		saveNote.Text = (player:GetAttribute("Saving") == false) and "Test session: coins and unlocks are not saved" or ""
		refreshPreview()
		if shop.Visible then renderShop() end
		self.refreshRoom()
	end
	for _, a in ipairs({ "Car", "Coins", "Skin", "Trail", "Owned", "Saving" }) do
		player:GetAttributeChangedSignal(a):Connect(self.refresh)
	end

	function self.setVisible(v)
		root.Visible = v
		if not v then closeAll() end
		self.refreshRoom()
	end
	self.refresh()
	return self
end

return Hub
