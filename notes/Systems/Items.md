---
tags: [velocity-cup, system, server]
---
# Items

Back to [[Home]] · Code: `src/server/RaceServer/ItemServer.luau`

Drive through a **?** box to get a random item (one at a time). Boxes respawn after 3 s. Press **E / F / X** to use it. All projectiles run on the server so every player sees the same thing.

| Item | What it does | Numbers (`Config.ITEMS`) |
|---|---|---|
| Turbo | speed burst | 1.8 s |
| Boomerang | flies ahead along the road, then back to you; stuns up to 2 racers | stun 1.6 s |
| Bomb | dropped behind; arms after 0.6 s, explodes when someone gets close | stun 2.2 s, radius 32 |
| Rocket | homes in on the racer one place ahead | knockout 2.6 s |
| Storm Cloud | zaps everyone else in the race | stun 2.0 s |

## Odds by position (`Config.ITEM_ODDS`)
| | Turbo | Boomerang | Bomb | Rocket | Storm |
|---|---|---|---|---|---|
| Front third | 30 | 40 | 30 | 0 | 0 |
| Middle | 30 | 30 | 20 | 18 | 2 |
| Back third | 38 | 14 | 5 | 35 | 8 |
(weights, not percentages)

## Rules
- After a stun you're immune for 1 s, so hits can't chain.
- Each hit you land is worth `HIT_COINS` (10) at the end of the race.
- Boomerangs and rockets fired from a shortcut now follow the shortcut, then carry on along the main road (they used to snap back to the main road).
- Bots use items with simple rules in `Items.botThink` (boomerang when someone is 20–260 studs ahead, bomb when someone is close behind…).

Related: [[Race Flow]] · [[Tuning Cheatsheet]]
