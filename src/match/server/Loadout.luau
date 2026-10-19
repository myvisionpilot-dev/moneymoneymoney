--!strict
-- What your Cred shop upgrades and unlocks give you in a run (serverCommon/Perks reads them from
-- your save): a bigger bag (Big Pockets) and extra starting cash (Head Start) from the start,
-- a lockpick (Toolbelt) and an energy drink (Thermos) in hand. The other upgrades are read
-- where they apply (pay, heat, jail, shop prices, prizes). The Mega Bag and Fat Stack game
-- passes add to the bag and the starting cash here too (a Mega Bag bought mid-run in the Shop
-- grows the bag on the spot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Passes = require(ServerScriptService.Common.Passes)
local Perks = require(ServerScriptService.Common.Perks)
local EconomyService = require(script.Parent.EconomyService)
local EnergyDrink = require(script.Parent.EnergyDrink)
local Notifier = require(script.Parent.Notifier)
local ShopService = require(script.Parent.ShopService)

local Loadout = {}

-- How much bigger than usual the bag is: Big Pockets, times the Mega Bag pass.
local function bagMultiplier(player: Player): number
	return (1 + Perks.amount(player, "Pockets")) * (if Passes.has(player, "MegaBag") then Config.Store.MegaBag else 1)
end

-- At the start of the run (before Mr. Penny names the first quota).
function Loadout.startRun(player: Player)
	local store = Config.Store
	local megaBag = Passes.has(player, "MegaBag")
	EconomyService.setPerkMultiplier(player, bagMultiplier(player))
	local bonus = Perks.amount(player, "HeadStart") + (if Passes.has(player, "FatStack") then store.FatStack else 0)
	EconomyService.setCarried(player, Config.Match.StartingCash + bonus, "starting cash")
	local extras: { string } = {}
	if bonus > 0 then
		table.insert(extras, `{Format.money(bonus)} extra cash`)
	end
	if megaBag then
		table.insert(extras, "a Mega Bag")
	end
	if Perks.has(player, "Toolbelt") then
		ShopService.grant(player, "Lockpick", 1)
		table.insert(extras, "a lockpick")
	end
	if Perks.has(player, "Thermos") and not EnergyDrink.holding(player) then
		EnergyDrink.give(player)
		table.insert(extras, "an energy drink")
	end
	if #extras > 0 then
		Notifier.send(player, `Your loadout: {table.concat(extras, ", ")}.`, "Good")
	end
end

-- A pass bought mid-run (in the Shop) works straight away: the bag grows for a Mega Bag.
function Loadout.start()
	Passes.changed:Connect(function(player: Player)
		EconomyService.setPerkMultiplier(player, bagMultiplier(player))
	end)
end

return Loadout
