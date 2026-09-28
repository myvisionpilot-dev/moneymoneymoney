--!strict
-- The pay-out pop-up every money path uses, including when the bag was (nearly) full.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Notifier = require(script.Parent.Notifier)

local PayNotice = {}

-- `pay` is what the job was worth; `added` is what actually fit in the bag.
function PayNotice.send(player: Player, headline: string, added: number, pay: number)
	if added >= pay then
		Notifier.send(player, `{headline} +{Format.money(added)}`, "Good")
	elseif added > 0 then
		Notifier.send(player, `{headline} Only {Format.money(added)} fit in your bag. Deposit at Tony's!`, "Bad")
	else
		Notifier.send(player, `{headline} But your bag was full, so you got nothing. Deposit at Tony's!`, "Bad")
	end
end

return PayNotice
