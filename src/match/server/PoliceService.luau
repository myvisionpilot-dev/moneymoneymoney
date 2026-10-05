--!strict
-- Police NPCs chase wanted players: Police.CopsPerStar per whole star (more, and faster, in
-- the late game and some twists: TwistService), at most Police.MaxCops in town. Cops for stars from Police.CarFromStar up come in police cars. A cop that gets
-- close enough arrests their target (a car pulls you over). No weapons.
-- Hide in a bush with no cop within Police.SpotHiddenStuds and they lose you: they circle
-- where they last saw you until you come out or your heat drains. Police only chase during a quota.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local NpcService = require(script.Parent.NpcService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local TwistService = require(script.Parent.TwistService)
local VehicleModels = require(script.Parent.VehicleModels)

local SPAWN_TAG = "PoliceSpawn"
local DIRECT_CHASE_STUDS = 40 -- closer than this, cops run straight at you
local WAYPOINT_REACHED_STUDS = 4
local SEARCH_STEP = math.rad(60) -- how far round the circle each search point is
local SEARCH_POINT_SECONDS = 4 -- give up on a search point after this long (a wall in the way)
local TICK_SECONDS = 0.1
local REBALANCE_SECONDS = 1
local LIGHT_DIM = 0.75

local UNIFORM = Color3.fromRGB(35, 70, 160)
local UNIFORM_DARK = Color3.fromRGB(25, 30, 55)
local BADGE = Color3.fromRGB(255, 200, 60)

-- Any skin tone, always in uniform.
local function copLook(): NpcService.Look
	return { skin = NpcService.randomLook().skin, shirt = UNIFORM, pants = UNIFORM_DARK }
end

-- A peaked police cap with a gold badge, welded to the head.
local function addCap(model: Model)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape or Enum.PartType.Block
		part.Size = size
		part.Color = color
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand along X; turn them upright
	piece("CapCrown", Vector3.new(0.5, 1.4, 1.4), CFrame.new(0, 0.6, 0) * up, UNIFORM_DARK, Enum.PartType.Cylinder)
	piece("CapBrim", Vector3.new(1.2, 0.12, 0.55), CFrame.new(0, 0.4, -0.72), Color3.new(0.08, 0.08, 0.1))
	piece("CapBadge", Vector3.new(0.3, 0.3, 0.08), CFrame.new(0, 0.62, -0.72), BADGE)
end

type Cop = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Player,
	inCar: boolean,
	turner: AlignOrientation?, -- police cars turn smoothly
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathing: boolean,
	nextPathAt: number,
	searchCenter: Vector3?, -- set while the target is hidden
	searchAngle: number,
	searchPoint: Vector3?,
	searchPointAt: number, -- when they set off for it (a blocked cop moves on)
	stunnedUntil: number, -- os.clock(); zapped by a blaster, they stand still until then
}

type Counts = { foot: number, car: number }

local PoliceService = {}

local cops: { Cop } = {}
local pending: { [Player]: Counts } = {} -- cops still being built, per target
local rng = Random.new()

local function pendingFor(player: Player): Counts
	local counts = pending[player]
	if not counts then
		counts = { foot = 0, car = 0 }
		pending[player] = counts
	end
	return counts
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- The cop sits hidden inside a police car body that swings round instead of snapping.
local function putInCar(model: Model, humanoid: Humanoid, root: BasePart): AlignOrientation?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") then
			descendant:Destroy() -- the face
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local car = VehicleModels.policeCar()
	VehicleModels.attach(car, root, humanoid, model)
	local roof = car:FindFirstChild("Cabin")
	if roof then
		Sounds.at("Siren", roof, true) -- goes when the car does
	end

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		return nil
	end
	humanoid.AutoRotate = false
	local turner = Instance.new("AlignOrientation")
	turner.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turner.Attachment0 = attachment
	turner.MaxAngularVelocity = Config.Police.CarTurnSpeed
	turner.MaxTorque = math.huge
	turner.Responsiveness = 40
	turner.CFrame = root.CFrame.Rotation
	turner.Parent = root
	return turner
