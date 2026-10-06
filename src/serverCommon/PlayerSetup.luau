--!strict
-- Every player, in both places: the normal zoomable camera, Movement.WalkSpeed and no
-- nametag over their head. Sprinting is handled on the client (shared/Movement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerSetup = {}

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function setupPlayer(player: Player)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = Config.Camera.MinZoom
	player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	player.DevEnableMouseLock = false -- Shift is sprint, not shift-lock
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

function PlayerSetup.start()
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
	Players.PlayerAdded:Connect(setupPlayer)
end

return PlayerSetup
