--!strict
-- Repo men, from Repo.FromQuota: the bank's debt collectors go after anyone carrying more than
-- Repo.BagFraction of their bag. A warning first, then one turns up at a patrol point at least
-- Repo.MinSpawnStuds away and chases on foot (slower than a sprint). A tag takes
-- Repo.TakePercent of the cash you carry (not inside the bank). He gives up once you bank or spend it, after
-- Repo.ChaseSeconds, or when the quota ends. A blaster freezes him like a cop. No weapons.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local EconomyService = require(script.Parent.EconomyService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local NpcService = require(script.Parent.NpcService)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local SafeZone = require(script.Parent.SafeZone)

local SPAWN_TAG = "PoliceSpawn" -- the patrol points
local DIRECT_CHASE_STUDS = 40
local WAYPOINT_REACHED_STUDS = 4
local REPATH_SECONDS = 1
local TICK_SECONDS = 0.1
local CHECK_SECONDS = 1
local SUIT = Color3.fromRGB(35, 35, 42)
local SUIT_DARK = Color3.fromRGB(22, 22, 28)

type Repo = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Player,
	givesUpAt: number, -- os.clock()
	stunnedUntil: number,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathing: boolean,
	nextPathAt: number,
}

local settings = Config.Repo

local RepoService = {}

local repos: { Repo } = {}
local building: { [Player]: boolean } = {} -- a repo man is being dressed for them
local warnedAt: { [Player]: number } = {}
local restUntil: { [Player]: number } = {} -- os.clock(): no repo man for them before this

local function repoFor(player: Player): Repo?
	for _, repo in repos do
		if repo.target == player then
			return repo
		end
	end
	return nil
end

-- Carrying more than they should, during a late-game quota.
local function overLimit(player: Player): boolean
	if
		RunState.phase ~= "Quota"
		or RunState.quotaIndex < settings.FromQuota
		or not RosterService.isActive(player)
		or JailService.isJailed(player)
	then
		return false
	end
	local account = EconomyService.account(player)
	return account.carried > account.bagCapacity * settings.BagFraction
end

local function remove(repo: Repo, rest: boolean)
	local index = table.find(repos, repo)
	if index then
		table.remove(repos, index)
	end
	repo.model:Destroy()
	if rest then
		restUntil[repo.target] = os.clock() + settings.CooldownSeconds
	end
end

local function spawnPosition(target: Player): Vector3
	local root = CharacterUtil.getRoot(target)
	local from = if root then root.Position else Vector3.zero
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, spawn in CollectionService:GetTagged(SPAWN_TAG) do
		if spawn:IsA("BasePart") then
			local distance = (spawn.Position - from).Magnitude
			if distance >= settings.MinSpawnStuds and distance < bestDistance then
				best, bestDistance = spawn.Position, distance
			end
		end
	end
	return (best or from + Vector3.new(settings.MinSpawnStuds, 0, 0)) + Vector3.new(0, 4, 0)
end

local function spawnRepo(target: Player)
	building[target] = true
	task.spawn(function()
		local look = NpcService.randomLook()
		look.shirt, look.pants, look.top, look.bottom, look.hat = SUIT, SUIT_DARK, nil, nil, nil
		local model = NpcService.makeRig("Repo Man", look)
		building[target] = nil
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or not overLimit(target) or repoFor(target) then
			model:Destroy()
			return
		end
		humanoid.WalkSpeed = settings.Speed
		NpcService.place(model, CFrame.new(spawnPosition(target)), true)
		table.insert(repos, {
			model = model,
			humanoid = humanoid,
			root = root,
			target = target,
			givesUpAt = os.clock() + settings.ChaseSeconds,
			stunnedUntil = 0,
			waypoints = {},
			waypointIndex = 1,
			pathing = false,
			nextPathAt = 0,
		})
	end)
end

local function requestPath(repo: Repo, goal: Vector3)
	repo.pathing = true
	repo.nextPathAt = os.clock() + REPATH_SECONDS
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(repo.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			repo.waypoints = path:GetWaypoints()
			repo.waypointIndex = 2
		end
		repo.pathing = false
	end)
