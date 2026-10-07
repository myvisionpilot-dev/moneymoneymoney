-- Something only each shop has, so they don't all look the same: a giant hammer on the
-- hardware store's roof, a burger on Burger Barn's, a barber's pole by the door, a mailbox at
-- the post office... Parts only, no scripts.
--
-- Signatures[name](model, cf, s): `cf` is the shop's frame (x across the front, y up, z back
-- from the front, -z toward the road) and s = { width, height, z0 (the front wall's outside
-- face), wall, accent, trim, fg, font }. Rooftop pieces stand behind the parapet, raised high
-- enough to be seen over it from the street.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)

local shared = ReplicatedStorage:FindFirstChild("Shared")
local looks = shared and shared:FindFirstChild("BlasterLooks")
-- A fresh copy: Studio keeps a module's first require even after its code is updated.
local BlasterLooks = if looks then require(looks:Clone()) :: any else nil

local Signatures = {}

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- and this points them at the road
local M = Enum.Material
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local STEEL = Color3.fromRGB(175, 180, 188)
local WHITE = Color3.fromRGB(245, 245, 240)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- A decor piece in the shop's frame.
local function put(model, cf, name, size, at, color, material, shape)
	local p = Kit.decor(Kit.part(model, name, size, cf * at, color, material))
	if shape then
		p.Shape = shape
	end
	return p
end

-- One you can bump into (on the pavement out front).
local function solid(model, cf, name, size, at, color, material, shape)
	local p = Kit.quiet(Kit.part(model, name, size, cf * at, color, material))
	if shape then
		p.Shape = shape
	end
	return p
end

-- A steel post standing at x, z from y0, h tall.
local function post(model, cf, x, z, y0, h, diameter)
	put(
		model,
		cf,
		"Post",
		Vector3.new(h, diameter or 0.5, diameter or 0.5),
		CFrame.new(x, y0 + h / 2, z) * UP,
		STEEL,
		M.Metal,
		CYLINDER
	)
end

local function roofOf(s)
	return s.height + 1, s.z0 + 5 -- the roof's top, and a spot behind the parapet
end

-- A stun blaster from shared/BlasterLooks at `at` in the shop's frame, `scale` times its size.
function Signatures.blaster(model, cf, at, design, scale)
	local pieces = BlasterLooks and BlasterLooks.pieces(design)
	if not pieces then
		return
	end
	local size = scale or 1
	for _, piece in pieces do
		local p = put(
			model,
			cf,
			"Blaster",
			piece.size * size,
			at * CFrame.new(piece.at.Position * size) * piece.at.Rotation,
			piece.color,
			piece.material or M.SmoothPlastic,
			piece.shape
		)
		p.Reflectance = piece.reflectance or 0
		p.Transparency = piece.transparency or 0
	end
end

Signatures.CornerStore = function(model, cf, s)
	-- An ice chest by the door.
	local x, z = -(s.width / 2 - 3.2), s.z0 - 1.6
	local chest = solid(model, cf, "IceChest", Vector3.new(3.2, 2.2, 1.7), CFrame.new(x, 1.6, z), WHITE)
	Kit.sign(chest, Enum.NormalId.Front, "ICE", WHITE, rgb(40, 110, 210), Enum.Font.Oswald)
	put(model, cf, "IceChestLid", Vector3.new(3.3, 0.35, 1.8), CFrame.new(x, 2.875, z), rgb(60, 130, 220))
end

