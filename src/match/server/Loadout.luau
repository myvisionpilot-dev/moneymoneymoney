--!strict
-- What your Cred shop upgrades and unlocks give you in a run (serverCommon/Perks reads them from
-- your save): a bigger bag (Big Pockets) and extra starting cash (Head Start) from the start,
-- a lockpick (Toolbelt) and an energy drink (Thermos) in hand, and a free Zapper the moment
-- blasters go on sale (Zapper License). The other upgrades are read
-- where they apply (pay, heat, jail, shop prices, prizes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Perks = require(ServerScriptService.Common.Perks)
local BlasterService = require(script.Parent.BlasterService)
local EconomyService = require(script.Parent.EconomyService)
local EnergyDrink = require(script.Parent.EnergyDrink)
local Notifier = require(script.Parent.Notifier)
local ShopService = require(script.Parent.ShopService)

local Loadout = {}

-- At the start of the run (before Mr. Penny names the first quota).
function Loadout.startRun(player: Player)
	EconomyService.setPerkMultiplier(player, 1 + Perks.amount(player, "Pockets"))
	local bonus = Perks.amount(player, "HeadStart")
	EconomyService.setCarried(player, Config.Match.StartingCash + bonus, "starting cash")
	local extras: { string } = {}
	if bonus > 0 then
		table.insert(extras, `{Format.money(bonus)} extra cash`)
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

-- When each quota starts.
function Loadout.quotaStarted(player: Player, quotaIndex: number)
	if
		quotaIndex == Config.Blasters.UnlockQuota
		and Perks.has(player, "ZapperLicense")
		and not BlasterService.owned(player)
	then
		BlasterService.give(player, "Zapper")
		Notifier.send(player, "Zapper License: your free Zapper is in your backpack.", "Good")
	end
end

return Loadout
