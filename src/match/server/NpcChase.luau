--!strict
-- Chasing on foot, for NPCs that aren't police (repo men, the rival crew): straight at the
-- target when close, otherwise along a path that's re-planned every second. Also turns up a
-- chaser at the patrol point nearest someone (but not too near).

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")

local NpcService = require(script.Parent.NpcService)

local SPAWN_TAG = "PoliceSpawn" -- the patrol points
local DIRECT_STUDS = 40
local WAYPOINT_REACHED_STUDS = 4
local REPATH_SECONDS = 1

export type Chaser = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathing: boolean,
	nextPathAt: number,
}

local NpcChase = {}

local function spawnPoint(near: Vector3, minStuds: number): Vector3
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, spawn in CollectionService:GetTagged(SPAWN_TAG) do
		if spawn:IsA("BasePart") then
			local distance = (spawn.Position - near).Magnitude
			if distance >= minStuds and distance < bestDistance then
				best, bestDistance = spawn.Position, distance
			end
		end
	end
	return (best or near + Vector3.new(minStuds, 0, 0)) + Vector3.new(0, 4, 0)
end

-- Builds a running rig at least minStuds from `near`. Yields while Roblox dresses it; nil if
-- the rig came out broken.
function NpcChase.spawn(name: string, look: NpcService.Look, near: Vector3, minStuds: number, speed: number): Chaser?
	local model = NpcService.makeRig(name, look)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.WalkSpeed = speed
	NpcService.place(model, CFrame.new(spawnPoint(near, minStuds)), true)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		waypoints = {},
		waypointIndex = 1,
		pathing = false,
		nextPathAt = 0,
	}
end

local function requestPath(chaser: Chaser, goal: Vector3)
	chaser.pathing = true
	chaser.nextPathAt = os.clock() + REPATH_SECONDS
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(chaser.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			chaser.waypoints = path:GetWaypoints()
			chaser.waypointIndex = 2
		end
		chaser.pathing = false
	end)
end

-- One step toward `goal`. Returns how far away it still is.
function NpcChase.step(chaser: Chaser, goal: Vector3): number
	local distance = (goal - chaser.root.Position).Magnitude
	if distance < DIRECT_STUDS then
		chaser.waypoints = {}
		chaser.humanoid:MoveTo(goal)
		return distance
	end
	if not chaser.pathing and os.clock() >= chaser.nextPathAt then
		requestPath(chaser, goal)
	end
	local waypoint = chaser.waypoints[chaser.waypointIndex]
	if waypoint and (waypoint.Position - chaser.root.Position).Magnitude < WAYPOINT_REACHED_STUDS then
		chaser.waypointIndex += 1
		waypoint = chaser.waypoints[chaser.waypointIndex]
	end
	chaser.humanoid:MoveTo(if waypoint then waypoint.Position else goal)
	if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
		chaser.humanoid.Jump = true
	end
	return distance
end

function NpcChase.hold(chaser: Chaser)
	chaser.humanoid:MoveTo(chaser.root.Position)
end

return NpcChase