end

-- Points a police car toward where it's heading.
local function steer(cop: Cop, goal: Vector3)
	local turner = cop.turner
	local direction = flat(goal - cop.root.Position)
	if turner and direction.Magnitude > 1 then
		turner.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
	end
end

local function moveTo(cop: Cop, goal: Vector3)
	cop.humanoid:MoveTo(goal)
	steer(cop, goal)
end

-- The nearest patrol point at least minStuds away, so police don't pop in on top of you.
local function spawnPosition(target: Player, minStuds: number): Vector3
	local root = CharacterUtil.getRoot(target)
	local from = if root then root.Position else Vector3.zero
	local best: Vector3? = nil
	local bestDistance = math.huge
	local fallback: Vector3? = nil
	for _, spawn in CollectionService:GetTagged(SPAWN_TAG) do
		if spawn:IsA("BasePart") then
			local distance = (spawn.Position - from).Magnitude
			fallback = fallback or spawn.Position
			if distance >= minStuds and distance < bestDistance then
				best = spawn.Position
				bestDistance = distance
			end
		end
	end
	return (best or fallback or Vector3.zero) + Vector3.new(0, 4, 0)
end

local function removeCop(cop: Cop)
	local index = table.find(cops, cop)
	if index then
		table.remove(cops, index)
	end
	cop.model:Destroy()
end

local function removeCopsChasing(player: Player)
	for _, cop in table.clone(cops) do
		if cop.target == player then
			removeCop(cop)
		end
	end
end

local function isWanted(player: Player): boolean
	return player.Parent ~= nil
		and RosterService.isActive(player)
		and not JailService.isJailed(player)
		and HeatService.stars(player) >= 1
end

-- Faster in the late game and slower in a Heatwave (TwistService).
local function speedFor(inCar: boolean): number
	return (if inCar then Config.Police.CarSpeed else Config.Police.CopSpeed) * TwistService.copSpeedMultiplier()
end

local function spawnCop(target: Player, inCar: boolean)
	local counts = pendingFor(target)
	if inCar then
		counts.car += 1
	else
		counts.foot += 1
	end
	task.spawn(function()
		local model = NpcService.makeRig("Police", copLook())
		if not inCar then
			addCap(model)
		end
		if inCar then
			counts.car = math.max(counts.car - 1, 0)
		else
			counts.foot = math.max(counts.foot - 1, 0)
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if
			not humanoid
			or not root
			or not root:IsA("BasePart")
			or not isWanted(target)
			or RunState.phase ~= "Quota"
		then
			model:Destroy()
			return
		end
		humanoid.WalkSpeed = speedFor(inCar)
		local turner = if inCar then putInCar(model, humanoid, root) else nil
		local minStuds = if inCar then Config.Police.CarMinSpawnStuds else Config.Police.MinSpawnStuds
		NpcService.place(model, CFrame.new(spawnPosition(target, minStuds)), true)
		if not inCar then
			Sounds.at("Whistle", root)
		end
		table.insert(cops, {
			model = model,
			humanoid = humanoid,
			root = root,
			target = target,
			inCar = inCar,
			turner = turner,
			waypoints = {},
			waypointIndex = 1,
			pathing = false,
			nextPathAt = 0,
			searchCenter = nil,
			searchAngle = 0,
			searchPoint = nil,
			searchPointAt = 0,
			stunnedUntil = 0,
		})
	end)
end

-- How many foot cops and police cars a player's stars call for (before the town-wide cap).
-- More come per star in the late game and in a Crackdown (TwistService).
local function wantedCounts(player: Player, budget: number): Counts
	local counts = { foot = 0, car = 0 }
	local perStar = TwistService.copsPerStar()
	local total = math.min(math.ceil(HeatService.stars(player) * perStar), budget)
	for index = 1, total do
		local star = math.ceil(index / perStar)
		if star >= Config.Police.CarFromStar then
			counts.car += 1
		else
			counts.foot += 1
		end
	end
	return counts
