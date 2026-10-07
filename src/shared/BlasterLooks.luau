--!strict
-- What the stun blasters look like: Tony's two (Zapper, Mega Zapper) and the custom blasters
-- sold in the lobby's CUSTOMISATION window. Each design is a list of pieces in the blaster's
-- own space: -Z out of the muzzle, +Y up, origin in the middle of the body, and the hand
-- closes round (0, -0.3, 0.4) on the grip. Roles: "body" and "trim" are its colours, "glow" is
-- neon (a zap colour cosmetic recolours it).
-- Used for the blaster in your hand (BlasterService), the shop pictures (ItemModels) and the
-- blasters on Tony's wall (the town builder).

export type Piece = {
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	role: string?, -- "body", "trim" or "glow"
	reflectance: number?,
	transparency: number?,
	name: string?, -- the part's name (a bag's strap clips)
}

local BlasterLooks = {}

local ALONG = CFrame.Angles(0, math.rad(90), 0) -- cylinders lie along X; this points them down the barrel
local UP = CFrame.Angles(0, 0, math.rad(90)) -- and this stands them up
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function grip(color: Color3, size: Vector3?, at: CFrame?): Piece
	return {
		size = size or Vector3.new(0.5, 1.05, 0.55),
		at = at or CFrame.new(0, -0.8, 0.5) * CFrame.Angles(math.rad(-15), 0, 0),
		color = color,
		role = "trim",
	}
end

-- Tony's everyday blaster: a sleek body, a metal barrel wrapped in two glowing coils, a glowing
-- cell in the side and an orb at the muzzle. Also the base of the Gold Plated custom blaster.
local function zapper(body: Color3, trim: Color3, glow: Color3, shiny: number?): { Piece }
	return {
		{
			size = Vector3.new(0.72, 0.78, 1.9),
			at = CFrame.new(0, 0, 0.05),
			color = body,
			role = "body",
			material = if shiny then METAL else nil,
			reflectance = shiny,
		},
		{ size = Vector3.new(0.5, 0.22, 1.5), at = CFrame.new(0, 0.5, 0.15), color = trim, role = "trim" },
		{
			size = Vector3.new(1.1, 0.6, 0.6),
			at = CFrame.new(0, 0.08, -1.35) * ALONG,
			color = trim,
			role = "trim",
			material = METAL,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.12, 0.78, 0.78),
			at = CFrame.new(0, 0.08, -1.05) * ALONG,
			color = glow,
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.12, 0.78, 0.78),
			at = CFrame.new(0, 0.08, -1.5) * ALONG,
			color = glow,
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.one * 0.5,
			at = CFrame.new(0, 0.08, -1.95),
			color = glow,
			role = "glow",
			material = NEON,
			shape = BALL,
		},
		{
			size = Vector3.new(0.78, 0.26, 0.9),
			at = CFrame.new(0, 0.05, 0.35),
			color = glow,
			role = "glow",
			material = NEON,
		},
		grip(trim),
		{ size = Vector3.new(0.14, 0.1, 0.55), at = CFrame.new(0, -0.48, 0), color = trim, role = "trim" },
		{ size = Vector3.new(0.14, 0.32, 0.3), at = CFrame.new(0, 0.77, 0.75), color = body, role = "body" },
	}
end

