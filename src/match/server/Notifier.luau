--!strict
-- Sends pop-up notices to players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local remotes = Remotes.match()

local Notifier = {}

function Notifier.send(player: Player, text: string, kind: Types.NoticeKind)
	if player.Parent then
		remotes.Notify:fireClient(player, { text = text, kind = kind })
	end
end

function Notifier.all(text: string, kind: Types.NoticeKind)
	remotes.Notify:fireAll({ text = text, kind = kind })
end

return Notifier