end

-- Matches the cops (on foot and in cars) to everyone's stars, highest heat first.
local function rebalance()
	if RunState.phase ~= "Quota" then
		for _, cop in table.clone(cops) do
			removeCop(cop)
		end
		return
	end

	local wanted = {}
	for _, player in Players:GetPlayers() do
		if isWanted(player) then
			table.insert(wanted, player)
		end
	end
	table.sort(wanted, function(a: Player, b: Player): boolean
		return HeatService.get(a) > HeatService.get(b)
	end)

	local desired: { [Player]: Counts } = {}
	local budget = Config.Police.MaxCops
	for _, player in wanted do
		local counts = wantedCounts(player, budget)
		desired[player] = counts
		budget -= counts.foot + counts.car
	end

	local current: { [Player]: Counts } = {}
	for _, cop in table.clone(cops) do
		cop.humanoid.WalkSpeed = speedFor(cop.inCar) -- a new quota can change it mid-chase
		local have = current[cop.target] or { foot = 0, car = 0 }
		current[cop.target] = have
		local want = desired[cop.target]
		local limit = if not want then 0 elseif cop.inCar then want.car else want.foot
		local count = if cop.inCar then have.car else have.foot
		if count >= limit or not cop.model.Parent then
			removeCop(cop)
		elseif cop.inCar then
			have.car += 1
		else
			have.foot += 1
		end
	end

	for player, want in desired do
		local have = current[player] or { foot = 0, car = 0 }
		local building = pendingFor(player)
		for _ = 1, want.foot - have.foot - building.foot do
			spawnCop(player, false)
		end
		for _ = 1, want.car - have.car - building.car do
			spawnCop(player, true)
		end
	end
end

-- A player in a bush is spotted if any cop is close; otherwise the police have lost them.
local function updateSpotted()
	local near: { [Player]: boolean } = {}
	local spotStuds = Config.Police.SpotHiddenStuds * TwistService.spotMultiplier() -- shorter in a Blackout
	for _, cop in cops do
		local targetRoot = CharacterUtil.getRoot(cop.target)
		if targetRoot and (targetRoot.Position - cop.root.Position).Magnitude <= spotStuds then
			near[cop.target] = true
		end
	end
	for _, player in Players:GetPlayers() do
		HeatService.setSpotted(player, HeatService.isHiding(player) and near[player] == true)
	end
end

