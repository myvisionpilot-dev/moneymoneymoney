--!strict
-- TeleportAsync with retries. Studio can't teleport, so there it warns and returns false.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ATTEMPTS = 4
local RETRY_SECONDS = 2
local FLOOD_SECONDS = 15
local MAX_INIT_RETRIES = 3

local SafeTeleport = {}

local initRetries: { [Player]: number } = {}

function SafeTeleport.teleport(placeId: number, players: { Player }, options: TeleportOptions?): boolean
	if RunService:IsStudio() then
		warn(`[SafeTeleport] Studio can't teleport; would send {#players} player(s) to place {placeId}`)
		return false
	end
	for attempt = 1, ATTEMPTS do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, players, options)
		end)
		if ok then
			return true
		end
		warn(`[SafeTeleport] attempt {attempt} failed: {err}`)
		task.wait(RETRY_SECONDS)
	end
	return false
end

TeleportService.TeleportInitFailed:Connect(
	function(player: Player, result: Enum.TeleportResult, message: string, placeId: number, options: TeleportOptions)
		warn(`[SafeTeleport] {player.Name} failed to teleport: {result.Name} {message}`)
		local tries = (initRetries[player] or 0) + 1
		initRetries[player] = tries
		if tries > MAX_INIT_RETRIES then
			return
		end
		task.wait(if result == Enum.TeleportResult.Flooded then FLOOD_SECONDS else RETRY_SECONDS)
		if player.Parent then
			SafeTeleport.teleport(placeId, { player }, options)
		end
	end
)

Players.PlayerRemoving:Connect(function(player: Player)
	initRetries[player] = nil
end)

return SafeTeleport
