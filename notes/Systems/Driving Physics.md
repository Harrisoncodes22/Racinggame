---
tags: [velocity-cup, system, shared]
---
# Driving Physics

Back to [[Home]] · Code: `src/shared/VelocityCup/CarController.luau`

One module drives **both** your car (on your device) and the bots (on the server), so they handle identically.

## How a car works
- The visible car is welded to one invisible `Body` part. A downward raycast finds the ground; the body hovers at its ride height (`Ride` attribute) — no wheel physics, so it never snags on bumps.
- Each step the controller rewrites the body's velocity directly: forward speed `fs`, sideways slide `ls` (bled off by grip), and vertical speed that follows the road surface.
- An `AlignOrientation` ("Align") turns the car; a `VectorForce` ("Lift") makes air time floatier (`AIR_GRAVITY` = 75 instead of Roblox's 196.2).

## Speed and surfaces
- Top speed = `top × K × SPEED_SCALE × skill × surface factor`.
- Surface = the **name** of the part under the car: `Road`, `Ramp`, `Ice`, `Dirt`, `Water`, `Shoulder`. Slowdowns are in `Config.SURFACES` (+ each track's `offTop` for shoulders), softened by the vehicle's `offroad` stat.
- Ice cuts grip to 28 %; water to 70 %.

## Boosts
| Source | Effect |
|---|---|
| Boost pad | 1.15 s boost |
| Drift (hold drift while turning, release) | charge > 1.1 → 0.7 s; charge > 2.3 → 1.3 s "super" |
| Trick (press drift in the air) | 0.9 s × vehicle `trick` stat on landing |
| Turbo item | `ITEMS.boost.duration` (1.8 s) |
While boosting, top speed is 1.38× the vehicle's base top speed.

## Getting hit
`C.stun(st, dur, kind)` — kinds `stun`, `knockout` (flipped), `blast` (thrown up), `splash` (water), `lightning`. Duration is multiplied by the vehicle's `stunResist`.

## Recovery
- Off the road for 0.3 s (or airborne > 3 s, or fell below the track) → put back at the last good spot, frozen for 2 s.
- Never respawns on a ramp: before a ramp, or past a water jump (`TrackMath.safeRespawnIndex`).
- Manual reset (R / Y / touch button) has a 3 s cooldown.

## AI
`C.aiInput` steers toward a point ahead on the racing line, prefers boost pads, swerves around trees, sometimes takes shortcuts, and slows for corners. Rubber-banding nudges bot skill ±6 % depending on the gap to the leading human.

Related: [[Tracks]] · [[Tuning Cheatsheet]] · [[Anti-Cheat]]
