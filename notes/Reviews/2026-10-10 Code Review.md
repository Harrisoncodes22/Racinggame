---
tags: [velocity-cup, review, changelog]
date: 2026-10-10
---
# 2026-10-10 Code Review

Back to [[Home]]

Full read-through of VelocityCup v7 (15 scripts, ~6,200 lines). Overall the code is in good shape: clear structure, good comments, solid validation on most remotes, and it type-checks cleanly. The problems were concentrated in **saving**, **trusting the client's car position**, and a few edge cases.

## 🔴 Critical
- **Save data could be wiped.** If loading a profile failed (DataStore hiccup), the player got a starter profile that was then autosaved over their real data. → Unloaded profiles are now never saved. [[Data and Saving]]
- **No session locking.** A fast rejoin onto another server could load stale data and the two servers would overwrite each other. → `UpdateAsync` session lock with takeover for crashed servers.
- **Lap skipping / fake leaderboard times.** The player's device owns their car, and the server counted any movement under 150 samples per tick as progress. → Speed budget on lap progress. [[Anti-Cheat]]

## 🟠 Bugs
- Player who left during profile loading leaked a profile (and would have held the lock). → Released properly.
- Save spam: several writes per second per player (buy + equip + PB laps) could hit DataStore throttling. → Batched saves, no save per PB lap.
- Shutdown saved players one after another (could run out of time). → Parallel.
- A player who couldn't be seated, or was dead at race start, stayed "in" the race (stuck UI) until it ended. → Sent back to the hub.
- Boomerangs/rockets fired on a shortcut snapped onto the main road. → Follow the route.
- Daily-spin screen showed weights as percentages (they added to 97.1 %). → Real percentages.
- `JoinRoom` accepted any number. → Whole numbers 1–4 only.

## 🟡 Improvements
- AFK players got place coins just for sitting on the grid. → Need ≥ 1 lap.
- Rate limits on `Shop`, `DailySpin`, `GetLeaderboard`; leaderboard refreshes are shared, names fetched in one batch (`GetUserInfosByUserIdsAsync`) instead of up to 50 calls.
- Route bounding boxes: per-frame track lookups skip far-away routes (checked: identical results on 72,000 random positions).
- 3 s cooldown on manual reset; wrong-way banner shows R / Y / tap depending on device.
- Small cleanups (unused variables, misplaced comment, mis-indented block).

## How it was checked
- `luau-lsp analyze` (Roblox types + Rojo sourcemap) before and after: no new warnings.
- Every script compiles with `luau-compile`.
- `TrackMath` run outside Roblox with a Vector3 stand-in: old vs new `locateAll` compared on 72k positions across all 6 maps × 3 slots.
- Anti-cheat simulated on all maps, all lanes, choppy network updates and every route: honest always-boosted driving lost 0 studs; teleporting capped at ~360 studs/s.
- **Not yet play-tested in Studio** — run the [[Testing Checklist]].

Next: [[Roadmap]]
