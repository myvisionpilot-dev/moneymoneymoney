-- Builds the two walk-in stores (Corner Store and Mini Mart) into Workspace.Map.Stores. Run in
-- the Match place after build_match_map.luau. Parts only, no scripts. Safe to run again: it
-- replaces the stores, including the solid grey-box ones from before Milestone 4.
--
-- Tags: StoreCounter (the register you rob), StoreZone (the inside: rings the door bell).

local CollectionService = game:GetService("CollectionService")

local FLOOR = Color3.fromRGB(232, 228, 214)
local TRIM = Color3.fromRGB(245, 245, 240)
local AWNING = Color3.fromRGB(220, 60, 60)
local SHELF = Color3.fromRGB(170, 120, 75)
local PRODUCT_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 190, 90),
	Color3.fromRGB(70, 140, 235),
	Color3.fromRGB(240, 130, 200),
	Color3.fromRGB(255, 150, 50),
}

local map = workspace:FindFirstChild("Map")
if not map then
	return "Build the Match map first (build_match_map.luau)"
end

-- Old solid stores and their outdoor counters.
local downtown = map:FindFirstChild("Downtown")
if downtown then
	for _, name in { "StoreA", "StoreCounterA", "StoreB", "StoreCounterB" } do
		local old = downtown:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end
local previous = map:FindFirstChild("Stores")
if previous then
	previous:Destroy()
end

local stores = Instance.new("Folder")
stores.Name = "Stores"
stores.Parent = map

local rng = Random.new(42) -- same shelves every build

local function part(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Small props: no shadow, no touch or raycast checks, nothing to bump into. Cheaper on phones.
local function decor(p)
	p.CastShadow = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

local function label(target, text, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 400
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
end

-- A 36 x 26 store with its door in the middle of the front wall. `facing` is 1 for a door on
-- the east side (+X) or -1 for the west side. Local x runs back (-18) to front (+18).
local function store(name, sign, center, facing, wallColor)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = stores
	local function piece(partName, size, x, y, z, color, material)
		return part(model, partName, size, center + Vector3.new(x * facing, y, z * facing), color, material)
	end

	piece("Floor", Vector3.new(36, 0.4, 26), 0, 0.2, 0, FLOOR, Enum.Material.Marble)
	piece("BackWall", Vector3.new(2, 14, 26), -17, 7, 0, wallColor)
	piece("SideWall1", Vector3.new(36, 14, 2), 0, 7, -12, wallColor)
	piece("SideWall2", Vector3.new(36, 14, 2), 0, 7, 12, wallColor)
	-- Front wall: a big window either side of a 10-wide door gap.
	for index, z in { -9, 9 } do
		piece(`FrontBase{index}`, Vector3.new(2, 3, 8), 17, 1.5, z, wallColor)
		local glass = piece(
			`Window{index}`,
			Vector3.new(0.6, 7, 8),
			17,
			6.5,
			z,
			Color3.fromRGB(180, 220, 255),
			Enum.Material.Glass
		)
		glass.Transparency = 0.55
		piece(`FrontTop{index}`, Vector3.new(2, 4, 8), 17, 12, z, wallColor)
	end
	piece("Lintel", Vector3.new(2, 5, 10), 17, 11.5, 0, TRIM)
	local roof = piece("Roof", Vector3.new(38, 1.5, 28), 0, 14.75, 0, TRIM)
	label(roof, sign, 5)
	piece("Awning", Vector3.new(5, 0.6, 16), 20.5, 10.5, 0, AWNING, Enum.Material.Fabric)
	decor(piece("Doormat", Vector3.new(3, 0.1, 8), 15, 0.45, 0, Color3.fromRGB(150, 40, 40), Enum.Material.Fabric))

	for index, z in { -5, 5 } do
		local lamp = piece(
			`Light{index}`,
			Vector3.new(10, 0.3, 1.5),
			0,
			13.8,
			z,
			Color3.fromRGB(255, 250, 230),
			Enum.Material.Neon
		)
		decor(lamp)
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 1
		light.Parent = lamp
	end

	local counter =
		piece("Counter", Vector3.new(3, 4, 10), -8, 2.4, -4, Color3.fromRGB(90, 150, 120), Enum.Material.Wood)
	CollectionService:AddTag(counter, "StoreCounter")
	decor(piece("Register", Vector3.new(1.4, 1.2, 1.8), -8, 5, -6, Color3.fromRGB(50, 50, 60), Enum.Material.Metal))

	-- Shelves along both side walls, stocked with colourful boxes.
	for unit, side in { -1, 1 } do
		local z = 10 * side
		piece(`ShelfBack{unit}`, Vector3.new(14, 6, 0.3), 3, 3.4, 10.85 * side, SHELF, Enum.Material.Wood)
		for level, height in { 0.9, 2.9, 4.9 } do
			piece(`Shelf{unit}_{level}`, Vector3.new(14, 0.3, 2), 3, height, z, SHELF, Enum.Material.Wood)
			for slot = 0, 4 do
				local color = PRODUCT_COLORS[rng:NextInteger(1, #PRODUCT_COLORS)]
				decor(
					piece(
						`Product{unit}_{level}_{slot}`,
						Vector3.new(1.8, 1.3, 1.2),
						-2.6 + slot * 2.8,
						height + 0.8,
						z,
						color
					)
				)
			end
		end
	end

	local zone = piece("StoreZone", Vector3.new(32, 10, 22), 0, 5.4, 0, FLOOR)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	CollectionService:AddTag(zone, "StoreZone")
end

store("CornerStore", "CORNER STORE", Vector3.new(-100, 0, -95), 1, Color3.fromRGB(120, 200, 160))
store("MiniMart", "MINI MART", Vector3.new(100, 0, 95), -1, Color3.fromRGB(240, 190, 90))

local parts = 0
for _, d in stores:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `Stores built: 2 stores, {parts} parts`
