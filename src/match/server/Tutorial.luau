--!strict
-- The first-join tutorial. The lobby sends brand-new players here alone (teleport data
-- `tutorial`), and once the quota starts this walks them through one of everything
-- (Config.Tutorial.Steps), a few words and a trail of arrows at a time (client/TutorialController):
--   knock on a door (it only offers a shady package), deliver it, hide in a bush from the cops,
--   buy a bigger bag, pickpocket someone, bank the cash.
-- Then it's done: saved on their profile (they never see it again) and back to the lobby. While
-- it runs the quota clock never runs out and the cops can't arrest them (TutorialState).

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Profiles = require(ServerScriptService.Common.Profiles)
local DepositService = require(script.Parent.DepositService)
local DoorKnock = require(script.Parent.Paths.DoorKnock)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local NpcService = require(script.Parent.NpcService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local ShopService = require(script.Parent.ShopService)
local Stats = require(script.Parent.Stats)
local TutorialState = require(script.Parent.TutorialState)

local TICK_SECONDS = 0.25
local RESEND_SECONDS = 1.2 -- the nearest bush or pedestrian (and the way there) changes as they move
local ROUTE_STEP = 4 -- studs between the route's points
local APPROACH_STUDS = { 5, 9 } -- how far beside a solid target to look for somewhere to stand
local CLOCK_FLOOR = 300 -- the quota clock never drops below this many seconds...
local CLOCK_RESET = 900 -- ...it's put back up to this

type Run = {
	player: Player,
	index: number, -- the step they're on (0: waiting for the quota to start)
	hiddenFor: number,
	sinceSend: number,
	finished: boolean,
	door: Vector3?, -- the door they're pointed at to knock on
	approach: Vector3?, -- a reachable spot beside...
	approachFor: Vector3?, -- ...this target
}

local settings = Config.Tutorial
local remotes = Remotes.match()

local Tutorial = {}

local runs: { [Player]: Run } = {}

local function keyOf(run: Run): string?
	local step = settings.Steps[run.index]
	return if step then step.key else nil
end

local function nearestTagged(tag: string, from: Vector3, accept: ((BasePart) -> boolean)?): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and (not accept or accept(instance)) then
			local distance = (instance.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = instance, distance
			end
		end
	end
	return best
end

-- Where this step's arrows point (and who, for a moving target).
local function targetFor(run: Run): (Vector3?, Instance?)
	local root = CharacterUtil.getRoot(run.player)
	if not root then
		return nil, nil
	end
	local from = root.Position
	local key = keyOf(run)
	if key == "Knock" then
		-- Stick with one door (it stops answering others while they're at it), unless it's
		-- resting and they've walked off.
		local door = run.door
		if door and (DoorKnock.isFree(door) or (door - from).Magnitude < 25) then
			return door, nil
		end
		run.door = DoorKnock.nearestFree(from)
		return run.door, nil
	elseif key == "Deliver" then
		local alley = nearestTagged("AlleyDrop", from)
		return if alley then alley.Position else nil, nil
	elseif key == "Hide" then
		local bush = nearestTagged("HidingSpot", from)
		return if bush then bush.Position else nil, nil
	elseif key == "Bag" then
		local counter = nearestTagged("ShopCounter", from, function(part: BasePart): boolean
			return part:GetAttribute("Shop") == "Clothes"
		end)
		return if counter then counter.Position else nil, nil
	elseif key == "Pickpocket" then
		local best: Model? = nil
		local bestDistance = math.huge
		for _, pedestrian in NpcService.pedestrians() do
			local pedestrianRoot = pedestrian:FindFirstChild("HumanoidRootPart")
			if pedestrianRoot and pedestrianRoot:IsA("BasePart") then
				local distance = (pedestrianRoot.Position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = pedestrian, distance
				end
			end
		end
		local pedestrianRoot = best and best:FindFirstChild("HumanoidRootPart")
		if pedestrianRoot and pedestrianRoot:IsA("BasePart") then
			return pedestrianRoot.Position, best
		end
		return nil, nil
	elseif key == "Bank" then
		local desk = nearestTagged("BankCounter", from)
		return if desk then desk.Position else nil, nil
	end
	return nil, nil
end

local function pathBetween(from: Vector3, to: Vector3): { Vector3 }?
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local points: { Vector3 } = {}
	for _, waypoint in path:GetWaypoints() do
		local last = points[#points]
		if not last or (waypoint.Position - last).Magnitude >= ROUTE_STEP then
			table.insert(points, waypoint.Position)
		end
	end
	return points
end

-- A walkable way from them to the target, round the buildings (nil if none was found). Doors,
-- counters and bushes are solid, so the way goes to a spot beside them (found once a step).
local function routeTo(run: Run, target: Vector3): { Vector3 }?
	local root = CharacterUtil.getRoot(run.player)
	if not root then
		return nil
	end
	local from = root.Position
	local approach = run.approach
	if approach and run.approachFor and (run.approachFor - target).Magnitude < 1 then
		return pathBetween(from, approach)
	end
	local direct = pathBetween(from, target)
	if direct then
		return direct
	end
	for _, reach in APPROACH_STUDS do
		for turn = 0, 7 do
			local angle = turn * math.pi / 4
			local spot = target + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
			local route = pathBetween(from, spot)
			if route then
				run.approach, run.approachFor = spot, target
				return route
			end
		end
	end
	return nil
end

local function send(run: Run, cheer: string?)
	local step = settings.Steps[run.index]
	if not step or not run.player.Parent then
		return
	end
	run.sinceSend = 0
	local index = run.index
	local target, follow = targetFor(run)
	local function fire(route: { Vector3 }?)
		if run.index == index and run.player.Parent and not run.finished then
			remotes.Tutorial:fireClient(run.player, {
				index = index,
				total = #settings.Steps,
				text = step.text,
				target = target,
				route = route,
				follow = follow,
				cheer = cheer,
			})
		end
	end
	if cheer or not target then
		fire(nil) -- the new step shows at once; its route follows a moment later
	end
	if target then
		task.spawn(function()
			fire(routeTo(run, target :: Vector3))
		end)
	end
end

local function enter(run: Run, index: number, cheer: string?)
	run.index = index
	run.hiddenFor = 0
	run.door = nil
	local key = keyOf(run)
	DoorKnock.only(run.player, if key == "Knock" then "ShadyPackage" else nil)
	if key == "Bag" then
		-- Make sure the bag's affordable (the package pays for it, but just in case).
		local price = math.floor(Config.Shop.Bag[1].price * 1.2)
		local carried = EconomyService.account(run.player).carried
		if carried < price then
			EconomyService.addCarried(run.player, price - carried, "tutorial: bag money", true)
		end
	end
	send(run, cheer)
end

local function finish(run: Run)
	local player = run.player
	run.finished = true
	DoorKnock.only(player, nil)
	remotes.Tutorial:fireClient(player, {
		index = #settings.Steps,
		total = #settings.Steps,
		text = settings.DoneSubtitle,
		cheer = settings.DoneText,
		done = true,
	})
	local data = Profiles.get(player)
	if data then
		data.TutorialDone = true
		Profiles.markChanged(player)
		Profiles.save(player)
	end
	task.delay(settings.DoneSeconds, function()
		runs[player] = nil
		TutorialState.remove(player)
		if player.Parent then
			RosterService.sendToLobby({ player })
		end
	end)
end

-- They just did `key`: on to the next step (if that's the step they're on).
local function advance(player: Player, key: string)
	local run = runs[player]
	if not run or run.finished or keyOf(run) ~= key then
		return
	end
	if run.index >= #settings.Steps then
		finish(run)
	else
		local nextStep = settings.Steps[run.index + 1]
		enter(run, run.index + 1, nextStep.cheer)
	end
end

-- Starts the tutorial for them (the first step shows once the quota's running).
function Tutorial.begin(player: Player)
	if runs[player] then
		return
	end
	TutorialState.add(player)
	runs[player] = {
		player = player,
		index = 0,
		hiddenFor = 0,
		sinceSend = 0,
		finished = false,
		door = nil,
		approach = nil,
		approachFor = nil,
	}
end

local function fromLobby(player: Player): boolean
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local teleportData = if ok and typeof(joinData) == "table" then (joinData :: any).TeleportData else nil
	return typeof(teleportData) == "table" and teleportData.tutorial == true
end

local function tick()
	local now = Timing.now()
	if TutorialState.server and RunState.phase == "Quota" and RunState.phaseEndsAt - now < CLOCK_FLOOR then
		RunState.phaseEndsAt = now + CLOCK_RESET
		RunState.changed:Fire()
	end
	for player, run in runs do
		if not player.Parent then
			runs[player] = nil
		elseif not run.finished then
			if run.index == 0 then
				if RunState.phase == "Quota" then
					enter(run, 1)
				end
			else
				if keyOf(run) == "Hide" and HeatService.isHiding(player) then
					run.hiddenFor += TICK_SECONDS
					if run.hiddenFor >= settings.HideSeconds then
						HeatService.clear(player)
						advance(player, "Hide")
					end
				end
				run.sinceSend += TICK_SECONDS
				if run.sinceSend >= RESEND_SECONDS then
					send(run)
				end
			end
		end
	end
end

function Tutorial.start()
	local function joined(player: Player)
		if fromLobby(player) then
			Tutorial.begin(player)
		end
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player: Player)
		runs[player] = nil
		TutorialState.remove(player)
	end)

	DoorKnock.started:Connect(function(player: Player, kind: string)
		if kind == "ShadyPackage" then
			advance(player, "Knock")
		end
	end)
	DoorKnock.finished:Connect(function(player: Player, kind: string)
		if kind == "ShadyPackage" then
			advance(player, "Deliver")
		end
	end)
	DoorKnock.failed:Connect(function(player: Player, _kind: string)
		local run = runs[player]
		if run and keyOf(run) == "Deliver" then
			enter(run, 1) -- the package fell through: knock again
		end
	end)
	ShopService.upgraded:Connect(function(player: Player, id: string)
		if id == "Bag" then
			advance(player, "Bag")
		end
	end)
	Stats.recorded:Connect(function(player: Player, stat: string)
		if stat == "Pickpocket" then
			advance(player, "Pickpocket")
		end
	end)
	DepositService.deposited:Connect(function(player: Player)
		advance(player, "Bank")
	end)

	task.spawn(function()
		while true do
			tick()
			task.wait(TICK_SECONDS)
		end
	end)
end

return Tutorial
