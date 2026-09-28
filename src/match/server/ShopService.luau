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
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local JailService = require(script.Parent.JailService)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local COUNTER_TAG = "ShopCounter"
local RANGE_SLACK = 3

type Levels = { [Types.UpgradeId]: number }

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

function ShopService.breakInHoldSeconds(player: Player): number
	local level = ShopService.level(player, "Lockpick")
	if level == 0 then
		return Config.Paths.Doors.BaseBreakInHoldSeconds
	end
	return Config.Shop.Lockpick[level].holdSeconds
end

-- Your kart's speed, or nil if you haven't bought one.
function ShopService.rideSpeed(player: Player): number?
	local entry = Config.Shop.Ride[ShopService.level(player, "Ride")]
	return if entry then entry.speed else nil
end

local function priceOf(id: Types.UpgradeId, level: number): number?
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

local function stateFor(player: Player): Types.ShopState
	local bag = ShopService.level(player, "Bag")
	local lockpick = ShopService.level(player, "Lockpick")
	local ride = ShopService.level(player, "Ride")

	local bagCapacity = if bag == 0 then Config.Economy.BaseBagCapacity else Config.Shop.Bag[bag].capacity
	local nextBag = Config.Shop.Bag[bag + 1]
	local nextLockpick = Config.Shop.Lockpick[lockpick + 1]
	local rideSpeed = ShopService.rideSpeed(player)
	local nextRide = Config.Shop.Ride[ride + 1]

	return {
		items = {
			{
				id = "Bag",
				title = "Bag size",
				level = bag,
				maxLevel = #Config.Shop.Bag,
				current = `Holds {Format.money(bagCapacity)}`,
				nextEffect = if nextBag then `Holds {Format.money(nextBag.capacity)}` else nil,
				nextPrice = if nextBag then nextBag.price else nil,
			},
			{
				id = "Lockpick",
				title = "Lockpick",
				level = lockpick,
				maxLevel = #Config.Shop.Lockpick,
				current = `{ShopService.breakInHoldSeconds(player)}s break-ins`,
				nextEffect = if nextLockpick then `{nextLockpick.holdSeconds}s break-ins` else nil,
				nextPrice = if nextLockpick then nextLockpick.price else nil,
			},
			{
				id = "Ride",
				title = "Ride (press R)",
				level = ride,
				maxLevel = #Config.Shop.Ride,
				current = if rideSpeed then `Kart, {rideSpeed} speed` else "On foot",
				nextEffect = if nextRide then `Kart, {nextRide.speed} speed` else nil,
				nextPrice = if nextRide then nextRide.price else nil,
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
	if not buyLimiter:allow(player) then
		return
	end
	local id: Types.UpgradeId
	if payload == "Bag" then
		id = "Bag"
	elseif payload == "Lockpick" then
		id = "Lockpick"
	elseif payload == "Ride" then
		id = "Ride"
	else
		return
	end
	if not canShop(player) or not nearCounter(player) then
		return
	end
	local current = levelsOf(player)
	local newLevel = (current[id] or 0) + 1
	local price = priceOf(id, newLevel)
	if not price then
		return
	end
	if EconomyService.account(player).carried < price then
		Notifier.send(player, `You need {Format.money(price)} in your bag for that.`, "Bad")
		return
	end

	current[id] = newLevel
	EconomyService.removeCarried(player, price, `shop: {id:lower()} level {newLevel}`)
	if id == "Bag" then
		local capacity = Config.Shop.Bag[newLevel].capacity
		EconomyService.setBagCapacity(player, capacity)
		Notifier.send(player, `Bigger bag! It now holds {Format.money(capacity)}.`, "Good")
	elseif id == "Lockpick" then
		Notifier.send(player, `Better lockpick! Break-ins take {ShopService.breakInHoldSeconds(player)}s.`, "Good")
	else
		local speed = Config.Shop.Ride[newLevel].speed
		Notifier.send(player, `New kart (speed {speed})! Press R to hop on or off.`, "Good")
	end
	ShopService.upgraded:Fire(player, id)
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
