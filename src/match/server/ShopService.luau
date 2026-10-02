--!strict
-- The shops. Each counter tagged ShopCounter has a Shop attribute saying what it sells, all
-- paid from the cash in your bag (never your deposits) and all for this run only:
--   Clothes (Threads): a bigger bag.        Hardware (Handy Hank's): lockpicks.
--   Garage (Speedy's): your own kart.       Convenience stores: five-minute boosts.
--   Guns (Tony's Blasters): stun blasters, from quota Blasters.UnlockQuota.
-- The client only says which item; the server works out which shop you're standing at.

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
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local BlasterService = require(script.Parent.BlasterService)
local BoostService = require(script.Parent.BoostService)
local EconomyService = require(script.Parent.EconomyService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local COUNTER_TAG = "ShopCounter"
local SHOP_ATTRIBUTE = "Shop"
local PROMPT_RANGE = 8
local RANGE_SLACK = 3

type Levels = { [Types.UpgradeId]: number }

local SHOPS: { [Types.ShopId]: { title: string, note: string } } = {
	Clothes = { title = "👕 THREADS", note = "A bigger bag holds more cash between trips to the bank." },
	Hardware = { title = "🔧 HANDY HANK'S", note = "A better lockpick makes break-ins quicker." },
	Garage = { title = "🏁 SPEEDY'S GARAGE", note = "Your own kart. Press R (or tap 🏎️) to hop on and off." },
	Convenience = { title = "🏪 CONVENIENCE STORE", note = "Treats that last 5 minutes. Different ones stack." },
	Guns = {
		title = "🔫 TONY'S BLASTERS",
		note = "Stun blasters: zap a cop to get away, zap a rival and grab the cash they drop.",
	},
}

local BOOSTS: { { id: Types.BoostId, icon: string, title: string, detail: string } } = {
	{ id = "Energy", icon = "⚡", title = "Energy Drink", detail = "Walk and sprint twice as fast (not in a kart)." },
	{ id = "Disguise", icon = "🧢", title = "Disguise", detail = "Your crimes add half as much heat." },
	{ id = "Candy", icon = "🍫", title = "Candy Bar", detail = "A wider green zone when you pickpocket." },
	{ id = "Gloves", icon = "🧤", title = "Gloves", detail = "Break-ins take half as long." },
	{ id = "Scanner", icon = "📻", title = "Police Scanner", detail = "See every cop in town, even through walls." },
}

local BLASTERS: { { id: Types.BlasterId, icon: string, title: string } } = {
	{ id = "Zapper", icon = "🔫", title = "Zapper" },
	{ id = "MegaZapper", icon = "💥", title = "Mega Zapper" },
}

local remotes = Remotes.match()
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local openLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local ShopService = {
	upgraded = Signal.new() :: Signal.Signal<Player, Types.UpgradeId>,
}

local levels: { [Player]: Levels } = {}

local function levelsOf(player: Player): Levels
	local current = levels[player]
	if not current then
		current = { Bag = 0, Lockpick = 0, Ride = 0 }
		levels[player] = current
	end
	return current
end

function ShopService.level(player: Player, id: Types.UpgradeId): number
	return levelsOf(player)[id] or 0
end

-- Break-in hold time: the lockpick shortens it, and so do gloves.
function ShopService.breakInHoldSeconds(player: Player): number
	local level = ShopService.level(player, "Lockpick")
	local seconds = if level == 0
		then Config.Paths.Doors.BaseBreakInHoldSeconds
		else Config.Shop.Lockpick[level].holdSeconds
	return seconds * BoostService.breakInMultiplier(player)
end

-- Your kart's speed, or nil if you haven't bought one.
function ShopService.rideSpeed(player: Player): number?
	local entry = Config.Shop.Ride[ShopService.level(player, "Ride")]
	return if entry then entry.speed else nil
end

local function upgradePrice(id: Types.UpgradeId, level: number): number?
	if id == "Bag" then
		local entry = Config.Shop.Bag[level]
		return if entry then entry.price else nil
	elseif id == "Lockpick" then
		local entry = Config.Shop.Lockpick[level]
		return if entry then entry.price else nil
	end
	local entry = Config.Shop.Ride[level]
	return if entry then entry.price else nil
end

local function upgradeItem(player: Player, id: Types.UpgradeId): Types.ShopItem
	local level = ShopService.level(player, id)
	local price = upgradePrice(id, level + 1)
	local icon, title, now, nextOne, maxLevel
	if id == "Bag" then
		local capacity = if level == 0 then Config.Economy.BaseBagCapacity else Config.Shop.Bag[level].capacity
		local upgrade = Config.Shop.Bag[level + 1]
		icon, title, maxLevel = "🎒", "Bigger Bag", #Config.Shop.Bag
		now, nextOne =
			`Holds {Format.money(capacity)}`, if upgrade then `holds {Format.money(upgrade.capacity)}` else nil
	elseif id == "Lockpick" then
		local upgrade = Config.Shop.Lockpick[level + 1]
		icon, title, maxLevel = "🔑", "Lockpick", #Config.Shop.Lockpick
		local base = if level == 0
			then Config.Paths.Doors.BaseBreakInHoldSeconds
			else Config.Shop.Lockpick[level].holdSeconds
		now, nextOne = `{base}s break-ins`, if upgrade then `{upgrade.holdSeconds}s` else nil
	else
		local speed = ShopService.rideSpeed(player)
		local upgrade = Config.Shop.Ride[level + 1]
		icon, title, maxLevel = "🏎️", "Kart", #Config.Shop.Ride
		now, nextOne =
			if speed then `Kart, speed {speed}` else "On foot", if upgrade then `speed {upgrade.speed}` else nil
	end
	return {
		id = id,
		kind = "Upgrade",
		icon = icon,
		title = title,
		detail = if nextOne then `{now} ➡️ {nextOne}` else `{now} (max)`,
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
	elseif shop == "Garage" then
		table.insert(items, upgradeItem(player, "Ride"))
	elseif shop == "Convenience" then
		local list = BoostService.list(player)
		for _, boost in BOOSTS do
			local endsAt = list[boost.id]
			table.insert(items, {
				id = boost.id :: string,
				kind = "Boost",
				icon = boost.icon,
				title = boost.title,
				detail = boost.detail,
				status = if endsAt then `On: {Format.clock(endsAt - Timing.now())} left` else "Lasts 5 minutes",
				price = Config.Boosts[boost.id].price,
			})
		end
	else
		local have = BlasterService.owned(player)
		for _, blaster in BLASTERS do
			local stats = Config.Blasters[blaster.id]
			local yours = have == blaster.id or (have == "MegaZapper" and blaster.id == "Zapper")
			table.insert(items, {
				id = blaster.id :: string,
				kind = "Blaster",
				icon = blaster.icon,
				title = blaster.title,
				detail = `Range {stats.range} · reloads in {stats.cooldown}s · freezes cops for {stats.copStunSeconds}s`,
				status = if have == blaster.id then "Yours" else nil,
				price = if yours then nil else stats.price,
			})
		end
		if RunState.quotaIndex < Config.Blasters.UnlockQuota then
			locked = `Tony's not selling yet. Come back at quota {Config.Blasters.UnlockQuota}.`
		end
	end
	return { shop = shop, title = SHOPS[shop].title, note = SHOPS[shop].note, items = items, locked = locked }
end

-- A counter's Shop attribute, if it names a real shop.
local function asShop(value: unknown): Types.ShopId?
	if value == "Convenience" or value == "Clothes" or value == "Hardware" or value == "Garage" or value == "Guns" then
		return value :: any
	end
	return nil
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

-- Takes the money, or says why not.
local function pay(player: Player, price: number, reason: string): boolean
	if EconomyService.account(player).carried < price then
		Notifier.send(player, `You need {Format.money(price)} in your bag for that.`, "Bad")
		return false
	end
	EconomyService.removeCarried(player, price, reason)
	return true
end

local function buyUpgrade(player: Player, id: Types.UpgradeId): boolean
	local current = levelsOf(player)
	local newLevel = (current[id] or 0) + 1
	local price = upgradePrice(id, newLevel)
	if not price or not pay(player, price, `shop: {id:lower()} level {newLevel}`) then
		return false
	end
	current[id] = newLevel
	if id == "Bag" then
		local capacity = Config.Shop.Bag[newLevel].capacity
		EconomyService.setBagCapacity(player, capacity)
		Notifier.send(player, `Bigger bag! It now holds {Format.money(capacity)}.`, "Good")
	elseif id == "Lockpick" then
		Notifier.send(player, `Better lockpick! Break-ins take {ShopService.breakInHoldSeconds(player)}s.`, "Good")
	else
		local speed = Config.Shop.Ride[newLevel].speed
		Notifier.send(player, `New kart (speed {speed})! Press R (or tap 🏎️) to hop on or off.`, "Good")
	end
	ShopService.upgraded:Fire(player, id)
	return true
end

local function buyBoost(player: Player, id: Types.BoostId): boolean
	if not pay(player, Config.Boosts[id].price, `shop: {id:lower()} boost`) then
		return false
	end
	BoostService.give(player, id)
	for _, boost in BOOSTS do
		if boost.id == id then
			Notifier.send(player, `{boost.icon} {boost.title}! {boost.detail} (5 minutes)`, "Good")
		end
	end
	return true
end

local function buyBlaster(player: Player, id: Types.BlasterId): boolean
	if RunState.quotaIndex < Config.Blasters.UnlockQuota then
		Notifier.send(player, `Tony's not selling yet. Come back at quota {Config.Blasters.UnlockQuota}.`, "Info")
		return false
	end
	local have = BlasterService.owned(player)
	if have == id or (have == "MegaZapper" and id == "Zapper") then
		return false
	end
	if not pay(player, Config.Blasters[id].price, `shop: {id:lower()}`) then
		return false
	end
	BlasterService.give(player, id)
	Notifier.send(
		player,
		'Tony: "Pleasure doing business." It\'s in your backpack: press 1 (or tap it) to draw it.',
		"Good"
	)
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
	local bought = false
	if shop == "Clothes" and payload == "Bag" then
		bought = buyUpgrade(player, "Bag")
	elseif shop == "Hardware" and payload == "Lockpick" then
		bought = buyUpgrade(player, "Lockpick")
	elseif shop == "Garage" and payload == "Ride" then
		bought = buyUpgrade(player, "Ride")
	elseif shop == "Convenience" then
		for _, boost in BOOSTS do
			if boost.id == payload then
				bought = buyBoost(player, boost.id)
			end
		end
	elseif shop == "Guns" then
		for _, blaster in BLASTERS do
			if blaster.id == payload then
				bought = buyBlaster(player, blaster.id)
			end
		end
	end
	if bought then
		Juice.sound(player, "Purchase")
	end
	remotes.ShopOpen:fireClient(player, stateFor(player, found :: any))
end

local function setupCounter(instance: Instance)
	local found = asShop(instance:GetAttribute(SHOP_ATTRIBUTE))
	if found == nil or not instance:IsA("BasePart") then
		return
	end
	local id: Types.ShopId = found :: any
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = SHOPS[id].title
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if openLimiter:allow(player) and canShop(player) then
			remotes.ShopOpen:fireClient(player, stateFor(player, id))
		end
	end)
	prompt.Parent = instance
end

function ShopService.start()
	for _, instance in CollectionService:GetTagged(COUNTER_TAG) do
		setupCounter(instance)
	end
	CollectionService:GetInstanceAddedSignal(COUNTER_TAG):Connect(setupCounter)
	remotes.BuyItem:onServer(onBuy)
	Players.PlayerRemoving:Connect(function(player: Player)
		levels[player] = nil
	end)
end

return ShopService
