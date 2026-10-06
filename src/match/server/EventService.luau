--!strict
-- Town events (Events/*): during a quota, one at a time, never in the quota's first
-- Events.FirstAfterSeconds and with a random gap after each. Everyone sees a banner (TownEvent
-- remote); an event can give one player their own banner, such as the VIP's driver. Events
-- stop when the quota ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local QuotaMath = require(script.Parent.QuotaMath)
local RunState = require(script.Parent.RunState)
local TownEvent = require(script.Parent.Events.TownEvent)

local TICK_SECONDS = 0.25

type Banner = { detail: string, marker: Vector3? }

local settings = Config.Events
local remotes = Remotes.match()
local rng = Random.new()

local EVENTS: { TownEvent.TownEvent } = {
	require(script.Parent.Events.CashDrop),
	require(script.Parent.Events.HappyHour),
	require(script.Parent.Events.FireSale),
	require(script.Parent.Events.VipFare),
	require(script.Parent.Events.ArmouredTruck),
	require(script.Parent.Events.RivalCrew),
	require(script.Parent.Events.HustleOff),
}

local EventService = {}

local current: TownEvent.TownEvent? = nil
local endsAt = 0
local banner: Banner = { detail = "", marker = nil }
local personal: { [Player]: Banner } = {}
local nextAt: number? = nil -- when the next event may start
local lastId: string? = nil
local lastQuota = 0
local running = 0 -- bumps every start, so a slow start() knows if it was already stopped

local function viewFor(player: Player): Types.TownEventView?
	local event = current
	if not event then
		return nil
	end
	local shown = personal[player] or banner
	return { id = event.id, title = event.title, detail = shown.detail, marker = shown.marker, endsAt = endsAt }
end

local function send(player: Player)
	remotes.TownEvent:fireClient(player, viewFor(player))
end

local function sendAll()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

local function stop()
	local event = current
	if not event then
		return
	end
	current = nil
	running += 1
	table.clear(personal)
	event.stop()
	lastId = event.id
	nextAt = Timing.now() + rng:NextNumber(settings.MinGapSeconds, settings.MaxGapSeconds)
	sendAll()
end

local function begin(event: TownEvent.TownEvent)
	current = event
	running += 1
	local run = running
	endsAt = Timing.now() + event.seconds
	banner = { detail = "", marker = nil }
	local context: TownEvent.Context = {
		endsAt = endsAt,
		tierMultiplier = QuotaMath.tierMultiplier(RunState.quotaIndex),
		announce = function(detail: string, marker: Vector3?)
			if running == run then
				banner = { detail = detail, marker = marker }
				sendAll()
			end
		end,
		announceTo = function(player: Player, detail: string?, marker: Vector3?)
			if running ~= run then
				return
			end
			if detail then
				personal[player] = { detail = detail, marker = marker }
			else
				personal[player] = nil
			end
			send(player)
		end,
		finish = function()
			if running == run then
				stop()
			end
		end,
	}
	task.spawn(event.start, context)
end

local function pick(): TownEvent.TownEvent?
	local eligible: { TownEvent.TownEvent } = {}
	for _, event in EVENTS do
		if event.id ~= lastId and event.canStart() then
			table.insert(eligible, event)
		end
	end
	return if #eligible > 0 then eligible[rng:NextInteger(1, #eligible)] else nil
end

local function tick()
	if RunState.phase ~= "Quota" then
		stop()
		nextAt = nil
		return
	end
	local now = Timing.now()
	if RunState.quotaIndex ~= lastQuota then
		lastQuota = RunState.quotaIndex
		nextAt = math.max(nextAt or 0, RunState.quotaStartedAt + settings.FirstAfterSeconds)
	end
	local event = current
	if event then
		if now >= endsAt then
			stop()
		else
			event.tick()
		end
	elseif nextAt and now >= nextAt then
		local chosen = pick()
		if chosen then
			begin(chosen)
		end
	end
end

-- Debug: start an event by id now (ending any current one).
function EventService.force(id: string): boolean
	for _, event in EVENTS do
		if event.id:lower() == id:lower() and RunState.phase == "Quota" then
			stop()
			begin(event)
			return true
		end
	end
	return false
end

function EventService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		personal[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return EventService
