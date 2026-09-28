--!strict
-- Things players did during the run (a delivery, a race win, losing the police...), for daily
-- challenges and badges. Money paths call Stats.record; RewardService listens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Stats = {
	-- (player, stat, amount): counts add up, except "QuotaCleared" whose amount is the quota number
	recorded = Signal.new() :: Signal.Signal<Player, string, number>,
}

function Stats.record(player: Player, stat: string, amount: number?)
	Stats.recorded:Fire(player, stat, amount or 1)
end

return Stats
