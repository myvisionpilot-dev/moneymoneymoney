-- Part-building helpers shared by the town builders. Parts only, no scripts.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

Kit.Colors = {
	Road = Color3.fromRGB(62, 62, 68),
	Path = Color3.fromRGB(196, 194, 188),
	Plaza = Color3.fromRGB(214, 206, 188),
	Grass = Color3.fromRGB(96, 170, 78),
	DarkGrass = Color3.fromRGB(70, 140, 60),
	Leaves = Color3.fromRGB(58, 138, 58),
	Trunk = Color3.fromRGB(110, 75, 45),
	White = Color3.fromRGB(245, 245, 240),
	Glass = Color3.fromRGB(170, 215, 250),
	Lot = Color3.fromRGB(88, 88, 94),
	Pad = Color3.fromRGB(255, 205, 60),
	Brick = Color3.fromRGB(150, 90, 70),
	Wood = Color3.fromRGB(150, 105, 70),
}

-- A plain anchored part. `cframe` may be a Vector3 for an unrotated part.
function Kit.part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	p.Color = color or Kit.Colors.White
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Kit.wedge(parent, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Upright cylinder (Roblox cylinders lie along X, so turn them).
function Kit.cylinder(parent, name, height, diameter, position, color, material)
	local p = Kit.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Small props: no shadow, no touch or raycast checks, nothing to bump into. Cheaper on phones.
function Kit.decor(p)
	p.CastShadow = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

-- Scenery you can walk into but that nothing else needs to know about.
function Kit.quiet(p)
	p.CanTouch = false
	p.CanQuery = false
	return p
end

-- An invisible, non-colliding marker part, optionally tagged.
function Kit.marker(parent, name, cframe, tag)
	local p = Kit.part(parent, name, Vector3.new(2, 1, 2), cframe)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if tag then
		CollectionService:AddTag(p, tag)
	end
	return p
end

function Kit.tag(instance, tag)
	CollectionService:AddTag(instance, tag)
	return instance
end

function Kit.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A painted sign on one face of a part (no floating labels anywhere in town).
function Kit.sign(part, face, text, background, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.fromRGB(30, 40, 70)
	label.BackgroundTransparency = if background then 0 else 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(22, 33, 62)
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = part
	return gui
end

-- A leafy bush you can hide in: an invisible tagged hitbox plus leafy balls to walk through.
local LEAVES = {
	{ Vector3.new(0, 3.2, 0), 7, Color3.fromRGB(55, 135, 55) },
	{ Vector3.new(2.8, 2.4, 1.2), 5.5, Color3.fromRGB(70, 150, 60) },
	{ Vector3.new(-2.6, 2.2, 1.6), 5, Color3.fromRGB(50, 125, 50) },
	{ Vector3.new(0.6, 2.4, -2.8), 5.5, Color3.fromRGB(65, 145, 65) },
	{ Vector3.new(-1.2, 5, -0.6), 4.5, Color3.fromRGB(80, 160, 70) },
}
function Kit.bush(parent, name, ground)
	local bush = Kit.model(parent, name)
	local hitbox = Kit.part(bush, "Hitbox", Vector3.new(9, 7, 9), ground + Vector3.new(0, 3.5, 0))
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = false
	CollectionService:AddTag(hitbox, "HidingSpot")
	for index, leaf in LEAVES do
		local ball =
			Kit.part(bush, `Leaves{index}`, Vector3.one * leaf[2], ground + leaf[1], leaf[3], Enum.Material.LeafyGrass)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
	end
	return bush
end

function Kit.tree(parent, name, ground, height)
	local h = height or 12
	local tree = Kit.model(parent, name)
	Kit.quiet(
		Kit.cylinder(tree, "Trunk", h, 1.8, ground + Vector3.new(0, h / 2, 0), Kit.Colors.Trunk, Enum.Material.Wood)
	)
	local canopy = Kit.part(
		tree,
		"Canopy",
		Vector3.one * (h * 0.9),
		ground + Vector3.new(0, h + h * 0.25, 0),
		Kit.Colors.Leaves,
		Enum.Material.Grass
	)
	canopy.Shape = Enum.PartType.Ball
	Kit.quiet(canopy)
	return tree
end

return Kit
