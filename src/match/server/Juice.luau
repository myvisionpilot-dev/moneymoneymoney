--!strict
-- Asks one player's client to dress up a moment: a money pop-up or a sound. Sounds that everyone
-- nearby should hear (knocks, alarms, sirens) are made in the world with Sounds.at instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local remotes = Remotes.match()

local Juice = {}

function Juice.paid(player: Player, amount: number)
	if amount > 0 and player.Parent then
		local root = CharacterUtil.getRoot(player)
		remotes.Juice:fireClient(player, { kind = "Paid", amount = amount, position = root and root.Position })
	end
end

function Juice.deposited(player: Player, amount: number)
	if amount > 0 and player.Parent then
		remotes.Juice:fireClient(player, { kind = "Deposited", amount = amount })
	end
end

function Juice.sound(player: Player, name: string)
	if player.Parent then
		remotes.Juice:fireClient(player, { kind = "Sound", sound = name })
	end
end

return Juice
