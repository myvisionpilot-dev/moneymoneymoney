--!strict
-- Phone gigs: while you're not wanted and not on another job, your phone rings every so often
-- (Paths.PhoneGigs) with a quick, timed job near you. Answer it (client/GigController) and beat
-- the clock: the quicker you finish, the bigger the speed bonus on top of the pay.
--   RUSH PARCEL  grab a parcel round the corner and get it onto a doormat across town (Courier)
--   LOST CAT     a cat's hiding in a bush near the marker (listen for it); carry it home
--   PHOTO GIG    snap a photo at a landmark
--   CLEAN-UP     pick up the litter round a street corner
-- A legal job (hustles and twists apply); the job guide shows the way. Busted, or the quota
-- ending, and the gig's off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Carry = require(script.Parent.Parent.Carry)
local Courier = require(script.Parent.Courier)
local LooseCash = require(script.Parent.Parent.Events.LooseCash)
local HeatService = require(script.Parent.Parent.HeatService)
local JobKit = require(script.Parent.JobKit)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PropModels = require(script.Parent.Parent.PropModels)
local RunState = require(script.Parent.Parent.RunState)
local Spots = require(script.Parent.Parent.Events.Spots)
local TutorialState = require(script.Parent.Parent.TutorialState)

local TICK_SECONDS = 0.5
local MEOW_SECONDS = 3.5
local KINDS: { Types.GigKind } = { "Parcel", "Cat", "Photo", "Litter" }
local TITLES: { [Types.GigKind]: string } = {
	Parcel = "RUSH PARCEL",
	Cat = "LOST CAT",
	Photo = "PHOTO GIG",
	Litter = "CLEAN-UP",
}
local LANDMARKS = {
	{ tag = "BankSpawn", name = "Penny National Bank" },
	{ tag = "JailExit", name = "the police station" },
	{ tag = "ChopShop", name = "Speedy's Garage" },
	{ tag = "ParkSpot", name = "the park" },
	{ tag = "CarWashBay", name = "Sudz Car Wash" },
	{ tag = "DeliveryDepot", name = "the delivery depot" },
	{ tag = "BurgerCustomer", name = "Burger Barn" },
	{ tag = "TaxiSpawn", name = "City Cabs" },
	{ tag = "FoodCartCounter", name = "the hot dog stand" },
}
local CAT_NAMES = { "Mrs. Whiskers", "Biscuit", "Sir Fluffington", "Pumpkin", "Noodle", "Captain Purr" }

local settings = Config.Paths.PhoneGigs
local remotes = Remotes.match()
local answerLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

-- What a gig involves, worked out when the phone rings.
type Plan = {
	kind: Types.GigKind,
	detail: string,
	pay: number,
	seconds: number,
	spots: { Vector3 }, -- parcel: pickup, door; cat: bush, home; photo: landmark; clean-up: the litter
}

type Gig = {
	id: number,
	plan: Plan,
	active: boolean, -- accepted (false: still ringing)
	endsAt: number, -- server time
	startedAt: number,
	stage: number, -- parcel and cat: 1 go and get it, 2 take it there
	parts: { Instance },
	customer: JobKit.Customer?,
	carried: BasePart?,
	litter: { BasePart },
	lastMeow: number,
	drop: Courier.Drop?, -- a rush parcel on its way to the doormat
}

local gigs: { [Player]: Gig } = {}
local nextCall: { [Player]: number } = {}
local lastKind: { [Player]: Types.GigKind } = {}
local lastId = 0
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("PhoneGigs used before init")
	end
	return current
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function send(player: Player, gig: Gig?, state: Types.GigState?, extra: { detail: string?, bonus: number? }?)
	if not player.Parent then
		return
	end
	if not gig or not state then
		remotes.Gig:fireClient(player, nil)
		return
	end
	remotes.Gig:fireClient(player, {
		id = gig.id,
		kind = gig.plan.kind,
		title = TITLES[gig.plan.kind],
		detail = if extra and extra.detail then extra.detail else gig.plan.detail,
		pay = gig.plan.pay,
		state = state,
		endsAt = gig.endsAt,
		bonus = if extra then extra.bonus else nil,
	})
