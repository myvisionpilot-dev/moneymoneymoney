-- Builds the grey-box Match town (Milestone 2 size). Run in the Match place (command bar or MCP).
-- Parts only, no scripts. Rebuilds Workspace.Map from scratch each time.
--
-- Tags the code looks for:
--   TonyDesk, TonySpawn, ShopCounter        Tony's office
--   House (+ HouseId, Tier attributes; children: Door part, BackDoor + Chore1-3 attachments)
--   DeliveryDepot, DeliveryDropoff           deliveries
--   StoreCounter                             store robberies
--   PoliceSpawn, JailCell, JailExit          police and jail
--   HidingSpot, ParkSpot, AlleyDrop          heat and door jobs
--   PedWaypoint (+ Route, Order attributes)  pedestrian routes

local CollectionService = game:GetService("CollectionService")

local GREY = Color3.fromRGB(163, 162, 165)
local ROAD = Color3.fromRGB(70, 70, 76)
local PAD = Color3.fromRGB(255, 205, 60)
local HOUSE_SIZES = { -- width (along the road), height, depth (toward the road)
	Vector3.new(18, 12, 16),
	Vector3.new(22, 14, 18),
	Vector3.new(26, 16, 22),
}
local HOUSE_COLORS = {
	Color3.fromRGB(180, 210, 235),
	Color3.fromRGB(235, 200, 170),
	Color3.fromRGB(200, 235, 190),
	Color3.fromRGB(235, 180, 200),
	Color3.fromRGB(225, 225, 170),
}

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
local template = workspace:FindFirstChild("SpawnLocation")
if template then
	template:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end

