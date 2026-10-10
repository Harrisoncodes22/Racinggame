---
tags: [velocity-cup, system, server, datastore]
---
# Data and Saving

Back to [[Home]] · Code: `src/server/RaceServer/DataService.luau`

## What is saved (DataStore `VelocityCup_Profiles_v1`, key `u_<UserId>`)
`coins`, owned `skins` / `trails` / `vehicles`, equipped `skin` / `trail`, personal best laps `best[trackId]` (ms), `lastSpin` (day number), plus a `lock`.

Leaderboards: one OrderedDataStore per track, `VelocityCup_Laps_v1_<trackId>`, value = best lap in ms. Top 50, cached 30 s.

## Safety rules
> [!important] A profile that failed to load is never saved
> Before the review, if loading failed 3 times the player got a fresh starter profile **and it was saved over their real data** on the next autosave. Now the session just runs unsaved (the hub shows *"coins and unlocks are not saved"*).

- **Session lock.** Loading uses `UpdateAsync` to stamp `lock = {job = JobId, t = time}`. If another live server holds the lock (player rejoined fast), we wait up to ~25 s for it to save and let go, then take over. A server that finds it has lost the lock stops saving that player.
- **Batched saves.** `DS.save(plr)` marks the profile dirty and writes at most once every 7 s (DataStores allow ~1 write / 6 s per key). Buying, equipping, spinning and race results all just call `DS.save`.
- **Autosave** every 60 s (also refreshes the lock; it expires after 150 s if a server crashes).
- **Leaving / shutdown.** `DS.release` writes the profile and clears the lock. On shutdown all players are released in parallel (Roblox gives ~30 s).
- Loaded data is sanitised (bad coin values, missing tables, equipped items you don't own).

## Daily spin
One spin per UTC day. Weighted tiers in `Config.SPIN_TIERS`; a duplicate skin pays `dupeCoins` instead. See [[Monetization]].

## Testing in Studio
Saving only works in a **published** place with *Enable Studio Access to API Services* on. Otherwise everything works for the session but nothing is saved, and the hub says so.

## Future
For a bigger game consider [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) — it does session locking, retries and auto-saves in a battle-tested way. See [[Roadmap]].

Related: [[Anti-Cheat]] · [[Monetization]]
