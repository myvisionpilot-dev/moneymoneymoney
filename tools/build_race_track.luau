-- Builds the grey-box race track north of town (Match place, command bar or MCP), after
-- build_match_map. Parts only, no scripts. Rebuilds Workspace.Map.RaceTrack from scratch.
--
-- Tags the code looks for:
--   RaceJoin                          the start pad (hold E to join)
--   RaceCheckpoint (+ Order)          gates in order; the last one is the finish line
--   RaceGrid (+ Order)                starting slots, facing the way to go
--
-- The loop runs east along the south straight, north up the east side, west along the top,
-- and back down the west side. Walls and a raised infield stop shortcuts.

local CollectionService = game:GetService("CollectionService")

local ROAD = Color3.fromRGB(70, 70, 76)
local WALL = Color3.fromRGB(200, 60, 60)
local POST = Color3.fromRGB(235, 235, 235)
local CONE = Color3.fromRGB(255, 140, 40)

local EAST, WEST, SOUTH, NORTH = 200, -200, -705, -905 -- centre line of the loop
local WIDTH = 32
local WALL_HEIGHT = 10 -- taller than a jump

local map = workspace:FindFirstChild("Map")
if not map then
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
end
local old = map:FindFirstChild("RaceTrack")
if old then
	old:Destroy()
end
local track = Instance.new("Folder")
track.Name = "RaceTrack"
track.Parent = map

