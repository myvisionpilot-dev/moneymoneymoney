--!strict
-- What the Cred shop bags look like. Each design is a list of pieces in the bag's own space:
-- -Z is its front, +Y up, origin in the middle of the body. Two pieces are named ClipLeft (-X)
-- and ClipRight (+X): where the strap hooks on when you wear it. Most bags are slung across you
-- on a strap over one shoulder (BagLooks.carry "Sling"); the backpack goes on your back.
-- Used for the shop pictures (ItemModels) and the bag you wear in a run (BagLook).

local BlasterLooks = require(script.Parent.BlasterLooks)

type Piece = BlasterLooks.Piece
export type Carry = "Sling" | "Back"

local BagLooks = {}

local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local LEATHER = Enum.Material.Leather
local RUBBER = Enum.Material.Rubber
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- and this points them front to back
local I = CFrame.identity

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local STEEL = rgb(175, 180, 190)
local GOLD = rgb(240, 195, 60)
local BLACK = rgb(24, 24, 28)

local function add(list: { Piece }, more: { Piece })
	for _, piece in more do
		table.insert(list, piece)
	end
end

-- A box with its four edges along X rounded off: two crossed slabs and a cylinder down each
-- edge. Turn it with `at` to round other edges.
local function rounded(size: Vector3, r: number, at: CFrame, color: Color3, material: Enum.Material?): { Piece }
	local y, z = size.Y / 2 - r, size.Z / 2 - r
	local pieces: { Piece } = {
		{ size = Vector3.new(size.X, size.Y, size.Z - 2 * r), at = at, color = color, material = material },
		{ size = Vector3.new(size.X - 0.02, size.Y - 2 * r, size.Z), at = at, color = color, material = material },
	}
	for _, corner in { Vector2.new(y, z), Vector2.new(-y, z), Vector2.new(y, -z), Vector2.new(-y, -z) } do
		table.insert(pieces, {
			size = Vector3.new(size.X - 0.01, r * 2, r * 2),
			at = at * CFrame.new(0, corner.X, corner.Y),
			color = color,
			material = material,
			shape = CYLINDER,
		})
	end
	return pieces
end

-- Where the strap hooks on.
local function clip(side: number, at: Vector3, size: Vector3, color: Color3): Piece
	return {
		name = if side < 0 then "ClipLeft" else "ClipRight",
		size = size,
		at = CFrame.new(at.X * side, at.Y, at.Z),
		color = color,
		material = METAL,
	}
end

-- A "$" facing -Z, centred on `at`, `tall` high.
local function dollar(at: CFrame, tall: number, color: Color3): { Piece }
	local s = tall / 0.62
	local function bar(x: number, y: number, w: number, h: number, deep: number): Piece
		return { size = Vector3.new(w * s, h * s, deep), at = at * CFrame.new(x * s, y * s, 0), color = color }
	end
	return {
		bar(0, 0.2, 0.34, 0.08, 0.04),
		bar(0, 0, 0.34, 0.08, 0.04),
		bar(0, -0.2, 0.34, 0.08, 0.04),
		bar(0.13, 0.1, 0.08, 0.2, 0.03), -- +X is on your left as you face it
		bar(-0.13, -0.1, 0.08, 0.2, 0.03),
		bar(0, 0, 0.07, 0.62, 0.05),
	}
end

