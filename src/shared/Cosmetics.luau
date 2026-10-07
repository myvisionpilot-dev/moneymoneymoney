--!strict
-- Every cosmetic in the Cred shop: how it looks, nothing it does. Each one fills a slot, and
-- you wear one per slot (or none):
--   Paint  the race cars you drive                      Glow   a neon light under them
--   Trail  a streak behind you as you move (both places) Aura   sparkles, flames... round you (both places)
--   Bag    a bag you carry in a run that swells as it fills
--   Blaster  a custom look for the blaster in your hand   Zap    the colour of your blaster's beam
--   Burst  a shower of sparkles when you bank cash
-- What trails, auras and bursts throw out (their particles) lives in shared/CosmeticFx.
-- Prices come from Config.CredShop.Tiers by rarity.

local Config = require(script.Parent.Config)

export type Slot = "Paint" | "Glow" | "Trail" | "Aura" | "Bag" | "Blaster" | "Zap" | "Burst"
export type Tier = "Common" | "Rare" | "Epic" | "Legendary"

export type Item = {
	id: string,
	slot: Slot,
	name: string,
	tier: Tier,
	color: Color3, -- the main colour: paint body, glow, beam, card
	trim: Color3?, -- paint: bumpers, seat and frame
	colors: { Color3 }?, -- trail and burst: the colours it runs through
	material: Enum.Material?, -- paint
	reflectance: number?, -- paint
	neon: boolean?, -- paint: the trim glows
	rainbow: boolean?, -- glow, zap, trail: every colour in turn
	model: string?, -- bag: its shared/BagLooks design; blaster: its shared/BlasterLooks design
}

local Cosmetics = {}

