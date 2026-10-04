--!strict
-- Car flipping: buy one of the wrecks in the lot behind Speedy's for CarFlip.Cost (from your
-- bag), then fix it up: bang out the dents and carry a tyre from the stack to each flat wheel.
-- Drive it through the paint booth, then onto the marked buyer's driveway for SalePrice (richer
-- streets pay a bit more). Run out of time (TimeLimitSeconds), get out of the car, get busted
-- or let the quota end, and the money you paid for the wreck is gone.
-- Map tags: FlipWreck (where a wreck sits, facing the way it drives off), TyreStack, PaintBooth.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Carry = require(script.Parent.Parent.Carry)
local EconomyService = require(script.Parent.Parent.EconomyService)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local VehicleModels = require(script.Parent.Parent.VehicleModels)
local VehicleService = require(script.Parent.Parent.VehicleService)
local CarDirt = require(script.Parent.CarDirt)
local JobKit = require(script.Parent.JobKit)

local WRECK_TAG = "FlipWreck"
local TYRE_TAG = "TyreStack"
local BOOTH_TAG = "PaintBooth"
local HOUSE_TAG = "House"
local CHECK_SECONDS = 0.2
local REFRESH_SECONDS = 1
local SPAWN_CLEARANCE = 8
local SELL_SPEED = 25 -- slow enough to count as parked on the driveway
local FASTEST = 1.5 -- a sale faster than straight-line at this x top speed is voided
local RUST = {
	Color3.fromRGB(140, 90, 60),
	Color3.fromRGB(120, 115, 100),
	Color3.fromRGB(100, 110, 90),
	Color3.fromRGB(150, 120, 90),
}
local FRESH = {
	Color3.fromRGB(220, 40, 60),
	Color3.fromRGB(30, 120, 230),
	Color3.fromRGB(40, 190, 110),
	Color3.fromRGB(250, 170, 30),
	Color3.fromRGB(150, 60, 220),
}
local DENT_LOOK: CarDirt.Look = {
	name = "Dent",
	color = Color3.fromRGB(70, 65, 60),
	material = Enum.Material.CorrodedMetal,
	transparency = 0,
}

type Wreck = {
	spot: BasePart,
	model: Model?,
	buyPrompt: ProximityPrompt?,
	color: Color3,
	respawnAt: number,
	taken: boolean,
}

type Stage = "Repair" | "Paint" | "Sell"

type Flat = { wheel: BasePart, flat: BasePart }

type Job = {
	player: Player,
	wreck: Wreck,
	stage: Stage,
	endsAt: number,
	cost: number,
	sale: number,
	buyer: Vector3,
	dents: { BasePart },
	flats: { Flat },
	tyre: BasePart?,
	prompts: { ProximityPrompt },
	props: { Instance },
	drivenAt: number,
	driveFrom: Vector3,
}

local settings = Config.Paths.CarFlip
local unlockQuota = Config.Paths.Unlocks.CarFlip
local rng = Random.new()

local wrecks: { Wreck } = {}
local jobs: { [Player]: Job } = {}
local context: MoneyPath.Context? = nil
local folder: Folder? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("CarFlip used before init")
	end
	return current
end

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "FlipWrecks"
	created.Parent = workspace
	folder = created
	return created
end

local function cost(): number
	return JobKit.scaled(settings.Cost, getContext().payMultiplier())
end

local function guide(job: Job)
	local markers: { Vector3 } = {}
	local title = "Fix the wreck"
	if job.stage == "Repair" then
		for _, dent in job.dents do
			table.insert(markers, dent.Position)
		end
		for _, flat in job.flats do
			table.insert(markers, flat.flat.Position)
		end
		local stack = JobKit.first(TYRE_TAG)
		if stack and #job.flats > 0 and not job.tyre then
			table.insert(markers, 1, stack.Position)
		end
		if #markers == 0 and job.wreck.model then
			table.insert(markers, job.wreck.model:GetPivot().Position)
			title = "Drive it to the paint booth"
		end
	elseif job.stage == "Paint" then
		local booth = JobKit.first(BOOTH_TAG)
		if booth then
			table.insert(markers, booth.Position)
		end
		title = "Paint booth"
	else
		table.insert(markers, job.buyer)
		title = "Sell it to the buyer"
	end
	JobKit.guide(job.player, title, markers, job.endsAt, job.sale)