end

local function tag(repo: Repo)
	local target = repo.target
	local account = EconomyService.account(target)
	local taken = EconomyService.removeCarried(target, account.carried * settings.TakePercent, "repo man")
	Juice.lost(target, taken, "Repo man took a cut")
	Sounds.at("Whistle", repo.root)
	remove(repo, true)
end

local function chase(repo: Repo)
	local target = repo.target
	local targetRoot = CharacterUtil.getRoot(target)
	if not targetRoot or not repo.model.Parent or not overLimit(target) then
		remove(repo, true)
		if target.Parent and targetRoot and RunState.phase == "Quota" and not JailService.isJailed(target) then
			Notifier.send(target, "The repo man gave up. Your cash is safe for now.", "Good")
		end
		return
	end
	if os.clock() >= repo.givesUpAt then
		remove(repo, true)
		Notifier.send(target, "You lost the repo man!", "Good")
		return
	end
	if os.clock() < repo.stunnedUntil then
		repo.humanoid:MoveTo(repo.root.Position)
		return
	end
	local distance = (targetRoot.Position - repo.root.Position).Magnitude
	if distance <= settings.TagRangeStuds then
		if not SafeZone.contains(targetRoot.Position) then
			tag(repo)
		else
			repo.humanoid:MoveTo(repo.root.Position) -- waits by you while you're in the bank
		end
		return
	end
	if distance < DIRECT_CHASE_STUDS then
		repo.waypoints = {}
		repo.humanoid:MoveTo(targetRoot.Position)
		return
	end
	if not repo.pathing and os.clock() >= repo.nextPathAt then
		requestPath(repo, targetRoot.Position)
	end
	local waypoint = repo.waypoints[repo.waypointIndex]
	if waypoint and (waypoint.Position - repo.root.Position).Magnitude < WAYPOINT_REACHED_STUDS then
		repo.waypointIndex += 1
		waypoint = repo.waypoints[repo.waypointIndex]
	end
	repo.humanoid:MoveTo(if waypoint then waypoint.Position else targetRoot.Position)
	if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
		repo.humanoid.Jump = true
	end
end

-- Warns anyone carrying too much, then sends a repo man after them.
local function check()
	local now = os.clock()
	local count = #repos
	for _ in building do
		count += 1
	end
	for _, player in Players:GetPlayers() do
		if not overLimit(player) or repoFor(player) or building[player] or now < (restUntil[player] or 0) then
			warnedAt[player] = nil
			continue
		end
		local warned = warnedAt[player]
		if not warned then
			if count < settings.MaxInTown then
				warnedAt[player] = now
				Notifier.send(
					player,
					"A repo man is coming for the cash in your bag! Bank it, outrun him or zap him.",
					"Bad"
				)
				Juice.sound(player, "Wanted")
			end
		elseif now - warned >= settings.WarnSeconds and count < settings.MaxInTown then
			warnedAt[player] = nil
			count += 1
			spawnRepo(player)
		end
	end
end

function RepoService.isRepo(model: Model): boolean
	for _, repo in repos do
		if repo.model == model then
			return true
		end
	end
	return false
end

-- Zapped by a blaster: he stands still until then.
function RepoService.stun(model: Model, seconds: number)
	for _, repo in repos do
		if repo.model == model then
			repo.stunnedUntil = os.clock() + seconds
			repo.humanoid:MoveTo(repo.root.Position)
		end
	end
end

function RepoService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local repo = repoFor(player)
		if repo then
			remove(repo, false)
		end
		warnedAt[player], restUntil[player], building[player] = nil, nil, nil
	end)
	task.spawn(function()
		local sinceCheck = 0
		while true do
			sinceCheck += task.wait(TICK_SECONDS)
			if sinceCheck >= CHECK_SECONDS then
				sinceCheck = 0
				check()
			end
			for _, repo in table.clone(repos) do
				if table.find(repos, repo) then
					chase(repo)
				end
			end
		end
	end)
end

return RepoService
