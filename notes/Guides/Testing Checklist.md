---
tags: [velocity-cup, guide, testing]
---
# Testing Checklist

Back to [[Home]]

Run through this in Studio after changes (use **Test → Clients and Servers** with 2–3 players for multiplayer bits).

## Hub
- [ ] Spawn in the server room; coins show; garage preview spins
- [ ] Pick a vehicle at a pedestal (E) and in the garage
- [ ] Buy and equip a skin and a trail; coins go down
- [ ] Daily spin works once, then says come back tomorrow
- [ ] Leaderboard tabs load

## Races
- [ ] Race bots on every map: countdown, GO, laps count, results, back to hub
- [ ] Waiting room: create, join with a 2nd player, ready, host starts, everyone returns to the booth after
- [ ] Take each shortcut — it appears on the minimap and the lap still counts
- [ ] Fire a boomerang / rocket while on a shortcut — it follows the shortcut
- [ ] Fall off / get knocked off: you respawn on the road (never on a ramp)
- [ ] Press R twice quickly — second press is refused for 3 s
- [ ] Leave the game mid-race — the race continues for others

## Saving (published place, API access on)
- [ ] Earn coins, leave, rejoin — coins are kept
- [ ] Rejoin immediately on another server — profile loads (may wait a few seconds for the lock)
- [ ] Output shows no "DataStore error" spam

## Code checks
- [ ] `luau-lsp analyze` shows no new warnings (see [[Project Setup]])
