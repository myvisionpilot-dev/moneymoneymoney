--!strict
-- Prize pool per cleared quota, each player's prize by contribution, and the MVP.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local EconomyService = require(script.Parent.EconomyService)
local PrizeMath = require(script.Parent.PrizeMath)
local RosterService = require(script.Parent.RosterService)

local PrizeService = {}

local quotasCleared = 0
local poolPerPlayer = 0
local lockedPrizes: { [number]: number } = {}

local function depositsOf(userId: number): number
	local account = EconomyService.get(userId)
	return if account then account.deposited else 0
end

function PrizeService.quotaCleared(quotaIndex: number)
	quotasCleared = quotaIndex
	poolPerPlayer = PrizeMath.poolPerPlayer(quotaIndex)
end

function PrizeService.highestCleared(): number
	return quotasCleared
end

function PrizeService.poolPerPlayer(): number
	return poolPerPlayer
end

function PrizeService.prizeFor(userId: number, failed: boolean): number
	return PrizeMath.prize(
		poolPerPlayer,
		RosterService.startingCount,
		depositsOf(userId),
		EconomyService.teamDeposited(),
		failed
	)
end

-- Fixes a player's prize when their run ends (cash out, fail or last quota).
function PrizeService.lock(userId: number, failed: boolean): number
	local prize = PrizeService.prizeFor(userId, failed)
	lockedPrizes[userId] = prize
	return prize
end

function PrizeService.lockedPrize(userId: number): number?
	return lockedPrizes[userId]
end

function PrizeService.mvpUserId(): number?
	local best: number? = nil
	local bestDeposits = 0
	for _, member in RosterService.all() do
		local deposits = depositsOf(member.userId)
		if member.status ~= "Left" and deposits > bestDeposits then
			best = member.userId
			bestDeposits = deposits
		end
	end
	return best
end

function PrizeService.rows(): { Types.ResultRow }
	local team = EconomyService.teamDeposited()
	local rows: { Types.ResultRow } = {}
	for _, member in RosterService.all() do
		local deposits = depositsOf(member.userId)
		local prize = 0
		if member.status ~= "Left" then
			prize = lockedPrizes[member.userId] or PrizeService.prizeFor(member.userId, false)
		end
		table.insert(rows, {
			userId = member.userId,
			name = member.name,
			deposited = deposits,
			share = if team > 0 then deposits / team else 0,
			prize = prize,
			status = member.status,
		})
	end
	table.sort(rows, function(a: Types.ResultRow, b: Types.ResultRow): boolean
		return a.deposited > b.deposited
	end)
	return rows
end

return PrizeService
