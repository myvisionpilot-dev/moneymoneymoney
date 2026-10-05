--!strict
-- Heat: 0 to Police.MaxHeat per player; each whole number is a wanted star.
-- Crimes add heat; it drains after a quiet spell. Hidden in a bush (and not spotted by a cop,
-- which PoliceService reports) it drains faster and straight away.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local BoostService = require(script.Parent.BoostService)
local HustleService = require(script.Parent.HustleService)
local TwistService = require(script.Parent.TwistService)

local HIDING_TAG = "HidingSpot"
local TICK_SECONDS = 0.5
local HIDING_MARGIN = 2 -- studs around a hiding spot that still count

type State = {
	heat: number,
	lastCrimeAt: number,
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
		state = { heat = 0, lastCrimeAt = 0, hiding = false, spotted = false }
		states[player] = state
	end
	return state
end

-- Only fire when the shown value (tenths of a star) or hiding changes, to keep sync traffic low.
local function setHeat(player: Player, state: State, heat: number, hiding: boolean)
	local before = math.floor(state.heat * 10)
	local wasHiding = state.hiding
	state.heat = math.clamp(heat, 0, Config.Police.MaxHeat)
	state.hiding = hiding
	if math.floor(state.heat * 10) ~= before or hiding ~= wasHiding then
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

-- Crimes add heat (a disguise from the convenience store halves it, the Cool Head hustle
-- lowers it, a Crackdown twist raises it). The debug command can pass a negative amount to
-- cool you down.
function HeatService.add(player: Player, amount: number)
	local state = stateOf(player)
	state.lastCrimeAt = os.clock()
	local scaled = if amount > 0
		then amount
			* BoostService.heatMultiplier(player)
			* HustleService.heatGainMultiplier(player)
			* TwistService.heatMultiplier()
		else amount
	setHeat(player, state, state.heat + scaled, state.hiding)
end

function HeatService.clear(player: Player)
	local state = stateOf(player)
	setHeat(player, state, 0, state.hiding)
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
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local state = stateOf(player)
		local hiding = inHidingSpot(player)
		local hidden = hiding and not state.spotted
		local heat = state.heat
		local starsBefore = math.floor(heat)
		if heat > 0 and (hidden or now - state.lastCrimeAt >= Config.Heat.DecayDelaySeconds) then
			local rate = Config.Police.HeatDecayPerSecond * HustleService.heatDecayMultiplier(player)
			if hidden then
				rate *= Config.Heat.HidingDecayMultiplier
			end
			heat -= rate * dt
		end
		setHeat(player, state, heat, hiding)
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
