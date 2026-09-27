--!strict
-- Pickpocketing: hold E on a pedestrian for a little cash and a little heat.
-- Each pedestrian can't be picked again for Pickpocket.CooldownSeconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local NpcService = require(script.Parent.Parent.NpcService)
local PromptGuard = require(script.Parent.Parent.PromptGuard)

local RANGE_SLACK = 3

local settings = Config.Paths.Pickpocket
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("Pickpocket used before init")
	end
	return current
end

local function payout(_player: Player, _tier: number): number
	return math.floor(settings.Pay * getContext().payMultiplier() + 0.5)
end

local function pick(player: Player, pedestrian: Model, prompt: ProximityPrompt): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "Pickpocketing opens when a quota starts."
	end
	if not ctx.canWork(player) or not PromptGuard.held(prompt, player) or not prompt.Enabled then
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
		return false, "Your bag is full. Deposit at Tony's first!"
	end

	prompt.Enabled = false
	task.delay(settings.CooldownSeconds, function()
		if prompt.Parent then
			prompt.Enabled = true
		end
	end)
	local pay = payout(player, ctx.tier())
	local added = EconomyService.addCarried(player, pay, "pickpocket")
	HeatService.add(player, Config.Heat.Pickpocket)
	Notifier.send(player, `Pickpocketed {pedestrian.Name}! +{Format.money(added)}`, "Good")
	return true, nil
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
		if not limiter:allow(player) then
			return
		end
		local ok, message = pick(player, pedestrian, prompt)
		if not ok and message then
			Notifier.send(player, message, "Info")
		end
	end)
	prompt.Parent = root
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, pedestrian in NpcService.pedestrians() do
		setupPedestrian(pedestrian)
	end
	NpcService.pedestrianAdded:Connect(setupPedestrian)
end

local function start(_player: Player, _source: Instance?): (boolean, string?)
	return false, "Hold E on a pedestrian."
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function noJob(_player: Player): boolean
	return false
end

local Pickpocket: MoneyPath.MoneyPath = {
	id = "Pickpocket",
	displayName = "Pickpocketing",
	unlockQuota = Config.Paths.Unlocks.Pickpocket,
	legal = false,
	init = init,
	start = start,
	complete = complete,
	fail = function(_player: Player, _reason: string) end,
	payout = payout,
	hasJob = noJob,
	cancelAll = function(_reason: string) end,
}

return Pickpocket
