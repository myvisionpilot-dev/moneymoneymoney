--!strict
-- Car theft → chop shop: from quota Paths.Unlocks.CarTheft, hold E on a parked car to break in,
-- then drive it to the chop shop bay before CarTheft.TimeLimitSeconds runs out. Stealing adds
-- Heat.CarTheft. Press R to ditch the car. An empty spot gets a new car after RespawnSeconds.
-- Map tags: ParkedCar (spot markers on the ground, facing along the parking space), ChopShop (the bay).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local Stats = require(script.Parent.Parent.Stats)
local VehicleModels = require(script.Parent.Parent.VehicleModels)
local VehicleService = require(script.Parent.Parent.VehicleService)

local SPOT_TAG = "ParkedCar"
local CHOP_TAG = "ChopShop"
local CHECK_SECONDS = 0.2
local REFRESH_SECONDS = 1
local CAR_REACH = 6 -- half a car's length, added to the prompt range check
local SPAWN_CLEARANCE = 8 -- don't park a new car on top of someone
local FASTEST = 1.5 -- a delivery faster than straight-line at this x drive speed is voided
local COLORS = {
	Color3.fromRGB(200, 60, 55),
	Color3.fromRGB(60, 110, 200),
	Color3.fromRGB(235, 200, 70),
	Color3.fromRGB(70, 160, 90),
	Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(60, 60, 65),
}

type Spot = {
	marker: BasePart,
	car: Model?,
	prompt: ProximityPrompt?,
	color: Color3,
	respawnAt: number,
}

type Job = {
	startedAt: number,
	endsAt: number,
	startPosition: Vector3,
}

local settings = Config.Paths.CarTheft
local unlockQuota = Config.Paths.Unlocks.CarTheft
local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local rng = Random.new()

local spots: { Spot } = {}
local jobs: { [Player]: Job } = {}
local folder: Folder? = nil
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("CarTheft used before init")
	end
	return current
end

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "ParkedCars"
	created.Parent = workspace
	folder = created
	return created
end

local function chopShop(): BasePart?
	for _, instance in CollectionService:GetTagged(CHOP_TAG) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function payout(_player: Player, _tier: number): number
	return math.floor(settings.Pay * getContext().payMultiplier() + 0.5)
end

local function clearJob(player: Player): boolean
	if not jobs[player] then
		return false
	end
	jobs[player] = nil
	if VehicleService.kind(player) == "StolenCar" then
		VehicleService.dismount(player)
	end
	if player.Parent then
		remotes.JobGuide:fireClient(player, nil)
	end
	return true
end

local function fail(player: Player, reason: string)
	if clearJob(player) then
		Notifier.send(player, reason, "Bad")
	end
end

local steal: (player: Player, spot: Spot) -> (boolean, string?)

