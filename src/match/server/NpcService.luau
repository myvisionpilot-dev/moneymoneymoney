--!strict
-- Grey-box NPCs built from plain R15 rigs (no Creator Store models): pedestrians walking
-- their routes, plus rigs for police and door residents.
-- Routes come from parts tagged PedWaypoint with attributes Route (string) and Order (number).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local WAYPOINT_TAG = "PedWaypoint"
local WALK_ANIMATION = "rbxassetid://507777826" -- Roblox's default R15 walk
local RUN_ANIMATION = "rbxassetid://507767714" -- Roblox's default R15 run

local PEDESTRIAN_NAMES = {
	"Jogger Jeff",
	"Tourist Tina",
	"Busy Barry",
	"Window Shopper Wendy",
	"Mailman Mo",
	"Daydreamer Dave",
	"Selfie Sam",
	"Snack-Run Sally",
	"Lost Larry",
	"Chatty Cathy",
}

local SKIN_TONES = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 110, 80),
	Color3.fromRGB(105, 64, 40),
}

export type Colors = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
}

local NpcService = {
	pedestrianAdded = Signal.new() :: Signal.Signal<Model>,
}

local rng = Random.new()
local pedestrians: { Model } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "NPCs"
	created.Parent = workspace
	folder = created
	return created
end

local function colorsFrom(random: Random): Colors
	return {
		skin = SKIN_TONES[random:NextInteger(1, #SKIN_TONES)],
		shirt = Color3.fromHSV(random:NextNumber(), 0.55, 0.85),
		pants = Color3.fromHSV(random:NextNumber(), 0.35, 0.45),
	}
end

function NpcService.randomColors(): Colors
	return colorsFrom(rng)
end

-- Same colours every time for the same seed (so a house's resident always looks the same).
function NpcService.colorsFromSeed(seed: number): Colors
	return colorsFrom(Random.new(seed))
end

-- Builds an unparented R15 rig. Yields while Roblox assembles the model.
function NpcService.makeRig(name: string, colors: Colors): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = colors.skin
	description.LeftArmColor = colors.skin
	description.RightArmColor = colors.skin
	description.TorsoColor = colors.shirt
	description.LeftLegColor = colors.pants
	description.RightLegColor = colors.pants
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- player-only script; NPC animation is handled below
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.NameDisplayDistance = 40
	end
	return model
end

local function addMoveAnimation(humanoid: Humanoid, animationId: string)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return
	end
	track.Looped = true
	humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			if not track.IsPlaying then
				track:Play(0.2)
			end
			track:AdjustSpeed(math.max(speed / 14, 0.5))
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end)
end

-- Puts a rig into the world, owned by the server, with a walk or run animation.
function NpcService.place(model: Model, cframe: CFrame, running: boolean?)
	model:PivotTo(cframe)
	model.Parent = getFolder()
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		addMoveAnimation(humanoid, if running then RUN_ANIMATION else WALK_ANIMATION)
	end
end

function NpcService.pedestrians(): { Model }
	local alive = {}
	for _, model in pedestrians do
		if model.Parent then
			table.insert(alive, model)
		end
	end
	return alive
end

local function readRoutes(): { { Vector3 } }
	local byName: { [string]: { { order: number, position: Vector3 } } } = {}
	for _, instance in CollectionService:GetTagged(WAYPOINT_TAG) do
		if instance:IsA("BasePart") then
			local route = instance:GetAttribute("Route")
			local order = instance:GetAttribute("Order")
			if typeof(route) == "string" and typeof(order) == "number" then
				local list = byName[route] or {}
				byName[route] = list
				table.insert(list, { order = order, position = instance.Position })
			end
		end
	end
	local routes = {}
	for _, list in byName do
		table.sort(list, function(a, b)
			return a.order < b.order
		end)
		local points = {}
		for _, point in list do
			table.insert(points, point.position)
		end
		if #points >= 2 then
			table.insert(routes, points)
		end
	end
	return routes
end

local function walkRoute(model: Model, humanoid: Humanoid, route: { Vector3 }, startIndex: number)
	local index = startIndex
	while model.Parent do
		index = index % #route + 1
		humanoid:MoveTo(route[index])
		humanoid.MoveToFinished:Wait()
	end
end

local function spawnPedestrian(route: { Vector3 }, number: number)
	local name = PEDESTRIAN_NAMES[(number - 1) % #PEDESTRIAN_NAMES + 1]
	local model = NpcService.makeRig(name, NpcService.randomColors())
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		return
	end
	humanoid.WalkSpeed = Config.Paths.Pickpocket.WalkSpeed
	local startIndex = rng:NextInteger(1, #route)
	NpcService.place(model, CFrame.new(route[startIndex] + Vector3.new(0, 3, 0)))
	table.insert(pedestrians, model)
	NpcService.pedestrianAdded:Fire(model)
	walkRoute(model, humanoid, route, startIndex)
end

function NpcService.start()
	local routes = readRoutes()
	if #routes == 0 then
		warn("[NpcService] No PedWaypoint routes on the map; no pedestrians spawned")
		return
	end
	for number = 1, Config.Paths.Pickpocket.Pedestrians do
		task.spawn(spawnPedestrian, routes[(number - 1) % #routes + 1], number)
	end
end

return NpcService
