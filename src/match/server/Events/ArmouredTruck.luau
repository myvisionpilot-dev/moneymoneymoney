--!strict
-- Armoured truck (from Events.ArmouredTruck.FromQuota): a cash truck drives the town loop (the
-- race checkpoints), slower than walking. Hold E at its back doors to pry them; every pry adds
-- a little heat, and it takes Pries in all (two people get there twice as fast). Cracked, it
-- stops and the cash is split by how many pries each person did. A crime, for hustles. The
-- truck is a hidden driver rig with the van welded on, like a police car, so it moves smoothly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local HeatService = require(script.Parent.Parent.HeatService)
local JailService = require(script.Parent.Parent.JailService)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local NpcService = require(script.Parent.Parent.NpcService)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local RunState = require(script.Parent.Parent.RunState)
local VehicleModels = require(script.Parent.Parent.VehicleModels)
local TownEvent = require(script.Parent.TownEvent)

local ROUTE_TAG = "RaceCheckpoint" -- the town loop, in Order
local CORNER_STUDS = 10 -- this close to a route point counts as reached
local TURN_SPEED = 3 -- radians/s
local LEAVE_SECONDS = 5 -- a cracked truck sits there this long before it goes

local settings = Config.Events.ArmouredTruck

type Truck = {
	ctx: TownEvent.Context,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	turner: AlignOrientation,
	route: { Vector3 },
	nextPoint: number,
	pries: number,
	helpers: { [Player]: number },
	prompt: ProximityPrompt?,
	cracked: boolean,
}

local truck: Truck? = nil
local building = false
local generation = 0 -- bumps when the event stops, so a slow start knows
local lastShownAt = 0 -- the banner follows the truck about once a second

local ArmouredTruck = {
	id = "ArmouredTruck",
	title = "ARMOURED TRUCK",
	seconds = settings.Seconds,
}

local function route(): { Vector3 }
	local points: { { position: Vector3, order: number } } = {}
	for _, instance in CollectionService:GetTagged(ROUTE_TAG) do
		local order = instance:GetAttribute("Order")
		if instance:IsA("BasePart") and typeof(order) == "number" then
			table.insert(points, { position = JobKit.ground(instance).Position, order = order })
		end
	end
	table.sort(points, function(a, b)
		return a.order < b.order
	end)
	local list = {}
	for _, point in points do
		table.insert(list, point.position)
	end
	return list
end

function ArmouredTruck.canStart(): boolean
	return RunState.quotaIndex >= settings.FromQuota and #route() >= 3 and not building
end

local function bannerText(current: Truck): string
	if current.pries == 0 then
		return "A cash truck is driving round town. Pry its back doors open (it's a crime!)"
	end
	return `The truck's doors are {current.pries}/{settings.Pries} cracked. Keep prying!`
end

local function crack(current: Truck)
	current.cracked = true
	current.humanoid.WalkSpeed = 0
	if current.prompt then
		current.prompt:Destroy()
		current.prompt = nil
	end
	local doors = current.model:FindFirstChild("BackDoors", true)
	if doors then
		doors:Destroy()
	end
	local box = current.model:FindFirstChild("Box", true)
	if box and box:IsA("BasePart") then
		Sounds.at("Alarm", box)
	end
	local total = math.floor(settings.Pay * current.ctx.tierMultiplier + 0.5)
	local names = {}
	for player, pries in current.helpers do
		if player.Parent then
			local share = math.floor(total * pries / current.pries + 0.5)
			PayNotice.earn(player, share, "Armoured truck cracked", "armoured truck", false)
			table.insert(names, player.DisplayName)
		end
	end
	local who = table.concat(names, " and ")
	for _, player in Players:GetPlayers() do
		if not current.helpers[player] then
			Notifier.send(player, `{who} cracked the armoured truck!`, "Info")
		end
	end
	current.ctx.finish()
end

