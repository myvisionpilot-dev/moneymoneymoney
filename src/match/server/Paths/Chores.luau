--!strict
-- Chores you actually do, not just hold a button for:
--   Mow: push the mower over every patch of long grass on the front lawn.
--   Bins: grab each wheelie bin and wheel it out to the kerb, one at a time.
--   CarWash: the resident's car pulls onto the driveway; scrub off every spot of dirt.
-- The server spawns the long grass, carries the props and checks where you are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local VehicleModels = require(script.Parent.Parent.VehicleModels)
local CarDirt = require(script.Parent.CarDirt)
local DoorTypes = require(script.Parent.DoorTypes)
local Residents = require(script.Parent.Parent.Residents)

type Job = DoorTypes.Job
type Kit = DoorTypes.Kit

local settings = Config.Paths.Doors.Chores

local LONG_GRASS = Color3.fromRGB(62, 128, 52)
local CUT_GRASS = Color3.fromRGB(128, 196, 96)
local BIN_COLOR = Color3.fromRGB(40, 110, 60)
local CAR_COLORS = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(50, 110, 210),
	Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(40, 40, 45),
	Color3.fromRGB(240, 190, 60),
}

-- Held low in front, like pushing a mower or wheeling a bin.
local PUSH_OFFSET = CFrame.new(0, -2, -2.6)

local TITLES: { [Residents.Chore]: string } = {
	Mow = "Mow the lawn",
	Bins = "Take out the bins",
	CarWash = "Wash the car",
}

local rng = Random.new()

local Chores = {}

function Chores.title(chore: Residents.Chore): string
	return TITLES[chore]
end