local DESIGNS: { [string]: { Piece } } = {
	Zapper = zapper(rgb(62, 66, 84), rgb(32, 34, 42), rgb(60, 220, 255)),

	-- Bigger and meaner: a glass tank with a glowing core on top, three coils, a dish muzzle.
	MegaZapper = {
		{ size = Vector3.new(0.95, 1, 2.3), at = CFrame.new(0, 0.05, 0.1), color = rgb(70, 40, 90), role = "body" },
		{
			size = Vector3.new(1.4, 0.6, 0.6),
			at = CFrame.new(0, 0.85, 0.15) * ALONG,
			color = rgb(220, 230, 240),
			material = Enum.Material.Glass,
			shape = CYLINDER,
			transparency = 0.45,
		},
		{
			size = Vector3.new(1.2, 0.28, 0.28),
			at = CFrame.new(0, 0.85, 0.15) * ALONG,
			color = rgb(255, 110, 220),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(1.3, 0.75, 0.75),
			at = CFrame.new(0, 0.05, -1.6) * ALONG,
			color = rgb(35, 30, 45),
			role = "trim",
			material = METAL,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 1, 1),
			at = CFrame.new(0, 0.05, -1.2) * ALONG,
			color = rgb(255, 110, 220),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 1, 1),
			at = CFrame.new(0, 0.05, -1.6) * ALONG,
			color = rgb(255, 110, 220),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 1, 1),
			at = CFrame.new(0, 0.05, -2) * ALONG,
			color = rgb(255, 110, 220),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.15, 1.2, 1.2),
			at = CFrame.new(0, 0.05, -2.35) * ALONG,
			color = rgb(35, 30, 45),
			role = "trim",
			material = METAL,
			shape = CYLINDER,
		},
		{
			size = Vector3.one * 0.6,
			at = CFrame.new(0, 0.05, -2.4),
			color = rgb(255, 110, 220),
			role = "glow",
			material = NEON,
			shape = BALL,
		},
		{
			size = Vector3.new(0.1, 0.5, 0.9),
			at = CFrame.new(-0.53, 0.05, 0.6),
			color = rgb(35, 30, 45),
			role = "trim",
		},
		{ size = Vector3.new(0.1, 0.5, 0.9), at = CFrame.new(0.53, 0.05, 0.6), color = rgb(35, 30, 45), role = "trim" },
		grip(
			rgb(35, 30, 45),
			Vector3.new(0.6, 1.15, 0.6),
			CFrame.new(0, -0.85, 0.6) * CFrame.Angles(math.rad(-15), 0, 0)
		),
		{ size = Vector3.new(0.16, 0.1, 0.6), at = CFrame.new(0, -0.5, 0), color = rgb(35, 30, 45), role = "trim" },
	},

	-- Custom blasters (lobby CUSTOMISATION, shared/Cosmetics slot "Blaster") -------------------

	-- A toy water pistol: bright plastic, a see-through tank on top.
	SquirtZapper = {
		{ size = Vector3.new(0.7, 0.9, 1.6), at = CFrame.new(0, 0, 0.2), color = rgb(255, 140, 40), role = "body" },
		{
			size = Vector3.new(1, 0.32, 0.32),
			at = CFrame.new(0, 0.15, -1.05) * ALONG,
			color = rgb(255, 220, 60),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.2, 0.44, 0.44),
			at = CFrame.new(0, 0.15, -1.6) * ALONG,
			color = rgb(120, 220, 255),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.9, 0.85, 0.85),
			at = CFrame.new(0, 0.9, 0.35) * UP,
			color = rgb(120, 200, 255),
			material = Enum.Material.Glass,
			shape = CYLINDER,
			transparency = 0.3,
		},
		{
			size = Vector3.new(0.2, 0.4, 0.4),
			at = CFrame.new(0, 1.45, 0.35) * UP,
			color = rgb(90, 200, 90),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.5, 0.35, 0.7),
			at = CFrame.new(0, -0.3, -0.75),
			color = rgb(90, 200, 90),
			role = "trim",
		},
		grip(
			rgb(90, 200, 90),
			Vector3.new(0.55, 1.05, 0.55),
			CFrame.new(0, -0.8, 0.55) * CFrame.Angles(math.rad(-15), 0, 0)
		),
		{
			size = Vector3.new(0.15, 0.3, 0.15),
			at = CFrame.new(0, -0.6, 0.05),
			color = rgb(255, 220, 60),
			role = "trim",
		},
	},

	-- Building blocks with studs on top.
	ToyBrick = {
		{ size = Vector3.new(0.8, 0.8, 1.8), at = CFrame.identity, color = rgb(220, 40, 45), role = "body" },
		{ size = Vector3.new(0.6, 0.6, 1), at = CFrame.new(0, 0.1, -1.35), color = rgb(40, 100, 220), role = "trim" },
		{
			size = Vector3.new(0.5, 0.5, 0.3),
			at = CFrame.new(0, 0.1, -2),
			color = rgb(255, 230, 90),
			role = "glow",
			material = NEON,
		},
		{ size = Vector3.new(0.8, 0.4, 1.2), at = CFrame.new(0, 0.6, 0.2), color = rgb(255, 205, 40), role = "trim" },
		{
			size = Vector3.new(0.14, 0.28, 0.28),
			at = CFrame.new(-0.2, 0.87, -0.1) * UP,
			color = rgb(255, 205, 40),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 0.28, 0.28),
			at = CFrame.new(0.2, 0.87, -0.1) * UP,
			color = rgb(255, 205, 40),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 0.28, 0.28),
			at = CFrame.new(-0.2, 0.87, 0.5) * UP,
			color = rgb(255, 205, 40),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.14, 0.28, 0.28),
			at = CFrame.new(0.2, 0.87, 0.5) * UP,
			color = rgb(255, 205, 40),
			role = "trim",
			shape = CYLINDER,
		},
		grip(rgb(60, 170, 70), Vector3.new(0.6, 1, 0.6), CFrame.new(0, -0.85, 0.5)),
	},

	-- A 1950s ray gun: a round red back end, chrome stages and fins, a glowing tip.
	RetroRay = {
		{
			size = Vector3.one * 1.15,
			at = CFrame.new(0, 0.05, 0.45),
			color = rgb(220, 50, 50),
			role = "body",
			shape = BALL,
		},
		{
			size = Vector3.new(1, 0.7, 0.7),
			at = CFrame.new(0, 0.05, -0.3) * ALONG,
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
			reflectance = 0.25,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.12, 0.95, 0.95),
			at = CFrame.new(0, 0.05, -0.1) * ALONG,
			color = rgb(220, 50, 50),
			role = "body",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.12, 0.95, 0.95),
			at = CFrame.new(0, 0.05, -0.45) * ALONG,
			color = rgb(220, 50, 50),
			role = "body",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.6, 0.5, 0.5),
			at = CFrame.new(0, 0.05, -1.05) * ALONG,
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
			reflectance = 0.25,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.5, 0.32, 0.32),
			at = CFrame.new(0, 0.05, -1.55) * ALONG,
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
			reflectance = 0.25,
			shape = CYLINDER,
		},
		{
			size = Vector3.one * 0.42,
			at = CFrame.new(0, 0.05, -1.88),
			color = rgb(120, 255, 140),
			role = "glow",
			material = NEON,
			shape = BALL,
		},
		{
			size = Vector3.new(0.08, 0.6, 0.6),
			at = CFrame.new(0, 0.8, 0.7),
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
		},
		{
			size = Vector3.new(0.6, 0.08, 0.6),
			at = CFrame.new(-0.7, 0.05, 0.7),
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
		},
		{
			size = Vector3.new(0.6, 0.08, 0.6),
			at = CFrame.new(0.7, 0.05, 0.7),
			color = rgb(215, 220, 230),
			role = "trim",
			material = METAL,
		},
		grip(
			rgb(90, 50, 35),
			Vector3.new(0.45, 1, 0.5),
			CFrame.new(0, -0.8, 0.45) * CFrame.Angles(math.rad(-20), 0, 0)
		),
	},

	-- A hair dryer that zaps. Pastel pink, with a glowing nozzle.
	HairDryer = {
		{
			size = Vector3.new(1.4, 1, 1),
			at = CFrame.new(0, 0.1, -0.1) * ALONG,
			color = rgb(250, 150, 200),
			role = "body",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.15, 1.05, 1.05),
			at = CFrame.new(0, 0.1, 0.65) * ALONG,
			color = rgb(245, 245, 245),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.06, 0.8, 0.8),
			at = CFrame.new(0, 0.1, 0.75) * ALONG,
			color = rgb(60, 60, 70),
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.8, 0.55, 0.55),
			at = CFrame.new(0, 0.1, -1.15) * ALONG,
			color = rgb(245, 245, 245),
			role = "trim",
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.12, 0.62, 0.62),
			at = CFrame.new(0, 0.1, -1.6) * ALONG,
			color = rgb(255, 180, 90),
			role = "glow",
			material = NEON,
			shape = CYLINDER,
		},
		grip(
			rgb(250, 150, 200),
			Vector3.new(0.45, 1.25, 0.5),
			CFrame.new(0, -0.85, 0.35) * CFrame.Angles(math.rad(-10), 0, 0)
		),
		{
			size = Vector3.new(0.12, 0.2, 0.2),
			at = CFrame.new(0, -0.55, 0.05),
			color = rgb(255, 180, 90),
			role = "glow",
			material = NEON,
		},
	},

	-- Sharp and black with neon lines, and an orb held between two prongs.
	NeonRipper = {
		{ size = Vector3.new(0.7, 0.75, 2), at = CFrame.new(0, 0, 0.1), color = rgb(25, 25, 30), role = "body" },
		{ size = Vector3.new(0.6, 0.15, 1.6), at = CFrame.new(0, 0.45, 0), color = rgb(55, 55, 65), role = "trim" },
		{
			size = Vector3.new(0.74, 0.08, 1.7),
			at = CFrame.new(0, 0.15, 0.1),
			color = rgb(255, 40, 80),
			role = "glow",
			material = NEON,
		},
		{
			size = Vector3.new(0.74, 0.08, 1.2),
			at = CFrame.new(0, -0.15, 0.3),
			color = rgb(255, 40, 80),
			role = "glow",
			material = NEON,
		},
		{
			size = Vector3.new(0.12, 0.12, 1.1),
			at = CFrame.new(-0.22, 0.1, -1.4),
			color = rgb(55, 55, 65),
			role = "trim",
			material = METAL,
		},
		{
			size = Vector3.new(0.12, 0.12, 1.1),
			at = CFrame.new(0.22, 0.1, -1.4),
			color = rgb(55, 55, 65),
			role = "trim",
			material = METAL,
		},
		{
			size = Vector3.one * 0.4,
			at = CFrame.new(0, 0.1, -1.55),
			color = rgb(255, 40, 80),
			role = "glow",
			material = NEON,
			shape = BALL,
		},
		{
			size = Vector3.new(0.12, 0.5, 0.4),
			at = CFrame.new(0, 0.62, 0.85),
			color = rgb(255, 40, 80),
			role = "glow",
			material = NEON,
		},
		grip(
			rgb(25, 25, 30),
			Vector3.new(0.5, 1.05, 0.55),
			CFrame.new(0, -0.8, 0.55) * CFrame.Angles(math.rad(-20), 0, 0)
		),
	},

	-- Tony's Zapper, plated in gold.
	GoldPlated = zapper(rgb(240, 196, 60), rgb(40, 34, 30), rgb(255, 240, 180), 0.35),
}

-- The pieces of a design (Zapper, MegaZapper, or a custom blaster's id), or nil.
function BlasterLooks.pieces(design: string): { Piece }?
	return DESIGNS[design]
end

-- Every design's id (the shop pictures register these).
function BlasterLooks.designs(): { string }
	local list = {}
	for id in DESIGNS do
		table.insert(list, id)
	end
	return list
end

return BlasterLooks
