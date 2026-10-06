--!strict
-- Fun titles for the results screen, from what everyone did this run: Biggest Payday (the
-- largest single payout), Hardest Worker (most payouts), Getaway King (lost the police in a
-- bush most often) and Most Busted. Each goes to whoever leads; ties go to the first to get there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local PayNotice = require(script.Parent.PayNotice)
local RosterService = require(script.Parent.RosterService)

type Tally = { biggest: number, jobs: number, escapes: number, busts: number }
type Field = "biggest" | "jobs" | "escapes" | "busts"

local RunAwards = {}

local tallies: { [number]: Tally } = {} -- by userId (players who left still count)

local function tallyOf(player: Player): Tally
	local tally = tallies[player.UserId]
	if not tally then
		tally = { biggest = 0, jobs = 0, escapes = 0, busts = 0 }
		tallies[player.UserId] = tally
	end
	return tally
end

local function times(n: number): string
	return if n == 1 then "once" else `{n} times`
end

local AWARDS: { { field: Field, title: string, detail: (n: number) -> string } } = {
	{
		field = "biggest",
		title = "BIGGEST PAYDAY",
		detail = function(n: number): string
			return `{Format.money(n)} in one go`
		end,
	},
	{
		field = "jobs",
		title = "HARDEST WORKER",
		detail = function(n: number): string
			return `{n} paydays`
		end,
	},
	{
		field = "escapes",
		title = "GETAWAY KING",
		detail = function(n: number): string
			return `lost the police {times(n)}`
		end,
	},
	{
		field = "busts",
		title = "MOST BUSTED",
		detail = function(n: number): string
			return `busted {times(n)}`
		end,
	},
}

-- Every award somebody earned (a count of zero doesn't win anything).
function RunAwards.list(): { Types.Award }
	local list: { Types.Award } = {}
	for _, award in AWARDS do
		local bestName: string? = nil
		local best = 0
		for _, member in RosterService.all() do
			local tally = tallies[member.userId]
			local value = if tally then tally[award.field] else 0
			if value > best then
				bestName, best = member.name, value
			end
		end
		if bestName then
			table.insert(list, { title = award.title, name = bestName, detail = award.detail(best) })
		end
	end
	return list
end

function RunAwards.start()
	PayNotice.earned:Connect(function(player: Player, added: number)
		local tally = tallyOf(player)
		tally.biggest = math.max(tally.biggest, added)
		tally.jobs += 1
	end)
	HeatService.escaped:Connect(function(player: Player)
		tallyOf(player).escapes += 1
	end)
	JailService.arrested:Connect(function(player: Player)
		tallyOf(player).busts += 1
	end)
end

return RunAwards
