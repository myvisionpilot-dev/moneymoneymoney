--!strict
-- NPCs built from R15 rigs (no Creator Store models), dressed in free Roblox-made hair and
-- clothes from Config.Outfits: pedestrians walking the footpaths, plus rigs for police, door
-- residents and shopkeepers. Pedestrians dash out of the way of cars (NpcService.dodge; the
-- Dodging attribute makes every client play the leap, see client/DodgeController).
-- Routes come from parts tagged PedWaypoint with attributes Route (string) and Order (number).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local CollisionGroups = require(script.Parent.CollisionGroups)

local WAYPOINT_TAG = "PedWaypoint"
local DODGE_ATTRIBUTE = "Dodging"
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
	"Busker Bella",
	"Hot Dog Hal",
	"Power-Walk Pam",
	"Headphones Hugo",
}

-- NPCs never climb, swim or fall over: switching those off saves the physics some work.
local UNUSED_STATES = {
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp,
}

local SKIN_TONES = {
	Color3.fromRGB(255, 224, 196),
	Color3.fromRGB(241, 194, 158),
	Color3.fromRGB(224, 172, 132),
	Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(172, 112, 76),
	Color3.fromRGB(141, 85, 54),
	Color3.fromRGB(110, 64, 40),
	Color3.fromRGB(80, 48, 32),
}

-- Body colours show wherever the clothes don't (arms without sleeves, a torso with no shirt).
-- Clothing and hair are catalog ids; nil leaves that part bare.
export type Look = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hair: number?,
	hat: number?,
	top: number?, -- a classic shirt
	bottom: number?, -- classic pants
}

local NpcService = {
	pedestrianAdded = Signal.new() :: Signal.Signal<Model>,
}

local rng = Random.new()
local pedestrians: { Model } = {}
local heading: { [Model]: Vector3 } = {} -- where each pedestrian is walking to
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

local function pick(random: Random, list: { number }): number?
	return if #list > 0 then list[random:NextInteger(1, #list)] else nil
end

local function lookFrom(random: Random): Look
	local outfits = Config.Outfits
	return {
		skin = SKIN_TONES[random:NextInteger(1, #SKIN_TONES)],
		shirt = Color3.fromHSV(random:NextNumber(), 0.55, 0.85),
		pants = Color3.fromHSV(random:NextNumber(), 0.35, 0.45),
		hair = pick(random, outfits.Hair),
		hat = if random:NextNumber() < outfits.HatChance then pick(random, outfits.Hats) else nil,
		top = pick(random, outfits.Shirts),
		bottom = pick(random, outfits.Pants),
	}
end

function NpcService.randomLook(): Look
	return lookFrom(rng)
end

-- The same look every time for the same seed (so a house's resident always looks the same).
function NpcService.lookFromSeed(seed: number): Look
	return lookFrom(Random.new(seed))
end

local function describe(look: Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftLegColor = look.pants
	description.RightLegColor = look.pants
	description.HairAccessory = if look.hair then tostring(look.hair) else ""
	description.HatAccessory = if look.hat then tostring(look.hat) else ""
	description.Shirt = look.top or 0
	description.Pants = look.bottom or 0
	return description
end

-- Builds an unparented R15 rig. Yields while Roblox loads the model and its clothes; if the
-- catalog can't be reached, the NPC still turns up in plain colours.
function NpcService.makeRig(name: string, look: Look): Model
	local ok, dressed = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(look), Enum.HumanoidRigType.R15)
	end)
	local model = if ok
		then dressed
		else Players:CreateHumanoidModelFromDescription(
			describe({ skin = look.skin, shirt = look.shirt, pants = look.pants }),
			Enum.HumanoidRigType.R15
		)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- player-only script; NPC animation is handled below
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.NameDisplayDistance = 40
		for _, state in UNUSED_STATES do
			humanoid:SetStateEnabled(state, false)
		end
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
	CollisionGroups.people(model)
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

-- Roblox gives up on a MoveTo after 8 seconds, and a footpath can take a minute to walk, so
-- keep asking until they get there (or stop trying after a while if something blocks them).
local function walkTo(model: Model, humanoid: Humanoid, target: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart")
	local distance = if root and root:IsA("BasePart") then (root.Position - target).Magnitude else 0
	local tries = math.ceil(distance / math.max(humanoid.WalkSpeed, 1) / 7) + 3
	heading[model] = target
	for _ = 1, tries do
		if not model.Parent then
			return
		end
		humanoid:MoveTo(target)
		local reached = humanoid.MoveToFinished:Wait()
		if model:GetAttribute(DODGE_ATTRIBUTE) then
			-- That was the dash aside, not this footpath; carry on once they've picked themselves up.
			while model.Parent and model:GetAttribute(DODGE_ATTRIBUTE) do
				task.wait(0.1)
			end
		elseif reached then
			return
		end
	end
end

-- A quick leap aside, away from a car (`away` is the direction to go). False if they're
-- already dodging or busy (a pickpocket has them frozen).
function NpcService.dodge(model: Model, away: Vector3): boolean
	local settings = Config.Dodge
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if model:GetAttribute(DODGE_ATTRIBUTE) or not humanoid or not root or not root:IsA("BasePart") then
		return false
	end
	if humanoid.WalkSpeed <= 0 or humanoid.Health <= 0 then
		return false
	end
	local walkSpeed = humanoid.WalkSpeed
	model:SetAttribute(DODGE_ATTRIBUTE, true)
	humanoid.WalkSpeed = settings.DashSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = settings.HopHeight
	humanoid:MoveTo(root.Position + away * settings.DashStuds)
	humanoid.Jump = true
	task.delay(settings.DashSeconds, function()
		if humanoid.WalkSpeed == settings.DashSpeed then
			humanoid.WalkSpeed = walkSpeed
		end
	end)
	task.delay(settings.Seconds, function()
		if not model.Parent then
			return
		end
		model:SetAttribute(DODGE_ATTRIBUTE, nil)
		local target = heading[model]
		if target then
			humanoid:MoveTo(target)
		end
	end)
	return true
end

local function walkRoute(model: Model, humanoid: Humanoid, route: { Vector3 }, startIndex: number)
	local index = startIndex
	while model.Parent do
		index = index % #route + 1
		walkTo(model, humanoid, route[index])
	end
end

local function spawnPedestrian(route: { Vector3 }, number: number)
	local name = PEDESTRIAN_NAMES[(number - 1) % #PEDESTRIAN_NAMES + 1]
	local model = NpcService.makeRig(name, NpcService.randomLook())
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
