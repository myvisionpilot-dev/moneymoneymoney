--!strict
-- Moments everyone nearby should see happen to a player: cash bursting out of them when they're
-- paid, their bank burst at the counter, a pillar of light when they level up, a flash when
-- they're busted. Sent to every screen; client/WorldFxController draws the ones close enough.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local remotes = Remotes.match()

local WorldFx = {}

local function send(player: Player, kind: Types.FxKind, extra: { amount: number?, level: number?, burst: string? }?)
	local root = CharacterUtil.getRoot(player)
	if not root then
		return
	end
	remotes.Fx:fireAll({
		kind = kind,
		player = player,
		at = root.Position,
		amount = extra and extra.amount,
		level = extra and extra.level,
		burst = extra and extra.burst,
	})
end

function WorldFx.payout(player: Player, amount: number)
	send(player, "Payout", { amount = amount })
end

-- `burst`: their bank burst cosmetic id, if they wear one.
function WorldFx.deposit(player: Player, amount: number, burst: string?)
	send(player, "Deposit", { amount = amount, burst = burst })
end

function WorldFx.levelUp(player: Player, level: number)
	send(player, "LevelUp", { level = level })
end

function WorldFx.busted(player: Player)
	send(player, "Busted")
end

return WorldFx
