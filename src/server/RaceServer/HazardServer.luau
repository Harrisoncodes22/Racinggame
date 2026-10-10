-- HazardServer: the water cannons on Lagoon Harbor. Each cannon glows as a
-- warning, then fires a jet of water across the road. Get caught and you are
-- shoved sideways and slowed for a moment.

local Hazards = {}

local PERIOD = 3.4
local WARN_END = 1.0
local FIRE_END = 2.2

-- cannons: from TrackBuilder; racers: list; now: os.clock();
-- hitFn(racer, pushVector) applies the splash
function Hazards.update(cannons, tr, racers, now, hitFn)
	for _, c in ipairs(cannons) do
		local tc = (now + c.phase) % PERIOD
		local state = "idle"
		if tc < WARN_END then state = "warn" elseif tc < FIRE_END then state = "fire" end
		if state ~= c.state then
			c.state = state
			if state == "warn" then
				c.jet.Transparency = 0.9
				c.spray.Enabled = false
				c.hit = {}
			elseif state == "fire" then
				c.jet.Transparency = 0.3
				c.spray.Enabled = true
			else
				c.jet.Transparency = 1
				c.spray.Enabled = false
			end
		end
		if state == "warn" then
			local blink = (math.floor(tc * 8) % 2 == 0)
			if c.blink ~= blink then
				c.blink = blink
				c.nozzle.Transparency = blink and 0 or 0.6
			end
		elseif c.blink ~= nil then
			c.blink = nil
			c.nozzle.Transparency = 0
		end
		if state == "fire" then
			local jcf, size = c.jet.CFrame, c.jet.Size
			for _, r in ipairs(racers) do
				if not r.gone and r.body.Parent and not c.hit[r] then
					local lp = jcf:PointToObjectSpace(r.body.Position)
					if math.abs(lp.X) < size.X / 2 and math.abs(lp.Y) < 6 and math.abs(lp.Z) < 4.5 then
						c.hit[r] = true
						local s = tr.S[c.i]
						hitFn(r, -s * (c.side * 70) + Vector3.new(0, 14, 0))
					end
				end
			end
		end
	end
end

function Hazards.reset(cannons)
	for _, c in ipairs(cannons) do
		c.state = nil
		c.hit = {}
	end
end

return Hazards
