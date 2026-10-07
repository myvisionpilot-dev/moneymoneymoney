--!strict
-- Asks one player's client to dress up a moment: a money line ("+$1,500 | Package dropped off"),
-- a level-up or a sound. Labels are a few words saying what happened. Sounds that everyone
-- nearby should hear (knocks, alarms, sirens) are made in the world with Sounds.at instead, and
-- effects everyone nearby should see go through WorldFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local remotes = Remotes.match()

local Juice = {}

local function money(player: Player, kind: Types.JuiceKind, amount: number, label: string?, streak: number?)
	if amount > 0 and player.Parent then
		remotes.Juice:fireClient(player, { kind = kind, amount = amount, label = label, streak = streak })
	end
end

-- Cash into the bag. `streak`: the streak multiplier it was paid at, when it's a job.
function Juice.paid(player: Player, amount: number, label: string, streak: number?)
	money(player, "Paid", amount, label, streak)
end

-- Cash out of the bag for something they chose to buy.
function Juice.spent(player: Player, amount: number, label: string)
	money(player, "Spent", amount, label)
end

-- Cash taken from them (busted, zapped, stolen).
function Juice.lost(player: Player, amount: number, label: string)
	money(player, "Lost", amount, label)
end

function Juice.deposited(player: Player, amount: number, label: string?)
	money(player, "Deposited", amount, label or "Deposited at the bank")
end

-- Pay that didn't fit in the bag.
function Juice.bagFull(player: Player, missed: number)
	money(player, "BagFull", missed, nil)
end

-- A new run level, and any Cred it gave.
function Juice.levelUp(player: Player, level: number, cred: number)
	if player.Parent then
		remotes.Juice:fireClient(player, { kind = "LevelUp", level = level, amount = cred })
	end
end

function Juice.sound(player: Player, name: string)
	if player.Parent then
		remotes.Juice:fireClient(player, { kind = "Sound", sound = name })
	end
end

return Juice
