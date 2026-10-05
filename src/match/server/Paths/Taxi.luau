--!strict
-- Taxi (City Cabs): hold E at the desk to start a shift in a yellow cab. A passenger waits at
-- one of the taxi stops; pull up slowly and they hop in, then drive them to the marked stop
-- for Taxi.BaseFare plus Taxi.PerStud for every stud of the trip. The next fare comes straight
-- away. A passenger gives up waiting after PickupSeconds, or gets out without paying if the
-- ride takes longer than FareSeconds. Getting out of the cab (R) ends the shift.
-- Map tags: TaxiDesk (the counter), TaxiSpawn (where the cab waits, facing along the road),
-- TaxiStop (on the footpaths, facing the road).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Timing = require(ReplicatedStorage.Shared.Timing)
local EconomyService = require(script.Parent.Parent.EconomyService)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local VehicleService = require(script.Parent.Parent.VehicleService)
local JobKit = require(script.Parent.JobKit)

local DESK_TAG = "TaxiDesk"
local SPAWN_TAG = "TaxiSpawn"
local STOP_TAG = "TaxiStop"
local CHECK_SECONDS = 0.2
local NEARBY_STOP = 60 -- don't send them to a passenger they're already parked next to
local FASTEST = 1.5 -- a trip faster than straight-line at this x the cab's top speed is voided
local HOP_OUT_SECONDS = 4 -- a dropped-off passenger stands around this long

local settings = Config.Paths.Taxi
local rng = Random.new()

type Fare = {
	pickup: BasePart,
	dropoff: BasePart,
	aboard: boolean,
	endsAt: number,
	pickedUpAt: number,
	pay: number,
	passenger: JobKit.Customer?,
}

type Shift = {
	fare: Fare?,
	fares: number,
}

local shifts: { [Player]: Shift } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("Taxi used before init")
	end
	return current
end

-- Passengers wait at the back of the footpath, out of the pedestrians' way.
local function standingAt(stop: BasePart): CFrame
	return JobKit.ground(stop) * CFrame.new(0, 0, 2)
end

local function fareFor(distance: number): number
	return JobKit.scaled(settings.BaseFare + settings.PerStud * distance, getContext().payMultiplier())
end

local function guide(player: Player, fare: Fare)
	local target = if fare.aboard then fare.dropoff else fare.pickup
	local title = if fare.aboard then "Taxi: drop them off" else "Taxi: pick up"
	JobKit.guide(player, title, { target.Position }, fare.endsAt, fare.pay)
end