end

-- A random tagged spot between `near` and `far` studs from `from` (or the closest to that).
local function taggedAround(tag: string, from: Vector3, near: number, far: number): Vector3?
	local fits: { Vector3 } = {}
	local best: Vector3? = nil
	local bestMiss = math.huge
	for _, part in JobKit.tagged(tag) do
		local spot = JobKit.ground(part).Position
		local distance = flat(spot, from)
		if distance >= near and distance <= far then
			table.insert(fits, spot)
		else
			local miss = if distance < near then near - distance else distance - far
			if miss < bestMiss then
				best, bestMiss = spot, miss
			end
		end
	end
	return if #fits > 0 then fits[rng:NextInteger(1, #fits)] else best
end

local function planFor(kind: Types.GigKind, from: Vector3): Plan?
	local multiplier = getContext().payMultiplier()
	if kind == "Parcel" then
		local spec = settings.Parcel
		local pickup = Spots.around(from, spec.PickupStuds[1], spec.PickupStuds[2])
		local door = pickup and taggedAround("DeliveryDropoff", pickup, spec.DropStuds[1], spec.DropStuds[2])
		if not pickup or not door then
			return nil
		end
		return {
			kind = kind,
			detail = "Rush a parcel across town.",
			pay = JobKit.scaled(spec.Pay, multiplier),
			seconds = spec.BaseSeconds + spec.PerStud * (flat(from, pickup) + flat(pickup, door)),
			spots = { pickup, door },
		}
	elseif kind == "Cat" then
		local spec = settings.Cat
		local bush = taggedAround("HidingSpot", from, spec.BushStuds[1], spec.BushStuds[2])
		local home = taggedAround("DeliveryDropoff", from, 30, 140)
		if not bush or not home then
			return nil
		end
		local name = CAT_NAMES[rng:NextInteger(1, #CAT_NAMES)]
		return {
			kind = kind,
			detail = `Find {name} in a bush. Take her home.`,
			pay = JobKit.scaled(spec.Pay, multiplier),
			seconds = spec.Seconds,
			spots = { bush, home },
		}
	elseif kind == "Photo" then
		local spec = settings.Photo
		local candidates = {}
		for _, landmark in LANDMARKS do
			local part = JobKit.first(landmark.tag)
			if part then
				local spot = JobKit.ground(part).Position
				local distance = flat(spot, from)
				if distance >= spec.Studs[1] and distance <= spec.Studs[2] then
					table.insert(candidates, { spot = spot, name = landmark.name, distance = distance })
				end
			end
		end
		if #candidates == 0 then
			return nil
		end
		local chosen = candidates[rng:NextInteger(1, #candidates)]
		return {
			kind = kind,
			detail = `Snap a photo at {chosen.name}.`,
			pay = JobKit.scaled(spec.Pay, multiplier),
			seconds = spec.BaseSeconds + spec.PerStud * chosen.distance,
			spots = { chosen.spot },
		}
	end
	local spec = settings.Litter
	local corner = Spots.around(from, spec.Studs[1], spec.Studs[2])
	if not corner then
		return nil
	end
	local pieces = {}
	for _ = 1, spec.Pieces do
		-- On the ground round the corner, never up on a roof.
		table.insert(pieces, LooseCash.groundAround(corner, 2, spec.SpreadStuds) or corner)
	end
	return {
		kind = kind,
		detail = `Pick up {spec.Pieces} bits of litter.`,
		pay = JobKit.scaled(spec.Pay, multiplier),
		seconds = spec.Seconds,
		spots = pieces,
	}
end

-- An invisible spot to hang a prompt on.
local function anchor(gig: Gig, at: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "GigSpot"
	part.Size = Vector3.new(2, 4, 2)
	part.CFrame = CFrame.new(at + Vector3.new(0, 2, 0))
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace
	table.insert(gig.parts, part)
	return part
end

local function cleanUp(player: Player, gig: Gig)
	for _, thing in gig.parts do
		thing:Destroy()
	end
	table.clear(gig.parts)
	for _, piece in gig.litter do
		piece:Destroy()
	end
	table.clear(gig.litter)
	if gig.carried then
		gig.carried:Destroy()
		gig.carried = nil
	end
	if gig.drop then
		Courier.stop(gig.drop, false)
		gig.drop = nil
	end
	JobKit.dismiss(gig.customer)
	gig.customer = nil
	JobKit.clearGuide(player)
end

local function gapAfter(player: Player)
	nextCall[player] = Timing.now() + rng:NextNumber(settings.GapSeconds[1], settings.GapSeconds[2])
end

-- Off: the phone shows why.
local function lose(player: Player, gig: Gig, reason: string)
	if gigs[player] ~= gig then
		return
	end
	gigs[player] = nil
	cleanUp(player, gig)
	send(player, gig, "Failed", { detail = reason })
	gapAfter(player)
end

-- `how`: a rush parcel's delivery (it pays through Courier: the mat bonus and the chain).
local function finish(player: Player, gig: Gig, how: Courier.How?)
	if gigs[player] ~= gig then
		return
	end
	gigs[player] = nil
	local drop = gig.drop
	gig.drop = nil
	cleanUp(player, gig)
	local spare = math.clamp((gig.endsAt - Timing.now()) / gig.plan.seconds, 0, 1)
	local bonus = math.floor(gig.plan.pay * settings.SpeedBonus * spare + 0.5)
	local label = if bonus > 0 then `{TITLES[gig.plan.kind]} + speed bonus` else TITLES[gig.plan.kind]
	if drop and how then
		Courier.reward(drop, how, gig.plan.pay + bonus, label, "phone gig", "PhoneGig")
	else
		JobKit.pay(player, gig.plan.pay + bonus, label, "phone gig", "PhoneGig")
	end
	send(player, gig, "Done", { bonus = bonus })
	gapAfter(player)
end

local function guide(player: Player, gig: Gig, step: string, markers: { Vector3 })
	JobKit.guide(player, `{TITLES[gig.plan.kind]}: {step}`, markers, gig.endsAt, gig.plan.pay)
end

-- Somebody to hand it to at a front door, and the prompt for it.
local function handOver(player: Player, gig: Gig, door: Vector3, action: string)
	gig.customer = JobKit.customer(CFrame.new(door))
	JobKit.prompt(anchor(gig, door), { action = action, object = "Customer", owner = player }, function()
		if gigs[player] == gig and gig.stage == 2 then
			finish(player, gig)
		end
	end)
end

-- Picked it up: it's in your hands, now take it to the door.
local function pickUp(player: Player, gig: Gig, prop: PropModels.Kind, step: string, action: string)
	gig.stage = 2
	for _, thing in gig.parts do
		thing:Destroy()
	end
	table.clear(gig.parts)
	local door = gig.plan.spots[2]
	gig.carried = Carry.prop(player, prop)
	handOver(player, gig, door, action)
	guide(player, gig, step, { door })
end

-- A rush parcel: onto the doormat across town (walked up or thrown; maybe fragile).
local function rushParcel(player: Player, gig: Gig)
	gig.stage = 2
	for _, thing in gig.parts do
		thing:Destroy()
	end
	table.clear(gig.parts)
	local fragile = rng:NextNumber() < Config.Paths.Courier.Fragile.Chance
	local drop = Courier.begin(player, {
		kind = "Package",
		near = gig.plan.spots[2],
		fragile = fragile,
		onDelivered = function(how: Courier.How)
			if gigs[player] == gig then
				finish(player, gig, how)
			end
		end,
		onBroken = function()
			lose(player, gig, "SMASH! The fragile parcel broke.")
		end,
		onMoved = function()
			local current = gig.drop
			if gigs[player] == gig and current then
				guide(player, gig, "rush it to the doormat", { Courier.marker(current) })
			end
		end,
	})
	gig.drop = drop
	if not drop then
		lose(player, gig, "Your hands are full.")
		return
	end
	guide(
		player,
		gig,
		if fragile then "FRAGILE: rush it to the doormat" else "rush it to the doormat",
		{ Courier.marker(drop) }
	)
	if Courier.hasGuard(drop) then
		Notifier.send(player, "Beware of the dog at that house! Throw it from the path.", "Bad")
	end
end

local function begin(player: Player, gig: Gig)
	local plan = gig.plan
	gig.active = true
	gig.startedAt = Timing.now()
	gig.endsAt = gig.startedAt + plan.seconds
	gig.stage = 1
	if plan.kind == "Parcel" then
		local pickup = plan.spots[1]
		local box = PropModels.place("Package", CFrame.new(pickup + Vector3.new(0, 0.65, 0)), workspace)
		table.insert(gig.parts, box)
		JobKit.prompt(box, { action = "Grab the parcel", object = "Rush parcel", owner = player }, function()
			if gigs[player] == gig and gig.stage == 1 then
				rushParcel(player, gig)
			end
		end)
		guide(player, gig, "grab the parcel", { pickup })
	elseif plan.kind == "Cat" then
		local bush = plan.spots[1]
		local cat = PropModels.place(
			"Cat",
			CFrame.new(bush + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			workspace
		)
		table.insert(gig.parts, cat)
		JobKit.prompt(cat, { action = "Grab the cat", object = "Lost cat", hold = 0.4, owner = player }, function()
			if gigs[player] == gig and gig.stage == 1 then
				Sounds.at("Meow", cat)
				pickUp(player, gig, "Cat", "carry the cat home", "Hand over the cat")
			end
		end)
		-- The marker's only near the bush: you find it by looking (and listening).
		local angle = rng:NextNumber(0, math.pi * 2)
		local fuzz = rng:NextNumber(0, settings.Cat.SearchStuds)
		guide(player, gig, "find the cat", { bush + Vector3.new(math.cos(angle) * fuzz, 0, math.sin(angle) * fuzz) })
	elseif plan.kind == "Photo" then
		local spot = plan.spots[1]
		JobKit.prompt(
			anchor(gig, spot),
			{ action = "Snap a photo", object = "Landmark", hold = 0.8, owner = player },
			function(_, prompt)
				if gigs[player] == gig then
					Sounds.at("Shutter", prompt.Parent :: Instance)
					finish(player, gig)
				end
			end
		)
		guide(player, gig, "snap the photo", { spot })
	else
		for _, spot in plan.spots do
			local piece = PropModels.place("Litter", CFrame.new(spot + Vector3.new(0, 0.3, 0)), workspace)
			table.insert(gig.litter, piece)
			JobKit.prompt(piece, { action = "Pick up", object = "Litter", hold = 0.25, owner = player }, function()
				local index = table.find(gig.litter, piece)
				if gigs[player] ~= gig or not index then
					return
				end
				table.remove(gig.litter, index)
				piece:Destroy()
				if #gig.litter == 0 then
					finish(player, gig)
					return
				end
				local left = {}
				for _, other in gig.litter do
					table.insert(left, other.Position)
				end
				guide(player, gig, `{#gig.litter} bits left`, left)
			end)
		end
		guide(player, gig, `pick up {#plan.spots} bits`, plan.spots)
	end
	send(player, gig, "Active")
end

-- Can the phone ring for them right now?
local function canCall(player: Player): boolean
	local ctx = getContext()
	return ctx.isOpen()
		and not TutorialState.server
		and ctx.canWork(player)
		and not ctx.isBusy(player)
		and HeatService.get(player) < 1
		and Timing.now() >= RunState.quotaStartedAt + settings.FirstAfterSeconds
end

-- Rings their phone with this kind of gig, if there's one to be had near them.
local function offer(player: Player, kind: Types.GigKind): boolean
	local root = CharacterUtil.getRoot(player)
	local plan = root and planFor(kind, root.Position)
	if not plan then
		return false
	end
	lastId += 1
	lastKind[player] = kind
	local gig: Gig = {
		id = lastId,
		plan = plan,
		active = false,
		endsAt = Timing.now() + settings.AnswerSeconds,
		startedAt = 0,
		stage = 0,
		parts = {},
		customer = nil,
		carried = nil,
		litter = {},
		lastMeow = 0,
		drop = nil,
	}
	gigs[player] = gig
	send(player, gig, "Offer")
	return true
end

-- A different kind from last time.
local function ring(player: Player)
	local choices: { Types.GigKind } = {}
	for _, kind in KINDS do
		if kind ~= lastKind[player] then
			table.insert(choices, kind)
		end
	end
	if not offer(player, choices[rng:NextInteger(1, #choices)]) then
		gapAfter(player)
	end
end

local function tick()
	local now = Timing.now()
	for _, player in Players:GetPlayers() do
		local gig = gigs[player]
		if gig and not gig.active then
			if now > gig.endsAt then
				gigs[player] = nil
				send(player, nil, nil) -- it rang out
				gapAfter(player)
			end
		elseif gig then
			if now > gig.endsAt then
				lose(player, gig, "Out of time! The client found someone quicker.")
			elseif gig.plan.kind == "Cat" and gig.stage == 1 and now - gig.lastMeow >= MEOW_SECONDS then
				gig.lastMeow = now
				local cat = gig.parts[1]
				if cat then
					Sounds.at("Meow", cat)
				end
			end
		elseif canCall(player) and now >= (nextCall[player] or 0) then
			ring(player)
		end
	end
end

local function onAnswer(player: Player, payload: unknown)
	if not answerLimiter:allow(player) or typeof(payload) ~= "table" then
		return
	end
	local answer = payload :: { [any]: unknown }
	local gig = gigs[player]
	if not gig or gig.active or answer.id ~= gig.id then
		return
	end
	local ctx = getContext()
	if answer.accept == true and ctx.isOpen() and ctx.canWork(player) and not ctx.isBusy(player) then
		begin(player, gig)
	else
		gigs[player] = nil
		send(player, nil, nil)
		gapAfter(player)
	end
end

-- Puts a ringing phone down quietly, or calls off a gig in progress.
local function stop(player: Player, reason: string)
	local gig = gigs[player]
	if not gig then
		return
	elseif gig.active then
		lose(player, gig, reason)
	else
		gigs[player] = nil
		send(player, nil, nil)
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	remotes.GigAnswer:onServer(onAnswer)
	JobKit.every(TICK_SECONDS, tick)
	Players.PlayerRemoving:Connect(function(player: Player)
		local gig = gigs[player]
		if gig then
			gigs[player] = nil
			cleanUp(player, gig)
		end
		nextCall[player] = nil
		lastKind[player] = nil
	end)
end

-- Debug: ring their phone now (a kind, or any).
local function ringNow(player: Player, kind: string?): boolean
	if gigs[player] or not getContext().canWork(player) then
		return false
	end
	if not kind then
		ring(player)
		return gigs[player] ~= nil
	end
	for _, known in KINDS do
		if known:lower() == kind:lower() then
			return offer(player, known :: Types.GigKind)
		end
	end
	return false
end

return {
	path = {
		id = "PhoneGigs",
		displayName = "Phone gigs",
		unlockQuota = Config.Paths.Unlocks.PhoneGigs,
		legal = true,
		init = init,
		start = function(_player: Player, _source: Instance?): (boolean, string?)
			return false, "Wait for your phone to ring."
		end,
		complete = function(_player: Player): (boolean, string?)
			return false, nil
		end,
		fail = stop,
		payout = function(_player: Player, _tier: number): number
			return JobKit.scaled(settings.Parcel.Pay, getContext().tierMultiplier())
		end,
		hasJob = function(player: Player): boolean
			local gig = gigs[player]
			return gig ~= nil and gig.active
		end,
		cancelAll = function(reason: string)
			for player in gigs do
				stop(player, reason)
			end
		end,
	} :: MoneyPath.MoneyPath,
	ringNow = ringNow,
}
