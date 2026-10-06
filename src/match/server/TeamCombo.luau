--!strict
-- Team combo: when everyone still in the run (2+ players) deposits within TeamCombo.Seconds of
-- each other, those deposits count TeamCombo.Bonus extra toward the quota. The first deposit
-- of a round tells everyone else the clock is ticking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)

type Deposit = { player: Player, amount: number, at: number }

local settings = Config.TeamCombo

local TeamCombo = {}

local recent: { Deposit } = {}

-- Call after each deposit. Returns the extra that counts toward the quota (0 most of the time).
function TeamCombo.deposited(player: Player, amount: number): number
	local members = RosterService.active()
	if #members < 2 then
		table.clear(recent)
		return 0
	end
	local now = os.clock()
	for index = #recent, 1, -1 do
		if now - recent[index].at > settings.Seconds then
			table.remove(recent, index)
		end
	end
	if #recent == 0 then
		Notifier.others(
			player,
			`{player.DisplayName} just banked! Everyone bank within {settings.Seconds}s for a team combo.`,
			"Info"
		)
	end
	table.insert(recent, { player = player, amount = amount, at = now })

	local total = 0
	local banked: { [Player]: boolean } = {}
	for _, deposit in recent do
		banked[deposit.player] = true
		total += deposit.amount
	end
	for _, member in members do
		if not banked[member.player] then
			return 0
		end
	end
	table.clear(recent)
	local bonus = math.floor(total * settings.Bonus + 0.5)
	for _, member in members do
		Juice.deposited(member.player, bonus, "Team combo bonus")
	end
	return bonus
end

return TeamCombo
