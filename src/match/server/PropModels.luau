--!strict
-- Things you carry, push or walk on jobs, built from parts (no Creator Store models): a dog on
-- a leash, a push mower, a wheelie bin, a sponge, a letter, packages, a burger tray, a tyre and
-- the hot-dog cart. PropModels.build makes one at the origin (facing -Z): a main part with the
-- rest as children. Carry puts it in your hands or on the ground in front of you.

local PropModels = {}

export type Kind =
	"Dog"
	| "Mower"
	| "Bin"
	| "Sponge"
	| "Letter"
	| "Package"
	| "ShadyPackage"
	| "Tray"
	| "Tyre"
	| "HotDogCart"

-- Where it goes: `ground` props stand on the floor (offset from the point under you); the rest
-- are held (offset from your middle).
export type Hold = { offset: CFrame, ground: boolean }

local HOLDS: { [Kind]: Hold } = {
	Dog = { offset = CFrame.new(2.6, 0, -1.2), ground = true },
	Mower = { offset = CFrame.new(0, 0, -3.4), ground = true },
	Bin = { offset = CFrame.new(0, 0, -2.8), ground = true },
	HotDogCart = { offset = CFrame.new(0, 0, -3.6), ground = true },
	Sponge = { offset = CFrame.new(0, 0, -1.4), ground = false },
	Letter = { offset = CFrame.new(0, 0, -1.4), ground = false },
	Package = { offset = CFrame.new(0, 0, -1.5), ground = false },
	ShadyPackage = { offset = CFrame.new(0, 0, -1.4), ground = false },
	Tray = { offset = CFrame.new(0, -0.4, -1.4), ground = false },
	Tyre = { offset = CFrame.new(0, -0.6, -1.6), ground = false },
}

local DOG_COATS = {
	{ Color3.fromRGB(150, 100, 60), Color3.fromRGB(95, 60, 35) },
	{ Color3.fromRGB(225, 180, 100), Color3.fromRGB(180, 130, 60) },
	{ Color3.fromRGB(240, 238, 230), Color3.fromRGB(170, 160, 150) },
	{ Color3.fromRGB(45, 42, 40), Color3.fromRGB(25, 24, 22) },
	{ Color3.fromRGB(140, 140, 145), Color3.fromRGB(90, 90, 95) },
}
local BLACK = Color3.fromRGB(25, 25, 30)
local STEEL = Color3.fromRGB(175, 180, 188)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

local rng = Random.new()

function PropModels.hold(kind: Kind): Hold
	return HOLDS[kind]
end

