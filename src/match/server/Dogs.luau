--!strict
-- Dogs built from parts on joints (no Creator Store models): the one you take for a walk and
-- the guard dogs that chase couriers. The server walks them along the ground (a rigid
-- AlignPosition/AlignOrientation, so every screen sees them glide smoothly) and says what
-- they're up to with the DogState attribute; client/DogController moves their legs, tail,
-- ears, head and jaw to match. Whoever owns a dog sets `brain`, called every frame before it
-- moves: pick a goal, a speed, a state.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Studs = require(ReplicatedStorage.Shared.Studs)
local Timing = require(ReplicatedStorage.Shared.Timing)
local CollisionGroups = require(script.Parent.CollisionGroups)

local DOG_TAG = "Dog"
local BODY_HEIGHT = 1.45 -- the root's middle above the feet (before scaling)
local TURN_RATE = math.rad(540) -- degrees a second they can turn
local ACCELERATION = 90 -- studs/s every second
local STEP_UP = 1.6 -- a ledge higher than this is a wall: walk through it at ground level
local FILTER_SECONDS = 1

export type Kind = "Pet" | "Guard"

export type Dog = {
	model: Model,
	root: BasePart,
	align: AlignPosition,
	turn: AlignOrientation,
	kind: Kind,
	scale: number,
	position: Vector3, -- its feet
	heading: Vector3, -- flat direction it faces
	goal: Vector3?, -- where it's going (nil: stand still)
	speed: number, -- top speed toward the goal
	moving: number, -- speed right now
	face: Vector3?, -- standing still: turn to look at this point
	state: string,
	hop: { started: number, seconds: number, height: number }?,
	brain: ((dog: Dog, dt: number) -> ())?,
	alive: boolean,
}

local COATS = {
	{ Color3.fromRGB(150, 100, 60), Color3.fromRGB(95, 60, 35) },
	{ Color3.fromRGB(225, 180, 100), Color3.fromRGB(180, 130, 60) },
	{ Color3.fromRGB(240, 238, 230), Color3.fromRGB(170, 160, 150) },
	{ Color3.fromRGB(205, 120, 60), Color3.fromRGB(140, 75, 35) },
	{ Color3.fromRGB(140, 140, 145), Color3.fromRGB(90, 90, 95) },
}
local GUARD_COAT = { Color3.fromRGB(58, 50, 45), Color3.fromRGB(150, 95, 55) }
local BLACK = Color3.fromRGB(25, 25, 30)

local Dogs = {}

local rng = Random.new()
local dogs: { Dog } = {}
local folder: Folder? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local filterAge = math.huge

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Animals"
	created.Parent = workspace
	folder = created
	return created
end

local function refreshFilter()
	local skip: { Instance } = { getFolder() }
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		table.insert(skip, npcs)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
end

