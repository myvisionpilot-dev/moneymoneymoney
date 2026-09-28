--!strict
-- Vehicles on players: your ride (bought at the upgrades counter, hop on or off with SetRiding), race
-- karts (Paths/Racing) and stolen cars (Paths/CarTheft; SetRiding off ditches one). A vehicle
-- is a grey-box body welded under you. Your speed comes from the VehicleSpeed character
-- attribute (read by shared/Movement), and MovementGuard allows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Cosmetics = require(ServerScriptService.Common.Cosmetics)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local JailService = require(script.Parent.JailService)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local ShopService = require(script.Parent.ShopService)
local VehicleModels = require(script.Parent.VehicleModels)

local SPEED_ATTRIBUTE = "VehicleSpeed"
local RIDE_COLORS = { -- by ride level
	Color3.fromRGB(80, 200, 105),
	Color3.fromRGB(95, 160, 245),
	Color3.fromRGB(255, 196, 50),
}

export type Kind = "Ride" | "RaceKart" | "StolenCar"

type Mounted = {
	kind: Kind,
	model: Model,
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
	created.Name = "Vehicles" -- outside characters, so riders can see their own kart in first person
	created.Parent = workspace
	folder = created
	return created
end

local function applySpeed(player: Player, speed: number?)
	local character = player.Character
	if character then
		character:SetAttribute(SPEED_ATTRIBUTE, speed)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed or Config.Movement.WalkSpeed
		end
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

function VehicleService.dismount(player: Player)
	local current = mounted[player]
	if not current then
		return
	end
	mounted[player] = nil
	current.model:Destroy()
	applySpeed(player, nil)
	VehicleService.changed:Fire(player)
end

-- Puts the player in a kart at `speed` (0 holds them still). Replaces any kart they're in.
function VehicleService.mount(player: Player, kind: Kind, speed: number, color: Color3): boolean
	VehicleService.dismount(player)
	local character = player.Character
	local root = CharacterUtil.getRoot(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return false
	end
	local paint = if kind == "StolenCar" then nil else Cosmetics.paint(player) -- your kart paint, if you bought one
	local model = if kind == "StolenCar" then VehicleModels.car(color) else VehicleModels.kart(paint or color)
	model.Name = `{player.Name}{kind}`
	VehicleModels.attach(model, root, humanoid, getFolder())
	mounted[player] = { kind = kind, model = model, speed = speed }
	applySpeed(player, speed)
	VehicleService.changed:Fire(player)
	return true
end

function VehicleService.setSpeed(player: Player, speed: number)
	local current = mounted[player]
	if current then
		current.speed = speed
		applySpeed(player, speed)
	end
end

local function mountRide(player: Player): boolean
	local speed = ShopService.rideSpeed(player)
	if not speed then
		return false
	end
	local color = RIDE_COLORS[ShopService.level(player, "Ride")] or RIDE_COLORS[1]
	return VehicleService.mount(player, "Ride", speed, color)
end

local function onSetRiding(player: Player, payload: unknown)
	if not limiter:allow(player) or typeof(payload) ~= "boolean" then
		return
	end
	local current = mounted[player]
	if not payload then
		if current and current.kind ~= "RaceKart" then
			VehicleService.dismount(player) -- off your ride, or ditching a stolen car
		end
		return
	end
	if current then
		return -- already riding, in a race kart or in a stolen car
	end
	if not ShopService.rideSpeed(player) then
		Notifier.send(player, "You don't have a ride yet. Buy a kart at the hardware store.", "Info")
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
		current.model:Destroy()
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
