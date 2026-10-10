-- Hud: everything on screen during a race. Place and lap, timer, speed,
-- held item, drift meter, minimap with every racer, live standings, results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UI = require(script.Parent:WaitForChild("UIKit"))
local Shared = ReplicatedStorage:WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))

local player = Players.LocalPlayer
local make, label = UI.make, UI.label

local Hud = {}

function Hud.create(gui, State)
	local self = {}
	local root = make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	self.root = root

	-- place + lap + time
	local placeLabel = label({ Parent = root, Text = "8th", Font = Enum.Font.GothamBlack, TextSize = 72, Position = UDim2.fromOffset(24, 46), Size = UDim2.fromOffset(240, 72), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 })
	local ofLabel = label({ Parent = root, Text = "OF 8", TextSize = 14, TextColor3 = Color3.fromRGB(220, 220, 220), Position = UDim2.fromOffset(28, 120), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	local topBox = make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(190, 58), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.35 }, { UI.corner(4) })
	local lapLabel = label({ Parent = topBox, Text = "LAP 1/3", Font = Enum.Font.GothamBlack, TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4) })
	local timeLabel = label({ Parent = topBox, Text = "0:00.00", Font = Enum.Font.GothamMedium, TextSize = 18, TextColor3 = Color3.fromRGB(220, 220, 220), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 32) })

	-- held item
	local itemBox = make("Frame", { Parent = root, Position = UDim2.fromOffset(24, 146), Size = UDim2.fromOffset(120, 84), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.3 }, { UI.corner(6), UI.stroke(UI.LINE, 2) })
	local itemStroke = itemBox:FindFirstChildOfClass("UIStroke")
	local itemSwatch = make("Frame", { Parent = itemBox, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = UI.LINE }, { UI.corner(14) })
	local itemName = label({ Parent = itemBox, Text = "NO ITEM", Font = Enum.Font.GothamBlack, TextSize = 14, Position = UDim2.fromOffset(44, 10), Size = UDim2.new(1, -50, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
	local itemHint = label({ Parent = itemBox, Text = "Grab a ? box", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })

	-- speed + drift
	local bottom = make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(300, 90), BackgroundTransparency = 1 })
	local speedLabel = label({ Parent = bottom, Text = "0", Font = Enum.Font.GothamBlack, TextSize = 60, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(170, 62), TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.5 })
	label({ Parent = bottom, Text = "KM/H", TextSize = 13, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 62), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.6 })
	label({ Parent = bottom, Text = "DRIFT", TextSize = 11, Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(100, 12), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	local driftBg = make("Frame", { Parent = bottom, Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(110, 8), BackgroundColor3 = Color3.fromRGB(60, 60, 60), BackgroundTransparency = 0.3, BorderSizePixel = 0 })
	local driftFill = make("Frame", { Parent = driftBg, Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.BLUE, BorderSizePixel = 0 })

	-- minimap + standings (top right)
	local MAP = 210
	local mapBox = make("Frame", { Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 46), Size = UDim2.fromOffset(MAP, MAP), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.35, ClipsDescendants = true }, { UI.corner(6) })
	local dotLayer = make("Frame", { Parent = mapBox, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local markLayer = make("Frame", { Parent = mapBox, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 })
	local standBox = make("Frame", { Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 46 + MAP + 8), Size = UDim2.fromOffset(MAP, 8 * 22 + 8), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.35 }, { UI.corner(6) })
	local standRows = {}
	for i = 1, 8 do
		local rowF = make("Frame", { Parent = standBox, Position = UDim2.fromOffset(4, 4 + (i - 1) * 22), Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(60, 52, 15) }, { UI.corner(3) })
		local num = label({ Parent = rowF, Text = tostring(i), Font = Enum.Font.GothamBlack, TextSize = 13, Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(18, 20) })
		local dot = make("Frame", { Parent = rowF, Position = UDim2.fromOffset(26, 6), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = UI.FG }, { UI.corner(4) })
		local nm = label({ Parent = rowF, Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
		standRows[i] = { frame = rowF, num = num, dot = dot, name = nm }
	end
	local markers = {}
	local mapF = nil

	local revealed = {}
	local routeCol = { Road = Color3.fromRGB(255, 210, 31), Dirt = Color3.fromRGB(196, 140, 80), Ice = Color3.fromRGB(150, 220, 255), Water = Color3.fromRGB(70, 170, 230) }
	function self.revealRoute(r)
		if revealed[r] or not mapF then return false end
		revealed[r] = true
		for j = 1, r.M, 5 do
			local x, y = mapF(r.P[j])
			make("Frame", { Parent = dotLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = routeCol[r.surface] or routeCol.Road, BorderSizePixel = 0 }, { UI.corner(2) })
		end
		return true
	end
	function self.setState(folder) State = folder end

	function self.setTrack(tr)
		for _, ch in ipairs(dotLayer:GetChildren()) do ch:Destroy() end
		local b = tr.bounds
		local span = math.max(b.x1 - b.x0, b.z1 - b.z0)
		local scale = (MAP - 24) / span
		local ox = (MAP - (b.x1 - b.x0) * scale) / 2
		local oz = (MAP - (b.z1 - b.z0) * scale) / 2
		mapF = function(p) return (p.X - b.x0) * scale + ox, (p.Z - b.z0) * scale + oz end
		for i = 1, tr.N, 6 do
			local x, y = mapF(tr.P[i])
			make("Frame", { Parent = dotLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = UI.FG, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, { UI.corner(3) })
		end
		revealed = {}
		for _, r in ipairs(tr.routes) do
			-- shortcuts are secret: they only appear on the map once you've found them
			if r.kind ~= "shortcut" then self.revealRoute(r) end
		end
		local sx, sy = mapF(tr.P[1])
		make("Frame", { Parent = dotLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(sx, sy), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = UI.YELLOW, BorderSizePixel = 0, Rotation = 45 })
	end

	local function markerFor(model, mine)
		local m = markers[model]
		if m then return m end
		local vdef = Config.getVehicle(model:GetAttribute("VehicleId"))
		local size = mine and 18 or 13
		local f = make("Frame", { Parent = markLayer, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = mine and UI.YELLOW or UI.rgb(vdef.color), ZIndex = mine and 5 or 4 },
			{ UI.corner(size), UI.stroke(Color3.new(0, 0, 0), mine and 2 or 1) })
		local t = label({ Parent = f, Text = "", Font = Enum.Font.GothamBlack, TextSize = mine and 11 or 9, Size = UDim2.fromScale(1, 1), TextColor3 = mine and UI.INK or Color3.new(1, 1, 1), TextStrokeTransparency = mine and 1 or 0.4, ZIndex = mine and 6 or 5 })
		m = { frame = f, text = t, color = UI.rgb(vdef.color) }
		markers[model] = m
		return m
	end

	-- toast / centre text / stun banner
	local centerLabel = label({ Parent = gui, Text = "", Font = Enum.Font.GothamBlack, TextSize = 120, TextColor3 = UI.YELLOW, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(700, 140), TextStrokeTransparency = 0.4 })
	local toastLabel = label({ Parent = root, Text = "", Font = Enum.Font.GothamBlack, TextSize = 30, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(700, 40), TextStrokeTransparency = 0.4 })
	local stunLabel = label({ Parent = root, Text = "", Font = Enum.Font.GothamBlack, TextSize = 40, TextColor3 = UI.RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(700, 50), TextStrokeTransparency = 0.3 })
	local wrongLabel = label({ Parent = root, Text = "WRONG WAY  ·  PRESS R TO RESET", Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = UI.RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 40), TextStrokeTransparency = 0.4, Visible = false })
	local hintLabel = label({ Parent = root, Text = "WASD drive  ·  Space drift / trick  ·  E use item  ·  R reset", TextSize = 13, Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(230, 230, 230), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.fromOffset(600, 16), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	self.infoLabel = label({ Parent = gui, Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.fromOffset(700, 26), TextStrokeTransparency = 0.5 })
	local toastT, goT = 0, 0

	function self.toast(text) toastLabel.Text = text; toastT = 1.6 end
	function self.center(text, dur)
		centerLabel.Text = text
		goT = dur or 0
	end
	function self.hint(show) hintLabel.Visible = show end
	function self.show(v)
		root.Visible = v
		if not v then
			for model, m in pairs(markers) do m.frame:Destroy(); markers[model] = nil end
		end
	end

	-- ---------- results ----------
	local results = UI.panel({ Parent = gui, Name = "Results", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 470), Visible = false, BackgroundTransparency = 0.08 })
	make("UIPadding", { Parent = results, PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 16) })
	local resTitle = label({ Parent = results, Text = "RESULTS", Font = Enum.Font.GothamBlack, TextSize = 36, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
	local resSub = label({ Parent = results, Text = "", Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = UI.MUTED, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
	local resList = make("Frame", { Parent = results, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -78), BackgroundTransparency = 1 },
		{ make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	function self.showResults()
		for _, ch in ipairs(resList:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		local okj, list = pcall(function() return HttpService:JSONDecode(State:GetAttribute("Results") or "[]") end)
		if not okj then list = {} end
		local myRow, anyProjected = nil, false
		for _, row in ipairs(list) do
			local me = row.userId == player.UserId and not row.bot
			if me then myRow = row end
			if row.projected then anyProjected = true end
			local f = make("Frame", { Parent = resList, LayoutOrder = row.place, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = me and Color3.fromRGB(60, 52, 15) or UI.CARD }, { UI.corner(3) })
			local col = me and UI.YELLOW or UI.FG
			label({ Parent = f, Text = tostring(row.place), Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = col, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(28, 40), TextXAlignment = Enum.TextXAlignment.Left })
			label({ Parent = f, Text = row.name .. (row.bot and "  (bot)" or ""), TextSize = 16, TextColor3 = col, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(0.4, -42, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			label({ Parent = f, Text = row.car, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = UI.MUTED, Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.28, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			label({ Parent = f, Text = UI.fmt(row.time) .. (row.projected and " *" or ""), TextSize = 16, TextColor3 = col, Position = UDim2.fromScale(0.68, 0), Size = UDim2.new(0.18, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
			if (row.coins or 0) > 0 then
				label({ Parent = f, Text = "+" .. row.coins, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = UI.YELLOW, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.12, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
		if myRow then
			resTitle.Text = myRow.place == 1 and "YOU WON!" or ("YOU FINISHED " .. string.upper(UI.ord(myRow.place)))
			resSub.Text = "+" .. (myRow.coins or 0) .. " coins  ·  " .. (myRow.hits or 0) .. " item hits  ·  best lap " .. UI.fmt(myRow.bestLap ~= 0 and myRow.bestLap or nil)
				.. (anyProjected and "  ·  * projected" or "")
		else
			resTitle.Text = "RACE RESULTS"
			resSub.Text = Config.getTrack(State:GetAttribute("TrackId")).name .. (anyProjected and "  ·  * projected time" or "")
		end
		results.Visible = true
	end
	function self.hideResults() results.Visible = false end

	-- ---------- per-frame update ----------
	local standT = 0
	function self.update(dt, st, myModel, carsFolder)
		if toastT > 0 then
			toastT = toastT - dt
			if toastT <= 0 then toastLabel.Text = "" end
		end
		if goT > 0 then
			goT = goT - dt
			if goT <= 0 then centerLabel.Text = "" end
		end
		if not root.Visible or not st or not myModel or not myModel.Parent then return end
		local place = myModel:GetAttribute("Place") or #carsFolder:GetChildren()
		placeLabel.Text = UI.ord(place)
		ofLabel.Text = "OF " .. tostring(#carsFolder:GetChildren())
		local laps = State:GetAttribute("Laps") or 3
		lapLabel.Text = "LAP " .. tostring(myModel:GetAttribute("Lap") or 1) .. "/" .. tostring(laps)
		local t = 0
		if myModel:GetAttribute("Finished") then
			t = myModel:GetAttribute("FinishTime") or 0
		elseif State:GetAttribute("Phase") == "Race" then
			t = workspace:GetServerTimeNow() - (State:GetAttribute("StartTime") or 0)
		end
		timeLabel.Text = UI.fmt(t)
		speedLabel.Text = tostring(math.floor(math.abs(st.fs) * Config.SPEED_TO_KMH + 0.5))
		local dc = st.drifting and math.clamp(st.driftCharge / 2.3, 0, 1) or 0
		driftFill.Size = UDim2.fromScale(dc, 1)
		driftFill.BackgroundColor3 = st.driftCharge > 2.3 and Color3.fromRGB(255, 138, 28) or (st.driftCharge > 1.1 and UI.BLUE or Color3.fromRGB(255, 242, 192))
		-- item
		local item = myModel:GetAttribute("Item")
		if item and Config.ITEMS[item] then
			local it = Config.ITEMS[item]
			itemName.Text = string.upper(it.name)
			itemHint.Text = it.desc .. "  ·  press E"
			itemSwatch.BackgroundColor3 = UI.rgb(it.color)
			itemStroke.Color = UI.YELLOW
		else
			itemName.Text = "NO ITEM"
			itemHint.Text = "Drive through a ? box"
			itemSwatch.BackgroundColor3 = UI.LINE
			itemStroke.Color = UI.LINE
		end
		-- stun banner / restart countdown after being put back on the track
		if st.freezeT and st.freezeT > 0 then
			stunLabel.Text = "GET READY  " .. tostring(math.ceil(st.freezeT))
		elseif st.stunT > 0 then
			local k = st.stunKind
			stunLabel.Text = (k == "knockout" and "KNOCKED OUT!") or (k == "blast" and "BLASTED!") or (k == "splash" and "SOAKED!") or (k == "lightning" and "ZAPPED!") or "STUNNED!"
		else
			stunLabel.Text = ""
		end
		-- minimap markers
		if mapF then
			local seen = {}
			for _, m in ipairs(carsFolder:GetChildren()) do
				local body = m:FindFirstChild("Body")
				if body then
					local mine = (m == myModel)
					local mk = markerFor(m, mine)
					local x, y = mapF(body.Position)
					mk.frame.Position = UDim2.fromOffset(x, y)
					mk.text.Text = tostring(m:GetAttribute("Place") or "")
					seen[m] = true
				end
			end
			for model, mk in pairs(markers) do
				if not seen[model] then mk.frame:Destroy(); markers[model] = nil end
			end
		end
		-- standings list
		standT = standT - dt
		if standT <= 0 then
			standT = 0.25
			local list = {}
			for _, m in ipairs(carsFolder:GetChildren()) do list[#list + 1] = m end
			table.sort(list, function(a, b) return (a:GetAttribute("Place") or 99) < (b:GetAttribute("Place") or 99) end)
			for i = 1, 8 do
				local row = standRows[i]
				local m = list[i]
				if m then
					row.frame.Visible = true
					local mine = (m == myModel)
					row.name.Text = (m:GetAttribute("DriverName") or "?") .. (m:GetAttribute("Finished") and "  ✓" or "")
					row.name.TextColor3 = mine and UI.YELLOW or UI.FG
					row.num.TextColor3 = mine and UI.YELLOW or UI.FG
					row.dot.BackgroundColor3 = mine and UI.YELLOW or UI.rgb(Config.getVehicle(m:GetAttribute("VehicleId")).color)
					row.frame.BackgroundTransparency = mine and 0.2 or 1
				else
					row.frame.Visible = false
				end
			end
		end
	end

	function self.setWrongWay(v) wrongLabel.Visible = v end
	return self
end

return Hud
