--!strict
-- Deposits at the bank counter. Only deposited cash counts toward the quota and your contribution.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local HappyHour = require(script.Parent.Events.HappyHour)
local HustleService = require(script.Parent.HustleService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local QuotaRunService = require(script.Parent.QuotaRunService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local TeamCombo = require(script.Parent.TeamCombo)

local DESK_TAG = "BankCounter"
local DESK_ATTRIBUTE = "BankCounterPosition" -- on ReplicatedStorage, for guides when the desk isn't streamed in
local RANGE_SLACK = 3 -- studs, for network lag

local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local DepositService = {}

local function onDeposit(player: Player, desk: BasePart)
	if not limiter:allow(player) or not RosterService.isActive(player) then
		return
	end
	if RunState.phase ~= "Quota" then
		Notifier.send(player, "The bank only takes deposits during a quota.", "Info")
		return
	end
	if CharacterUtil.distanceTo(player, desk.Position) > Config.Economy.DepositRangeStuds + RANGE_SLACK then
		return
	end
	local amount = EconomyService.depositAll(player, "deposit at the bank")
	if amount <= 0 then
		Notifier.send(player, "Your bag is empty. Go make some money!", "Info")
		return
	end
	-- The Interest hustle, happy hour and a team combo count extra toward the quota (not toward
	-- anyone's share of the prize).
	local interest = math.floor(amount * HustleService.depositBonus(player) + 0.5)
	local happy = math.floor(amount * HappyHour.bonus() + 0.5)
	Juice.deposited(player, amount)
	local combo = TeamCombo.deposited(player, amount)
	QuotaRunService.addProgress(amount + interest + happy + combo)
	if interest > 0 then
		Juice.deposited(player, interest, "Interest from the bank")
	end
	if happy > 0 then
		Juice.deposited(player, happy, "Happy hour bonus")
	end
end

local function setupDesk(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local desk: BasePart = instance
	ReplicatedStorage:SetAttribute(DESK_ATTRIBUTE, desk.Position)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = "Deposit cash"
	prompt.ObjectText = "Mr. Penny"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = Config.Economy.DepositRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk
	prompt.Triggered:Connect(function(player: Player)
		onDeposit(player, desk)
	end)
end

function DepositService.start()
	for _, instance in CollectionService:GetTagged(DESK_TAG) do
		setupDesk(instance)
	end
	CollectionService:GetInstanceAddedSignal(DESK_TAG):Connect(setupDesk)
end

return DepositService
