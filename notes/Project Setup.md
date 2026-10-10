---
tags: [velocity-cup, setup]
---
# Project Setup

Back to [[Home]]

The game used to live only inside `VelocityCup-v7.rbxlx`. Its 15 scripts are now plain files in this repo so they can be versioned, reviewed and edited outside Studio.

## Folder → Roblox mapping
| Repo path | Becomes in Studio |
|---|---|
| `src/shared/VelocityCup/` | `ReplicatedStorage.VelocityCup` (ModuleScripts used by server **and** clients) |
| `src/server/RaceServer/init.server.luau` | `ServerScriptService.RaceServer` (Script) |
| `src/server/RaceServer/*.luau` | ModuleScripts inside `RaceServer` |
| `src/client/RaceClient/init.client.luau` | `StarterPlayer.StarterPlayerScripts.RaceClient` (LocalScript) |
| `src/client/RaceClient/*.luau` | ModuleScripts inside `RaceClient` |
| `notes/` | this Obsidian vault (not part of the game) |

The mapping is written down in `default.project.json` (a [Rojo](https://rojo.space) project file).

## Getting the code into Studio
**Option A — Rojo (recommended)**
1. Install the Rojo plugin in Studio and the `rojo` CLI (e.g. with Aftman/Rokit).
2. In the repo folder run `rojo serve`.
3. In Studio open your place, click **Rojo → Connect**. Scripts now live-sync from these files.

**Option B — copy & paste**
Open each `.luau` file and paste it into the matching script in Studio (same names and nesting as the table above). `init.server.luau` / `init.client.luau` are the bodies of the `RaceServer` Script and `RaceClient` LocalScript themselves.

> [!note] Everything is built from code
> The place has no hand-built parts: the hub, every track and every vehicle are generated at runtime by `HubBuilder`, `TrackBuilder` and `VehicleBuilder`. An empty Baseplate plus these scripts is the whole game.

## Studio settings to check
- **Game Settings → Security → Enable Studio Access to API Services** — needed for saving in Studio (see [[Data and Saving]]).
- **Workspace.StreamingEnabled** — worth turning on, see [[Roadmap]].

## Checking code without Studio
- `luau-lsp analyze` with a Rojo sourcemap type-checks every script (used for the [[2026-10-10 Code Review]]).
