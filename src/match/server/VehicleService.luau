--!strict
-- Vehicles: race cars lent by the garage (Paths/Racing), stolen cars (Paths/CarTheft), City Cabs
-- taxis (Paths/Taxi) and flipped wrecks (Paths/CarFlip). LeaveCar (R) gets you out of anything
-- but a race car.
-- Each is a real physics car (CarBuilder) that you sit in; your own computer drives it
-- (client/CarController). The car's TopSpeed attribute caps it (0 holds it still), the
-- VehicleSpeed attribute on your character tells everything else you're driving, and
-- MovementGuard allows that speed. Getting out, however it happens, puts the car away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Style = require(ServerScriptService.Common.Style)
local CarBuilder = require(script.Parent.CarBuilder)
local CollisionGroups = require(script.Parent.CollisionGroups)
local JailService = require(script.Parent.JailService)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local RunState = require(script.Parent.RunState)
local VehicleModels = require(script.Parent.VehicleModels)

local SPEED_ATTRIBUTE = "VehicleSpeed"
local GROUND_PROBE = 30 -- how far down to look for the road under you

export type Kind = "RaceCar" | "StolenCar" | "Taxi" | "FlipCar" | "Debug" -- Debug: DebugService's /drive

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

-- The car they're driving, if any (CarFlip repaints it in the paint booth).
function VehicleService.car(player: Player): Model?
	local current = mounted[player]
	return if current then current.car else nil
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

-- Their race car wears their paint and underglow from the Cred shop: the glow
-- is a neon slab under the floor with a light, tagged RainbowGlow when it cycles (shared/Rainbow).
local function dress(player: Player, body: Model)
	local paint = Style.worn(player, "Paint")
	if paint then
		Cosmetics.paint(body, paint)
	end
	local glow = Style.worn(player, "Glow")
	local hull = body:FindFirstChild("Hull")
	if glow and hull and hull:IsA("BasePart") then
		local slab = Instance.new("Part")
		slab.Name = "Underglow"
		-- A little wider than the body, so the glowing edge shows even in daylight.
		slab.Size = Vector3.new(hull.Size.X + 1.4, 0.12, hull.Size.Z + 0.4)
		slab.CFrame = CFrame.new(0, 0.3, hull.Position.Z)
		slab.Color = glow.color
		slab.Material = Enum.Material.Neon
		slab.CanCollide = false
		slab.CanQuery = false
		slab.CanTouch = false
		slab.Massless = true
		slab.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = glow.color
		light.Range = 14
		light.Brightness = 4
		light.Parent = slab
		if glow.rainbow then
			slab:AddTag("RainbowGlow")
		end
		slab.Parent = body
	end
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
	-- A taxi is a taxi; everything else is a car in `color`.
	local body = if kind == "Taxi" then VehicleModels.taxi() else VehicleModels.car(color)
	if kind == "RaceCar" then
		dress(player, body) -- their Cred shop paint and underglow
	end
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

local function onLeaveCar(player: Player, _payload: unknown)
	local current = mounted[player]
	if limiter:allow(player) and current and current.kind ~= "RaceCar" then
		VehicleService.dismount(player) -- out of a taxi or flip car, or ditching a stolen car
	end
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
	remotes.LeaveCar:onServer(onLeaveCar)
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
