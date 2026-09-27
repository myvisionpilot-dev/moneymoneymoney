--!strict
-- In-run upgrades bought with carried cash at Tony's shop counter. Spending never touches
-- your contribution (deposits). Upgrades last for this run only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local JailService = require(script.Parent.JailService)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local COUNTER_TAG = "ShopCounter"
local RANGE_SLACK = 3

type Levels = { Bag: number, Lockpick: number }

local remotes = Remotes.match()
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local openLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local ShopService = {}

local levels: { [Player]: Levels } = {}

local function levelsOf(player: Player): Levels
	local current = levels[player]
	if not current then
		current = { Bag = 0, Lockpick = 0 }
		levels[player] = current
	end
	return current
end

function ShopService.level(player: Player, id: Types.UpgradeId): number
	local current = levelsOf(player)
	return if id == "Bag" then current.Bag else current.Lockpick
end

function ShopService.breakInHoldSeconds(player: Player): number
	local level = levelsOf(player).Lockpick
	if level == 0 then
		return Config.Paths.Doors.BaseBreakInHoldSeconds
	end
	return Config.Shop.Lockpick[level].holdSeconds
end

local function stateFor(player: Player): Types.ShopState
	local current = levelsOf(player)

	local bagCapacity = if current.Bag == 0
		then Config.Economy.BaseBagCapacity
		else Config.Shop.Bag[current.Bag].capacity
	local nextBag = Config.Shop.Bag[current.Bag + 1]

	local nextLockpick = Config.Shop.Lockpick[current.Lockpick + 1]

	return {
		items = {
			{
				id = "Bag",
				title = "Bag size",
				level = current.Bag,
				maxLevel = #Config.Shop.Bag,
				current = `Holds {Format.money(bagCapacity)}`,
				nextEffect = if nextBag then `Holds {Format.money(nextBag.capacity)}` else nil,
				nextPrice = if nextBag then nextBag.price else nil,
			},
			{
				id = "Lockpick",
				title = "Lockpick",
				level = current.Lockpick,
				maxLevel = #Config.Shop.Lockpick,
				current = `{ShopService.breakInHoldSeconds(player)}s break-ins`,
				nextEffect = if nextLockpick then `{nextLockpick.holdSeconds}s break-ins` else nil,
				nextPrice = if nextLockpick then nextLockpick.price else nil,
			},
		},
	}
end

local function nearCounter(player: Player): boolean
	for _, counter in CollectionService:GetTagged(COUNTER_TAG) do
		if
			counter:IsA("BasePart")
			and CharacterUtil.distanceTo(player, counter.Position) <= Config.Shop.RangeStuds + RANGE_SLACK
		then
			return true
		end
	end
	return false
end

local function canShop(player: Player): boolean
	local phase = RunState.phase
	return RosterService.isActive(player)
		and not JailService.isJailed(player)
		and phase ~= "Waiting"
		and phase ~= "Results"
		and phase ~= "Ended"
end

local function onBuy(player: Player, payload: unknown)
	if not buyLimiter:allow(player) or (payload ~= "Bag" and payload ~= "Lockpick") then
		return
	end
	if not canShop(player) or not nearCounter(player) then
		return
	end
	local current = levelsOf(player)
	local price: number
	if payload == "Bag" then
		local nextLevel = Config.Shop.Bag[current.Bag + 1]
		if not nextLevel then
			return
		end
		price = nextLevel.price
	else
		local nextLevel = Config.Shop.Lockpick[current.Lockpick + 1]
		if not nextLevel then
			return
		end
		price = nextLevel.price
	end

	if EconomyService.account(player).carried < price then
		Notifier.send(player, `You need {Format.money(price)} in your bag for that.`, "Bad")
		return
	end
	if payload == "Bag" then
		current.Bag += 1
		EconomyService.removeCarried(player, price, `shop: bag level {current.Bag}`)
		EconomyService.setBagCapacity(player, Config.Shop.Bag[current.Bag].capacity)
		Notifier.send(player, `Bigger bag! It now holds {Format.money(Config.Shop.Bag[current.Bag].capacity)}.`, "Good")
	else
		current.Lockpick += 1
		EconomyService.removeCarried(player, price, `shop: lockpick level {current.Lockpick}`)
		Notifier.send(player, `Better lockpick! Break-ins take {ShopService.breakInHoldSeconds(player)}s.`, "Good")
	end
	remotes.ShopOpen:fireClient(player, stateFor(player))
end

local function setupCounter(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Tony's shop"
	prompt.MaxActivationDistance = Config.Shop.RangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if openLimiter:allow(player) and canShop(player) then
			remotes.ShopOpen:fireClient(player, stateFor(player))
		end
	end)
	prompt.Parent = instance
end

function ShopService.start()
	for _, instance in CollectionService:GetTagged(COUNTER_TAG) do
		setupCounter(instance)
	end
	CollectionService:GetInstanceAddedSignal(COUNTER_TAG):Connect(setupCounter)
	remotes.BuyUpgrade:onServer(onBuy)
	Players.PlayerRemoving:Connect(function(player: Player)
		levels[player] = nil
	end)
end

return ShopService
