--!strict
-- Burger Barn: clock in at the counter for a shift of BurgerBarn.Orders orders in ShiftSeconds.
-- Each customer wants some of: a burger, fries, a shake. Grill: put a patty on, take it off
-- once it's cooked (GrillSeconds) and before it burns (BurnSeconds later), or scrape it off
-- and start again. Fryer and shake machine: hold E. Then serve the tray at the counter. Pays
-- per order, plus NoBurnBonus for a full shift with nothing burnt. One cook at a time.
-- The grill and fryer sizzle while they cook, the shake machine whirrs while you pour, and a desk
-- bell rings when a customer walks up.
-- Map tags: BurgerCounter, BurgerGrill, BurgerFryer, BurgerShake (kitchen stations),
-- BurgerCustomer (where customers stand, facing the counter).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Carry = require(script.Parent.Parent.Carry)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local JobKit = require(script.Parent.JobKit)

local TICK_SECONDS = 0.1
local LEAVE_STUDS = 60 -- wander this far from the counter and the shift ends
local NEXT_ORDER_SECONDS = 1.5
local RAW = Color3.fromRGB(230, 120, 120)
local COOKED = Color3.fromRGB(120, 70, 40)
local BURNT = Color3.fromRGB(25, 20, 20)

type Item = "Burger" | "Fries" | "Shake"
type Grill = "Empty" | "Cooking" | "Done" | "Burnt"

local ITEMS: { Item } = { "Burger", "Fries", "Shake" }
local CHANCE: { [string]: number } = { Burger = 0.8, Fries = 0.5, Shake = 0.5 }
local STATION_TAGS: { [string]: string } = { Burger = "BurgerGrill", Fries = "BurgerFryer", Shake = "BurgerShake" }

type Shift = {
	player: Player,
	endsAt: number,
	served: number,
	burnt: boolean,
	order: { Item },
	ready: { [string]: boolean }, -- by Item
	customer: JobKit.Customer?,
	grill: Grill,
	cookStarted: number,
	patty: BasePart?,
	machine: Sound?, -- the fryer's sizzle or the shake machine's whirr while E is held
	tray: BasePart?,
	prompts: { [string]: ProximityPrompt },
	waiting: boolean, -- between orders
}

local settings = Config.Paths.BurgerBarn
local rng = Random.new()

local shift: Shift? = nil -- one cook at a time
local context: MoneyPath.Context? = nil
local clockIn: ProximityPrompt? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("BurgerBarn used before init")
	end
	return current
end

local function orderPay(): number
	return JobKit.scaled(settings.PayPerOrder, getContext().payMultiplier())
end

local function wants(current: Shift, item: Item): boolean
	return table.find(current.order, item) ~= nil and not current.ready[item]
end

local function allReady(current: Shift): boolean
	for _, item in current.order do
		if not current.ready[item] then
			return false
		end
	end
	return true
end

-- Prompts show only for what this order still needs.
local function refresh(current: Shift)
	local prompts = current.prompts
	local busy = current.waiting
	if prompts.Grill then
		prompts.Grill.Enabled = not busy and wants(current, "Burger") and current.grill ~= "Cooking"
		prompts.Grill.ActionText = if current.grill == "Done"
			then "Take patty"
			elseif current.grill == "Burnt" then "Scrape it off"
			else "Add patty"
		prompts.Grill.HoldDuration = if current.grill == "Burnt" then 0.8 else 0.3
	end
	if prompts.Fryer then
		prompts.Fryer.Enabled = not busy and wants(current, "Fries")
	end
	if prompts.Shake then
		prompts.Shake.Enabled = not busy and wants(current, "Shake")
	end
	if prompts.Serve then
		prompts.Serve.Enabled = not busy and allReady(current)
	end

	local markers: { Vector3 } = {}
	if not busy then
		if allReady(current) then
			local counter = JobKit.first("BurgerCounter")
			if counter then
				table.insert(markers, counter.Position)
			end
		else
			for _, item in current.order do
				local station = JobKit.first(STATION_TAGS[item])
				if station and not current.ready[item] then
					table.insert(markers, station.Position)
				end
			end
		end
	end
	local title = `Order {current.served + 1}/{settings.Orders}: {table.concat(current.order, ", ")}`
	JobKit.guide(current.player, title, markers, current.endsAt, orderPay())
