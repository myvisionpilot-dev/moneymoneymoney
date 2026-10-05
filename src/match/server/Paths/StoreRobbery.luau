--!strict
-- Store robberies: hold E at a store's register for a big payout and a lot of heat. With a
-- blaster out it's a hold-up: quicker, and it pays more.
-- Each store closes for StoreRobbery.CooldownSeconds afterwards. Unlocks at Paths.Unlocks.StoreRobbery.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local BlasterService = require(script.Parent.Parent.BlasterService)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local Stats = require(script.Parent.Parent.Stats)
local TwistService = require(script.Parent.Parent.TwistService)

local COUNTER_TAG = "StoreCounter"
local RANGE_SLACK = 3
local LABEL_REFRESH_SECONDS = 1

type Store = {
	counter: BasePart,
	prompt: ProximityPrompt,
	closedUntil: number,
}

local settings = Config.Paths.StoreRobbery
local unlockQuota = Config.Paths.Unlocks.StoreRobbery
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local stores: { Store } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("StoreRobbery used before init")
	end
	return current
end

local function payout(_player: Player, _tier: number): number
	return math.floor(settings.Pay * getContext().payMultiplier() + 0.5)
end

local function rob(player: Player, store: Store): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, `Stores unlock at quota {unlockQuota}.`
	end
	-- A hold-up (blaster out) is quicker and pays more.
	local holdUp = BlasterService.drawn(player)
	local hold = (if holdUp then settings.HoldSeconds / Config.Blasters.HoldUpSpeed else settings.HoldSeconds)
		* TwistService.crimeHoldMultiplier()
	if not ctx.canWork(player) or not PromptGuard.held(store.prompt, player, hold) then
		return false, nil
	end
	if CharacterUtil.distanceTo(player, store.counter.Position) > settings.RangeStuds + RANGE_SLACK then
		return false, nil
	end
	if os.clock() < store.closedUntil then
		return false, "This register is empty. Come back later."
	end
	if EconomyService.isFull(player) then
		return false, "Your bag is full. Deposit at the bank first!"
	end

	store.closedUntil = os.clock() + settings.CooldownSeconds
	local basePay = payout(player, ctx.tier())
	local pay = if holdUp then math.floor(basePay * Config.Blasters.HoldUpPay + 0.5) else basePay
	local added = EconomyService.addCarried(player, pay, if holdUp then "store hold-up" else "store robbery")
	HeatService.add(player, Config.Heat.StoreRobbery)
	PayNotice.send(player, if holdUp then "Store held up" else "Store register emptied", added, pay)
	Stats.record(player, "StoreRobbery")
	local alarm = Sounds.at("Alarm", store.counter, true)
	if alarm then
		Debris:AddItem(alarm, settings.AlarmSeconds)
	end
	Notifier.others(player, "Alarm! Someone just robbed a store.", "Bad")
	return true, nil
end

local function refreshLabels()
	local open = context ~= nil and getContext().isOpen()
	for _, store in stores do
		local closed = os.clock() < store.closedUntil
		store.prompt.Enabled = not closed -- stays visible while locked so players see when it opens
		store.prompt.ObjectText = if open then "Store" else `Unlocks at quota {unlockQuota}`
	end
end

local function setupCounter(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RobPrompt"
	prompt.ActionText = "Rob the register"
	prompt.ObjectText = "Store"
	-- The quickest hold (a hold-up); each player's own screen shows their real hold time
	-- (BlasterController), and rob() checks it.
	prompt.HoldDuration = settings.HoldSeconds / Config.Blasters.HoldUpSpeed
	prompt.MaxActivationDistance = settings.RangeStuds
	prompt.RequiresLineOfSight = false
	PromptGuard.watch(prompt)
	local store: Store = { counter = instance, prompt = prompt, closedUntil = 0 }
	table.insert(stores, store)
	prompt.Triggered:Connect(function(player: Player)
		if not limiter:allow(player) then
			return
		end
		local ok, message = rob(player, store)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = instance
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, instance in CollectionService:GetTagged(COUNTER_TAG) do
		setupCounter(instance)
	end
	CollectionService:GetInstanceAddedSignal(COUNTER_TAG):Connect(setupCounter)
	task.spawn(function()
		while true do
			refreshLabels()
			task.wait(LABEL_REFRESH_SECONDS)
		end
	end)
end

local function start(player: Player, source: Instance?): (boolean, string?)
	for _, store in stores do
		if store.counter == source then
			return rob(player, store)
		end
	end
	return false, nil
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function noJob(_player: Player): boolean
	return false
end

local StoreRobbery: MoneyPath.MoneyPath = {
	id = "StoreRobbery",
	displayName = "Store robberies",
	unlockQuota = unlockQuota,
	legal = false,
	init = init,
	start = start,
	complete = complete,
	fail = function(_player: Player, _reason: string) end,
	payout = payout,
	hasJob = noJob,
	cancelAll = function(_reason: string) end,
}

return StoreRobbery
