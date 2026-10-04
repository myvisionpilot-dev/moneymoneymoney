--!strict
-- Permanent perks from the lobby's speed shop (both places), read from the saved profile. The
-- speed buff shows on your character as the SpeedBuff attribute, which shared/Movement
-- multiplies into on-foot speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Profiles = require(script.Parent.Profiles)

local SPEED_ATTRIBUTE = "SpeedBuff"

local Perks = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

function Perks.level(player: Player, id: Catalog.PerkId): number
	local data = Profiles.get(player)
	local level = if data then data.Perks[id] else nil
	return if typeof(level) == "number" then level else 0
end

function Perks.speedMultiplier(player: Player): number
	return Catalog.speedMultiplier(Perks.level(player, "Speed"))
end

-- Puts the perks on their character (after loading, buying one, or respawning).
function Perks.refresh(player: Player)
	local character = player.Character
	local multiplier = Perks.speedMultiplier(player)
	if character then
		character:SetAttribute(SPEED_ATTRIBUTE, if multiplier ~= 1 then multiplier else nil)
	end
	Perks.changed:Fire(player)
end

function Perks.start()
	Profiles.loaded:Connect(Perks.refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			Perks.refresh(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Perks
