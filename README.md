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

Maps are grey boxes kept in the place files, not in Rojo. Rebuild them with `tools/build_lobby_map.luau` (then
`tools/build_lobby_extras.luau` for the cosmetics stand and leaderboards), `tools/build_match_map.luau` and then
`tools/build_race_track.luau` (paste into the command bar). Code finds map points by CollectionService tags:
`QueuePad`, `CosmeticShop`, `Leaderboard`, `TonyDesk`, `TonySpawn`, `DeliveryDepot`, `DeliveryDropoff`, `House`,
`HidingSpot`, `StoreCounter`, `ShopCounter`, `PoliceSpawn`, `JailCell`, `JailExit`, `PedWaypoint`, `ParkSpot`,
`AlleyDrop`, `RaceJoin`, `RaceCheckpoint`, `RaceGrid`, `ParkedCar`, `ChopShop`.

## Saving

Profiles (Cred, cosmetics, badges, daily challenge and streak) are saved with
[ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (MIT, vendored in `src/serverCommon/Vendor/`,
skipped by the checks). Its session lock means a profile is only open on one server at a time, so the
Lobby → Match → Lobby teleports can't lose or duplicate Cred. The Match adds your prize and saves the moment your run
ends. Leaderboards are OrderedDataStores. Studio tests use `Studio_`-prefixed stores so they never touch live data;
turn on Game Settings → Security → Enable Studio Access to API Services to save in Studio at all.

Place settings (not in Rojo, set in both places): `StarterGui.ScreenOrientation = LandscapeSensor`, so phones
play sideways (the HUD is laid out for landscape).

## Checks

- `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` runs strict type-checking (luau-lsp), Selene and StyLua.
- `tools/check_math.luau` (Match place, Edit mode, command bar) unit-checks quota targets and the prize formula.

No Rojo connection? `scripts/sync-studio.ps1` builds each place's code into Studio's content folder,
and `tools/load_code.luau` (set `PLACE`) swaps it into the open place.

## Layout

```
src/shared/        ReplicatedStorage.Shared: Config, Remotes, Types, Catalog (cosmetics, badges), UI, Movement
src/serverCommon/  ServerScriptService.Common: Profiles, Daily, Badges, Cosmetics, Leaderboards, ProfileSync,
                   SafeTeleport, RateLimiter, Admin, Vendor/ProfileStore (both places)
src/lobby/         QueueService (pads → reserved Match server), cosmetics stand, leaderboard boards, profile panel
src/match/server/  QuotaRunService (state machine), Economy, Deposit, Prize, Path + Paths/*, Heat, Police, Jail,
                   Shop, Vehicles, Steal, NPCs, MovementGuard, Sync, Tony, Debug
src/match/client/  HUD, Tony banner, toasts, job guide, door offers, shop, ride key, race panel, results
```

Every tunable number is in `src/shared/Config.luau`. The server owns all money: clients only send intents
(`SubmitDecision`, `ChooseDoorOffer`, `BuyUpgrade`, `SetRiding`, `LeaveQueue`, `ClientReady`, `BuyCosmetic`,
`EquipCosmetic`); jobs, crimes, races and arrests use server-checked ProximityPrompts. Every Cred change goes through
`Profiles.addCred` and is logged.

## Debug commands

Chat commands for the game owner, anyone in `Config.Debug.AdminUserIds`, and everyone in a Studio test:

| Command | Does |
| --- | --- |
| `/cash <amount> [player]` | Give carried cash (ignores bag size) |
| `/cred <amount>` | Add saved Cred to yourself (to test the lobby shop) |
| `/skip` | Pass the current quota now |
| `/timer <seconds>` | Set time left in the current phase |
| `/start` | Start the run without waiting for arrivals |
| `/heat <stars>` | Add heat to yourself (negative clears it) |
| `/tp <x> <y> <z>` | Teleport yourself |

In Studio, `game.ServerStorage.DebugHook:Invoke("cash", "5000")` runs the same commands from the server command bar.
Set `Config.Debug.Enabled = true` to run every phase timer at `TimerScale` speed.

Teleports don't run in Studio: test the Match place directly (it starts `Debug.StudioAutoStartSeconds` after the
first player joins). The Lobby → Match → Lobby loop needs both places published.