-- A duffel bag like a gym bag: padded body with darker end caps, a zip along the top, two
-- webbing handles held together by a wrap, a zipped front pocket and a clip at each end.
local function duffel(): { Piece }
	local body = rgb(36, 36, 40)
	local cap = rgb(24, 24, 27)
	local webbing = rgb(16, 16, 18)
	local zip = rgb(75, 75, 82)
	local pieces = rounded(Vector3.new(3, 1.5, 1.5), 0.42, I, body, FABRIC)
	for _, side in { -1, 1 } do
		add(pieces, rounded(Vector3.new(0.14, 1.6, 1.6), 0.46, CFrame.new(side * 1.53, 0, 0), cap, FABRIC))
		table.insert(pieces, {
			size = Vector3.new(0.04, 0.55, 0.55),
			at = CFrame.new(side * 1.605, 0, 0),
			color = rgb(90, 90, 98),
			shape = CYLINDER,
		})
		table.insert(pieces, clip(side, Vector3.new(1.56, 0.86, 0), Vector3.new(0.12, 0.3, 0.2), STEEL))
		-- Webbing: down the front and back, round the top edge, up into a handle.
		for _, x in { -0.62, 0.62 } do
			local face = side * 0.77
			table.insert(pieces, { size = Vector3.new(0.26, 0.9, 0.05), at = CFrame.new(x, 0, face), color = webbing })
			table.insert(pieces, {
				size = Vector3.new(0.25, 0.89, 0.89),
				at = CFrame.new(x, 0.33, side * 0.33),
				color = webbing,
				shape = CYLINDER,
			})
			table.insert(pieces, {
				size = Vector3.new(0.24, 0.6, 0.05),
				at = CFrame.new(x, 0.97, side * 0.28) * CFrame.Angles(math.rad(-31 * side), 0, 0),
				color = webbing,
			})
		end
		table.insert(pieces, {
			size = Vector3.new(1.1, 0.22, 0.22),
			at = CFrame.new(0, 1.24, side * 0.13),
			color = webbing,
			material = RUBBER,
			shape = CYLINDER,
		})
	end
	add(pieces, {
		{ size = Vector3.new(0.55, 0.3, 0.52), at = CFrame.new(0, 1.24, 0), color = cap, material = FABRIC },
		{ size = Vector3.new(2.5, 0.05, 0.14), at = CFrame.new(0, 0.765, 0), color = zip, material = METAL },
		{
			size = Vector3.new(0.1, 0.04, 0.26),
			at = CFrame.new(0.95, 0.8, -0.1) * CFrame.Angles(math.rad(-20), 0, 0),
			color = STEEL,
			material = METAL,
		},
		{
			size = Vector3.new(0.1, 0.04, 0.26),
			at = CFrame.new(0.78, 0.8, -0.1) * CFrame.Angles(math.rad(-20), 0, 0),
			color = STEEL,
			material = METAL,
		},
		{
			size = Vector3.new(0.86, 0.62, 0.06),
			at = CFrame.new(0, -0.06, -0.77),
			color = rgb(42, 42, 47),
			material = FABRIC,
		},
		{ size = Vector3.new(0.74, 0.035, 0.03), at = CFrame.new(0, 0.17, -0.805), color = zip, material = METAL },
		{ size = Vector3.new(0.06, 0.16, 0.03), at = CFrame.new(0.3, 0.1, -0.82), color = STEEL, material = METAL },
	})
	return pieces
end

