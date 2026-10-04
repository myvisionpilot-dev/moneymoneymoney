--!strict
-- Vehicles: your ride (a kart from the garage, hop in or out with SetRiding), race cars lent
-- by the garage (Paths/Racing) and stolen cars (Paths/CarTheft; SetRiding off ditches one).
-- Each is a real physics car (CarBuilder) that you sit in; your own computer drives it
-- (client/CarController). The car's TopSpeed attribute caps it (0 holds it still), the
-- VehicleSpeed attribute on your character tells everything else you're driving, and
-- MovementGuard allows that speed. Getting out, however it happens, puts the car away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local CarBuilder = require(script.Parent.CarBuilder)
local CollisionGroups = require(script.Parent.CollisionGroups)
local JailService = require(script.Parent.JailService)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local ShopService = require(script.Parent.ShopService)
local VehicleModels = require(script.Parent.VehicleModels)

local SPEED_ATTRIBUTE = "VehicleSpeed"
local GROUND_PROBE = 30 -- how far down to look for the road under you
local RIDE_COLORS = { -- by ride level
	Color3.fromRGB(80, 200, 105),
	Color3.fromRGB(95, 160, 245),
	Color3.fromRGB(255, 196, 50),
}

export type Kind = "Ride" | "RaceCar" | "StolenCar" | "Debug" -- Debug: DebugService's /drive

type Mounted = {
	kind: Kind,
	car: Model,
	speed: number,
}

local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local VehicleService = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

local mounted: { [Player]: Mounted } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Vehicles"
	created.Parent = workspace
	folder = created
	return created
end

local function applySpeed(player: Player, speed: number?)
	local character = player.Character
	if character then
		character:SetAttribute(SPEED_ATTRIBUTE, speed)
	end
	MovementGuard.setAllowedSpeed(player, if speed then math.max(speed, Config.Movement.SprintSpeed) else nil)
end

function VehicleService.kind(player: Player): Kind?
	local current = mounted[player]
	return if current then current.kind else nil
end

function VehicleService.isRiding(player: Player): boolean
	return VehicleService.kind(player) == "Ride"
end

-- Every car someone is driving (for pedestrians to get out of the way of).
function VehicleService.cars(): { Model }
	local list = {}
	for _, current in mounted do
		table.insert(list, current.car)
	end
	return list
end

function VehicleService.dismount(player: Player)
	local current = mounted[player]
	if not current then
		return
	end
	mounted[player] = nil
	local seat = current.car:FindFirstChild("DriverSeat")
	local seatWeld = seat and seat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
	end
	current.car:Destroy()
	if player.Character then
		CollisionGroups.driving(player.Character, false)
	end
	applySpeed(player, nil)
	VehicleService.changed:Fire(player)
end

-- Where a car can go under the player: on the ground, facing their way, with room for it.
local function spaceFor(player: Player, body: Model): CFrame?
	local character = player.Character
	local root = CharacterUtil.getRoot(player)
	if not character or not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, getFolder() }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_PROBE, 0), params)
	if not hit then
		return nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local facing = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local ground = CFrame.lookAt(hit.Position, hit.Position + facing)
	body:PivotTo(ground)
	local box, size = body:GetBoundingBox()
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	-- Lifted a little so the road and kerbs underneath don't count.
	local blocking = workspace:GetPartBoundsInBox(box + Vector3.new(0, 0.8, 0), size - Vector3.new(0, 1, 0), overlap)
	return if #blocking == 0 then ground else nil
end

