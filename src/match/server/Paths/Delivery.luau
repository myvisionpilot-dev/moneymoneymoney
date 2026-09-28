--!strict
-- Delivery: grab a package at the depot, walk it to the marked house, get paid into your bag.

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
local Carry = require(script.Parent.Parent.Carry)
local EconomyService = require(script.Parent.Parent.EconomyService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local Stats = require(script.Parent.Parent.Stats)

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
	package: BasePart?,
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
	if job.package then
		job.package:Destroy()
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
		return false, "Your bag is full. Deposit at Tony's first!"
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
		package = Carry.attach(
			player,
			"DeliveryPackage",
			Vector3.new(1.6, 1.3, 1.6),
			Color3.fromRGB(176, 128, 72),
			Enum.Material.Cardboard
		),
	}
	jobs[player] = job

	local pay = payout(player, ctx.tier())
	remotes.JobGuide:fireClient(player, {
		title = "Delivery",
		markers = { dropoff.Position },
		endsAt = job.endsAt,
		pay = pay,
	})
	Notifier.send(player, `Take the package to the marked house for {Format.money(pay)}.`, "Info")
	return true, nil
end

local function complete(player: Player): (boolean, string?)
	local job = jobs[player]
	if not job then
		return false, nil
	end
	if CharacterUtil.distanceTo(player, job.dropoff.Position) > settings.DropoffRadiusStuds + 2 then
		return false, nil
	end
	local elapsed = Timing.now() - job.startedAt
	local minimum = (job.dropoff.Position - job.startPosition).Magnitude / settings.MaxSpeedStudsPerSecond
	if elapsed < minimum then
		warn(`[Delivery] {player.Name} arrived impossibly fast ({elapsed}s, minimum {minimum}s)`)
		fail(player, "Delivery voided: that was impossibly fast.")
		return false, "Too fast"
	end

	clear(player)
	local pay = payout(player, getContext().tier())
	local added = EconomyService.addCarried(player, pay, "delivery")
	PayNotice.send(player, "Delivered!", added, pay)
	Stats.record(player, "Delivery")
	return true, nil
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
		elseif CharacterUtil.distanceTo(player, job.dropoff.Position) <= settings.DropoffRadiusStuds then
			complete(player)
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
		jobs[player] = nil
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
