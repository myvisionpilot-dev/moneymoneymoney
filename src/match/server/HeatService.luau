--!strict
-- Heat: 0 to Police.MaxHeat per player; each whole number is a wanted star.
-- Crimes add heat, and it all clears Heat.WantedSeconds after your last crime, however many
-- stars you have (the chase music is that long). The clock runs faster hidden in a bush (and not
-- spotted by a cop, which PoliceService reports) and with the Ghost hustle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local BoostService = require(script.Parent.BoostService)
local HustleService = require(script.Parent.HustleService)
local TwistService = require(script.Parent.TwistService)

local HIDING_TAG = "HidingSpot"
local TICK_SECONDS = 0.5
local HIDING_MARGIN = 2 -- studs around a hiding spot that still count

type State = {
	heat: number,
	secondsLeft: number, -- until the heat clears (counts down faster when hidden)
	speed: number, -- how fast that's counting down right now
	hiding: boolean, -- in a bush
	spotted: boolean, -- a cop is close enough to see you anyway
}

local HeatService = {
	changed = Signal.new() :: Signal.Signal<Player>,
	escaped = Signal.new() :: Signal.Signal<Player>, -- lost your last star while hidden in a bush
}

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { heat = 0, secondsLeft = 0, speed = 1, hiding = false, spotted = false }
		states[player] = state
	end
	return state
end

-- Only fire when the shown value (tenths of a star), hiding or the countdown's speed changes,
-- to keep sync traffic low.
local function setHeat(player: Player, state: State, heat: number, hiding: boolean, speed: number)
	local before = math.floor(state.heat * 10)
	local wasHiding, wasSpeed = state.hiding, state.speed
	state.heat = math.clamp(heat, 0, Config.Police.MaxHeat)
	state.hiding = hiding
	state.speed = speed
	if math.floor(state.heat * 10) ~= before or hiding ~= wasHiding or speed ~= wasSpeed then
		HeatService.changed:Fire(player)
	end
end

function HeatService.get(player: Player): number
	local state = states[player]
	return if state then state.heat else 0
end

function HeatService.stars(player: Player): number
	return math.floor(HeatService.get(player))
end

-- When (server time) their heat will clear at the current pace; 0 with no heat.
function HeatService.clearsAt(player: Player): number
	local state = states[player]
	if not state or state.heat <= 0 then
		return 0
	end
	return Timing.now() + state.secondsLeft / math.max(state.speed, 0.01)
end

function HeatService.isHiding(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.hiding
end

function HeatService.isSpotted(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.spotted
end

-- In a bush with no cop close enough to see: the police have lost you.
function HeatService.isHidden(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.hiding and not state.spotted
end

function HeatService.setSpotted(player: Player, spotted: boolean)
	local state = stateOf(player)
	if state.spotted ~= spotted then
		state.spotted = spotted
		HeatService.changed:Fire(player)
	end
end

-- Crimes add heat and restart the clock (a disguise from the convenience store halves it, the
-- Cool Head hustle lowers it, a Crackdown twist raises it). The debug command can pass a
-- negative amount to cool you down.
function HeatService.add(player: Player, amount: number)
	local state = stateOf(player)
	local scaled = if amount > 0
		then amount
			* BoostService.heatMultiplier(player)
			* HustleService.heatGainMultiplier(player)
			* TwistService.heatMultiplier()
		else amount
	if scaled > 0 then
		state.secondsLeft = Config.Heat.WantedSeconds
	end
	setHeat(player, state, state.heat + scaled, state.hiding, state.speed)
	HeatService.changed:Fire(player) -- the clock restarted
end

function HeatService.clear(player: Player)
	local state = stateOf(player)
	state.secondsLeft = 0
	setHeat(player, state, 0, state.hiding, 1)
end

local function inHidingSpot(player: Player): boolean
	local root = CharacterUtil.getRoot(player)
	if not root then
		return false
	end
	for _, spot in CollectionService:GetTagged(HIDING_TAG) do
		if spot:IsA("BasePart") then
			local offset = spot.CFrame:PointToObjectSpace(root.Position)
			local half = spot.Size / 2 + Vector3.one * HIDING_MARGIN
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local state = stateOf(player)
		local hiding = inHidingSpot(player)
		local hidden = hiding and not state.spotted
		local speed = HustleService.heatDecayMultiplier(player)
			* (if hidden then Config.Heat.HidingDecayMultiplier else 1)
		local heat = state.heat
		local starsBefore = math.floor(heat)
		if heat > 0 then
			state.secondsLeft -= dt * speed
			if state.secondsLeft <= 0 then
				heat = 0
			end
		end
		setHeat(player, state, heat, hiding, if heat > 0 then speed else 1)
		if hidden and starsBefore >= 1 and math.floor(state.heat) == 0 then
			HeatService.escaped:Fire(player)
		end
	end
end

function HeatService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			tick(task.wait(TICK_SECONDS))
		end
	end)
end

return HeatService
