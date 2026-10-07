--!strict
-- Your STREAK (Config.Streak): every payout within WindowSeconds of the last one adds one to
-- it, and the more in a row, the more each pays (PayNotice asks StreakService.hit). Banking
-- your cash refills the timer, so a trip to the bank doesn't break it; getting busted ends it,
-- and so does going too long without a payout. The count rides on your character as the
-- Streak attribute, so every screen can set you on fire (client/WorldFxController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local JailService = require(script.Parent.JailService)

local ATTRIBUTE = "Streak"
local CHECK_SECONDS = 0.25

type State = { count: number, endsAt: number }

local settings = Config.Streak

local StreakService = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

local states: { [Player]: State } = {}

local function show(player: Player, count: number)
	local character = player.Character
	if character then
		character:SetAttribute(ATTRIBUTE, if count > 0 then count else nil)
	end
end

local function set(player: Player, count: number, endsAt: number)
	states[player] = { count = count, endsAt = endsAt }
	show(player, count)
	StreakService.changed:Fire(player)
end

-- The pay multiplier for a streak this long (1 below the first tier).
function StreakService.multiplierFor(count: number): number
	local multiplier = 1
	for _, tier in settings.Tiers do
		if count >= tier.count then
			multiplier = tier.multiplier
		end
	end
	return multiplier
end

function StreakService.count(player: Player): number
	local state = states[player]
	return if state and state.endsAt > Timing.now() then state.count else 0
end

function StreakService.endsAt(player: Player): number
	local state = states[player]
	return if state then state.endsAt else 0
end

-- A payout: one more in a row (or the first of a new streak). Returns the multiplier it pays at.
function StreakService.hit(player: Player): number
	local count = StreakService.count(player) + 1
	set(player, count, Timing.now() + settings.WindowSeconds)
	return StreakService.multiplierFor(count)
end

-- Banking cash: the clock starts again, the streak stays.
function StreakService.refill(player: Player)
	local count = StreakService.count(player)
	if count > 0 then
		set(player, count, Timing.now() + settings.WindowSeconds)
	end
end

function StreakService.reset(player: Player)
	if states[player] and states[player].count > 0 then
		set(player, 0, 0)
	end
end

function StreakService.start()
	JailService.arrested:Connect(StreakService.reset)
	-- Run out the clock on streaks nobody kept going.
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		local now = Timing.now()
		for player, state in states do
			if state.count > 0 and state.endsAt <= now then
				set(player, 0, 0)
			end
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			show(player, StreakService.count(player)) -- a new character keeps the flames
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

return StreakService
