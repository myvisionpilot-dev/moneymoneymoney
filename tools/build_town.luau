-- Builds the Match town into Workspace.Map from scratch (roads, bank, shops, 60 houses, park,
-- yards, markers). Parts only, no scripts. Run in the Match place, e.g. with the MCP:
--   require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_town)
-- (scripts/sync-studio.ps1 builds tools.rbxm.) The pieces live in tools/town/.
--
-- Tags the code looks for:
--   BankCounter, BankSpawn, StaffSpot           the bank (deposits, spawns), Mr. Penny and Tony
--   House (+ HouseId, Tier; Door, Lawn, Bin1/2, BackDoor, Kerb, CarSpot)   door knocks, chores
--   DeliveryDepot, DeliveryDropoff              deliveries
--   StoreCounter, StoreZone                     store robberies, the door bell
--   ShopCounter                                 the upgrades counter (hardware store)
--   PoliceSpawn, JailCell, JailExit             police and jail
--   HidingSpot, ParkSpot, AlleyDrop             heat and door jobs
--   ParkedCar, ChopShop                         car theft
--   PedWaypoint (+ Route, Order)                pedestrian routes
--   TaxiDesk, TaxiSpawn, TaxiStop               taxi shifts
--   BurgerCounter/Grill/Fryer/Shake/Customer    Burger Barn
--   CarWashDesk, CarWashBay, CarWashLever       Sudz car wash
--   FlipWreck, TyreStack, PaintBooth            car flipping
--   FoodCartCounter                             the hot-dog cart

local town = script.Parent:WaitForChild("town")
local Buildings = require(town.Buildings)
local Houses = require(town.Houses)
local Outdoors = require(town.Outdoors)
local Roads = require(town.Roads)

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
local template = workspace:FindFirstChild("SpawnLocation")
if template then
	template:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"

Roads.build(map)
Buildings.build(map)
Houses.build(map)
Outdoors.build(map)
map.Parent = workspace

local parts, houses = 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
for _ in game:GetService("CollectionService"):GetTagged("House") do
	houses += 1
end
return `Town built: {houses} houses, {parts} parts`