-- A money sack: a pear-shaped bag gathered at the neck, tied with rope, with a $ label.
local function sack(
	cloth: Color3,
	material: Enum.Material,
	rope: Color3,
	label: Color3,
	mark: Color3,
	shine: number?
): { Piece }
	local function puff(size: number, at: CFrame): Piece
		return {
			size = Vector3.one * size,
			at = at,
			color = cloth,
			material = material,
			shape = BALL,
			reflectance = shine,
		}
	end
	local pieces: { Piece } = {
		puff(2.4, I),
		puff(1.9, CFrame.new(0, 0.5, 0)),
		{
			size = Vector3.new(0.55, 0.8, 0.8),
			at = CFrame.new(0, 1.5, 0) * UP,
			color = cloth,
			material = material,
			shape = CYLINDER,
			reflectance = shine,
		},
		puff(0.9, CFrame.new(0, 1.9, 0)),
		{
			size = Vector3.new(0.16, 0.9, 0.9),
			at = CFrame.new(0, 1.55, 0) * UP,
			color = rope,
			material = FABRIC,
			shape = CYLINDER,
		},
		{ size = Vector3.one * 0.26, at = CFrame.new(0.2, 1.55, -0.38), color = rope, material = FABRIC, shape = BALL },
		{
			size = Vector3.new(0.08, 0.45, 0.08),
			at = CFrame.new(0.15, 1.4, -0.51) * CFrame.Angles(math.rad(40), 0, math.rad(-10)),
			color = rope,
			material = FABRIC,
		},
		{
			size = Vector3.new(0.08, 0.4, 0.08),
			at = CFrame.new(0.27, 1.41, -0.5) * CFrame.Angles(math.rad(40), 0, math.rad(15)),
			color = rope,
			material = FABRIC,
		},
		{
			size = Vector3.new(0.06, 0.85, 0.85),
			at = CFrame.new(0, -0.05, -1.205) * ALONG,
			color = label,
			shape = CYLINDER,
		},
	}
	for _, angle in { 0, 90, 180, 270 } do
		local turn = CFrame.Angles(0, math.rad(angle), 0)
		table.insert(pieces, puff(0.45, CFrame.new(0, 1.97, 0) * turn * CFrame.new(0.32, 0, 0)))
	end
	for _, side in { -1, 1 } do
		table.insert(pieces, clip(side, Vector3.new(0.48, 1.55, 0), Vector3.new(0.12, 0.2, 0.2), STEEL))
	end
	add(pieces, dollar(CFrame.new(0, -0.05, -1.248), 0.56, mark))
	return pieces
end

-- A school backpack: rounded top with a zip round it, a front pocket, side pockets, a grab
-- handle, and padded straps on the back.
local function backpack(): { Piece }
	local blue = rgb(60, 120, 220)
	local dark = rgb(40, 88, 175)
	local yellow = rgb(255, 205, 60)
	local pieces: { Piece } = {
		{ size = Vector3.new(2, 1.6, 1.1), at = CFrame.new(0, -0.4, 0), color = blue, material = FABRIC },
		{
			size = Vector3.new(1.08, 2, 2),
			at = CFrame.new(0, 0.4, 0) * ALONG,
			color = blue,
			material = FABRIC,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.06, 2.04, 2.04),
			at = CFrame.new(0, 0.4, -0.3) * ALONG,
			color = yellow,
			shape = CYLINDER,
		},
		{ size = Vector3.new(1.5, 0.9, 0.3), at = CFrame.new(0, -0.6, -0.68), color = dark, material = FABRIC },
		{ size = Vector3.new(1.3, 0.04, 0.03), at = CFrame.new(0, -0.22, -0.835), color = yellow },
		{ size = Vector3.new(0.12, 0.3, 0.12), at = CFrame.new(-0.32, 1.45, 0.1), color = BLACK },
		{ size = Vector3.new(0.12, 0.3, 0.12), at = CFrame.new(0.32, 1.45, 0.1), color = BLACK },
		{
			size = Vector3.new(0.7, 0.16, 0.16),
			at = CFrame.new(0, 1.6, 0.1),
			color = BLACK,
			material = RUBBER,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.05, 0.36, 0.36),
			at = CFrame.new(0, -0.72, -0.85) * ALONG,
			color = yellow,
			shape = CYLINDER,
		},
	}
	for _, side in { -1, 1 } do
		add(pieces, {
			{
				size = Vector3.new(0.2, 0.8, 0.7),
				at = CFrame.new(side * 1.05, -0.65, 0),
				color = dark,
				material = FABRIC,
			},
			{
				size = Vector3.new(0.35, 2, 0.12),
				at = CFrame.new(side * 0.5, -0.1, 0.6),
				color = BLACK,
				material = FABRIC,
			},
		})
		table.insert(pieces, clip(side, Vector3.new(0.5, 0.95, 0.62), Vector3.new(0.3, 0.15, 0.12), BLACK))
	end
	return pieces
end