Signatures.MiniMart = function(model, cf, s)
	-- An OPEN sign stuck on the outside of the window (sign text doesn't show through glass).
	local sign =
		put(model, cf, "OpenSign", Vector3.new(4.2, 1.6, 0.2), CFrame.new(10, 6.6, s.z0 - 0.15), rgb(25, 25, 30))
	Kit.sign(sign, Enum.NormalId.Front, "OPEN", rgb(25, 25, 30), rgb(255, 70, 70), Enum.Font.LuckiestGuy)
end

Signatures.Hardware = function(model, cf, s)
	-- A giant hammer leaning on the roof.
	local roof, back = roofOf(s)
	local base = CFrame.new(s.width * 0.32, roof, back) * CFrame.Angles(0, 0, math.rad(-18))
	put(model, cf, "HammerHandle", Vector3.new(0.9, 7, 0.9), base * CFrame.new(0, 3.5, 0), rgb(150, 105, 70), M.Wood)
	put(model, cf, "HammerGrip", Vector3.new(1, 2, 1), base * CFrame.new(0, 1.2, 0), rgb(200, 50, 40))
	put(model, cf, "HammerHead", Vector3.new(4.6, 1.6, 1.6), base * CFrame.new(0.6, 7.4, 0), rgb(70, 72, 80), M.Metal)
end

Signatures.Clothes = function(model, cf, s)
	-- A giant shopping bag on the roof.
	local roof, back = roofOf(s)
	local x = -s.width / 4
	local bag = put(model, cf, "GiantBag", Vector3.new(5, 7, 2.4), CFrame.new(x, roof + 3.5, back), rgb(255, 170, 215))
	Kit.sign(bag, Enum.NormalId.Front, "BAGS", rgb(255, 170, 215), rgb(35, 28, 40), Enum.Font.Bodoni)
	put(model, cf, "GiantBagBand", Vector3.new(5.1, 0.6, 2.5), CFrame.new(x, roof + 6.6, back), rgb(35, 28, 40))
	for _, z in { -0.7, 0.7 } do
		for _, dx in { -1, 1 } do
			put(
				model,
				cf,
				"BagHandle",
				Vector3.new(0.3, 1.8, 0.3),
				CFrame.new(x + dx, roof + 7.9, back + z),
				rgb(35, 28, 40)
			)
		end
		put(model, cf, "BagHandle", Vector3.new(2.3, 0.3, 0.3), CFrame.new(x, roof + 8.95, back + z), rgb(35, 28, 40))
	end
end

Signatures.GunStore = function(model, cf, s)
	-- A giant Mega Zapper on a post, aimed at the sky.
	local roof, back = roofOf(s)
	local x = s.width / 4
	post(model, cf, x, back, roof, 3.2, 0.7)
	Signatures.blaster(
		model,
		cf,
		CFrame.new(x, roof + 5.8, back) * ALONG * CFrame.Angles(math.rad(15), 0, 0),
		"MegaZapper",
		3
	)
end

Signatures.Burger = function(model, cf, s)
	-- A giant burger on a post.
	local roof, back = roofOf(s)
	local y = roof + 3
	post(model, cf, 0, back, roof, 3, 0.8)
	local function layer(name, height, diameter, at, color)
		put(
			model,
			cf,
			name,
			Vector3.new(height, diameter, diameter),
			CFrame.new(0, y + at, back) * UP,
			color,
			nil,
			CYLINDER
		)
	end
	layer("BunBottom", 1.2, 6, 0.6, rgb(220, 160, 80))
	layer("Patty", 0.9, 6.4, 1.65, rgb(110, 60, 35))
	put(
		model,
		cf,
		"Cheese",
		Vector3.new(5.2, 0.2, 5.2),
		CFrame.new(0, y + 2.2, back) * CFrame.Angles(0, math.rad(45), 0),
		rgb(255, 200, 40)
	)
	layer("Lettuce", 0.3, 6.6, 2.45, rgb(110, 200, 70))
	layer("BunTop", 1.4, 6, 3.3, rgb(220, 160, 80))
	layer("BunDome", 0.6, 4.6, 4.3, rgb(220, 160, 80))
	for index = 0, 5 do
		local angle = index / 6 * math.pi * 2
		put(
			model,
			cf,
			"Seed",
			Vector3.one * 0.4,
			CFrame.new(math.cos(angle) * 1.4, y + 4.65, back + math.sin(angle) * 1.4),
			rgb(250, 240, 210),
			nil,
			BALL
		)
	end
end

Signatures.Depot = function(model, cf, s)
	-- Parcels stacked by the door.
	local x, z = -(s.width / 2 - 3.5), s.z0 - 1.8
	-- { across, bottom, size }: two on the pavement, one on top of the first.
	for index, info in { { 0, 0.5, 2.6 }, { 0.3, 3.1, 2.2 }, { 3.4, 0.5, 2.4 } } do
		local box = solid(
			model,
			cf,
			`Parcel{index}`,
			Vector3.one * info[3],
			CFrame.new(x + info[1], info[2] + info[3] / 2, z) * CFrame.Angles(0, math.rad(index * 11), 0),
			rgb(190, 145, 90),
			M.Cardboard
		)
		box.CanCollide = index ~= 2 -- the top one is just for show
	end
end

Signatures.Taxi = function(model, cf, s)
	-- A big taxi light on the roof.
	local roof, back = roofOf(s)
	post(model, cf, -2, back, roof, 3)
	post(model, cf, 2, back, roof, 3)
	local light =
		put(model, cf, "TaxiLight", Vector3.new(7, 2.2, 2.4), CFrame.new(0, roof + 4.1, back), rgb(255, 210, 50))
	Kit.sign(light, Enum.NormalId.Front, "TAXI", rgb(255, 210, 50), rgb(30, 30, 35), Enum.Font.RobotoCondensed)
end

Signatures.Barber = function(model, cf, s)
	-- A barber's pole out front: red, white and blue on a white base, a gold ball on top.
	local x, z = -s.width / 2 + 2.2, s.z0 - 1
	solid(model, cf, "PoleBase", Vector3.new(0.6, 1.1, 1.1), CFrame.new(x, 0.8, z) * UP, WHITE, nil, CYLINDER)
	local colors = { rgb(220, 40, 50), WHITE, rgb(40, 80, 200) }
	for index = 0, 5 do
		put(
			model,
			cf,
			"PoleStripe",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(x, 1.5 + index * 0.8, z) * UP,
			colors[index % 3 + 1],
			nil,
			CYLINDER
		)
	end
	put(model, cf, "PoleTop", Vector3.one * 0.9, CFrame.new(x, 6.15, z), rgb(240, 196, 60), M.Metal, BALL)
end

Signatures.Laundromat = function(model, cf, s)
	-- Soap bubbles floating up off the roof.
	local roof, back = roofOf(s)
	local x = -s.width / 5
	for index, info in { { 0, 3.5, 3.2 }, { 2.2, 6.2, 2.4 }, { -1.8, 6.8, 2 }, { 0.8, 8.9, 1.6 }, { -0.6, 10.4, 1.2 } } do
		local bubble = put(
			model,
			cf,
			`Bubble{index}`,
			Vector3.one * info[3],
			CFrame.new(x + info[1], roof + info[2], back + (index % 2) * 0.8),
			rgb(190, 225, 255),
			M.Glass,
			BALL
		)
		bubble.Transparency = 0.35
	end
end

Signatures.Cafe = function(model, cf, s)
	-- A giant coffee cup with steam, on a post.
	local roof, back = roofOf(s)
	local x = s.width / 4
	local y = roof + 2.5
	post(model, cf, x, back, roof, 2.5)
	put(model, cf, "Saucer", Vector3.new(0.4, 5.6, 5.6), CFrame.new(x, y + 0.2, back) * UP, WHITE, nil, CYLINDER)
	put(model, cf, "Cup", Vector3.new(4, 4, 4), CFrame.new(x, y + 2.4, back) * UP, WHITE, nil, CYLINDER)
	put(model, cf, "CupBand", Vector3.new(0.8, 4.05, 4.05), CFrame.new(x, y + 2.4, back) * UP, s.accent, nil, CYLINDER)
	put(
		model,
		cf,
		"Coffee",
		Vector3.new(0.2, 3.6, 3.6),
		CFrame.new(x, y + 4.25, back) * UP,
		rgb(90, 55, 30),
		nil,
		CYLINDER
	)
	put(model, cf, "CupHandle", Vector3.new(0.5, 2.2, 0.5), CFrame.new(x + 2.7, y + 2.4, back), WHITE)
	for _, dy in { 1.4, 3.4 } do
		put(model, cf, "CupHandle", Vector3.new(0.8, 0.4, 0.5), CFrame.new(x + 2.25, y + dy, back), WHITE)
	end
	for index, info in { { -0.4, 5.3, 1.2 }, { 0.5, 6.3, 1 }, { -0.2, 7.2, 0.8 } } do
		local puff = put(
			model,
			cf,
			`Steam{index}`,
			Vector3.one * info[3],
			CFrame.new(x + info[1], y + info[2], back),
			WHITE,
			nil,
			BALL
		)
		puff.Transparency = 0.5
	end
end

Signatures.Pharmacy = function(model, cf, s)
	-- A green cross sign sticking out from the wall, seen from along the street.
	local x, y = s.width / 2 - 1.4, s.height - 2
	put(model, cf, "SignArm", Vector3.new(0.3, 0.3, 1.6), CFrame.new(x, y + 1.9, s.z0 - 0.8), STEEL, M.Metal)
	put(model, cf, "CrossBack", Vector3.new(0.5, 3.4, 3.4), CFrame.new(x, y, s.z0 - 2.6), WHITE)
	put(model, cf, "Cross", Vector3.new(0.6, 2.8, 1), CFrame.new(x, y, s.z0 - 2.6), rgb(40, 200, 90), M.Neon)
	put(model, cf, "Cross", Vector3.new(0.6, 1, 2.8), CFrame.new(x, y, s.z0 - 2.6), rgb(40, 200, 90), M.Neon)
end

Signatures.Bakery = function(model, cf, s)
	-- A giant cupcake with a cherry on top.
	local roof, back = roofOf(s)
	local x = -s.width / 4
	local y = roof + 2.5
	post(model, cf, x, back, roof, 2.5)
	put(
		model,
		cf,
		"Wrapper",
		Vector3.new(2.4, 3.6, 3.6),
		CFrame.new(x, y + 1.2, back) * UP,
		rgb(240, 150, 180),
		nil,
		CYLINDER
	)
	put(model, cf, "Frosting", Vector3.one * 4.4, CFrame.new(x, y + 3.6, back), rgb(255, 240, 220), nil, BALL)
	put(model, cf, "Cherry", Vector3.one * 1, CFrame.new(x, y + 6, back), rgb(220, 30, 40), nil, BALL)
	for index = 0, 6 do
		local angle = index / 7 * math.pi * 2
		put(
			model,
			cf,
			"Sprinkle",
			Vector3.one * 0.35,
			CFrame.new(x + math.cos(angle) * 1.5, y + 5.1, back + math.sin(angle) * 1.5),
			({ rgb(80, 160, 240), rgb(250, 200, 50), rgb(120, 210, 90) })[index % 3 + 1],
			nil,
			BALL
		)
	end
end

Signatures.Florist = function(model, cf, s)
	-- A window box full of flowers under the shop window.
	local from, to = -s.width / 2 + 1, s.width / 2 - 8
	put(
		model,
		cf,
		"WindowBox",
		Vector3.new(to - from, 1.1, 1.1),
		CFrame.new((from + to) / 2, 1.75, s.z0 - 0.6),
		rgb(130, 90, 60),
		M.Wood
	)
	local colors = { rgb(240, 90, 140), rgb(250, 210, 70), rgb(170, 110, 240), rgb(230, 60, 60) }
	local count = math.floor((to - from) / 0.9)
	for index = 0, count - 1 do
		put(
			model,
			cf,
			"Flower",
			Vector3.one * 0.8,
			CFrame.new(from + 0.45 + index * 0.9, 2.7 + (index % 2) * 0.2, s.z0 - 0.9),
			colors[index % #colors + 1],
			nil,
			BALL
		)
	end
end

Signatures.PostOffice = function(model, cf, s)
	-- A mailbox out front, and a flag on the roof.
	local x, z = -(s.width / 2 - 2.5), s.z0 - 1.6
	solid(model, cf, "MailboxLeg", Vector3.new(1, 0.8, 0.8), CFrame.new(x, 0.9, z), rgb(40, 40, 46))
	local box = solid(model, cf, "Mailbox", Vector3.new(1.4, 1.8, 1.2), CFrame.new(x, 2.2, z), rgb(40, 70, 160))
	Kit.sign(box, Enum.NormalId.Front, "MAIL", rgb(40, 70, 160), rgb(250, 220, 80), Enum.Font.Merriweather)
	put(
		model,
		cf,
		"MailboxTop",
		Vector3.new(1.1, 1.4, 1.4),
		CFrame.new(x, 3.1, z) * ALONG,
		rgb(40, 70, 160),
		nil,
		CYLINDER
	)
	local roof, back = roofOf(s)
	local poleX = s.width / 2 - 3
	put(
		model,
		cf,
		"Flagpole",
		Vector3.new(8, 0.3, 0.3),
		CFrame.new(poleX, roof + 4, back - 2) * UP,
		WHITE,
		nil,
		CYLINDER
	)
	put(
		model,
		cf,
		"Flag",
		Vector3.new(3.4, 2.2, 0.1),
		CFrame.new(poleX - 1.85, roof + 6.8, back - 2),
		rgb(40, 60, 140),
		M.Fabric
	)
	put(
		model,
		cf,
		"FlagStripe",
		Vector3.new(3.3, 0.6, 0.14),
		CFrame.new(poleX - 1.85, roof + 6.8, back - 2),
		rgb(220, 50, 50),
		M.Fabric
	)
end

Signatures.Diner = function(model, cf, s)
	-- A pink neon line along the cornice, and an EAT sign up top.
	put(
		model,
		cf,
		"NeonLine",
		Vector3.new(s.width + 2, 0.22, 0.2),
		CFrame.new(0, s.height + 4.78, s.z0 - 1.1),
		rgb(255, 80, 160),
		M.Neon
	)
	local roof, back = roofOf(s)
	local x = s.width / 4
	post(model, cf, x - 2.8, back, roof, 5)
	post(model, cf, x + 2.8, back, roof, 5)
	local sign = put(model, cf, "EatSign", Vector3.new(7, 2.6, 0.4), CFrame.new(x, roof + 6.3, back), rgb(30, 30, 40))
	Kit.sign(sign, Enum.NormalId.Front, "EAT", rgb(30, 30, 40), rgb(255, 80, 160), Enum.Font.DenkOne)
end

Signatures.Gym = function(model, cf, s)
	-- A giant dumbbell resting on two stands.
	local roof, back = roofOf(s)
	local y = roof + 5.3
	for _, x in { -2.2, 2.2 } do
		put(model, cf, "Stand", Vector3.new(0.8, 5, 0.8), CFrame.new(x, roof + 2.5, back), rgb(40, 40, 45), M.Metal)
	end
	put(model, cf, "Bar", Vector3.new(7.4, 0.6, 0.6), CFrame.new(0, y, back), STEEL, M.Metal, CYLINDER)
	for _, side in { -1, 1 } do
		put(
			model,
			cf,
			"Weight",
			Vector3.new(0.9, 3.4, 3.4),
			CFrame.new(side * 3, y, back),
			rgb(40, 40, 45),
			nil,
			CYLINDER
		)
		put(
			model,
			cf,
			"Plate",
			Vector3.new(0.5, 2.6, 2.6),
			CFrame.new(side * 3.7, y, back),
			rgb(240, 140, 30),
			nil,
			CYLINDER
		)
		put(model, cf, "Collar", Vector3.new(0.3, 0.9, 0.9), CFrame.new(side * 2.4, y, back), STEEL, M.Metal, CYLINDER)
	end
end

Signatures.Books = function(model, cf, s)
	-- A stack of giant books.
	local roof, back = roofOf(s)
	put(model, cf, "BookPlinth", Vector3.new(5, 2.5, 4), CFrame.new(0, roof + 1.25, back), s.wall)
	local y = roof + 2.5
	for index, info in
		{
			{ 6, 1.3, 4.2, 6, rgb(70, 110, 60) },
			{ 5.4, 1.2, 3.8, -8, rgb(170, 50, 50) },
			{ 5, 1.1, 3.6, 15, rgb(50, 80, 160) },
		}
	do
		local book = CFrame.new(0, y + info[2] / 2, back) * CFrame.Angles(0, math.rad(info[4]), 0)
		put(model, cf, `Book{index}`, Vector3.new(info[1], info[2], info[3]), book, info[5])
		put(
			model,
			cf,
			"Pages",
			Vector3.new(info[1] - 0.3, info[2] - 0.2, 0.15),
			book * CFrame.new(0, 0, -info[3] / 2 - 0.075),
			rgb(245, 240, 225)
		)
		y += info[2]
	end
end

Signatures.PetShop = function(model, cf, s)
	-- A giant dog bone on a post.
	local roof, back = roofOf(s)
	local x = s.width / 4
	local y = roof + 4.3
	post(model, cf, x, back, roof, 3.5)
	put(model, cf, "Bone", Vector3.new(5, 1, 1), CFrame.new(x, y, back), rgb(245, 235, 210), nil, CYLINDER)
	for _, dx in { -2.6, 2.6 } do
		for _, dy in { -0.5, 0.5 } do
			put(
				model,
				cf,
				"BoneEnd",
				Vector3.one * 1.6,
				CFrame.new(x + dx, y + dy, back),
				rgb(245, 235, 210),
				nil,
				BALL
			)
		end
	end
end

Signatures.Toys = function(model, cf, s)
	-- Giant A, B, C blocks.
	local roof, back = roofOf(s)
	put(model, cf, "BlockPlinth", Vector3.new(6.6, 2.4, 3), CFrame.new(0, roof + 1.2, back), s.wall)
	local y = roof + 2.4
	for index, info in
		{
			{ "A", -1.5, 1.4, 0, rgb(230, 60, 60) },
			{ "B", 1.5, 1.4, 0, rgb(60, 110, 230) },
			{ "C", 0, 4.2, 10, rgb(250, 200, 50) },
		}
	do
		local block = put(
			model,
			cf,
			`Block{index}`,
			Vector3.one * 2.8,
			CFrame.new(info[2], y + info[3], back) * CFrame.Angles(0, math.rad(info[4]), 0),
			info[5]
		)
		Kit.sign(block, Enum.NormalId.Front, info[1], info[5], WHITE, Enum.Font.LuckiestGuy)
	end
end

Signatures.Music = function(model, cf, s)
	-- A giant record leaning on the roof, and a music note.
	local roof, back = roofOf(s)
	local x = -s.width / 4
	local record = CFrame.new(x, roof + 4.3, back) * CFrame.Angles(0, 0, math.rad(12)) * ALONG
	put(model, cf, "Record", Vector3.new(0.3, 6.5, 6.5), record, rgb(20, 20, 24), nil, CYLINDER)
	put(model, cf, "RecordLabel", Vector3.new(0.36, 2.2, 2.2), record, rgb(200, 50, 60), nil, CYLINDER)
	put(model, cf, "RecordHole", Vector3.new(0.42, 0.3, 0.3), record, rgb(20, 20, 24), nil, CYLINDER)
	local noteX = s.width / 4
	post(model, cf, noteX, back, roof, 2)
	put(model, cf, "NoteHead", Vector3.one * 1.6, CFrame.new(noteX, roof + 2.8, back), rgb(20, 20, 24), nil, BALL)
	put(model, cf, "NoteStem", Vector3.new(0.3, 3.4, 0.3), CFrame.new(noteX + 0.65, roof + 4.5, back), rgb(20, 20, 24))
	put(model, cf, "NoteFlag", Vector3.new(1.3, 0.45, 0.3), CFrame.new(noteX + 1.2, roof + 5.9, back), rgb(20, 20, 24))
end

return Signatures
