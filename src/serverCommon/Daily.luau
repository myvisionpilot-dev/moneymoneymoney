--!strict
-- The daily challenge: one per UTC day, the same for everyone, picked in order from
-- Config.Daily.Challenges. Finishing it pays Cred and keeps your streak going (a day missed
-- starts it again). Progress is earned in the Match; the lobby shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Profiles = require(script.Parent.Profiles)

local SECONDS_PER_DAY = 86_400

export type Challenge = {
	stat: string,
	goal: number,
	text: string,
	best: boolean?,
}

local settings = Config.Daily

local Daily = {}

function Daily.today(): number
	return os.time() // SECONDS_PER_DAY
end

function Daily.challenge(day: number): Challenge
	local list: { Challenge } = settings.Challenges
	return list[day % #list + 1]
end

-- Days in a row, counting today or yesterday (0 once a day was missed).
function Daily.streak(data: Profiles.Data): number
	return if data.Streak.LastDay >= Daily.today() - 1 then data.Streak.Count else 0
end

-- What finishing today's challenge would pay, with the streak it would give you.
local function rewardFor(streakAfter: number): number
	return settings.Reward + settings.StreakBonusPerDay * math.min(streakAfter - 1, settings.MaxStreakBonusDays)
end

local function refresh(data: Profiles.Data)
	local today = Daily.today()
	if data.Daily.Day ~= today then
		data.Daily = { Day = today, Progress = 0, Done = false }
	end
end

function Daily.view(data: Profiles.Data): Types.DailyView
	refresh(data)
	local challenge = Daily.challenge(data.Daily.Day)
	local nextStreak = if data.Daily.Done then Daily.streak(data) else Daily.streak(data) + 1
	return {
		text = challenge.text,
		progress = math.min(data.Daily.Progress, challenge.goal),
		goal = challenge.goal,
		reward = rewardFor(math.max(nextStreak, 1)),
		done = data.Daily.Done,
	}
end

export type Result = {
	progressed: boolean,
	completed: boolean,
	reward: number,
	streak: number,
}

-- Counts `amount` of `stat` toward today's challenge and updates the streak when it's done.
-- The caller pays result.reward (through Profiles.addCred).
function Daily.record(data: Profiles.Data, stat: string, amount: number): Result
	refresh(data)
	local challenge = Daily.challenge(data.Daily.Day)
	local result: Result = { progressed = false, completed = false, reward = 0, streak = Daily.streak(data) }
	if data.Daily.Done or challenge.stat ~= stat then
		return result
	end
	local before = data.Daily.Progress
	data.Daily.Progress = if challenge.best then math.max(before, amount) else before + amount
	result.progressed = data.Daily.Progress > before
	if data.Daily.Progress < challenge.goal then
		return result
	end

	local today = data.Daily.Day
	local streak = data.Streak
	if streak.LastDay == today - 1 then
		streak.Count += 1
	elseif streak.LastDay ~= today then
		streak.Count = 1
	end
	streak.LastDay = today
	data.Daily.Done = true
	result.completed = true
	result.reward = rewardFor(streak.Count)
	result.streak = streak.Count
	return result
end

return Daily
