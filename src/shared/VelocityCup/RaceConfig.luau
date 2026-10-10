-- RaceConfig: every vehicle, track, item and shop item, plus the main game settings.
-- Change numbers here to tune the game. Colors are {red, green, blue} from 0 to 255.

local Config = {}

Config.LAPS = 3
Config.MAX_RACERS = 8        -- real players first, AI bots fill the empty spots
Config.MAX_ROOMS = 4         -- waiting rooms in the server room (one group of friends each)
Config.ROOM_SIZE = 8         -- players allowed in one waiting room
Config.TRACK_SLOTS = 9       -- how many races can run on one server at the same time
Config.RESULTS_TIME = 12     -- seconds the results screen stays up
Config.FINISH_GRACE = 30     -- after the first human finishes, others get this long
Config.MAX_RACE_TIME = 480   -- safety cap in seconds
Config.SAMPLES = 1600        -- how finely the track centre line is measured
Config.K = 2.5               -- world scale (studs per design unit)
Config.SPEED_TO_KMH = 1.43    -- studs/second to the km/h shown on the speedometer
Config.VEHICLE_SCALE = 1.35  -- how much bigger vehicles are built (the skateboard stays normal size)
Config.SPEED_SCALE = 1.12    -- a bit more speed to suit the bigger vehicles and roads
Config.TRACK_WIDTH_SCALE = 1.35   -- wider roads
Config.TRACK_LENGTH_SCALE = 1.15  -- slightly longer laps
Config.HUB_POSITION = {0, 4000, 0}  -- the server room floats high above the tracks
Config.LEADERBOARD_SIZE = 50
Config.START_COINS = 350
Config.FIRST_PLACE_COINS = 150  -- the winner gets this; each place below gets a bit less, last place gets 0
Config.HIT_COINS = 10