end

local function setReady(current: Shift, item: Item)
	current.ready[item] = true
	if not current.tray then
		current.tray = Carry.prop(current.player, "Tray")
	end
	Juice.sound(current.player, "Ding")
	refresh(current)
end

local function newOrder(current: Shift)
	local order: { Item } = {}
	for _, item in ITEMS do
		if rng:NextNumber() < CHANCE[item] then
			table.insert(order, item)
		end
	end
	if #order == 0 then
		table.insert(order, "Burger")
	end
	current.order = order
	current.ready = {}
	current.waiting = false
	local spot = JobKit.first("BurgerCustomer")
	if spot then
		current.customer = JobKit.customer(JobKit.ground(spot))
	end
	local counter = JobKit.first("BurgerCounter")
	if counter then
		Sounds.at("CustomerBell", counter)
	end
	refresh(current)
end

local function stopMachine(current: Shift)
	if current.machine then
		current.machine:Destroy()
		current.machine = nil
	end
end

-- A sound from the station for as long as E is held on its prompt.
local function soundWhileHeld(current: Shift, prompt: ProximityPrompt, station: BasePart, sound: string)
	prompt.PromptButtonHoldBegan:Connect(function()
		if shift == current and not current.machine then
			current.machine = Sounds.at(sound, station, true)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		stopMachine(current)
	end)
end

local function clearPatty(current: Shift)
	if current.patty then
		current.patty:Destroy()
		current.patty = nil
	end
	current.grill = "Empty"
end

local function endShift(reason: string?, kind: ("Info" | "Good" | "Bad")?)
	local current = shift
	if not current then
		return
	end
	shift = nil
	for _, prompt in current.prompts do
		prompt:Destroy()
	end
	clearPatty(current)
	stopMachine(current)
	if current.tray then
		current.tray:Destroy()
	end
	JobKit.dismiss(current.customer)
	JobKit.clearGuide(current.player)
	if clockIn then
		clockIn.Enabled = true
	end
	if reason then
		Notifier.send(current.player, reason, kind or "Info")
	end
end

local function serve(current: Shift)
	if current.waiting or not allReady(current) then
		return
	end
	current.served += 1
	current.waiting = true
	if current.tray then
		current.tray:Destroy()
		current.tray = nil
	end
	JobKit.dismiss(current.customer)
	current.customer = nil
	JobKit.pay(current.player, orderPay(), "Customer served", "burger order", "BurgerOrder")
	if current.served >= settings.Orders then
		if not current.burnt then
			local bonus = JobKit.scaled(settings.NoBurnBonus, getContext().payMultiplier())
			JobKit.pay(current.player, bonus, "No-burn shift bonus", "burger bonus")
		end
		endShift("Shift done. Nice cooking!", "Good")
		return
	end
	refresh(current)
	task.delay(NEXT_ORDER_SECONDS, function()
		if shift == current then
			newOrder(current)
		end
	end)
end

