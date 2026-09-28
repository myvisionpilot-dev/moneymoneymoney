-- Where everything in town goes. Studs; the bank is at (0, 0) and north is -Z.
--
--   The bank sits on a plaza where the two main roads cross. Shops line the main roads near the
--   bank. North and south of the shops are the neighbourhoods: a grid of blocks, each with a row
--   of houses, plus two cul-de-sacs per neighbourhood with a mansion at the end. The roads at
--   x = +-330 and z = +-310 make the street-race loop.

local Layout = {}

Layout.ROAD = 24 -- road width
Layout.HALF = 12 -- road centre to kerb
Layout.PATH = 6 -- footpath width
Layout.EDGE = 18 -- road centre to the outside of the footpath
Layout.PLAZA = 50 -- half-size of the bank plaza
Layout.ROAD_TOP = 0.2
Layout.PATH_TOP = 0.5

-- Straight roads. axis "x" runs east-west at z = at; axis "z" runs north-south at x = at.
-- plazaEnd / bulbEnd mark an end that meets the plaza or a cul-de-sac turning circle.
Layout.roads = {
	{ axis = "x", at = 0, from = -330, to = -50, plazaEnd = "to" },
	{ axis = "x", at = 0, from = 50, to = 330, plazaEnd = "from" },
	{ axis = "z", at = 0, from = -430, to = -50, plazaEnd = "to" },
	{ axis = "z", at = 0, from = 50, to = 430, plazaEnd = "from" },
	{ axis = "z", at = -330, from = -430, to = 430 },
	{ axis = "z", at = 330, from = -430, to = 430 },
}

-- Turning circles at the ends of the cul-de-sacs.
Layout.bulbs = {}
Layout.BULB_RADIUS = 20
Layout.BULB_PATH_RADIUS = 26

for _, side in { -1, 1 } do -- -1 = north neighbourhood, 1 = south
	for _, z in { 190, 310, 430 } do
		table.insert(Layout.roads, { axis = "x", at = z * side, from = -330, to = 330 })
	end
	for _, x in { -165, 165 } do
		table.insert(
			Layout.roads,
			{ axis = "z", at = x, from = math.min(190 * side, 430 * side), to = math.max(190 * side, 430 * side) }
		)
	end
	for _, x in { -247.5, 247.5 } do
		if side < 0 then
			table.insert(Layout.roads, { axis = "z", at = x, from = -530, to = -430, bulbEnd = "from" })
		else
			table.insert(Layout.roads, { axis = "z", at = x, from = 430, to = 530, bulbEnd = "to" })
		end
		table.insert(Layout.bulbs, Vector3.new(x, 0, 530 * side))
	end
end

-- Shop slots along the main roads. `front` is where the shop's front wall sits and `facing`
-- points from the shop toward its road. Widths are along the road.
Layout.SHOP_DEPTH = 42
local SLOT = 44
local PITCH = 49.5
local function eastWest(x, northSide)
	local z = if northSide then -41 else 41
	return { center = Vector3.new(x, 0, z), facing = Vector3.new(0, 0, if northSide then 1 else -1), width = SLOT }
end
local function northSouth(z, westSide)
	local x = if westSide then -41 else 41
	return { center = Vector3.new(x, 0, z), facing = Vector3.new(if westSide then 1 else -1, 0, 0), width = SLOT }
end
local function double(a, b)
	return {
		center = (a.center + b.center) / 2,
		facing = a.facing,
		width = SLOT + PITCH,
	}
end

local xs = { 90, 90 + PITCH, 90 + PITCH * 2, 90 + PITCH * 3, 90 + PITCH * 4 }
Layout.slots = {
	-- North side of the east-west road, west half
	CornerStore = eastWest(-xs[1], true),
	Clothes = eastWest(-xs[2], true),
	Burger = eastWest(-xs[3], true),
	Barber = eastWest(-xs[4], true),
	Hardware = eastWest(-xs[5], true),
	-- South side, west half
	GunStore = eastWest(-xs[1], false),
	Laundromat = eastWest(-xs[2], false),
	Alley = eastWest(-xs[3], false),
	Cafe = eastWest(-xs[4], false),
	Garage = eastWest(-xs[5], false),
	-- North side, east half
	Police = double(eastWest(xs[1], true), eastWest(xs[2], true)),
	Pharmacy = eastWest(xs[3], true),
	MiniMart = eastWest(xs[4], true),
	Bakery = eastWest(xs[5], true),
	-- South side, east half
	Depot = double(eastWest(xs[1], false), eastWest(xs[2], false)),
	CarWash = eastWest(xs[3], false),
	Taxi = eastWest(xs[4], false),
	Market = eastWest(xs[5], false),
	-- Along the north-south road
	Florist = northSouth(-91, true),
	PostOffice = northSouth(-145, true),
	Diner = northSouth(-91, false),
	Gym = northSouth(-145, false),
	Books = northSouth(91, true),
	PetShop = northSouth(145, true),
	Toys = northSouth(91, false),
	Music = northSouth(145, false),
}

-- The open ground behind the shops, one per corner of town (x from, x to, z from, z to).
Layout.yards = {
	Park = { -312, -68, -170, -66 }, -- north-west
	PoliceYard = { 68, 312, -170, -66 }, -- north-east
	GarageLot = { -312, -68, 66, 170 }, -- south-west
	DepotYard = { 68, 312, 66, 170 }, -- south-east
}

-- House lots. `front` is the middle of the lot's street edge (the outside of the footpath),
-- `inward` points from the street into the lot. Ids go up with wealth: nearest town first.
Layout.LOT_WIDTH = 43
Layout.LOT_DEPTH = 84
Layout.MANSION_WIDTH = 90
Layout.MANSION_DEPTH = 110

local function blockLots(front, inward, tier, list)
	for _, block in { { -312, -183 }, { -147, -18 }, { 18, 147 }, { 183, 312 } } do
		for k = 0, 2 do
			table.insert(list, {
				tier = tier,
				front = Vector3.new(block[1] + 21.5 + 43 * k, 0, front),
				inward = inward,
			})
		end
	end
end

Layout.lots = {}
do
	local lots = Layout.lots
	-- Tier 1: facing the roads nearest town
	blockLots(-208, Vector3.new(0, 0, -1), 1, lots)
	blockLots(208, Vector3.new(0, 0, 1), 1, lots)
	-- Tier 2: facing the outer roads
	blockLots(-412, Vector3.new(0, 0, 1), 2, lots)
	blockLots(412, Vector3.new(0, 0, -1), 2, lots)
	-- Tier 3: either side of each cul-de-sac
	for _, side in { -1, 1 } do
		for _, x in { -247.5, 247.5 } do
			local z = 473.5 * side
			table.insert(lots, { tier = 3, front = Vector3.new(x - 18, 0, z), inward = Vector3.new(-1, 0, 0) })
			table.insert(lots, { tier = 3, front = Vector3.new(x + 18, 0, z), inward = Vector3.new(1, 0, 0) })
		end
	end
	-- Tier 4: the mansions past each turning circle
	for _, side in { -1, 1 } do
		for _, x in { -247.5, 247.5 } do
			table.insert(lots, {
				tier = 4,
				front = Vector3.new(x, 0, (530 + Layout.BULB_PATH_RADIUS) * side),
				inward = Vector3.new(0, 0, side),
			})
		end
	end
	for id, lot in lots do
		lot.id = id
	end
end

return Layout
