--!strict
-- Street races from Speedy's Garage: pay the Racing.EntryFee at the start pad (from your bag)
-- and the garage lends you a car. Once someone joins, others have Racing.GatherSeconds to join
-- too; then everyone lines up on the grid in identical cars, counts down and races Racing.Laps
-- laps round the town loop through the checkpoints in order. The top 3 get their fee back
-- plus a prize by place; a solo racer races the par times instead (gold, silver, bronze).
-- Anyone else loses the fee. Leaving before the start, or the race being called off, refunds it.
-- Map tags: RaceJoin (start pad), RaceCheckpoint (Order 1..n, the last is the finish line),
-- RaceGrid (Order 1..n, facing the way to go).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local MovementGuard = require(script.Parent.Parent.MovementGuard)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local Stats = require(script.Parent.Parent.Stats)
local VehicleService = require(script.Parent.Parent.VehicleService)

local JOIN_TAG = "RaceJoin"
local CHECKPOINT_TAG = "RaceCheckpoint"
local GRID_TAG = "RaceGrid"
local UPDATE_SECONDS = 0.5
local CAR_COLOR = Color3.fromRGB(225, 75, 65)
local MEDALS = { "Gold", "Silver", "Bronze" }
local MIN_TIME_SLACK = 1.3 -- a finish faster than straight lines at this x car speed is voided

type Phase = "Idle" | "Gathering" | "Countdown" | "Racing" | "Cooldown"

type Racer = {
	player: Player,
	passed: number,
	finishedAt: number?,
	fee: number, -- entry fee still held by the garage (refunded or kept at the end)
}

local settings = Config.Paths.Racing
local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local phase: Phase = "Idle"
local phaseEndsAt = 0 -- Gathering: countdown starts; Countdown: GO; Racing: time limit; Cooldown: reopens
local goAt = 0
local solo = false
local finishers = 0
local racers: { Racer } = {}
local course: { BasePart } = {} -- checkpoints for the current race, in order
local joinPrompt: ProximityPrompt? = nil
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("Racing used before init")
	end
	return current
end

local function sortedTagged(tag: string): { BasePart }
	local list: { { part: BasePart, order: number } } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		local order = instance:GetAttribute("Order")
		if instance:IsA("BasePart") and typeof(order) == "number" then
			table.insert(list, { part = instance, order = order })
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	local parts = {}
	for _, entry in list do
		table.insert(parts, entry.part)
	end
	return parts
end

local function joinPad(): BasePart?
	for _, instance in CollectionService:GetTagged(JOIN_TAG) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function totalCheckpoints(): number
	return #course * settings.Laps
end

-- Pay for a place (or medal) at the current quota.
local function payout(_player: Player, _tier: number): number
	return math.floor(settings.Pay[1] * getContext().payMultiplier() + 0.5)
end

local function payFor(rank: number): number
	local base = settings.Pay[rank]
	return if base then math.floor(base * getContext().payMultiplier() + 0.5) else 0
end

local function findRacer(player: Player): Racer?
	for _, racer in racers do
		if racer.player == player then
			return racer
		end
	end
	return nil
end