local function part(name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = track
	return p
end

local function label(target, text, height, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
	gui.Parent = target
end

local half = WIDTH / 2
local length = EAST - WEST + WIDTH -- straights overlap at the corners
local depth = SOUTH - NORTH + WIDTH

-- Road
part("TrackSouth", Vector3.new(length, 0.2, WIDTH), Vector3.new(0, 0.1, SOUTH), ROAD)
part("TrackNorth", Vector3.new(length, 0.2, WIDTH), Vector3.new(0, 0.1, NORTH), ROAD)
part("TrackWest", Vector3.new(WIDTH, 0.2, depth), Vector3.new(WEST, 0.1, (SOUTH + NORTH) / 2), ROAD)
part("TrackEast", Vector3.new(WIDTH, 0.2, depth), Vector3.new(EAST, 0.1, (SOUTH + NORTH) / 2), ROAD)

-- Raised infield and outer walls (a gap in the south wall where the north road comes in)
local infield = part(
	"Infield",
	Vector3.new(EAST - WEST - WIDTH, WALL_HEIGHT, SOUTH - NORTH - WIDTH),
	Vector3.new(0, WALL_HEIGHT / 2, (SOUTH + NORTH) / 2),
	Color3.fromRGB(90, 170, 80),
	Enum.Material.Grass
)
label(infield, "RACE TRACK", WALL_HEIGHT / 2 + 12, Color3.fromRGB(255, 196, 50))
local outerX, outerSouth, outerNorth = EAST + half + 1, SOUTH + half + 1, NORTH - half - 1
local wallLength = 2 * outerX + 2
part("WallNorth", Vector3.new(wallLength, WALL_HEIGHT, 2), Vector3.new(0, WALL_HEIGHT / 2, outerNorth), WALL)
part(
	"WallWest",
	Vector3.new(2, WALL_HEIGHT, depth + 4),
	Vector3.new(-outerX, WALL_HEIGHT / 2, (SOUTH + NORTH) / 2),
	WALL
)
part(
	"WallEast",
	Vector3.new(2, WALL_HEIGHT, depth + 4),
	Vector3.new(outerX, WALL_HEIGHT / 2, (SOUTH + NORTH) / 2),
	WALL
)
local gap = 16
local pieceLength = outerX + 1 - gap
for index, sign in { -1, 1 } do
	part(
		`WallSouth{index}`,
		Vector3.new(pieceLength, WALL_HEIGHT, 2),
		Vector3.new(sign * (gap + pieceLength / 2), WALL_HEIGHT / 2, outerSouth),
		WALL
	)
end

-- Cones to weave around
for index, position in
	{
		Vector3.new(100, 2, NORTH + 8),
		Vector3.new(0, 2, NORTH - 8),
		Vector3.new(-100, 2, NORTH + 8),
		Vector3.new(EAST + 8, 2, (SOUTH + NORTH) / 2),
		Vector3.new(WEST - 8, 2, (SOUTH + NORTH) / 2),
	}
do
	part(`Cone{index}`, Vector3.new(5, 4, 5), position, CONE)
end

-- Checkpoint gates: an invisible tagged marker at the road centre, posts and a banner across.
local checkpoints = {
	Vector3.new(EAST, 3, -760),
	Vector3.new(EAST, 3, -850),
	Vector3.new(100, 3, NORTH),
	Vector3.new(-100, 3, NORTH),
	Vector3.new(WEST, 3, -850),
	Vector3.new(WEST, 3, -760),
	Vector3.new(-100, 3, SOUTH),
	Vector3.new(30, 3, SOUTH), -- finish line
}
for order, position in checkpoints do
	local alongX = position.Z == SOUTH or position.Z == NORTH -- road runs east-west here
	local across = if alongX then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	local finish = order == #checkpoints

	local marker = part(`Checkpoint{order}`, Vector3.new(2, 2, 2), position, POST)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker:SetAttribute("Order", order)
	CollectionService:AddTag(marker, "RaceCheckpoint")

	for _, side in { -1, 1 } do
		part(
			`Post{order}`,
			Vector3.new(1.5, 13, 1.5),
			Vector3.new(position.X, 6.5, position.Z) + across * side * (half + 1.5),
			POST
		)
	end
	local bannerSize = if alongX then Vector3.new(1, 2.5, WIDTH + 4) else Vector3.new(WIDTH + 4, 2.5, 1)
	local banner = part(
		`Banner{order}`,
		bannerSize,
		Vector3.new(position.X, 12, position.Z),
		if finish then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(255, 196, 50),
		if finish then Enum.Material.SmoothPlastic else Enum.Material.Neon
	)
	label(banner, if finish then "FINISH" else tostring(order), 4)
	if finish then
		local line =
			part("FinishLine", Vector3.new(2, 0.25, WIDTH), Vector3.new(position.X, 0.15, SOUTH), Color3.new(1, 1, 1))
		line.CanCollide = false
	end
end

-- Starting grid: two columns just past the finish line, facing east.
for order, position in
	{
		Vector3.new(74, 0.3, SOUTH + 7),
		Vector3.new(74, 0.3, SOUTH - 7),
		Vector3.new(62, 0.3, SOUTH + 7),
		Vector3.new(62, 0.3, SOUTH - 7),
		Vector3.new(50, 0.3, SOUTH + 7),
		Vector3.new(50, 0.3, SOUTH - 7),
	}
do
	local slot = part(
		`Grid{order}`,
		Vector3.new(4, 0.2, 6),
		CFrame.lookAt(position, position + Vector3.xAxis),
		Color3.new(1, 1, 1)
	)
	slot.CanCollide = false
	slot.Transparency = 0.3
	slot:SetAttribute("Order", order)
	CollectionService:AddTag(slot, "RaceGrid")
end

-- Start pad at the entrance, where the north road meets the track.
local pad = part(
	"RaceJoin",
	Vector3.new(10, 0.4, 10),
	Vector3.new(0, 0.3, SOUTH + half + 14),
	Color3.fromRGB(80, 200, 105),
	Enum.Material.Neon
)
pad.CanCollide = false
pad.Transparency = 0.3
CollectionService:AddTag(pad, "RaceJoin")
label(pad, "RACES\nhold E to join", 7, Color3.fromRGB(255, 196, 50))

local parts = 0
for _, d in track:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `Race track built: {#checkpoints} checkpoints, {parts} parts`
