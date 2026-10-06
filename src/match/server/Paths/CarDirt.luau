--!strict
-- Patches on a sedan from VehicleModels (car space: facing -Z, ground at 0), for scrubbing or
-- banging out: dirt for the house "wash the car" chore and the Sudz car wash, dents on a car
-- flip wreck. The chore uses the body panels; the car wash adds the roof, windows and wheels.
-- Callers add the prompts and keep track of what's left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local DIRT = Color3.fromRGB(110, 80, 50)

type Spot = { position: Vector3, normal: Vector3 }

-- Bonnet, boot and the four sides of the body.
local BODY: { Spot } = {
	{ position = Vector3.new(0, 3.35, -4), normal = Vector3.yAxis },
	{ position = Vector3.new(0, 3.35, 5.1), normal = Vector3.yAxis },
	{ position = Vector3.new(-3.05, 2, -2.5), normal = -Vector3.xAxis },
	{ position = Vector3.new(3.05, 2, -2.5), normal = Vector3.xAxis },
	{ position = Vector3.new(-3.05, 2, 3), normal = -Vector3.xAxis },
	{ position = Vector3.new(3.05, 2, 3), normal = Vector3.xAxis },
}

-- Roof, side windows, windscreen and the four wheels.
local EXTRA: { Spot } = {
	{ position = Vector3.new(0, 5.6, 0.8), normal = Vector3.yAxis },
	{ position = Vector3.new(-2.75, 4.3, -0.6), normal = -Vector3.xAxis },
	{ position = Vector3.new(2.75, 4.3, -0.6), normal = Vector3.xAxis },
	{ position = Vector3.new(0, 4.32, -2.64), normal = Vector3.new(0, 0.514, -0.857) }, -- the sloped windscreen
	{ position = Vector3.new(-3.65, 1.1, -3.8), normal = -Vector3.xAxis },
	{ position = Vector3.new(3.65, 1.1, -3.8), normal = Vector3.xAxis },
	{ position = Vector3.new(-3.65, 1.1, 3.8), normal = -Vector3.xAxis },
	{ position = Vector3.new(3.65, 1.1, 3.8), normal = Vector3.xAxis },
}

export type Look = {
	name: string,
	color: Color3,
	material: Enum.Material,
	transparency: number,
}

local DIRT_LOOK: Look = { name = "Dirt", color = DIRT, material = Enum.Material.Sand, transparency = 0.1 }

local rng = Random.new()

local CarDirt = {}

-- `count` patches in random spots on the car standing at `ground`. `everywhere` adds the roof,
-- windows and wheels to the body panels.
function CarDirt.place(ground: CFrame, count: number, everywhere: boolean, parent: Instance, look: Look?): { BasePart }
	local style = look or DIRT_LOOK
	local pool = table.clone(BODY)
	if everywhere then
		for _, spot in EXTRA do
			table.insert(pool, spot)
		end
	end
	for index = #pool, 2, -1 do
		local swap = rng:NextInteger(1, index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	local patches: { BasePart } = {}
	for index = 1, math.min(count, #pool) do
		local where = pool[index]
		local position = ground:PointToWorldSpace(where.position)
		local facing = ground:VectorToWorldSpace(where.normal)
		local up = if math.abs(facing.Y) > 0.9 then ground.LookVector else Vector3.yAxis
		local patch = Instance.new("Part")
		patch.Name = style.name
		patch.Size = Vector3.new(1.8, 1.8, 0.12)
		patch.CFrame = CFrame.lookAt(position + facing * 0.05, position + facing * 2, up)
		patch.Color = style.color
		patch.Material = style.material
		patch.Transparency = style.transparency
		patch.Anchored = true
		patch.CanCollide = false
		patch.CanQuery = false
		patch.CanTouch = false
		patch.CastShadow = false
		patch.Parent = parent
		table.insert(patches, patch)
	end
	return patches
end

-- The patch fades away with a scrubbing sound (the caller destroys it later).
function CarDirt.scrub(patch: BasePart)
	Sounds.at("Rustle", patch)
	TweenService:Create(patch, TweenInfo.new(0.4), { Transparency = 1, Size = patch.Size * 0.3 }):Play()
end

return CarDirt
