--!strict
-- Door knocks: knock at any house (hold E at the door). Its fixed resident answers and offers
-- two jobs: a chore (always legal) and their own wildcard (legal or illegal). The house then
-- rests for Doors.HouseRestSeconds. The jobs themselves live in DoorJobs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Carry = require(script.Parent.Parent.Carry)
local DoorJobs = require(script.Parent.DoorJobs)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local NpcService = require(script.Parent.Parent.NpcService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local Residents = require(script.Parent.Parent.Residents)
local ShopService = require(script.Parent.Parent.ShopService)
local Stats = require(script.Parent.Parent.Stats)

local HOUSE_TAG = "House"
local PARK_TAG = "ParkSpot"
local ALLEY_TAG = "AlleyDrop"
local TICK_SECONDS = 0.2
local RANGE_SLACK = 3
local JOB_PROMPT_RANGE = 8
local KNOCK_HOLD_SECONDS = 0.5

type House = DoorJobs.House
type Job = DoorJobs.Job

type Offer = {
	house: House,
	wildcard: DoorJobs.Kind, -- slot 2; slot 1 is always the chore
	expiresAt: number,
	resident: Model?,
	closed: boolean,
}

local settings = Config.Paths.Doors
local remotes = Remotes.match()
local knockLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local chooseLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

local houses: { House } = {}
local offers: { [Player]: Offer } = {}
local jobs: { [Player]: Job } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("DoorKnock used before init")
	end
	return current
end

local function taggedPosition(tag: string): Vector3?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance.Position
		end
	end
	return nil
end

local function basePay(kind: DoorJobs.Kind): number
	local pay = settings.Pay
	if kind == "Chore" then
		return pay.Chore
	elseif kind == "DogWalk" then
		return pay.DogWalk
	elseif kind == "Letter" then
		return pay.Letter
	elseif kind == "WalletSwipe" then
		return pay.WalletSwipe
	elseif kind == "ShadyPackage" then
		return pay.ShadyPackage
	end
	return 0
end

local function payFor(kind: DoorJobs.Kind, house: House): number
	local multiplier = getContext().payMultiplier(kind, DoorJobs.isLegal(kind))
	if kind == "BreakIn" then
		return math.floor(settings.BreakInPay[house.tier] * multiplier + 0.5)
	end
	return math.floor(basePay(kind) * settings.HouseTierPayMultiplier[house.tier] * multiplier + 0.5)
end

local function heatFor(kind: DoorJobs.Kind, house: House): number
	if kind == "BreakIn" then
		return Config.Heat.BreakIn[house.tier]
	elseif kind == "WalletSwipe" then
		return Config.Heat.WalletSwipe
	elseif kind == "ShadyPackage" then
		return Config.Heat.ShadyPackage
	end
	return 0
end

-- Jobs ---------------------------------------------------------------------------------

local function clearJob(job: Job)
	if jobs[job.player] == job then
		jobs[job.player] = nil
	end
	for _, prompt in job.prompts do
		prompt:Destroy()
	end
	for _, prop in job.props do
		prop:Destroy()
	end
	for _, cleanup in job.cleanup do
		cleanup()
	end
	job.prompts = {}
	job.props = {}
	job.cleanup = {}
	job.carried = nil
	if job.player.Parent then
		remotes.JobGuide:fireClient(job.player, nil)
	end
end

local kit: DoorJobs.Kit
kit = {
	guide = function(job: Job)
		if jobs[job.player] == job then
			remotes.JobGuide:fireClient(job.player, {
				title = DoorJobs.title(job.kind, job.house),
				markers = job.targets,
				endsAt = job.endsAt,
				pay = job.pay,
			})
		end
	end,

	finish = function(job: Job, message: string)
		if jobs[job.player] ~= job then
			return
		end
		clearJob(job)
		PayNotice.earn(job.player, job.pay, message, `door job: {job.kind}`, DoorJobs.isLegal(job.kind))
		if job.kind == "Chore" then
			Stats.record(job.player, "Chore")
		end
	end,

	fail = function(job: Job, reason: string)
		if jobs[job.player] ~= job then
			return
		end
		clearJob(job)
		Notifier.send(job.player, reason, "Bad")
	end,

	addHeat = function(job: Job)
		if not job.heatApplied and job.heat > 0 then
			job.heatApplied = true
			HeatService.add(job.player, job.heat)
		end
	end,

	notify = function(job: Job, text: string)
		Notifier.send(job.player, text, "Info")
	end,

	prompt = function(
		job: Job,
		parent: Instance,
		action: string,
		holdSeconds: number,
		onDone: (prompt: ProximityPrompt) -> ()
	): ProximityPrompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = job.house.resident.name
		prompt.HoldDuration = holdSeconds
		prompt.MaxActivationDistance = JOB_PROMPT_RANGE
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OnlyFor", job.player.UserId) -- PromptController hides it for everyone else
		PromptGuard.watch(prompt)
		prompt.Triggered:Connect(function(player: Player)
			if player ~= job.player or jobs[player] ~= job or not PromptGuard.held(prompt, player) then
				return
			end
			local position: Vector3? = nil
			if parent:IsA("Attachment") then
				position = parent.WorldPosition
			elseif parent:IsA("BasePart") then
				position = parent.Position
			end
			if position and CharacterUtil.distanceTo(player, position) > JOB_PROMPT_RANGE + RANGE_SLACK then
				return
			end
			onDone(prompt)
		end)
		prompt.Parent = parent
		table.insert(job.prompts, prompt)
		return prompt
	end,

	carry = function(job: Job, name: string, size: Vector3, color: Color3, offset: CFrame?): BasePart?
		local prop = Carry.attach(job.player, name, size, color, nil, offset)
		if prop then
			table.insert(job.props, prop)
		end
		return prop
	end,

	root = function(job: Job): BasePart?
		return CharacterUtil.getRoot(job.player)
	end,

	arrived = function(job: Job, position: Vector3): boolean
		return CharacterUtil.distanceTo(job.player, position) <= settings.TargetRadiusStuds
	end,

	tooFast = function(job: Job): boolean
		return Timing.now() - job.startedAt < job.travel / settings.MaxSpeedStudsPerSecond
	end,

	park = function(): Vector3?
		return taggedPosition(PARK_TAG)
	end,

	alley = function(): Vector3?
		return taggedPosition(ALLEY_TAG)
	end,

	otherDoor = function(from: House): Vector3?
		local far: { Vector3 } = {}
		local any: { Vector3 } = {}
		for _, house in houses do
			if house ~= from then
				local position = house.door.Position
				table.insert(any, position)
				if (position - from.door.Position).Magnitude >= settings.MinLetterDistance then
					table.insert(far, position)
				end
			end
		end
		local pool = if #far > 0 then far else any
		return if #pool > 0 then pool[rng:NextInteger(1, #pool)] else nil
	end,

	breakInHold = ShopService.breakInHoldSeconds,
}

local function startJob(player: Player, house: House, kind: DoorJobs.Kind)
	local now = Timing.now()
	local job: Job = {
		player = player,
		house = house,
		kind = kind,
		startedAt = now,
		endsAt = now + settings.JobTimeLimitSeconds,
		stage = 1,
		targets = {},
		prompts = {},
		props = {},
		pieces = {},
		placed = {},
		carried = nil,
		cleanup = {},
		pay = payFor(kind, house),
		heat = heatFor(kind, house),
		heatApplied = false,
		travel = 0,
	}
	jobs[player] = job
	DoorJobs.handler(kind).begin(job, kit)
end

-- Offers -------------------------------------------------------------------------------

local function spawnResident(offer: Offer)
	task.spawn(function()
		local house = offer.house
		local model = NpcService.makeRig(house.resident.name, NpcService.lookFromSeed(house.id))
		if offer.closed then
			model:Destroy()
			return
		end
		local door = house.door
		local outward = door.CFrame.LookVector
		local ground = door.Position.Y - door.Size.Y / 2
		local position = Vector3.new(door.Position.X, ground + 3, door.Position.Z) + outward * 2.5
		NpcService.place(model, CFrame.lookAt(position, position + outward))
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		offer.resident = model
	end)
end

local function closeOffer(player: Player, message: string?)
	local offer = offers[player]
	if not offer then
		return
	end
	offers[player] = nil
	offer.closed = true
	local model = offer.resident
	if model then
		task.delay(1.5, function()
			model:Destroy()
		end)
	end
	if player.Parent then
		remotes.DoorOffer:fireClient(player, nil)
		if message then
			Notifier.send(player, message, "Info")
		end
	end
end

local function optionFor(slot: number, kind: DoorJobs.Kind, house: House, detail: string): Types.DoorOfferOption
	return {
		slot = slot,
		title = DoorJobs.title(kind, house),
		detail = detail,
		legal = DoorJobs.isLegal(kind),
		pay = payFor(kind, house),
		heat = heatFor(kind, house),
	}
end

local function knock(player: Player, house: House): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Nobody answers. Try again when a quota starts."
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	if CharacterUtil.distanceTo(player, house.door.Position) > settings.KnockRangeStuds + RANGE_SLACK then
		return false, nil
	end
	local now = Timing.now()
	if house.restUntil > now then
		return false, `Nobody's home. Try again in {math.ceil(house.restUntil - now)}s.`
	end
	house.restUntil = now + settings.HouseRestSeconds
	Sounds.at("Knock", house.door)

	local resident = house.resident
	local options: { Types.DoorOfferOption } = {
		optionFor(1, "Chore", house, "A bit of honest work."),
		optionFor(2, resident.wildcard, house, resident.wildcardLine),
	}
	local offer: Offer = {
		house = house,
		wildcard = resident.wildcard,
		expiresAt = now + settings.OfferSeconds,
		resident = nil,
		closed = false,
	}
	offers[player] = offer
	spawnResident(offer)
	remotes.DoorOffer:fireClient(player, {
		residentName = resident.name,
		greeting = resident.greeting,
		options = options,
		expiresAt = offer.expiresAt,
	})
	return true, nil
end

local function onChoose(player: Player, payload: unknown)
	if not chooseLimiter:allow(player) or typeof(payload) ~= "number" then
		return
	end
	local offer = offers[player]
	if not offer then
		return
	end
	if payload == 0 then
		closeOffer(player, `{offer.house.resident.name}: "Suit yourself!"`)
		return
	end
	local kind: DoorJobs.Kind
	if payload == 1 then
		kind = "Chore"
	elseif payload == 2 then
		kind = offer.wildcard
	else
		return
	end
	if Timing.now() > offer.expiresAt then
		closeOffer(player, "Too slow. They shut the door.")
		return
	end
	local ctx = getContext()
	if not ctx.isOpen() or not ctx.canWork(player) then
		closeOffer(player)
		return
	end
	if CharacterUtil.distanceTo(player, offer.house.door.Position) > settings.KnockRangeStuds + 6 then
		closeOffer(player, "You wandered off, so they shut the door.")
		return
	end
	closeOffer(player)
	startJob(player, offer.house, kind)
end

-- Setup --------------------------------------------------------------------------------

local function setupHouse(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local id = instance:GetAttribute("HouseId")
	local tier = instance:GetAttribute("Tier")
	local door = instance:FindFirstChild("Door")
	if typeof(id) ~= "number" or not door or not door:IsA("BasePart") then
		warn(`[DoorKnock] {instance:GetFullName()} needs a HouseId attribute and a Door part`)
		return
	end
	local bins: { BasePart } = {}
	for index = 1, 2 do
		local bin = instance:FindFirstChild(`Bin{index}`)
		if bin and bin:IsA("BasePart") then
			table.insert(bins, bin)
		end
	end
	local function attachment(name: string): Attachment?
		local found = instance:FindFirstChild(name)
		return if found and found:IsA("Attachment") then found else nil
	end
	local lawn = instance:FindFirstChild("Lawn")
	local house: House = {
		id = id,
		part = instance,
		tier = math.clamp(if typeof(tier) == "number" then tier else 1, 1, #settings.HouseTierPayMultiplier),
		door = door,
		backDoor = attachment("BackDoor"),
		lawn = if lawn and lawn:IsA("BasePart") then lawn else nil,
		bins = bins,
		kerb = attachment("Kerb"),
		carSpot = attachment("CarSpot"),
		resident = Residents.forHouse(id),
		restUntil = 0,
	}
	table.insert(houses, house)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KnockPrompt"
	prompt.ActionText = "Knock"
	prompt.ObjectText = house.resident.name
	prompt.HoldDuration = KNOCK_HOLD_SECONDS
	prompt.MaxActivationDistance = settings.KnockRangeStuds
	prompt.RequiresLineOfSight = false
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(player: Player)
		if not knockLimiter:allow(player) or not PromptGuard.held(prompt, player) then
			return
		end
		local ok, message = knock(player, house)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = door
end

local function fail(player: Player, reason: string)
	local job = jobs[player]
	if job then
		kit.fail(job, reason)
	end
	closeOffer(player)
end

local function tick()
	local now = Timing.now()
	for player, job in jobs do
		if not player.Parent then
			clearJob(job)
		elseif now > job.endsAt then
			kit.fail(job, "Too slow! The job fell through.")
		else
			local handler = DoorJobs.handler(job.kind)
			if handler.tick then
				handler.tick(job, kit)
			end
		end
	end
	for player, offer in offers do
		if not player.Parent then
			offers[player] = nil
		elseif now > offer.expiresAt then
			closeOffer(player, "They got bored and shut the door.")
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, instance in CollectionService:GetTagged(HOUSE_TAG) do
		setupHouse(instance)
	end
	CollectionService:GetInstanceAddedSignal(HOUSE_TAG):Connect(setupHouse)
	remotes.ChooseDoorOffer:onServer(onChoose)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					fail(player, "You dropped everything!")
				end)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceTick += dt
		if sinceTick >= TICK_SECONDS then
			sinceTick = 0
			tick()
		end
	end)
end

local function start(player: Player, source: Instance?): (boolean, string?)
	for _, house in houses do
		if source == house.door or source == house.part then
			return knock(player, house)
		end
	end
	return false, nil
end

local function complete(_player: Player): (boolean, string?)
	return false, "Door jobs finish at their markers."
end

local function payout(player: Player, _tier: number): number
	local job = jobs[player]
	return if job then job.pay else 0
end

local function hasJob(player: Player): boolean
	return jobs[player] ~= nil or offers[player] ~= nil
end

local function cancelAll(reason: string)
	for player in jobs do
		fail(player, reason)
	end
	for player in offers do
		closeOffer(player)
	end
end

local DoorKnock: MoneyPath.MoneyPath = {
	id = "DoorKnock",
	displayName = "Door knocks",
	unlockQuota = Config.Paths.Unlocks.DoorKnock,
	legal = true,
	init = init,
	start = start,
	complete = complete,
	fail = fail,
	payout = payout,
	hasJob = hasJob,
	cancelAll = cancelAll,
}

return DoorKnock
