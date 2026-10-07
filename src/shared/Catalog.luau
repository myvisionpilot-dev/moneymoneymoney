--!strict
-- The Cred shop's upgrades and unlocks (cosmetics are in Cosmetics) and every badge: names,
-- descriptions and the little 3D picture each card shows. Prices, levels and amounts live in
-- Config.CredShop. Everything is bought with Cred at a fixed price: nothing random.

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

export type Upgrade = {
	id: string,
	name: string,
	picture: string, -- ItemModels id
	effect: (amount: number) -> string, -- what this many levels' worth does, e.g. "+16% bag size"
}

export type Unlock = {
	id: string,
	name: string,
	picture: string,
	text: string,
}

export type Badge = {
	id: string,
	name: string,
	text: string,
}

local Catalog = {}

local UPGRADES = Config.CredShop.Upgrades :: { [string]: { PerLevel: number, Prices: { number } } }

local function percent(amount: number): string
	return `{math.floor(amount * 100 + 0.5)}%`
end

Catalog.Upgrades = {
	{
		id = "Speed",
		name = "Speed Buff",
		picture = "Speed",
		effect = function(amount: number): string
			return `{string.format("%.1f", 1 + amount)}x speed on foot`
		end,
	},
	{
		id = "Pockets",
		name = "Big Pockets", -- (Deep Pockets is a hustle)
		picture = "Bag",
		effect = function(amount: number): string
			return `+{percent(amount)} bag size`
		end,
	},
	{
		id = "HeadStart",
		name = "Head Start",
		picture = "Cash",
		effect = function(amount: number): string
			return `Start runs with +{Format.money(amount)}`
		end,
	},
	{
		id = "SilverTongue",
		name = "Silver Tongue",
		picture = "Mower",
		effect = function(amount: number): string
			return `Honest work pays +{percent(amount)}`
		end,
	},
	{
		id = "SmoothOperator",
		name = "Smooth Operator",
		picture = "Mask",
		effect = function(amount: number): string
			return `Crimes pay +{percent(amount)}`
		end,
	},
	{
		id = "LowProfile",
		name = "Low Profile",
		picture = "Disguise",
		effect = function(amount: number): string
			return `{percent(amount)} less heat from crimes`
		end,
	},
	{
		id = "QuickHands",
		name = "Quick Hands",
		picture = "Gloves",
		effect = function(amount: number): string
			return `Break-ins and robberies {percent(amount)} quicker`
		end,
	},
	{
		id = "Lawyer",
		name = "Good Lawyer",
		picture = "Gavel",
		effect = function(amount: number): string
			return `{amount}s less in jail`
		end,
	},
	{
		id = "Insurance",
		name = "Insurance",
		picture = "Shield",
		effect = function(amount: number): string
			return `Lose {percent(amount)} less when busted`
		end,
	},
	{
		id = "Bargain",
		name = "Bargain Hunter",
		picture = "Tag",
		effect = function(amount: number): string
			return `Town shops {percent(amount)} cheaper`
		end,
	},
	{
		id = "Investor",
		name = "Investor",
		picture = "Coins",
		effect = function(amount: number): string
			return `+{percent(amount)} Cred from every run`
		end,
	},
} :: { Upgrade }

Catalog.Unlocks = {
	{ id = "Toolbelt", name = "Toolbelt", picture = "Lockpick", text = "Start every run with a lockpick." },
	{ id = "Thermos", name = "Thermos", picture = "Energy", text = "Start every run with an energy drink." },
	{
		id = "ZapperLicense",
		name = "Zapper License",
		picture = "Zapper",
		text = "A free Zapper the moment blasters go on sale.",
	},
	{ id = "WideOptions", name = "Wide Options", picture = "Cards", text = "Pick each hustle from 4 instead of 3." },
} :: { Unlock }

local badges = Config.Badges
Catalog.Badges = {
	{ id = "FirstRun", name = "First Payday", text = "Finish your first run" },
	{ id = "GettingSerious", name = "Getting Serious", text = `Clear quota {badges.GettingSeriousQuota}` },
	{ id = "PaidInFull", name = "Paid in Full", text = `Clear quota {#Config.Match.Quotas}` },
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

function Catalog.upgrade(id: string): Upgrade?
	for _, upgrade in Catalog.Upgrades do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

function Catalog.unlock(id: string): Unlock?
	for _, unlock in Catalog.Unlocks do
		if unlock.id == id then
			return unlock
		end
	end
	return nil
end

function Catalog.badge(id: string): Badge?
	return badgesById[id]
end

-- What the next level of an upgrade costs, or nil once it's maxed.
function Catalog.upgradePrice(id: string, currentLevel: number): number?
	local settings = UPGRADES[id]
	return if settings then settings.Prices[currentLevel + 1] else nil
end

function Catalog.upgradeMax(id: string): number
	local settings = UPGRADES[id]
	return if settings then #settings.Prices else 0
end

-- What this many levels of an upgrade add up to (e.g. 0.16 for two levels of Pockets).
function Catalog.upgradeAmount(id: string, level: number): number
	local settings = UPGRADES[id]
	return if settings then settings.PerLevel * level else 0
end

function Catalog.unlockPrice(id: string): number?
	return (Config.CredShop.Unlocks :: { [string]: number })[id]
end

-- The on-foot speed multiplier a Speed level gives.
function Catalog.speedMultiplier(level: number): number
	return 1 + Catalog.upgradeAmount("Speed", level)
end

return Catalog
