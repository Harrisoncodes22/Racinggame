---
tags: [velocity-cup, guide, tracks]
---
# Add a Track

Back to [[Home]] · Background: [[Tracks]]

1. Copy an existing entry in `Config.TRACKS` (e.g. the jungle block at the bottom) and give it a new `id`, `name`, `blurb`.
2. **Points**: `{x, z, height}` in design units, going around the loop in driving order. ~12–17 points works well. Keep corners gentle — the spline smooths them, but very sharp angles make hairpins the cars can't take.
3. Pick a `theme` that exists in `Themes.presets` (`coast`, `city`, `frost`, `lava`, `water`, `jungle`) or add a new preset there.
4. Colours/materials: `road`, `shoulder`, `shoulderMat`, `kerbA/B`, `barA/B`, `ground`, `groundMat`.
5. Features: `pads`, `ramps`, `boxes`, optional `ice`, `gaps`, `cannons`, `trees`. Positions are **fractions of a lap** (0.5 = halfway); `TrackMath.straightIndex` nudges them to the straightest nearby spot and away from route junctions.
6. Routes: `a` and `b` are design-unit points near the main line where the route leaves and rejoins; `via` points shape it. Use `kind = "shortcut"` for secret ones.
7. Play-test: drive it, take every route, check the minimap and that respawns land on the road.

> [!warning] Keep tracks inside a slot
> Slots are 10,000 studs apart. With `K` = 2.5 and `scale` ≈ 2, keep coordinates within about ±400 design units so the ground and scenery of neighbouring races never overlap.

New tracks show up automatically in the map picker, room picker and leaderboard tabs.
