# MONEY MONEY MONEY

A 1–6 player Roblox quota run: pay off Tony every 7 minutes, split the prize by contribution.
One universe, two places, each synced from its own Rojo project.

| Place | Place ID | Project file | Rojo port |
| --- | --- | --- | --- |
| Lobby (start place) | 89656922694625 | `lobby.project.json` | 34872 |
| Match | 80496708814164 | `match.project.json` | 34873 |

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` here (Rojo, StyLua, Selene, luau-lsp).
2. `rojo plugin install`, then restart Studio so the plugin loads.
3. Open a place in Studio and run its server, then press Connect in the Rojo plugin (use the port above):
   - `rojo serve lobby.project.json`
   - `rojo serve match.project.json`

Maps are grey boxes kept in the place files, not in Rojo. Rebuild them with `tools/build_lobby_map.luau`
and `tools/build_match_map.luau` (paste into the command bar). Code finds map points by CollectionService tags:
`QueuePad`, `TonyDesk`, `TonySpawn`, `DeliveryDepot`, `DeliveryDropoff` (plus `House`, `HidingSpot` for later).

## Checks

- `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` runs strict type-checking (luau-lsp), Selene and StyLua.
- `tools/check_math.luau` (Match place, Edit mode, command bar) unit-checks quota targets and the prize formula.

No Rojo connection? `scripts/sync-studio.ps1` builds each place's code into Studio's content folder,
and `tools/load_code.luau` (set `PLACE`) swaps it into the open place.

## Layout

```
src/shared/        ReplicatedStorage.Shared: Config, Remotes, Types, UI helpers (both places)
src/serverCommon/  ServerScriptService.Common: SafeTeleport, RateLimiter, Admin (both places)
src/lobby/         QueueService (pads → reserved Match server) + queue panel
src/match/server/  QuotaRunService (state machine), Economy, Deposit, Prize, Path + Paths/*, Sync, Tony, Debug
src/match/client/  HUD, Tony banner, toasts, delivery guide, intermission, decision, results
```

Every tunable number is in `src/shared/Config.luau`. The server owns all money: clients only send intents
(`SubmitDecision`, `LeaveQueue`, `ClientReady`); deposits and jobs use server-side ProximityPrompts.

## Debug commands

Chat commands for the game owner, anyone in `Config.Debug.AdminUserIds`, and everyone in a Studio test:

| Command | Does |
| --- | --- |
| `/cash <amount> [player]` | Give carried cash (ignores bag size) |
| `/skip` | Pass the current quota now |
| `/timer <seconds>` | Set time left in the current phase |
| `/start` | Start the run without waiting for arrivals |

In Studio, `game.ServerStorage.DebugHook:Invoke("cash", "5000")` runs the same commands from the server command bar.
Set `Config.Debug.Enabled = true` to run every phase timer at `TimerScale` speed.

Teleports don't run in Studio: test the Match place directly (it starts `Debug.StudioAutoStartSeconds` after the
first player joins). The Lobby → Match → Lobby loop needs both places published.