-- The ground under a point (or nil if there's nothing within reach).
function Dogs.groundAt(position: Vector3, reach: number?): Vector3?
	local up = reach or 4
	local hit = workspace:Raycast(position + Vector3.new(0, up, 0), Vector3.new(0, -(up + 12), 0), params)
	return if hit then hit.Position else nil
end

-- Building -----------------------------------------------------------------------------

type Builder = {
	model: Model,
	scale: number,
}

local function piece(
	build: Builder,
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3,
	rotation: CFrame?,
	material: Enum.Material?
): Part
	local s = build.scale
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * s
	p.CFrame = CFrame.new(at * s) * (rotation or CFrame.identity)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	Studs.dress(p)
	p.Parent = build.model
	return p
end

local function fasten(a: BasePart, b: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = a
	joint.Part1 = b
	joint.Parent = b
end

-- A joint client/DogController turns: at `pivot` (unscaled, in the dog's frame).
local function joint(build: Builder, name: string, part0: BasePart, part1: BasePart, pivot: Vector3)
	local where = CFrame.new(pivot * build.scale)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(where)
	motor.C1 = part1.CFrame:ToObjectSpace(where)
	motor.Parent = part0
end

local function build(kind: Kind, name: string): (Model, BasePart, number)
	local scale = if kind == "Guard" then 1.3 else 1
	local coat = if kind == "Guard" then GUARD_COAT else COATS[rng:NextInteger(1, #COATS)]
	local fur, dark = coat[1], coat[2]
	local model = Instance.new("Model")
	model.Name = name
	local b: Builder = { model = model, scale = scale }
	local fabric = Enum.Material.Fabric

	local root = piece(b, "Root", Vector3.new(1.2, 1.1, 2.2), Vector3.new(0, BODY_HEIGHT, 0), fur)
	root.Transparency = 1
	root.Massless = false
	model.PrimaryPart = root

	local body = piece(b, "Body", Vector3.new(1.2, 1.1, 2.2), Vector3.new(0, 1.45, 0.1), fur, nil, fabric)
	joint(b, "Spine", root, body, Vector3.new(0, 1.45, -0.95)) -- sitting tips the body up round the chest
	local chest = piece(b, "Chest", Vector3.new(1.1, 1.1, 0.8), Vector3.new(0, 1.85, -0.95), fur, nil, fabric)
	fasten(body, chest)

	local head = piece(b, "DogHead", Vector3.new(1.1, 1, 1.1), Vector3.new(0, 2.55, -1.45), fur, nil, fabric)
	joint(b, "Neck", body, head, Vector3.new(0, 2.15, -1.2))
	for _, bit in
		{
			piece(b, "Snout", Vector3.new(0.65, 0.4, 0.6), Vector3.new(0, 2.35, -2.2), dark, nil, fabric),
			piece(b, "Nose", Vector3.new(0.3, 0.22, 0.12), Vector3.new(0, 2.47, -2.54), BLACK),
		}
	do
		fasten(head, bit)
	end
	local jaw = piece(b, "Jaw", Vector3.new(0.55, 0.16, 0.55), Vector3.new(0, 2.1, -2.12), dark, nil, fabric)
	joint(b, "Jaw", head, jaw, Vector3.new(0, 2.15, -1.86))
	local tongue =
		piece(b, "Tongue", Vector3.new(0.26, 0.05, 0.4), Vector3.new(0, 2.04, -2.4), Color3.fromRGB(240, 110, 130))
	tongue.Transparency = 1 -- the client shows it while they pant
	fasten(jaw, tongue)
	local mouth = Instance.new("Attachment")
	mouth.Name = "Mouth"
	mouth.Position = Vector3.new(0, 0.12, -0.3) * scale
	mouth.Parent = jaw

	for _, side in { -1, 1 } do
		local eye = piece(b, "Eye", Vector3.new(0.16, 0.2, 0.1), Vector3.new(side * 0.28, 2.75, -2.03), BLACK)
		fasten(head, eye)
		if kind == "Guard" then
			-- A cross little brow.
			local brow = piece(
				b,
				"Brow",
				Vector3.new(0.3, 0.08, 0.08),
				Vector3.new(side * 0.27, 2.92, -2.05),
				dark,
				CFrame.Angles(0, 0, side * 0.35)
			)
			fasten(head, brow)
		end
		local ear = piece(
			b,
			"Ear",
			Vector3.new(0.25, 0.6, 0.4),
			Vector3.new(side * 0.6, 2.75, -1.35),
			dark,
			CFrame.Angles(0, 0, side * -0.3),
			fabric
		)
		joint(b, if side < 0 then "LeftEar" else "RightEar", head, ear, Vector3.new(side * 0.55, 3.0, -1.35))
		for index, z in { -0.75, 0.85 } do
			local leg = piece(b, "Leg", Vector3.new(0.35, 1, 0.35), Vector3.new(side * 0.38, 0.5, z), fur, nil, fabric)
			local paw = piece(b, "Paw", Vector3.new(0.4, 0.2, 0.45), Vector3.new(side * 0.38, 0.1, z - 0.05), dark)
			fasten(leg, paw)
			local legName = (if index == 1 then "Front" else "Back") .. (if side < 0 then "Left" else "Right")
			joint(b, legName, body, leg, Vector3.new(side * 0.38, 1.0, z))
		end
	end
	local tail = piece(
		b,
		"Tail",
		Vector3.new(0.22, 0.22, 0.9),
		Vector3.new(0, 2.15, 1.45),
		dark,
		CFrame.Angles(math.rad(40), 0, 0),
		fabric
	)
	joint(b, "Tail", body, tail, Vector3.new(0, 1.85, 1.15))

	local collar = piece(
		b,
		"Collar",
		Vector3.new(1.2, 0.22, 0.9),
		Vector3.new(0, 2.25, -0.95),
		if kind == "Guard" then BLACK else Color3.fromRGB(220, 50, 50)
	)
	fasten(chest, collar)
	if kind == "Guard" then
		for _, x in { -0.62, 0.62 } do
			for _, z in { -0.25, 0.25 } do
				local spike = piece(
					b,
					"Spike",
					Vector3.new(0.18, 0.18, 0.18),
					Vector3.new(x, 2.25, -0.95 + z),
					Color3.fromRGB(200, 205, 210),
					nil,
					Enum.Material.Metal
				)
				spike.Shape = Enum.PartType.Ball
				fasten(collar, spike)
			end
		end
	end
	local ring = Instance.new("Attachment")
	ring.Name = "Leash"
	ring.Position = Vector3.new(0, 0.12, -0.1) * scale
	ring.Parent = collar
	local trail = Instance.new("Attachment") -- where a dropped leash drags along the ground
	trail.Name = "LeashTrail"
	trail.Position = Vector3.new(0.3, -BODY_HEIGHT + 0.05, 1.8) * scale
	trail.Parent = root
	return model, root, scale
end

-- Spawning and moving ------------------------------------------------------------------

function Dogs.spawn(kind: Kind, ground: CFrame, name: string): Dog
	local model, root, scale = build(kind, name)
	local flat = Vector3.new(ground.LookVector.X, 0, ground.LookVector.Z)
	local heading = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local middle = ground.Position + Vector3.new(0, BODY_HEIGHT * scale, 0)
	model:PivotTo(CFrame.lookAt(middle, middle + heading))
	local anchor = Instance.new("Attachment")
	anchor.Name = "Drive"
	anchor.Parent = root
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = anchor
	align.RigidityEnabled = true
	align.Position = root.Position
	align.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = anchor
	turn.RigidityEnabled = true
	turn.CFrame = CFrame.lookAt(Vector3.zero, heading)
	turn.Parent = root

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- every joint arrives together
	model:SetAttribute("DogKind", kind)
	model:SetAttribute("DogScale", scale)
	model:SetAttribute("DogState", "Idle")
	CollisionGroups.people(model)
	CollectionService:AddTag(model, DOG_TAG)
	model.Parent = getFolder()
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local dog: Dog = {
		model = model,
		root = root,
		align = align,
		turn = turn,
		kind = kind,
		scale = scale,
		position = ground.Position,
		heading = heading,
		goal = nil,
		speed = 0,
		moving = 0,
		face = nil,
		state = "Idle",
		hop = nil,
		brain = nil,
		alive = true,
	}
	table.insert(dogs, dog)
	filterAge = math.huge -- the new dog goes in the ground check's ignore list
	return dog
end

function Dogs.go(dog: Dog, goal: Vector3?, speed: number?)
	dog.goal = goal
	if speed then
		dog.speed = speed
	end
end

function Dogs.lookAt(dog: Dog, point: Vector3?)
	dog.face = point
end

function Dogs.state(dog: Dog, state: string)
	if dog.state ~= state then
		dog.state = state
		dog.model:SetAttribute("DogState", state)
	end
end

function Dogs.hop(dog: Dog, height: number, seconds: number)
	dog.hop = { started = os.clock(), seconds = seconds, height = height }
end

function Dogs.bark(dog: Dog, twice: boolean?)
	local head = dog.model:FindFirstChild("DogHead")
	if head then
		Sounds.at(if twice then "BarkTwice" else "Bark", head)
	end
	dog.model:SetAttribute("BarkAt", Timing.now())
end

-- Straight there, no walking (it got left far behind).
function Dogs.teleport(dog: Dog, feet: Vector3)
	dog.position = feet
	dog.moving = 0
	dog.align.Position = feet + Vector3.new(0, BODY_HEIGHT * dog.scale, 0)
	dog.model:PivotTo(CFrame.lookAt(dog.align.Position, dog.align.Position + dog.heading))
end

function Dogs.mouth(dog: Dog): Attachment?
	local jaw = dog.model:FindFirstChild("Jaw")
	local mouth = jaw and jaw:FindFirstChild("Mouth")
	return if mouth and mouth:IsA("Attachment") then mouth else nil
end

function Dogs.attachment(dog: Dog, name: string): Attachment?
	for _, found in dog.model:GetDescendants() do
		if found.Name == name and found:IsA("Attachment") then
			return found
		end
	end
	return nil
end

-- Open ground at this spot (not inside a building): somewhere a loose dog can run to.
function Dogs.open(point: Vector3): boolean
	local hit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), params)
	return hit ~= nil and hit.Position.Y <= point.Y + 1.5
end

function Dogs.remove(dog: Dog)
	dog.alive = false
	dog.brain = nil
	local index = table.find(dogs, dog)
	if index then
		table.remove(dogs, index)
	end
	dog.model:Destroy()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function turnToward(dog: Dog, direction: Vector3, dt: number)
	local want = flat(direction)
	if want.Magnitude < 0.01 then
		return
	end
	want = want.Unit
	local angle = math.acos(math.clamp(dog.heading:Dot(want), -1, 1))
	if angle < 1e-3 then
		dog.heading = want
		return
	end
	local share = math.min(1, TURN_RATE * dt / angle)
	local blended = dog.heading:Lerp(want, share)
	if blended.Magnitude > 0.01 then
		dog.heading = blended.Unit
	end
end

local function step(dog: Dog, dt: number)
	local brain = dog.brain
	if brain then
		brain(dog, dt)
	end
	if not dog.alive then
		return
	end
	local goal = dog.goal
	local want = 0
	local toGoal = Vector3.zero
	if goal then
		toGoal = flat(goal - dog.position)
		if toGoal.Magnitude > 0.15 then
			want = math.min(dog.speed, toGoal.Magnitude / math.max(dt, 1e-3))
		end
	end
	if dog.moving < want then
		dog.moving = math.min(want, dog.moving + ACCELERATION * dt)
	else
		dog.moving = want
	end
	if dog.moving > 0 and toGoal.Magnitude > 0.01 then
		local move = toGoal.Unit * math.min(dog.moving * dt, toGoal.Magnitude)
		local nextFeet = dog.position + move
		local ground = Dogs.groundAt(nextFeet + Vector3.new(0, 0.5, 0), 2)
		if ground and ground.Y <= dog.position.Y + STEP_UP then
			nextFeet = Vector3.new(nextFeet.X, ground.Y, nextFeet.Z)
		end
		dog.position = nextFeet
		turnToward(dog, toGoal, dt)
	elseif dog.face then
		turnToward(dog, dog.face - dog.position, dt)
	end
	local lift = 0
	local hop = dog.hop
	if hop then
		local t = (os.clock() - hop.started) / hop.seconds
		if t >= 1 then
			dog.hop = nil
		else
			lift = hop.height * math.sin(math.pi * t)
		end
	end
	dog.align.Position = dog.position + Vector3.new(0, BODY_HEIGHT * dog.scale + lift, 0)
	dog.turn.CFrame = CFrame.lookAt(Vector3.zero, dog.heading)
end

function Dogs.start()
	RunService.Heartbeat:Connect(function(dt: number)
		filterAge += dt
		if filterAge >= FILTER_SECONDS then
			filterAge = 0
			refreshFilter()
		end
		for index = #dogs, 1, -1 do
			local dog = dogs[index]
			if not dog.model.Parent then
				table.remove(dogs, index)
				dog.alive = false
			else
				step(dog, dt)
			end
		end
	end)
end

return Dogs
