--!strict
-- Sudz Car Wash: clock in at the cashier and dirty cars roll into the bay one at a time (up to
-- CarWash.Cars in ShiftSeconds). Scrub every patch of dirt (roof, windows and wheels too), then
-- pull the rinse lever: PayPerCar, plus QuickTip if the car was done within QuickSeconds of
-- rolling in. One washer at a time. The scrubbing is the house chore's (Paths/CarDirt).
-- Map tags: CarWashDesk (the cashier), CarWashBay (where a car stops, facing the way it drives
-- through), CarWashLever.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local VehicleModels = require(script.Parent.Parent.VehicleModels)
local CarDirt = require(script.Parent.CarDirt)
local JobKit = require(script.Parent.JobKit)

local TICK_SECONDS = 0.2
local LEAVE_STUDS = 70
local ROLL_STUDS = 26 -- cars roll in from this far behind the bay and out this far ahead
local RINSE_SECONDS = 1.2
local COLORS = {
	Color3.fromRGB(200, 60, 55),
	Color3.fromRGB(60, 110, 200),
	Color3.fromRGB(235, 200, 70),
	Color3.fromRGB(70, 160, 90),
	Color3.fromRGB(230, 230, 230),
}

type Shift = {
	player: Player,
	endsAt: number,
	washed: number,
	car: Model?,
	arrivedAt: number,
	dirt: { BasePart },
	prompts: { ProximityPrompt },
	lever: ProximityPrompt?,
	busy: boolean, -- a car is rolling or being rinsed
}

local settings = Config.Paths.CarWash
local rng = Random.new()

local shift: Shift? = nil
local context: MoneyPath.Context? = nil
local clockIn: ProximityPrompt? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("CarWash used before init")
	end
	return current
end

local function carPay(): number
	return JobKit.scaled(settings.PayPerCar, getContext().payMultiplier())
end

-- Slides an anchored car from one place to another.
local function roll(car: Model, from: CFrame, to: CFrame, seconds: number)
	local value = Instance.new("CFrameValue")
	value.Value = from
	value.Changed:Connect(function(cframe: CFrame)
		if car.Parent then
			car:PivotTo(cframe)
		end
	end)
	car:PivotTo(from)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Value = to })
	tween:Play()
	tween.Completed:Wait()
	value:Destroy()
end

local function guide(current: Shift)
	local markers: { Vector3 } = {}
	if current.busy then
		markers = {}
	elseif #current.dirt > 0 then
		for _, patch in current.dirt do
			table.insert(markers, patch.Position)
		end
	else
		local lever = JobKit.first("CarWashLever")
		if lever then
			table.insert(markers, lever.Position)
		end
	end
	JobKit.guide(
		current.player,
		`Car wash: car {current.washed + 1}/{settings.Cars}`,
		markers,
		current.endsAt,
		carPay()
	)
end

local function clearCar(current: Shift)
	for _, prompt in current.prompts do
		prompt:Destroy()
	end
	for _, patch in current.dirt do
		patch:Destroy()
	end
	current.prompts, current.dirt = {}, {}
	if current.car then
		current.car:Destroy()
		current.car = nil
	end
end

local function endShift(reason: string?, kind: ("Info" | "Good" | "Bad")?)
	local current = shift
	if not current then
		return
	end
	shift = nil
	clearCar(current)
	if current.lever then
		current.lever:Destroy()
	end
	JobKit.clearGuide(current.player)
	if clockIn then
		clockIn.Enabled = true
	end
	if reason then
		Notifier.send(current.player, reason, kind or "Info")
	end
end

