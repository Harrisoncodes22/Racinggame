---
tags: [velocity-cup, roadmap]
---
# Roadmap

Back to [[Home]] · Last review: [[2026-10-10 Code Review]]

Ideas in rough priority order. Tick them off as you go.

## Must-do before a big launch
- [ ] Play through the [[Testing Checklist]] with 2+ players in Studio
- [ ] Set real `gamePassId`s for the Robux items ([[Monetization]])
- [ ] Turn on **StreamingEnabled** — every running race's track (thousands of parts) is currently sent to every player, even ones in the hub. With streaming, players only load what's near them. Test that the minimap and item boxes still behave.
- [ ] Consider switching saving to ProfileStore ([[Data and Saving]])

## Game feel
- [ ] **Sound** — there is none yet: engine loop (pitch from speed), drift screech, boost whoosh, item sounds, countdown beeps, music per map
- [ ] Camera shake on hits and landings
- [ ] Drift smoke particles from the rear wheels
- [ ] Lap-split display (+/- vs your best lap)

## Content
- [ ] More maps (see [[Add a Track]])
- [ ] Time-trial mode with ghost replay of your best lap
- [ ] Shield item (blocks one hit) and a banana-style trap for the front of the pack
- [ ] Badges: first win, all maps, find every shortcut

## Tech
- [ ] Reuse a built track if the next race in that slot uses the same map (faster loading)
- [ ] Tighter anti-cheat: compare the reported position with what the server expects from the last known speed ([[Anti-Cheat]])
- [ ] Unit tests for `TrackMath` (it already runs outside Roblox — see the review)