local function nextCheckpoint(racer: Racer, ahead: number?): BasePart?
	if #course == 0 then
		return nil
	end
	return course[(racer.passed + (ahead or 0)) % #course + 1]
end

-- Finishers by time, then most checkpoints passed, then closest to their next checkpoint.
local function standings(): { Racer }
	local distances: { [Racer]: number } = {}
	for _, racer in racers do
		local target = nextCheckpoint(racer)
		distances[racer] = if target then CharacterUtil.distanceTo(racer.player, target.Position) else math.huge
	end
	local list = table.clone(racers)
	table.sort(list, function(a: Racer, b: Racer): boolean
		local aDone, bDone = a.finishedAt, b.finishedAt
		if aDone and bDone then
			return aDone < bDone
		elseif aDone or bDone then
			return aDone ~= nil
		elseif a.passed ~= b.passed then
			return a.passed > b.passed
		end
		return distances[a] < distances[b]
	end)
	return list
end

local function sendUpdates()
	if phase ~= "Gathering" and phase ~= "Countdown" and phase ~= "Racing" then
		return
	end
	local state: Types.RaceState = if phase == "Gathering"
		then "Gathering"
		elseif phase == "Countdown" then "Countdown"
		else "Racing"
	for place, racer in standings() do
		if not racer.finishedAt and racer.player.Parent then
			remotes.RaceUpdate:fireClient(racer.player, {
				state = state,
				racers = #racers,
				solo = if phase == "Gathering" then #racers == 1 else solo,
				startsAt = if phase == "Gathering" then phaseEndsAt else goAt,
				endsAt = if phase == "Racing" then phaseEndsAt else 0,
				checkpoint = racer.passed,
				total = totalCheckpoints(),
				laps = settings.Laps,
				place = place,
				parSeconds = settings.ParSeconds,
			})
		end
	end
end

local function guide(racer: Racer)
	local first, second = nextCheckpoint(racer), nextCheckpoint(racer, 1)
	local markers = {}
	if first then
		table.insert(markers, first.Position)
	end
	if second and racer.passed + 1 < totalCheckpoints() then
		table.insert(markers, second.Position)
	end
	remotes.JobGuide:fireClient(racer.player, {
		title = "Race",
		markers = markers,
		endsAt = phaseEndsAt,
		pay = payFor(1),
	})
end

-- Gives the entry fee back (it was theirs, so it fits even in a full bag).
local function refund(racer: Racer, reason: string)
	if racer.fee > 0 and racer.player.Parent then
		EconomyService.addCarried(racer.player, racer.fee, reason, true)
	end
	racer.fee = 0
end

-- Takes a racer out of the race screens and their loaner car (they stay in the list for standings).
local function release(racer: Racer)
	local player = racer.player
	if VehicleService.kind(player) == "RaceCar" then
		VehicleService.dismount(player)
	end
	if player.Parent then
		remotes.RaceUpdate:fireClient(player, nil)
		remotes.JobGuide:fireClient(player, nil)
	end
end

local function reset(nextPhase: Phase, reopensAt: number)
	racers = {}
	finishers = 0
	phase = nextPhase
	phaseEndsAt = reopensAt
end

local function cancel(reason: string)
	for _, racer in racers do
		if not racer.finishedAt then
			refund(racer, "street race called off")
			release(racer)
			Notifier.send(racer.player, `{reason} Your entry fee is back in your bag.`, "Bad")
		end
	end
	reset("Idle", 0)
end

local function endRace()
	for _, racer in racers do
		if not racer.finishedAt then
			release(racer)
			Notifier.send(racer.player, "Time's up! You didn't finish the race.", "Bad")
		end
	end
	reset("Cooldown", Timing.now() + settings.CooldownSeconds)
end

local function unfinishedCount(): number
	local count = 0
	for _, racer in racers do
		if not racer.finishedAt then
			count += 1
		end
	end
	return count
end

local function leave(racer: Racer, message: string?)
	local index = table.find(racers, racer)
	if not index then
		return
	end
	table.remove(racers, index)
	if phase == "Gathering" then
		refund(racer, "left the street race before the start")
	end
	release(racer)
	if message then
		Notifier.send(racer.player, message, "Info")
	end
	if phase == "Gathering" and #racers == 0 then
		reset("Idle", 0)
	elseif (phase == "Countdown" or phase == "Racing") and unfinishedCount() == 0 then
		endRace()
	end
end

-- The shortest possible race (straight lines between checkpoints) at kart speed.
local function minimumSeconds(): number
	local length = 0
	for index, checkpoint in course do
		local nextOne = course[index % #course + 1]
		length += (nextOne.Position - checkpoint.Position).Magnitude
	end
	return length * settings.Laps / (settings.CarSpeed * MIN_TIME_SLACK)
end

local function finish(racer: Racer, now: number)
	local player = racer.player
	local time = now - goAt
	racer.finishedAt = now
	finishers += 1
	release(racer)

	if time < minimumSeconds() then
		warn(`[Racing] {player.Name} finished impossibly fast ({time}s)`)
		Notifier.send(player, "Race voided: that was impossibly fast.", "Bad")
		return
	end

	local rank: number? = nil
	if solo then
		for index, par in settings.ParSeconds do
			if time <= par then
				rank = index
				break
			end
		end
	elseif finishers <= #settings.Pay and time <= settings.ParSeconds[#settings.ParSeconds] then
		rank = finishers
	end

	local timeText = Format.raceTime(time)
	local bronze = Format.raceTime(settings.ParSeconds[#settings.ParSeconds])
	if not rank then
		racer.fee = 0 -- the garage keeps it
		local text = if solo
			then `{timeText}: no medal (bronze is {bronze}), so the garage keeps your entry fee.`
			else `{Format.ordinal(finishers)} place in {timeText}. No prize, and the garage keeps your entry fee.`
		Notifier.send(player, text, "Info")
		return
	end
	refund(racer, "street race entry back")
	local pay = payFor(rank)
	local added = EconomyService.addCarried(
		player,
		pay,
		if solo then `race: {MEDALS[rank]:lower()} time` else `race: {Format.ordinal(rank)} place`
	)
	local headline = if solo then `{MEDALS[rank]} time! {timeText}` else `{Format.ordinal(rank)} place in {timeText}!`
	PayNotice.send(player, headline, added, pay)
	if rank == 1 then
		Stats.record(player, "RaceWin")
		Juice.sound(player, "Fanfare")
	end
	if not solo and rank == 1 then
		Notifier.others(player, `{player.DisplayName} won the race!`, "Info")
	end
end

local function startCountdown()
	course = sortedTagged(CHECKPOINT_TAG)
	local slots = sortedTagged(GRID_TAG)
	if #course < 2 or #slots == 0 then
		cancel("The race track isn't set up on this map.")
		return
	end
	phase = "Countdown"
	goAt = Timing.now() + settings.CountdownSeconds
	phaseEndsAt = goAt
	solo = #racers == 1
	finishers = 0
	for index, racer in table.clone(racers) do
		local slot = slots[index]
		if phase ~= "Countdown" then
			return -- everyone dropped out
		elseif not slot then
			refund(racer, "street race grid was full")
			leave(racer, "The grid was full, sorry! Your entry fee is back.")
		else
			MovementGuard.teleport(racer.player, slot.CFrame + Vector3.new(0, 3, 0))
			if VehicleService.mount(racer.player, "RaceCar", 0, CAR_COLOR) then
				guide(racer)
			else
				refund(racer, "no loaner car for the street race")
				leave(racer, nil)
			end
		end
	end
	if phase == "Countdown" then
		sendUpdates()
	end
end

local function go()
	phase = "Racing"
	phaseEndsAt = goAt + settings.TimeLimitSeconds
	for _, racer in racers do
		VehicleService.setSpeed(racer.player, settings.CarSpeed)
		guide(racer)
	end
	sendUpdates()
end

local function join(player: Player): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Races open when a quota starts."
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if findRacer(player) then
		return false, "You're already in this race."
	end
	if phase == "Countdown" or phase == "Racing" then
		return false, "A race is on. Join the next one!"
	end
	if phase == "Cooldown" then
		return false, `The track reopens in {math.ceil(phaseEndsAt - Timing.now())}s.`
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	if HeatService.stars(player) >= 1 then
		return false, "The police are after you. Lose them before you race."
	end
	local slots = sortedTagged(GRID_TAG)
	if #slots == 0 then
		return false, "The race track isn't set up on this map."
	end
	if #racers >= #slots then
		return false, "This race is full."
	end
	if EconomyService.account(player).carried < settings.EntryFee then
		return false, `The entry fee is {Format.money(settings.EntryFee)}, paid from your bag.`
	end

	EconomyService.removeCarried(player, settings.EntryFee, "street race entry")
	table.insert(racers, { player = player, passed = 0, finishedAt = nil, fee = settings.EntryFee })
	if phase == "Idle" then
		phase = "Gathering"
		phaseEndsAt = Timing.now() + settings.GatherSeconds
		Notifier.others(
			player,
			`{player.DisplayName} is starting a street race at Speedy's Garage! Join within {settings.GatherSeconds}s.`,
			"Info"
		)
	end
	Notifier.send(player, "You're in! The garage has lent you a car. Stay by the start line.", "Good")
	sendUpdates()
	return true, nil
end

local function refreshPrompt()
	local prompt = joinPrompt
	if not prompt then
		return
	end
	local ctx = context
	if not ctx or not ctx.isOpen() then
		prompt.ObjectText = "Races open when a quota starts"
	elseif phase == "Gathering" then
		prompt.ObjectText = `Race starting: {#racers} in`
	elseif phase == "Countdown" or phase == "Racing" then
		prompt.ObjectText = "Race in progress"
	elseif phase == "Cooldown" then
		prompt.ObjectText = `Next race in {math.ceil(phaseEndsAt - Timing.now())}s`
	else
		prompt.ObjectText = `{Format.money(settings.EntryFee)} entry · 1st wins {Format.money(payFor(1))} more`
	end
end

local function tick()
	local now = Timing.now()
	local ctx = getContext()
	if phase == "Gathering" then
		local pad = joinPad()
		for _, racer in table.clone(racers) do
			local far = pad == nil or CharacterUtil.distanceTo(racer.player, pad.Position) > settings.LeaveRangeStuds
			if not racer.player.Parent or not ctx.canWork(racer.player) then
				leave(racer, nil)
			elseif far then
				leave(racer, "You left the race.")
			end
		end
		if phase == "Gathering" and now >= phaseEndsAt then
			startCountdown()
		end
	elseif phase == "Countdown" then
		if now >= goAt then
			go()
		end
	elseif phase == "Racing" then
		local total = totalCheckpoints()
		for _, racer in table.clone(racers) do
			if not racer.finishedAt then
				local target = nextCheckpoint(racer)
				if not racer.player.Parent or not ctx.canWork(racer.player) then
					leave(racer, nil)
				elseif
					target
					and CharacterUtil.distanceTo(racer.player, target.Position) <= settings.CheckpointRadiusStuds
				then
					racer.passed += 1
					if racer.passed >= total then
						finish(racer, now)
					else
						guide(racer)
					end
				end
			end
		end
		if phase == "Racing" and (now >= phaseEndsAt or unfinishedCount() == 0) then
			endRace()
		end
	elseif phase == "Cooldown" and now >= phaseEndsAt then
		phase = "Idle"
	end
end

local function setupPad(instance: Instance)
	if not instance:IsA("BasePart") or joinPrompt then
		return
	end
	local pad: BasePart = instance
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RacePrompt"
	prompt.ActionText = "Enter street race"
	prompt.ObjectText = "Speedy's Garage"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = settings.JoinRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if not limiter:allow(player) then
			return
		end
		if CharacterUtil.distanceTo(player, pad.Position) > settings.JoinRangeStuds + 3 then
			return
		end
		local ok, message = join(player)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = pad
	joinPrompt = prompt
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, instance in CollectionService:GetTagged(JOIN_TAG) do
		setupPad(instance)
	end
	CollectionService:GetInstanceAddedSignal(JOIN_TAG):Connect(setupPad)

	local sinceUpdate = 0
	RunService.Heartbeat:Connect(function(dt: number)
		tick()
		sinceUpdate += dt
		if sinceUpdate >= UPDATE_SECONDS then
			sinceUpdate = 0
			sendUpdates()
			refreshPrompt()
		end
	end)
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	return join(player)
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function fail(player: Player, reason: string)
	local racer = findRacer(player)
	if racer and not racer.finishedAt then
		leave(racer, reason)
	end
end

local function hasJob(player: Player): boolean
	local racer = findRacer(player)
	return racer ~= nil and racer.finishedAt == nil
end

local Racing: MoneyPath.MoneyPath = {
	id = "Racing",
	displayName = "Racing",
	unlockQuota = Config.Paths.Unlocks.Racing,
	legal = true,
	init = init,
	start = start,
	complete = complete,
	fail = fail,
	payout = payout,
	hasJob = hasJob,
	cancelAll = function(reason: string)
		if phase ~= "Idle" and phase ~= "Cooldown" then
			cancel(reason)
		end
	end,
}

return Racing
