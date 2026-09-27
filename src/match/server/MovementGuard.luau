--!strict
-- Catches impossible speed or teleporting: anyone moving faster than their allowed speed
-- (plus slack) is pulled back to their last good position. Server teleports go through
-- MovementGuard.teleport so they don't count as cheating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)

local settings = Config.Movement

type Track = {
	position: Vector3,
	at: number,
	strikes: number,
}

local MovementGuard = {}

local tracks: { [Player]: Track } = {}
local speedOverrides: { [Player]: number } = {} -- e.g. ride speed in Part B

-- Sprinting is client-side, so the guard always allows sprint speed.
local function allowedSpeed(player: Player): number
	return speedOverrides[player] or settings.SprintSpeed
end

-- nil goes back to sprint speed.
function MovementGuard.setAllowedSpeed(player: Player, speed: number?)
	if speed then
		speedOverrides[player] = speed
	else
		speedOverrides[player] = nil
	end
end

-- Moves a character on purpose (gathering, jail) without tripping the guard.
function MovementGuard.teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cframe)
	tracks[player] = { position = cframe.Position, at = os.clock(), strikes = 0 }
end

local function check(player: Player, now: number)
	local root = CharacterUtil.getRoot(player)
	if not root then
		tracks[player] = nil
		return
	end
	local track = tracks[player]
	if not track then
		tracks[player] = { position = root.Position, at = now, strikes = 0 }
		return
	end
	local elapsed = now - track.at
	local offset = root.Position - track.position
	local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local limit = allowedSpeed(player) * (1 + settings.SlackPercent) * elapsed + settings.LagAllowanceStuds
	if horizontal > limit then
		track.strikes += 1
		local moved, took, allowed = math.floor(horizontal), string.format("%.2f", elapsed), math.floor(limit)
		warn(`[MovementGuard] {player.Name} moved {moved} studs in {took}s (limit {allowed}); pulled back`)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(track.position + Vector3.new(0, 3, 0)))
		end
		track.at = now
		return
	end
	track.position = root.Position
	track.at = now
end

function MovementGuard.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		tracks[player] = nil
		speedOverrides[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			tracks[player] = nil -- a fresh spawn is a legit jump
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			tracks[player] = nil
		end)
	end

	task.spawn(function()
		while true do
			task.wait(settings.CheckSeconds)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				check(player, now)
			end
		end
	end)
end

return MovementGuard