-- A parked car: solid, anchored, with a Steal prompt.
local function park(spot: Spot)
	local color = COLORS[rng:NextInteger(1, #COLORS)]
	local car = VehicleModels.car(color)
	car.Name = "ParkedCar"
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Massless = false
			descendant.CanCollide = descendant.Name == "Lower" or descendant.Name == "Upper"
		end
	end
	local marker = spot.marker
	car:PivotTo(marker.CFrame * CFrame.new(0, -marker.Size.Y / 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealCarPrompt"
	prompt.ActionText = "Steal car"
	prompt.ObjectText = "Parked car"
	prompt.HoldDuration = settings.HoldSeconds
	prompt.MaxActivationDistance = settings.RangeStuds
	prompt.RequiresLineOfSight = false
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(player: Player)
		if not limiter:allow(player) then
			return
		end
		local ok, message = steal(player, spot)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = car:FindFirstChild("Upper")

	car.Parent = getFolder()
	spot.car = car
	spot.prompt = prompt
	spot.color = color
end

steal = function(player: Player, spot: Spot): (boolean, string?)
	local ctx = getContext()
	local car, prompt = spot.car, spot.prompt
	if not car or not prompt then
		return false, nil
	end
	if not ctx.isOpen() then
		return false, `Car theft unlocks at quota {unlockQuota}.`
	end
	if not ctx.canWork(player) or not PromptGuard.held(prompt, player) then
		return false, nil
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	if CharacterUtil.distanceTo(player, car:GetPivot().Position) > settings.RangeStuds + CAR_REACH then
		return false, nil
	end
	local bay = chopShop()
	if not bay then
		return false, "There's no chop shop on this map."
	end

	car:Destroy()
	spot.car, spot.prompt = nil, nil
	spot.respawnAt = Timing.now() + settings.RespawnSeconds
	if not VehicleService.mount(player, "StolenCar", settings.DriveSpeed, spot.color) then
		return false, nil
	end
	HeatService.add(player, Config.Heat.CarTheft)

	local root = CharacterUtil.getRoot(player)
	local now = Timing.now()
	jobs[player] = {
		startedAt = now,
		endsAt = now + settings.TimeLimitSeconds,
		startPosition = if root then root.Position else bay.Position,
	}
	remotes.JobGuide:fireClient(player, {
		title = "Stolen car to chop shop",
		markers = { bay.Position },
		endsAt = now + settings.TimeLimitSeconds,
		pay = payout(player, ctx.tier()),
	})
	Notifier.send(player, "You stole a car! Get it to the chop shop before it gets too hot. R ditches it.", "Info")
	return true, nil
end

local function deliver(player: Player, job: Job, bay: BasePart)
	local elapsed = Timing.now() - job.startedAt
	local minimum = (bay.Position - job.startPosition).Magnitude / (settings.DriveSpeed * FASTEST)
	if elapsed < minimum then
		warn(`[CarTheft] {player.Name} delivered impossibly fast ({elapsed}s, minimum {minimum}s)`)
		fail(player, "The chop shop won't touch it: that was impossibly fast.")
		return
	end
	clearJob(player)
	local pay = payout(player, getContext().tier())
	local added = EconomyService.addCarried(player, pay, "chop shop")
	PayNotice.send(player, "The chop shop took the car!", added, pay)
	Stats.record(player, "ChopShop")
end

local function checkJobs()
	local now = Timing.now()
	local bay = chopShop()
	for player, job in jobs do
		if not player.Parent then
			jobs[player] = nil
		elseif VehicleService.kind(player) ~= "StolenCar" then
			fail(player, "You ditched the stolen car.")
		elseif now > job.endsAt then
			fail(player, "The car got too hot to sell, so you ditched it.")
		elseif bay and CharacterUtil.distanceTo(player, bay.Position) <= settings.ChopRadiusStuds then
			deliver(player, job, bay)
		end
	end
end

local function someoneNear(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		if CharacterUtil.distanceTo(player, position) < SPAWN_CLEARANCE then
			return true
		end
	end
	return false
end

local function refreshSpots()
	local now = Timing.now()
	local open = context ~= nil and getContext().isOpen()
	for _, spot in spots do
		local prompt = spot.prompt
		if prompt then
			prompt.ObjectText = if open then "Parked car" else `Unlocks at quota {unlockQuota}`
		elseif now >= spot.respawnAt and not someoneNear(spot.marker.Position) then
			park(spot)
		end
	end
end

local function addSpot(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local spot: Spot = { marker = instance, car = nil, prompt = nil, color = COLORS[1], respawnAt = 0 }
	table.insert(spots, spot)
	park(spot)
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, instance in CollectionService:GetTagged(SPOT_TAG) do
		addSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(addSpot)
	Players.PlayerRemoving:Connect(function(player: Player)
		jobs[player] = nil
	end)

	local sinceCheck, sinceRefresh = 0, REFRESH_SECONDS
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		sinceRefresh += dt
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			checkJobs()
		end
		if sinceRefresh >= REFRESH_SECONDS then
			sinceRefresh = 0
			refreshSpots()
		end
	end)
end

local function start(_player: Player, _source: Instance?): (boolean, string?)
	return false, "Hold E on a parked car."
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function hasJob(player: Player): boolean
	return jobs[player] ~= nil
end

local CarTheft: MoneyPath.MoneyPath = {
	id = "CarTheft",
	displayName = "Car theft (chop shop)",
	unlockQuota = unlockQuota,
	legal = false,
	init = init,
	start = start,
	complete = complete,
	fail = fail,
	payout = payout,
	hasJob = hasJob,
	cancelAll = function(reason: string)
		for player in jobs do
			fail(player, reason)
		end
	end,
}

return CarTheft
