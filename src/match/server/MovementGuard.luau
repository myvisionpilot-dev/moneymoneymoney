--!strict
-- Catches impossible speed, teleporting and flying: anyone moving faster than their allowed
-- speed (plus slack) is pulled back to their last good position, and anyone hovering higher
-- than Movement.MaxAirStuds above the ground for a few checks goes back to where they last
-- stood. Server teleports go through MovementGuard.teleport so they don't count as cheating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)

local settings = Config.Movement
local FALLING_SPEED = -20 -- dropping faster than this is a fall, not flying

type Track = {
	position: Vector3,
	at: number,
	strikes: number,
	grounded: Vector3, -- last position with the ground close below
	airChecks: number,
}

local MovementGuard = {}

local tracks: { [Player]: Track } = {}
local speedOverrides: { [Player]: number } = {} -- kart speeds
local graces: { [Player]: { speed: number, untilAt: number } } = {} -- old speed, briefly, after slowing down

-- Sprinting is client-side, so the guard always allows sprint speed.
local function allowedSpeed(player: Player): number
	local speed = speedOverrides[player] or settings.SprintSpeed
	local grace = graces[player]
	if grace then
		if os.clock() < grace.untilAt then
			speed = math.max(speed, grace.speed)
		else
			graces[player] = nil
		end
	end
	return speed
end

-- nil goes back to sprint speed. Slowing down keeps the old limit for two checks, so the
-- last stretch in a kart isn't judged at walking speed.
function MovementGuard.setAllowedSpeed(player: Player, speed: number?)
	local before = allowedSpeed(player)
	if speed then
		speedOverrides[player] = speed
	else
		speedOverrides[player] = nil
	end
	if allowedSpeed(player) < before then
		graces[player] = { speed = before, untilAt = os.clock() + settings.CheckSeconds * 2 }
	end
end

local function newTrack(position: Vector3, at: number): Track
	return { position = position, at = at, strikes = 0, grounded = position, airChecks = 0 }
end

-- Moves a character on purpose (gathering, jail) without tripping the guard.
function MovementGuard.teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cframe)
	tracks[player] = newTrack(cframe.Position, os.clock())
end

local function heightAboveGround(player: Player, root: BasePart): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local result = workspace:Raycast(root.Position, Vector3.new(0, -(settings.MaxAirStuds + 10), 0), params)
	return if result then root.Position.Y - result.Position.Y else math.huge
end

-- True if they've been hovering too high for too long (and pulls them back down).
local function checkFlying(player: Player, root: BasePart, track: Track): boolean
	local height = heightAboveGround(player, root)
	if height <= settings.MaxAirStuds or root.AssemblyLinearVelocity.Y < FALLING_SPEED then
		track.airChecks = 0
		if height <= settings.MaxAirStuds then
			track.grounded = root.Position
		end
		return false
	end
	track.airChecks += 1
	if track.airChecks < settings.MaxAirChecks then
		return false
	end
	local shown = if height == math.huge then `over {settings.MaxAirStuds + 10}` else tostring(math.floor(height))
	warn(`[MovementGuard] {player.Name} hovered {shown} studs up; pulled back down`)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(track.grounded + Vector3.new(0, 3, 0)))
	end
	track.position = track.grounded
	track.airChecks = 0
	return true
end

local function check(player: Player, now: number)
	local root = CharacterUtil.getRoot(player)
	if not root then
		tracks[player] = nil
		return
	end
	local track = tracks[player]
	if not track then
		tracks[player] = newTrack(root.Position, now)
		return
	end
	if checkFlying(player, root, track) then
		track.at = now
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
		graces[player] = nil
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
