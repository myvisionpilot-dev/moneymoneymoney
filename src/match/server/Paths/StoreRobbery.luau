--!strict
-- Store robberies: pick "Rob the register" when a shopkeeper talks to you (CounterService) and
-- the till opens on your screen, seen from above (client/RegisterController): click the bills
-- out of its slots before StoreRobbery.GrabSeconds run out. You get what you grabbed, a lot of
-- heat and the alarm. Walk off and it ends with what you've got. Each register is empty for
-- StoreRobbery.CooldownSeconds afterwards. Unlocks at Paths.Unlocks.StoreRobbery.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local Perks = require(ServerScriptService.Common.Perks)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local Stats = require(script.Parent.Parent.Stats)
local TwistService = require(script.Parent.Parent.TwistService)

local RANGE_SLACK = 3
local TICK_SECONDS = 0.2

-- Called once when a robbery ends: with cash grabbed (ok), or cut short with a reason.
export type OnEnd = (ok: boolean, message: string?) -> ()

type Robbery = {
	counter: BasePart,
	endsAt: number, -- server time
	slots: { Types.RegisterSlot },
	grabbed: number, -- dollars so far
	lastGrab: number, -- os.clock()
	onEnd: OnEnd,
}

local settings = Config.Paths.StoreRobbery
local unlockQuota = Config.Paths.Unlocks.StoreRobbery
local remotes = Remotes.match()
local rng = Random.new()

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

-- What the whole till holds.
function StoreRobbery.payFor(player: Player): number
	return payout(player, getContext().tier())
end

-- Fills the till: `total` split across the slots by weight, a few bills in each.
local function fillTill(total: number): { Types.RegisterSlot }
	local weights = settings.SlotWeights
	local sum = 0
	for _, weight in weights do
		sum += weight
	end
	local slots: { Types.RegisterSlot } = {}
	for _, weight in weights do
		local bills = rng:NextInteger(settings.BillsPerSlot[1], settings.BillsPerSlot[2])
		local value = math.max(math.floor(total * weight / sum / bills / 10 + 0.5) * 10, 10)
		table.insert(slots, { bills = bills, value = value })
	end
	return slots
end

-- Opens the till for them: returns when time's up (server time), or nil and why not.
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
	-- Longer at the till: Quick Hands, and twists that make crimes quicker.
	local seconds = settings.GrabSeconds * (1 + Perks.amount(player, "QuickHands")) / TwistService.crimeHoldMultiplier()
	local endsAt = Timing.now() + seconds
	local slots = fillTill(StoreRobbery.payFor(player))
	emptyUntil[counter] = math.huge
	robberies[player] = {
		counter = counter,
		endsAt = endsAt,
		slots = slots,
		grabbed = 0,
		lastGrab = 0,
		onEnd = onEnd,
	}
	remotes.RegisterGame:fireClient(player, { slots = table.clone(slots), endsAt = endsAt })
	return endsAt, nil
end

function StoreRobbery.isRobbing(player: Player): boolean
	return robberies[player] ~= nil
end

-- Over: pay what they grabbed (with the heat and the alarm), or nothing if they grabbed nothing
-- or it was cut short (`forfeit`: busted, or the quota ended).
local function finish(player: Player, robbery: Robbery, message: string?, forfeit: boolean?)
	if robberies[player] ~= robbery then
		return
	end
	robberies[player] = nil
	if player.Parent then
		remotes.RegisterGame:fireClient(player, nil)
	end
	if forfeit or robbery.grabbed <= 0 then
		emptyUntil[robbery.counter] = 0
		robbery.onEnd(false, if forfeit then message else message or "You didn't grab anything.")
		return
	end
	emptyUntil[robbery.counter] = os.clock() + settings.CooldownSeconds
	HeatService.add(player, Config.Heat.StoreRobbery)
	PayNotice.earn(player, robbery.grabbed, "Till emptied", "store robbery", false)
	Stats.record(player, "StoreRobbery")
	local alarm = Sounds.at("Alarm", robbery.counter, true)
	if alarm then
		Debris:AddItem(alarm, settings.AlarmSeconds)
	end
	Notifier.others(player, "Alarm! Someone just robbed a store.", "Bad")
	robbery.onEnd(true, message)
end

local function onGrab(player: Player, payload: unknown)
	local robbery = robberies[player]
	if not robbery or typeof(payload) ~= "number" then
		return
	end
	local slot = robbery.slots[payload :: number]
	local now = os.clock()
	if not slot or slot.bills <= 0 or now - robbery.lastGrab < settings.MinGrabGap then
		return
	end
	if Timing.now() > robbery.endsAt + settings.LatencySlack then
		return
	end
	robbery.lastGrab = now
	slot.bills -= 1
	robbery.grabbed += slot.value
	for _, other in robbery.slots do
		if other.bills > 0 then
			return
		end
	end
	finish(player, robbery, nil) -- cleaned it out
end

-- Time's up, or they walked off (or got busted).
local function tick()
	for player, robbery in robberies do
		local ctx = getContext()
		if not ctx.canWork(player) then
			finish(player, robbery, nil, true)
		elseif CharacterUtil.distanceTo(player, robbery.counter.Position) > settings.RangeStuds + RANGE_SLACK then
			finish(player, robbery, "You ran off with what you'd grabbed.")
		elseif Timing.now() >= robbery.endsAt + settings.LatencySlack then
			finish(player, robbery, nil)
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	remotes.RegisterGrab:onServer(onGrab)
	Players.PlayerRemoving:Connect(function(player: Player)
		local robbery = robberies[player]
		if robbery then
			robberies[player] = nil
			emptyUntil[robbery.counter] = 0
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

local function stop(player: Player, reason: string?)
	local robbery = robberies[player]
	if robbery then
		finish(player, robbery, reason, true)
	end
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