-- A passenger somewhere away from the cab, going somewhere well away from them.
local function newFare(player: Player, shift: Shift)
	local stops = JobKit.tagged(STOP_TAG)
	local root = CharacterUtil.getRoot(player)
	if #stops < 2 or not root then
		return
	end
	local away: { BasePart } = {}
	for _, stop in stops do
		if (stop.Position - root.Position).Magnitude >= NEARBY_STOP then
			table.insert(away, stop)
		end
	end
	local pool = if #away > 0 then away else stops
	local pickup = pool[rng:NextInteger(1, #pool)]
	local far: { BasePart } = {}
	local farthest, farthestDistance = stops[1], -1
	for _, stop in stops do
		local distance = (stop.Position - pickup.Position).Magnitude
		if distance >= settings.MinTripStuds then
			table.insert(far, stop)
		end
		if distance > farthestDistance then
			farthest, farthestDistance = stop, distance
		end
	end
	local dropoff = if #far > 0 then far[rng:NextInteger(1, #far)] else farthest
	local fare: Fare = {
		pickup = pickup,
		dropoff = dropoff,
		aboard = false,
		endsAt = Timing.now() + settings.PickupSeconds,
		pickedUpAt = 0,
		pay = fareFor((dropoff.Position - pickup.Position).Magnitude),
		passenger = JobKit.customer(standingAt(pickup)),
	}
	shift.fare = fare
	guide(player, fare)
end

local function endShift(player: Player, reason: string?, kind: ("Info" | "Bad")?)
	local shift = shifts[player]
	if not shift then
		return
	end
	shifts[player] = nil
	if shift.fare then
		JobKit.dismiss(shift.fare.passenger)
	end
	if VehicleService.kind(player) == "Taxi" then
		VehicleService.dismount(player)
	end
	JobKit.clearGuide(player)
	if reason then
		Notifier.send(player, reason, kind or "Info")
	end
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Taxi shifts start when a quota does."
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	if EconomyService.isFull(player) then
		return false, "Your bag is full. Deposit at the bank first!"
	end
	local spawn = JobKit.first(SPAWN_TAG)
	if not spawn then
		return false, "City Cabs has no cabs today."
	end
	if not VehicleService.mount(player, "Taxi", settings.DriveSpeed, Color3.new(1, 1, 0), JobKit.ground(spawn)) then
		return false, nil
	end
	local shift: Shift = { fare = nil, fares = 0 }
	shifts[player] = shift
	newFare(player, shift)
	Notifier.send(player, "You're on shift! Pick up your passenger. Press R to end your shift.", "Info")
	return true, nil
end

-- Pulled up at the stop they're heading for (slowly enough to hop in or out).
local function atStop(player: Player, stop: BasePart): boolean
	return CharacterUtil.distanceTo(player, stop.Position) <= settings.StopRadiusStuds
		and JobKit.speed(player) <= settings.StopSpeed
end

local function pickUp(player: Player, fare: Fare)
	JobKit.dismiss(fare.passenger)
	fare.passenger = nil
	fare.aboard = true
	fare.pickedUpAt = Timing.now()
	fare.endsAt = fare.pickedUpAt + settings.FareSeconds
	guide(player, fare)
	Juice.sound(player, "Ding")
	Notifier.send(player, "Passenger aboard! Get them to the marked stop.", "Info")
end

local function dropOff(player: Player, shift: Shift, fare: Fare)
	shift.fare = nil
	local trip = (fare.dropoff.Position - fare.pickup.Position).Magnitude
	if Timing.now() - fare.pickedUpAt < trip / (settings.DriveSpeed * FASTEST) then
		warn(`[Taxi] {player.Name} finished a {math.floor(trip)}-stud fare impossibly fast`)
		Notifier.send(player, "Your passenger won't pay: that ride was impossibly fast.", "Bad")
	else
		JobKit.pay(player, fare.pay, "Passenger dropped off", "taxi fare", "TaxiFare")
		shift.fares += 1
	end
	JobKit.dismiss(JobKit.customer(standingAt(fare.dropoff)), HOP_OUT_SECONDS)
	newFare(player, shift)
end

local function checkShifts()
	local now = Timing.now()
	for player, shift in shifts do
		local fare = shift.fare
		if not player.Parent then
			endShift(player)
		elseif VehicleService.kind(player) ~= "Taxi" then
			endShift(player, `Shift over: you drove {shift.fares} fare{if shift.fares == 1 then "" else "s"}.`)
		elseif not fare then
			newFare(player, shift)
		elseif now > fare.endsAt then
			JobKit.dismiss(fare.passenger)
			shift.fare = nil
			Notifier.send(
				player,
				if fare.aboard
					then "Too slow! Your passenger got out without paying."
					else "Your passenger got tired of waiting.",
				"Bad"
			)
			newFare(player, shift)
		elseif not fare.aboard and atStop(player, fare.pickup) then
			pickUp(player, fare)
		elseif fare.aboard and atStop(player, fare.dropoff) then
			dropOff(player, shift, fare)
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, desk in JobKit.tagged(DESK_TAG) do
		JobKit.prompt(desk, { action = "Start taxi shift", object = "City Cabs", hold = 0.3 }, function(player: Player)
			local ok, message = start(player)
			if not ok and message then
				Notifier.send(player, message, "Info")
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		endShift(player)
	end)
	JobKit.every(CHECK_SECONDS, checkShifts)
end

local Taxi: MoneyPath.MoneyPath = {
	id = "Taxi",
	displayName = "Taxi shifts",
	unlockQuota = Config.Paths.Unlocks.Taxi,
	legal = true,
	init = init,
	start = start,
	complete = function(_player: Player): (boolean, string?)
		return false, nil
	end,
	fail = function(player: Player, reason: string)
		endShift(player, reason, "Bad")
	end,
	payout = function(_player: Player, _tier: number): number
		return fareFor(settings.MinTripStuds)
	end,
	hasJob = function(player: Player): boolean
		return shifts[player] ~= nil
	end,
	cancelAll = function(reason: string)
		for player in shifts do
			endShift(player, reason, "Bad")
		end
	end,
}

return Taxi
