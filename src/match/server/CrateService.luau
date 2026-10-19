--!strict
-- Tony's lucky crates (the Crates shop, stocked through ShopService.register). Paid from your bag
-- like everything else. The server rolls a rarity by the crate's odds (Config.Crates, shown on
-- each crate), then one prize of that rarity, and hands it over straight away: treats and
-- upgrades for this run, never cash. An upgrade you've already maxed becomes a Treat Pack. Then
-- your screen shakes the crate open (client/CrateController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local BoostService = require(script.Parent.BoostService)
local EnergyDrink = require(script.Parent.EnergyDrink)
local ShopService = require(script.Parent.ShopService)

local SHOP: Types.ShopId = "Crates"
local TREATS: { Types.BoostId } = { "Candy", "Disguise", "Gloves", "Scanner" } -- and the drink

local remotes = Remotes.match()
local rng = Random.new()

local CrateService = {}

local function rollTier(kind: Crates.Kind): Crates.Tier
	local total = 0
	for _, tier in Crates.Tiers do
		total += kind.odds[tier :: Crates.Tier] or 0
	end
	local roll = rng:NextNumber() * total
	for _, tier in Crates.Tiers do
		local chance = kind.odds[tier :: Crates.Tier] or 0
		if chance > 0 then
			roll -= chance
			if roll < 0 then
				return tier :: Crates.Tier
			end
		end
	end
	return Crates.Tiers[1] :: Crates.Tier
end

-- An energy drink in their backpack, or (holding one already) the speed boost right away.
local function drink(player: Player)
	if EnergyDrink.holding(player) then
		BoostService.give(player, "Energy")
	else
		EnergyDrink.give(player)
	end
end

local function treats(player: Player, list: { Types.BoostId })
	for _, id in list do
		BoostService.give(player, id :: Types.BoostId)
	end
end

local function maxLevel(id: Types.UpgradeId): number
	return if id == "Bag" then #Config.Shop.Bag else #Config.Shop.Lockpick
end

-- Up a level (or all the way). False if it's already maxed.
local function upgrade(player: Player, id: Types.UpgradeId, toMax: boolean?): boolean
	local level = ShopService.level(player, id)
	local top = maxLevel(id)
	if level >= top then
		return false
	end
	ShopService.grant(player, id, if toMax then top else level + 1)
	return true
end

local function treatPack(player: Player)
	treats(player, TREATS)
	drink(player)
end

-- Hands a prize over. False if it's no use to them (an upgrade already maxed).
local GIVE: { [string]: (Player) -> boolean } = {
	Candy = function(player)
		treats(player, { "Candy" })
		return true
	end,
	Energy = function(player)
		drink(player)
		return true
	end,
	Gloves = function(player)
		treats(player, { "Gloves" })
		return true
	end,
	Disguise = function(player)
		treats(player, { "Disguise" })
		return true
	end,
	Scanner = function(player)
		treats(player, { "Scanner" })
		return true
	end,
	SnackPack = function(player)
		treats(player, { "Candy", "Gloves" })
		drink(player)
		return true
	end,
	BagUp = function(player)
		return upgrade(player, "Bag")
	end,
	LockpickUp = function(player)
		return upgrade(player, "Lockpick")
	end,
	TreatPack = function(player)
		treatPack(player)
		return true
	end,
	MaxBag = function(player)
		return upgrade(player, "Bag", true)
	end,
	Jackpot = function(player)
		treatPack(player)
		upgrade(player, "Bag")
		upgrade(player, "Lockpick")
		return true
	end,
}

local function items(player: Player): { Types.ShopItem }
	local list: { Types.ShopItem } = {}
	for _, kind in Config.Crates.Kinds :: any do
		table.insert(list, {
			id = kind.id,
			kind = "Crate",
			title = Crates.Names[kind.id] or kind.id,
			detail = Crates.oddsText(kind, true),
			price = ShopService.price(player, SHOP, kind.price),
		})
	end
	return list
end

-- Opens one for them: rolls it, hands the prize over and shows them. `tier` skips the roll
-- (the /crate debug command).
function CrateService.open(player: Player, kind: Crates.Kind, forced: Crates.Tier?)
	local tier = forced or rollTier(kind)
	if not (Config.Crates.Prizes :: { [string]: { string } })[tier] then
		return
	end
	local list = (Config.Crates.Prizes :: { [string]: { string } })[tier]
	local prize = list[rng:NextInteger(1, #list)]
	local give = GIVE[prize]
	local swapped = false
	if not give or not give(player) then
		treatPack(player)
		prize, swapped = "TreatPack", true
	end
	print(`[Crates] {player.Name} opened a {kind.id}: {tier} {prize}`)
	remotes.CrateOpened:fireClient(player, { crate = kind.id, prize = prize, tier = tier, swapped = swapped })
end

local function buy(player: Player, id: string)
	local kind = Crates.kind(id)
	if not kind then
		return
	end
	local name = Crates.Names[kind.id] or kind.id
	if ShopService.pay(player, ShopService.price(player, SHOP, kind.price), `shop: {id}`, `{name} opened`) then
		CrateService.open(player, kind)
	end
end

function CrateService.start()
	ShopService.register(SHOP, { items = items, buy = buy })
end

return CrateService
