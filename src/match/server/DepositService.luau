--!strict
-- Deposits at Tony's desk. Only deposited cash counts toward the quota and your contribution.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local Notifier = require(script.Parent.Notifier)
local QuotaRunService = require(script.Parent.QuotaRunService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local DESK_TAG = "TonyDesk"
local RANGE_SLACK = 3 -- studs, for network lag

local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

local DepositService = {}

local function onDeposit(player: Player, desk: BasePart)
	if not limiter:allow(player) or not RosterService.isActive(player) then
		return
	end
	if RunState.phase ~= "Quota" then
		Notifier.send(player, "Tony only takes deposits during a quota.", "Info")
		return
	end
	if CharacterUtil.distanceTo(player, desk.Position) > Config.Economy.DepositRangeStuds + RANGE_SLACK then
		return
	end
	local amount = EconomyService.depositAll(player, "deposit at Tony's")
	if amount <= 0 then
		Notifier.send(player, "Your bag is empty. Go make some money!", "Info")
		return
	end
	QuotaRunService.addProgress(amount)
	Notifier.send(player, `Deposited {Format.money(amount)}`, "Good")
end

local function setupDesk(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local desk: BasePart = instance
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = "Deposit cash"
	prompt.ObjectText = "Tony"
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