-- A leather briefcase: rounded corners, a handle on gold mounts, gold latches and a nameplate.
local function briefcase(): { Piece }
	local leather = rgb(110, 70, 40)
	local pieces = rounded(Vector3.new(0.7, 1.8, 2.6), 0.18, ALONG, leather, LEATHER)
	add(pieces, {
		{
			size = Vector3.new(0.95, 0.2, 0.2),
			at = CFrame.new(0, 1.18, 0),
			color = BLACK,
			material = LEATHER,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(2.62, 0.05, 0.72),
			at = CFrame.new(0, 0.62, 0),
			color = rgb(85, 52, 28),
			material = LEATHER,
		},
		{ size = Vector3.new(0.5, 0.18, 0.04), at = CFrame.new(0, 0.3, -0.365), color = GOLD, material = METAL },
	})
	for _, side in { -1, 1 } do
		add(pieces, {
			{
				size = Vector3.new(0.16, 0.3, 0.16),
				at = CFrame.new(side * 0.4, 1.0, 0),
				color = BLACK,
				material = LEATHER,
			},
			{
				size = Vector3.new(0.25, 0.08, 0.3),
				at = CFrame.new(side * 0.4, 0.91, 0),
				color = GOLD,
				material = METAL,
			},
			{
				size = Vector3.new(0.32, 0.24, 0.06),
				at = CFrame.new(side * 0.8, 0.62, -0.37),
				color = GOLD,
				material = METAL,
			},
		})
		table.insert(pieces, clip(side, Vector3.new(1.25, 0.93, 0), Vector3.new(0.1, 0.22, 0.16), GOLD))
	end
	return pieces
end

-- A piggy bank: a round pink pig with a snout, ears, eyes, four legs, a curly tail and a coin
-- going in the slot.
local function piggy(): { Piece }
	local pink = rgb(255, 150, 190)
	local deep = rgb(240, 120, 165)
	local pieces: { Piece } = {
		{ size = Vector3.new(1, 2, 2), at = I, color = pink, shape = CYLINDER },
		{ size = Vector3.one * 2, at = CFrame.new(-0.5, 0, 0), color = pink, shape = BALL },
		{ size = Vector3.one * 2, at = CFrame.new(0.5, 0, 0), color = pink, shape = BALL },
		{ size = Vector3.new(0.35, 0.8, 0.8), at = CFrame.new(1.55, -0.05, 0), color = deep, shape = CYLINDER },
		{ size = Vector3.new(0.7, 0.06, 0.12), at = CFrame.new(0, 1.0, 0), color = BLACK },
		{
			size = Vector3.new(0.06, 0.5, 0.5),
			at = CFrame.new(0, 1.12, 0) * ALONG,
			color = GOLD,
			material = METAL,
			shape = CYLINDER,
		},
		{ size = Vector3.one * 0.18, at = CFrame.new(-1.55, 0.2, 0), color = deep, shape = BALL },
		{ size = Vector3.one * 0.16, at = CFrame.new(-1.66, 0.32, 0.08), color = deep, shape = BALL },
		{ size = Vector3.one * 0.14, at = CFrame.new(-1.6, 0.44, 0), color = deep, shape = BALL },
	}
	for _, side in { -1, 1 } do
		add(pieces, {
			{
				size = Vector3.new(0.06, 0.16, 0.16),
				at = CFrame.new(1.73, -0.05, side * 0.15),
				color = rgb(170, 70, 110),
				shape = CYLINDER,
			},
			{ size = Vector3.one * 0.2, at = CFrame.new(1.3, 0.35, side * 0.45), color = BLACK, shape = BALL },
			{
				size = Vector3.new(0.4, 0.45, 0.12),
				at = CFrame.new(0.95, 0.95, side * 0.45) * CFrame.Angles(0, 0, math.rad(-20)),
				color = deep,
			},
			{
				size = Vector3.new(0.5, 0.45, 0.45),
				at = CFrame.new(0.75, -0.95, side * 0.55) * UP,
				color = deep,
				shape = CYLINDER,
			},
			{
				size = Vector3.new(0.5, 0.45, 0.45),
				at = CFrame.new(-0.75, -0.95, side * 0.55) * UP,
				color = deep,
				shape = CYLINDER,
			},
		})
		table.insert(pieces, clip(side, Vector3.new(0.8, 1.0, 0), Vector3.new(0.12, 0.2, 0.16), STEEL))
	end
	return pieces
