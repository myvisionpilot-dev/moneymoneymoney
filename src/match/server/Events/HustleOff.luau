--!strict
-- Hustle-off (Events.HustleOff.MinPlayers or more): whoever earns the most from jobs while it's
-- on wins Prize (scaled by quota), straight into their bag. The event card shows the leader,
-- and each player's own card shows their total too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Signal = require(ReplicatedStorage.Shared.Signal)
local EconomyService = require(script.Parent.Parent.EconomyService)
local Juice = require(script.Parent.Parent.Juice)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local RunState = require(script.Parent.Parent.RunState)
local TownEvent = require(script.Parent.TownEvent)

local settings = Config.Events.HustleOff

local totals: { [Player]: number } = {}
local connection: Signal.Connection? = nil
local context: TownEvent.Context? = nil

local HustleOff = {
	id = "HustleOff",
	title = "HUSTLE-OFF",
	seconds = settings.Seconds,
}

function HustleOff.canStart(): boolean
	return #RosterService.active() >= settings.MinPlayers
end

local function prize(): number
	local ctx = context
	return math.floor(settings.Prize * (if ctx then ctx.tierMultiplier else 1) + 0.5)
end

local function leader(): (Player?, number)
	local best: Player? = nil
	local bestTotal = 0
	for player, total in totals do
		if total > bestTotal and player.Parent then
			best, bestTotal = player, total
		end
	end
	return best, bestTotal
end

local function refresh()
	local ctx = context
	if not ctx then
		return
	end
	local best, bestTotal = leader()
	local lead = if best
		then `Leader: {best.DisplayName}, {Format.money(bestTotal)}.`
		else "Nobody's earned anything yet."
	ctx.announce(`Earn the most from jobs to win {Format.money(prize())}! {lead}`, nil)
	for _, player in Players:GetPlayers() do
		if RosterService.isActive(player) then
			ctx.announceTo(
				player,
				`Earn the most to win {Format.money(prize())}! You: {Format.money(totals[player] or 0)}. {lead}`,
				nil
			)
		end
	end
end

function HustleOff.start(ctx: TownEvent.Context)
	context = ctx
	table.clear(totals)
	connection = PayNotice.earned:Connect(function(player: Player, added: number)
		totals[player] = (totals[player] or 0) + added
		refresh()
	end)
	refresh()
end

function HustleOff.tick() end

function HustleOff.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local winner, total = leader()
	if winner and RunState.phase == "Quota" and RosterService.isActive(winner) then
		local amount = prize()
		EconomyService.addCarried(winner, amount, "hustle-off prize", true)
		Juice.paid(winner, amount, "Won the hustle-off")
		Juice.sound(winner, "Fanfare")
		Notifier.others(winner, `{winner.DisplayName} won the hustle-off with {Format.money(total)}!`, "Info")
	end
	context = nil
	table.clear(totals)
end

return HustleOff
