--!strict
-- Pure quota maths: targets, player-count scaling, endless growth, carry-over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local QuotaMath = {}

-- Quota for a full 6-player lobby. Endless quotas grow from the last listed one.
function QuotaMath.base(quotaIndex: number): number
	local quotas = Config.Match.Quotas
	if quotaIndex <= #quotas then
		return quotas[quotaIndex]
	end
	return quotas[#quotas] * Config.Match.EndlessQuotaMultiplier ^ (quotaIndex - #quotas)
end

-- Seconds on the clock for a quota; endless quotas get the last listed time.
function QuotaMath.duration(quotaIndex: number): number
	local list = Config.Match.QuotaSeconds
	return list[math.clamp(quotaIndex, 1, #list)]
end

-- Whole minutes left on the clock when a quota was paid (up to Match.EarlyBonus.MaxMinutes).
function QuotaMath.earlyMinutes(secondsLeft: number): number
	return math.clamp(math.floor(secondsLeft / 60), 0, Config.Match.EarlyBonus.MaxMinutes)
end

-- Each player's bonus for paying a quota that many minutes early (shared from the next target).
function QuotaMath.earlyBonus(minutes: number, nextTarget: number, playerCount: number): number
	if minutes <= 0 or playerCount <= 0 then
		return 0
	end
	local share = nextTarget * Config.Match.EarlyBonus.PercentPerMinute * minutes / playerCount
	return math.floor(share / 10 + 0.5) * 10
end

-- Pay multiplier at a quota (pay stops rising after Economy.MaxPayoutTier).
function QuotaMath.tierMultiplier(quotaIndex: number): number
	local tier = math.clamp(quotaIndex, 1, Config.Economy.MaxPayoutTier)
	return Config.Economy.TierPayoutMultiplier ^ (tier - 1)
end

function QuotaMath.scale(playerCount: number): number
	local scales = Config.Match.PlayerCountScale
	return scales[math.clamp(playerCount, 1, #scales)]
end

function QuotaMath.target(quotaIndex: number, playerCount: number): number
	return math.floor(QuotaMath.base(quotaIndex) * QuotaMath.scale(playerCount) + 0.5)
end

-- Cred added to each player's prize pool when this quota is cleared.
function QuotaMath.cred(quotaIndex: number): number
	local list = Config.Prizes.CredPerPlayerPerQuota
	if quotaIndex <= #list then
		return list[quotaIndex]
	end
	return math.floor(list[#list] * Config.Match.EndlessQuotaMultiplier ^ (quotaIndex - #list) + 0.5)
end

function QuotaMath.carry(progress: number, target: number): number
	if not Config.Match.CarryOverExcess then
		return 0
	end
	return math.max(0, progress - target)
end

return QuotaMath