local function pry(current: Truck, player: Player)
	if current.cracked or not RosterService.isActive(player) or JailService.isJailed(player) then
		return
	end
	current.pries += 1
	current.helpers[player] = (current.helpers[player] or 0) + 1
	HeatService.add(player, settings.Heat / settings.Pries)
	if current.prompt then
		current.prompt.ObjectText = `Armoured truck {current.pries}/{settings.Pries}`
	end
	if current.pries >= settings.Pries then
		crack(current)
	else
		current.ctx.announce(bannerText(current), current.root.Position)
	end
end

-- The driver: an invisible rig with the van welded on, turning smoothly toward where it's going.
local function build(ctx: TownEvent.Context, at: CFrame): Truck?
	local model = NpcService.makeRig("Armoured Truck", NpcService.randomLook())
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local attachment = root and root:FindFirstChild("RootAttachment")
	if not humanoid or not root or not root:IsA("BasePart") or not attachment or not attachment:IsA("Attachment") then
		model:Destroy()
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") then
			descendant:Destroy()
		end
	end
	humanoid.WalkSpeed = settings.Speed
	humanoid.AutoRotate = false
	model:PivotTo(at)
	VehicleModels.attach(VehicleModels.armouredTruck(), root, humanoid, model)
	local turner = Instance.new("AlignOrientation")
	turner.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turner.Attachment0 = attachment
	turner.MaxAngularVelocity = TURN_SPEED
	turner.MaxTorque = math.huge
	turner.Responsiveness = 40
	turner.CFrame = at.Rotation
	turner.Parent = root
	NpcService.place(model, at, false)
	return {
		ctx = ctx,
		model = model,
		humanoid = humanoid,
		root = root,
		turner = turner,
		route = {},
		nextPoint = 1,
		pries = 0,
		helpers = {},
		prompt = nil,
		cracked = false,
	}
end

function ArmouredTruck.start(ctx: TownEvent.Context)
	local points = route()
	local first = Random.new():NextInteger(1, #points)
	local nextPoint = first % #points + 1
	local at = CFrame.lookAt(points[first] + Vector3.new(0, 4, 0), points[nextPoint] + Vector3.new(0, 4, 0))
	local run = generation
	building = true
	local current = build(ctx, at)
	building = false
	if not current then
		ctx.finish()
		return
	end
	if generation ~= run then
		current.model:Destroy() -- the event ended while the van was being built
		return
	end
	current.route = points
	current.nextPoint = nextPoint
	truck = current
	local doors = current.model:FindFirstChild("BackDoors", true)
	if doors and doors:IsA("BasePart") then
		current.prompt = JobKit.prompt(doors, {
			action = "Pry the doors",
			object = `Armoured truck 0/{settings.Pries}`,
			hold = settings.PryHoldSeconds,
			range = settings.RangeStuds,
		}, function(player: Player)
			pry(current, player)
		end)
	end
	ctx.announce(bannerText(current), current.root.Position)
end

function ArmouredTruck.tick()
	local current = truck
	if not current or current.cracked or not current.model.Parent then
		return
	end
	local goal = current.route[current.nextPoint]
	local flat = Vector3.new(goal.X - current.root.Position.X, 0, goal.Z - current.root.Position.Z)
	if flat.Magnitude < CORNER_STUDS then
		current.nextPoint = current.nextPoint % #current.route + 1
		return
	end
	current.humanoid:MoveTo(goal)
	current.turner.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	if os.clock() - lastShownAt >= 1 then
		lastShownAt = os.clock()
		current.ctx.announce(bannerText(current), current.root.Position)
	end
end

function ArmouredTruck.stop()
	generation += 1
	local current = truck
	truck = nil
	if not current then
		return
	end
	if current.cracked then
		task.delay(LEAVE_SECONDS, function()
			current.model:Destroy()
		end)
	else
		current.model:Destroy()
	end
end

return ArmouredTruck
