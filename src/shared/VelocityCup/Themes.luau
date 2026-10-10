-- Themes: sky and lighting for each map, plus the server room.
-- Applied on each player's own screen, so players in different races
-- (or in the server room) each see the right time of day.

local Lighting = game:GetService("Lighting")

local Themes = {}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

Themes.presets = {
	hub   = { clock = 14, bright = 2, amb = {120,120,140}, out = {150,150,170}, aCol = {200,200,220}, aDec = {120,120,150}, dens = 0.05, haze = 0, shadows = true },
	coast = { clock = 17.6, bright = 2.5, amb = {90,70,60}, out = {160,120,100}, aCol = {255,180,140}, aDec = {255,120,90}, dens = 0.3, haze = 1.5 },
	city  = { clock = 0.2, bright = 1, amb = {60,50,90}, out = {80,70,120}, aCol = {60,30,110}, aDec = {30,10,60}, dens = 0.35, haze = 2 },
	frost = { clock = 13, bright = 3, amb = {150,160,180}, out = {180,190,210}, aCol = {230,240,250}, aDec = {200,215,235}, dens = 0.35, haze = 1 },
	lava  = { clock = 18.8, bright = 1.5, amb = {90,40,30}, out = {130,60,40}, aCol = {120,40,20}, aDec = {90,25,10}, dens = 0.45, haze = 2.5 },
	jungle = { clock = 15.5, bright = 2.2, amb = {80,110,70}, out = {120,150,100}, aCol = {170,210,150}, aDec = {90,130,80}, dens = 0.4, haze = 2.2 },
	water = { clock = 11, bright = 3, amb = {120,140,160}, out = {160,180,200}, aCol = {200,230,250}, aDec = {120,180,220}, dens = 0.25, haze = 0.8 },
}

function Themes.apply(name)
	local s = Themes.presets[name] or Themes.presets.coast
	Lighting.ClockTime = s.clock
	Lighting.Brightness = s.bright
	Lighting.Ambient = rgb(s.amb)
	Lighting.OutdoorAmbient = rgb(s.out)
	Lighting.GlobalShadows = true
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = s.dens
	atm.Offset = 0.1
	atm.Color = rgb(s.aCol)
	atm.Decay = rgb(s.aDec)
	atm.Glare = 0.4
	atm.Haze = s.haze
	atm.Parent = Lighting
end

return Themes
