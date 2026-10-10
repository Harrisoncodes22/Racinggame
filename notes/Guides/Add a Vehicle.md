---
tags: [velocity-cup, guide, vehicles]
---
# Add a Vehicle

Back to [[Home]]

1. Add an entry to `Config.VEHICLES` with a unique `id`, `name`, `class`, `kind` (one-line description), `color`, `accent` and stats (`top`, `accel`, `turn`, `offroad`, `weight`, `stunResist`, `trick`).
2. `type` decides the body that `VehicleBuilder` builds: `car`, `kart`, `bicycle`, `motorcycle`, `truck`, `monster`, `skateboard`, `atv`. Cars also take `cabinZ`, `cabinLen`, `wing` (`"wing"`, `"lip"`, `"none"`), `nose`, optional `twoTone`, `style = "stealth"`.
3. A brand-new body type needs a size/ride height in `VB.TYPES` and a build branch in `VehicleBuilder.build` (mark painted parts with the `P(...)` helper so skins apply).
4. Robux vehicle? Add `robux = <price>`, `gamePassId = <pass id>`, `premium = true` — see [[Monetization]]. Bots never drive Robux vehicles.

It appears on a hub pedestal, in the garage and (for bots) on the grid automatically.

Related: [[Driving Physics]] · [[Tuning Cheatsheet]]
