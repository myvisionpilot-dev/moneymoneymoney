-- Unit checks for QuotaMath and PrizeMath. Run in the Match place in Edit mode
-- (Studio command bar or the MCP); prints PASS/FAIL per case.

local QuotaMath = require(game.ServerScriptService.Server.QuotaMath)
local PrizeMath = require(game.ServerScriptService.Server.PrizeMath)

local failures = 0
local function check(label, got, want)
	local ok = got == want
	if not ok then
		failures += 1
	end
	print((if ok then "PASS " else "FAIL ") .. `{label}: got {got}` .. (if ok then "" else ` want {want}`))
end

-- Quota targets (base × PlayerCountScale), endless ×1.6
check("q1 x1", QuotaMath.target(1, 1), 17500)
check("q1 x3", QuotaMath.target(1, 3), 35000)
check("q2 x2", QuotaMath.target(2, 2), 82500)
check("q5 x6", QuotaMath.target(5, 6), 1000000)
check("q6 x6 endless", QuotaMath.target(6, 6), 1600000)
check("q7 x6 endless", QuotaMath.target(7, 6), 2560000)
check("q6 x1 endless", QuotaMath.target(6, 1), 560000)

-- Cred per quota and pool
check("cred q6", QuotaMath.cred(6), 2400)
check("pool after 3", PrizeMath.poolPerPlayer(3), 850)
check("pool after 5", PrizeMath.poolPerPlayer(5), 3250)

-- Carry-over
check("carry", QuotaMath.carry(20000, 17500), 2500)

-- The plan's example: 3 players, 60/30/10% after 3 quotas; then failing quota 4 keeps 25%
local pool = PrizeMath.poolPerPlayer(3)
check("A 60%", PrizeMath.prize(pool, 3, 60000, 100000, false), 1530)
check("B 30%", PrizeMath.prize(pool, 3, 30000, 100000, false), 765)
check("C 10%", PrizeMath.prize(pool, 3, 10000, 100000, false), 255)
check("A fail", PrizeMath.prize(pool, 3, 60000, 100000, true), 382)
check("B fail", PrizeMath.prize(pool, 3, 30000, 100000, true), 191)
check("C fail", PrizeMath.prize(pool, 3, 10000, 100000, true), 63)
check("even split = base", PrizeMath.prize(pool, 3, 1, 3, false), 850)
check("no deposits = even", PrizeMath.prize(pool, 3, 0, 0, false), 850)
check("leaver's share not redistributed", PrizeMath.prize(pool, 3, 33333, 99999, false), 850)

print(if failures == 0 then "ALL PASS" else `{failures} FAILURES`)