-- ---------------------------------------------------------------- vehicles
-- top = top speed, accel = acceleration, turn = handling,
-- offroad = 0..1 how little grass/sand/water slows you, weight = how hard you shove others,
-- stunResist = multiplier on stun time (lower is better), trick = multiplier on trick boosts
Config.VEHICLES = {
	{ id = "toro", type = "car", class = "Supercar", name = "Toro V12", kind = "V12 wedge supercar",
	  color = {242,194,0}, accent = {21,22,26}, top = 75, accel = 30, turn = 1.95, offroad = 0, weight = 1, stunResist = 1, trick = 1,
	  cabinZ = 0.2, cabinLen = 0.36, wing = "lip", nose = 0.9 },
	{ id = "rosso", type = "car", class = "Supercar", name = "Rosso GT", kind = "Front-engine Italian GT",
	  color = {204,16,22}, accent = {26,26,26}, top = 72, accel = 32, turn = 2.08, offroad = 0, weight = 1, stunResist = 1, trick = 1,
	  cabinZ = -0.12, cabinLen = 0.32, wing = "lip", nose = 0.6 },
	{ id = "sterling", type = "car", class = "Supercar", name = "Sterling GT", kind = "British grand tourer",
	  color = {29,74,55}, accent = {196,200,204}, top = 69, accel = 30, turn = 2.32, offroad = 0.05, weight = 1.1, stunResist = 1, trick = 1,
	  cabinZ = -0.14, cabinLen = 0.36, wing = "none", nose = 0.5 },
	{ id = "hyper", type = "car", class = "Supercar", name = "Hyper 16", kind = "Two-tone hypercar",
	  color = {28,63,148}, accent = {10,18,34}, top = 81, accel = 27, turn = 1.78, offroad = 0, weight = 1.15, stunResist = 1, trick = 1,
	  cabinZ = 0.1, cabinLen = 0.34, wing = "wing", nose = 0.7, twoTone = {143,176,255} },
	{ id = "papaya", type = "car", class = "Supercar", name = "Papaya S", kind = "Lightweight track car",
	  color = {255,115,0}, accent = {28,28,28}, top = 71, accel = 36, turn = 2.02, offroad = 0, weight = 0.9, stunResist = 1, trick = 1,
	  cabinZ = 0.15, cabinLen = 0.34, wing = "wing", nose = 0.85 },
	{ id = "kaiser", type = "car", class = "Supercar", name = "Kaiser R", kind = "Rear-engine sports coupe",
	  color = {217,221,224}, accent = {200,16,46}, top = 67, accel = 33, turn = 2.42, offroad = 0.05, weight = 1, stunResist = 1, trick = 1,
	  cabinZ = -0.02, cabinLen = 0.42, wing = "wing", nose = 0.55 },
	{ id = "kart", type = "kart", class = "Go-kart", name = "Rocket Kart", kind = "Tiny, twitchy and quick off the line",
	  color = {230,40,60}, accent = {30,30,34}, top = 66, accel = 41, turn = 2.65, offroad = 0.1, weight = 0.7, stunResist = 1, trick = 1.1 },
	{ id = "bmx", type = "bicycle", class = "Bike", name = "Trail BMX", kind = "Pedal power. Huge trick boosts",
	  color = {40,200,120}, accent = {25,25,25}, top = 62, accel = 43, turn = 2.85, offroad = 0.5, weight = 0.4, stunResist = 0.9, trick = 1.5 },
	{ id = "viper", type = "motorcycle", class = "Motorcycle", name = "Viper 1000", kind = "Superbike. Fast but light",
	  color = {20,20,24}, accent = {255,60,40}, top = 80, accel = 37, turn = 2.2, offroad = 0.2, weight = 0.6, stunResist = 1.1, trick = 1.2 },
	{ id = "hauler", type = "truck", class = "Truck", name = "Big Hauler", kind = "Slow to start, shoves everyone aside",
	  color = {40,90,200}, accent = {200,200,205}, top = 65, accel = 25, turn = 1.7, offroad = 0.4, weight = 2.2, stunResist = 0.7, trick = 0.8 },
	{ id = "crusher", type = "monster", class = "Monster truck", name = "Crusher", kind = "Giant wheels. Barely slowed off-road",
	  color = {120,200,30}, accent = {20,20,20}, top = 66, accel = 28, turn = 1.8, offroad = 0.9, weight = 2.4, stunResist = 0.65, trick = 1.1 },
	{ id = "deck", type = "skateboard", class = "Skateboard", name = "Deckster", kind = "Best handling and tricks, low top speed",
	  color = {250,90,170}, accent = {240,240,240}, top = 60, accel = 45, turn = 3.0, offroad = 0, weight = 0.3, stunResist = 0.9, trick = 1.7 },
	{ id = "atv", type = "atv", class = "Four-wheeler", name = "Mudslinger ATV", kind = "Great all-rounder off the road",
	  color = {210,120,30}, accent = {40,40,40}, top = 68, accel = 34, turn = 2.25, offroad = 0.75, weight = 0.9, stunResist = 0.9, trick = 1.2 },
	-- Robux vehicle: sold as a Roblox Game Pass (700 Robux). Paste the pass ID into
	-- gamePassId (see README). Bots never drive it. Best all-round stats in the game.
	{ id = "nightshade", type = "car", class = "Premium", name = "Nightshade X", kind = "Armored stealth interceptor. Best all-round stats",
	  robux = 700, gamePassId = 0, premium = true,
	  color = {26,24,36}, accent = {52,54,66}, glow = {0,225,255}, top = 84, accel = 38, turn = 2.45, offroad = 0.35, weight = 1.7, stunResist = 0.7, trick = 1.25,
	  cabinZ = -0.05, cabinLen = 0.3, wing = "wing", nose = 1.0, style = "stealth" },
}
-- In Studio play tests, Robux vehicles are unlocked so you can try them.
-- (Real players in the published game still have to buy the Game Pass.)
Config.UNLOCK_ROBUX_VEHICLES_IN_STUDIO = true

-- ---------------------------------------------------------------- items
-- item boxes give a random item; racers further back get stronger items
Config.ITEMS = {
	boost     = { name = "Turbo", color = {255,176,0}, desc = "Speed burst", duration = 1.8 },
	boomerang = { name = "Boomerang", color = {255,220,60}, desc = "Flies ahead and back. Stuns", stun = 1.6 },
	bomb      = { name = "Bomb", color = {40,40,46}, desc = "Drop behind you. Blasts cars", stun = 2.2, radius = 32 },
	rocket    = { name = "Rocket", color = {255,60,50}, desc = "Homes in on the car ahead. Knocks out", stun = 2.6 },
	storm     = { name = "Storm Cloud", color = {90,100,140}, desc = "Lightning strikes everyone else in the race", stun = 2.0 },
}
-- weights by race position: {front of the pack, middle, back}
Config.ITEM_ODDS = {
	front  = { boost = 30, boomerang = 40, bomb = 30, rocket = 0, storm = 0 },
	middle = { boost = 30, boomerang = 30, bomb = 20, rocket = 18, storm = 2 },
	back   = { boost = 38, boomerang = 14, bomb = 5, rocket = 35, storm = 8 },
}

