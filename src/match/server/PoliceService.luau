--!strict
-- Police NPCs chase wanted players: Police.CopsPerStar per whole star, at most Police.MaxCops
-- in town. A cop that gets within Police.TagRangeStuds arrests their target. No weapons.
-- Police only chase during a quota.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local NpcService = require(script.Parent.NpcService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local SPAWN_TAG = "PoliceSpawn"
local DIRECT_CHASE_STUDS = 40 -- closer than this, cops run straight at you
local WAYPOINT_REACHED_STUDS = 4
local TICK_SECONDS = 0.1
local REBALANCE_SECONDS = 1

local COP_COLORS: NpcService.Colors = {
	skin = Color3.fromRGB(234, 184, 146),
	shirt = Color3.fromRGB(35, 70, 160),
	pants = Color3.fromRGB(25, 30, 55),
}

type Cop = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Player,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathing: boolean,
	nextPathAt: number,
}

local PoliceService = {}

local cops: { Cop } = {}
local pending: { [Player]: number } = {} -- cops still being built, per target

-- The nearest patrol point that's at least Police.MinSpawnStuds away, so police don't pop in on top of you.
local function spawnPosition(target: Player): Vector3
	local root = CharacterUtil.getRoot(target)
	local from = if root then root.Position else Vector3.zero
	local best: Vector3? = nil
	local bestDistance = math.huge
	local fallback: Vector3? = nil
	for _, spawn in CollectionService:GetTagged(SPAWN_TAG) do
		if spawn:IsA("BasePart") then
			local distance = (spawn.Position - from).Magnitude
			fallback = fallback or spawn.Position
			if distance >= Config.Police.MinSpawnStuds and distance < bestDistance then
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

local function spawnCop(target: Player)
	pending[target] = (pending[target] or 0) + 1
	task.spawn(function()
		local model = NpcService.makeRig("Police", COP_COLORS)
		pending[target] = math.max((pending[target] or 1) - 1, 0)
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
		humanoid.WalkSpeed = Config.Police.CopSpeed
		NpcService.place(model, CFrame.new(spawnPosition(target)), true)
		table.insert(cops, {
			model = model,
			humanoid = humanoid,
			root = root,
			target = target,
			waypoints = {},
			waypointIndex = 1,
			pathing = false,
			nextPathAt = 0,
		})
	end)
end

-- Matches the number of cops to everyone's stars, highest heat first.
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

	local desired: { [Player]: number } = {}
	local budget = Config.Police.MaxCops
	for _, player in wanted do
		local count = math.min(HeatService.stars(player) * Config.Police.CopsPerStar, budget)
		desired[player] = count
		budget -= count
	end

	local current: { [Player]: number } = {}
	for _, cop in table.clone(cops) do
		local have = current[cop.target] or 0
		if have >= (desired[cop.target] or 0) or not cop.model.Parent then
			removeCop(cop)
		else
			current[cop.target] = have + 1
		end
	end

	for player, count in desired do
		local missing = count - (current[player] or 0) - (pending[player] or 0)
		for _ = 1, missing do
			spawnCop(player)
		end
	end
end

local function requestPath(cop: Cop, goal: Vector3)
	cop.pathing = true
	cop.nextPathAt = os.clock() + Config.Police.RepathSeconds
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
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

local function chase(cop: Cop)
	local targetRoot = CharacterUtil.getRoot(cop.target)
	if not targetRoot or not cop.model.Parent or cop.humanoid.Health <= 0 then
		removeCop(cop)
		return
	end
	local distance = (targetRoot.Position - cop.root.Position).Magnitude
	if distance <= Config.Police.TagRangeStuds then
		local target = cop.target
		JailService.arrest(target, "the police")
		removeCopsChasing(target)
		return
	end
	if distance < DIRECT_CHASE_STUDS then
		cop.waypoints = {}
		cop.humanoid:MoveTo(targetRoot.Position)
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
		cop.humanoid:MoveTo(waypoint.Position)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			cop.humanoid.Jump = true
		end
	else
		cop.humanoid:MoveTo(targetRoot.Position)
	end
end

function PoliceService.copCount(): number
	return #cops
end

function PoliceService.start()
	JailService.arrested:Connect(removeCopsChasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		removeCopsChasing(player)
		pending[player] = nil
	end)

	task.spawn(function()
		local sinceRebalance = REBALANCE_SECONDS
		while true do
			local dt = task.wait(TICK_SECONDS)
			sinceRebalance += dt
			if sinceRebalance >= REBALANCE_SECONDS then
				sinceRebalance = 0
				rebalance()
			end
			for _, cop in table.clone(cops) do
				if table.find(cops, cop) then
					chase(cop)
				end
			end
		end
	end)
end

return PoliceService
