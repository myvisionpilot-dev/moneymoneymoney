--!strict
-- Pure prize maths.
-- prize = poolPerPlayer × startingPlayers × (playerDeposits ÷ teamDeposits), rounded down to whole Cred.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local QuotaMath = require(script.Parent.QuotaMath)

local EPSILON = 1e-6 -- guards floor() against float error like 764.9999999

local PrizeMath = {}

function PrizeMath.poolPerPlayer(quotasCleared: number): number
	local total = 0
	for quotaIndex = 1, quotasCleared do
		total += QuotaMath.cred(quotaIndex)
	end
	return total
end

function PrizeMath.failKeep(prize: number): number
	return math.floor(prize * Config.Match.FailKeepPercent + EPSILON)
end

function PrizeMath.prize(
	poolPerPlayer: number,
	startingPlayers: number,
	playerDeposits: number,
	teamDeposits: number,
	failed: boolean
): number
	if poolPerPlayer <= 0 or startingPlayers <= 0 then
		return 0
	end
	local raw
	if teamDeposits <= 0 then
		raw = poolPerPlayer -- nobody deposited (e.g. /skip): even split
	else
		raw = poolPerPlayer * startingPlayers * playerDeposits / teamDeposits
	end
	local prize = math.floor(raw + EPSILON)
	if failed then
		return PrizeMath.failKeep(prize)
	end
	return prize
end

return PrizeMath
