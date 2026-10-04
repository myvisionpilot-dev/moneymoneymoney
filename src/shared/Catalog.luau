--!strict
-- The speed shop's perks and every badge: names and descriptions. Prices, levels and badge
-- thresholds live in Config. Perks are bought with Cred at fixed prices: nothing random.

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

export type PerkId = "Speed"

export type Perk = {
	id: PerkId,
	name: string,
	text: string, -- what one level does
}

export type Badge = {
	id: string,
	name: string,
	text: string,
}

local Catalog = {}

Catalog.Perks = {
	{
		id = "Speed",
		name = "Speed Buff",
		text = `Walk and sprint {Config.Perks.Speed.PerLevel}x faster per level. Yours for good.`,
	},
} :: { Perk }

local badges = Config.Badges
Catalog.Badges = {
	{ id = "FirstRun", name = "First Payday", text = "Finish your first run" },
	{ id = "GettingSerious", name = "Getting Serious", text = `Clear quota {badges.GettingSeriousQuota}` },
	{ id = "PaidInFull", name = "Paid in Full", text = `Clear quota {Config.Match.CashOutAfterQuota}` },
	{ id = "InTooDeep", name = "In Too Deep", text = "Clear an endless quota" },
	{ id = "Snake", name = "The Snake", text = "Steal the most in a run" },
	{ id = "TopEarner", name = "Top Earner", text = `Deposit the most in a run of {badges.MvpMinPlayers}+ players` },
	{ id = "SpeedDemon", name = "Speed Demon", text = "Win a race or set a gold time" },
	{ id = "NowYouSeeMe", name = "Now You See Me", text = "Lose the police in a bush" },
	{ id = "LawAndOrder", name = "Law and Order", text = "Claim a bounty" },
	{ id = "HotWheels", name = "Hot Wheels", text = "Sell a car to the chop shop" },
	{ id = "Regular", name = "Regular", text = `Keep a {badges.RegularStreakDays}-day streak` },
	{ id = "Loaded", name = "Loaded", text = `Earn {Format.number(badges.LoadedCred)} Cred in total` },
} :: { Badge }

local badgesById: { [string]: Badge } = {}
for _, badge in Catalog.Badges do
	badgesById[badge.id] = badge
end

function Catalog.perk(id: string): Perk?
	for _, perk in Catalog.Perks do
		if perk.id == id then
			return perk
		end
	end
	return nil
end

function Catalog.badge(id: string): Badge?
	return badgesById[id]
end

-- What the next level of a perk costs, or nil once it's maxed.
function Catalog.perkPrice(id: PerkId, currentLevel: number): number?
	if id == "Speed" then
		return Config.Perks.Speed.Prices[currentLevel + 1]
	end
	return nil
end

function Catalog.perkMaxLevel(id: PerkId): number
	return if id == "Speed" then #Config.Perks.Speed.Prices else 0
end

-- The on-foot speed multiplier a Speed level gives.
function Catalog.speedMultiplier(level: number): number
	return 1 + Config.Perks.Speed.PerLevel * level
end

return Catalog
