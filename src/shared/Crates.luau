--!strict
-- Tony's lucky crates and what comes out of them: names, a line on what each prize does and the
-- ItemModels picture each one shows. Prices, odds and which prizes are in each rarity live in
-- Config.Crates; the server rolls and hands them out (server/CrateService).

local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)

export type Tier = Cosmetics.Tier

export type Kind = {
	id: string,
	price: number,
	odds: { [string]: number }, -- by rarity
}

export type Prize = {
	id: string,
	title: string,
	text: string,
	picture: string, -- ItemModels id
}

local Crates = {}

Crates.Tiers = { "Common", "Rare", "Epic", "Legendary" } :: { Tier }
Crates.TierColors = (Cosmetics.TierColors :: any) :: { [string]: Color3 }

Crates.Names = {
	LuckyCrate = "Lucky Crate",
	GoldCrate = "Gold Crate",
	DiamondCrate = "Diamond Crate",
} :: { [string]: string }

local PRIZES: { Prize } = {
	{ id = "Candy", title = "Candy Bar", text = "Wider pickpocket zone", picture = "Candy" },
	{ id = "Energy", title = "Energy Drink", text = "2x speed when you drink it", picture = "Energy" },
	{ id = "Gloves", title = "Gloves", text = "Quicker break-ins", picture = "Gloves" },
	{ id = "Disguise", title = "Disguise", text = "Half the heat", picture = "Disguise" },
	{ id = "Scanner", title = "Police Scanner", text = "See every cop", picture = "Scanner" },
	{ id = "SnackPack", title = "Snack Pack", text = "Candy, gloves and a drink", picture = "Candy" },
	{ id = "BagUp", title = "Bigger Bag", text = "Your bag goes up a size", picture = "Bag" },
	{ id = "LockpickUp", title = "Better Lockpick", text = "Your lockpick levels up", picture = "Lockpick" },
	{ id = "TreatPack", title = "Treat Pack", text = "Every treat at once", picture = "Scanner" },
	{ id = "MaxBag", title = "Biggest Bag", text = "The biggest bag there is", picture = "Bag" },
	{ id = "Jackpot", title = "JACKPOT", text = "Every treat and upgrade", picture = "GoldCrate" },
}

local prizes: { [string]: Prize } = {}
for _, prize in PRIZES do
	prizes[prize.id] = prize
end

function Crates.prize(id: string): Prize?
	return prizes[id]
end

function Crates.kind(id: string): Kind?
	for _, kind in Config.Crates.Kinds :: any do
		if kind.id == id then
			return kind :: Kind
		end
	end
	return nil
end

-- Which rarity a prize is.
function Crates.tierOf(prizeId: string): Tier?
	for tier, list in Config.Crates.Prizes :: { [string]: { string } } do
		if table.find(list, prizeId) then
			return tier :: Tier
		end
	end
	return nil
end

-- A crate's odds, one rarity a line (rarities it can't give left out), for its shop card.
-- `colored` wraps each rarity in its colour (RichText).
function Crates.oddsText(kind: Kind, colored: boolean?): string
	local lines: { string } = {}
	for _, each in Crates.Tiers do
		local tier = each :: Tier
		local chance = kind.odds[tier] or 0
		if chance > 0 then
			local name = if colored then `<font color="#{Crates.TierColors[tier]:ToHex()}">{tier}</font>` else tier
			table.insert(lines, `{name} {chance}%`)
		end
	end
	return table.concat(lines, "\n")
end

return Crates