local function requestPath(cop: Cop, goal: Vector3)
	cop.pathing = true
	cop.nextPathAt = os.clock() + Config.Police.RepathSeconds
	task.spawn(function()
		local agent = if cop.inCar
			then { AgentRadius = 3.5, AgentHeight = 6, AgentCanJump = false }
			else { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true }
		local path = PathfindingService:CreatePath(agent)
		local ok = pcall(function()
			path:ComputeAsync(cop.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			cop.waypoints = path:GetWaypoints()
			cop.waypointIndex = 2
		end
		cop.pathing = false
	end)
end

-- Lost the target: walk a wide circle round where they vanished. The circle never comes
-- within Police.SpotHiddenStuds of its middle, so a player who stays put stays hidden.
local function search(cop: Cop, lastSeen: Vector3)
	local center: Vector3 = cop.searchCenter or lastSeen
	if not cop.searchCenter then
		cop.searchCenter = center
		local offset = flat(cop.root.Position - lastSeen)
		cop.searchAngle = math.atan2(offset.Z, offset.X)
		cop.searchPoint = nil
		cop.waypoints = {}
	end
	local current = cop.searchPoint
	local reached = current and flat(current - cop.root.Position).Magnitude < WAYPOINT_REACHED_STUDS * 2
	local blocked = current and os.clock() - cop.searchPointAt > SEARCH_POINT_SECONDS
	if reached or blocked then
		cop.searchAngle += if rng:NextNumber() < 0.5 then SEARCH_STEP else -SEARCH_STEP
		current = nil
	end
	local radius = Config.Police.SearchRadiusStuds
	local point = current
		or center + Vector3.new(math.cos(cop.searchAngle) * radius, 0, math.sin(cop.searchAngle) * radius)
	if point ~= cop.searchPoint then
		cop.searchPoint = point
		cop.searchPointAt = os.clock()
	end
	moveTo(cop, point)
end

local function chase(cop: Cop)
	local targetRoot = CharacterUtil.getRoot(cop.target)
	if not targetRoot or not cop.model.Parent or cop.humanoid.Health <= 0 then
		removeCop(cop)
		return
	end
	if os.clock() < cop.stunnedUntil then
		cop.humanoid:MoveTo(cop.root.Position)
		return
	end
	if HeatService.isHidden(cop.target) then
		search(cop, targetRoot.Position)
		return
	end
	cop.searchCenter = nil

	local distance = (targetRoot.Position - cop.root.Position).Magnitude
	local tagRange = if cop.inCar then Config.Police.CarTagRangeStuds else Config.Police.TagRangeStuds
	if distance <= tagRange then
		local target = cop.target
		JailService.arrest(target, "the police")
		removeCopsChasing(target)
		return
	end
	if distance < DIRECT_CHASE_STUDS then
		cop.waypoints = {}
		moveTo(cop, targetRoot.Position)
		return
	end
	if not cop.pathing and os.clock() >= cop.nextPathAt then
		requestPath(cop, targetRoot.Position)
	end
	local waypoint = cop.waypoints[cop.waypointIndex]
	if waypoint and (waypoint.Position - cop.root.Position).Magnitude < WAYPOINT_REACHED_STUDS then
		cop.waypointIndex += 1
		waypoint = cop.waypoints[cop.waypointIndex]
	end
	if waypoint then
		moveTo(cop, waypoint.Position)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			cop.humanoid.Jump = true
		end
	else
		moveTo(cop, targetRoot.Position)
	end
end

-- Red and blue take turns on every police car.
local function flashLights(redOn: boolean)
	for _, cop in cops do
		local car = cop.model:FindFirstChild("PoliceCar")
		local red = car and car:FindFirstChild("LightRed")
		local blue = car and car:FindFirstChild("LightBlue")
		if red and red:IsA("BasePart") and blue and blue:IsA("BasePart") then
			red.Transparency = if redOn then 0 else LIGHT_DIM
			blue.Transparency = if redOn then LIGHT_DIM else 0
		end
	end
end

function PoliceService.copCount(): number
	return #cops
end

-- True if this model is one of the police.
function PoliceService.isCop(model: Model): boolean
	for _, cop in cops do
		if cop.model == model then
			return true
		end
	end
	return false
end

-- Zapped by a blaster: the cop freezes for a few seconds (and can't arrest anyone).
function PoliceService.stun(model: Model, seconds: number)
	for _, cop in cops do
		if cop.model == model then
			cop.stunnedUntil = os.clock() + seconds
			cop.humanoid:MoveTo(cop.root.Position)
			return
		end
	end
end

function PoliceService.start()
	JailService.arrested:Connect(removeCopsChasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		removeCopsChasing(player)
		pending[player] = nil
	end)

	task.spawn(function()
		local sinceRebalance = REBALANCE_SECONDS
		local sinceFlash = 0
		local redOn = true
		while true do
			local dt = task.wait(TICK_SECONDS)
			sinceRebalance += dt
			sinceFlash += dt
			if sinceRebalance >= REBALANCE_SECONDS then
				sinceRebalance = 0
				rebalance()
			end
			if sinceFlash >= Config.Police.LightFlashSeconds then
				sinceFlash = 0
				redOn = not redOn
				flashLights(redOn)
			end
			updateSpotted()
			for _, cop in table.clone(cops) do
				if table.find(cops, cop) then
					chase(cop)
				end
			end
		end
	end)
end

return PoliceService
