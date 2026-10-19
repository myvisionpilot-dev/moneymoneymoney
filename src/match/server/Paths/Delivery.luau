--!strict
-- Delivery: grab a package at the depot and get it onto the marked house's doormat (walk it up,
-- or throw it: see Courier), then get paid into your bag. Some are fragile, some houses have a
-- guard dog, and deliveries one after another build a chain.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Courier = require(script.Parent.Courier)
local EconomyService = require(script.Parent.Parent.EconomyService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)

local DEPOT_TAG = "DeliveryDepot"
local DROPOFF_TAG = "DeliveryDropoff"
local CHECK_SECONDS = 0.2

local settings = Config.Paths.Delivery
local remotes = Remotes.match()
local promptLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local rng = Random.new()

type Job = {
	dropoff: BasePart,
	startedAt: number,
	endsAt: number,
	startPosition: Vector3,
	fragile: boolean,
	drop: Courier.Drop?,
}

local jobs: { [Player]: Job } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("Delivery used before init")
	end
	return current
end

local function payout(_player: Player, tier: number): number
	return math.floor(settings.BasePayout * Config.Economy.TierPayoutMultiplier ^ (tier - 1) + 0.5)
end

local function clear(player: Player): Job?
	local job = jobs[player]
	if not job then
		return nil
	end
	jobs[player] = nil
	local drop = job.drop
	if drop then
		Courier.stop(drop, false)
	end
	if player.Parent then
		remotes.JobGuide:fireClient(player, nil)
	end
	return job
end

local function fail(player: Player, reason: string)
	if clear(player) then
		Notifier.send(player, reason, "Bad")
	end
end

local function guide(player: Player, job: Job)
	local drop = job.drop
	if jobs[player] ~= job or not drop then
		return
	end
	remotes.JobGuide:fireClient(player, {
		title = if job.fragile then "Delivery (FRAGILE)" else "Delivery",
		markers = { Courier.marker(drop) },
		endsAt = job.endsAt,
		pay = payout(player, getContext().tier()),
	})
end

local function pickDropoff(from: Vector3): BasePart?
	local far: { BasePart } = {}
	local all: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(DROPOFF_TAG) do
		if instance:IsA("BasePart") then
			table.insert(all, instance)
			if (instance.Position - from).Magnitude >= settings.MinDropoffDistance then
				table.insert(far, instance)
			end
		end
	end
	local pool = if #far > 0 then far else all
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function delivered(player: Player, job: Job, how: Courier.How)
	local drop = job.drop
	if jobs[player] ~= job or not drop then
		return
	end
	local elapsed = Timing.now() - job.startedAt
	local minimum = (job.dropoff.Position - job.startPosition).Magnitude / settings.MaxSpeedStudsPerSecond
	if elapsed < minimum then
		warn(`[Delivery] {player.Name} arrived impossibly fast ({elapsed}s, minimum {minimum}s)`)
		fail(player, "Delivery voided: that was impossibly fast.")
		return
	end
	job.drop = nil
	jobs[player] = nil
	remotes.JobGuide:fireClient(player, nil)
	Courier.reward(drop, how, payout(player, getContext().tier()), "Package delivered", "delivery", "Delivery")
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Deliveries open when a quota starts."
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
	local root = CharacterUtil.getRoot(player)
	if not root then
		return false, nil
	end
	local dropoff = pickDropoff(root.Position)
	if not dropoff then
		return false, "There are no drop-off points on this map."
	end

	local now = Timing.now()
	local job: Job = {
		dropoff = dropoff,
		startedAt = now,
		endsAt = now + settings.TimeLimitSeconds,
		startPosition = root.Position,
		fragile = rng:NextNumber() < Config.Paths.Courier.Fragile.Chance,
		drop = nil,
	}
	jobs[player] = job
	local drop = Courier.begin(player, {
		kind = "Package",
		near = dropoff.Position,
		fragile = job.fragile,
		onDelivered = function(how: Courier.How)
			delivered(player, job, how)
		end,
		onBroken = function()
			if jobs[player] == job then
				fail(player, "SMASH! The fragile package broke. No pay for that one.")
			end
		end,
		onMoved = function()
			guide(player, job)
		end,
	})
	if not drop then
		jobs[player] = nil
		return false, nil
	end
	job.drop = drop
	guide(player, job)

	local pay = payout(player, ctx.tier())
	local message = `Get the package onto the marked doormat for {Format.money(pay)}. Throw it on for a bonus!`
	if job.fragile then
		message =
			`FRAGILE package (+{math.floor(Config.Paths.Courier.Fragile.PayBonus * 100)}% pay): don't crash into anything!`
	end
	Notifier.send(player, message, "Info")
	if Courier.hasGuard(drop) then
		Notifier.send(player, "Beware of the dog at that house! Throw it from the path.", "Bad")
	end
	return true, nil
end

local function complete(_player: Player): (boolean, string?)
	return false, "Deliveries finish on the doormat."
end

local function cancelAll(reason: string)
	for player in jobs do
		fail(player, reason)
	end
end

local function checkJobs()
	local now = Timing.now()
	for player, job in jobs do
		if not player.Parent then
			clear(player)
		elseif now > job.endsAt then
			fail(player, "Too slow! The package went back to the depot.")
		end
	end
end

local function setupDepot(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local depot: BasePart = instance
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeliveryPrompt"
	prompt.ActionText = "Start delivery"
	prompt.ObjectText = "Delivery depot"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = settings.PromptRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = depot
	prompt.Triggered:Connect(function(player: Player)
		if not promptLimiter:allow(player) then
			return
		end
		if CharacterUtil.distanceTo(player, depot.Position) > settings.PromptRangeStuds + 3 then
			return
		end
		local ok, message = start(player)
		if not ok and message then
			Notifier.send(player, message, "Bad")
		end
	end)
end

local function watchCharacter(player: Player)
	local function hook(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				fail(player, "You dropped the package!")
			end)
		end
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, instance in CollectionService:GetTagged(DEPOT_TAG) do
		setupDepot(instance)
	end
	CollectionService:GetInstanceAddedSignal(DEPOT_TAG):Connect(setupDepot)

	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	Players.PlayerRemoving:Connect(function(player: Player)
		clear(player)
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			checkJobs()
		end
	end)
end

local function hasJob(player: Player): boolean
	return jobs[player] ~= nil
end

local Delivery: MoneyPath.MoneyPath = {
	id = "Delivery",
	displayName = "Delivery jobs",
	unlockQuota = Config.Paths.Unlocks.Delivery,
	legal = true,
	init = init,
	start = start,
	complete = complete,
	fail = fail,
	payout = payout,
	hasJob = hasJob,
	cancelAll = cancelAll,
}

return Delivery
