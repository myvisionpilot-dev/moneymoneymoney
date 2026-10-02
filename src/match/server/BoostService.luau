--!strict
-- Five-minute boosts from the convenience stores. Other services ask how a boost changes
-- things (heat, the pickpocket zone, break-ins); the energy drink also shows on the character
-- as the SpeedBoost attribute (read by shared/Movement) and widens MovementGuard's limit.
-- The police scanner is drawn on the player's own screen from the snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local MovementGuard = require(script.Parent.MovementGuard)

local SPEED_ATTRIBUTE = "SpeedBoost"
local TICK_SECONDS = 1

local settings = Config.Boosts

local BoostService = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

local active: { [Player]: { [string]: number } } = {} -- BoostId -> when it wears off

function BoostService.isActive(player: Player, id: Types.BoostId): boolean
	local list = active[player]
	local endsAt = list and list[id]
	return endsAt ~= nil and endsAt > Timing.now()
end

-- For the snapshot: every active boost and when it wears off.
function BoostService.list(player: Player): { [string]: number }
	local copy: { [string]: number } = {}
	local list = active[player]
	if list then
		for id, endsAt in list do
			copy[id] = endsAt
		end
	end
	return copy
end

function BoostService.speedMultiplier(player: Player): number
	return if BoostService.isActive(player, "Energy") then settings.Energy.speed else 1
end

function BoostService.heatMultiplier(player: Player): number
	return if BoostService.isActive(player, "Disguise") then settings.Disguise.heat else 1
end

function BoostService.zoneMultiplier(player: Player): number
	return if BoostService.isActive(player, "Candy") then settings.Candy.zone else 1
end

function BoostService.breakInMultiplier(player: Player): number
	return if BoostService.isActive(player, "Gloves") then settings.Gloves.breakIn else 1
end

local function applySpeed(player: Player)
	local multiplier = BoostService.speedMultiplier(player)
	local character = player.Character
	if character then
		character:SetAttribute(SPEED_ATTRIBUTE, if multiplier ~= 1 then multiplier else nil)
	end
	MovementGuard.setBoost(player, multiplier)
end

-- Starts a boost, or restarts its clock if it's already going.
function BoostService.give(player: Player, id: Types.BoostId)
	local list = active[player]
	if not list then
		list = {}
		active[player] = list
	end
	list[id] = Timing.now() + settings.Seconds
	if id == "Energy" then
		applySpeed(player)
	end
	BoostService.changed:Fire(player)
end

local function expire()
	local now = Timing.now()
	for player, list in active do
		local ended = false
		for id, endsAt in list do
			if endsAt <= now then
				list[id] = nil
				ended = true
				if id == "Energy" then
					applySpeed(player)
				end
			end
		end
		if ended then
			BoostService.changed:Fire(player)
		end
	end
end

function BoostService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			applySpeed(player) -- a new character needs the attribute again
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		active[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			expire()
		end
	end)
end

return BoostService
