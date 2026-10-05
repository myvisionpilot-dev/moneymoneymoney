--!strict
-- Asks one player's client to dress up a moment: a money line ("+$1,500 | Package dropped off")
-- or a sound. Labels are a few words saying what happened. Sounds that everyone nearby should
-- hear (knocks, alarms, sirens) are made in the world with Sounds.at instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local remotes = Remotes.match()

local Juice = {}

local function money(player: Player, kind: Types.JuiceKind, amount: number, label: string?)
	if amount > 0 and player.Parent then
		remotes.Juice:fireClient(player, { kind = kind, amount = amount, label = label })
	end
end

-- Cash into the bag.
function Juice.paid(player: Player, amount: number, label: string)
	money(player, "Paid", amount, label)
end

-- Cash out of the bag for something they chose to buy.
function Juice.spent(player: Player, amount: number, label: string)
	money(player, "Spent", amount, label)
end

-- Cash taken from them (busted, zapped, stolen).
function Juice.lost(player: Player, amount: number, label: string)
	money(player, "Lost", amount, label)
end

function Juice.deposited(player: Player, amount: number)
	money(player, "Deposited", amount, "Deposited at the bank")
end

-- Pay that didn't fit in the bag.
function Juice.bagFull(player: Player, missed: number)
	money(player, "BagFull", missed, nil)
end

function Juice.sound(player: Player, name: string)
	if player.Parent then
		remotes.Juice:fireClient(player, { kind = "Sound", sound = name })
	end
end

return Juice
