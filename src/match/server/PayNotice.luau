--!strict
-- Pays a job into the bag, the same way for every money path: the player's hustles on top
-- (Smooth Talker or Sticky Fingers, Lucky Break), their streak and run level, a money line
-- ("+$1,500 | Package delivered"), cash bursting out of them for everyone nearby to see, and a
-- BAG FULL line when some or all of it didn't fit. `earned` tells the hustle-off and the
-- end-of-run awards. The pay-boost town events (EventBoosts) are on top: GOLDEN HOUR doubles
-- legal pay, and in a TIP FRENZY customers add a tip of their own. So do the game passes: 2x
-- Cash doubles it all, and with the Tip Jar every tipping customer tips too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Passes = require(ServerScriptService.Common.Passes)
local Perks = require(ServerScriptService.Common.Perks)
local EconomyService = require(script.Parent.EconomyService)
local HustleService = require(script.Parent.HustleService)
local EventBoosts = require(script.Parent.EventBoosts)
local Gestures = require(script.Parent.Gestures)
local Juice = require(script.Parent.Juice)
local LevelService = require(script.Parent.LevelService)
local StreakService = require(script.Parent.StreakService)
local WorldFx = require(script.Parent.WorldFx)

local PayNotice = {
	earned = Signal.new() :: Signal.Signal<Player, number>, -- (player, what went into the bag)
}

-- Customers who tip in a TIP FRENZY (by the pay's reason).
local TIPPERS: { [string]: boolean } = {
	["burger order"] = true,
	["taxi fare"] = true,
	["car wash"] = true,
	["hot dog"] = true,
	["delivery"] = true,
	["vip fare"] = true,
	["phone gig"] = true,
}

export type Options = {
	streak: boolean?, -- false: neither extends nor gets the streak (loose cash off the ground)
	payoutXp: boolean?, -- false: XP for the dollars only, not the flat XP every payout gives
}

-- Returns what actually went into the bag.
function PayNotice.earn(
	player: Player,
	amount: number,
	label: string,
	reason: string,
	legal: boolean,
	options: Options?
): number
	-- Hustles, the Cred shop's Silver Tongue (honest work) or Smooth Operator (crimes), then the
	-- streak this payout extends, the run level and any pay boost.
	local perk = Perks.amount(player, if legal then "SilverTongue" else "SmoothOperator")
	local streak = if options and options.streak == false then 1 else StreakService.hit(player)
	local boost = if legal then EventBoosts.legalPay else 1
	local pass = if Passes.has(player, "DoubleCash") then Config.Store.DoubleCash else 1
	local pay = math.floor(
		amount
				* HustleService.payMultiplier(player, legal)
				* (1 + perk)
				* streak
				* LevelService.payMultiplier(player)
				* boost
				* pass
			+ 0.5
	)
	if boost > 1 then
		label = `{label} x{boost}`
	end
	if HustleService.lucky(player) then
		pay *= 2
		label = `Lucky! {label}`
	end
	local added = EconomyService.addCarried(player, pay, reason)
	Juice.paid(player, added, label, streak)
	if added < pay then
		Juice.bagFull(player, pay - added)
	end
	if added > 0 then
		PayNotice.earned:Fire(player, added)
		WorldFx.payout(player, added)
		-- A little cheer for honest work (not for tips or cash off the ground).
		if legal and not (options and options.streak == false) then
			Gestures.playFor(player, "Cheer")
		end
	end
	LevelService.earned(player, pay, not (options and options.payoutXp == false))
	-- A customer's tip, as its own money line.
	if EventBoosts.tipShare > 0 and TIPPERS[reason] then
		local tip = math.floor(amount * EventBoosts.tipShare + 0.5)
		PayNotice.earn(player, tip, "Big tip!", "tip", true, { streak = false, payoutXp = false })
	end
	if TIPPERS[reason] and Passes.has(player, "TipJar") then
		local tip = math.floor(amount * Config.Store.TipJarShare + 0.5)
		PayNotice.earn(player, tip, "Tip jar", "tip", true, { streak = false, payoutXp = false })
	end
	return added
end

return PayNotice
