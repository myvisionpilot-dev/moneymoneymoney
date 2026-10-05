--!strict
-- Pays a job into the bag, the same way for every money path: the player's hustles on top
-- (Smooth Talker or Sticky Fingers, Lucky Break), a money line ("+$1,500 | Package
-- delivered"), and a BAG FULL line when some or all of it didn't fit.

local EconomyService = require(script.Parent.EconomyService)
local HustleService = require(script.Parent.HustleService)
local Juice = require(script.Parent.Juice)

local PayNotice = {}

-- Returns what actually went into the bag.
function PayNotice.earn(player: Player, amount: number, label: string, reason: string, legal: boolean): number
	local pay = math.floor(amount * HustleService.payMultiplier(player, legal) + 0.5)
	if HustleService.lucky(player) then
		pay *= 2
		label = `Lucky! {label}`
	end
	local added = EconomyService.addCarried(player, pay, reason)
	Juice.paid(player, added, label)
	if added < pay then
		Juice.bagFull(player, pay - added)
	end
	return added
end

return PayNotice
