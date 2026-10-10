---
tags: [velocity-cup, system, client]
---
# UI

Back to [[Home]] · Code: `src/client/RaceClient/` (`Hub.luau`, `Hud.luau`, `UIKit.luau`)

All screens are built in code with `UIKit` helpers (`UI.make`, `UI.label`, `UI.button`, `UI.panel`) and one shared palette (`UI.YELLOW`, `UI.INK`, …). A `UIScale` keeps them readable from phone to monitor.

## Hub (server room)
Bottom bar: **Daily Spin · Garage · Shop · Leaderboard**. Walking up to the red/blue arches, the shop counter, the leaderboard stand or a vehicle pedestal and pressing **E** opens the same screens (ProximityPrompts carry a `Menu` or `Vehicle` attribute).
- Garage: 3D preview in a ViewportFrame, stat bars.
- Shop: Skins / Trails / Robux tabs.
- Rooms list + waiting-room panel (ready / start / bots toggle / invite).

## Race HUD
Place, lap, timer, speed (km/h = studs/s × `SPEED_TO_KMH`), drift meter, held item, minimap (secret shortcuts appear once found), live standings, stun banner, wrong-way banner (shows the reset control for your device), results table.

## Controls
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Drive / steer | WASD / arrows | RT / LT / stick | thumbstick (auto-throttle) |
| Drift / trick | Space | R1 / L1 | Drift button |
| Use item | E / F | X | Item button |
| Reset | R | Y | Reset button (3 s cooldown) |

Related: [[Race Flow]] · [[Monetization]]
