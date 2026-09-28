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

-- Seconds on the clock for a quota: each one gets a little longer than the last.
function QuotaMath.duration(quotaIndex: number): number
	return Config.Match.QuotaBaseSeconds + Config.Match.QuotaExtraSecondsPerQuota * (quotaIndex - 1)
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