local function onGrill(current: Shift, grillPart: BasePart)
	if current.grill == "Empty" then
		current.patty = JobKit.prop(
			workspace,
			"Patty",
			Vector3.new(1.6, 0.4, 1.6),
			grillPart.CFrame * CFrame.new(0, grillPart.Size.Y / 2 + 0.2, 0),
			RAW,
			Enum.Material.Sand
		)
		Sounds.at("Sizzle", current.patty :: BasePart, true) -- goes when the patty does
		current.grill = "Cooking"
		current.cookStarted = os.clock()
		refresh(current)
	elseif current.grill == "Done" then
		clearPatty(current)
		setReady(current, "Burger")
	elseif current.grill == "Burnt" then
		clearPatty(current)
		refresh(current)
	end
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Burger Barn opens when a quota starts."
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if shift then
		return false, "Someone's already on the grill. Try again soon."
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	local current: Shift = {
		player = player,
		endsAt = Timing.now() + settings.ShiftSeconds,
		served = 0,
		burnt = false,
		order = {},
		ready = {},
		customer = nil,
		grill = "Empty",
		cookStarted = 0,
		patty = nil,
		machine = nil,
		tray = nil,
		prompts = {},
		waiting = false,
	}
	shift = current
	local range = settings.RangeStuds
	local grillPart = JobKit.first("BurgerGrill")
	if grillPart then
		current.prompts.Grill = JobKit.prompt(
			grillPart,
			{ action = "Add patty", object = "Grill", hold = 0.3, range = range, owner = player },
			function()
				onGrill(current, grillPart)
			end
		)
	end
	local fryer = JobKit.first("BurgerFryer")
	if fryer then
		current.prompts.Fryer = JobKit.prompt(
			fryer,
			{ action = "Fry", object = "Fryer", hold = settings.FryHoldSeconds, range = range, owner = player },
			function()
				stopMachine(current)
				setReady(current, "Fries")
			end
		)
		soundWhileHeld(current, current.prompts.Fryer, fryer, "Sizzle")
	end
	local shaker = JobKit.first("BurgerShake")
	if shaker then
		current.prompts.Shake = JobKit.prompt(shaker, {
			action = "Pour shake",
			object = "Shake machine",
			hold = settings.ShakeHoldSeconds,
			range = range,
			owner = player,
		}, function()
			stopMachine(current)
			setReady(current, "Shake")
		end)
		soundWhileHeld(current, current.prompts.Shake, shaker, "Milkshake")
	end
	local counter = JobKit.first("BurgerCounter")
	if counter then
		current.prompts.Serve = JobKit.prompt(
			counter,
			{ action = "Serve order", object = "Counter", hold = 0.3, range = range, owner = player },
			function()
				serve(current)
			end
		)
	end
	if clockIn then
		clockIn.Enabled = false
	end
	newOrder(current)
	Notifier.send(player, `You're on the grill! {settings.Orders} orders to make. Follow the markers.`, "Info")
	return true, nil
end

local function tick()
	local current = shift
	if not current then
		return
	end
	local counter = JobKit.first("BurgerCounter")
	if not current.player.Parent then
		endShift()
		return
	elseif Timing.now() > current.endsAt then
		endShift(`Shift's over. You served {current.served}/{settings.Orders} orders.`, "Bad")
		return
	elseif counter and CharacterUtil.distanceTo(current.player, counter.Position) > LEAVE_STUDS then
		endShift("You walked out on your shift.", "Bad")
		return
	end
	local patty = current.patty
	if not patty then
		return
	end
	local cooked = os.clock() - current.cookStarted
	if current.grill == "Cooking" then
		patty.Color = RAW:Lerp(COOKED, math.clamp(cooked / settings.GrillSeconds, 0, 1))
		if cooked >= settings.GrillSeconds then
			current.grill = "Done"
			Juice.sound(current.player, "Ding")
			refresh(current)
		end
	elseif current.grill == "Done" and cooked >= settings.GrillSeconds + settings.BurnSeconds then
		current.grill = "Burnt"
		current.burnt = true
		patty.Color = BURNT
		Juice.sound(current.player, "Fail")
		Notifier.send(current.player, "It burnt! Scrape it off and start again.", "Bad")
		refresh(current)
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	local counter = JobKit.first("BurgerCounter")
	if counter then
		clockIn = JobKit.prompt(counter, { action = "Clock in", object = "Burger Barn", hold = 0.3 }, function(player)
			local ok, message = start(player)
			if not ok and message then
				Notifier.send(player, message, "Info")
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		if shift and shift.player == player then
			endShift()
		end
	end)
	JobKit.every(TICK_SECONDS, tick)
end

local BurgerBarn: MoneyPath.MoneyPath = {
	id = "BurgerBarn",
	displayName = "Burger Barn shifts",
	unlockQuota = Config.Paths.Unlocks.BurgerBarn,
	legal = true,
	init = init,
	start = start,
	complete = function(_player: Player): (boolean, string?)
		return false, nil
	end,
	fail = function(player: Player, reason: string)
		if shift and shift.player == player then
			endShift(reason, "Bad")
		end
	end,
	payout = function(_player: Player, _tier: number): number
		return orderPay()
	end,
	hasJob = function(player: Player): boolean
		return shift ~= nil and shift.player == player
	end,
	cancelAll = function(reason: string)
		endShift(reason, "Bad")
	end,
}

return BurgerBarn
