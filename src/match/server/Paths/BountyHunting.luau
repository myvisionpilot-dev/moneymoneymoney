--!strict
-- Bounty hunting: from quota Paths.Unlocks.BountyHunting, anyone with BountyHunting.MinStars or
-- more can be arrested by a teammate who has no heat. Hold E on them: they're busted as if by
-- the police, and the police pay the hunter PerStar per star (new money, scaled like other pay).
-- Wanted players wear a WANTED sign so hunters can find them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.Parent.EconomyService)
local HeatService = require(script.Parent.Parent.HeatService)
local JailService = require(script.Parent.Parent.JailService)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local RosterService = require(script.Parent.Parent.RosterService)

local RANGE_SLACK = 3
local REFRESH_SECONDS = 0.5

type Mark = {
	character: Model,
	prompt: ProximityPrompt,
	label: TextLabel,
	sign: BillboardGui,
}

local settings = Config.Paths.BountyHunting
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local marks: { [Player]: Mark } = {}
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("BountyHunting used before init")
	end
	return current
end

-- Reward per star at the current quota.
local function payout(_player: Player, _tier: number): number
	return math.floor(settings.PerStar * getContext().payMultiplier() + 0.5)
end

-- What a teammate earns for arresting this player right now (0 = they can't be arrested).
local function bountyFor(player: Player): number
	local ctx = context
	if not ctx or not ctx.isOpen() or not RosterService.isActive(player) or JailService.isJailed(player) then
		return 0
	end
	local stars = HeatService.stars(player)
	if stars < settings.MinStars then
		return 0
	end
	return stars * payout(player, ctx.tier())
end

local function arrest(hunter: Player, target: Player, prompt: ProximityPrompt)
	if hunter == target or not limiter:allow(hunter) or not PromptGuard.held(prompt, hunter) then
		return
	end
	local ctx = getContext()
	if not ctx.isOpen() or not ctx.canWork(hunter) then
		return
	end
	if HeatService.get(hunter) > 0 then
		Notifier.send(hunter, "Only players with no heat can claim a bounty. Lie low first.", "Info")
		return
	end
	local bounty = bountyFor(target)
	local targetRoot = CharacterUtil.getRoot(target)
	if bounty <= 0 or not targetRoot then
		return
	end
	if CharacterUtil.distanceTo(hunter, targetRoot.Position) > settings.RangeStuds + RANGE_SLACK then
		return
	end

	JailService.arrest(target, hunter.DisplayName)
	local added = EconomyService.addCarried(hunter, bounty, `bounty on {target.Name}`)
	PayNotice.send(hunter, `You arrested {target.DisplayName}! The police paid the bounty.`, added, bounty)
end

local function removeMark(player: Player)
	local mark = marks[player]
	if mark then
		marks[player] = nil
		mark.prompt:Destroy()
		mark.sign:Destroy()
	end
end

local function makeMark(player: Player, character: Model): Mark?
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ArrestPrompt"
	prompt.ActionText = "Arrest"
	prompt.HoldDuration = settings.HoldSeconds
	prompt.MaxActivationDistance = settings.RangeStuds
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NotFor", player.UserId) -- PromptController hides it on your own character
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(hunter: Player)
		arrest(hunter, player, prompt)
	end)
	prompt.Parent = root

	local sign = Instance.new("BillboardGui")
	sign.Name = "WantedSign"
	sign.Size = UDim2.fromOffset(150, 44)
	sign.StudsOffset = Vector3.new(0, 3.2, 0)
	sign.MaxDistance = 250
	sign.LightInfluence = 0
	sign.PlayerToHideFrom = player
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(225, 75, 65)
	label.TextStrokeTransparency = 0.2
	label.Parent = sign
	sign.Parent = head

	return { character = character, prompt = prompt, label = label, sign = sign }
end

local function refresh()
	for _, player in Players:GetPlayers() do
		local bounty = bountyFor(player)
		local character = player.Character
		local mark: Mark? = marks[player]
		if bounty <= 0 or not character then
			removeMark(player)
		else
			if mark and (mark.character ~= character or not mark.prompt.Parent) then
				removeMark(player)
				mark = nil
			end
			if not mark then
				mark = makeMark(player, character)
				if mark then
					marks[player] = mark
				end
			end
			if mark then
				local stars = string.rep("★", HeatService.stars(player))
				mark.label.Text = `WANTED {stars}\n{Format.money(bounty)} bounty`
				mark.prompt.ObjectText = `{player.DisplayName} ({Format.money(bounty)} bounty)`
			end
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	Players.PlayerRemoving:Connect(removeMark)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

local function start(_player: Player, _source: Instance?): (boolean, string?)
	return false, "Hold E on a wanted player to arrest them."
end

local function complete(_player: Player): (boolean, string?)
	return false, nil
end

local function noJob(_player: Player): boolean
	return false
end

local path: MoneyPath.MoneyPath = {
	id = "BountyHunting",
	displayName = "Bounty hunting",
	unlockQuota = Config.Paths.Unlocks.BountyHunting,
	legal = true,
	init = init,
	start = start,
	complete = complete,
	fail = function(_player: Player, _reason: string) end,
	payout = payout,
	hasJob = noJob,
	cancelAll = function(_reason: string) end, -- marks come off on the next refresh
}

return {
	path = path,
	bountyFor = bountyFor,
}
