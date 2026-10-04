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
local boosts: { [Player]: number } = {} -- energy drink and speed buff: on foot only
local graces: { [Player]: { speed: number, untilAt: number } } = {} -- old speed, briefly, after slowing down

-- Sprinting is client-side, so the guard always allows sprint speed.
local function allowedSpeed(player: Player): number
	local speed = speedOverrides[player] or settings.SprintSpeed * (boosts[player] or 1)
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

-- The energy drink and speed buff multiply on-foot speed (1 = none). Wearing off keeps the old
-- limit briefly.
function MovementGuard.setBoost(player: Player, multiplier: number)
	local before = allowedSpeed(player)
	if multiplier ~= 1 then
		boosts[player] = multiplier
	else
		boosts[player] = nil
	end
	if allowedSpeed(player) < before then
		graces[player] = { speed = before, untilAt = os.clock() + settings.CheckSeconds * 2 }
	end
end

local function newTrack(position: Vector3, at: number): Track
	return { position = position, at = at, strikes = 0, grounded = position, airChecks = 0 }
end

-- The physics car they're sitting in, if any (CarBuilder marks it PhysicsCar).
local function carOf(character: Model): Model?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local car = seat and seat:FindFirstAncestorOfClass("Model")
	return if car and car:GetAttribute("PhysicsCar") then car else nil
end

-- Puts someone back at `position` (where their root part was): the whole car if they're driving.
local function pullBack(character: Model, position: Vector3)
	local car = carOf(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if car and root and root:IsA("BasePart") then
		local pivot = car:GetPivot()
		car:PivotTo(CFrame.new(position + (pivot.Position - root.Position) + Vector3.new(0, 1, 0)) * pivot.Rotation)
		for _, part in car:GetDescendants() do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
	else
		character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end
end

-- Moves a character on purpose (gathering, jail) without tripping the guard. Anyone in a car
-- gets out first (VehicleService puts the car away when its seat empties).
function MovementGuard.teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local car = carOf(character)
	local seat = car and car:FindFirstChild("DriverSeat")
	local seatWeld = seat and seat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
		-- The driver's computer was still moving them with the car; move them again once it
		-- knows they're out.
		task.delay(0.2, function()
			if character.Parent then
				character:PivotTo(cframe)
				tracks[player] = newTrack(cframe.Position, os.clock())
			end
		end)
	end
	character:PivotTo(cframe)
	tracks[player] = newTrack(cframe.Position, os.clock())
end

-- Forget their last position (they were just moved on purpose, e.g. sat in a car).
function MovementGuard.reset(player: Player)
	tracks[player] = nil
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
		pullBack(character, track.grounded)
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
			pullBack(character, track.position)
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
		boosts[player] = nil
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
