--!strict
-- Lying down (C: client/ProneController). The Prone attribute on your character is what everyone
-- reads: every screen lays you flat (client/PoseController) and you crawl (shared/Movement).
-- Not in a car; getting into one, or a new character, stands you up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)

local PRONE_ATTRIBUTE = "Prone"
local VEHICLE_ATTRIBUTE = "VehicleSpeed"

local limiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local Prone = {}

function Prone.isProne(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(PRONE_ATTRIBUTE) == true
end

function Prone.stand(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute(PRONE_ATTRIBUTE, nil)
	end
end

function Prone.start()
	Remotes.match().SetProne:onServer(function(player: Player, payload: unknown)
		local character = player.Character
		if not limiter:allow(player) or typeof(payload) ~= "boolean" or not character then
			return
		end
		local down = payload and character:GetAttribute(VEHICLE_ATTRIBUTE) == nil
		character:SetAttribute(PRONE_ATTRIBUTE, if down then true else nil)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:GetAttributeChangedSignal(VEHICLE_ATTRIBUTE):Connect(function()
				if character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil then
					character:SetAttribute(PRONE_ATTRIBUTE, nil)
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Prone
