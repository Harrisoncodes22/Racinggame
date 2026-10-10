---
tags: [velocity-cup, guide, config]
---
# Tuning Cheatsheet

Back to [[Home]] · File: `src/shared/VelocityCup/RaceConfig.luau`

Change a number, play-test, repeat. Colours are `{r, g, b}` 0–255.

## Race
| Setting | Now | Effect |
|---|---|---|
| `LAPS` | 3 | laps per race |
| `MAX_RACERS` | 8 | grid size (bots fill empty spots) |
| `FINISH_GRACE` | 30 | seconds others get after the first human finishes |
| `MAX_RACE_TIME` | 480 | hard cap |
| `RESULTS_TIME` | 12 | results screen length |
| `TRACK_SLOTS` | 9 | races running at once per server |
| `MAX_ROOMS` / `ROOM_SIZE` | 4 / 8 | waiting rooms |

## Feel
| Setting | Now | Effect |
|---|---|---|
| `SPEED_SCALE` | 1.12 | global speed multiplier |
| `VEHICLE_SCALE` | 1.35 | vehicle size (not the skateboard) |
| `TRACK_WIDTH_SCALE` / `TRACK_LENGTH_SCALE` | 1.35 / 1.15 | wider roads / longer laps |
| `SURFACES` | Dirt 0.8, Water 0.45 | top-speed factor per surface |
| per-track `grip` | 0.72–1.05 | Frost Peak is the slippery one |
| `AIR_GRAVITY` (CarController) | 75 | lower = floatier jumps |

## Vehicles (`Config.VEHICLES`)
`top` speed · `accel` · `turn` · `offroad` (0–1) · `weight` (shoving) · `stunResist` (lower = shorter stuns) · `trick` (trick boost multiplier). Garage stat bars are scaled for `top` 54–82, `accel` 22–46, `turn` 1.6–3.05.

## Economy
| Setting | Now |
|---|---|
| `START_COINS` | 350 |
| `FIRST_PLACE_COINS` | 150 — winner's coins; each place below gets an even step less, last place 0 (8 racers: 150, 129, 107, 86, 64, 43, 21, 0) |
| `HIT_COINS` | 10 |
| `SKINS[].price`, `TRAILS[].price` | 150–1000 |
| `SPIN_TIERS[].chance` | weights (see [[Monetization]]) |

## Items
`Config.ITEMS` (durations, stun times, bomb radius) and `Config.ITEM_ODDS` — see [[Items]].

> [!tip]
> Bumping `top` or `SPEED_SCALE` automatically raises the [[Anti-Cheat]] speed budget too — it is computed from the same numbers.
