--!strict
-- Store robberies: pick "Rob the register" when a shopkeeper talks to you (CounterService), then
-- stay at the counter while it empties: a big payout and a lot of heat. With a blaster out it's
-- a hold-up: quicker, and it pays more. Each register is empty for StoreRobbery.CooldownSeconds
-- afterwards. Unlocks at Paths.Unlocks.StoreRobbery.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local BlasterService = require(script.Parent.Parent.BlasterService)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local Stats = require(script.Parent.Parent.Stats)
local TwistService = require(script.Parent.Parent.TwistService)

local RANGE_SLACK = 3
local TICK_SECONDS = 0.2

-- Called once when a robbery ends: emptied (ok), or cut short with a reason.
export type OnEnd = (ok: boolean, message: string?) -> ()

type Robbery = {
	counter: BasePart,
	endsAt: number,
	holdUp: boolean,
	onEnd: OnEnd,
}

local settings = Config.Paths.StoreRobbery
local unlockQuota = Config.Paths.Unlocks.StoreRobbery

local context: MoneyPath.Context? = nil
local emptyUntil: { [BasePart]: number } = {} -- os.clock(); math.huge while it's being robbed
local robberies: { [Player]: Robbery } = {}

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

local StoreRobbery = {}

-- Why this register can't be robbed right now ("Opens at quota 2"), or nil if it can.
function StoreRobbery.status(counter: BasePart): string?
	if not context or not getContext().isOpen() then
		return `Opens at quota {unlockQuota}`
	end
	local emptyAt = emptyUntil[counter] or 0
	if emptyAt == math.huge then
		return "Someone's robbing it"
	elseif emptyAt > os.clock() then
		return `Empty for {Format.clock(emptyAt - os.clock())}`
	end
	return nil
end

-- What they'd get: more for a hold-up (blaster out).
function StoreRobbery.payFor(player: Player): number
	local base = payout(player, getContext().tier())
	return if BlasterService.drawn(player) then math.floor(base * Config.Blasters.HoldUpPay + 0.5) else base
end

-- Starts emptying the register: returns when it'll be done (server time), or nil and why not.
-- `onEnd` hears how it went.
function StoreRobbery.begin(player: Player, counter: BasePart, onEnd: OnEnd): (number?, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return nil, `Robberies start at quota {unlockQuota}.`
	end
	if robberies[player] or not ctx.canWork(player) then
		return nil, nil
	end
	local reason = StoreRobbery.status(counter)
	if reason then
		return nil, `{reason}. Come back later.`
	end
	if EconomyService.isFull(player) then
		return nil, "Your bag is full. Deposit at the bank first!"
	end
	local holdUp = BlasterService.drawn(player)
	local seconds = (if holdUp then settings.HoldSeconds / Config.Blasters.HoldUpSpeed else settings.HoldSeconds)
		* TwistService.crimeHoldMultiplier()
	local endsAt = Timing.now() + seconds
	emptyUntil[counter] = math.huge
	robberies[player] = { counter = counter, endsAt = endsAt, holdUp = holdUp, onEnd = onEnd }
	return endsAt, nil
end

function StoreRobbery.isRobbing(player: Player): boolean
	return robberies[player] ~= nil
end

local function stop(player: Player, message: string?)
	local robbery = robberies[player]
	if not robbery then
		return
	end
	robberies[player] = nil
	emptyUntil[robbery.counter] = 0
	robbery.onEnd(false, message)
end

local function finish(player: Player, robbery: Robbery)
	robberies[player] = nil
	emptyUntil[robbery.counter] = os.clock() + settings.CooldownSeconds
	local basePay = payout(player, getContext().tier())
	local pay = if robbery.holdUp then math.floor(basePay * Config.Blasters.HoldUpPay + 0.5) else basePay
	HeatService.add(player, Config.Heat.StoreRobbery)
	local label = if robbery.holdUp then "Store held up" else "Store register emptied"
	PayNotice.earn(player, pay, label, if robbery.holdUp then "store hold-up" else "store robbery", false)
	Stats.record(player, "StoreRobbery")
	local alarm = Sounds.at("Alarm", robbery.counter, true)
	if alarm then
		Debris:AddItem(alarm, settings.AlarmSeconds)
	end
	Notifier.others(player, "Alarm! Someone just robbed a store.", "Bad")
	robbery.onEnd(true, nil)
end

-- Walk off (or get busted) before it's empty and it's off.
local function tick()
	for player, robbery in robberies do
		local ctx = getContext()
		if not ctx.canWork(player) then
			stop(player, nil)
		elseif CharacterUtil.distanceTo(player, robbery.counter.Position) > settings.RangeStuds + RANGE_SLACK then
			stop(player, "You ran off before the register was empty.")
		elseif Timing.now() >= robbery.endsAt then
			finish(player, robbery)
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	Players.PlayerRemoving:Connect(function(player: Player)
		stop(player, nil)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

StoreRobbery.path = {
	id = "StoreRobbery",
	displayName = "Store robberies",
	unlockQuota = unlockQuota,
	legal = false,
	init = init,
	start = function(player: Player, source: Instance?): (boolean, string?)
		if not source or not source:IsA("BasePart") then
			return false, nil
		end
		local endsAt, message = StoreRobbery.begin(player, source, function(_ok: boolean, _message: string?) end)
		return endsAt ~= nil, message
	end,
	complete = function(_player: Player): (boolean, string?)
		return false, nil
	end,
	fail = function(player: Player, reason: string)
		stop(player, reason)
	end,
	payout = payout,
	hasJob = StoreRobbery.isRobbing,
	cancelAll = function(reason: string)
		for player in robberies do
			stop(player, reason)
		end
	end,
} :: MoneyPath.MoneyPath

return StoreRobbery