local function nextCar(current: Shift)
	local bay = JobKit.first("CarWashBay")
	if not bay then
		endShift("The car wash bay is missing.", "Bad")
		return
	end
	current.busy = true
	guide(current)
	local ground = JobKit.ground(bay)
	local car = VehicleModels.car(COLORS[rng:NextInteger(1, #COLORS)])
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = part.Name == "Lower" or part.Name == "Upper"
		end
	end
	car:PivotTo(ground * CFrame.new(0, 0, ROLL_STUDS))
	car.Parent = workspace
	current.car = car
	roll(car, ground * CFrame.new(0, 0, ROLL_STUDS), ground, settings.RollSeconds)
	if shift ~= current or current.car ~= car then
		return
	end
	current.busy = false
	current.arrivedAt = os.clock()
	current.dirt = CarDirt.place(ground, settings.DirtSpots, true, workspace)
	for _, patch in current.dirt do
		table.insert(
			current.prompts,
			JobKit.prompt(patch, {
				action = "Scrub",
				object = "Dirt",
				hold = settings.ScrubHoldSeconds,
				range = settings.RangeStuds,
				owner = current.player,
			}, function(_player: Player, prompt: ProximityPrompt)
				prompt:Destroy()
				local at = table.find(current.dirt, patch)
				if at then
					table.remove(current.dirt, at)
				end
				CarDirt.scrub(patch)
				task.delay(0.5, function()
					patch:Destroy()
				end)
				if #current.dirt == 0 and current.lever then
					current.lever.Enabled = true
				end
				guide(current)
			end)
		)
	end
	guide(current)
end

local function rinse(current: Shift)
	local car = current.car
	if current.busy or not car or #current.dirt > 0 then
		return
	end
	current.busy = true
	if current.lever then
		current.lever.Enabled = false
	end
	guide(current)
	-- A sheet of water over the car.
	local pivot = car:GetPivot()
	local water = JobKit.prop(
		workspace,
		"Rinse",
		Vector3.new(7, 6, 13),
		pivot * CFrame.new(0, 3, 0),
		Color3.fromRGB(120, 190, 255),
		Enum.Material.Glass
	)
	water.Transparency = 0.6
	Sounds.at("Rustle", water)
	task.wait(RINSE_SECONDS)
	water:Destroy()
	if shift ~= current then
		return
	end
	local quick = os.clock() - current.arrivedAt <= settings.QuickSeconds
	local pay = carPay() + if quick then JobKit.scaled(settings.QuickTip, getContext().payMultiplier()) else 0
	JobKit.pay(current.player, pay, if quick then "Car washed, quick tip" else "Car washed", "car wash", "CarWash")
	current.washed += 1
	roll(car, pivot, pivot * CFrame.new(0, 0, -ROLL_STUDS), settings.RollSeconds)
	if shift ~= current then
		return
	end
	clearCar(current)
	if current.washed >= settings.Cars then
		endShift("Shift done. Every car's gleaming!", "Good")
	else
		nextCar(current)
	end
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, `Sudz opens at quota {Config.Paths.Unlocks.CarWash}.`
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if shift then
		return false, "Someone's already washing cars. Try again soon."
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	local current: Shift = {
		player = player,
		endsAt = Timing.now() + settings.ShiftSeconds,
		washed = 0,
		car = nil,
		arrivedAt = 0,
		dirt = {},
		prompts = {},
		lever = nil,
		busy = false,
	}
	shift = current
	local lever = JobKit.first("CarWashLever")
	if lever then
		local prompt = JobKit.prompt(
			lever,
			{ action = "Pull rinse lever", object = "Rinse", hold = 0.3, range = settings.RangeStuds, owner = player },
			function()
				rinse(current)
			end
		)
		prompt.Enabled = false
		current.lever = prompt
	end
	if clockIn then
		clockIn.Enabled = false
	end
	Notifier.send(player, "Clocked in! Scrub each car clean, then pull the rinse lever.", "Info")
	task.spawn(nextCar, current)
	return true, nil
end

local function tick()
	local current = shift
	if not current then
		return
	end
	local bay = JobKit.first("CarWashBay")
	if not current.player.Parent then
		endShift()
	elseif Timing.now() > current.endsAt then
		endShift(`Shift's over. You washed {current.washed}/{settings.Cars} cars.`, "Bad")
	elseif bay and CharacterUtil.distanceTo(current.player, bay.Position) > LEAVE_STUDS then
		endShift("You walked out on your shift.", "Bad")
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	local desk = JobKit.first("CarWashDesk")
	if desk then
		clockIn = JobKit.prompt(desk, { action = "Clock in", object = "Sudz Car Wash", hold = 0.3 }, function(player)
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

local CarWash: MoneyPath.MoneyPath = {
	id = "CarWash",
	displayName = "Sudz Car Wash",
	unlockQuota = Config.Paths.Unlocks.CarWash,
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
		return carPay()
	end,
	hasJob = function(player: Player): boolean
		return shift ~= nil and shift.player == player
	end,
	cancelAll = function(reason: string)
		endShift(reason, "Bad")
	end,
}

return CarWash
