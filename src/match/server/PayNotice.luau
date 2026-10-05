--!strict
-- The pay-out every money path uses: a money line ("+$1,500 | Package dropped off"), plus a
-- BAG FULL line when some or all of it didn't fit.

local Juice = require(script.Parent.Juice)

local PayNotice = {}

-- `pay` is what the job was worth; `added` is what actually fit in the bag.
function PayNotice.send(player: Player, label: string, added: number, pay: number)
	Juice.paid(player, added, label)
	if added < pay then
		Juice.bagFull(player, pay - added)
	end
end

return PayNotice