-- `at` moved down onto whatever's under it (a marker floats a little above the road).
local function onGround(at: CFrame): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { getFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(at.Position + Vector3.new(0, 3, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	return if hit then at.Rotation + hit.Position else at
end

local function driverMass(character: Model): number
	local mass = 0
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Massless then
			mass += part:GetMass()
		end
	end
	return mass
end

-- Puts the player in a car with this top speed (0 holds it still). `at` is the ground point to
-- park it on (a race grid slot, a stolen car's spot); otherwise it appears right where they
-- stand. Replaces any car they're in.
function VehicleService.mount(player: Player, kind: Kind, speed: number, color: Color3, at: CFrame?): boolean
	VehicleService.dismount(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	-- Your own kart is a kart; race cars (a garage loaner) and stolen cars are cars.
	local body = if kind == "Ride" then VehicleModels.kart(color) else VehicleModels.car(color)
	local ground = if at then onGround(at) else spaceFor(player, body)
	if not ground then
		body:Destroy()
		Notifier.send(player, "No room for a car here. Try somewhere more open.", "Info")
		return false
	end
	local car = CarBuilder.build(body, ground + Vector3.new(0, 0.1, 0), speed)
	if not car then
		body:Destroy()
		return false
	end
	car.Name = `{player.Name}{kind}`
	car.Parent = getFolder()
	CarBuilder.tune(car, driverMass(character))
	local seat = car:FindFirstChild("DriverSeat")
	if not seat or not seat:IsA("VehicleSeat") then
		car:Destroy()
		return false
	end
	seat:Sit(humanoid)
	CollisionGroups.driving(character, true)
	CarBuilder.giveTo(car, player)
	MovementGuard.reset(player) -- sitting down moved them
	mounted[player] = { kind = kind, car = car, speed = speed }
	applySpeed(player, speed)

	-- Jumping out, dying, being teleported: whatever the reason, out means out.
	local function checkSeated()
		local current = mounted[player]
		if seat.Occupant ~= humanoid and current and current.car == car then
			VehicleService.dismount(player)
		end
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(checkSeated)
	task.delay(1, checkSeated) -- in case they never sat down at all
	VehicleService.changed:Fire(player)
	return true
end

function VehicleService.setSpeed(player: Player, speed: number)
	local current = mounted[player]
	if current then
		current.speed = speed
		current.car:SetAttribute("TopSpeed", speed)
		applySpeed(player, speed)
	end
end

local function mountRide(player: Player): boolean
	local speed = ShopService.rideSpeed(player)
	if not speed then
		return false
	end
	local current = mounted[player]
	local at = if current then current.car:GetPivot() else nil -- a new kart where the old one was
	local color = RIDE_COLORS[ShopService.level(player, "Ride")] or RIDE_COLORS[1]
	return VehicleService.mount(player, "Ride", speed, color, at)
end

local function onSetRiding(player: Player, payload: unknown)
	if not limiter:allow(player) or typeof(payload) ~= "boolean" then
		return
	end
	local current = mounted[player]
	if not payload then
		if current and current.kind ~= "RaceCar" then
			VehicleService.dismount(player) -- out of your ride, or ditching a stolen car
		end
		return
	end
	if current then
		return -- already riding, in a race car or in a stolen car
	end
	if not ShopService.rideSpeed(player) then
		Notifier.send(player, "You don't have a ride yet. Buy a kart at Speedy's Garage.", "Info")
		return
	end
	if not RosterService.isActive(player) or JailService.isJailed(player) then
		return
	end
	if RunState.phase == "Results" or RunState.phase == "Ended" then
		return
	end
	mountRide(player)
end

local function forget(player: Player)
	local current = mounted[player]
	if current then
		mounted[player] = nil
		current.car:Destroy()
		MovementGuard.setAllowedSpeed(player, nil)
		VehicleService.changed:Fire(player)
	end
end

function VehicleService.start()
	remotes.SetRiding:onServer(onSetRiding)

	ShopService.upgraded:Connect(function(player: Player, id: Types.UpgradeId)
		if id == "Ride" and VehicleService.isRiding(player) then
			mountRide(player) -- faster kart right away
		end
	end)
	JailService.arrested:Connect(VehicleService.dismount)
	RunState.changed:Connect(function()
		if RunState.phase == "Results" or RunState.phase == "Ended" then
			for player in mounted do
				VehicleService.dismount(player)
			end
		end
	end)

	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			forget(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(forget)
end

return VehicleService
