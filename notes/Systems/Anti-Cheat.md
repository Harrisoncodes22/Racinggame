---
tags: [velocity-cup, system, server, security]
---
# Anti-Cheat

Back to [[Home]]

Rule of thumb: **the client is untrusted**. Anything a client sends can be faked by an exploiter.

## What clients can send — and the checks
| Remote | Server check |
|---|---|
| `ChooseCar` | vehicle id exists; Robux vehicles need the game pass |
| `StartSolo`, `CreateRoom`, `RoomSetTrack` | track id exists; not already racing; host-only where relevant |
| `JoinRoom` | whole number 1–`MAX_ROOMS`, room open and not full |
| `RoomStart` | host only; everyone ready |
| `UseItem` | you're in a racing session and actually hold an item |
| `Shop` | kind/id are strings; item exists; enough coins; not a Robux/spin-only item; rate-limited |
| `DailySpin` | once per UTC day; rate-limited |
| `GetLeaderboard` | track id exists; rate-limited; shared cache so spam can't hammer DataStores |

Coins, unlocks, items, hits, places and lap times are all decided by the server.

## The one big trust: your car's physics
Your device owns your car's physics (otherwise driving would feel laggy). An exploiter could therefore move their car anywhere. Defence:

- **Speed budget on lap progress.** Each player has a budget that refills at their vehicle's *boosted top speed × 1.25* and holds up to 2.5 s worth. Forward progress spends it; progress beyond the budget is ignored (and logged once with `warn`). On a shortcut the cost is scaled by how much lap distance the shortcut saves (`route.mainPerStud`).
- Result: teleporting or speed-hacking can't skip laps or set impossible leaderboard times. Tested in a simulation on all 6 maps: an honest player who is *always* boosting, hugging the inside line, with choppy network updates, never loses any progress; a teleporter is held to ~360 studs/s.
- Lap progress jumps over 150 samples in one tick are ignored entirely (old rule, kept).

## Not covered (yet)
- A cheater can still drive at the budget's limit (faster than a legit player's average). Tighter checks (e.g. comparing against the server's own estimate) are on the [[Roadmap]].
- Client-side effects (camera, HUD) are cosmetic and don't matter.

Related: [[Race Flow]] · [[Data and Saving]]