end

-- Clears everything the job made. The wreck spot fills up again after a while.
local function clear(job: Job)
	if jobs[job.player] == job then
		jobs[job.player] = nil
	end
	for _, prompt in job.prompts do
		prompt:Destroy()
	end
	for _, prop in job.props do
		prop:Destroy()
	end
	if job.tyre then
		job.tyre:Destroy()
	end
	local wreck = job.wreck
	if wreck.model then
		wreck.model:Destroy()
		wreck.model = nil
	end
	wreck.taken = false
	wreck.respawnAt = Timing.now() + settings.RespawnSeconds
	if VehicleService.kind(job.player) == "FlipCar" then
		VehicleService.dismount(job.player)
	end
	JobKit.clearGuide(job.player)
end

local function fail(player: Player, reason: string)
	local job = jobs[player]
	if not job then
		return
	end
	clear(job)
	Notifier.send(player, `{reason} The {Format.money(job.cost)} you paid for the wreck is gone.`, "Bad")
end

local function readyToDrive(job: Job)
	local model = job.wreck.model
	local upper = model and model:FindFirstChild("Upper")
	if not upper then
		return
	end
	Notifier.send(job.player, "Fixed up! Drive it through the paint booth. Don't get out, or you lose it.", "Good")
	table.insert(
		job.prompts,
		JobKit.prompt(upper, {
			action = "Drive it",
			object = "Fixed-up car",
			hold = 0.3,
			range = settings.RangeStuds + 2,
			owner = job.player,
		}, function()
			if jobs[job.player] ~= job or job.stage ~= "Repair" then
				return
			end
			local wreckModel = job.wreck.model
			if not wreckModel then
				return
			end
			local at = wreckModel:GetPivot()
			wreckModel:Destroy()
			job.wreck.model = nil
			if not VehicleService.mount(job.player, "FlipCar", settings.DriveSpeed, job.wreck.color, at) then
				fail(job.player, "The car wouldn't start.")
				return
			end
			job.stage = "Paint"
			job.drivenAt = Timing.now()
			job.driveFrom = at.Position
			guide(job)
		end)
	)
	guide(job)
end

local function checkRepaired(job: Job)
	if #job.dents == 0 and #job.flats == 0 then
		readyToDrive(job)
	else
		guide(job)
	end
end

