-- Builds the grey-box Match town. Run in the Match place (Studio command bar or the MCP).
-- Parts only, no scripts. Rebuilds Workspace.Map from scratch each time.
-- Tags used by code: TonyDesk, TonySpawn, DeliveryDepot, DeliveryDropoff. Tags for later: House, HidingSpot.

local CollectionService = game:GetService("CollectionService")

local GREY = Color3.fromRGB(163, 162, 165)
local ROAD = Color3.fromRGB(70, 70, 76)
local PAD = Color3.fromRGB(255, 205, 60)

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

-- Ground: plaza, four roads out of it, and a ring road.
local ground = folder("Roads")
part(ground, "Plaza", Vector3.new(100, 0.2, 100), Vector3.new(0, 0.1, 0), Color3.fromRGB(205, 200, 185))
part(ground, "RoadNorth", Vector3.new(28, 0.2, 270), Vector3.new(0, 0.1, -185), ROAD)
part(ground, "RoadSouth", Vector3.new(28, 0.2, 270), Vector3.new(0, 0.1, 185), ROAD)
part(ground, "RoadWest", Vector3.new(270, 0.2, 28), Vector3.new(-185, 0.1, 0), ROAD)
part(ground, "RoadEast", Vector3.new(270, 0.2, 28), Vector3.new(185, 0.1, 0), ROAD)
part(ground, "RingNorth", Vector3.new(428, 0.15, 28), Vector3.new(0, 0.08, -200), ROAD)
part(ground, "RingSouth", Vector3.new(428, 0.15, 28), Vector3.new(0, 0.08, 200), ROAD)
part(ground, "RingWest", Vector3.new(28, 0.15, 428), Vector3.new(-200, 0.08, 0), ROAD)
part(ground, "RingEast", Vector3.new(28, 0.15, 428), Vector3.new(200, 0.08, 0), ROAD)

-- Tony's office: open front facing north (toward the depot).
local office = folder("TonysOffice")
local wall = Color3.fromRGB(120, 60, 60)
part(office, "Floor", Vector3.new(44, 1, 34), Vector3.new(0, 0.5, 0), Color3.fromRGB(150, 110, 80), Enum.Material.WoodPlanks)
part(office, "BackWall", Vector3.new(44, 14, 2), Vector3.new(0, 8, 16), wall)
part(office, "WallWest", Vector3.new(2, 14, 34), Vector3.new(-21, 8, 0), wall)
part(office, "WallEast", Vector3.new(2, 14, 34), Vector3.new(21, 8, 0), wall)
local roof = part(office, "Roof", Vector3.new(46, 1.5, 36), Vector3.new(0, 15.75, 0), Color3.fromRGB(60, 40, 40))
label(roof, "TONY'S OFFICE", 6, 400)
local desk = part(office, "Desk", Vector3.new(12, 4, 4), Vector3.new(0, 3, 6), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
CollectionService:AddTag(desk, "TonyDesk")
local tony = part(office, "Tony", Vector3.new(3, 7, 2), Vector3.new(0, 4.5, 11), Color3.fromRGB(90, 40, 110))
local head = part(office, "TonyHead", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 9.2, 11), Color3.fromRGB(234, 184, 146))
head.Shape = Enum.PartType.Ball
label(tony, "TONY\nDeposit cash here", 8, 120)

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

-- Delivery depot and taxi stand, either side of the north road.
local depotFolder = folder("DeliveryDepot")
local depot = block(depotFolder, "Building", 30, 12, 24, 45, -130, Color3.fromRGB(200, 120, 50))
label(depot, "DELIVERY DEPOT", 9)
local counter = part(depotFolder, "Counter", Vector3.new(3, 4, 10), Vector3.new(28, 2, -130), Color3.fromRGB(176, 128, 72), Enum.Material.Cardboard)
CollectionService:AddTag(counter, "DeliveryDepot")
local taxi = block(folder("TaxiStand"), "Shelter", 16, 8, 8, -40, -130, Color3.fromRGB(240, 200, 40))
label(taxi, "TAXI STAND (M2)", 6)