local function part(
	parent: Instance?,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- A bar from one point to another.
local function rod(main: BasePart, name: string, from: Vector3, to: Vector3, thickness: number, color: Color3)
	local length = (to - from).Magnitude
	part(
		main,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt((from + to) / 2, to),
		color,
		Enum.Material.Metal
	)
end

local builders: { [Kind]: () -> Part } = {
	Dog = function(): Part
		local coat = DOG_COATS[rng:NextInteger(1, #DOG_COATS)]
		local fur, dark = coat[1], coat[2]
		local main = part(nil, "Dog", Vector3.new(1.2, 1.1, 2.2), at(0, 1.45, 0.1), fur, Enum.Material.Fabric)
		part(main, "Chest", Vector3.new(1.1, 1.1, 0.8), at(0, 1.85, -0.95), fur, Enum.Material.Fabric)
		part(main, "Head", Vector3.new(1.1, 1, 1.1), at(0, 2.55, -1.45), fur, Enum.Material.Fabric)
		part(main, "Snout", Vector3.new(0.65, 0.45, 0.6), at(0, 2.3, -2.2), dark, Enum.Material.Fabric)
		part(main, "Nose", Vector3.new(0.3, 0.22, 0.12), at(0, 2.45, -2.54), BLACK)
		for _, side in { -1, 1 } do
			part(main, "Eye", Vector3.new(0.16, 0.2, 0.1), at(side * 0.28, 2.75, -2.03), BLACK)
			part(
				main,
				"Ear",
				Vector3.new(0.25, 0.6, 0.4),
				at(side * 0.6, 2.75, -1.35) * CFrame.Angles(0, 0, side * -0.3),
				dark
			)
			for _, z in { -0.75, 0.85 } do
				part(main, "Leg", Vector3.new(0.35, 1, 0.35), at(side * 0.38, 0.5, z), fur, Enum.Material.Fabric)
				part(main, "Paw", Vector3.new(0.4, 0.2, 0.45), at(side * 0.38, 0.1, z - 0.05), dark)
			end
		end
		part(main, "Tail", Vector3.new(0.22, 0.22, 0.9), at(0, 2.15, 1.45) * CFrame.Angles(math.rad(40), 0, 0), dark)
		local collar =
			part(main, "Collar", Vector3.new(1.2, 0.22, 0.9), at(0, 2.25, -0.95), Color3.fromRGB(220, 50, 50))
		local ring = Instance.new("Attachment")
		ring.Name = "Leash"
		ring.Position = Vector3.new(0, 0.1, 0)
		ring.Parent = collar
		return main
	end,

	Mower = function(): Part
		local red = Color3.fromRGB(210, 50, 45)
		local main = part(nil, "Mower", Vector3.new(2.4, 0.6, 2.6), at(0, 0.75, 0), red)
		part(
			main,
			"Engine",
			Vector3.new(1.2, 0.8, 1.2),
			at(0, 1.45, -0.2),
			Color3.fromRGB(60, 60, 66),
			Enum.Material.Metal
		)
		part(main, "FuelCap", Vector3.new(0.25, 0.6, 0.6), at(0, 1.95, -0.2) * UP, BLACK, nil, Enum.PartType.Cylinder)
		for _, x in { -1.3, 1.3 } do
			for _, z in { -0.95, 0.95 } do
				part(main, "Wheel", Vector3.new(0.3, 0.8, 0.8), at(x, 0.4, z), BLACK, nil, Enum.PartType.Cylinder)
			end
			rod(main, "Handle", Vector3.new(x * 0.7, 1, 1.2), Vector3.new(x * 0.7, 3.3, 2.4), 0.15, STEEL)
		end
		part(main, "Grip", Vector3.new(2.1, 0.22, 0.22), at(0, 3.3, 2.4), BLACK)
		part(
			main,
			"GrassBag",
			Vector3.new(1.4, 0.9, 1),
			at(0, 1.3, 1.65),
			Color3.fromRGB(40, 90, 50),
			Enum.Material.Fabric
		)
		return main
	end,

	Bin = function(): Part
		local green = Color3.fromRGB(40, 110, 60)
		local main = part(nil, "Bin", Vector3.new(2, 3, 2), at(0, 1.7, 0), green)
		part(main, "Lid", Vector3.new(2.2, 0.25, 2.3), at(0, 3.3, 0.05), Color3.fromRGB(30, 85, 45))
		part(main, "BinHandle", Vector3.new(1.6, 0.25, 0.3), at(0, 3.1, 1.2), BLACK)
		for _, x in { -0.8, 0.8 } do
			part(main, "Wheel", Vector3.new(0.3, 0.8, 0.8), at(x, 0.4, 1.0), BLACK, nil, Enum.PartType.Cylinder)
		end
		return main
	end,

	Sponge = function(): Part
		local main = part(
			nil,
			"Sponge",
			Vector3.new(1, 0.5, 1.4),
			CFrame.identity,
			Color3.fromRGB(255, 220, 70),
			Enum.Material.Sand
		)
		part(
			main,
			"Scrubber",
			Vector3.new(1, 0.2, 1.4),
			at(0, 0.35, 0),
			Color3.fromRGB(60, 160, 80),
			Enum.Material.Fabric
		)
		return main
	end,

	Letter = function(): Part
		local main = part(
			nil,
			"Letter",
			Vector3.new(1.6, 0.1, 1.1),
			CFrame.identity,
			Color3.fromRGB(245, 238, 220),
			Enum.Material.Fabric
		)
		part(main, "Stamp", Vector3.new(0.3, 0.12, 0.35), at(0.55, 0.01, -0.3), Color3.fromRGB(220, 60, 60))
		for index, z in { 0.05, 0.25 } do
			part(main, `Address{index}`, Vector3.new(0.7, 0.12, 0.07), at(-0.1, 0.01, z), Color3.fromRGB(120, 120, 130))
		end
		return main
	end,

	Package = function(): Part
		local main = part(
			nil,
			"DeliveryPackage",
			Vector3.new(1.6, 1.3, 1.6),
			CFrame.identity,
			Color3.fromRGB(176, 128, 72),
			Enum.Material.Cardboard
		)
		part(main, "Tape", Vector3.new(0.35, 1.34, 1.64), CFrame.identity, Color3.fromRGB(210, 180, 120))
		part(main, "Label", Vector3.new(0.6, 0.05, 0.45), at(0.4, 0.66, 0.4), Color3.new(1, 1, 1))
		return main
	end,

	ShadyPackage = function(): Part
		local main = part(nil, "ShadyPackage", Vector3.new(1.4, 1, 1.4), CFrame.identity, Color3.fromRGB(40, 40, 45))
		part(main, "Tape", Vector3.new(1.44, 0.3, 1.44), CFrame.identity, Color3.fromRGB(230, 190, 40))
		return main
	end,

	Tray = function(): Part
		local main = part(nil, "Tray", Vector3.new(2, 0.15, 1.4), CFrame.identity, Color3.fromRGB(200, 60, 50))
		-- The burger, bottom to top: thickness, width, height and colour of each layer.
		local bun = Color3.fromRGB(225, 160, 80)
		local layers: { { name: string, thick: number, wide: number, y: number, color: Color3 } } = {
			{ name = "BunBottom", thick = 0.2, wide = 0.9, y = 0.18, color = bun },
			{ name = "Patty", thick = 0.18, wide = 0.95, y = 0.37, color = Color3.fromRGB(110, 60, 35) },
			{ name = "Cheese", thick = 0.06, wide = 1, y = 0.48, color = Color3.fromRGB(250, 200, 50) },
			{ name = "BunTop", thick = 0.32, wide = 0.9, y = 0.67, color = bun },
		}
		for _, layer in layers do
			local size = Vector3.new(layer.thick, layer.wide, layer.wide)
			part(main, layer.name, size, at(-0.45, layer.y, 0) * UP, layer.color, nil, Enum.PartType.Cylinder)
		end
		part(main, "Fries", Vector3.new(0.5, 0.6, 0.35), at(0.45, 0.37, -0.25), Color3.fromRGB(220, 50, 45))
		for index, x in { 0.3, 0.42, 0.54, 0.62 } do
			part(main, `Fry{index}`, Vector3.new(0.08, 0.35, 0.08), at(x, 0.8, -0.25), Color3.fromRGB(250, 210, 90))
		end
		part(
			main,
			"Cup",
			Vector3.new(0.75, 0.5, 0.5),
			at(0.6, 0.45, 0.35) * UP,
			Color3.new(1, 1, 1),
			nil,
			Enum.PartType.Cylinder
		)
		part(main, "Straw", Vector3.new(0.08, 0.5, 0.08), at(0.65, 1, 0.35), Color3.fromRGB(220, 50, 45))
		return main
	end,

	Tyre = function(): Part
		local main = part(nil, "Tyre", Vector3.new(1, 2.2, 2.2), CFrame.identity, BLACK, nil, Enum.PartType.Cylinder)
		part(
			main,
			"Hub",
			Vector3.new(1.06, 1.1, 1.1),
			CFrame.identity,
			STEEL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		return main
	end,

	HotDogCart = function(): Part
		local main = part(nil, "HotDogCart", Vector3.new(3, 2.2, 2.2), at(0, 1.6, 0), Color3.fromRGB(235, 235, 235))
		part(main, "Stripe", Vector3.new(3.05, 0.5, 2.25), at(0, 2.1, 0), Color3.fromRGB(220, 50, 50))
		part(main, "Top", Vector3.new(3.3, 0.15, 2.5), at(0, 2.78, 0), STEEL, Enum.Material.Metal)
		for index, x in { -0.6, 0.4 } do
			part(main, `Bun{index}`, Vector3.new(0.9, 0.3, 0.4), at(x, 3, -0.4), Color3.fromRGB(225, 160, 80))
			part(main, `Sausage{index}`, Vector3.new(1.05, 0.22, 0.22), at(x, 3.1, -0.4), Color3.fromRGB(170, 70, 50))
		end
		part(
			main,
			"Mustard",
			Vector3.new(0.6, 0.3, 0.3),
			at(1.1, 3.15, 0.5) * UP,
			Color3.fromRGB(250, 210, 40),
			nil,
			Enum.PartType.Cylinder
		)
		part(
			main,
			"Ketchup",
			Vector3.new(0.6, 0.3, 0.3),
			at(1.1, 3.15, 0.05) * UP,
			Color3.fromRGB(220, 40, 40),
			nil,
			Enum.PartType.Cylinder
		)
		part(main, "Pole", Vector3.new(0.2, 3.4, 0.2), at(0, 4.4, 0.3), STEEL, Enum.Material.Metal)
		part(
			main,
			"Umbrella",
			Vector3.new(0.3, 4.6, 4.6),
			at(0, 6.15, 0.3) * UP,
			Color3.fromRGB(255, 200, 40),
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		part(
			main,
			"UmbrellaTop",
			Vector3.new(0.3, 2.4, 2.4),
			at(0, 6.4, 0.3) * UP,
			Color3.fromRGB(220, 50, 50),
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		rod(main, "PushBar", Vector3.new(-1.2, 2.6, 1.1), Vector3.new(-1.2, 3.4, 2.2), 0.15, STEEL)
		rod(main, "PushBar", Vector3.new(1.2, 2.6, 1.1), Vector3.new(1.2, 3.4, 2.2), 0.15, STEEL)
		part(main, "Grip", Vector3.new(2.6, 0.2, 0.2), at(0, 3.4, 2.2), BLACK)
		for _, x in { -1.2, 1.2 } do
			part(main, "CartWheel", Vector3.new(0.3, 1, 1), at(x, 0.5, 0), BLACK, nil, Enum.PartType.Cylinder)
		end
		return main
	end,
}

-- The prop at the origin (its ground point, or its middle for held things), facing -Z.
function PropModels.build(kind: Kind): Part
	return builders[kind]()
end

-- Moves a freshly built prop (main part and children together) so its origin is at `origin`.
function PropModels.moveTo(main: BasePart, origin: CFrame)
	for _, child in main:GetDescendants() do
		if child:IsA("BasePart") then
			child.CFrame = origin * child.CFrame
		end
	end
	main.CFrame = origin * main.CFrame
end

-- A prop standing in the world (e.g. a bin at the kerb), anchored; its ground point at `cframe`.
function PropModels.place(kind: Kind, cframe: CFrame, parent: Instance): Part
	local main = PropModels.build(kind)
	PropModels.moveTo(main, cframe)
	for _, piece in main:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	main.Anchored = true
	main.Parent = parent
	return main
end

return PropModels
