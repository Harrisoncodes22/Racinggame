---
tags: [velocity-cup, system]
---
# Tracks

Back to [[Home]] · Code: `TrackMath.luau` (shared), `TrackBuilder.luau` (server)

## From points to a circuit
1. Each track in `Config.TRACKS` lists control points `{x, z, height}`.
2. `TrackMath.build` scales them (`scale × K`), runs a **centripetal Catmull-Rom** spline through them and resamples it into `SAMPLES` = 1600 evenly spaced points `P`, with direction `T` and right-hand side `S` per point.
3. **Routes** (shortcuts / alt roads) branch off at the main-line point nearest `a` and rejoin nearest `b`, curving through `via`. Where a route runs beside the main road it is blended to the same height so the roads don't poke through each other.
4. `TrackBuilder.build` lays parts along the samples: road, kerbs, shoulders, walls (with hidden gaps where a secret shortcut leaves), pads, ramps, item boxes, ice, trees, cannons, scenery.

## Track features (all in `RaceConfig`)
| Field | Meaning |
|---|---|
| `W`, `SH` | road width, shoulder width (scaled up by `TRACK_WIDTH_SCALE`) |
| `grip`, `offTop` | grip multiplier; top-speed factor on the shoulder |
| `pads` `{frac, lat}` | boost pads at a fraction of the lap, sideways offset |
| `ramps`, `boxes`, `ice`, `gaps`, `cannons`, `trees` | see comments in `RaceConfig` |
| `routes[].kind` | `"shortcut"` (secret: hidden wall, not on minimap until found) or `"alt"` (signposted) |
| `routes[].surface` | `Road`, `Dirt`, `Ice`, `Water` |
| `open`, `cave` | route with no walls / a tunnel through a hill |

## Locating a car
`TrackMath.locateAll(tr, pos, hint…)` returns the nearest main-line index (or route + sample mapped back to a main-line index), the sideways offset and direction. With a hint it only scans ±45 samples. Routes now carry a bounding box, so routes far from the car are skipped entirely (same results, less work).

## Current maps
Sunset Coast · Neon City · Frost Peak · Lava Canyon · Lagoon Harbor · Jungle Ruins

Related: [[Add a Track]] · [[Driving Physics]] · [[Items]]
