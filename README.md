# MONEY MONEY MONEY

A 1–6 player Roblox quota run: pay the bank each quota (7 minutes, then 9, 10, 11, 12), split the prize by contribution.
From quota 2 each quota rolls a twist (Rush Hour, Blackout, Sale Day...: `Config.Twists`) and everyone picks a hustle,
a run perk (`Config.Hustles`); every few minutes a town event happens (cash drop, armoured truck, VIP fare, happy hour,
fire sale, a rival crew with blasters, and with 2+ players a hustle-off: `Config.Events`, `src/match/server/Events/`);
everyone banking within 30s of each other is a team combo (`Config.TeamCombo`); the results screen hands out fun awards
(`RunAwards`); paying early puts a bonus in everyone's bag; the cash-out vote comes after quota 3 and every quota after; from quota 4 cops get tougher and repo men
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

Maps are built from parts by scripts and kept in the place files, not in Rojo. The lobby is the hall of Penny National
Bank: `tools/build_lobby.luau` (marble hall, teller counter, vault, leaderboards on the walls). The Match town:
`tools/build_town.luau` with its pieces in `tools/town/` (layout, roads, bank and shops, 60 houses, park and yards);
after `scripts/sync-studio.ps1`, run `require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_town)` (or
`.build_lobby` in the Lobby). The bank's inside matches the lobby hall (`tools/town/BankInterior.luau`);
`.restyle_bank` redresses just the bank in place without rebuilding the town, and `.rebuild_buildings`
rebuilds only the bank and shops (each shop has its own roofline, awning and signature piece: `tools/town/Signatures.luau`).
Blasters everywhere (in your hand, shop pictures, Tony's wall) come from `src/shared/BlasterLooks.luau`, which also holds the
custom blasters sold in CUSTOMISATION. Hand edits made in Studio are copied
into the builders (the vault, the dumpster lid, the lobby title's font) so a rebuild keeps them.
Code finds map points by CollectionService tags: `Leaderboard`, `BankCounter`,
`BankSpawn`, `StaffSpot`, `DeliveryDepot`, `DeliveryDropoff`, `House`, `HidingSpot`, `StoreZone`,
`ShopCounter` (with `Shop` and `Staff`), `PoliceSpawn`, `JailCell`, `JailExit`, `PedWaypoint`, `ParkSpot`, `AlleyDrop`,
`ParkedCar`, `ChopShop`, and for the legal jobs `TaxiDesk`, `TaxiSpawn`, `TaxiStop`, `BurgerCounter`, `BurgerGrill`,
`BurgerFryer`, `BurgerShake`, `BurgerCustomer`, `CarWashDesk`, `CarWashBay`, `CarWashLever`, `FlipWreck`, `TyreStack`, `FoodCartCounter`. No floating labels: buildings carry painted signs. After changing the town, run
`tools/find_zfighting.luau` to check for flickering faces.

## The lobby

A menu bar along the bottom of the screen: **UPGRADES**, **PLAY** and **CUSTOMISATION**. PLAY asks Solo (leave now)
or With others, which opens FIND A LOBBY: every lobby waiting for players with a JOIN button, or HOST A LOBBY. The
host picks the party size and can START NOW; a lobby leaves when full or `Config.Match.QueueWaitSeconds` after it
opened. While you wait, PLAY turns into LEAVE with the countdown.

Everything in the two shop windows is bought with Cred at a fixed price (nothing random) and kept for good
(`Config.CredShop`). UPGRADES has the upgrades, loadout unlocks and badges; CUSTOMISATION has a tab per cosmetic slot
and a stage that shows whatever card you tap (a race car wears your paint and underglow there):

- **Upgrades** (levelled): Speed Buff, Big Pockets (bag size), Head Start (starting cash), Silver Tongue (honest pay),
  Smooth Operator (crime pay), Low Profile (less heat), Quick Hands (faster break-ins and robberies), Good Lawyer
  (shorter jail), Insurance (lose less when busted), Bargain Hunter (cheaper town shops), Investor (more Cred per run).
  The Match reads them through `Perks.amount` where each one applies; `Loadout` hands out the start-of-run ones.
- **Loadout unlocks**: Toolbelt (a lockpick), Thermos (an energy drink), Zapper License (a free Zapper
  at quota 2), Wide Options (four hustle choices).
- **Cosmetics** (`shared/Cosmetics`, priced by rarity), one worn per slot: paint and underglow for your race
  cars, trails, a bag slung over your shoulder that swells as it fills (`BagLook`, designs in `shared/BagLooks`), zap colours, and bank bursts.

## Saving

Profiles (Cred, upgrades, cosmetics owned and worn, badges, daily challenge and streak) are saved with
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
src/shared/        ReplicatedStorage.Shared: Config, Remotes, Types, Catalog (upgrades, unlocks, badges), Cosmetics,
                   ItemModels (3D pictures), Rainbow, UI, Movement
src/serverCommon/  ServerScriptService.Common: Profiles, Daily, Badges, Perks (upgrade levels), Style (cosmetics worn,
                   trails, bank bursts), Leaderboards, ProfileSync,
                   SafeTeleport, RateLimiter, Admin, Vendor/ProfileStore (both places)
src/lobby/         QueueService (PLAY → reserved Match server), CredShopService (buy, wear), BankStaff, leaderboard
                   boards; client MenuBar, UpgradesWindow, CustomiseWindow, ShopFrame, QueueController, profile panel
src/match/server/  QuotaRunService (state machine), Twists (+ late-game pressure), Hustles, Events + Events/*, Repo men,
                   Economy, Deposit, Prize,
                   Path + Paths/*, Heat, Police, Jail,
                   Shop + Counters (talk to the shopkeeper: buy or rob), Vehicles (car bodies: VehicleModels),
                   job props (PropModels: dog, mower, bins...), Steal, NPCs, Staff, MovementGuard, Sync,
                   Penny (the bank), Debug
src/match/client/  HUD, money lines ("+$1,500 | Package delivered"), announcements (Mr. Penny, town news) sliding out
                   from under the quota panel, conversations (Dialogue:
                   the speaker's line over their head, numbered answer cards, orange when it adds heat; door
                   offers, shopkeepers, the cash-out choice), next-step guide, job guide, shop (3D item pictures
                   from shared/ItemModels turning in front of light rays), pickpocket, results
src/shared/Music   quiet background music, swapped for the chase track while you're wanted (Config.Music); during a
                   chase a siren plays and every other effect goes quiet except Config.Music.ChaseKeeps (money,
                   sirens, the quota clock) via SoundGroups in shared/Sounds
```

Every tunable number is in `src/shared/Config.luau`. The server owns all money: clients only send intents
(`SubmitDecision`, `ChooseDoorOffer`, `TalkAnswer`, `BuyItem`, `SetRiding`, `PickHustle`, `Play`, `LeaveQueue`, `ClientReady`, `BuyCredItem`, `EquipCosmetic`); jobs, crimes,
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
| `/drive [top speed]` | A car where you stand |
| `/twist <id\|none>` | Swap this quota's twist (ids in `Config.Twists`, e.g. `blackout`) |
| `/hustle <id>` | Give yourself a hustle (ids in `Config.Hustles`, e.g. `deeppockets`) |
| `/event <id>` | Start a town event now: `cashdrop`, `happyhour`, `firesale`, `vipfare`, `armouredtruck`, `rivalcrew`, `hustleoff` |

In Studio, `game.ServerStorage.DebugHook:Invoke("cash", "5000")` runs the same commands from the server command bar.
Set `Config.Debug.Enabled = true` to run every phase timer at `TimerScale` speed.

Teleports don't run in Studio: test the Match place directly (it starts `Debug.StudioAutoStartSeconds` after the
first player joins). The Lobby → Match → Lobby loop needs both places published.