Cosmetics.Slots = {
	{ slot = "Paint" :: Slot, name = "Paint", text = "The race cars you drive." },
	{ slot = "Glow" :: Slot, name = "Underglow", text = "A neon light under your rides." },
	{ slot = "Trail" :: Slot, name = "Trails", text = "A streak behind you everywhere you go." },
	{ slot = "Aura" :: Slot, name = "Auras", text = "Sparkles, flames and more round you, everywhere you go." },
	{ slot = "Bag" :: Slot, name = "Bags", text = "Slung over your shoulder in a run. It swells as it fills." },
	{ slot = "Blaster" :: Slot, name = "Blasters", text = "Your blaster's look, whichever one you buy from Tony." },
	{ slot = "Zap" :: Slot, name = "Zap Colours", text = "Your blaster's beam." },
	{ slot = "Burst" :: Slot, name = "Bank Bursts", text = "A shower of sparkles when you deposit." },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local RAINBOW = {
	rgb(255, 70, 70),
	rgb(255, 170, 40),
	rgb(255, 235, 60),
	rgb(80, 220, 90),
	rgb(60, 160, 255),
	rgb(170, 90, 255),
}

Cosmetics.Items = {
	-- Paint ------------------------------------------------------------------------------
	{ id = "CherryRed", slot = "Paint", name = "Cherry Red", tier = "Common", color = rgb(220, 40, 50) },
	{ id = "OceanBlue", slot = "Paint", name = "Ocean Blue", tier = "Common", color = rgb(40, 110, 220) },
	{ id = "LimeGreen", slot = "Paint", name = "Lime Green", tier = "Common", color = rgb(110, 210, 60) },
	{ id = "SunsetOrange", slot = "Paint", name = "Sunset Orange", tier = "Common", color = rgb(245, 130, 40) },
	{ id = "Bubblegum", slot = "Paint", name = "Bubblegum", tier = "Common", color = rgb(245, 120, 190) },
	{
		id = "Midnight",
		slot = "Paint",
		name = "Midnight",
		tier = "Common",
		color = rgb(30, 30, 38),
		trim = rgb(110, 110, 120),
	},
	{ id = "Snow", slot = "Paint", name = "Snow", tier = "Common", color = rgb(240, 240, 245), trim = rgb(60, 60, 70) },
	{ id = "CabYellow", slot = "Paint", name = "Cab Yellow", tier = "Common", color = rgb(255, 205, 40) },
	{
		id = "PoliceIssue",
		slot = "Paint",
		name = "Police Issue",
		tier = "Rare",
		color = rgb(240, 240, 240),
		trim = rgb(25, 25, 30),
	},
	{
		id = "MintRacer",
		slot = "Paint",
		name = "Mint Racer",
		tier = "Rare",
		color = rgb(150, 230, 200),
		trim = rgb(250, 250, 250),
	},
	{
		id = "GrapeSoda",
		slot = "Paint",
		name = "Grape Soda",
		tier = "Rare",
		color = rgb(130, 60, 200),
		trim = rgb(170, 240, 60),
	},
	{
		id = "Woodie",
		slot = "Paint",
		name = "Woodie",
		tier = "Rare",
		color = rgb(160, 110, 70),
		trim = rgb(60, 40, 30),
		material = Enum.Material.WoodPlanks,
	},
	{
		id = "Chrome",
		slot = "Paint",
		name = "Chrome",
		tier = "Epic",
		color = rgb(205, 210, 220),
		trim = rgb(60, 60, 70),
		material = Enum.Material.Metal,
		reflectance = 0.45,
	},
	{
		id = "Carbon",
		slot = "Paint",
		name = "Carbon",
		tier = "Epic",
		color = rgb(45, 45, 50),
		trim = rgb(220, 40, 50),
		material = Enum.Material.Fabric,
	},
	{
		id = "NeonNights",
		slot = "Paint",
		name = "Neon Nights",
		tier = "Epic",
		color = rgb(25, 20, 35),
		trim = rgb(255, 60, 200),
		neon = true,
	},
	{
		id = "Frostbite",
		slot = "Paint",
		name = "Frostbite",
		tier = "Epic",
		color = rgb(180, 220, 255),
		trim = rgb(240, 250, 255),
		material = Enum.Material.Ice,
	},
	{
		id = "SolidGold",
		slot = "Paint",
		name = "Solid Gold",
		tier = "Legendary",
		color = rgb(240, 195, 60),
		trim = rgb(170, 130, 40),
		material = Enum.Material.Metal,
		reflectance = 0.35,
	},
	{
		id = "Diamond",
		slot = "Paint",
		name = "Diamond",
		tier = "Legendary",
		color = rgb(200, 240, 255),
		trim = rgb(255, 255, 255),
		material = Enum.Material.Glass,
		reflectance = 0.5,
	},
	{
		id = "Lava",
		slot = "Paint",
		name = "Lava",
		tier = "Legendary",
		color = rgb(70, 35, 30),
		trim = rgb(255, 110, 30),
		material = Enum.Material.CrackedLava,
		neon = true,
	},
	-- Underglow --------------------------------------------------------------------------
	{ id = "GlowRed", slot = "Glow", name = "Red Glow", tier = "Common", color = rgb(255, 50, 60) },
	{ id = "GlowBlue", slot = "Glow", name = "Blue Glow", tier = "Common", color = rgb(50, 130, 255) },
	{ id = "GlowGreen", slot = "Glow", name = "Green Glow", tier = "Common", color = rgb(60, 240, 110) },
	{ id = "GlowPink", slot = "Glow", name = "Pink Glow", tier = "Common", color = rgb(255, 80, 200) },
	{ id = "GlowYellow", slot = "Glow", name = "Yellow Glow", tier = "Common", color = rgb(255, 220, 50) },
	{ id = "GlowWhite", slot = "Glow", name = "White Glow", tier = "Rare", color = rgb(240, 245, 255) },
	{ id = "GlowPurple", slot = "Glow", name = "Purple Glow", tier = "Rare", color = rgb(160, 80, 255) },
	{
		id = "GlowRainbow",
		slot = "Glow",
		name = "Rainbow Glow",
		tier = "Epic",
		color = rgb(255, 120, 60),
		rainbow = true,
	},
	-- Trails -----------------------------------------------------------------------------
	{
		id = "TrailSky",
		slot = "Trail",
		name = "Sky",
		tier = "Common",
		color = rgb(140, 200, 255),
		colors = { rgb(140, 200, 255), rgb(255, 255, 255) },
	},
	{
		id = "TrailMint",
		slot = "Trail",
		name = "Mint",
		tier = "Common",
		color = rgb(120, 230, 180),
		colors = { rgb(120, 230, 180), rgb(230, 255, 240) },
	},
	{
		id = "TrailPeach",
		slot = "Trail",
		name = "Peach",
		tier = "Common",
		color = rgb(255, 180, 140),
		colors = { rgb(255, 180, 140), rgb(255, 235, 210) },
	},
	{
		id = "TrailFire",
		slot = "Trail",
		name = "Fire",
		tier = "Rare",
		color = rgb(255, 120, 30),
		colors = { rgb(255, 230, 80), rgb(255, 120, 30), rgb(220, 30, 30) },
	},
	{
		id = "TrailIce",
		slot = "Trail",
		name = "Ice",
		tier = "Rare",
		color = rgb(150, 220, 255),
		colors = { rgb(255, 255, 255), rgb(150, 220, 255), rgb(60, 120, 230) },
	},
	{
		id = "TrailToxic",
		slot = "Trail",
		name = "Toxic",
		tier = "Rare",
		color = rgb(150, 240, 50),
		colors = { rgb(220, 255, 80), rgb(80, 220, 40), rgb(30, 120, 30) },
	},
	{
		id = "TrailSunset",
		slot = "Trail",
		name = "Sunset",
		tier = "Epic",
		color = rgb(255, 120, 150),
		colors = { rgb(255, 220, 80), rgb(255, 110, 150), rgb(130, 70, 200) },
	},
	{
		id = "TrailOcean",
		slot = "Trail",
		name = "Ocean",
		tier = "Epic",
		color = rgb(40, 170, 220),
		colors = { rgb(120, 240, 255), rgb(40, 150, 220), rgb(20, 40, 120) },
	},
	{
		id = "TrailCandy",
		slot = "Trail",
		name = "Candy",
		tier = "Epic",
		color = rgb(255, 140, 210),
		colors = { rgb(255, 120, 200), rgb(255, 255, 255), rgb(255, 120, 200) },
	},
	{
		id = "TrailRainbow",
		slot = "Trail",
		name = "Rainbow",
		tier = "Legendary",
		color = rgb(255, 120, 60),
		colors = RAINBOW,
	},
	{
		id = "TrailGold",
		slot = "Trail",
		name = "Gold Rush",
		tier = "Legendary",
		color = rgb(255, 205, 60),
		colors = { rgb(255, 245, 180), rgb(255, 200, 40), rgb(255, 245, 180) },
	},
	{
		id = "TrailBubbles",
		slot = "Trail",
		name = "Bubbles",
		tier = "Rare",
		color = rgb(150, 220, 255),
		colors = { rgb(200, 245, 255), rgb(120, 200, 255) },
	},
	{
		id = "TrailShadow",
		slot = "Trail",
		name = "Shadow",
		tier = "Rare",
		color = rgb(70, 60, 90),
		colors = { rgb(90, 70, 120), rgb(20, 15, 30) },
	},
	{
		id = "TrailMoney",
		slot = "Trail",
		name = "Money Trail",
		tier = "Epic",
		color = rgb(90, 210, 90),
		colors = { rgb(180, 255, 150), rgb(60, 180, 70), rgb(20, 110, 40) },
	},
	{
		id = "TrailLightning",
		slot = "Trail",
		name = "Lightning",
		tier = "Epic",
		color = rgb(110, 200, 255),
		colors = { rgb(255, 255, 255), rgb(110, 200, 255), rgb(60, 90, 255) },
	},
	{
		id = "TrailSnow",
		slot = "Trail",
		name = "Snowfall",
		tier = "Epic",
		color = rgb(220, 240, 255),
		colors = { rgb(255, 255, 255), rgb(190, 225, 255) },
	},
	{
		id = "TrailInferno",
		slot = "Trail",
		name = "Inferno",
		tier = "Legendary",
		color = rgb(255, 100, 30),
		colors = { rgb(255, 240, 120), rgb(255, 110, 20), rgb(170, 20, 20) },
	},
	{
		id = "TrailGalaxy",
		slot = "Trail",
		name = "Galaxy",
		tier = "Legendary",
		color = rgb(130, 80, 255),
		colors = { rgb(255, 140, 255), rgb(120, 70, 255), rgb(20, 20, 90) },
	},
	{
		id = "TrailCoins",
		slot = "Trail",
		name = "Coin Shower",
		tier = "Legendary",
		color = rgb(255, 210, 60),
		colors = { rgb(255, 250, 200), rgb(255, 205, 50), rgb(200, 130, 20) },
	},
	-- Auras ------------------------------------------------------------------------------
	{ id = "AuraSparkle", slot = "Aura", name = "Sparkle Aura", tier = "Common", color = rgb(255, 240, 170) },
	{ id = "AuraBubbles", slot = "Aura", name = "Bubble Aura", tier = "Common", color = rgb(150, 220, 255) },
	{ id = "AuraHearts", slot = "Aura", name = "Sweetheart", tier = "Rare", color = rgb(255, 110, 170) },
	{ id = "AuraToxic", slot = "Aura", name = "Toxic Aura", tier = "Rare", color = rgb(140, 240, 60) },
	{ id = "AuraFlame", slot = "Aura", name = "Flame Aura", tier = "Epic", color = rgb(255, 120, 30) },
	{ id = "AuraFrost", slot = "Aura", name = "Frost Aura", tier = "Epic", color = rgb(150, 220, 255) },
	{ id = "AuraMoney", slot = "Aura", name = "Money Aura", tier = "Epic", color = rgb(90, 210, 90) },
	{ id = "AuraStorm", slot = "Aura", name = "Storm Aura", tier = "Legendary", color = rgb(100, 180, 255) },
	{ id = "AuraGolden", slot = "Aura", name = "Golden Aura", tier = "Legendary", color = rgb(255, 210, 60) },
	{ id = "AuraGalaxy", slot = "Aura", name = "Galaxy Aura", tier = "Legendary", color = rgb(150, 90, 255) },
	-- Bags -------------------------------------------------------------------------------
	{ id = "BagSack", slot = "Bag", name = "Money Sack", tier = "Rare", color = rgb(190, 150, 100), model = "Sack" },
	{ id = "BagDuffel", slot = "Bag", name = "Duffel Bag", tier = "Rare", color = rgb(36, 36, 40), model = "Bag" },
	{
		id = "BagBackpack",
		slot = "Bag",
		name = "Backpack",
		tier = "Rare",
		color = rgb(60, 120, 220),
		model = "Backpack",
	},
	{
		id = "BagBriefcase",
		slot = "Bag",
		name = "Briefcase",
		tier = "Epic",
		color = rgb(110, 70, 40),
		model = "Briefcase",
	},
	{
		id = "BagPiggy",
		slot = "Bag",
		name = "Piggy Bank",
		tier = "Epic",
		color = rgb(255, 150, 190),
		model = "PiggyBank",
	},
	{ id = "BagSafe", slot = "Bag", name = "Mini Safe", tier = "Epic", color = rgb(90, 95, 105), model = "MiniSafe" },
	{
		id = "BagGold",
		slot = "Bag",
		name = "Gold Sack",
		tier = "Legendary",
		color = rgb(240, 195, 60),
		model = "GoldSack",
	},
	-- Blasters ---------------------------------------------------------------------------
	{
		id = "SquirtZapper",
		slot = "Blaster",
		name = "Squirt Zapper",
		tier = "Common",
		color = rgb(255, 140, 40),
		model = "SquirtZapper",
	},
	{
		id = "ToyBrick",
		slot = "Blaster",
		name = "Toy Brick",
		tier = "Common",
		color = rgb(220, 40, 45),
		model = "ToyBrick",
	},
	{
		id = "RetroRay",
		slot = "Blaster",
		name = "Retro Ray",
		tier = "Rare",
		color = rgb(220, 50, 50),
		model = "RetroRay",
	},
	{
		id = "HairDryer",
		slot = "Blaster",
		name = "Hair Dryer",
		tier = "Rare",
		color = rgb(250, 150, 200),
		model = "HairDryer",
	},
	{
		id = "NeonRipper",
		slot = "Blaster",
		name = "Neon Ripper",
		tier = "Epic",
		color = rgb(255, 40, 80),
		model = "NeonRipper",
	},
	{
		id = "GoldPlated",
		slot = "Blaster",
		name = "Gold Plated",
		tier = "Legendary",
		color = rgb(240, 196, 60),
		model = "GoldPlated",
	},
	-- Zap colours ------------------------------------------------------------------------
	{ id = "ZapLime", slot = "Zap", name = "Lime Zap", tier = "Common", color = rgb(150, 255, 60) },
	{ id = "ZapPink", slot = "Zap", name = "Pink Zap", tier = "Common", color = rgb(255, 90, 210) },
	{ id = "ZapOrange", slot = "Zap", name = "Orange Zap", tier = "Common", color = rgb(255, 150, 40) },
	{ id = "ZapGold", slot = "Zap", name = "Gold Zap", tier = "Rare", color = rgb(255, 215, 60) },
	{ id = "ZapPurple", slot = "Zap", name = "Purple Zap", tier = "Rare", color = rgb(170, 90, 255) },
	{ id = "ZapRainbow", slot = "Zap", name = "Rainbow Zap", tier = "Epic", color = rgb(255, 120, 60), rainbow = true },
	-- Bank bursts ------------------------------------------------------------------------
	{
		id = "BurstCoins",
		slot = "Burst",
		name = "Gold Coins",
		tier = "Rare",
		color = rgb(255, 205, 50),
		colors = { rgb(255, 225, 90), rgb(230, 170, 30) },
	},
	{
		id = "BurstConfetti",
		slot = "Burst",
		name = "Confetti",
		tier = "Rare",
		color = rgb(255, 100, 150),
		colors = { rgb(255, 90, 120), rgb(80, 180, 255), rgb(255, 220, 60), rgb(120, 230, 100) },
	},
	{
		id = "BurstBills",
		slot = "Burst",
		name = "Green Bills",
		tier = "Rare",
		color = rgb(90, 210, 90),
		colors = { rgb(140, 230, 120), rgb(50, 160, 70) },
	},
	{
		id = "BurstHearts",
		slot = "Burst",
		name = "Hearts",
		tier = "Rare",
		color = rgb(255, 90, 140),
		colors = { rgb(255, 120, 170), rgb(230, 40, 90) },
	},
	{
		id = "BurstFireworks",
		slot = "Burst",
		name = "Fireworks",
		tier = "Epic",
		color = rgb(160, 120, 255),
		colors = RAINBOW,
	},
	{
		id = "BurstStars",
		slot = "Burst",
		name = "Shooting Stars",
		tier = "Rare",
		color = rgb(255, 240, 150),
		colors = { rgb(255, 255, 255), rgb(255, 230, 120) },
	},
	{
		id = "BurstFrost",
		slot = "Burst",
		name = "Frost Nova",
		tier = "Epic",
		color = rgb(150, 220, 255),
		colors = { rgb(255, 255, 255), rgb(150, 220, 255) },
	},
	{
		id = "BurstInferno",
		slot = "Burst",
		name = "Inferno",
		tier = "Epic",
		color = rgb(255, 110, 30),
		colors = { rgb(255, 230, 90), rgb(255, 110, 30), rgb(200, 30, 20) },
	},
	{
		id = "BurstGalaxy",
		slot = "Burst",
		name = "Galaxy",
		tier = "Legendary",
		color = rgb(150, 90, 255),
		colors = { rgb(255, 150, 255), rgb(140, 90, 255), rgb(60, 170, 255) },
	},
	{
		id = "BurstThunder",
		slot = "Burst",
		name = "Thunder",
		tier = "Legendary",
		color = rgb(110, 200, 255),
		colors = { rgb(255, 255, 255), rgb(110, 200, 255), rgb(70, 90, 255) },
	},
	{
		id = "BurstStorm",
		slot = "Burst",
		name = "Money Storm",
		tier = "Legendary",
		color = rgb(240, 200, 60),
		colors = { rgb(255, 220, 70), rgb(90, 210, 90), rgb(255, 255, 255) },
	},
} :: { Item }

Cosmetics.TierColors = {
	Common = rgb(70, 150, 230),
	Rare = rgb(60, 175, 90),
	Epic = rgb(165, 85, 235),
	Legendary = rgb(240, 170, 30),
} :: { [Tier]: Color3 }

Cosmetics.Rainbow = RAINBOW

local byId: { [string]: Item } = {}
for _, item in Cosmetics.Items do
	byId[item.id] = item
end

function Cosmetics.get(id: string): Item?
	return byId[id]
end

function Cosmetics.price(item: Item): number
	return Config.CredShop.Tiers[item.tier]
end

-- A trail's (or burst's) colours as a ColorSequence.
function Cosmetics.sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

-- Paints a vehicle body from VehicleModels (or a car picture from ItemModels): panels marked
-- Paint (or Role "body") get the colour and finish, the trim (Role "trim", bumpers, the seat
-- frame) gets the trim colour.
local TRIM_NAMES = { Chassis = true, FrontBar = true, RearBar = true, Bumper = true, Grille = true }
function Cosmetics.paint(model: Instance, item: Item)
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local role = part:GetAttribute("Role")
		if part:GetAttribute("Paint") or role == "body" then
			part.Color = item.color
			part.Material = item.material or Enum.Material.SmoothPlastic
			part.Reflectance = item.reflectance or 0
		elseif (TRIM_NAMES[part.Name] or role == "trim") and item.trim then
			part.Color = item.trim
			part.Material = if item.neon then Enum.Material.Neon else part.Material
		end
	end
end

return Cosmetics
