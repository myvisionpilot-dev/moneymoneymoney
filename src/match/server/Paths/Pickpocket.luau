--!strict
-- Pickpocketing: hold E on a pedestrian to start the minigame. They stop to check their phone
-- while a needle sweeps a bar; press while it's in the green, once a round, three rounds. Get
-- them all and you lift their wallet (Pickpocket.MinPay-MaxPay at tier 1, big wallets rare) for
-- a little heat. Miss one and they spot you: Heat.PickpocketFail. The server makes the rounds
-- and checks every press; the client only reports when it pressed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local BoostService = require(script.Parent.Parent.BoostService)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local NpcService = require(script.Parent.Parent.NpcService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local Stats = require(script.Parent.Parent.Stats)

local RANGE_SLACK = 4
local TIMEOUT_SLACK = 2 -- seconds after the last round before an unfinished game counts as spotted

local settings = Config.Paths.Pickpocket
local minigame = settings.Minigame
local remotes = Remotes.match()
local promptLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local pressLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

type Game = {
	pedestrian: Model,
	prompt: ProximityPrompt,
	zones: { Types.PickpocketZone },
	startedAt: number, -- os.clock()
}

local games: { [Player]: Game } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("Pickpocket used before init")
	end
	return current
end

-- Where the needle is (0 to 1) t seconds into a round: it bounces end to end.
local function needleAt(zone: Types.PickpocketZone, t: number): number
	local travel = (t * zone.speed) % 2
	return if travel <= 1 then travel else 2 - travel
end

local function hits(zone: Types.PickpocketZone, t: number): boolean
	local position = needleAt(zone, t)
	return position >= zone.start - minigame.Tolerance and position <= zone.start + zone.width + minigame.Tolerance
end

-- A tier-1 wallet between MinPay and MaxPay, skewed low so big wallets are rare.
local function rollWallet(): number
	local spread = settings.MaxPay - settings.MinPay
	local amount = settings.MinPay + spread * rng:NextNumber() ^ settings.PayRarity
	return math.floor(amount / 10 + 0.5) * 10
end

local function payout(_player: Player, _tier: number): number
	return math.floor(rollWallet() * getContext().payMultiplier() + 0.5)
end

local function setFrozen(pedestrian: Model, frozen: boolean)
	local humanoid = pedestrian:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if frozen then 0 else settings.WalkSpeed
	end
end

-- Ends the game: the pedestrian walks on and can be picked again after the cooldown.
local function finish(player: Player, current: Game)
	if games[player] ~= current then
		return
	end
	games[player] = nil
	if player.Parent then
		remotes.PickpocketGame:fireClient(player, nil)
	end
	setFrozen(current.pedestrian, false)
	local prompt = current.prompt
	task.delay(settings.CooldownSeconds, function()
		if prompt.Parent then
			prompt.Enabled = true
		end
	end)
end

local function spotted(player: Player, current: Game, why: string)
	finish(player, current)
	HeatService.add(player, Config.Heat.PickpocketFail)
	Notifier.send(player, `{current.pedestrian.Name} {why}`, "Bad")
	local root = current.pedestrian:FindFirstChild("HumanoidRootPart")
	if root then
		Sounds.at("Whistle", root)
	end
end

local function succeed(player: Player, current: Game)
	finish(player, current)
	local base = rollWallet()
	local pay = math.floor(base * getContext().payMultiplier() + 0.5)
	local added = EconomyService.addCarried(player, pay, "pickpocket")
	HeatService.add(player, Config.Heat.Pickpocket)
	local name = current.pedestrian.Name
	local headline = if base >= settings.FatWallet
		then `Fat wallet! You lifted {name}'s wallet.`
		else `You lifted {name}'s wallet.`
	PayNotice.send(player, headline, added, pay)
	Juice.sound(player, "Swipe")
	Stats.record(player, "Pickpocket")
end

local function begin(player: Player, pedestrian: Model, prompt: ProximityPrompt): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Pickpocketing opens when a quota starts."
	end
	if games[player] or not ctx.canWork(player) or not PromptGuard.held(prompt, player) or not prompt.Enabled then
		return false, nil
	end
	local root = pedestrian:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, nil
	end
	if CharacterUtil.distanceTo(player, root.Position) > settings.RangeStuds + RANGE_SLACK then
		return false, nil
	end
	if EconomyService.isFull(player) then
		return false, "Your bag is full. Deposit at the bank first!"
	end

	prompt.Enabled = false
	setFrozen(pedestrian, true)
	local zones: { Types.PickpocketZone } = {}
	local wider = BoostService.zoneMultiplier(player) -- a candy bar steadies your hands
	for index, baseWidth in minigame.ZoneWidths do
		local width = math.min(baseWidth * wider, 0.5)
		table.insert(zones, {
			start = rng:NextNumber(0.08, 0.92 - width),
			width = width,
			speed = minigame.Speeds[index] or minigame.Speeds[#minigame.Speeds],
		})
	end
	local current: Game = { pedestrian = pedestrian, prompt = prompt, zones = zones, startedAt = os.clock() }
	games[player] = current
	remotes.PickpocketGame:fireClient(player, {
		target = pedestrian.Name,
		zones = zones,
		roundSeconds = minigame.RoundSeconds,
		pauseSeconds = minigame.PauseSeconds,
	})
	local longest = #zones * (minigame.RoundSeconds + minigame.PauseSeconds) + minigame.LatencySlack + TIMEOUT_SLACK
	task.delay(longest, function()
		if games[player] == current then
			spotted(player, current, "noticed you hovering. +1 heat")
		end
	end)
	return true, nil
end

-- The client sends its press times when it finishes (all hits) or on its first miss.
local function onPresses(player: Player, payload: unknown)
	local current = games[player]
	if not current or not pressLimiter:allow(player) or typeof(payload) ~= "table" then
		return
	end
	local presses: { number } = {}
	for index = 1, #current.zones do
		local value = (payload :: { any })[index]
		if value == nil then
			break
		elseif typeof(value) ~= "number" or value ~= value then
			return
		end
		table.insert(presses, value)
	end
	if #presses == 0 then
		return
	end

	-- Nobody can claim more time than has passed (plus a little lag).
	local claimed = 0
	for index, t in presses do
		claimed += math.max(t, 0) + (if index > 1 then minigame.PauseSeconds else 0)
	end
	if claimed > os.clock() - current.startedAt + minigame.LatencySlack then
		warn(`[Pickpocket] {player.Name} claimed {claimed}s of presses in {os.clock() - current.startedAt}s`)
		spotted(player, current, "caught you! +1 heat")
		return
	end
	local root = current.pedestrian:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		finish(player, current)
		return
	end
	if CharacterUtil.distanceTo(player, root.Position) > settings.RangeStuds + RANGE_SLACK then
		spotted(player, current, "felt you pulling away! +1 heat")
		return
	end

	for index, t in presses do
		if t < 0 or t > minigame.RoundSeconds or not hits(current.zones[index], t) then
			spotted(player, current, "caught you! +1 heat")
			return
		end
	end
	if #presses == #current.zones then
		succeed(player, current)
	end
end

local function setupPedestrian(pedestrian: Model)
	local root = pedestrian:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickpocketPrompt"
	prompt.ActionText = "Pickpocket"
	prompt.ObjectText = pedestrian.Name
	prompt.HoldDuration = settings.HoldSeconds
	prompt.MaxActivationDistance = settings.RangeStuds
	prompt.RequiresLineOfSight = false
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(player: Player)
		if not promptLimiter:allow(player) then
			return
		end
		local ok, message = begin(player, pedestrian, prompt)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = root
end

local function endQuietly(player: Player)
	local current = games[player]
	if current then
		finish(player, current)
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, pedestrian in NpcService.pedestrians() do
		setupPedestrian(pedestrian)
	end
	NpcService.pedestrianAdded:Connect(setupPedestrian)
	remotes.PickpocketPresses:onServer(onPresses)
	Players.PlayerRemoving:Connect(endQuietly)
end

local function start(_player: Player, _source: Instance?): (boolean, string?)
	return false, "Hold E on a pedestrian."
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function hasJob(player: Player): boolean
	return games[player] ~= nil
end

local Pickpocket: MoneyPath.MoneyPath = {
	id = "Pickpocket",
	displayName = "Pickpocketing",
	unlockQuota = Config.Paths.Unlocks.Pickpocket,
	legal = false,
	init = init,
	start = start,
	complete = complete,
	fail = function(player: Player, _reason: string)
		endQuietly(player)
	end,
	payout = payout,
	hasJob = hasJob,
	cancelAll = function(_reason: string)
		for player in games do
			endQuietly(player)
		end
	end,
}

return Pickpocket
