-- ItemServer: item boxes, random items and everything they do.
--   Turbo      - speed burst
--   Boomerang  - flies ahead along the track and back, stuns whoever it touches
--   Bomb       - dropped behind you, explodes when someone drives close, blasts everyone nearby
--   Rocket     - homes in on the racer one place ahead and knocks them out
-- Projectiles live on the server so every player sees the same thing.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VelocityCup")
local Config = require(Shared:WaitForChild("RaceConfig"))
local TrackMath = require(Shared:WaitForChild("TrackMath"))

-- Each race gets its own item system (Items.new), so races can run side by side.
local Factory = {}

function Factory.new()
	local Items = {}
	local UP = Vector3.new(0, 1, 0)
	local ctx = nil          -- set by Items.start
	local projectiles = {}

	local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end

	local function newPart(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if props.Shape then p.Shape = props.Shape end
		for k, v in pairs(props) do
			if k ~= "Shape" then p[k] = v end
		end
		p.Parent = ctx.folder
		return p
	end

	local function boom(pos, radius)
		local e = Instance.new("Explosion")
		e.Position = pos
		e.BlastRadius = radius
		e.BlastPressure = 0
		e.DestroyJointRadiusPercent = 0
		e.ExplosionType = Enum.ExplosionType.NoCraters
		e.Parent = workspace
	end

	-- ctx: { tr, getRacers(), standings(), applyStun(r, dur, kind, by), applyBoost(r, dur), notify(r, text) }
	function Items.start(context)
		ctx = context
		projectiles = {}
		local f = Instance.new("Folder")
		f.Name = ctx.folderName or "VCProjectiles"
		f.Parent = workspace
		ctx.folder = f
	end

	function Items.stop()
		for _, p in ipairs(projectiles) do
			if p.part then p.part:Destroy() end
		end
		projectiles = {}
		if ctx and ctx.folder then ctx.folder:Destroy() end
		ctx = nil
	end

	local function pickItem(r)
		local list = ctx.standings()
		local place = table.find(list, r) or #list
		local frac = (#list <= 1) and 0 or (place - 1) / (#list - 1)
		local odds = Config.ITEM_ODDS.middle
		if frac < 0.34 then odds = Config.ITEM_ODDS.front elseif frac > 0.66 then odds = Config.ITEM_ODDS.back end
		local total = 0
		for _, w in pairs(odds) do total = total + w end
		local roll = math.random() * total
		local order = { "boost", "boomerang", "bomb", "rocket", "storm" }
		for _, id in ipairs(order) do
			roll = roll - (odds[id] or 0)
			if roll <= 0 then return id end
		end
		return "boost"
	end

	function Items.give(r)
		if r.item or r.finished then return end
		r.item = pickItem(r)
		r.itemT = 0
		if r.model then r.model:SetAttribute("Item", r.item) end
	end

	-- item boxes (from TrackBuilder). Called every frame.
	function Items.updateBoxes(boxes, dt)
		if not ctx then return end
		local racers = ctx.getRacers()
		for _, b in ipairs(boxes) do
			if b.active then
				local pos = b.part.Position
				for _, r in ipairs(racers) do
					if not r.gone and r.body.Parent and (r.body.Position - pos).Magnitude < 9.5 then
						b.active = false
						b.t = 3
						b.part.Transparency = 1
						b.core.Transparency = 1
						b.gui.Enabled = false
						b.light.Enabled = false
						Items.give(r)
						break
					end
				end
			else
				b.t = b.t - dt
				if b.t <= 0 then
					b.active = true
					b.part.Transparency = 0.3
					b.core.Transparency = 0.2
					b.gui.Enabled = true
					b.light.Enabled = true
				end
			end
		end
	end

	local function forwardOf(r)
		local lv = r.body.CFrame.LookVector
		local f = Vector3.new(lv.X, 0, lv.Z)
		if f.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
		return f.Unit
	end

	function Items.use(r)
		if not ctx then return end
		if not r.item or r.gone or not r.body.Parent then return end
		if r.stunUntil and os.clock() < r.stunUntil then return end
		local id = r.item
		r.item = nil
		if r.model then r.model:SetAttribute("Item", nil) end
		local tr = ctx.tr
		local pos = r.body.Position
		if id == "boost" then
			ctx.applyBoost(r, Config.ITEMS.boost.duration)
		elseif id == "boomerang" then
			local part = newPart({ Name = "Boomerang", Size = Vector3.new(4.5, 0.5, 1.4), Color = rgb(Config.ITEMS.boomerang.color), Material = Enum.Material.Neon, CFrame = CFrame.new(pos + UP * 2.5) })
			local wing = newPart({ Name = "BoomerangWing", Size = Vector3.new(1.4, 0.5, 4.5), Color = rgb(Config.ITEMS.boomerang.color), Material = Enum.Material.Neon, CFrame = part.CFrame * CFrame.new(-1.55, 0, 1.55) })
			wing.Parent = part
			projectiles[#projectiles + 1] = { kind = "boomerang", owner = r, part = part, wing = wing, f = r.idx or 1, lat = math.clamp(r.lat or 0, -tr.W / 2 + 4, tr.W / 2 - 4), t = 0, out = true, pos = pos + UP * 2.5, hits = {}, nhits = 0 }
		elseif id == "rocket" then
			local list = ctx.standings()
			local place = table.find(list, r) or 1
			local target = nil
			for k = place - 1, 1, -1 do
				local c = list[k]
				if c and not c.finished and not c.gone then target = c; break end
			end
			local part = newPart({ Name = "Rocket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.4, 1.4), Color = rgb(Config.ITEMS.rocket.color), Material = Enum.Material.Neon, CFrame = CFrame.new(pos + UP * 3) })
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 0
			fire.Parent = part
			projectiles[#projectiles + 1] = { kind = "rocket", owner = r, target = target, part = part, f = r.idx or 1, lat = r.lat or 0, t = 0, pos = pos + UP * 3 }
			if target then ctx.notify(target, "ROCKET INCOMING!") end
		elseif id == "storm" then
			-- a storm cloud over every other racer: lightning stuns them all
			local victims = {}
			for _, o in ipairs(ctx.getRacers()) do
				if o ~= r and not o.gone and not o.finished and o.body.Parent then
					local cloud = newPart({ Name = "StormCloud", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 5, 9), Color = Color3.fromRGB(70, 74, 92), Material = Enum.Material.SmoothPlastic, Transparency = 0.1, CFrame = CFrame.new(o.body.Position + UP * 14) })
					for _, off in ipairs({ Vector3.new(-3.5, -0.5, 1), Vector3.new(3.5, -0.3, -1), Vector3.new(0, 1.2, 0) }) do
						local puff = newPart({ Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 4.5, 6), Color = Color3.fromRGB(60, 64, 80), Material = Enum.Material.SmoothPlastic, Transparency = 0.1, CFrame = cloud.CFrame * CFrame.new(off) })
						puff:SetAttribute("Offset", off)
						puff.Parent = cloud
					end
					local bolt = newPart({ Name = "Lightning", Size = Vector3.new(0.6, 12, 0.6), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon, CFrame = CFrame.new(o.body.Position + UP * 7) })
					bolt.Parent = cloud
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(200, 210, 255)
					light.Range = 30
					light.Brightness = 4
					light.Parent = bolt
					victims[#victims + 1] = { r = o, cloud = cloud, bolt = bolt }
					ctx.applyStun(o, Config.ITEMS.storm.stun, "lightning", r)
				end
			end
			projectiles[#projectiles + 1] = { kind = "storm", owner = r, victims = victims, t = 0, part = nil }
			ctx.notify(r, "Storm cloud! Everyone else got zapped")
		elseif id == "bomb" then
			local back = pos - forwardOf(r) * 10
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { workspace:FindFirstChild("VCCars"), ctx.folder }
			params.RespectCanCollide = true
			local hit = workspace:Raycast(back + UP * 6, Vector3.new(0, -30, 0), params)
			local gy = hit and hit.Position.Y or (back.Y - 1)
			local part = newPart({ Name = "Bomb", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Color = rgb(Config.ITEMS.bomb.color), Material = Enum.Material.SmoothPlastic, Position = Vector3.new(back.X, gy + 1.6, back.Z) })
			local fuse = newPart({ Name = "Fuse", Size = Vector3.new(0.5, 1, 0.5), Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon, Position = part.Position + UP * 1.9 })
			fuse.Parent = part
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(255, 200, 80)
			sp.Parent = fuse
			projectiles[#projectiles + 1] = { kind = "bomb", owner = r, part = part, fuse = fuse, t = 0, pos = part.Position }
		end
	end

	local function explodeBomb(p)
		local radius = Config.ITEMS.bomb.radius
		boom(p.pos, radius)
		for _, r in ipairs(ctx.getRacers()) do
			if not r.gone and r.body.Parent and (r.body.Position - p.pos).Magnitude < radius then
				ctx.applyStun(r, Config.ITEMS.bomb.stun, "blast", p.owner)
			end
		end
		p.dead = true
	end

	function Items.update(dt)
		if not ctx then return end
		local tr = ctx.tr
		local racers = ctx.getRacers()
		for _, p in ipairs(projectiles) do
			if not p.dead then
				p.t = p.t + dt
				if p.kind == "boomerang" then
					if p.out then
						p.f = p.f + 280 * dt / tr.seg
						local pt, _, s = TrackMath.pointAt(tr, p.f)
						p.pos = pt + s * p.lat + UP * 2.5
						if p.t > 1.4 then p.out = false end
					else
						local o = p.owner
						if o.gone or not o.body.Parent then p.dead = true else
							local d = (o.body.Position + UP * 2) - p.pos
							if d.Magnitude < 8 then p.dead = true else p.pos = p.pos + d.Unit * math.min(d.Magnitude, 330 * dt) end
						end
					end
					p.part.CFrame = CFrame.new(p.pos) * CFrame.Angles(0, p.t * 18, 0)
					p.wing.CFrame = p.part.CFrame * CFrame.new(-1.55, 0, 1.55)
					for _, r in ipairs(racers) do
						if r ~= p.owner and not p.hits[r] and not r.gone and r.body.Parent and (r.body.Position - p.pos).Magnitude < 10 then
							p.hits[r] = true
							p.nhits = p.nhits + 1
							ctx.applyStun(r, Config.ITEMS.boomerang.stun, "stun", p.owner)
							if p.nhits >= 2 then p.dead = true end
						end
					end
					if p.t > 4 then p.dead = true end
				elseif p.kind == "rocket" then
					local tg = p.target
					local speed = 340
					if tg and (tg.gone or not tg.body.Parent or tg.finished) then tg = nil; p.target = nil end
					if tg then
						local tp = tg.body.Position
						local ahead = ((tg.idx or 1) - p.f) % tr.N
						if (tp - p.pos).Magnitude < 70 or ahead < 12 or ahead > tr.N - 40 then
							local d = tp - p.pos
							p.pos = p.pos + d.Unit * math.min(d.Magnitude, speed * dt)
						else
							p.f = p.f + speed * dt / tr.seg
							p.lat = p.lat + ((tg.lat or 0) - p.lat) * math.min(1, dt * 2)
							local pt, _, s = TrackMath.pointAt(tr, p.f)
							p.pos = pt + s * math.clamp(p.lat, -tr.W / 2, tr.W / 2) + UP * 3
						end
						if (tp - p.pos).Magnitude < 9 then
							boom(p.pos, 10)
							ctx.applyStun(tg, Config.ITEMS.rocket.stun, "knockout", p.owner)
							p.dead = true
						end
					else
						p.f = p.f + speed * dt / tr.seg
						local pt, _, s = TrackMath.pointAt(tr, p.f)
						p.pos = pt + s * p.lat + UP * 3
						if p.t > 3 then boom(p.pos, 10); p.dead = true end
					end
					local _, tdir = TrackMath.pointAt(tr, p.f)
					p.part.CFrame = CFrame.lookAt(p.pos, p.pos + tdir) * CFrame.Angles(0, math.pi / 2, 0)
					if p.t > 9 then boom(p.pos, 10); p.dead = true end
				elseif p.kind == "storm" then
				for _, v in ipairs(p.victims) do
					if v.r.body.Parent then
						local pos = v.r.body.Position
						v.cloud.CFrame = CFrame.new(pos + UP * 14)
						for _, ch in ipairs(v.cloud:GetChildren()) do
							if ch.Name == "Puff" then ch.CFrame = v.cloud.CFrame * CFrame.new(ch:GetAttribute("Offset") or Vector3.new()) end
						end
						v.bolt.CFrame = CFrame.new(pos + UP * 7) * CFrame.Angles(0, p.t * 9, math.sin(p.t * 30) * 0.2)
						v.bolt.Transparency = (math.floor(p.t * 12) % 3 == 0) and 0.8 or 0
					end
				end
				if p.t > Config.ITEMS.storm.stun then
					for _, v in ipairs(p.victims) do v.cloud:Destroy() end
					p.dead = true
				end
			elseif p.kind == "bomb" then
					p.fuse.Transparency = (math.floor(p.t * 6) % 2 == 0) and 0 or 0.7
					if p.t > 0.6 then
						for _, r in ipairs(racers) do
							if not r.gone and r.body.Parent and (r ~= p.owner or p.t > 1.5) and (r.body.Position - p.pos).Magnitude < 15 then
								explodeBomb(p)
								break
							end
						end
					end
					if not p.dead and p.t > 15 then explodeBomb(p) end
				end
				if p.dead and p.part then p.part:Destroy() end
			end
		end
		local alive = {}
		for _, p in ipairs(projectiles) do
			if not p.dead then alive[#alive + 1] = p end
		end
		projectiles = alive
	end

	-- simple bot item tactics
	function Items.botThink(r, dt)
		if not ctx then return end
		if not r.item then return end
		r.itemT = (r.itemT or 0) + dt
		local id = r.item
		local tr = ctx.tr
		local use = false
		if id == "boost" then
			use = r.itemT > 0.8 and math.random() < 0.02
		elseif id == "boomerang" then
			for _, o in ipairs(ctx.getRacers()) do
				local gap = (o.total - r.total) * tr.seg
				if o ~= r and not o.gone and gap > 20 and gap < 260 then use = true; break end
			end
			use = use or r.itemT > 7
		elseif id == "rocket" then
			use = r.itemT > 1.5 and math.random() < 0.03
		elseif id == "storm" then
			use = r.itemT > 1 and math.random() < 0.02
		elseif id == "bomb" then
			for _, o in ipairs(ctx.getRacers()) do
				local gap = (r.total - o.total) * tr.seg
				if o ~= r and not o.gone and gap > 15 and gap < 200 then use = true; break end
			end
			use = use or r.itemT > 9
		end
		if use then Items.use(r) end
	end
	return Items
end

return Factory
