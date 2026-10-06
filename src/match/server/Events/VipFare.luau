--!strict
-- VIP fare: a celebrity waits at a taxi stop. Pull up in any car or kart and pick them up,
-- then drive them to the marked stop for Events.VipFare.Multiplier times a normal taxi fare.
-- Getting out of the car (or busted) loses them. First come, first served.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Timing = require(ReplicatedStorage.Shared.Timing)
local JailService = require(script.Parent.Parent.JailService)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local VehicleService = require(script.Parent.Parent.VehicleService)
local TownEvent = require(script.Parent.TownEvent)

local STOP_TAG = "TaxiStop"
local FASTEST = 1.5 -- a trip faster than straight-line at this x taxi speed is voided
local NAMES = { "Movie Star Max", "Pop Star Pia", "Billionaire Bree", "Chef Celeste", "Rapper Rocco" }

local settings = Config.Events.VipFare
local taxi = Config.Paths.Taxi

type Ride = {
	ctx: TownEvent.Context,
	name: string,
	pickup: BasePart,
	dropoff: BasePart,
	customer: JobKit.Customer?,
	prompt: ProximityPrompt?,
	rider: Player?,
	pickedUpAt: number,
}

local ride: Ride? = nil

local VipFare = {
	id = "VipFare",
	title = "VIP FARE",
	seconds = settings.Seconds,
}

function VipFare.canStart(): boolean
	return #CollectionService:GetTagged(STOP_TAG) >= 2
end

local function standingAt(stop: BasePart): CFrame
	return JobKit.ground(stop) * CFrame.new(0, 0, 2)
end

local function pickUp(current: Ride, player: Player)
	if current.rider or not RosterService.isActive(player) or JailService.isJailed(player) then
		return
	end
	if not VehicleService.kind(player) then
		Notifier.send(player, `{current.name} doesn't walk. Pull up in a car or kart!`, "Info")
		return
	end
	current.rider = player
	current.pickedUpAt = Timing.now()
	JobKit.dismiss(current.customer)
	current.customer = nil
	if current.prompt then
		current.prompt:Destroy()
		current.prompt = nil
	end
	current.ctx.announce(`{player.DisplayName} picked up {current.name}.`, nil)
	current.ctx.announceTo(
		player,
		`Drive {current.name} to the marked stop. Stay in your car!`,
		current.dropoff.Position
	)
end

function VipFare.start(ctx: TownEvent.Context)
	local stops = JobKit.tagged(STOP_TAG)
	local rng = Random.new()
	local pickup = stops[rng:NextInteger(1, #stops)]
	local far: { BasePart } = {}
	for _, stop in stops do
		if (stop.Position - pickup.Position).Magnitude >= settings.MinTripStuds then
			table.insert(far, stop)
		end
	end
	if #far == 0 then
		ctx.finish()
		return
	end
	local current: Ride = {
		ctx = ctx,
		name = NAMES[rng:NextInteger(1, #NAMES)],
		pickup = pickup,
		dropoff = far[rng:NextInteger(1, #far)],
		customer = nil,
		prompt = nil,
		rider = nil,
		pickedUpAt = 0,
	}
	ride = current
	current.customer = JobKit.customer(standingAt(pickup), current.name)
	current.prompt = JobKit.prompt(pickup, {
		action = "Pick up the VIP",
		object = current.name,
		hold = 0.5,
		range = taxi.StopRadiusStuds,
	}, function(player: Player)
		pickUp(current, player)
	end)
	local multiplier = settings.Multiplier
	ctx.announce(`{current.name} needs a ride and pays {multiplier}x a taxi fare. Pull up in any car!`, pickup.Position)
end

function VipFare.tick()
	local current = ride
	local rider = current and current.rider
	if not current or not rider then
		return
	end
	if not rider.Parent or JailService.isJailed(rider) or not VehicleService.kind(rider) then
		if rider.Parent then
			Notifier.send(rider, `{current.name} got out and called someone else.`, "Bad")
		end
		current.ctx.finish()
		return
	end
	local root = CharacterUtil.getRoot(rider)
	if not root or (root.Position - current.dropoff.Position).Magnitude > taxi.StopRadiusStuds then
		return
	end
	local trip = (current.dropoff.Position - current.pickup.Position).Magnitude
	if Timing.now() - current.pickedUpAt < trip / (taxi.DriveSpeed * FASTEST) then
		Notifier.send(rider, `{current.name} won't pay: that ride was impossibly fast.`, "Bad")
	else
		local fare = (taxi.BaseFare + taxi.PerStud * trip) * settings.Multiplier * current.ctx.tierMultiplier
		PayNotice.earn(rider, math.floor(fare + 0.5), "VIP dropped off", "vip fare", true)
		JobKit.dismiss(JobKit.customer(standingAt(current.dropoff), current.name), 4)
	end
	current.ctx.finish()
end

function VipFare.stop()
	local current = ride
	ride = nil
	if current then
		JobKit.dismiss(current.customer)
		if current.prompt then
			current.prompt:Destroy()
		end
	end
end

return VipFare
