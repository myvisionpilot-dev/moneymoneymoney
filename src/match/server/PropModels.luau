--!strict
-- Things you carry, push or throw on jobs, built from parts (no Creator Store models): a push
-- mower, a wheelie bin, a sponge, a letter, packages, a burger tray, a tyre, the hot-dog cart,
-- a lost cat, bits of litter, the dog's ball, a bill; and things a job leaves in the world: a
-- doormat, a kennel and its BEWARE OF THE DOG sign, a squirrel, and what the dog leaves behind.
-- PropModels.build makes one at the origin (facing -Z): a main part with the rest as children.
-- Carry puts it in your hands or on the ground in front of you. (The dogs are in Dogs.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Studs = require(ReplicatedStorage.Shared.Studs)

local PropModels = {}

export type Kind =
	"Mower"
	| "Bin"
	| "Sponge"
	| "Letter"
	| "Package"
	| "ShadyPackage"
	| "Tray"
	| "Tyre"
	| "HotDogCart"
	| "Cat"
	| "Litter"
	| "Ball"
	| "Bill"
	| "Poop"
	| "Doormat"
	| "Kennel"
	| "DogSign"
	| "Squirrel"

-- Where it goes: `ground` props stand on the floor (offset from the point under you); `hand`
-- ones are in your right hand (offset from the hand, fingers along -Y); the rest are held in
-- both hands (offset from your middle). `pose` is how you hold it (client/PoseController).
export type Hold = { offset: CFrame, ground: boolean, hand: boolean?, pose: string }

-- In the hand: in front of the fingers, lying flat while the forearm points ahead.
local IN_HAND = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-90), 0, 0)

local HOLDS: { [Kind]: Hold } = {
	Mower = { offset = CFrame.new(0, 0, -3.9), ground = true, pose = "Push" },
	Bin = { offset = CFrame.new(0, 0, -2.8), ground = true, pose = "Push" },
	HotDogCart = { offset = CFrame.new(0, 0, -3.6), ground = true, pose = "Push" },
	Sponge = { offset = IN_HAND, ground = false, hand = true, pose = "Hold" },
	Letter = { offset = IN_HAND, ground = false, hand = true, pose = "Hold" },
	Litter = { offset = IN_HAND, ground = false, hand = true, pose = "Hold" },
	Ball = { offset = CFrame.new(0, -0.45, 0), ground = false, hand = true, pose = "Hold" },
	Bill = { offset = IN_HAND, ground = false, hand = true, pose = "Hold" },
	Package = { offset = CFrame.new(0, 0.15, -1.6), ground = false, pose = "Carry" },
	ShadyPackage = { offset = CFrame.new(0, 0.15, -1.5), ground = false, pose = "Carry" },
	Tray = { offset = CFrame.new(0, 0.3, -1.6), ground = false, pose = "Tray" },
	Tyre = { offset = CFrame.new(0, 0, -1.7), ground = false, pose = "Carry" },
	Cat = { offset = CFrame.new(0, 0.2, -1.4), ground = false, pose = "Carry" },
	-- Never carried (placed in the world), but every kind needs an entry.
	Poop = { offset = CFrame.identity, ground = true, pose = "Carry" },
	Doormat = { offset = CFrame.identity, ground = true, pose = "Carry" },
	Kennel = { offset = CFrame.identity, ground = true, pose = "Carry" },
	DogSign = { offset = CFrame.identity, ground = true, pose = "Carry" },
	Squirrel = { offset = CFrame.identity, ground = true, pose = "Carry" },
}

