# MONEY MONEY MONEY

A 1–6 player Roblox quota run: pay the bank each quota (7 minutes, then 9, 10, 11, 12), split the prize by contribution.
From quota 2 each quota rolls a twist (Rush Hour, Blackout, Sale Day...: `Config.Twists`) and everyone picks a hustle,
a run perk (`Config.Hustles`); paying early puts a bonus in everyone's bag; the cash-out vote comes after quota 3 and every quota after; from quota 4 cops get tougher and repo men
chase anyone carrying more than half a bag.
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

Maps are built from parts by scripts and kept in the place files, not in Rojo. The lobby: `tools/build_lobby_map.luau`
then `tools/build_lobby_extras.luau` (speed shop stand and leaderboards), pasted into the command bar. The Match town:
`tools/build_town.luau` with its pieces in `tools/town/` (layout, roads, bank and shops, 60 houses, park and yards);
after `scripts/sync-studio.ps1`, run `require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_town)`.
Code finds map points by CollectionService tags: `QueuePad`, `PerkShop`, `Leaderboard`, `BankCounter`,
`BankSpawn`, `StaffSpot`, `DeliveryDepot`, `DeliveryDropoff`, `House`, `HidingSpot`, `StoreCounter`,
`StoreZone`, `ShopCounter`, `PoliceSpawn`, `JailCell`, `JailExit`, `PedWaypoint`, `ParkSpot`, `AlleyDrop`,
`ParkedCar`, `ChopShop`, and for the legal jobs `TaxiDesk`, `TaxiSpawn`, `TaxiStop`, `BurgerCounter`, `BurgerGrill`,
`BurgerFryer`, `BurgerShake`, `BurgerCustomer`, `CarWashDesk`, `CarWashBay`, `CarWashLever`, `FlipWreck`, `TyreStack`,
`PaintBooth`, `FoodCartCounter`. No floating labels: buildings carry painted signs. After changing the town, run
`tools/find_zfighting.luau` to check for flickering faces.

## Saving

Profiles (Cred, perks, badges, daily challenge and streak) are saved with
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
src/shared/        ReplicatedStorage.Shared: Config, Remotes, Types, Catalog (perks, badges), UI, Movement
src/serverCommon/  ServerScriptService.Common: Profiles, Daily, Badges, Perks, Leaderboards, ProfileSync,
                   SafeTeleport, RateLimiter, Admin, Vendor/ProfileStore (both places)
src/lobby/         QueueService (pads → reserved Match server), speed shop (permanent perks), leaderboard boards, profile panel
src/match/server/  QuotaRunService (state machine), Twists (+ late-game pressure), Hustles, Repo men, Economy, Deposit, Prize,
                   Path + Paths/*, Heat, Police, Jail,
                   Shop, Vehicles, Steal, NPCs, Staff, MovementGuard, Sync, Penny (the bank), Debug
src/match/client/  HUD, money lines ("+$1,500 | Package delivered"), Mr. Penny's banner, next-step guide, job guide,
                   door offers, shop, pickpocket, results
```

Every tunable number is in `src/shared/Config.luau`. The server owns all money: clients only send intents
(`SubmitDecision`, `ChooseDoorOffer`, `BuyItem`, `SetRiding`, `PickHustle`, `LeaveQueue`, `ClientReady`, `BuyPerk`); jobs, crimes,
races and arrests use server-checked ProximityPrompts. Every Cred change goes through `Profiles.addCred` and is logged.

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
| `/drive [kart] [top speed]` | A car (or kart) where you stand |
| `/twist <id\|none>` | Swap this quota's twist (ids in `Config.Twists`, e.g. `blackout`) |
| `/hustle <id>` | Give yourself a hustle (ids in `Config.Hustles`, e.g. `deeppockets`) |

In Studio, `game.ServerStorage.DebugHook:Invoke("cash", "5000")` runs the same commands from the server command bar.
Set `Config.Debug.Enabled = true` to run every phase timer at `TimerScale` speed.

Teleports don't run in Studio: test the Match place directly (it starts `Debug.StudioAutoStartSeconds` after the
first player joins). The Lobby → Match → Lobby loop needs both places published.