end

-- A little safe: rounded steel box on feet, a door on hinges, a gold dial and a spoked handle.
local function safe(): { Piece }
	local steel = rgb(90, 95, 105)
	local door = rgb(70, 74, 82)
	local pieces = rounded(Vector3.new(1.7, 2, 1.9), 0.15, ALONG, steel, METAL)
	add(pieces, {
		{ size = Vector3.new(1.5, 1.6, 0.1), at = CFrame.new(0, 0.02, -0.88), color = door, material = METAL },
		{
			size = Vector3.new(0.1, 0.62, 0.62),
			at = CFrame.new(-0.15, 0.3, -0.96) * ALONG,
			color = GOLD,
			material = METAL,
			shape = CYLINDER,
		},
		{
			size = Vector3.new(0.1, 0.22, 0.22),
			at = CFrame.new(-0.15, 0.3, -1.03) * ALONG,
			color = BLACK,
			shape = CYLINDER,
		},
		{ size = Vector3.new(0.04, 0.1, 0.03), at = CFrame.new(-0.15, 0.66, -0.935), color = rgb(240, 240, 240) },
		{
			size = Vector3.new(0.14, 0.16, 0.16),
			at = CFrame.new(-0.15, -0.35, -0.98) * ALONG,
			color = STEEL,
			material = METAL,
			shape = CYLINDER,
		},
	})
	for _, angle in { 0, 60, 120 } do
		table.insert(pieces, {
			size = Vector3.new(0.5, 0.06, 0.06),
			at = CFrame.new(-0.15, -0.35, -1.01) * CFrame.Angles(0, 0, math.rad(angle)),
			color = STEEL,
			material = METAL,
		})
	end
	for _, y in { -0.5, 0.5 } do
		table.insert(pieces, {
			size = Vector3.new(0.35, 0.16, 0.16),
			at = CFrame.new(0.78, y, -0.92) * UP,
			color = STEEL,
			material = METAL,
			shape = CYLINDER,
		})
	end
	for _, side in { -1, 1 } do
		for _, z in { -0.6, 0.6 } do
			table.insert(
				pieces,
				{ size = Vector3.new(0.3, 0.15, 0.3), at = CFrame.new(side * 0.65, -1.07, z), color = BLACK }
			)
		end
		table.insert(pieces, clip(side, Vector3.new(0.75, 1.07, 0), Vector3.new(0.12, 0.2, 0.2), STEEL))
	end
	return pieces
end

local DESIGNS: { [string]: { Piece } } = {
	Bag = duffel(),
	Sack = sack(rgb(196, 160, 110), FABRIC, rgb(120, 80, 40), rgb(80, 175, 90), rgb(245, 245, 235)),
	GoldSack = sack(GOLD, METAL, rgb(150, 100, 40), rgb(255, 240, 190), rgb(200, 150, 30), 0.3),
	Backpack = backpack(),
	Briefcase = briefcase(),
	PiggyBank = piggy(),
	MiniSafe = safe(),
}

local CARRY: { [string]: Carry } = { Backpack = "Back" }

local STRAPS: { [string]: Color3 } = {
	Sack = rgb(120, 80, 40),
	GoldSack = rgb(150, 100, 40),
	Briefcase = rgb(70, 45, 25),
	PiggyBank = rgb(220, 60, 90),
}

function BagLooks.pieces(design: string): { Piece }?
	return DESIGNS[design]
end

-- Every design's id (the shop pictures register these).
function BagLooks.designs(): { string }
	local list = {}
	for id in DESIGNS do
		table.insert(list, id)
	end
	return list
end

-- How you wear it: slung across you on a strap, or on your back.
function BagLooks.carry(design: string): Carry
	return CARRY[design] or "Sling"
end

-- The colour of the strap you wear it on.
function BagLooks.strap(design: string): Color3
	return STRAPS[design] or BLACK
end

return BagLooks
