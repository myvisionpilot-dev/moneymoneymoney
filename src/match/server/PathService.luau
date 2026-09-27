--!strict
-- Registers money paths, opens them as their quota unlocks, and cancels jobs between quotas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local MoneyPath = require(script.Parent.Paths.MoneyPath)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)

local PathService = {}

local paths: { MoneyPath.MoneyPath } = {}
local open = false
local quotaIndex = 0

local function contextFor(path: MoneyPath.MoneyPath): MoneyPath.Context
	return {
		isOpen = function(): boolean
			return open and quotaIndex >= path.unlockQuota
		end,
		tier = function(): number
			return math.clamp(quotaIndex, 1, Config.Economy.MaxPayoutTier)
		end,
		canWork = function(player: Player): boolean
			return RosterService.isActive(player) and CharacterUtil.getRoot(player) ~= nil
		end,
	}
end

function PathService.register(path: MoneyPath.MoneyPath)
	table.insert(paths, path)
end

function PathService.openQuota(newQuotaIndex: number)
	quotaIndex = newQuotaIndex
	open = true
	for _, path in paths do
		if path.unlockQuota == newQuotaIndex and newQuotaIndex > 1 then
			Notifier.all(`New money path unlocked: {path.displayName}!`, "Good")
		end
	end
end

function PathService.closeQuota(reason: string)
	open = false
	for _, path in paths do
		path.cancelAll(reason)
	end
end

function PathService.start()
	for _, path in paths do
		path.init(contextFor(path))
	end
end

return PathService
