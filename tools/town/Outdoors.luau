-- Everything outside: the park, the yards behind the shops (police, garage, depot), the jail,
-- hiding bushes, parked-car spots, police patrol points and the pedestrian routes.
--
-- Tags placed here: ParkSpot, JailCell, JailExit, PoliceSpawn, ChopShop, ParkedCar,
-- HidingSpot (via Kit.bush), PedWaypoint (+ Route, Order attributes).

local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)

local Outdoors = {}

local function yardFloor(parent, name, yard, color, material)
	local x1, x2, z1, z2 = yard[1], yard[2], yard[3], yard[4]
	return Kit.quiet(
		Kit.part(
			parent,
			name,
			Vector3.new(x2 - x1, 0.3, z2 - z1),
			Vector3.new((x1 + x2) / 2, 0.15, (z1 + z2) / 2),
			color,
			material
		)
	)
end

local function park(parent)
	local yard = Layout.yards.Park
	local folder = Kit.folder(parent, "Park")
	yardFloor(folder, "Grass", yard, Kit.Colors.Grass, Enum.Material.Grass)
	local pond = Kit.cylinder(
		folder,
		"Pond",
		0.2,
		30,
		Vector3.new(-250, 0.35, -118),
		Color3.fromRGB(80, 160, 230),
		Enum.Material.Glass
	)
	Kit.decor(pond)
	Kit.quiet(
		Kit.part(
			folder,
			"ParkPath",
			Vector3.new(yard[2] - yard[1] - 20, 0.1, 5),
			Vector3.new((yard[1] + yard[2]) / 2, 0.35, -118),
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	)
	for index, spot in
		{
			Vector3.new(-290, 0.3, -150),
			Vector3.new(-200, 0.3, -86),
			Vector3.new(-150, 0.3, -150),
			Vector3.new(-95, 0.3, -90),
			Vector3.new(-205, 0.3, -152),
		}
	do
		Kit.tree(folder, `Tree{index}`, spot, 11 + index % 3 * 2)
	end
	for index, x in { -175, -125 } do
		Kit.quiet(
			Kit.part(
				folder,
				`Bench{index}`,
				Vector3.new(6, 1, 2),
				Vector3.new(x, 1.3, -124),
				Kit.Colors.Wood,
				Enum.Material.Wood
			)
		)
	end
	Kit.bush(folder, "Bush1", Vector3.new(-160, 0.3, -95))
	Kit.bush(folder, "Bush2", Vector3.new(-280, 0.3, -90))
	Kit.marker(folder, "ParkSpot", Vector3.new(-190, 1, -118), "ParkSpot")
end

local function policeYard(parent)
	local yard = Layout.yards.PoliceYard
	local folder = Kit.folder(parent, "PoliceYard")
	yardFloor(folder, "Tarmac", yard, Kit.Colors.Lot, Enum.Material.Asphalt)
	-- The jail cell, with see-through bars.
	local center = Vector3.new(130, 0, -125)
	local cell = Kit.part(
		folder,
		"CellFloor",
		Vector3.new(16, 1, 16),
		center + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(80, 80, 85)
	)
	Kit.tag(cell, "JailCell")
	local bars = Color3.fromRGB(90, 90, 100)
	for _, info in
		{
			{ Vector3.new(16, 10, 1), Vector3.new(0, 6, -8) },
			{ Vector3.new(16, 10, 1), Vector3.new(0, 6, 8) },
			{ Vector3.new(1, 10, 16), Vector3.new(-8, 6, 0) },
			{ Vector3.new(1, 10, 16), Vector3.new(8, 6, 0) },
			{ Vector3.new(16, 1, 16), Vector3.new(0, 11.5, 0) },
		}
	do
		local wall = Kit.part(folder, "CellWall", info[1], center + info[2], bars, Enum.Material.DiamondPlate)
		wall.Transparency = 0.45
	end
	Kit.marker(folder, "JailExit", Vector3.new(170, 1, -100), "JailExit")
	Kit.marker(folder, "PoliceSpawnYardA", Vector3.new(220, 3, -100), "PoliceSpawn")
	Kit.marker(folder, "PoliceSpawnYardB", Vector3.new(260, 3, -140), "PoliceSpawn")
end

local function garageLot(parent)
	local yard = Layout.yards.GarageLot
	local folder = Kit.folder(parent, "GarageLot")
	yardFloor(folder, "Tarmac", yard, Kit.Colors.Lot, Enum.Material.Asphalt)
	-- Drive stolen cars onto the orange bay behind the garage.
	local bay = Kit.part(
		folder,
		"ChopBay",
		Vector3.new(16, 0.3, 16),
		Vector3.new(-288, 0.45, 95),
		Color3.fromRGB(255, 140, 40),
		Enum.Material.Neon
	)
	bay.CanCollide = false
	bay.Transparency = 0.4
	Kit.tag(bay, "ChopShop")
	for index = 0, 4 do -- parking lines
		Kit.decor(
			Kit.part(
				folder,
				"Line",
				Vector3.new(0.4, 0.05, 12),
				Vector3.new(-230 + index * 12, 0.33, 150),
				Kit.Colors.White
			)
		)
	end
end

local function depotYard(parent)
	local yard = Layout.yards.DepotYard
	local folder = Kit.folder(parent, "DepotYard")
	yardFloor(folder, "Tarmac", yard, Kit.Colors.Lot, Enum.Material.Asphalt)
	for index = 1, 4 do
		Kit.quiet(
			Kit.part(
				folder,
				`Pallet{index}`,
				Vector3.new(4, 3, 4),
				Vector3.new(80 + index * 7, 1.8, 80),
				Color3.fromRGB(190, 145, 90),
				Enum.Material.Cardboard
			)
		)
	end
	Kit.bush(folder, "Bush", Vector3.new(290, 0.3, 150))
end

-- Parked cars (the server parks a car on each spot): along the roads, away from the garage.
local PARKING = {
	{ Vector3.new(-322, 0.5, -110), Vector3.zAxis },
	{ Vector3.new(322, 0.5, 110), Vector3.zAxis },
	{ Vector3.new(-322, 0.5, 250), Vector3.zAxis },
	{ Vector3.new(322, 0.5, -250), Vector3.zAxis },
	{ Vector3.new(100, 0.5, -182), Vector3.xAxis },
	{ Vector3.new(-100, 0.5, 182), Vector3.xAxis },
	{ Vector3.new(-80, 0.5, -438), Vector3.xAxis },
	{ Vector3.new(80, 0.5, 438), Vector3.xAxis },
}

-- Police appear from the nearest of these (at least Police.MinSpawnStuds from you).
local PATROLS = {
	Vector3.new(-330, 3, 0),
	Vector3.new(330, 3, 0),
	Vector3.new(0, 3, -310),
	Vector3.new(0, 3, 310),
	Vector3.new(-165, 3, -430),
	Vector3.new(165, 3, 430),
	Vector3.new(-330, 3, 310),
	Vector3.new(330, 3, -310),
	Vector3.new(-247.5, 3, -530),
	Vector3.new(247.5, 3, 530),
}

-- Pedestrian loops along the footpaths (x, z pairs, walked in order and round again).
local ROUTES = {
	Main = {
		{ -310, -15 },
		{ -40, -15 },
		{ -40, -36 },
		{ 40, -36 },
		{ 40, -15 },
		{ 310, -15 },
		{ 310, 15 },
		{ 40, 15 },
		{ 40, 36 },
		{ -40, 36 },
		{ -40, 15 },
		{ -310, 15 },
	},
	NorthShops = { { -15, -60 }, { -15, -170 }, { 15, -170 }, { 15, -60 } },
	SouthShops = { { 15, 60 }, { 15, 170 }, { -15, 170 }, { -15, 60 } },
	NorthInner = { { -310, -205 }, { 310, -205 }, { 310, -175 }, { -310, -175 } },
	SouthInner = { { 310, 205 }, { -310, 205 }, { -310, 175 }, { 310, 175 } },
	NorthOuter = { { -310, -415 }, { 310, -415 }, { 310, -445 }, { -310, -445 } },
	SouthOuter = { { 310, 415 }, { -310, 415 }, { -310, 445 }, { 310, 445 } },
}

function Outdoors.build(map)
	local folder = Kit.folder(map, "Outdoors")
	park(folder)
	policeYard(folder)
	garageLot(folder)
	depotYard(folder)

	-- A bush in the middle of each turning circle.
	for index, center in Layout.bulbs do
		Kit.bush(folder, `CircleBush{index}`, center + Vector3.new(0, 0.56, 0))
	end

	local parking = Kit.folder(folder, "ParkingSpots")
	for index, spot in PARKING do
		local position, along = spot[1], spot[2]
		Kit.marker(parking, `ParkingSpot{index}`, CFrame.lookAt(position, position + along), "ParkedCar")
	end

	local patrols = Kit.folder(folder, "PolicePatrols")
	for index, position in PATROLS do
		Kit.marker(patrols, `PolicePatrol{index}`, position, "PoliceSpawn")
	end

	local routes = Kit.folder(folder, "PedRoutes")
	for name, points in ROUTES do
		for order, point in points do
			local p = Kit.marker(routes, `{name}{order}`, Vector3.new(point[1], 1, point[2]), "PedWaypoint")
			p:SetAttribute("Route", name)
			p:SetAttribute("Order", order)
		end
	end
	return folder
end

return Outdoors
