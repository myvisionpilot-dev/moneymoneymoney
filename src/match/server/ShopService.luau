--!strict
-- The shops. Each counter tagged ShopCounter has a Shop attribute saying what it sells, all
-- paid from the cash in your bag (never your deposits) and all for this run only:
--   Clothes (the BAGS shop): a bigger bag.  Hardware (Handy Hank's): lockpicks.
--   Convenience stores: five-minute boosts (the energy drink goes in your backpack: EnergyDrink).
--   Crates (Tony's): lucky crates (CrateService fills this shop with ShopService.register).
-- (Speedy's Garage sells nothing: it runs the street races and the car flips.) Maps built before
-- the crates came in still say Shop "Guns" on Tony's counter: that's the crate shop too.
-- The shopkeeper's "Buy something" opens it (CounterService). The client only says which item;
-- the server works out which shop you're standing at.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local Perks = require(ServerScriptService.Common.Perks)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local BoostService = require(script.Parent.BoostService)
local EconomyService = require(script.Parent.EconomyService)
local EnergyDrink = require(script.Parent.EnergyDrink)
local FireSale = require(script.Parent.Events.FireSale)
local HustleService = require(script.Parent.HustleService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local TwistService = require(script.Parent.TwistService)

local COUNTER_TAG = "ShopCounter"
local SHOP_ATTRIBUTE = "Shop"
local RANGE_SLACK = 3

type Levels = { [Types.UpgradeId]: number }

local SHOPS: { [Types.ShopId]: { title: string, note: string } } = {
	Clothes = { title = "BAGS", note = "A bigger bag holds more cash between trips to the bank." },
	Hardware = { title = "HANDY HANK'S", note = "A better lockpick makes break-ins quicker." },
	Convenience = { title = "CONVENIENCE STORE", note = "Treats that last 5 minutes. Different ones stack." },
	Crates = { title = "TONY'S CRATES", note = "Treats and upgrades inside. The odds are on every crate." },
}

-- A shop another module stocks (ShopService.register).
export type Stock = {
	items: (player: Player) -> { Types.ShopItem },
	buy: (player: Player, id: string) -> (),
}

local BOOSTS: { { id: Types.BoostId, title: string, detail: string } } = {
	{
		id = "Energy",
		title = "Energy Drink",
		detail = "Drink it when you like: 2x speed on foot.",
	},
	{ id = "Disguise", title = "Disguise", detail = "Your crimes add half as much heat." },
	{ id = "Candy", title = "Candy Bar", detail = "A wider green zone when you pickpocket." },
	{ id = "Gloves", title = "Gloves", detail = "Break-ins take half as long." },
	{ id = "Scanner", title = "Police Scanner", detail = "See every cop in town, even through walls." },
}

local remotes = Remotes.match()
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local ShopService = {
	upgraded = Signal.new() :: Signal.Signal<Player, Types.UpgradeId>,
}

local levels: { [Player]: Levels } = {}
local stocks: { [Types.ShopId]: Stock } = {}

-- Another module stocks this shop: what's on its shelves for a player, and buying one.
function ShopService.register(shop: Types.ShopId, stock: Stock)
	stocks[shop] = stock
end

local function levelsOf(player: Player): Levels
	local current = levels[player]
	if not current then
		current = { Bag = 0, Lockpick = 0 }
		levels[player] = current
	end
	return current
end

function ShopService.level(player: Player, id: Types.UpgradeId): number
	return levelsOf(player)[id] or 0
end

-- Hands them an upgrade level for free (a Cred shop loadout unlock), unless they're already past it.
function ShopService.grant(player: Player, id: Types.UpgradeId, level: number)
	local current = levelsOf(player)
	if (current[id] or 0) >= level then
		return
	end
	current[id] = level
	if id == "Bag" then
		EconomyService.setBagCapacity(player, Config.Shop.Bag[level].capacity)
	end
	ShopService.upgraded:Fire(player, id)
end

-- Break-in hold time: the lockpick shortens it, and so do gloves, Safecracker and a Blackout.
function ShopService.breakInHoldSeconds(player: Player): number
	local level = ShopService.level(player, "Lockpick")
	local seconds = if level == 0
		then Config.Paths.Doors.BaseBreakInHoldSeconds
		else Config.Shop.Lockpick[level].holdSeconds
	return seconds
		* BoostService.breakInMultiplier(player)
		* HustleService.breakInMultiplier(player)
		* TwistService.crimeHoldMultiplier()
		* (1 - Perks.amount(player, "QuickHands"))
end

-- A price after this quota's twists (Sale Day), a fire sale, their Haggler hustle and their
-- Bargain Hunter upgrade, to the nearest $10.
local function price(player: Player, shop: Types.ShopId, base: number): number
	local multiplier = TwistService.shopPriceMultiplier()
		* FireSale.multiplier(shop)
		* HustleService.shopMultiplier(player)
		* (1 - Perks.amount(player, "Bargain"))
	return math.floor(base * multiplier / 10 + 0.5) * 10
end
ShopService.price = price

local function upgradePrice(player: Player, id: Types.UpgradeId, level: number): number?
	local base: number? = nil
	if id == "Bag" then
		local entry = Config.Shop.Bag[level]
		base = if entry then entry.price else nil
	else
		local entry = Config.Shop.Lockpick[level]
		base = if entry then entry.price else nil
	end
	local shop: Types.ShopId = if id == "Bag" then "Clothes" else "Hardware"
	return if base then price(player, shop, base) else nil
end

local function upgradeItem(player: Player, id: Types.UpgradeId): Types.ShopItem
	local level = ShopService.level(player, id)
	local price = upgradePrice(player, id, level + 1)
	local title, now, nextOne, maxLevel
	if id == "Bag" then
		local pockets = HustleService.bagMultiplier(player) -- Deep Pockets
		local capacity = if level == 0 then Config.Economy.BaseBagCapacity else Config.Shop.Bag[level].capacity
		local upgrade = Config.Shop.Bag[level + 1]
		title, maxLevel = "Bigger Bag", #Config.Shop.Bag
		now, nextOne =
			`Holds {Format.money(capacity * pockets)}`,
			if upgrade then `holds {Format.money(upgrade.capacity * pockets)}` else nil
	else
		local upgrade = Config.Shop.Lockpick[level + 1]
		title, maxLevel = "Lockpick", #Config.Shop.Lockpick
		local base = if level == 0
			then Config.Paths.Doors.BaseBreakInHoldSeconds
			else Config.Shop.Lockpick[level].holdSeconds
		now, nextOne = `{base}s break-ins`, if upgrade then `{upgrade.holdSeconds}s` else nil
	end
	return {
		id = id,
		kind = "Upgrade",
		title = title,
		detail = if nextOne then `Now: {now}\nNext: {nextOne}` else `{now} (max)`,
		status = `Level {level}/{maxLevel}`,
		price = price,
	}
end

local function stateFor(player: Player, shop: Types.ShopId): Types.ShopState
	local items: { Types.ShopItem } = {}
	local locked: string? = nil
	if shop == "Clothes" then
		table.insert(items, upgradeItem(player, "Bag"))
	elseif shop == "Hardware" then
		table.insert(items, upgradeItem(player, "Lockpick"))
	elseif shop == "Convenience" then
		local list = BoostService.list(player)
		for _, boost in BOOSTS do
			local endsAt = list[boost.id]
			local carrying = boost.id == "Energy" and EnergyDrink.holding(player)
			table.insert(items, {
				id = boost.id :: string,
				kind = "Boost",
				title = boost.title,
				detail = boost.detail,
				status = if carrying
					then "In your backpack"
					elseif endsAt then `On: {Format.clock(endsAt - Timing.now())} left`
					else "Lasts 5 minutes",
				price = if carrying then nil else price(player, "Convenience", Config.Boosts[boost.id].price),
			})
		end
	elseif stocks[shop] then
		items = stocks[shop].items(player)
	end
	local off = math.floor((1 - TwistService.shopPriceMultiplier() * FireSale.multiplier(shop)) * 100 + 0.5)
	local note = if off > 0 then `SALE: {off}% off everything! {SHOPS[shop].note}` else SHOPS[shop].note
	return { shop = shop, title = SHOPS[shop].title, note = note, items = items, locked = locked }
end

-- A counter's Shop attribute, if it names a real shop.
local function asShop(value: unknown): Types.ShopId?
	if value == "Convenience" or value == "Clothes" or value == "Hardware" or value == "Crates" then
		return value :: any
	elseif value == "Guns" then
		return "Crates"
	end
	return nil
end
ShopService.asShop = asShop

-- The shop a counter belongs to (its Shop attribute), if any.
function ShopService.shopOf(counter: Instance): Types.ShopId?
	return asShop(counter:GetAttribute(SHOP_ATTRIBUTE))
end

function ShopService.title(shop: Types.ShopId): string
	return SHOPS[shop].title
end

-- The shop whose counter they're standing at, if any.
local function shopAt(player: Player): Types.ShopId?
	for _, counter in CollectionService:GetTagged(COUNTER_TAG) do
		local shop = asShop(counter:GetAttribute(SHOP_ATTRIBUTE))
		if
			shop ~= nil
			and counter:IsA("BasePart")
			and CharacterUtil.distanceTo(player, counter.Position) <= Config.Shop.RangeStuds + RANGE_SLACK
		then
			return shop :: any
		end
	end
	return nil
end

local function canShop(player: Player): boolean
	local phase = RunState.phase
	return RosterService.isActive(player)
		and not JailService.isJailed(player)
		and phase ~= "Waiting"
		and phase ~= "Results"
		and phase ~= "Ended"
end
ShopService.canShop = canShop

-- Shows them the shop's window.
function ShopService.open(player: Player, shop: Types.ShopId)
	if canShop(player) then
		remotes.ShopOpen:fireClient(player, stateFor(player, shop))
	end
end

-- Takes the money (with a money line saying what for), or says why not.
local function pay(player: Player, price: number, reason: string, label: string): boolean
	if EconomyService.account(player).carried < price then
		Notifier.send(player, `You need {Format.money(price)} in your bag for that.`, "Bad")
		return false
	end
	EconomyService.removeCarried(player, price, reason)
	Juice.spent(player, price, label)
	return true
end
ShopService.pay = pay

local UPGRADE_LABELS: { [Types.UpgradeId]: string } = {
	Bag = "Bigger bag purchased",
	Lockpick = "Better lockpick purchased",
}

local function buyUpgrade(player: Player, id: Types.UpgradeId): boolean
	local current = levelsOf(player)
	local newLevel = (current[id] or 0) + 1
	local price = upgradePrice(player, id, newLevel)
	if not price or not pay(player, price, `shop: {id:lower()} level {newLevel}`, UPGRADE_LABELS[id]) then
		return false
	end
	current[id] = newLevel
	if id == "Bag" then
		EconomyService.setBagCapacity(player, Config.Shop.Bag[newLevel].capacity)
	end
	ShopService.upgraded:Fire(player, id)
	return true
end

local function buyBoost(player: Player, id: Types.BoostId): boolean
	if id == "Energy" and EnergyDrink.holding(player) then
		Notifier.send(player, "You've already got an energy drink in your backpack.", "Info")
		return false
	end
	local title = id :: string
	for _, boost in BOOSTS do
		if boost.id == id then
			title = boost.title
		end
	end
	if
		not pay(
			player,
			price(player, "Convenience", Config.Boosts[id].price),
			`shop: {id:lower()} boost`,
			`{title} purchased`
		)
	then
		return false
	end
	if id == "Energy" then
		EnergyDrink.give(player)
		Notifier.send(player, "It's in your backpack: hold it, then click (or tap) to drink.", "Info")
	else
		BoostService.give(player, id)
	end
	return true
end

local function onBuy(player: Player, payload: unknown)
	if not buyLimiter:allow(player) or typeof(payload) ~= "string" or not canShop(player) then
		return
	end
	local found = shopAt(player)
	if found == nil then
		return
	end
	local shop: Types.ShopId = found :: any
	if shop == "Clothes" and payload == "Bag" then
		buyUpgrade(player, "Bag")
	elseif shop == "Hardware" and payload == "Lockpick" then
		buyUpgrade(player, "Lockpick")
	elseif shop == "Convenience" then
		for _, boost in BOOSTS do
			if boost.id == payload then
				buyBoost(player, boost.id)
			end
		end
	elseif stocks[shop] then
		stocks[shop].buy(player, payload)
	end
	remotes.ShopOpen:fireClient(player, stateFor(player, found :: any))
end

function ShopService.start()
	remotes.BuyItem:onServer(onBuy)
	Players.PlayerRemoving:Connect(function(player: Player)
		levels[player] = nil
	end)
end

return ShopService
