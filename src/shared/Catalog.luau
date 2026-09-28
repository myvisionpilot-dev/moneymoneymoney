--!strict
-- Every cosmetic and badge: names, slots and looks. Prices and badge thresholds live in Config.
-- Cosmetics are bought with Cred at fixed prices: nothing random, nothing that helps you win.

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

export type Slot = "Paint" | "Trail" | "Title" | "Hat"
export type HatStyle = "Cap" | "TopHat" | "Crown"

export type Cosmetic = {
	id: string,
	name: string,
	slot: Slot,
	colors: { Color3 }, -- paint and hats: [1]; trails: gradient stops; titles: text colour
	text: string?, -- titles only
	hat: HatStyle?, -- hats only
}

export type Badge = {
	id: string,
	name: string,
	text: string,
}

local Catalog = {}

Catalog.Slots = { "Paint", "Trail", "Title", "Hat" } :: { Slot }

Catalog.SlotNames = {
	Paint = "Kart paint",
	Trail = "Trail",
	Title = "Title",
	Hat = "Hat",
} :: { [string]: string }

Catalog.Cosmetics = {
	{ id = "paint_cherry", name = "Cherry Red", slot = "Paint", colors = { Color3.fromRGB(220, 40, 50) } },
	{ id = "paint_ocean", name = "Ocean Blue", slot = "Paint", colors = { Color3.fromRGB(40, 110, 220) } },
	{ id = "paint_lime", name = "Lime Zest", slot = "Paint", colors = { Color3.fromRGB(140, 220, 60) } },
	{ id = "paint_midnight", name = "Midnight", slot = "Paint", colors = { Color3.fromRGB(30, 30, 45) } },
	{ id = "paint_gold", name = "Gold Rush", slot = "Paint", colors = { Color3.fromRGB(255, 196, 50) } },
	{
		id = "trail_cash",
		name = "Cash Trail",
		slot = "Trail",
		colors = { Color3.fromRGB(80, 200, 105), Color3.fromRGB(200, 255, 200) },
	},
	{
		id = "trail_fire",
		name = "Hot Streak",
		slot = "Trail",
		colors = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(235, 60, 30) },
	},
	{
		id = "trail_rainbow",
		name = "Rainbow",
		slot = "Trail",
		colors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 200, 40),
			Color3.fromRGB(80, 220, 90),
			Color3.fromRGB(60, 140, 255),
			Color3.fromRGB(180, 80, 255),
		},
	},
	{
		id = "title_hustler",
		name = "Hustler",
		slot = "Title",
		text = "Hustler",
		colors = { Color3.fromRGB(200, 200, 200) },
	},
	{
		id = "title_bigshot",
		name = "Big Shot",
		slot = "Title",
		text = "Big Shot",
		colors = { Color3.fromRGB(95, 160, 245) },
	},
	{
		id = "title_favourite",
		name = "Tony's Favourite",
		slot = "Title",
		text = "Tony's Favourite",
		colors = { Color3.fromRGB(80, 200, 105) },
	},
	{
		id = "title_kingpin",
		name = "Kingpin",
		slot = "Title",
		text = "Kingpin",
		colors = { Color3.fromRGB(255, 196, 50) },
	},
	{ id = "hat_cap", name = "Delivery Cap", slot = "Hat", hat = "Cap", colors = { Color3.fromRGB(200, 120, 50) } },
	{ id = "hat_tophat", name = "Top Hat", slot = "Hat", hat = "TopHat", colors = { Color3.fromRGB(30, 30, 35) } },
	{ id = "hat_crown", name = "Crown", slot = "Hat", hat = "Crown", colors = { Color3.fromRGB(255, 196, 50) } },
} :: { Cosmetic }

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

local cosmeticsById: { [string]: Cosmetic } = {}
for _, item in Catalog.Cosmetics do
	cosmeticsById[item.id] = item
end

local badgesById: { [string]: Badge } = {}
for _, badge in Catalog.Badges do
	badgesById[badge.id] = badge
end

function Catalog.cosmetic(id: string): Cosmetic?
	return cosmeticsById[id]
end

function Catalog.badge(id: string): Badge?
	return badgesById[id]
end

function Catalog.price(id: string): number?
	return Config.Cosmetics.Prices[id]
end

return Catalog
