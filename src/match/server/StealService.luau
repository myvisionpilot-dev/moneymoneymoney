--!strict
-- Stealing from teammates: a Steal prompt (F) on every character, hidden on your own.
-- Takes Steal.Percent of the victim's carried cash, capped at Steal.CapPercentOfQuota of the
-- quota, with a per-thief cooldown and a grace period at the start of quota 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local PromptGuard = require(script.Parent.PromptGuard)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local RANGE_SLACK = 3

local settings = Config.Steal
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local StealService = {
	changed = Signal.new() :: Signal.Signal<number>, -- userId whose stolen total changed
}

local stolenTotals: { [number]: number } = {}
local lastSteal: { [Player]: number } = {}

function StealService.totalStolen(userId: number): number
	return stolenTotals[userId] or 0
end

-- Counts money taken from a teammate some other way (grabbing a blasted player's cash).
function StealService.record(thief: Player, amount: number)
	if amount <= 0 then
		return
	end
	stolenTotals[thief.UserId] = (stolenTotals[thief.UserId] or 0) + amount
	StealService.changed:Fire(thief.UserId)
end

-- The Snake: whoever stole the most (nil if nobody stole anything).
function StealService.snakeUserId(): number?
	local best: number? = nil
	local bestTotal = 0
	for userId, total in stolenTotals do
		if total > bestTotal then
			best = userId
			bestTotal = total
		end
	end
	return best
end

local function onSteal(thief: Player, victim: Player, prompt: ProximityPrompt)
	if thief == victim or not limiter:allow(thief) or not PromptGuard.held(prompt, thief) then
		return
	end
	if RunState.phase ~= "Quota" or not RosterService.isActive(thief) or not RosterService.isActive(victim) then
		return
	end
	if JailService.isJailed(thief) or JailService.isJailed(victim) then
		return
	end
	local victimRoot = CharacterUtil.getRoot(victim)
	if not victimRoot or CharacterUtil.distanceTo(thief, victimRoot.Position) > settings.RangeStuds + RANGE_SLACK then
		return
	end
	local sinceQuotaStart = Timing.now() - RunState.quotaStartedAt
	if RunState.quotaIndex == 1 and sinceQuotaStart < settings.GraceSeconds then
		local wait = math.ceil(settings.GraceSeconds - sinceQuotaStart)
		Notifier.send(thief, `Too early to steal. Give it {wait}s.`, "Info")
		return
	end
	local last = lastSteal[thief]
	if last and os.clock() - last < settings.CooldownSeconds then
		local wait = math.ceil(settings.CooldownSeconds - (os.clock() - last))
		Notifier.send(thief, `Lie low for {wait}s before stealing again.`, "Info")
		return
	end
	local victimCarried = EconomyService.account(victim).carried
	if victimCarried <= 0 then
		Notifier.send(thief, `{victim.DisplayName}'s pockets are empty.`, "Info")
		return
	end

	local amount =
		math.min(math.floor(victimCarried * settings.Percent), math.floor(RunState.target * settings.CapPercentOfQuota))
	local moved = EconomyService.transferCarried(victim, thief, amount, "steal")
	if moved <= 0 then
		Notifier.send(thief, "Your bag is full. Deposit first!", "Info")
		return
	end
	lastSteal[thief] = os.clock()
	stolenTotals[thief.UserId] = (stolenTotals[thief.UserId] or 0) + moved
	HeatService.add(thief, Config.Heat.Steal)
	for _, other in Players:GetPlayers() do
		if other ~= thief and other ~= victim then
			Notifier.send(other, `{thief.DisplayName} stole {Format.money(moved)} from {victim.DisplayName}!`, "Bad")
		end
	end
	Juice.paid(thief, moved, `Stole from {victim.DisplayName}`)
	Juice.sound(thief, "Swipe")
	Juice.lost(victim, moved, `Stolen by {thief.DisplayName}`)
	Juice.sound(victim, "Whistle")
	StealService.changed:Fire(thief.UserId)
end

local function addPrompt(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = settings.HoldSeconds
	prompt.MaxActivationDistance = settings.RangeStuds
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NotFor", player.UserId) -- PromptController hides it on your own character
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(thief: Player)
		onSteal(thief, player, prompt)
	end)
	prompt.Parent = root
end

function StealService.start()
	local function watch(player: Player)
		if player.Character then
			task.spawn(addPrompt, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character: Model)
			addPrompt(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSteal[player] = nil
	end)
end

return StealService