-- ---------------------------------------------------------------- shop
Config.SKINS = {
	{ id = "factory", name = "Factory paint", price = 0 },
	{ id = "camo", name = "Camo", price = 300, color = {86,98,62}, material = "Fabric", camo = { {58,66,40}, {120,104,72}, {40,44,30} } },
	{ id = "carbon", name = "Carbon fibre", price = 350, color = {28,28,30}, material = "Fabric", reflectance = 0.05 },
	{ id = "ice", name = "Glacier", price = 400, color = {170,220,255}, material = "Ice", reflectance = 0.2 },
	{ id = "neon", name = "Neon pink", price = 500, color = {255,60,200}, material = "Neon" },
	{ id = "chrome", name = "Chrome", price = 600, color = {200,205,212}, material = "Metal", reflectance = 0.7 },
	{ id = "lava", name = "Molten lava", price = 700, color = {255,96,20}, material = "CrackedLava" },
	{ id = "gold", name = "Solid gold", price = 800, color = {230,180,40}, material = "Foil", reflectance = 0.45 },
	{ id = "galaxy", name = "Galaxy", price = 900, color = {70,30,140}, material = "Glass", reflectance = 0.3, sparkle = {200,170,255} },
	{ id = "diamond", name = "Diamond", price = 1000, color = {190,240,255}, material = "Glass", reflectance = 0.6, transparency = 0.15, sparkle = {255,255,255} },
	-- daily spin skins (can't be bought; win them on the daily wheel)
	{ id = "crimson", name = "Crimson", spin = "uncommon", color = {196,22,28}, material = "SmoothPlastic", reflectance = 0.25 },
	{ id = "reptile", name = "Reptile Scales", spin = "rare", color = {46,92,40}, material = "Slate", pattern = "scales", tiles = { {80,140,60}, {30,66,28}, {120,160,70} } },
	{ id = "flames", name = "Flames", spin = "epic", color = {28,22,22}, material = "SmoothPlastic", reflectance = 0.2, pattern = "flames" },
	{ id = "goldglow", name = "Gold Glow", spin = "legendary", color = {255,196,40}, material = "Foil", reflectance = 0.55, glow = {255,200,60}, sparkle = {255,220,120} },
	{ id = "blackdiamond", name = "Black Diamond", spin = "mythic", color = {16,16,24}, material = "Glass", reflectance = 0.85, pattern = "facets", tiles = { {40,40,56}, {10,10,16}, {70,60,110} }, sparkle = {255,255,255}, glow = {150,110,255} },
}
Config.TRAILS = {
	{ id = "none", name = "No trail", price = 0 },
	{ id = "smoke", name = "Tyre smoke", price = 150, colors = { {230,230,230}, {160,160,160} }, light = 0, width = 2.6 },
	{ id = "flame", name = "Flame", price = 300, colors = { {255,240,120}, {255,120,20}, {200,30,10} }, light = 1, width = 2 },
	{ id = "frost", name = "Frost", price = 350, colors = { {255,255,255}, {120,210,255} }, light = 0.8, width = 2 },
	{ id = "toxic", name = "Toxic", price = 400, colors = { {200,255,60}, {40,200,60} }, light = 1, width = 2 },
	{ id = "gold", name = "Gold dust", price = 500, colors = { {255,240,160}, {230,170,30} }, light = 1, width = 1.6 },
	{ id = "rainbow", name = "Rainbow", price = 800, colors = { {255,50,50}, {255,160,0}, {255,240,0}, {60,220,80}, {40,140,255}, {170,70,255} }, light = 1, width = 2.2 },
	-- Robux trails: sold as Roblox Game Passes. Make the passes on create.roblox.com
	-- (your experience > Monetization > Passes) and paste each pass ID below. See README.
	{ id = "galaxy", name = "Galaxy", robux = 99, gamePassId = 0, colors = { {255,120,255}, {120,80,255}, {30,200,255}, {10,10,40} }, light = 1, width = 2.6, sparkle = true },
	{ id = "poop", name = "Meme Poop", robux = 49, gamePassId = 0, colors = { {150,95,45}, {110,65,30}, {80,45,20} }, light = 0, width = 2.2, drops = true },
}

-- ---------------------------------------------------------------- tracks
-- points are {x, z, height}: the main loop goes smoothly through them.
-- routes branch off the main loop at point a and rejoin at point b, through the via points.
--   kind = "shortcut" (shorter, usually rougher) or "alt" (different road, often with goodies)
--   surface = "Road", "Dirt" (light slowdown), "Ice" (slippery) or "Water" (slow)
-- pads/ramps/boxes positions are fractions of a lap (0.5 = halfway)
Config.TRACKS = {
	{ id = "coast", name = "Sunset Coast", blurb = "Seaside sweepers, a beach shortcut and a cliff road",
	  theme = "coast", W = 46, SH = 14, scale = 1.8, grip = 1.0, offTop = 0.6,
	  points = {{0,0,0},{150,0,0},{260,40,3},{300,150,8},{240,250,12},{120,260,9},{60,200,5},{-20,260,3},{-160,250,7},{-240,160,5},{-220,40,2},{-120,-10,0}},
	  routes = {
		{ name = "Beach Cut", kind = "shortcut", surface = "Dirt", a = {120,260}, b = {-20,260}, via = {{50,280}}, boxes = {0.5} },
		{ name = "Cliff Road", kind = "alt", surface = "Road", a = {262,45}, b = {245,245}, via = {{318,75},{332,185}}, pads = {0.35, 0.7} },
	  },
	  pads = {{0.1,0},{0.38,-12},{0.64,12},{0.88,0}}, ramps = {{0.5,0}}, boxes = {0.15, 0.45, 0.78}, ice = {},
	  road = {58,58,64}, shoulder = {220,188,140}, shoulderMat = "Sand", kerbA = {229,64,47}, kerbB = {244,239,228},
	  barA = {244,239,228}, barB = {31,111,178}, ground = {225,195,145}, groundMat = "Sand" },
	{ id = "city", name = "Neon City", blurb = "Night streets, a back-alley shortcut and boost pads everywhere",
	  theme = "city", W = 44, SH = 10, scale = 1.75, grip = 1.05, offTop = 0.6,
	  points = {{-200,0,0},{150,0,0},{200,30,1},{200,180,4},{170,210,4},{60,210,4},{30,180,4},{30,110,2},{0,80,1},{-80,80,1},{-110,110,2},{-110,200,5},{-140,230,5},{-220,230,4},{-250,200,3},{-250,40,1},{-230,5,0}},
	  routes = {
		{ name = "Back Alley", kind = "shortcut", surface = "Road", W = 28, a = {30,150}, b = {-110,150}, via = {{-40,140}}, boxes = {0.5} },
		{ name = "Plaza Cut", kind = "shortcut", surface = "Road", W = 30, a = {95,0}, b = {200,110}, via = {{160,55}}, pads = {0.5} },
	  },
	  pads = {{0.04,0},{0.18,10},{0.33,-10},{0.5,0},{0.66,10},{0.8,-10}}, ramps = {{0.42,0}}, boxes = {0.1, 0.36, 0.6, 0.88}, ice = {},
	  road = {36,36,46}, shoulder = {21,21,28}, shoulderMat = "Concrete", kerbA = {255,43,214}, kerbB = {26,26,34},
	  barA = {255,43,214}, barB = {34,230,255}, ground = {20,20,28}, groundMat = "Concrete", neon = true },
	{ id = "frost", name = "Frost Peak", blurb = "Mountain pass with a frozen-lake shortcut and big drifts",
	  theme = "frost", W = 46, SH = 14, scale = 1.85, grip = 0.72, offTop = 0.55,
	  points = {{0,0,0},{120,-30,3},{220,20,7},{240,120,11},{180,200,15},{80,180,14},{40,100,11},{-40,80,9},{-100,160,12},{-200,180,10},{-260,100,6},{-220,-20,3},{-110,-40,0}},
	  routes = {
		{ name = "Frozen Lake", kind = "shortcut", surface = "Ice", W = 40, a = {80,180}, b = {-100,160}, via = {{-10,195}}, boxes = {0.5} },
		{ name = "Ridge Road", kind = "alt", surface = "Road", a = {212,12}, b = {190,190}, via = {{272,62},{275,160}}, pads = {0.5} },
	  },
	  pads = {{0.1,0},{0.55,0},{0.9,10}}, ramps = {{0.2,0},{0.66,0}}, boxes = {0.3, 0.6, 0.85},
	  ice = {{0.3,0,170,38},{0.72,-8,150,34},{0.95,8,100,30}},
	  road = {74,79,90}, shoulder = {238,243,248}, shoulderMat = "Snow", kerbA = {31,95,191}, kerbB = {246,249,252},
	  barA = {246,249,252}, barB = {210,58,58}, ground = {242,246,250}, groundMat = "Snow" },
	{ id = "lava", name = "Lava Canyon", blurb = "Volcanic hairpins and a crater shortcut with no walls",
	  theme = "lava", W = 44, SH = 12, scale = 1.85, grip = 0.95, offTop = 0.38,
	  points = {{0,0,0},{160,-20,2},{260,60,6},{250,170,10},{170,230,9},{110,160,6},{150,90,8},{80,60,5},{-20,120,3},{-60,220,6},{-180,230,8},{-250,140,4},{-230,30,2},{-120,-20,0}},
	  routes = {
		{ name = "Crater Run", kind = "shortcut", surface = "Dirt", W = 30, open = true, a = {-20,125}, b = {-230,30}, via = {{-130,175},{-200,110}}, boxes = {0.5} },
	  },
	  pads = {{0.12,0},{0.4,12},{0.7,-12}}, ramps = {{0.3,0},{0.84,0}}, boxes = {0.2, 0.5, 0.65, 0.92}, ice = {},
	  road = {44,37,36}, shoulder = {255,90,18}, shoulderMat = "Neon", kerbA = {255,106,26}, kerbB = {32,26,25},
	  barA = {255,106,26}, barB = {28,22,21}, ground = {36,22,20}, groundMat = "Basalt" },
	{ id = "lagoon", name = "Lagoon Harbor", blurb = "Water everywhere, a jump over the bay and water cannons to dodge",
	  theme = "water", W = 46, SH = 12, scale = 1.75, grip = 0.98, offTop = 0.6,
	  points = {{0,0,0},{170,-20,0},{290,30,0},{340,140,0},{300,250,0},{190,300,0},{70,270,0},{0,190,0},{-80,170,0},{-150,240,0},{-260,250,0},{-330,160,0},{-300,40,0},{-170,-20,0}},
	  routes = {
		{ name = "Shallows", kind = "shortcut", surface = "Water", W = 34, a = {70,270}, b = {-150,240}, via = {{-40,262}}, boxes = {0.5} },
		{ name = "Pier Road", kind = "alt", surface = "Road", a = {295,35}, b = {300,245}, via = {{368,95},{370,195}}, pads = {0.3, 0.7} },
	  },
	  gaps = {{0.075, 70}},              -- {where, length in studs}: open water you jump over
	  cannons = {{0.27, 5, 22}},         -- {where, how many, samples apart}
	  pads = {{0.16,0},{0.45,10},{0.62,-10},{0.86,0}}, ramps = {}, boxes = {0.2, 0.5, 0.7, 0.93}, ice = {},
	  road = {64,66,74}, shoulder = {40,140,200}, shoulderMat = "Glass", kerbA = {255,255,255}, kerbB = {230,60,50},
	  barA = {255,255,255}, barB = {230,60,50}, ground = {40,140,200}, groundMat = "Glass" },
}

-- ---------------------------------------------------------------- jungle
Config.TRACKS[#Config.TRACKS + 1] = {
	id = "jungle", name = "Jungle Ruins", blurb = "Thick jungle, trees in the road and a hidden cave",
	theme = "jungle", W = 44, SH = 14, scale = 1.75, grip = 0.95, offTop = 0.55,
	points = {{0,0,0},{160,-30,2},{280,10,5},{330,120,8},{290,230,10},{170,270,8},{60,230,5},{-40,250,4},{-160,280,6},{-270,220,5},{-310,100,3},{-250,0,1},{-130,-30,0}},
	routes = {
		{ name = "Hidden Cave", kind = "shortcut", surface = "Dirt", W = 30, cave = true, a = {330,120}, b = {60,230}, via = {{205,170}}, boxes = {0.5} },
	},
	trees = {{0.6, 0.82, 34}},          -- trees standing in the road: {from, to, samples apart}
	pads = {{0.08,0},{0.45,10},{0.9,-10}}, ramps = {{0.94,0}}, boxes = {0.2, 0.5, 0.7}, ice = {},
	road = {124,112,96}, roadMat = "Cobblestone", shoulder = {70,112,42}, shoulderMat = "Grass", kerbA = {214,180,70}, kerbB = {70,58,44},
	barA = {104,80,50}, barB = {62,110,44}, ground = {58,98,38}, groundMat = "Grass",
}

-- make every road wider and every lap a little longer (keeps all the numbers above simple)
for _, t in ipairs(Config.TRACKS) do
	local w, l = Config.TRACK_WIDTH_SCALE, Config.TRACK_LENGTH_SCALE
	t.W = math.floor(t.W * w + 0.5)
	t.SH = math.floor(t.SH * 1.25 + 0.5)
	t.scale = t.scale * l
	for _, r in ipairs(t.routes or {}) do
		if r.W then r.W = math.floor(r.W * w + 0.5) end
	end
	for _, pd in ipairs(t.pads or {}) do pd[2] = pd[2] * w end
	for _, rp in ipairs(t.ramps or {}) do rp[2] = rp[2] * w end
	for _, ic in ipairs(t.ice or {}) do
		ic[2] = ic[2] * w
		ic[3] = ic[3] * l
		ic[4] = ic[4] * w
	end
	for _, g in ipairs(t.gaps or {}) do g[2] = g[2] * l end
end

-- ---------------------------------------------------------------- daily spin
-- One free spin per day (resets at midnight UTC). Chances are weights, so they don't
-- have to add up to 100. If you win a skin you already own, you get coins instead.
Config.SPIN_TIERS = {
	{ id = "uncommon",  name = "Uncommon",  color = {60,200,90},  chance = 60,  skin = "crimson",      dupeCoins = 100 },
	{ id = "rare",      name = "Rare",      color = {60,140,255}, chance = 30,  skin = "reptile",      dupeCoins = 200 },
	{ id = "epic",      name = "Epic",      color = {170,80,255}, chance = 5,   skin = "flames",       dupeCoins = 500 },
	{ id = "legendary", name = "Legendary", color = {255,196,40}, chance = 2,   skin = "goldglow",     dupeCoins = 1000 },
	{ id = "mythic",    name = "Mythic",    color = {235,40,50},  chance = 0.1, skin = "blackdiamond", dupeCoins = 5000 },
}
function Config.spinTier(id)
	for _, t in ipairs(Config.SPIN_TIERS) do
		if t.id == id then return t end
	end
	return Config.SPIN_TIERS[1]
end

-- surfaces: how much they cap top speed (before the vehicle's off-road skill helps)
Config.SURFACES = {
	Road = 1, Ramp = 1, Ice = 1, Dirt = 0.8, Water = 0.45,
}

local function find(list, id)
	for _, x in ipairs(list) do
		if x.id == id then return x end
	end
	return nil
end
function Config.getVehicle(id) return find(Config.VEHICLES, id) or Config.VEHICLES[2] end
Config.getCar = Config.getVehicle
function Config.getTrack(id) return find(Config.TRACKS, id) or Config.TRACKS[1] end
function Config.getSkin(id) return find(Config.SKINS, id) or Config.SKINS[1] end
function Config.getTrail(id) return find(Config.TRAILS, id) or Config.TRAILS[1] end
-- everything sold for Robux (vehicles first, then trails); shopKind says which
function Config.robuxItems()
	local list = {}
	for _, v in ipairs(Config.VEHICLES) do
		if v.robux then v.shopKind = "vehicle"; list[#list + 1] = v end
	end
	for _, t in ipairs(Config.TRAILS) do
		if t.robux then t.shopKind = "trail"; list[#list + 1] = t end
	end
	return list
end
-- coins for finishing in `place` out of `field` racers: an even step down from
-- FIRST_PLACE_COINS for the winner to 0 for last place (8 racers: 150, 129, 107, 86, 64, 43, 21, 0)
function Config.placeCoins(place, field)
	if field <= 1 then return Config.FIRST_PLACE_COINS end
	local share = (field - place) / (field - 1)
	return math.floor(Config.FIRST_PLACE_COINS * math.clamp(share, 0, 1) + 0.5)
end
-- vehicles anyone can drive (and bots use)
function Config.freeVehicles()
	local list = {}
	for _, v in ipairs(Config.VEHICLES) do
		if not v.robux then list[#list + 1] = v end
	end
	return list
end

return Config