-- Houses in three neighbourhoods. Every house has a drop-off pad by its front door.
local houses = folder("Houses")
local count = 0
local function house(tier, x, z, facing)
	count += 1
	local sizes = { Vector3.new(18, 12, 16), Vector3.new(22, 14, 18), Vector3.new(26, 16, 22) }
	local colors = {
		Color3.fromRGB(180, 210, 235),
		Color3.fromRGB(235, 200, 170),
		Color3.fromRGB(200, 235, 190),
		Color3.fromRGB(235, 180, 200),
	}
	local size = sizes[tier]
	local body = block(houses, `House{count}`, size.X, size.Y, size.Z, x, z, colors[count % #colors + 1])
	body:SetAttribute("Tier", tier)
	CollectionService:AddTag(body, "House")
	label(body, `House T{tier}`, size.Y / 2 + 3, 150)
	-- facing: unit vector from the house toward its road
	local half = if math.abs(facing.X) > 0 then size.X / 2 else size.Z / 2
	local padPosition = Vector3.new(x, 0.25, z) + facing * (half + 4)
	local pad = part(houses, `Dropoff{count}`, Vector3.new(6, 0.3, 6), padPosition, PAD, Enum.Material.Neon)
	pad.Transparency = 0.4
	pad.CanCollide = false
	CollectionService:AddTag(pad, "DeliveryDropoff")
end

-- Tier 1: west road
for _, x in { -95, -140, -250, -295 } do
	house(1, x, 40, Vector3.new(0, 0, -1))
	house(1, x, -40, Vector3.new(0, 0, 1))
end
-- Tier 2: east road
for _, x in { 95, 140, 250, 295 } do
	house(2, x, 40, Vector3.new(0, 0, -1))
end
for _, x in { 95, 140, 250 } do
	house(2, x, -40, Vector3.new(0, 0, 1))
end
-- Tier 3: south road
house(3, -50, 100, Vector3.new(1, 0, 0))
house(3, 50, 100, Vector3.new(-1, 0, 0))
house(3, -50, 150, Vector3.new(1, 0, 0))
house(3, 50, 150, Vector3.new(-1, 0, 0))
house(3, -50, 250, Vector3.new(1, 0, 0))

-- Placeholders for later milestones.
local later = folder("Placeholders")
label(block(later, "Bank", 36, 18, 28, -75, -80, Color3.fromRGB(210, 210, 200)), "BANK (locked until quota 3)", 12)
label(block(later, "StoreA", 30, 12, 22, -150, -95, Color3.fromRGB(120, 200, 160)), "STORE", 9)
label(block(later, "StoreB", 30, 12, 22, 100, 95, Color3.fromRGB(120, 200, 160)), "STORE", 9)
label(block(later, "Garage", 34, 14, 26, 150, -95, Color3.fromRGB(110, 110, 130)), "GARAGE / CHOP SHOP", 10)
label(block(later, "PoliceStation", 36, 16, 28, -100, 90, Color3.fromRGB(60, 90, 170)), "POLICE STATION + JAIL", 11)
label(block(later, "Mansion", 60, 24, 40, 0, 360, Color3.fromRGB(240, 235, 220)), "MANSION (locked until quota 5)", 15)

local track = folder("RaceTrack")
part(track, "TrackNorth", Vector3.new(180, 0.2, 20), Vector3.new(0, 0.1, -450), ROAD)
part(track, "TrackSouth", Vector3.new(180, 0.2, 20), Vector3.new(0, 0.1, -350), ROAD)
part(track, "TrackWest", Vector3.new(20, 0.2, 120), Vector3.new(-80, 0.1, -400), ROAD)
local trackEast = part(track, "TrackEast", Vector3.new(20, 0.2, 120), Vector3.new(80, 0.1, -400), ROAD)
label(trackEast, "RACE TRACK (M2)", 8)
part(track, "Link", Vector3.new(28, 0.2, 30), Vector3.new(0, 0.1, -335), ROAD)

local hiding = folder("HidingSpots")
for index, position in { Vector3.new(-170, 3, 60), Vector3.new(170, 3, -40), Vector3.new(-30, 3, 230) } do
	local bush = part(hiding, `Bush{index}`, Vector3.new(8, 6, 8), position, Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
	CollectionService:AddTag(bush, "HidingSpot")
end

local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `Match map built: {count} houses, {parts} parts`
