--!strict
-- Pays a job into the bag, the same way for every money path: the player's hustles on top
-- (Smooth Talker or Sticky Fingers, Lucky Break), their streak and run level, a money line
-- ("+$1,500 | Package delivered"), cash bursting out of them for everyone nearby to see, and a
-- BAG FULL line when some or all of it didn't fit. `earned` tells the hustle-off and the
-- end-of-run awards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Perks = require(ServerScriptService.Common.Perks)
local EconomyService = require(script.Parent.EconomyService)
local HustleService = require(script.Parent.HustleService)
local Juice = require(script.Parent.Juice)
local LevelService = require(script.Parent.LevelService)
local StreakService = require(script.Parent.StreakService)
local WorldFx = require(script.Parent.WorldFx)

local PayNotice = {
	earned = Signal.new() :: Signal.Signal<Player, number>, -- (player, what went into the bag)
}

-- Returns what actually went into the bag.
function PayNotice.earn(player: Player, amount: number, label: string, reason: string, legal: boolean): number
	-- Hustles, the Cred shop's Silver Tongue (honest work) or Smooth Operator (crimes), then the
	-- streak this payout extends and the run level.
	local perk = Perks.amount(player, if legal then "SilverTongue" else "SmoothOperator")
	local streak = StreakService.hit(player)
	local pay = math.floor(
		amount * HustleService.payMultiplier(player, legal) * (1 + perk) * streak * LevelService.payMultiplier(player)
			+ 0.5
	)
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
	end
	LevelService.earned(player, pay)
	return added
end

return PayNotice
