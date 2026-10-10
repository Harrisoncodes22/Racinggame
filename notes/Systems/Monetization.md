---
tags: [velocity-cup, system, robux]
---
# Monetization

Back to [[Home]]

## Robux items (Game Passes)
| Item | Price | Config entry |
|---|---|---|
| Nightshade X (vehicle) | R$ 700 | `Config.VEHICLES` → `id = "nightshade"` |
| Galaxy trail | R$ 99 | `Config.TRAILS` → `id = "galaxy"` |
| Meme Poop trail | R$ 49 | `Config.TRAILS` → `id = "poop"` |

### Setting up a pass
1. create.roblox.com → your experience → **Monetization → Passes** → create the pass, set the price.
2. Copy its **Pass ID** into that item's `gamePassId` in `RaceConfig` (it's `0` = not set up; the shop then says so).
3. Publish. Owners are detected on join (`UserOwnsGamePassAsync`) and right after purchase (`PromptGamePassPurchaseFinished`).

`Config.UNLOCK_ROBUX_VEHICLES_IN_STUDIO = true` lets you test Robux vehicles in Studio for free (never saved, never in live servers).

## Coins
Earned from race places (`Config.placeCoins`: winner gets `FIRST_PLACE_COINS`, last place 0; needs ≥ 1 lap) and item hits. Spent on skins (300–1000) and trails (150–800). New players start with `START_COINS` = 350.

## Daily spin
Free, once per UTC day. Real odds (the spin screen now shows these, rounded):

| Tier | Weight | Chance | Skin | Duplicate pays |
|---|---|---|---|---|
| Uncommon | 60 | 61.8 % | Crimson | 100 |
| Rare | 30 | 30.9 % | Reptile Scales | 200 |
| Epic | 5 | 5.1 % | Flames | 500 |
| Legendary | 2 | 2.1 % | Gold Glow | 1000 |
| Mythic | 0.1 | 0.1 % | Black Diamond | 5000 |

> [!warning] If you ever sell spins for Robux
> Roblox requires paid random items to show their odds. The screen already does, but double-check the policy before adding paid spins.

Related: [[Data and Saving]] · [[UI]]