local function prop(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	return part
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Mow ----------------------------------------------------------------------------------

local function beginMow(job: Job, kit: Kit)
	local lawn = job.house.lawn
	if not lawn then
		kit.fail(job, "Their lawn has vanished. Weird.")
		return
	end
	local columns = math.max(1, math.floor(lawn.Size.X / settings.MowPatchStuds + 0.5))
	local rows = math.max(1, math.floor(lawn.Size.Z / settings.MowPatchStuds + 0.5))
	local width, depth = lawn.Size.X / columns, lawn.Size.Z / rows
	local top = lawn.CFrame * CFrame.new(0, lawn.Size.Y / 2, 0)
	for column = 1, columns do
		for row = 1, rows do
			local offset =
				CFrame.new(-lawn.Size.X / 2 + (column - 0.5) * width, 0.5, -lawn.Size.Z / 2 + (row - 0.5) * depth)
			local patch = prop(
				"LongGrass",
				Vector3.new(width - 0.4, 1, depth - 0.4),
				top * offset,
				LONG_GRASS,
				Enum.Material.Grass
			)
			table.insert(job.props, patch)
			table.insert(job.pieces, patch)
		end
	end
	kit.carry(job, "Mower", Vector3.new(2.4, 1.4, 2.8), Color3.fromRGB(210, 50, 45), PUSH_OFFSET)
	job.targets = { lawn.Position }
	kit.notify(job, "Push the mower over all the long grass!")
	kit.guide(job)
end

local function tickMow(job: Job, kit: Kit)
	local root = kit.root(job)
	if not root then
		return
	end
	for index = #job.pieces, 1, -1 do
		local patch = job.pieces[index]
		if flatDistance(patch.Position, root.Position) <= settings.MowReachStuds then
			table.remove(job.pieces, index)
			patch.Color = CUT_GRASS
			TweenService:Create(patch, TweenInfo.new(0.2), { Size = Vector3.new(patch.Size.X, 0.15, patch.Size.Z) })
				:Play()
			patch.CFrame = patch.CFrame * CFrame.new(0, -0.4, 0)
		end
	end
	if #job.pieces == 0 then
		kit.finish(job, "Front lawn mowed")
	end
end

-- Bins ---------------------------------------------------------------------------------

local function binTargets(job: Job): { Vector3 }
	local targets = {}
	for _, bin in job.pieces do
		table.insert(targets, bin.Position)
	end
	return targets
end

local function beginBins(job: Job, kit: Kit)
	local kerb = job.house.kerb
	local bins = job.house.bins
	if not kerb or #bins == 0 then
		kit.fail(job, "They don't seem to have any bins.")
		return
	end
	-- The bins go back where they were a little after the job, however it ends.
	table.insert(job.cleanup, function()
		task.delay(settings.CleanupSeconds, function()
			for _, bin in job.placed do
				bin:Destroy()
			end
			for _, bin in bins do
				bin.Transparency = 0
				bin.CanCollide = true
			end
		end)
	end)
	for _, bin in bins do
		table.insert(job.pieces, bin)
		kit.prompt(job, bin, "Grab bin", settings.BinHoldSeconds, function(prompt: ProximityPrompt)
			if job.carried then
				kit.notify(job, "One bin at a time!")
				return
			end
			prompt:Destroy()
			bin.Transparency = 1
			bin.CanCollide = false
			local index = table.find(job.pieces, bin)
			if index then
				table.remove(job.pieces, index)
			end
			job.carried = kit.carry(job, "Bin", bin.Size, BIN_COLOR, PUSH_OFFSET)
			job.targets = { kerb.WorldPosition }
			kit.guide(job)
		end)
	end
	job.targets = binTargets(job)
	kit.notify(job, "Wheel both bins out to the kerb.")
	kit.guide(job)
end

local function tickBins(job: Job, kit: Kit)
	local carried = job.carried
	local kerb = job.house.kerb
	if not carried or not kerb or not kit.arrived(job, kerb.WorldPosition) then
		return
	end
	carried:Destroy()
	job.carried = nil
	-- Out at the kerb, side by side.
	local side = kerb.WorldCFrame.RightVector * ((#job.placed - 0.5) * 2.6)
	local bin = prop(
		"KerbBin",
		carried.Size,
		CFrame.new(kerb.WorldPosition + side + Vector3.new(0, carried.Size.Y / 2, 0)) * kerb.WorldCFrame.Rotation,
		BIN_COLOR
	)
	bin.CanCollide = true
	table.insert(job.placed, bin)
	Sounds.at("Knock", bin)
	if #job.pieces == 0 then
		kit.finish(job, "Bins taken to the kerb")
	else
		job.targets = binTargets(job)
		kit.guide(job)
	end
end

-- Car wash -----------------------------------------------------------------------------

local function beginCarWash(job: Job, kit: Kit)
	local spot = job.house.carSpot
	if not spot then
		kit.fail(job, "Their car's in the shop. Never mind!")
		return
	end
	local car = VehicleModels.car(CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
	car:PivotTo(spot.WorldCFrame)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = part.Name == "Lower" or part.Name == "Upper"
		end
	end
	car.Parent = workspace
	table.insert(job.cleanup, function()
		task.delay(settings.CleanupSeconds, function()
			car:Destroy()
		end)
	end)

	for _, dirt in CarDirt.place(spot.WorldCFrame, settings.DirtSpots, false, workspace) do
		table.insert(job.props, dirt)
		table.insert(job.pieces, dirt)
		kit.prompt(job, dirt, "Scrub", settings.ScrubHoldSeconds, function(prompt: ProximityPrompt)
			prompt:Destroy()
			local at = table.find(job.pieces, dirt)
			if at then
				table.remove(job.pieces, at)
			end
			CarDirt.scrub(dirt)
			if #job.pieces == 0 then
				kit.finish(job, "Resident's car washed")
			end
		end)
	end
	kit.carry(job, "Sponge", Vector3.new(1, 0.6, 1.4), Color3.fromRGB(255, 220, 70))
	job.targets = { spot.WorldPosition }
	kit.notify(job, "Scrub every bit of dirt off the car!")
	kit.guide(job)
end

-- Dispatch -----------------------------------------------------------------------------

function Chores.begin(job: Job, kit: Kit)
	local chore = job.house.resident.chore
	if chore == "Mow" then
		beginMow(job, kit)
	elseif chore == "Bins" then
		beginBins(job, kit)
	else
		beginCarWash(job, kit)
	end
end

function Chores.tick(job: Job, kit: Kit)
	local chore = job.house.resident.chore
	if chore == "Mow" then
		tickMow(job, kit)
	elseif chore == "Bins" then
		tickBins(job, kit)
	end
end

return Chores
