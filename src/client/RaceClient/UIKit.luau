-- UIKit: small helpers so the screens below stay readable.

local UI = {}

UI.YELLOW = Color3.fromRGB(255, 210, 31)
UI.INK = Color3.fromRGB(13, 16, 23)
UI.CARD = Color3.fromRGB(24, 28, 37)
UI.LINE = Color3.fromRGB(60, 64, 75)
UI.FG = Color3.fromRGB(239, 234, 223)
UI.MUTED = Color3.fromRGB(146, 152, 166)
UI.BLUE = Color3.fromRGB(79, 179, 255)
UI.GREEN = Color3.fromRGB(23, 178, 106)
UI.RED = Color3.fromRGB(255, 74, 46)

function UI.rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

function UI.make(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, ch in ipairs(children or {}) do ch.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

function UI.corner(r) return UI.make("UICorner", { CornerRadius = UDim.new(0, r or 4) }) end
function UI.stroke(c, t)
	return UI.make("UIStroke", { Color = c or UI.LINE, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function UI.pad(px)
	return UI.make("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px) })
end

function UI.label(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or UI.FG
	props.Font = props.Font or Enum.Font.GothamBold
	return UI.make("TextLabel", props)
end

function UI.button(props)
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextSize = props.TextSize or 15
	props.TextColor3 = props.TextColor3 or UI.INK
	props.BackgroundColor3 = props.BackgroundColor3 or UI.YELLOW
	props.AutoButtonColor = true
	return UI.make("TextButton", props, { UI.corner(4) })
end

function UI.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UI.INK
	props.BackgroundTransparency = props.BackgroundTransparency or 0.1
	return UI.make("Frame", props, { UI.corner(6), UI.stroke() })
end

function UI.fmt(t)
	if not t or t ~= t then return "--:--.--" end
	local m = math.floor(t / 60)
	local s = t - m * 60
	return string.format("%d:%05.2f", m, s)
end

function UI.ord(n)
	local suf = "th"
	local m = n % 100
	if m < 11 or m > 13 then
		if n % 10 == 1 then suf = "st" elseif n % 10 == 2 then suf = "nd" elseif n % 10 == 3 then suf = "rd" end
	end
	return tostring(n) .. suf
end

function UI.gradient(colors)
	local keys = {}
	local n = #colors
	for i, c in ipairs(colors) do
		keys[#keys + 1] = ColorSequenceKeypoint.new(n == 1 and 0 or (i - 1) / (n - 1), UI.rgb(c))
	end
	if n == 1 then keys[2] = ColorSequenceKeypoint.new(1, UI.rgb(colors[1])) end
	return UI.make("UIGradient", { Color = ColorSequence.new(keys) })
end

return UI