-- A buyer's driveway well away from the lot, and what they'll pay.
local function pickBuyer(from: Vector3): (Vector3?, number)
	local options: { { position: Vector3, tier: number } } = {}
	for _, house in CollectionService:GetTagged(HOUSE_TAG) do
		local spot = house:FindFirstChild("CarSpot")
		local tier = house:GetAttribute("Tier")
		if spot and spot:IsA("Attachment") and (spot.WorldPosition - from).Magnitude >= settings.MinBuyerStuds then
			table.insert(
				options,
				{ position = spot.WorldPosition, tier = if typeof(tier) == "number" then tier else 1 }
			)
		end
	end
	if #options == 0 then
		return nil, 0
	end
	local choice = options[rng:NextInteger(1, #options)]
	local bonus = settings.BuyerTierBonus[choice.tier] or 1
	return choice.position, JobKit.scaled(settings.SalePrice * bonus, getContext().payMultiplier())
end

local function startRepairs(job: Job, model: Model)
	local ground = model:GetPivot()
	job.dents = CarDirt.place(ground, settings.Dents, false, getFolder(), DENT_LOOK)
	for _, dent in job.dents do
		table.insert(job.props, dent)
		table.insert(
			job.prompts,
			JobKit.prompt(dent, {
				action = "Bang out dent",
				object = "Dent",
				hold = settings.DentHoldSeconds,
				range = settings.RangeStuds,
				owner = job.player,
			}, function(_player: Player, prompt: ProximityPrompt)
				prompt:Destroy()
				local at = table.find(job.dents, dent)
				if at then
					table.remove(job.dents, at)
				end
				dent:Destroy()
				Juice.sound(job.player, "Knock")
				checkRepaired(job)
			end)
		)
	end

	local wheels: { BasePart } = {}
	for index = 1, 4 do
		local wheel = model:FindFirstChild(`Wheel{index}`)
		if wheel and wheel:IsA("BasePart") then
			table.insert(wheels, wheel)
		end
	end
	for _ = 1, math.min(settings.FlatTyres, #wheels) do
		local wheel = table.remove(wheels, rng:NextInteger(1, #wheels)) :: BasePart
		wheel.Transparency = 1
		local flat = JobKit.prop(
			getFolder(),
			"FlatTyre",
			Vector3.new(1.1, 1.2, 2.4),
			wheel.CFrame * CFrame.new(0, -0.5, 0),
			Color3.fromRGB(30, 30, 32)
		)
		table.insert(job.props, flat)
		local entry: Flat = { wheel = wheel, flat = flat }
		table.insert(job.flats, entry)
		table.insert(
			job.prompts,
			JobKit.prompt(flat, {
				action = "Fit tyre",
				object = "Flat tyre",
				hold = settings.FitHoldSeconds,
				range = settings.RangeStuds,
				owner = job.player,
			}, function(_player: Player, prompt: ProximityPrompt)
				local tyre = job.tyre
				if not tyre then
					Notifier.send(job.player, "Grab a tyre from the stack first.", "Info")
					return
				end
				prompt:Destroy()
				tyre:Destroy()
				job.tyre = nil
				flat:Destroy()
				wheel.Transparency = 0
				local at = table.find(job.flats, entry)
				if at then
					table.remove(job.flats, at)
				end
				Juice.sound(job.player, "Knock")
				checkRepaired(job)
			end)
		)
	end

	local stack = JobKit.first(TYRE_TAG)
	if stack then
		table.insert(
			job.prompts,
			JobKit.prompt(
				stack,
				{ action = "Grab tyre", object = "Tyres", hold = 0.3, range = settings.RangeStuds, owner = job.player },
				function()
					if job.tyre or #job.flats == 0 or job.stage ~= "Repair" then
						return
					end
					local tyre = Carry.attach(
						job.player,
						"Tyre",
						Vector3.new(1, 2.2, 2.2),
						Color3.fromRGB(30, 30, 32),
						Enum.Material.SmoothPlastic,
						CFrame.new(0, -0.6, -1.6)
					)
					if tyre and tyre:IsA("Part") then
						tyre.Shape = Enum.PartType.Cylinder
					end
					job.tyre = tyre
					guide(job)
				end
			)
		)
	end
end

local function buy(player: Player, wreck: Wreck): (boolean, string?)
	local ctx = getContext()
	local model = wreck.model
	if not model or wreck.taken then
		return false, nil
	end
	if not ctx.isOpen() then
		return false, `Car flipping opens at quota {unlockQuota}.`
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	local price = cost()
	if EconomyService.account(player).carried < price then
		return false, `You need {Format.money(price)} in your bag to buy this wreck.`
	end
	local buyer, sale = pickBuyer(model:GetPivot().Position)
	if not buyer then
		return false, "Nobody in town wants a car right now."
	end
	EconomyService.removeCarried(player, price, "bought a wreck to flip")
	wreck.taken = true
	if wreck.buyPrompt then
		wreck.buyPrompt:Destroy()
		wreck.buyPrompt = nil
	end
	local job: Job = {
		player = player,
		wreck = wreck,
		stage = "Repair",
		endsAt = Timing.now() + settings.TimeLimitSeconds,
		cost = price,
		sale = sale,
		buyer = buyer,
		dents = {},
		flats = {},
		tyre = nil,
		prompts = {},
		props = {},
		drivenAt = 0,
		driveFrom = model:GetPivot().Position,
	}
	jobs[player] = job
	startRepairs(job, model)
	Juice.sound(player, "Purchase")
	Notifier.send(
		player,
		`It's yours for {Format.money(price)}. Bang out the dents and fit new tyres, then sell it for {Format.money(
			sale
		)}.`,
		"Info"
	)
	guide(job)
	return true, nil
end

local function spawnWreck(wreck: Wreck)
	wreck.color = RUST[rng:NextInteger(1, #RUST)]
	local model = VehicleModels.car(wreck.color)
	model.Name = "Wreck"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = part.Name == "Lower" or part.Name == "Upper"
		end
	end
	model:PivotTo(JobKit.ground(wreck.spot))
	model.Parent = getFolder()
	wreck.model = model
	local upper = model:FindFirstChild("Upper")
	if upper then
		wreck.buyPrompt = JobKit.prompt(
			upper,
			{ action = "Buy wreck", object = "Fixer-upper", hold = 0.5, range = settings.RangeStuds + 2 },
			function(player: Player)
				local ok, message = buy(player, wreck)
				if not ok and message then
					Notifier.send(player, message, "Info")
				end
			end
		)
	end
end

local function sell(job: Job)
	local trip = (job.buyer - job.driveFrom).Magnitude
	if Timing.now() - job.drivenAt < trip / (settings.DriveSpeed * FASTEST) then
		warn(`[CarFlip] {job.player.Name} reached the buyer impossibly fast`)
		fail(job.player, "The buyer backed out: that was impossibly fast.")
		return
	end
	clear(job)
	JobKit.pay(job.player, job.sale, "Sold! The buyer loves it.", "flipped a car", "CarFlip")
end

local function repaint(job: Job)
	local car = VehicleService.car(job.player)
	local color = FRESH[rng:NextInteger(1, #FRESH)]
	if car then
		for _, part in car:GetDescendants() do
			if part:IsA("BasePart") and (part.Name == "Lower" or part.Name == "Upper") then
				part.Color = color
				part.Reflectance = 0.15
			end
		end
	end
	job.stage = "Sell"
	Juice.sound(job.player, "Ding")
	Notifier.send(job.player, "Fresh paint! Now drive it onto the buyer's driveway.", "Good")
	guide(job)
end

local function checkJobs()
	local now = Timing.now()
	local booth = JobKit.first(BOOTH_TAG)
	for player, job in jobs do
		if not player.Parent then
			clear(job)
		elseif now > job.endsAt then
			fail(player, "Out of time!")
		elseif job.stage ~= "Repair" and VehicleService.kind(player) ~= "FlipCar" then
			fail(player, "You got out of the car.")
		elseif job.stage == "Paint" and booth then
			if CharacterUtil.distanceTo(player, booth.Position) <= settings.BoothRadiusStuds then
				repaint(job)
			end
		elseif job.stage == "Sell" then
			if
				CharacterUtil.distanceTo(player, job.buyer) <= settings.SellRadiusStuds
				and JobKit.speed(player) <= SELL_SPEED
			then
				sell(job)
			end
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

local function refreshWrecks()
	local now = Timing.now()
	local open = context ~= nil and getContext().isOpen()
	for _, wreck in wrecks do
		local prompt = wreck.buyPrompt
		if prompt then
			prompt.ObjectText = if open then `Fixer-upper: {Format.money(cost())}` else `Unlocks at quota {unlockQuota}`
		elseif
			not wreck.model
			and not wreck.taken
			and now >= wreck.respawnAt
			and not someoneNear(wreck.spot.Position)
		then
			spawnWreck(wreck)
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, spot in JobKit.tagged(WRECK_TAG) do
		local wreck: Wreck =
			{ spot = spot, model = nil, buyPrompt = nil, color = RUST[1], respawnAt = 0, taken = false }
		table.insert(wrecks, wreck)
		spawnWreck(wreck)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local job = jobs[player]
		if job then
			clear(job)
		end
	end)
	JobKit.every(CHECK_SECONDS, checkJobs)
	JobKit.every(REFRESH_SECONDS, refreshWrecks)
end

local CarFlip: MoneyPath.MoneyPath = {
	id = "CarFlip",
	displayName = "Car flipping",
	unlockQuota = unlockQuota,
	legal = true,
	init = init,
	start = function(_player: Player, _source: Instance?): (boolean, string?)
		return false, "Buy a wreck in the lot behind Speedy's Garage."
	end,
	complete = function(_player: Player): (boolean, string?)
		return false, nil
	end,
	fail = fail,
	payout = function(_player: Player, _tier: number): number
		return JobKit.scaled(settings.SalePrice, getContext().payMultiplier())
	end,
	hasJob = function(player: Player): boolean
		return jobs[player] ~= nil
	end,
	cancelAll = function(reason: string)
		for player in jobs do
			fail(player, reason)
		end
	end,
}

return CarFlip
