--!strict
-- Turns a run into saved progress. When your run ends (cash out, bust or failed quota) your
-- prize goes into your Cred and is saved straight away, with your run count, badges and
-- leaderboard scores. During the run, Stats feed today's challenge and badges.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Badges = require(ServerScriptService.Common.Badges)
local Daily = require(ServerScriptService.Common.Daily)
local Leaderboards = require(ServerScriptService.Common.Leaderboards)
local Perks = require(ServerScriptService.Common.Perks)
local Profiles = require(ServerScriptService.Common.Profiles)
local HeatService = require(script.Parent.HeatService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local PrizeService = require(script.Parent.PrizeService)
local RosterService = require(script.Parent.RosterService)
local Stats = require(script.Parent.Stats)
local StealService = require(script.Parent.StealService)

-- Badges earned by doing a thing once.
local STAT_BADGES: { [string]: string } = {
	RaceWin = "SpeedDemon",
	Escape = "NowYouSeeMe",
	Bounty = "LawAndOrder",
	ChopShop = "HotWheels",
}

local RewardService = {}

local function award(player: Player, data: Profiles.Data, id: string)
	local name = Badges.award(data, id)
	if name then
		Notifier.send(player, `Badge earned: {name}!`, "Good")
		Juice.sound(player, "Badge")
	end
end

local function onStat(player: Player, stat: string, amount: number)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local result = Daily.record(data, stat, amount)
	if result.completed then
		Profiles.addCred(player, data, result.reward, "daily challenge")
		Notifier.send(player, `Daily challenge done! +{Format.cred(result.reward)} (streak: {result.streak})`, "Good")
		Juice.sound(player, "Badge")
		if result.streak >= Config.Badges.RegularStreakDays then
			award(player, data, "Regular")
		end
	elseif result.progressed then
		local view = Daily.view(data)
		Notifier.send(player, `Daily challenge: {view.progress}/{view.goal}`, "Info")
	end

	local badge = STAT_BADGES[stat]
	if badge then
		award(player, data, badge)
	end
	if stat == "QuotaCleared" then
		data.HighestQuota = math.max(data.HighestQuota, amount)
		if amount >= Config.Badges.GettingSeriousQuota then
			award(player, data, "GettingSerious")
		end
		if amount >= #Config.Match.Quotas then
			award(player, data, "PaidInFull")
		end
		if amount > #Config.Match.Quotas then
			award(player, data, "InTooDeep")
		end
	end
	Profiles.markChanged(player)
end

local function onRunEnded(userId: number, prize: number, failed: boolean)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local data = Profiles.get(player)
	if not data then
		warn(`[Rewards] {player.Name}'s save isn't loaded, so their {prize} Cred couldn't be saved`)
		return
	end
	data.Runs += 1
	Profiles.addCred(player, data, prize, if failed then "run prize (failed, kept share)" else "run prize")
	-- The Cred shop's Investor upgrade adds a cut on top.
	local bonus = math.floor(prize * Perks.amount(player, "Investor"))
	if bonus > 0 then
		Profiles.addCred(player, data, bonus, "Investor bonus")
		Notifier.send(player, `Investor: +{Format.cred(bonus)} on top of your prize.`, "Good")
	end
	award(player, data, "FirstRun")
	if StealService.snakeUserId() == userId then
		award(player, data, "Snake")
	end
	if PrizeService.mvpUserId() == userId and RosterService.startingCount >= Config.Badges.MvpMinPlayers then
		award(player, data, "TopEarner")
	end
	if data.LifetimeCred >= Config.Badges.LoadedCred then
		award(player, data, "Loaded")
	end
	Leaderboards.submit(player, "Cred", data.LifetimeCred)
	Leaderboards.submit(player, "Quota", data.HighestQuota)
	Profiles.markChanged(player)
	Profiles.save(player)
	Notifier.send(player, `Saved! You now have {Format.cred(data.Cred)}.`, "Good")
end

function RewardService.start()
	Stats.recorded:Connect(onStat)
	HeatService.escaped:Connect(function(player: Player)
		Stats.record(player, "Escape")
	end)
	PrizeService.locked:Connect(onRunEnded)
end

return RewardService