-- Parts that turn on a joint instead of being welded fast (client/PoseController spins wheels
-- with how fast the prop goes, and rattles the mower's engine).
PropModels.Moving = { Wheel = true, CartWheel = true, Engine = true }

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
	Studs.dress(p)
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

-- A sign's words, on the front of a board.
local function writing(board: BasePart, text: string, color: Color3, background: Color3?, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.3
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(1, 1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
end
PropModels.writing = writing

-- FRAGILE on top of a box, and a dark crack for each knock it's taken (welded on, so it goes
-- wherever the box goes).
function PropModels.fragile(box: BasePart, cracks: number)
	local added: { BasePart } = {}
	if not box:FindFirstChild("Fragile") then
		local sticker = part(
			box,
			"Fragile",
			Vector3.new(1.2, 0.04, 0.6),
			box.CFrame * CFrame.new(0, box.Size.Y / 2 + 0.02, 0),
			Color3.fromRGB(215, 40, 40)
		)
		writing(sticker, "FRAGILE", Color3.new(1, 1, 1), nil, Enum.NormalId.Top)
		table.insert(added, sticker)
	end
	local have = 0
	for _, child in box:GetChildren() do
		if child.Name == "CrackLine" then
			have += 1
		end
	end
	for index = have + 1, cracks do
		local x = (index - 2) * 0.45
		local tilt = CFrame.Angles(0, 0, 0.35 * (if index % 2 == 0 then 1 else -1))
		table.insert(
			added,
			part(
				box,
				"CrackLine",
				Vector3.new(0.08, 0.9, 0.04),
				box.CFrame * CFrame.new(x, 0, -box.Size.Z / 2 - 0.02) * tilt,
				Color3.fromRGB(60, 40, 25)
			)
		)
	end
	for _, piece in added do
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = box
		joint.Part1 = piece
		joint.Parent = piece
	end
end

local builders: { [Kind]: () -> Part } = {
	Ball = function(): Part
		local ball =
			part(nil, "Ball", Vector3.one * 0.7, CFrame.identity, Color3.fromRGB(205, 240, 60), Enum.Material.Fabric)
		ball.Shape = Enum.PartType.Ball
		part(ball, "Seam", Vector3.new(0.72, 0.08, 0.72), CFrame.Angles(0, 0, 0.5), Color3.new(1, 1, 1)).Shape =
			Enum.PartType.Cylinder
		return ball
	end,

	Bill = function(): Part
		local bill = part(nil, "Bill", Vector3.new(1.3, 0.05, 0.62), CFrame.identity, Color3.fromRGB(110, 200, 90))
		part(bill, "Band", Vector3.new(0.32, 0.07, 0.64), CFrame.identity, Color3.fromRGB(245, 235, 200))
		return bill
	end,

	-- What the dog leaves behind: a cartoon swirl.
	Poop = function(): Part
		local brown = Color3.fromRGB(115, 72, 40)
		local main = part(nil, "Poop", Vector3.new(0.9, 0.45, 0.9), at(0, 0.22, 0), brown)
		main.Shape = Enum.PartType.Ball
		part(main, "Middle", Vector3.new(0.65, 0.38, 0.65), at(0, 0.52, 0), brown).Shape = Enum.PartType.Ball
		part(main, "Top", Vector3.new(0.4, 0.3, 0.4), at(0, 0.76, 0), brown).Shape = Enum.PartType.Ball
		part(main, "Tip", Vector3.new(0.16, 0.2, 0.16), at(0.05, 0.92, 0), brown).Shape = Enum.PartType.Ball
		return main
	end,

	-- A WELCOME mat for a delivery's porch (the job marks it so you can aim at it).
	Doormat = function(): Part
		local mat = part(
			nil,
			"Doormat",
			Vector3.new(3.4, 0.12, 2.1),
			at(0, 0.06, 0),
			Color3.fromRGB(150, 95, 50),
			Enum.Material.Fabric
		)
		local inner = part(
			mat,
			"Inner",
			Vector3.new(2.9, 0.14, 1.6),
			at(0, 0.07, 0),
			Color3.fromRGB(190, 135, 70),
			Enum.Material.Fabric
		)
		-- Lying flat, words facing up and reading the right way from the street (-Z is outwards).
		local face = part(
			inner,
			"Words",
			Vector3.new(2.7, 1.2, 0.02),
			at(0, 0.145, 0) * CFrame.Angles(math.rad(90), 0, 0),
			Color3.fromRGB(190, 135, 70)
		)
		face.Transparency = 1
		writing(face, "WELCOME", Color3.fromRGB(95, 55, 25))
		return mat
	end,

	-- A guard dog's kennel: a wooden box with a pitched roof and a dark doorway, facing -Z.
	Kennel = function(): Part
		local wood = Color3.fromRGB(150, 95, 55)
		local roof = Color3.fromRGB(170, 50, 45)
		local main = part(nil, "Kennel", Vector3.new(3.6, 2.8, 3.6), at(0, 1.4, 0), wood, Enum.Material.WoodPlanks)
		main.CanCollide = true
		part(main, "Doorway", Vector3.new(1.6, 1.9, 0.1), at(0, 1.05, -1.8), Color3.fromRGB(25, 18, 14))
		for _, side in { -1, 1 } do
			part(
				main,
				"Roof",
				Vector3.new(2.5, 0.25, 4.2),
				at(side * 1.0, 3.32, 0) * CFrame.Angles(0, 0, -side * math.rad(32)),
				roof,
				Enum.Material.WoodPlanks
			)
		end
		local board =
			part(main, "NameBoard", Vector3.new(1.4, 0.4, 0.06), at(0, 2.35, -1.84), Color3.fromRGB(240, 230, 210))
		writing(board, "DOG", Color3.fromRGB(170, 50, 45))
		return main
	end,

	-- BEWARE OF THE DOG on a stake, facing -Z.
	DogSign = function(): Part
		local main = part(
			nil,
			"DogSign",
			Vector3.new(0.25, 3, 0.25),
			at(0, 1.5, 0),
			Color3.fromRGB(120, 80, 50),
			Enum.Material.Wood
		)
		local board = part(main, "Board", Vector3.new(2.6, 1.3, 0.12), at(0, 2.9, -0.15), Color3.fromRGB(245, 200, 40))
		writing(board, "BEWARE OF THE DOG", Color3.fromRGB(30, 25, 20))
		return main
	end,

	-- A squirrel sitting up, facing -Z, with a big curled tail.
	Squirrel = function(): Part
		local fur = Color3.fromRGB(170, 95, 45)
		local light = Color3.fromRGB(235, 200, 160)
		local main = part(nil, "Squirrel", Vector3.new(0.55, 0.75, 0.6), at(0, 0.45, 0), fur, Enum.Material.Fabric)
		part(main, "Belly", Vector3.new(0.4, 0.5, 0.1), at(0, 0.45, -0.3), light, Enum.Material.Fabric)
		part(main, "Head", Vector3.new(0.45, 0.4, 0.45), at(0, 0.98, -0.1), fur, Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			part(main, "Ear", Vector3.new(0.1, 0.18, 0.1), at(side * 0.15, 1.24, -0.05), fur)
			part(main, "Eye", Vector3.new(0.08, 0.1, 0.05), at(side * 0.12, 1.02, -0.33), BLACK)
		end
		part(
			main,
			"Tail",
			Vector3.new(0.35, 0.9, 0.35),
			at(0, 0.65, 0.42) * CFrame.Angles(math.rad(-20), 0, 0),
			fur,
			Enum.Material.Fabric
		)
		part(main, "TailCurl", Vector3.new(0.38, 0.38, 0.5), at(0, 1.15, 0.3), fur, Enum.Material.Fabric)
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

	Cat = function(): Part
		local fur = Color3.fromRGB(235, 140, 50)
		local stripe = Color3.fromRGB(195, 95, 30)
		local main = part(nil, "Cat", Vector3.new(1, 0.9, 1.6), at(0, 0, 0.1), fur, Enum.Material.Fabric)
		part(main, "Stripe", Vector3.new(1.04, 0.2, 0.3), at(0, 0.36, 0.2), stripe, Enum.Material.Fabric)
		part(main, "Head", Vector3.new(0.95, 0.85, 0.85), at(0, 0.45, -0.85), fur, Enum.Material.Fabric)
		part(main, "Muzzle", Vector3.new(0.5, 0.3, 0.2), at(0, 0.3, -1.3), Color3.fromRGB(250, 235, 215))
		part(main, "Nose", Vector3.new(0.14, 0.1, 0.06), at(0, 0.42, -1.4), Color3.fromRGB(240, 120, 140))
		for _, side in { -1, 1 } do
			part(main, "Eye", Vector3.new(0.14, 0.2, 0.06), at(side * 0.22, 0.6, -1.28), Color3.fromRGB(60, 170, 70))
			part(
				main,
				"Ear",
				Vector3.new(0.12, 0.35, 0.3),
				at(side * 0.3, 0.98, -0.85),
				fur,
				Enum.Material.Fabric,
				Enum.PartType.Wedge
			)
			for _, z in { -0.45, 0.55 } do
				part(main, "Paw", Vector3.new(0.3, 0.3, 0.32), at(side * 0.32, -0.5, z), fur, Enum.Material.Fabric)
			end
		end
		part(
			main,
			"Tail",
			Vector3.new(0.2, 0.2, 1.1),
			at(0.3, 0.45, 1.25) * CFrame.Angles(math.rad(35), 0.4, 0),
			stripe
		)
		return main
	end,

	-- A random bit of rubbish: a screwed-up paper ball, a fizzy drink can or a crisp packet.
	Litter = function(): Part
		local pick = rng:NextInteger(1, 3)
		if pick == 1 then
			local ball = part(nil, "Litter", Vector3.new(0.7, 0.7, 0.7), CFrame.identity, Color3.fromRGB(240, 240, 232))
			ball.Shape = Enum.PartType.Ball
			return ball
		elseif pick == 2 then
			local can = part(
				nil,
				"Litter",
				Vector3.new(1, 0.55, 0.55),
				CFrame.Angles(0, rng:NextNumber(0, 6), 0),
				Color3.fromRGB(215, 40, 45),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
			part(
				can,
				"Band",
				Vector3.new(0.3, 0.57, 0.57),
				can.CFrame,
				Color3.new(1, 1, 1),
				nil,
				Enum.PartType.Cylinder
			)
			return can
		end
		local bag = part(
			nil,
			"Litter",
			Vector3.new(1.1, 0.25, 0.8),
			CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color3.fromRGB(250, 200, 40)
		)
		part(bag, "Print", Vector3.new(0.5, 0.27, 0.4), bag.CFrame, Color3.fromRGB(220, 60, 50))
		return bag
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

-- Like place, but the pieces are welded to an anchored main part, so moving the main part moves
-- the lot (for things that fly through the air: Throwing.fly).
function PropModels.loose(kind: Kind, cframe: CFrame, parent: Instance): Part
	local main = PropModels.build(kind)
	PropModels.moveTo(main, cframe)
	for _, piece in main:GetDescendants() do
		if piece:IsA("BasePart") then
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = main
			joint.Part1 = piece
			joint.Parent = piece
		end
	end
	main.Anchored = true
	main.Parent = parent
	return main
end

return PropModels