local function part(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color or GREY
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A block standing on the ground at (x, z).
local function block(parent, name, width, height, depth, x, z, color)
	return part(parent, name, Vector3.new(width, height, depth), Vector3.new(x, height / 2, z), color)
end

-- An invisible, non-colliding marker part.
local function marker(parent, name, position, tag)
	local p = part(parent, name, Vector3.new(2, 1, 2), position)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if tag then
		CollectionService:AddTag(p, tag)
	end
	return p
end

local function label(target, text, height, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance or 300
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
	gui.Parent = target
	return gui
end

-- Roads: plaza, four main roads, a ring road at 320 studs, and the race track up north.
local roads = folder("Roads")
part(roads, "Plaza", Vector3.new(120, 0.2, 120), Vector3.new(0, 0.1, 0), Color3.fromRGB(205, 200, 185))
part(roads, "RoadNorth", Vector3.new(30, 0.2, 630), Vector3.new(0, 0.1, -375), ROAD)
part(roads, "RoadSouth", Vector3.new(30, 0.2, 560), Vector3.new(0, 0.1, 340), ROAD)
part(roads, "RoadWest", Vector3.new(500, 0.2, 30), Vector3.new(-310, 0.1, 0), ROAD)
part(roads, "RoadEast", Vector3.new(500, 0.2, 30), Vector3.new(310, 0.1, 0), ROAD)
part(roads, "RingNorth", Vector3.new(670, 0.15, 30), Vector3.new(0, 0.08, -320), ROAD)
part(roads, "RingSouth", Vector3.new(670, 0.15, 30), Vector3.new(0, 0.08, 320), ROAD)
part(roads, "RingWest", Vector3.new(30, 0.15, 670), Vector3.new(-320, 0.08, 0), ROAD)
part(roads, "RingEast", Vector3.new(30, 0.15, 670), Vector3.new(320, 0.08, 0), ROAD)

local track = folder("RaceTrack")
part(track, "TrackNorth", Vector3.new(264, 0.2, 24), Vector3.new(0, 0.1, -830), ROAD)
part(track, "TrackSouth", Vector3.new(264, 0.2, 24), Vector3.new(0, 0.1, -690), ROAD)
part(track, "TrackWest", Vector3.new(24, 0.2, 164), Vector3.new(-120, 0.1, -760), ROAD)
local trackEast = part(track, "TrackEast", Vector3.new(24, 0.2, 164), Vector3.new(120, 0.1, -760), ROAD)
label(trackEast, "RACE TRACK (Part B)", 8)

-- Tony's office: open front facing north.
local office = folder("TonysOffice")
local wall = Color3.fromRGB(120, 60, 60)
part(office, "Floor", Vector3.new(44, 1, 34), Vector3.new(0, 0.5, 0), Color3.fromRGB(150, 110, 80), Enum.Material.WoodPlanks)
part(office, "BackWall", Vector3.new(44, 14, 2), Vector3.new(0, 8, 16), wall)
part(office, "WallWest", Vector3.new(2, 14, 34), Vector3.new(-21, 8, 0), wall)
part(office, "WallEast", Vector3.new(2, 14, 34), Vector3.new(21, 8, 0), wall)
local roof = part(office, "Roof", Vector3.new(46, 1.5, 36), Vector3.new(0, 15.75, 0), Color3.fromRGB(60, 40, 40))
label(roof, "TONY'S OFFICE", 6, 500)
local desk = part(office, "Desk", Vector3.new(12, 4, 4), Vector3.new(0, 3, 6), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
CollectionService:AddTag(desk, "TonyDesk")
local tony = part(office, "Tony", Vector3.new(3, 7, 2), Vector3.new(0, 4.5, 11), Color3.fromRGB(90, 40, 110))
local head = part(office, "TonyHead", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 9.2, 11), Color3.fromRGB(234, 184, 146))
head.Shape = Enum.PartType.Ball
label(tony, "TONY\nDeposit cash here", 8, 120)
local shop = part(office, "ShopCounter", Vector3.new(8, 3, 3), Vector3.new(-14, 2.5, 6), Color3.fromRGB(60, 140, 90))
CollectionService:AddTag(shop, "ShopCounter")
label(shop, "UPGRADES", 4, 80)

for index, x in { -12, 0, 12 } do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = `TonySpawn{index}`
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.Position = Vector3.new(x, 1.1, -8)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = office
	CollectionService:AddTag(spawn, "TonySpawn")
end

-- Downtown: stores, police and jail, the alley drop, placeholders.
local downtown = folder("Downtown")
label(block(downtown, "StoreA", 36, 14, 26, -100, -95, Color3.fromRGB(120, 200, 160)), "CORNER STORE", 10)
local counterA = part(downtown, "StoreCounterA", Vector3.new(3, 4, 8), Vector3.new(-80, 2, -95), Color3.fromRGB(90, 150, 120))
CollectionService:AddTag(counterA, "StoreCounter")
label(block(downtown, "StoreB", 36, 14, 26, 100, 95, Color3.fromRGB(120, 200, 160)), "MINI MART", 10)
local counterB = part(downtown, "StoreCounterB", Vector3.new(3, 4, 8), Vector3.new(80, 2, 95), Color3.fromRGB(90, 150, 120))
CollectionService:AddTag(counterB, "StoreCounter")

label(block(downtown, "PoliceStation", 40, 16, 30, 100, -100, Color3.fromRGB(60, 90, 170)), "POLICE", 11)
marker(downtown, "PoliceSpawnA", Vector3.new(74, 3, -95), "PoliceSpawn")
marker(downtown, "PoliceSpawnB", Vector3.new(74, 3, -105), "PoliceSpawn")
-- Patrol points around town: police appear from the nearest one.
for index, position in {
	Vector3.new(-270, 3, 0),
	Vector3.new(-470, 3, 0),
	Vector3.new(270, 3, 0),
	Vector3.new(470, 3, 0),
	Vector3.new(0, 3, 250),
	Vector3.new(0, 3, 470),
	Vector3.new(0, 3, -250),
	Vector3.new(-320, 3, -200),
	Vector3.new(320, 3, 200),
} do
	marker(downtown, `PolicePatrol{index}`, position, "PoliceSpawn")
end

local jail = folder("Jail")
local bars = Color3.fromRGB(90, 90, 100)
local cell = part(jail, "CellFloor", Vector3.new(16, 1, 16), Vector3.new(100, 0.5, -150), Color3.fromRGB(80, 80, 85))
CollectionService:AddTag(cell, "JailCell")
label(cell, "JAIL", 12, 150)
for _, info in {
	{ Vector3.new(16, 10, 1), Vector3.new(100, 6, -158) },
	{ Vector3.new(16, 10, 1), Vector3.new(100, 6, -142) },
	{ Vector3.new(1, 10, 16), Vector3.new(92, 6, -150) },
	{ Vector3.new(1, 10, 16), Vector3.new(108, 6, -150) },
	{ Vector3.new(16, 1, 16), Vector3.new(100, 11.5, -150) },
} do
	local w = part(jail, "CellWall", info[1], info[2], bars, Enum.Material.DiamondPlate)
	w.Transparency = 0.45
end
marker(jail, "JailExit", Vector3.new(76, 1, -150), "JailExit")

label(block(downtown, "Bank", 36, 18, 26, -100, -165, Color3.fromRGB(210, 210, 200)), "BANK (quota 3)", 12)
label(block(downtown, "Garage", 36, 14, 26, 100, 165, Color3.fromRGB(110, 110, 130)), "GARAGE / CHOP SHOP", 10)

local alley = folder("Alley")
part(alley, "AlleyWallWest", Vector3.new(4, 16, 40), Vector3.new(-110, 8, 95), Color3.fromRGB(120, 95, 80), Enum.Material.Brick)
part(alley, "AlleyWallEast", Vector3.new(4, 16, 40), Vector3.new(-80, 8, 95), Color3.fromRGB(120, 95, 80), Enum.Material.Brick)
part(alley, "Dumpster", Vector3.new(6, 4, 3), Vector3.new(-95, 2, 111), Color3.fromRGB(40, 90, 50), Enum.Material.Metal)
local drop = part(alley, "AlleyDrop", Vector3.new(6, 0.4, 6), Vector3.new(-95, 0.3, 102), Color3.fromRGB(35, 35, 40))
drop.CanCollide = false
CollectionService:AddTag(drop, "AlleyDrop")
label(drop, "ALLEY DROP", 6, 150)

-- Delivery depot and taxi stand up the north road.
local depotFolder = folder("DeliveryDepot")
label(block(depotFolder, "Building", 30, 12, 24, 70, -230, Color3.fromRGB(200, 120, 50)), "DELIVERY DEPOT", 9)
local counter = part(depotFolder, "Counter", Vector3.new(3, 4, 10), Vector3.new(53, 2, -230), Color3.fromRGB(176, 128, 72), Enum.Material.Cardboard)
CollectionService:AddTag(counter, "DeliveryDepot")
label(block(folder("TaxiStand"), "Shelter", 16, 8, 8, -50, -230, Color3.fromRGB(240, 200, 40)), "TAXI STAND (later)", 6)

-- Houses: every one has a door (knock), a back door and three chore spots, plus a delivery pad.
local houses = folder("Houses")
local count = 0
local function house(tier, x, z, facing)
	count += 1
	local size = HOUSE_SIZES[tier]
	local alongZ = facing.Z ~= 0
	local worldSize = if alongZ then Vector3.new(size.X, size.Y, size.Z) else Vector3.new(size.Z, size.Y, size.X)
	local body = part(houses, `House{count}`, worldSize, Vector3.new(x, size.Y / 2, z), HOUSE_COLORS[count % #HOUSE_COLORS + 1])
	body:SetAttribute("HouseId", count)
	body:SetAttribute("Tier", tier)
	CollectionService:AddTag(body, "House")
	label(body, `House {count}`, size.Y / 2 + 3, 120)

	local half = size.Z / 2
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local center = Vector3.new(x, 0, z)

	local doorPosition = center + facing * (half + 0.3) + Vector3.new(0, 3.5, 0)
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Anchored = true
	door.Size = Vector3.new(4, 7, 0.6)
	door.CFrame = CFrame.lookAt(doorPosition, doorPosition + facing)
	door.Color = Color3.fromRGB(110, 70, 45)
	door.Material = Enum.Material.Wood
	door.Parent = body

	local backDoor = Instance.new("Attachment")
	backDoor.Name = "BackDoor"
	backDoor.Parent = body
	backDoor.WorldPosition = center - facing * (half + 1.5) + Vector3.new(0, 3, 0)

	for index, offset in {
		facing * (half + 10) - side * (size.X / 2 - 3),
		facing * (half + 10) + side * (size.X / 2 - 3),
		side * (size.X / 2 + 5),
	} do
		local spot = Instance.new("Attachment")
		spot.Name = `Chore{index}`
		spot.Parent = body
		spot.WorldPosition = center + offset + Vector3.new(0, 1, 0)
	end

	local pad = part(houses, `Dropoff{count}`, Vector3.new(6, 0.3, 6), center + facing * (half + 4) + Vector3.new(0, 0.25, 0), PAD, Enum.Material.Neon)
	pad.Transparency = 0.4
	pad.CanCollide = false
	CollectionService:AddTag(pad, "DeliveryDropoff")
end

-- Westside, tier 1 (houses 1-12)
for _, x in { -110, -170, -230, -380, -440, -500 } do
	house(1, x, 44, Vector3.new(0, 0, -1))
	house(1, x, -44, Vector3.new(0, 0, 1))
end
-- Eastside, tier 2 (houses 13-22)
for _, x in { 110, 175, 240, 390, 460 } do
	house(2, x, 45, Vector3.new(0, 0, -1))
	house(2, x, -45, Vector3.new(0, 0, 1))
end
-- Hillside, tier 3 (houses 23-30)
for _, z in { 110, 180, 400, 470 } do
	house(3, -53, z, Vector3.new(1, 0, 0))
	house(3, 53, z, Vector3.new(-1, 0, 0))
end

label(block(folder("Mansion"), "Mansion", 60, 24, 40, 0, 660, Color3.fromRGB(240, 235, 220)), "MANSION (quota 5)", 15)

-- Park for dog walks.
local park = folder("Park")
local grass = part(park, "Grass", Vector3.new(100, 0.3, 80), Vector3.new(-420, 0.15, -200), Color3.fromRGB(90, 170, 80), Enum.Material.Grass)
label(grass, "PARK", 10, 250)
marker(park, "ParkSpot", Vector3.new(-420, 1, -200), "ParkSpot")
for index, position in { Vector3.new(-450, 0, -220), Vector3.new(-395, 0, -180) } do
	part(park, `Trunk{index}`, Vector3.new(2, 10, 2), position + Vector3.new(0, 5, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local canopy = part(park, `Canopy{index}`, Vector3.new(12, 12, 12), position + Vector3.new(0, 13, 0), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
	canopy.Shape = Enum.PartType.Ball
end

-- Hiding spots speed up heat decay.
local hiding = folder("HidingSpots")
for index, position in {
	Vector3.new(-200, 3, 140),
	Vector3.new(-450, 3, -110),
	Vector3.new(200, 3, -140),
	Vector3.new(450, 3, 130),
	Vector3.new(-150, 3, 450),
	Vector3.new(150, 3, 250),
} do
	local bush = part(hiding, `Bush{index}`, Vector3.new(8, 6, 8), position, Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
	bush.CanCollide = false
	CollectionService:AddTag(bush, "HidingSpot")
end

-- Pedestrian routes (walked in Order, looping).
local routes = folder("PedRoutes")
local function route(name, points)
	for order, point in points do
		local p = marker(routes, `{name}{order}`, Vector3.new(point.X, 1, point.Y), "PedWaypoint")
		p:SetAttribute("Route", name)
		p:SetAttribute("Order", order)
	end
end
route("Downtown", {
	Vector2.new(-75, -75), Vector2.new(0, -75), Vector2.new(75, -75), Vector2.new(75, 0),
	Vector2.new(75, 75), Vector2.new(0, 75), Vector2.new(-75, 75), Vector2.new(-75, 0),
})
route("West", { Vector2.new(-80, -22), Vector2.new(-300, -22), Vector2.new(-540, -22), Vector2.new(-540, 22), Vector2.new(-300, 22), Vector2.new(-80, 22) })
route("East", { Vector2.new(80, -22), Vector2.new(300, -22), Vector2.new(540, -22), Vector2.new(540, 22), Vector2.new(300, 22), Vector2.new(80, 22) })
route("South", { Vector2.new(22, 80), Vector2.new(22, 300), Vector2.new(22, 560), Vector2.new(-22, 560), Vector2.new(-22, 300), Vector2.new(-22, 80) })

local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `Match map built: {count} houses, {parts} parts`
