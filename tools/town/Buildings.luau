-- The bank on the plaza and every shop along the main roads.
--
-- Tags placed here: BankCounter + BankSpawn + SafeZone (deposits, spawning, no blasting),
-- StaffSpot (Mr. Penny, every shopkeeper and the people at the job desks), ShopCounter with Shop
-- and Staff attributes (Clothes, Hardware, Garage, Guns, Convenience: talk to the shopkeeper to
-- buy or rob), StoreZone (the convenience stores' door bell), DeliveryDepot, AlleyDrop,
-- JailCell + JailExit (the cell inside the police station).

local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)

local Buildings = {}

local DEPTH = Layout.SHOP_DEPTH
local DOOR = 10 -- door gap width
local DOOR_HEIGHT = 10

local PRODUCT_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 190, 90),
	Color3.fromRGB(70, 140, 235),
	Color3.fromRGB(240, 130, 200),
	Color3.fromRGB(255, 150, 50),
}
local rng = Random.new(7) -- same shelves every build

-- The slot's frame: centre on the ground, looking out of the shop front toward the road.
local function frameOf(slot)
	return CFrame.lookAt(slot.center, slot.center + slot.facing)
end

-- Part placed in a shop's local space (x across the front, y up, z from front -D/2 to back D/2).
local function piece(model, cf, name, size, x, y, z, color, material)
	return Kit.part(model, name, size, cf * CFrame.new(x, y, z), color, material)
end

local function staffSpot(model, cf, who, z, x)
	-- Standing behind the counter, facing the customers (the shop's frame looks out the front).
	local spot = Kit.marker(model, `{who}Spot`, cf * CFrame.new(x or 0, 0.9, z), "StaffSpot")
	spot:SetAttribute("Staff", who)
	return spot
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

-- A small decor piece in a shop's local space.
local function bit(model, cf, name, size, at, color, material, shape)
	local p = Kit.decor(Kit.part(model, name, size, cf * at, color, material))
	if shape then
		p.Shape = shape
	end
	return p
end

-- One shelf slot's worth of stock at `at` (on the shelf, facing the aisle along -X): cereal
-- boxes, cans, bottles or crisps; or for the hardware store paint tins, toolboxes and boxes.
local GROCERY = { "Cereal", "Cans", "Bottles", "Crisps" }
local HARDWARE = { "Paint", "Toolbox", "Boxes" }
local function stock(model, at, kind, color)
	if kind == "Cereal" then
		for _, z in { -0.6, 0.6 } do
			bit(model, at, "Cereal", Vector3.new(0.5, 1.5, 1), CFrame.new(0, 0.75, z), color)
			bit(model, at, "CerealBand", Vector3.new(0.56, 0.35, 1.06), CFrame.new(0, 1.25, z), Kit.Colors.White)
		end
	elseif kind == "Cans" then
		for _, z in { -0.75, 0, 0.75 } do
			bit(
				model,
				at,
				"Can",
				Vector3.new(0.85, 0.6, 0.6),
				CFrame.new(0, 0.43, z) * UP,
				color,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
	elseif kind == "Bottles" then
		for _, z in { -0.5, 0.5 } do
			bit(
				model,
				at,
				"Bottle",
				Vector3.new(1, 0.55, 0.55),
				CFrame.new(0, 0.5, z) * UP,
				color,
				Enum.Material.Glass,
				Enum.PartType.Cylinder
			)
			bit(
				model,
				at,
				"Cap",
				Vector3.new(0.35, 0.25, 0.25),
				CFrame.new(0, 1.15, z) * UP,
				Kit.Colors.White,
				nil,
				Enum.PartType.Cylinder
			)
		end
	elseif kind == "Crisps" then
		for _, z in { -0.55, 0.55 } do
			bit(model, at, "Crisps", Vector3.new(0.45, 1.1, 0.9), CFrame.new(0, 0.55, z), color, Enum.Material.Foil)
			bit(
				model,
				at,
				"Crimp",
				Vector3.new(0.3, 0.12, 0.92),
				CFrame.new(0, 1.16, z),
				Color3.fromRGB(200, 200, 205),
				Enum.Material.Foil
			)
		end
	elseif kind == "Paint" then
		for _, z in { -0.6, 0.6 } do
			bit(
				model,
				at,
				"PaintTin",
				Vector3.new(1, 0.9, 0.9),
				CFrame.new(0, 0.5, z) * UP,
				Color3.fromRGB(190, 195, 200),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
			bit(
				model,
				at,
				"PaintLabel",
				Vector3.new(0.5, 0.92, 0.92),
				CFrame.new(0, 0.5, z) * UP,
				color,
				nil,
				Enum.PartType.Cylinder
			)
		end
	elseif kind == "Toolbox" then
		bit(model, at, "Toolbox", Vector3.new(0.8, 0.7, 1.6), CFrame.new(0, 0.35, 0), color, Enum.Material.Metal)
		bit(model, at, "ToolboxHandle", Vector3.new(0.15, 0.2, 0.9), CFrame.new(0, 0.8, 0), Color3.fromRGB(30, 30, 35))
	else
		for index, z in { -0.55, 0.55 } do
			bit(
				model,
				at,
				"Box",
				Vector3.new(0.9, 0.8 + index * 0.15, 1),
				CFrame.new(0, 0.4 + index * 0.075, z),
				Color3.fromRGB(190, 145, 90),
				Enum.Material.Cardboard
			)
		end
	end
end

local function ceilingLight(model, cf, width, height)
	local lamp = Kit.decor(
		piece(
			model,
			cf,
			"Light",
			Vector3.new(width, 0.3, 1.2),
			0,
			height - 0.3,
			0,
			Color3.fromRGB(255, 250, 230),
			Enum.Material.Neon
		)
	)
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1
	light.Parent = lamp
end

-- The street side of a business whose front wall's outside face is at depth z0: paving out to
-- the footpath, corner pilasters, a parapet with a cornice and a framed sign in the shop's own
-- lettering, a striped awning, and planters by the door. `style` = { wall, accent, trim, text,
-- fg, font, awning (stripe colours), height of the awning's top (awningTop), planters (x of each) }.
local PATH_EDGE = -(41 - Layout.EDGE) -- the footpath's outer edge, in a shop's frame
local function storefront(model, cf, width, height, z0, style)
	local trim = style.trim or Kit.Colors.White
	-- Paving from the front wall out to the footpath (it would be bare ground otherwise).
	local gap = z0 - (PATH_EDGE + 0.05)
	if gap > 0.1 then
		Kit.quiet(
			piece(
				model,
				cf,
				"Forecourt",
				Vector3.new(width + 3.8, 0.5, gap),
				0,
				0.25,
				z0 - gap / 2,
				Color3.fromRGB(205, 200, 190),
				Enum.Material.Concrete
			)
		)
	end
	for _, side in { -1, 1 } do
		Kit.quiet(
			piece(
				model,
				cf,
				"Pilaster",
				Vector3.new(1.4, height + 3.4, 1.3),
				side * (width / 2 + 0.1),
				0.02 + (height + 3.4) / 2,
				z0 - 0.2,
				trim
			)
		)
	end
	Kit.quiet(piece(model, cf, "Parapet", Vector3.new(width + 1.2, 3.6, 1.2), 0, height + 2.75, z0 - 0.1, style.wall))
	Kit.decor(piece(model, cf, "Cornice", Vector3.new(width + 2, 0.5, 1.8), 0, height + 4.78, z0 - 0.1, trim))
	Kit.board(model, "Sign", math.min(width * 0.72, 32), 2.5, cf * CFrame.new(0, height + 2.75, z0 - 0.92), {
		text = style.text or style.sign,
		bg = style.accent,
		fg = style.fg,
		font = style.font,
		frame = trim,
	})
	-- The awning clears the door's frame (low shops get a shallower one).
	local top = style.awningTop or math.min(DOOR_HEIGHT + 2.4, height - 0.4)
	Kit.awning(
		model,
		width - 2,
		3.2,
		style.awningDrop or math.min(1.8, top - DOOR_HEIGHT - 0.45),
		cf * CFrame.new(0, top, z0 - 0.06),
		style.awning or { style.accent, Kit.Colors.White }
	)
	for index, x in style.planters or { -(DOOR / 2 + 2.4), DOOR / 2 + 2.4 } do
		Kit.planter(model, (cf * CFrame.new(x, 0.52, z0 - 1.1)).Position, cf.Rotation, index)
	end
end

-- A shop you can walk into: walls, a glass front with a door gap, roof, and the storefront.
local function walkIn(parent, name, slot, style)
	local cf = frameOf(slot)
	local width, height = slot.width, style.height or 14
	local model = Kit.model(parent, name)
	local front = -DEPTH / 2 + 0.5
	-- The floor stops just inside the walls' outer faces (matching faces flicker).
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(width - 0.4, 0.4, DEPTH - 0.4),
		0,
		0.2,
		0,
		style.floor or Color3.fromRGB(232, 228, 214),
		Enum.Material.Marble
	)
	piece(model, cf, "BackWall", Vector3.new(width, height, 1), 0, height / 2, DEPTH / 2 - 0.5, style.wall)
	for _, side in { -1, 1 } do
		piece(model, cf, "SideWall", Vector3.new(1, height, DEPTH), side * (width / 2 - 0.5), height / 2, 0, style.wall)
		local segment = width / 2 - DOOR / 2
		local x = side * (DOOR / 2 + segment / 2)
		piece(model, cf, "FrontBase", Vector3.new(segment, 3, 1), x, 1.5, front, style.wall)
		-- The glass stops at the side wall's inside face.
		local glassWidth = segment - 1
		local glass = piece(
			model,
			cf,
			"Window",
			Vector3.new(glassWidth, DOOR_HEIGHT - 3, 0.4),
			side * (DOOR / 2 + glassWidth / 2),
			3 + (DOOR_HEIGHT - 3) / 2,
			front,
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
		glass.Transparency = 0.5
		piece(
			model,
			cf,
			"FrontTop",
			Vector3.new(segment, height - DOOR_HEIGHT, 1),
			x,
			DOOR_HEIGHT + (height - DOOR_HEIGHT) / 2,
			front,
			style.wall
		)
	end
	piece(
		model,
		cf,
		"Lintel",
		Vector3.new(DOOR, height - DOOR_HEIGHT, 1),
		0,
		DOOR_HEIGHT + (height - DOOR_HEIGHT) / 2,
		front,
		style.wall
	)
	piece(model, cf, "Roof", Vector3.new(width + 1, 1, DEPTH + 1), 0, height + 0.5, 0, Kit.Colors.White)
	storefront(model, cf, width, height, -DEPTH / 2, style)
	-- An open doorway: a frame round it.
	for _, side in { -1, 1 } do
		Kit.quiet(
			piece(
				model,
				cf,
				"DoorJamb",
				Vector3.new(0.8, DOOR_HEIGHT - 0.65, 1.3),
				side * (DOOR / 2 - 0.2),
				0.45 + (DOOR_HEIGHT - 0.65) / 2,
				front,
				style.trim or Kit.Colors.White
			)
		)
	end
	Kit.decor(
		piece(
			model,
			cf,
			"DoorHeader",
			Vector3.new(DOOR + 1.4, 0.5, 1.3),
			0,
			DOOR_HEIGHT + 0.05,
			front,
			style.trim or Kit.Colors.White
		)
	)
	-- Window bars: a few uprights, a crossbar and a sill under each window.
	for _, side in { -1, 1 } do
		local from, to = DOOR / 2 + 0.2, width / 2 - 1
		local span = to - from
		local count = math.floor(span / 5)
		for index = 1, count do
			local x = side * (from + span * index / (count + 1))
			Kit.decor(
				piece(
					model,
					cf,
					"Mullion",
					Vector3.new(0.3, DOOR_HEIGHT - 3, 0.3),
					x,
					3 + (DOOR_HEIGHT - 3) / 2,
					front - 0.36,
					style.trim or Kit.Colors.White
				)
			)
		end
		local middle = side * (from + to) / 2
		Kit.decor(
			piece(
				model,
				cf,
				"Transom",
				Vector3.new(span, 0.3, 0.3),
				middle,
				8.2,
				front - 0.36,
				style.trim or Kit.Colors.White
			)
		)
		Kit.decor(
			piece(
				model,
				cf,
				"Sill",
				Vector3.new(span - 0.2, 0.3, 1),
				middle,
				3,
				front - 0.55,
				style.trim or Kit.Colors.White
			)
		)
	end
	-- Inside: framed posters on the side walls, above the shelves.
	for index, side in { -1, 1 } do
		local text = style.posters and style.posters[index]
		if text then
			local x = side * (width / 2 - 1.15)
			Kit.decor(piece(model, cf, "PosterFrame", Vector3.new(0.2, 3.6, 5.6), x, 10, 2, Color3.fromRGB(40, 40, 46)))
			local poster =
				Kit.decor(piece(model, cf, "Poster", Vector3.new(0.16, 3, 5), x - side * 0.1, 10, 2, style.accent))
			Kit.sign(
				poster,
				if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
				text,
				style.accent,
				style.fg,
				style.font
			)
		end
	end
	ceilingLight(model, cf, width * 0.5, height)
	return model, cf
end

-- A few things inside each small business's front room (a barber's chair, washing machines,
-- a coffee machine...). `x` is across the room, `z` from its back (0) toward the window.
local ROOM_BACK = -9 -- the front room runs from the window (z -19) back to here
local function roomBit(model, cf, name, size, x, y, z, color, material, shape, turn)
	return bit(
		model,
		cf,
		name,
		size,
		CFrame.new(x, y, ROOM_BACK - z) * (turn or CFrame.identity),
		color,
		material,
		shape
	)
end
local FACING = CFrame.Angles(0, math.rad(90), 0) -- a cylinder facing out of the room
local EXTRAS = {
	Barber = function(model, cf, w)
		roomBit(model, cf, "ChairSeat", Vector3.new(2.2, 0.8, 2.2), -w / 4, 2.4, 4, Color3.fromRGB(200, 40, 50))
		roomBit(model, cf, "ChairBack", Vector3.new(2.2, 2.2, 0.5), -w / 4, 3.6, 3, Color3.fromRGB(200, 40, 50))
		roomBit(
			model,
			cf,
			"ChairBase",
			Vector3.new(2, 0.6, 0.6),
			-w / 4,
			1.4,
			4,
			Color3.fromRGB(190, 195, 200),
			Enum.Material.Metal,
			Enum.PartType.Cylinder,
			UP
		)
		roomBit(
			model,
			cf,
			"Mirror",
			Vector3.new(4, 4, 0.2),
			-w / 4,
			6,
			0.4,
			Color3.fromRGB(200, 225, 240),
			Enum.Material.Glass
		)
		-- The striped pole outside, by the window.
		for index, color in
			{ Color3.fromRGB(220, 40, 50), Kit.Colors.White, Color3.fromRGB(40, 80, 200), Kit.Colors.White }
		do
			bit(
				model,
				cf,
				"BarberPole",
				Vector3.new(0.8, 0.8, 0.8),
				CFrame.new(-w / 2 + 2.6, 3.6 + index * 0.8, -19.45) * UP,
				color,
				nil,
				Enum.PartType.Cylinder
			)
		end
	end,
	Laundromat = function(model, cf, w)
		for index = 0, 2 do
			local x = -w / 2 + 4 + index * 3.6
			roomBit(model, cf, "Washer", Vector3.new(3.2, 3.6, 2.6), x, 2.2, 1.5, Kit.Colors.White, Enum.Material.Metal)
			roomBit(
				model,
				cf,
				"WasherDoor",
				Vector3.new(0.2, 2, 2),
				x,
				2.4,
				2.85,
				Color3.fromRGB(60, 90, 130),
				Enum.Material.Glass,
				Enum.PartType.Cylinder,
				FACING
			)
		end
	end,
	Cafe = function(model, cf)
		roomBit(
			model,
			cf,
			"CoffeeMachine",
			Vector3.new(2, 2, 1.4),
			2.5,
			4.4,
			3.6,
			Color3.fromRGB(190, 195, 200),
			Enum.Material.Metal
		)
		for index = 0, 2 do
			roomBit(
				model,
				cf,
				"Cup",
				Vector3.new(0.7, 0.5, 0.5),
				-1 + index * 0.8,
				3.75,
				3.4,
				Kit.Colors.White,
				nil,
				Enum.PartType.Cylinder,
				UP
			)
		end
		local menu = roomBit(model, cf, "Menu", Vector3.new(6, 3, 0.2), 0, 8, 0.4, Color3.fromRGB(35, 35, 35))
		Kit.sign(
			menu,
			Enum.NormalId.Front,
			"COFFEE  TEA  CAKE",
			Color3.fromRGB(35, 35, 35),
			Kit.Colors.White,
			Enum.Font.IndieFlower
		)
	end,
	Pharmacy = function(model, cf)
		roomBit(
			model,
			cf,
			"CrossV",
			Vector3.new(1, 3, 0.3),
			0,
			8,
			0.45,
			Color3.fromRGB(40, 200, 90),
			Enum.Material.Neon
		)
		roomBit(model, cf, "CrossH", Vector3.new(3, 1, 0.3), 0, 8, 0.5, Color3.fromRGB(40, 200, 90), Enum.Material.Neon)
		for index = 0, 3 do
			roomBit(model, cf, "Box", Vector3.new(1, 1.2, 0.8), -5 + index * 1.3, 4, 3.5, PRODUCT_COLORS[index + 1])
		end
	end,
	Bakery = function(model, cf)
		for index = 0, 2 do
			roomBit(
				model,
				cf,
				"Cake",
				Vector3.new(0.8, 1.6, 1.6),
				-3 + index * 2.4,
				3.8,
				3.5,
				Color3.fromRGB(245, 190, 210),
				nil,
				Enum.PartType.Cylinder,
				UP
			)
		end
		-- Bread on a shelf to the left of the baker.
		for index = 0, 2 do
			roomBit(
				model,
				cf,
				"Loaf",
				Vector3.new(1.6, 0.7, 0.9),
				-12.5 + index * 2.2,
				6.4,
				0.7,
				Color3.fromRGB(200, 140, 70)
			)
		end
		roomBit(model, cf, "BreadShelf", Vector3.new(8, 0.3, 1.2), -10.5, 5.9, 0.7, Kit.Colors.Wood, Enum.Material.Wood)
	end,
	Florist = function(model, cf, w)
		for index = 0, 4 do
			local x = -w / 2 + 3 + index * 2.4
			roomBit(
				model,
				cf,
				"Bucket",
				Vector3.new(1.3, 1.3, 1.3),
				x,
				1.05,
				8.2,
				Color3.fromRGB(120, 130, 140),
				Enum.Material.Metal,
				Enum.PartType.Cylinder,
				UP
			)
			for flower = 0, 2 do
				local ball = roomBit(
					model,
					cf,
					"Bloom",
					Vector3.one * 0.8,
					x + (flower - 1) * 0.4,
					2.3 + flower % 2 * 0.3,
					8.2,
					PRODUCT_COLORS[(index + flower) % #PRODUCT_COLORS + 1]
				)
				ball.Shape = Enum.PartType.Ball
			end
		end
	end,
	PostOffice = function(model, cf, w)
		for index = 0, 4 do
			roomBit(
				model,
				cf,
				"Parcel",
				Vector3.new(1.6, 1.2, 1.4),
				-w / 2 + 3 + index % 3 * 1.8,
				1.0 + math.floor(index / 3) * 1.2,
				1.5,
				Color3.fromRGB(190, 145, 90),
				Enum.Material.Cardboard
			)
		end
		-- A red post box outside.
		bit(
			model,
			cf,
			"PostBox",
			Vector3.new(4, 1.6, 1.6),
			CFrame.new(-w / 2 + 3, 2.52, -21.2) * UP,
			Color3.fromRGB(210, 40, 40),
			nil,
			Enum.PartType.Cylinder
		)
		bit(
			model,
			cf,
			"PostBoxTop",
			Vector3.new(0.4, 1.9, 1.9),
			CFrame.new(-w / 2 + 3, 4.6, -21.2) * UP,
			Color3.fromRGB(30, 30, 35),
			nil,
			Enum.PartType.Cylinder
		)
	end,
	Diner = function(model, cf)
		local open = roomBit(
			model,
			cf,
			"OpenSign",
			Vector3.new(3.4, 1.4, 0.2),
			-6,
			7.2,
			9,
			Color3.fromRGB(255, 70, 110),
			Enum.Material.Neon
		)
		Kit.sign(open, Enum.NormalId.Front, "OPEN", Color3.fromRGB(255, 70, 110), Kit.Colors.White, Enum.Font.Bangers)
		for index = 0, 2 do
			roomBit(
				model,
				cf,
				"Stool",
				Vector3.new(0.4, 1.4, 1.4),
				-3 + index * 3,
				2.6,
				5.8,
				Color3.fromRGB(220, 40, 50),
				nil,
				Enum.PartType.Cylinder,
				UP
			)
			roomBit(
				model,
				cf,
				"StoolLeg",
				Vector3.new(2.1, 0.3, 0.3),
				-3 + index * 3,
				1.42,
				5.8,
				Color3.fromRGB(190, 195, 200),
				Enum.Material.Metal,
				Enum.PartType.Cylinder,
				UP
			)
		end
	end,
	Gym = function(model, cf, w)
		roomBit(
			model,
			cf,
			"Bench",
			Vector3.new(6, 2, 1.2),
			-w / 4,
			1.4,
			1.5,
			Color3.fromRGB(40, 40, 45),
			Enum.Material.Metal
		)
		for index = 0, 2 do
			roomBit(
				model,
				cf,
				"Dumbbell",
				Vector3.new(1.6, 0.6, 0.6),
				-w / 4 - 2 + index * 2,
				2.7,
				1.5,
				Color3.fromRGB(60, 60, 66),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
		roomBit(
			model,
			cf,
			"PunchBag",
			Vector3.new(4, 1.6, 1.6),
			w / 4,
			5.5,
			6,
			Color3.fromRGB(200, 40, 40),
			nil,
			Enum.PartType.Cylinder,
			UP
		)
		roomBit(
			model,
			cf,
			"Chain",
			Vector3.new(0.15, 5.3, 0.15),
			w / 4,
			10.15,
			6,
			Color3.fromRGB(120, 120, 128),
			Enum.Material.Metal
		)
	end,
	Books = function(model, cf)
		-- Shelves of books to the left of the bookseller.
		for row = 0, 2 do
			roomBit(
				model,
				cf,
				"BookShelf",
				Vector3.new(8, 0.3, 1.2),
				-11,
				4 + row * 2.2,
				0.7,
				Kit.Colors.Wood,
				Enum.Material.Wood
			)
			for book = 0, 5 do
				roomBit(
					model,
					cf,
					"Book",
					Vector3.new(0.9, 1.5, 1),
					-14 + book * 1.2,
					4.9 + row * 2.2,
					0.7,
					PRODUCT_COLORS[(book + row) % #PRODUCT_COLORS + 1]
				)
			end
		end
	end,
	PetShop = function(model, cf)
		local tank = roomBit(
			model,
			cf,
			"FishTank",
			Vector3.new(4, 2.2, 1.6),
			3,
			4.5,
			3.5,
			Color3.fromRGB(80, 170, 230),
			Enum.Material.Glass
		)
		tank.Transparency = 0.35
		for index = 0, 1 do
			roomBit(
				model,
				cf,
				"Fish",
				Vector3.new(0.6, 0.35, 0.2),
				2.3 + index * 1.3,
				4.3 + index * 0.4,
				3.5,
				Color3.fromRGB(255, 150, 40)
			)
		end
	end,
	Toys = function(model, cf)
		local brown = Color3.fromRGB(170, 110, 60)
		for _, info in { { "TeddyBody", 1.4, 4.1 }, { "TeddyHead", 1, 5.1 } } do
			roomBit(model, cf, info[1], Vector3.one * info[2], 3, info[3], 3.5, brown).Shape = Enum.PartType.Ball
		end
		for index = 0, 2 do
			roomBit(model, cf, "Block", Vector3.one * 0.8, -3 + index * 0.9, 3.8, 3.4, PRODUCT_COLORS[index + 1])
		end
	end,
	Music = function(model, cf)
		for index, x in { -3, 3 } do
			local color = if index == 1 then Color3.fromRGB(200, 60, 40) else Color3.fromRGB(40, 40, 45)
			roomBit(model, cf, "GuitarBody", Vector3.new(1.8, 2.2, 0.4), x, 6.5, 0.5, color)
			roomBit(model, cf, "GuitarNeck", Vector3.new(0.35, 3, 0.25), x, 9, 0.5, Kit.Colors.Wood, Enum.Material.Wood)
		end
		roomBit(
			model,
			cf,
			"Drum",
			Vector3.new(1.4, 2, 2),
			-4,
			1.1,
			6.5,
			Kit.Colors.White,
			nil,
			Enum.PartType.Cylinder,
			UP
		)
	end,
}

-- A small business you can't walk into: a solid building with a lit front room behind a big
-- window, where someone stands behind the counter (a StaffSpot). `look` = { wall, accent, fg,
-- text, font, staff, kind, inside (wall colour of the room) }.
local function frontRoom(parent, name, slot, look)
	local cf = frameOf(slot)
	local width, height = slot.width - 4, 13
	local z0 = -DEPTH / 2 + 2 -- the front wall's outside face
	local model = Kit.model(parent, name)
	-- The solid back of the building, and the room in front of it.
	Kit.quiet(
		piece(
			model,
			cf,
			"Body",
			Vector3.new(width, height, -ROOM_BACK + DEPTH / 2 - 2),
			0,
			height / 2,
			(ROOM_BACK + DEPTH / 2 - 2) / 2,
			look.wall
		)
	)
	piece(model, cf, "Roof", Vector3.new(width + 1, 1, DEPTH - 3), 0, height + 0.5, 0, Kit.Colors.White)
	local room = (z0 + ROOM_BACK) / 2
	local roomDepth = ROOM_BACK - z0
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(width - 0.4, 0.4, roomDepth - 0.4),
		0,
		0.2,
		room,
		Color3.fromRGB(150, 110, 80),
		Enum.Material.WoodPlanks
	)
	for _, side in { -1, 1 } do
		piece(
			model,
			cf,
			"SideWall",
			Vector3.new(1, height, roomDepth),
			side * (width / 2 - 0.5),
			height / 2,
			room,
			look.wall
		)
	end
	Kit.decor(
		piece(
			model,
			cf,
			"Wallpaper",
			Vector3.new(width - 2.2, height - 0.6, 0.2),
			0,
			height / 2,
			ROOM_BACK - 0.15,
			look.inside
		)
	)
	-- The front wall: a sill under the window, a band above it, and a closed door on the right.
	local face = z0 + 0.5
	local doorX = width / 2 - 4.5
	piece(model, cf, "FrontBase", Vector3.new(width, 2.5, 1), 0, 1.25, face, look.wall)
	piece(model, cf, "FrontTop", Vector3.new(width, height - 9, 1), 0, 9 + (height - 9) / 2, face, look.wall)
	piece(model, cf, "FrontEnd", Vector3.new(1, 6.5, 1), -width / 2 + 0.5, 5.75, face, look.wall)
	piece(model, cf, "DoorWall", Vector3.new(8, 6.5, 1), width / 2 - 4, 5.75, face, look.wall)
	local glassFrom, glassTo = -width / 2 + 1, width / 2 - 8
	local glass = Kit.quiet(
		piece(
			model,
			cf,
			"Window",
			Vector3.new(glassTo - glassFrom, 6.5, 0.4),
			(glassFrom + glassTo) / 2,
			5.75,
			face,
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
	)
	glass.Transparency = 0.55
	for _, x in { glassFrom + (glassTo - glassFrom) / 3, glassFrom + (glassTo - glassFrom) * 2 / 3 } do
		Kit.decor(
			piece(model, cf, "Mullion", Vector3.new(0.3, 6.5, 0.3), x, 5.75, face - 0.36, look.trim or Kit.Colors.White)
		)
	end
	Kit.decor(
		piece(
			model,
			cf,
			"Sill",
			Vector3.new(glassTo - glassFrom + 0.4, 0.3, 1),
			(glassFrom + glassTo) / 2,
			2.5,
			face - 0.55,
			look.trim or Kit.Colors.White
		)
	)
	Kit.decor(
		piece(
			model,
			cf,
			"Door",
			Vector3.new(4, 7.6, 0.3),
			doorX,
			4.32,
			z0 - 0.2,
			Color3.fromRGB(110, 70, 45),
			Enum.Material.Wood
		)
	)
	Kit.decor(
		piece(model, cf, "DoorFrame", Vector3.new(4.8, 8, 0.2), doorX, 4.52, z0 - 0.06, look.trim or Kit.Colors.White)
	)
	local knob = Kit.decor(
		piece(
			model,
			cf,
			"Knob",
			Vector3.one * 0.35,
			doorX - 1.4,
			4.3,
			z0 - 0.4,
			Color3.fromRGB(230, 190, 60),
			Enum.Material.Metal
		)
	)
	knob.Shape = Enum.PartType.Ball
	-- Inside: a counter with someone behind it, and a light.
	Kit.quiet(
		piece(
			model,
			cf,
			"Counter",
			Vector3.new(width * 0.4, 3, 1.8),
			2,
			1.9,
			ROOM_BACK - 3.4,
			look.accent,
			Enum.Material.Wood
		)
	)
	staffSpot(model, cf, look.staff, ROOM_BACK - 1.4, 2)
	local lamp = Kit.decor(
		piece(
			model,
			cf,
			"Light",
			Vector3.new(width * 0.4, 0.2, 1.6),
			0,
			height - 0.15,
			room,
			Color3.fromRGB(255, 245, 220),
			Enum.Material.Neon
		)
	)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = lamp
	local extras = EXTRAS[look.kind]
	if extras then
		extras(model, cf, width)
	end
	storefront(model, cf, width, height, z0, {
		wall = look.wall,
		accent = look.accent,
		trim = look.trim,
		text = look.text,
		fg = look.fg,
		font = look.font,
		awningTop = 11.2,
		awningDrop = 1.8,
		planters = { -width / 4, width / 8 },
	})
	return model
end
local function shelves(model, cf, width, kinds)
	for index, side in { -1, 1 } do
		local x = side * (width / 2 - 2)
		piece(
			model,
			cf,
			`ShelfBack{index}`,
			Vector3.new(0.3, 6, 18),
			x + side * 0.9,
			3.4,
			2,
			Color3.fromRGB(170, 120, 75),
			Enum.Material.Wood
		)
		for level, y in { 0.9, 2.9, 4.9 } do
			Kit.quiet(
				piece(
					model,
					cf,
					`Shelf{index}_{level}`,
					Vector3.new(2, 0.3, 17.6),
					x,
					y,
					2,
					Color3.fromRGB(170, 120, 75),
					Enum.Material.Wood
				)
			)
			for slot = 0, 4 do
				local at = cf * CFrame.new(x, y + 0.15, -5 + slot * 3.6)
				local kind = kinds[rng:NextInteger(1, #kinds)]
				stock(model, at, kind, PRODUCT_COLORS[rng:NextInteger(1, #PRODUCT_COLORS)])
			end
		end
	end
end

-- A cash register on a counter top at (x, z): a till with a drawer, keys and a screen.
local function till(model, cf, x, z)
	local dark = Color3.fromRGB(50, 50, 60)
	bit(model, cf, "Till", Vector3.new(1.8, 0.6, 1.4), CFrame.new(x, 3.7, z), dark, Enum.Material.Metal)
	bit(
		model,
		cf,
		"TillDrawer",
		Vector3.new(1.6, 0.3, 0.1),
		CFrame.new(x, 3.6, z - 0.72),
		Color3.fromRGB(80, 80, 92),
		Enum.Material.Metal
	)
	bit(model, cf, "TillKeys", Vector3.new(1, 0.1, 0.6), CFrame.new(x, 4.05, z - 0.2), Color3.fromRGB(200, 200, 205))
	bit(
		model,
		cf,
		"TillScreen",
		Vector3.new(1.1, 0.7, 0.12),
		CFrame.new(x, 4.45, z + 0.45) * CFrame.Angles(math.rad(-15), 0, 0),
		Color3.fromRGB(60, 200, 120),
		Enum.Material.Neon
	)
end

-- A counter; `shop` makes it a ShopCounter for that shop (Clothes, Hardware, Garage, Guns...),
-- served by `staff` (their StaffSpot is placed separately).
local function counter(model, cf, width, z, color, tag, shop, staff)
	local desk = piece(
		model,
		cf,
		"Counter",
		Vector3.new(width, 3, 3),
		0,
		1.9,
		z,
		color or Color3.fromRGB(90, 150, 120),
		Enum.Material.Wood
	)
	if tag then
		Kit.tag(desk, tag)
	end
	if shop then
		Kit.tag(desk, "ShopCounter")
		desk:SetAttribute("Shop", shop)
		desk:SetAttribute("Staff", staff)
	end
	return desk
end

-- A shop's counter at depth z with its shopkeeper standing behind it and a till on top.
local function shopCounter(model, cf, width, z, color, shop, staff)
	local desk = counter(model, cf, width, z, color, nil, shop, staff)
	staffSpot(model, cf, staff, z + 3)
	till(model, cf, -width / 2 + 2, z)
	return desk
end

-- Shops ---------------------------------------------------------------------------------

-- A drinks fridge at (x, z), its glass door facing into the shop: a cabinet you can see into,
-- shelves of bottles and a light along the top.
local function fridge(model, cf, x, z)
	local white = Kit.Colors.White
	Kit.quiet(piece(model, cf, "FridgeBack", Vector3.new(6, 7, 0.3), x, 3.9, z - 1.1, white, Enum.Material.Metal))
	for _, side in { -1, 1 } do
		Kit.quiet(
			piece(
				model,
				cf,
				"FridgeSide",
				Vector3.new(0.3, 7, 2.5),
				x + side * 2.85,
				3.9,
				z,
				white,
				Enum.Material.Metal
			)
		)
	end
	Kit.quiet(piece(model, cf, "FridgeTop", Vector3.new(5.4, 0.5, 2.5), x, 7.15, z, white, Enum.Material.Metal))
	Kit.quiet(piece(model, cf, "FridgeBase", Vector3.new(5.4, 0.8, 2.5), x, 0.8, z, white, Enum.Material.Metal))
	bit(
		model,
		cf,
		"FridgeLight",
		Vector3.new(5, 0.1, 0.3),
		CFrame.new(x, 6.85, z - 0.6),
		Color3.fromRGB(230, 245, 255),
		Enum.Material.Neon
	)
	for row, y in { 1.2, 3.2, 5.2 } do
		if row > 1 then
			bit(
				model,
				cf,
				"FridgeShelf",
				Vector3.new(5.4, 0.1, 2.2),
				CFrame.new(x, y - 0.05, z),
				Color3.fromRGB(200, 220, 230),
				Enum.Material.Glass
			)
		end
		for column = -2, 2 do
			local color = PRODUCT_COLORS[(row + column) % #PRODUCT_COLORS + 1]
			local at = CFrame.new(x + column * 1.05, y, z - 0.2)
			bit(
				model,
				cf,
				"Drink",
				Vector3.new(1.1, 0.55, 0.55),
				at * CFrame.new(0, 0.55, 0) * UP,
				color,
				Enum.Material.Glass,
				Enum.PartType.Cylinder
			)
			bit(
				model,
				cf,
				"DrinkCap",
				Vector3.new(0.3, 0.3, 0.3),
				at * CFrame.new(0, 1.25, 0) * UP,
				Kit.Colors.White,
				nil,
				Enum.PartType.Cylinder
			)
		end
	end
	local door = Kit.quiet(
		piece(
			model,
			cf,
			"FridgeGlass",
			Vector3.new(5.3, 5.7, 0.2),
			x,
			4.05,
			z + 1.3,
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
	)
	door.Transparency = 0.6
	bit(
		model,
		cf,
		"FridgeHandle",
		Vector3.new(0.2, 2, 0.2),
		CFrame.new(x + 2.3, 3.9, z + 1.5),
		Color3.fromRGB(170, 175, 185),
		Enum.Material.Metal
	)
end

local function convenience(parent, name, slot, look, staff)
	local model, cf = walkIn(parent, name, slot, look)
	shopCounter(model, cf, 12, 12, nil, "Convenience", staff)
	-- Sweets on the counter by the till.
	bit(model, cf, "SweetRack", Vector3.new(2.2, 0.8, 1), CFrame.new(3, 3.8, 11.8), Color3.fromRGB(200, 60, 60))
	for index = 1, 4 do
		bit(
			model,
			cf,
			"Sweets",
			Vector3.new(0.4, 0.3, 0.8),
			CFrame.new(1.95 + index * 0.42, 4.35, 11.8),
			PRODUCT_COLORS[index]
		)
	end
	shelves(model, cf, slot.width, GROCERY)
	-- A drinks fridge by the door, facing into the shop.
	fridge(model, cf, -12, -15)
	local zone = piece(model, cf, "StoreZone", Vector3.new(slot.width - 4, 10, DEPTH - 4), 0, 5.4, 0)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	Kit.tag(zone, "StoreZone")
end
local function hardware(parent, slot)
	local model, cf = walkIn(parent, "Hardware", slot, {
		wall = Color3.fromRGB(240, 160, 60),
		accent = Color3.fromRGB(200, 90, 30),
		trim = Color3.fromRGB(70, 60, 55),
		fg = Kit.Colors.White,
		font = Enum.Font.Sarpanch,
		sign = "HANDY HANK'S HARDWARE",
		posters = { "TOOLS", "KEYS CUT" },
	})
	shopCounter(model, cf, 14, 12, Color3.fromRGB(160, 110, 70), "Hardware", "Hank")
	shelves(model, cf, slot.width, HARDWARE)
	-- A pegboard of tools on the back wall.
	local back = DEPTH / 2 - 1.15
	bit(
		model,
		cf,
		"Pegboard",
		Vector3.new(16, 5, 0.2),
		CFrame.new(0, 7, back),
		Color3.fromRGB(190, 150, 100),
		Enum.Material.Wood
	)
	local steel = Color3.fromRGB(175, 180, 188)
	for index = 0, 5 do
		local x = -6.5 + index * 2.6
		if index % 2 == 0 then -- a hammer
			bit(
				model,
				cf,
				"HammerHandle",
				Vector3.new(0.25, 1.6, 0.2),
				CFrame.new(x, 6.6, back - 0.2),
				Kit.Colors.Wood,
				Enum.Material.Wood
			)
			bit(
				model,
				cf,
				"HammerHead",
				Vector3.new(0.9, 0.35, 0.3),
				CFrame.new(x, 7.5, back - 0.2),
				Color3.fromRGB(60, 60, 66),
				Enum.Material.Metal
			)
		else -- a saw
			bit(
				model,
				cf,
				"SawBlade",
				Vector3.new(0.9, 2, 0.06),
				CFrame.new(x, 6.7, back - 0.15),
				steel,
				Enum.Material.Metal
			)
			bit(
				model,
				cf,
				"SawHandle",
				Vector3.new(0.8, 0.6, 0.2),
				CFrame.new(x, 8, back - 0.2),
				Color3.fromRGB(220, 60, 50)
			)
		end
	end
end

local function clothes(parent, slot)
	local model, cf = walkIn(parent, "Clothes", slot, {
		wall = Color3.fromRGB(240, 170, 210),
		accent = Color3.fromRGB(35, 28, 40),
		trim = Color3.fromRGB(255, 170, 215),
		fg = Color3.fromRGB(255, 170, 215),
		font = Enum.Font.Bodoni,
		awning = { Color3.fromRGB(35, 28, 40), Color3.fromRGB(255, 170, 215) },
		sign = "BAGS",
		posters = { "NEW IN", "BIG BAGS" },
	})
	shopCounter(model, cf, 12, 12, Color3.fromRGB(200, 170, 220), "Clothes", "Bea")
	-- Shelving built against each side wall, floor to shoulder height, with bags sitting on the
	-- shelves: out of the walkway and nothing floating.
	local wood = Color3.fromRGB(235, 225, 230)
	for index, side in { -1, 1 } do
		local wallX = side * (slot.width / 2 - 1.2)
		local shelfX = side * (slot.width / 2 - 2.47)
		Kit.quiet(piece(model, cf, `ShelvingBack{index}`, Vector3.new(0.3, 7.6, 18), wallX, 4.22, -1, wood))
		for _, z in { -9.85, 7.85 } do
			Kit.quiet(piece(model, cf, `ShelvingEnd{index}`, Vector3.new(2.2, 7.6, 0.3), shelfX, 4.22, z, wood))
		end
		for level, y in { 0.6, 2.9, 5.2 } do
			Kit.quiet(piece(model, cf, `BagShelf{index}_{level}`, Vector3.new(2.2, 0.25, 17.3), shelfX, y, -1, wood))
			for slotIndex = 0, 3 do
				local color = PRODUCT_COLORS[rng:NextInteger(1, #PRODUCT_COLORS)]
				local z = -7.5 + slotIndex * 4.3
				Kit.decor(
					piece(
						model,
						cf,
						"Bag",
						Vector3.new(1.4, 1.3, 2.6),
						shelfX,
						y + 0.78,
						z,
						color,
						Enum.Material.Fabric
					)
				)
				Kit.decor(
					piece(
						model,
						cf,
						"BagStrap",
						Vector3.new(0.2, 0.7, 1.6),
						shelfX,
						y + 1.75,
						z,
						color:Lerp(Color3.new(0, 0, 0), 0.3),
						Enum.Material.Fabric
					)
				)
			end
		end
		Kit.decor(piece(model, cf, `ShelvingTop{index}`, Vector3.new(2.5, 0.3, 18.2), shelfX, 8.12, -1, wood))
	end
end

-- A stun blaster (like the ones Tony sells) at `at` in a shop's local space: body, glowing
-- barrel and fin, and a grip.
local function blaster(model, cf, at, glow)
	local body = Color3.fromRGB(60, 60, 75)
	bit(model, cf, "BlasterBody", Vector3.new(0.7, 0.8, 2.2), at, body)
	bit(
		model,
		cf,
		"BlasterBarrel",
		Vector3.new(0.45, 0.45, 1),
		at * CFrame.new(0, 0.1, -1.55),
		glow,
		Enum.Material.Neon
	)
	bit(model, cf, "BlasterFin", Vector3.new(0.15, 0.5, 1.2), at * CFrame.new(0, 0.62, 0), glow, Enum.Material.Neon)
	bit(
		model,
		cf,
		"BlasterGrip",
		Vector3.new(0.5, 1, 0.5),
		at * CFrame.new(0, -0.8, 0.55) * CFrame.Angles(math.rad(-15), 0, 0),
		body
	)
end

local function gunStore(parent, slot)
	local model, cf = walkIn(parent, "GunStore", slot, {
		wall = Color3.fromRGB(90, 90, 110),
		accent = Color3.fromRGB(25, 30, 45),
		trim = Color3.fromRGB(60, 200, 240),
		fg = Color3.fromRGB(80, 230, 255),
		font = Enum.Font.Michroma,
		awning = { Color3.fromRGB(25, 30, 45), Color3.fromRGB(60, 200, 240) },
		sign = "TONY'S BLASTERS",
		posters = { "STUN ONLY", "NO REFUNDS" },
	})
	shopCounter(model, cf, 16, 12, Color3.fromRGB(60, 60, 75), "Guns", "Tony")
	-- A rack of blasters on the wall behind Tony.
	local back = DEPTH / 2 - 1.15
	bit(model, cf, "Rack", Vector3.new(14, 4, 0.2), CFrame.new(0, 7.5, back), Color3.fromRGB(45, 45, 55))
	for index, x in { -4.5, 0, 4.5 } do
		local glow = if index == 2 then Color3.fromRGB(255, 120, 220) else Color3.fromRGB(60, 220, 255)
		blaster(model, cf, CFrame.new(x, 7.6, back - 0.6) * CFrame.Angles(0, math.rad(90), 0), glow)
	end
	for index, x in { -13, 13 } do
		local case = Kit.quiet(
			piece(
				model,
				cf,
				`DisplayCase{index}`,
				Vector3.new(6, 3.5, 10),
				x,
				1.95,
				0,
				Kit.Colors.Glass,
				Enum.Material.Glass
			)
		)
		case.Transparency = 0.5
		-- Blasters lying on their sides in the case.
		for _, info in { { -2.5, Color3.fromRGB(60, 220, 255) }, { 2.5, Color3.fromRGB(255, 120, 220) } } do
			blaster(model, cf, CFrame.new(x, 3, info[1]) * CFrame.Angles(0, 0, math.rad(90)), info[2])
		end
	end
end

local function burger(parent, slot)
	local model, cf = walkIn(parent, "Burger", slot, {
		wall = Color3.fromRGB(250, 210, 90),
		accent = Color3.fromRGB(200, 40, 35),
		trim = Color3.fromRGB(120, 60, 40),
		fg = Color3.fromRGB(255, 215, 80),
		font = Enum.Font.Bangers,
		sign = "BURGER BARN",
		posters = { "BURGERS", "SHAKES" },
	})
	counter(model, cf, 18, 12, Color3.fromRGB(220, 60, 50), "BurgerCounter")
	-- The kitchen behind the counter (Paths/BurgerBarn), and where customers wait.
	local steel = Color3.fromRGB(170, 175, 185)
	Kit.tag(
		piece(
			model,
			cf,
			"Grill",
			Vector3.new(5, 3.2, 2.6),
			-8,
			2,
			18.5,
			Color3.fromRGB(60, 60, 66),
			Enum.Material.Metal
		),
		"BurgerGrill"
	)
	Kit.tag(
		piece(model, cf, "Fryer", Vector3.new(3.6, 3.2, 2.6), 0, 2, 18.5, steel, Enum.Material.Metal),
		"BurgerFryer"
	)
	Kit.decor(
		piece(
			model,
			cf,
			"FryerOil",
			Vector3.new(3, 0.1, 2),
			0,
			3.65,
			18.5,
			Color3.fromRGB(230, 180, 60),
			Enum.Material.Glass
		)
	)
	Kit.tag(
		piece(model, cf, "ShakeMachine", Vector3.new(2.6, 4.6, 2.4), 8, 2.7, 18.6, Color3.fromRGB(245, 170, 200)),
		"BurgerShake"
	)
	Kit.marker(model, "BurgerCustomer", cf * CFrame.new(0, 0.9, 8) * CFrame.Angles(0, math.pi, 0), "BurgerCustomer")
	local menu = piece(model, cf, "Menu", Vector3.new(16, 5, 0.4), 0, 9, DEPTH / 2 - 1.2, Color3.fromRGB(30, 30, 35))
	Kit.sign(
		menu,
		Enum.NormalId.Front,
		"BURGERS   FRIES   SHAKES",
		Color3.fromRGB(30, 30, 35),
		Color3.fromRGB(255, 220, 90)
	)
	for index, x in { -12, 12 } do
		Kit.quiet(piece(model, cf, `Table{index}`, Vector3.new(5, 0.4, 5), x, 3, -8, Kit.Colors.White))
		Kit.decor(
			piece(
				model,
				cf,
				"TableLeg",
				Vector3.new(0.6, 3, 0.6),
				x,
				1.5,
				-8,
				Color3.fromRGB(120, 120, 130),
				Enum.Material.Metal
			)
		)
	end
end

local function garage(parent, slot)
	local cf = frameOf(slot)
	local width, height = slot.width, 18
	local model = Kit.model(parent, "Garage")
	local wall = Color3.fromRGB(120, 125, 140)
	local accent = Color3.fromRGB(240, 190, 40)
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(width - 0.4, 0.4, DEPTH - 0.4), -- just inside the walls
		0,
		0.2,
		0,
		Color3.fromRGB(110, 110, 115),
		Enum.Material.Concrete
	)
	for _, side in { -1, 1 } do
		piece(model, cf, "SideWall", Vector3.new(1, height, DEPTH), side * (width / 2 - 0.5), height / 2, 0, wall)
		-- Wide doors front and back, so cars drive straight through to the lot.
		piece(
			model,
			cf,
			"FrontPost",
			Vector3.new(width / 2 - 10, height, 1),
			side * (10 + (width / 2 - 10) / 2),
			height / 2,
			-DEPTH / 2 + 0.5,
			wall
		)
		piece(
			model,
			cf,
			"BackPost",
			Vector3.new(width / 2 - 10, height, 1),
			side * (10 + (width / 2 - 10) / 2),
			height / 2,
			DEPTH / 2 - 0.5,
			wall
		)
	end
	piece(model, cf, "FrontHeader", Vector3.new(20, height - 14, 1), 0, 14 + (height - 14) / 2, -DEPTH / 2 + 0.5, wall)
	piece(model, cf, "BackHeader", Vector3.new(20, height - 14, 1), 0, 14 + (height - 14) / 2, DEPTH / 2 - 0.5, wall)
	piece(model, cf, "Roof", Vector3.new(width + 1, 1, DEPTH + 1), 0, height + 0.5, 0, Kit.Colors.White)
	local sign = piece(model, cf, "Sign", Vector3.new(32, 3.4, 0.5), 0, height - 2, -DEPTH / 2 - 0.3, accent)
	Kit.sign(sign, Enum.NormalId.Front, "SPEEDY'S GARAGE", accent, Color3.fromRGB(30, 30, 35), Enum.Font.ArimoBold)
	local deskX = -width / 2 + 6
	counter(model, cf, 8, 10, Color3.fromRGB(80, 80, 90), nil, "Garage", "Speedy").CFrame = cf
		* CFrame.new(deskX, 1.9, 10)
	staffSpot(model, cf, "Speedy", 13, deskX)
	till(model, cf, deskX - 2, 10)
	-- A stack of tyres, a red toolbox and oil drums by the walls.
	for level = 0, 3 do
		bit(
			model,
			cf,
			"Tyre",
			Vector3.new(0.9, 2.8, 2.8),
			CFrame.new(width / 2 - 4, 0.85 + level * 0.9, -12) * UP,
			Color3.fromRGB(30, 30, 32),
			nil,
			Enum.PartType.Cylinder
		)
	end
	local toolbox = Color3.fromRGB(200, 45, 40)
	bit(model, cf, "Toolbox", Vector3.new(4, 4, 2), CFrame.new(width / 2 - 4, 2.4, 6), toolbox, Enum.Material.Metal)
	for drawer = 0, 3 do
		bit(
			model,
			cf,
			"Drawer",
			Vector3.new(3.4, 0.08, 0.1),
			CFrame.new(width / 2 - 4, 1.2 + drawer * 0.9, 4.98),
			Color3.fromRGB(200, 200, 205),
			Enum.Material.Metal
		)
	end
	for index, z in { 13, 16 } do
		bit(
			model,
			cf,
			`OilDrum{index}`,
			Vector3.new(3.2, 2.2, 2.2),
			CFrame.new(width / 2 - 3, 2, z) * UP,
			if index == 1 then Color3.fromRGB(40, 90, 170) else Color3.fromRGB(230, 170, 40),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	ceilingLight(model, cf, 16, height)
end

local function depot(parent, slot)
	local model, cf = walkIn(parent, "Depot", slot, {
		wall = Color3.fromRGB(210, 130, 60),
		accent = Color3.fromRGB(120, 70, 30),
		fg = Kit.Colors.White,
		font = Enum.Font.Ubuntu,
		sign = "ZOOM DELIVERIES",
		posters = { "FAST", "FRAGILE" },
		height = 15,
	})
	counter(model, cf, 16, 12, Color3.fromRGB(176, 128, 72), "DeliveryDepot")
	staffSpot(model, cf, "Dee", 15)
	for index = 1, 6 do
		Kit.quiet(
			piece(
				model,
				cf,
				`Crate{index}`,
				Vector3.new(4, 4, 4),
				-slot.width / 2 + 6 + (index % 3) * 5,
				2.4 + (index > 3 and 4 or 0),
				14,
				Color3.fromRGB(190, 145, 90),
				Enum.Material.Cardboard
			)
		)
	end
end

-- A wall across the building at depth z, from x1 to x2, with rectangular openings
-- ({ x1, x2, y1, y2 }, left to right).
local function wallWithOpenings(model, cf, name, z, x1, x2, height, openings, color)
	local x = x1
	for _, o in openings do
		if o[1] > x then
			piece(model, cf, name, Vector3.new(o[1] - x, height, 1), (x + o[1]) / 2, height / 2, z, color)
		end
		piece(model, cf, name, Vector3.new(o[2] - o[1], o[3], 1), (o[1] + o[2]) / 2, o[3] / 2, z, color)
		piece(
			model,
			cf,
			name,
			Vector3.new(o[2] - o[1], height - o[4], 1),
			(o[1] + o[2]) / 2,
			(o[4] + height) / 2,
			z,
			color
		)
		x = o[2]
	end
	if x2 > x then
		piece(model, cf, name, Vector3.new(x2 - x, height, 1), (x + x2) / 2, height / 2, z, color)
	end
end

-- Steel bars from `from` to `to` (points in the building's frame; y is ignored), y1 to y2 high:
-- see-through decor plus an invisible wall nobody can walk, jump or blast through.
local function bars(model, cf, from, to, y1, y2, color)
	local a, b = Vector3.new(from.X, 0, from.Z), Vector3.new(to.X, 0, to.Z)
	local length = (b - a).Magnitude
	local along = cf * CFrame.lookAt((a + b) / 2, b)
	local blocker =
		Kit.part(model, "BarsBlocker", Vector3.new(0.6, y2 - y1, length), along * CFrame.new(0, (y1 + y2) / 2, 0))
	blocker.Transparency = 1
	blocker.CanTouch = false
	local count = math.floor(length / 1.2)
	for index = 1, count do
		local z = -length / 2 + (index - 0.5) * length / count
		local position = (along * CFrame.new(0, (y1 + y2) / 2, z)).Position
		Kit.decor(Kit.cylinder(model, "Bar", y2 - y1, 0.35, position, color, Enum.Material.Metal))
	end
	for _, y in { y1 + 0.3, y2 - 0.3 } do
		Kit.decor(
			Kit.part(
				model,
				"Rail",
				Vector3.new(0.5, 0.4, length),
				along * CFrame.new(0, y, 0),
				color,
				Enum.Material.Metal
			)
		)
	end
end

local CELL_WIDTH, CELL_DEPTH = 18, 16
local BARS_TOP = 11

-- The police station: a front office and, in the front corner, the jail cell. Its barred window
-- looks out onto the main road, so you can watch the town while you wait (and everyone can see
-- you). Tags: JailCell (the cell), JailExit (the front step).
local function police(parent, slot)
	local cf = frameOf(slot)
	local width, height, depth = slot.width - 4, 16, DEPTH - 4
	local model = Kit.model(parent, "PoliceStation")
	local wall = Color3.fromRGB(70, 100, 180)
	local steel = Color3.fromRGB(90, 90, 100)
	local front, inner = -depth / 2 + 0.5, width / 2 - 1
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(width - 0.4, 0.4, depth - 0.4),
		0,
		0.2,
		0,
		Color3.fromRGB(205, 205, 210),
		Enum.Material.Marble
	)
	piece(model, cf, "BackWall", Vector3.new(width - 2, height, 1), 0, height / 2, depth / 2 - 0.5, wall)
	for _, side in { -1, 1 } do
		piece(model, cf, "SideWall", Vector3.new(1, height, depth), side * (width / 2 - 0.5), height / 2, 0, wall)
	end
	piece(model, cf, "Roof", Vector3.new(width + 1, 1, depth + 1), 0, height + 0.5, 0, Kit.Colors.White)

	-- The front wall: an office window, and the cell's barred window.
	local x1, x2 = inner - CELL_WIDTH, inner
	local z1, z2 = -depth / 2 + 1, -depth / 2 + 1 + CELL_DEPTH
	local office = { -width / 4 - 10, -width / 4 + 10, 4, 10 }
	local window = { x1 + 3, x2 - 3, 3.5, 10.5 }
	wallWithOpenings(model, cf, "FrontWall", front, -inner, inner, height, { office, window }, wall)
	local glass = piece(
		model,
		cf,
		"OfficeWindow",
		Vector3.new(office[2] - office[1], office[4] - office[3], 0.3),
		(office[1] + office[2]) / 2,
		(office[3] + office[4]) / 2,
		front,
		Kit.Colors.Glass,
		Enum.Material.Glass
	)
	glass.Transparency = 0.4
	bars(model, cf, Vector3.new(window[1], 0, front), Vector3.new(window[2], 0, front), window[3], window[4], steel)
	Kit.decor(piece(model, cf, "Door", Vector3.new(6, 9, 0.3), 0, 4.5, -DEPTH / 2 + 1.8, Color3.fromRGB(30, 40, 70)))

	-- The cell's two inside walls: bars, with wall above them up to the roof.
	bars(model, cf, Vector3.new(x1 - 0.3, 0, z1), Vector3.new(x1 - 0.3, 0, z2), 0.4, BARS_TOP, steel)
	bars(model, cf, Vector3.new(x1 - 0.6, 0, z2 + 0.3), Vector3.new(x2, 0, z2 + 0.3), 0.4, BARS_TOP, steel)
	local over = height - BARS_TOP
	piece(model, cf, "CellHeader", Vector3.new(0.6, over, z2 - z1), x1 - 0.3, BARS_TOP + over / 2, (z1 + z2) / 2, wall)
	piece(
		model,
		cf,
		"CellHeader",
		Vector3.new(x2 - x1 + 0.6, over, 0.6),
		(x1 - 0.6 + x2) / 2,
		BARS_TOP + over / 2,
		z2 + 0.3,
		wall
	)
	Kit.quiet(
		piece(model, cf, "Bunk", Vector3.new(3.2, 2.2, 8), x2 - 1.6, 1.5, (z1 + z2) / 2 + 2, steel, Enum.Material.Metal)
	)
	Kit.decor(
		piece(
			model,
			cf,
			"Blanket",
			Vector3.new(3, 0.2, 5),
			x2 - 1.6,
			2.7,
			(z1 + z2) / 2 + 3,
			Color3.fromRGB(150, 120, 90)
		)
	)
	Kit.marker(model, "JailCell", cf * CFrame.new((x1 + x2) / 2, 1, (z1 + z2) / 2), "JailCell")
	Kit.marker(model, "JailExit", cf * CFrame.new(0, 1, -DEPTH / 2 - 4), "JailExit")

	-- The office: a desk and a noticeboard.
	local desk = -width / 4
	Kit.quiet(piece(model, cf, "Desk", Vector3.new(12, 3.5, 3), desk, 2.15, -8, Kit.Colors.Wood, Enum.Material.Wood))
	Kit.decor(piece(model, cf, "Monitor", Vector3.new(2.6, 1.8, 0.3), desk + 3, 4.8, -7.5, Color3.fromRGB(30, 30, 35)))
	staffSpot(model, cf, "Sergeant", -5.6, desk - 1)
	local board = piece(model, cf, "Noticeboard", Vector3.new(12, 5, 0.3), desk, 7, depth / 2 - 1.15, Kit.Colors.White)
	Kit.decor(board)
	Kit.sign(
		board,
		Enum.NormalId.Front,
		"MOST WANTED",
		Color3.fromRGB(240, 230, 200),
		Color3.fromRGB(40, 40, 60),
		Enum.Font.SpecialElite
	)
	for _, at in { { desk, 0 }, { (x1 + x2) / 2, (z1 + z2) / 2 } } do
		local lamp = Kit.decor(
			piece(
				model,
				cf,
				"Light",
				Vector3.new(4, 0.3, 1.2),
				at[1],
				height - 0.15,
				at[2],
				Color3.fromRGB(255, 250, 230),
				Enum.Material.Neon
			)
		)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1
		light.Parent = lamp
	end
	local sign = piece(
		model,
		cf,
		"Sign",
		Vector3.new(30, 3.4, 0.5),
		0,
		height - 2,
		-DEPTH / 2 + 1.6,
		Color3.fromRGB(30, 50, 120)
	)
	Kit.sign(sign, Enum.NormalId.Front, "POLICE", Color3.fromRGB(30, 50, 120), Kit.Colors.White, Enum.Font.GothamBlack)
	Kit.decor(
		piece(
			model,
			cf,
			"LightBar",
			Vector3.new(6, 0.8, 0.8),
			0,
			height + 1.4,
			-DEPTH / 2 + 3,
			Color3.fromRGB(230, 40, 40),
			Enum.Material.Neon
		)
	)
end

local function carWash(parent, slot)
	local cf = frameOf(slot)
	local model = Kit.model(parent, "CarWash")
	local accent = Color3.fromRGB(60, 160, 230)
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(slot.width, 0.4, DEPTH),
		0,
		0.2,
		0,
		Color3.fromRGB(150, 150, 155),
		Enum.Material.Concrete
	)
	for _, x in { -slot.width / 2 + 1, slot.width / 2 - 1 } do
		for _, z in { -DEPTH / 2 + 1, DEPTH / 2 - 1 } do
			Kit.quiet(piece(model, cf, "Pillar", Vector3.new(1.5, 13, 1.5), x, 6.5, z, Kit.Colors.White))
		end
	end
	piece(model, cf, "Canopy", Vector3.new(slot.width + 1, 1, DEPTH + 1), 0, 13.5, 0, accent)
	for index, x in { -6, 6 } do
		Kit.decor(
			Kit.cylinder(
				model,
				`Brush{index}`,
				9,
				3,
				(cf * CFrame.new(x, 5, 0)).Position,
				Color3.fromRGB(80, 200, 255),
				Enum.Material.Fabric
			)
		)
	end
	local sign = piece(model, cf, "Sign", Vector3.new(30, 3.4, 0.5), 0, 11.5, -DEPTH / 2 - 0.4, accent)
	Kit.sign(sign, Enum.NormalId.Front, "SUDZ CAR WASH", accent, Kit.Colors.White, Enum.Font.FredokaOne)
	-- Paths/CarWash: the cashier, the bay a car stops in between the brushes (driving in from the
	-- road and out the back) and the rinse lever.
	Kit.tag(
		piece(model, cf, "Cashier", Vector3.new(4, 3, 2.4), -17, 1.9, -16, accent, Enum.Material.Wood),
		"CarWashDesk"
	)
	staffSpot(model, cf, "Suds", -13.6, -17)
	Kit.marker(model, "CarWashBay", cf * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.pi, 0), "CarWashBay")
	Kit.tag(
		piece(
			model,
			cf,
			"RinseLever",
			Vector3.new(0.6, 4, 0.6),
			12,
			2.4,
			6,
			Color3.fromRGB(90, 90, 100),
			Enum.Material.Metal
		),
		"CarWashLever"
	)
	Kit.decor(piece(model, cf, "LeverHandle", Vector3.new(0.5, 0.5, 2), 12, 4.2, 5.2, Color3.fromRGB(220, 50, 50)))
end

local function taxi(parent, slot)
	local model, cf = walkIn(parent, "Taxi", slot, {
		wall = Color3.fromRGB(255, 210, 50),
		accent = Color3.fromRGB(40, 40, 45),
		fg = Color3.fromRGB(255, 210, 40),
		font = Enum.Font.RobotoCondensed,
		awning = { Color3.fromRGB(40, 40, 45), Color3.fromRGB(255, 210, 40) },
		sign = "CITY CABS",
		height = 12,
	})
	counter(model, cf, 10, 12, Color3.fromRGB(40, 40, 45), "TaxiDesk")
	staffSpot(model, cf, "Carl", 15)
	-- Paths/Taxi: where your cab waits, on the road out front, facing east with the traffic.
	local spot = Vector3.new(slot.center.X, 0.7, slot.center.Z + slot.facing.Z * 35)
	Kit.marker(model, "TaxiSpawn", CFrame.lookAt(spot, spot + Vector3.xAxis), "TaxiSpawn")
	return model
end

local function market(parent, slot)
	local cf = frameOf(slot)
	local model = Kit.model(parent, "Market")
	piece(model, cf, "Floor", Vector3.new(slot.width, 0.4, DEPTH), 0, 0.2, 0, Kit.Colors.Plaza, Enum.Material.Pavement)
	local stripes = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 150, 230), Color3.fromRGB(250, 190, 50) }
	for index, x in { -14, 0, 14 } do
		local stall = Kit.quiet(
			piece(model, cf, `Stall{index}`, Vector3.new(10, 3.5, 4), x, 2, -6, Kit.Colors.Wood, Enum.Material.Wood)
		)
		if index == 2 then
			Kit.tag(stall, "FoodCartCounter") -- rent the hot-dog cart here (Paths/FoodStand)
			staffSpot(model, cf, "Hal", -2.6)
		end
		for _, px in { -4.5, 4.5 } do
			Kit.decor(piece(model, cf, "Pole", Vector3.new(0.5, 9, 0.5), x + px, 4.5, -3, Kit.Colors.White))
		end
		Kit.decor(
			piece(model, cf, `Canopy{index}`, Vector3.new(11, 0.4, 7), x, 9, -5, stripes[index], Enum.Material.Fabric)
		)
	end
	local arch = piece(model, cf, "Arch", Vector3.new(36, 3.4, 0.5), 0, 12, -DEPTH / 2 + 1, Color3.fromRGB(230, 70, 70))
	Kit.sign(arch, Enum.NormalId.Front, "STREET MARKET", Color3.fromRGB(230, 70, 70), Kit.Colors.White, Enum.Font.Kalam)
	for _, x in { -18.5, 18.5 } do
		Kit.quiet(piece(model, cf, "ArchPost", Vector3.new(1, 13.7, 1), x, 6.85, -DEPTH / 2 + 1, Kit.Colors.White))
	end
end

-- A narrow alley beside a storage block, with the drop spot behind a dumpster.
local function alley(parent, slot)
	local cf = frameOf(slot)
	local model = Kit.model(parent, "Alley")
	Kit.quiet(
		piece(model, cf, "Storage", Vector3.new(30, 16, DEPTH - 2), -7, 8, 0, Kit.Colors.Brick, Enum.Material.Brick)
	)
	local sign = piece(model, cf, "Sign", Vector3.new(18, 3, 0.4), -7, 13, -DEPTH / 2 + 0.7, Color3.fromRGB(90, 60, 50))
	Kit.sign(sign, Enum.NormalId.Front, "STORAGE", Color3.fromRGB(90, 60, 50), Kit.Colors.White, Enum.Font.SpecialElite)
	piece(model, cf, "AlleyWall", Vector3.new(1, 12, DEPTH - 2), 21.5, 6, 0, Kit.Colors.Brick, Enum.Material.Brick)
	Kit.quiet(
		piece(model, cf, "Dumpster", Vector3.new(6, 4, 3), 15, 2.2, 12, Color3.fromRGB(40, 90, 50), Enum.Material.Metal)
	)
	local drop = piece(model, cf, "AlleyDrop", Vector3.new(6, 0.3, 6), 15, 0.35, 6, Color3.fromRGB(35, 35, 40))
	drop.CanCollide = false
	Kit.tag(drop, "AlleyDrop")
end

-- The bank --------------------------------------------------------------------------------

local function bank(parent)
	local model = Kit.model(parent, "Bank")
	local cf = CFrame.new() -- world space; the bank has a grand front north and south
	local W, D, H = 60, 44, 20
	local stone = Color3.fromRGB(236, 232, 220)
	local gold = Color3.fromRGB(240, 196, 60)
	-- The floor stops just inside the walls' outer faces (matching faces flicker).
	piece(
		model,
		cf,
		"Floor",
		Vector3.new(W - 0.4, 0.5, D - 0.4),
		0,
		0.25,
		0,
		Color3.fromRGB(245, 240, 230),
		Enum.Material.Marble
	)
	-- The north wall is solid all the way across: the vault hangs on it, behind Mr. Penny.
	piece(model, cf, "Wall", Vector3.new(W, H, 1.5), 0, H / 2, -(D / 2 - 0.75), stone, Enum.Material.Limestone)
	-- The other three have a door gap in the middle. East and west fit between north and south.
	for _, face in { { axis = "z", sign = 1 }, { axis = "x", sign = -1 }, { axis = "x", sign = 1 } } do
		local length = if face.axis == "z" then W else D - 3
		local segment = length / 2 - 6
		for _, part in { -1, 1 } do
			local offset = part * (6 + segment / 2)
			if face.axis == "z" then
				piece(
					model,
					cf,
					"Wall",
					Vector3.new(segment, H, 1.5),
					offset,
					H / 2,
					face.sign * (D / 2 - 0.75),
					stone,
					Enum.Material.Limestone
				)
			else
				piece(
					model,
					cf,
					"Wall",
					Vector3.new(1.5, H, segment),
					face.sign * (W / 2 - 0.75),
					H / 2,
					offset,
					stone,
					Enum.Material.Limestone
				)
			end
		end
		if face.axis == "z" then
			piece(
				model,
				cf,
				"Lintel",
				Vector3.new(12, H - 12, 1.5),
				0,
				12 + (H - 12) / 2,
				face.sign * (D / 2 - 0.75),
				stone,
				Enum.Material.Limestone
			)
		else
			piece(
				model,
				cf,
				"Lintel",
				Vector3.new(1.5, H - 12, 12),
				face.sign * (W / 2 - 0.75),
				12 + (H - 12) / 2,
				0,
				stone,
				Enum.Material.Limestone
			)
		end
	end
	piece(model, cf, "Roof", Vector3.new(W + 2, 1.5, D + 2), 0, H + 0.75, 0, stone, Enum.Material.Limestone)
	piece(model, cf, "RoofTrim", Vector3.new(W + 3, 1, D + 3), 0, H + 2, 0, gold)
	-- Grand fronts north and south: columns, a portico and the name.
	for _, sideZ in { -1, 1 } do
		for _, x in { -18, -10, 10, 18 } do
			Kit.quiet(
				Kit.cylinder(
					model,
					"Column",
					14,
					2.4,
					(cf * CFrame.new(x, 7.25, sideZ * (D / 2 + 3))).Position,
					stone,
					Enum.Material.Limestone
				)
			)
		end
		piece(
			model,
			cf,
			"Portico",
			Vector3.new(44, 1.2, 7),
			0,
			14.8,
			sideZ * (D / 2 + 3),
			stone,
			Enum.Material.Limestone
		)
		local sign =
			piece(model, cf, "Sign", Vector3.new(30, 4, 0.6), 0, 17, sideZ * (D / 2 + 0.2), Color3.fromRGB(40, 110, 70))
		Kit.sign(
			sign,
			if sideZ > 0 then Enum.NormalId.Back else Enum.NormalId.Front,
			"PENNY NATIONAL BANK",
			Color3.fromRGB(40, 110, 70),
			gold,
			Enum.Font.Garamond
		)
	end
	-- The counter where you pay, with Mr. Penny behind it.
	local desk =
		piece(model, cf, "Counter", Vector3.new(28, 3, 3), 0, 2, -4, Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	Kit.tag(desk, "BankCounter")
	-- No blasting in the bank.
	local safe = Kit.part(model, "SafeZone", Vector3.new(W, H, D), Vector3.new(0, H / 2, 0))
	safe.Transparency = 1
	safe.CanCollide = false
	safe.CanQuery = false
	safe.CanTouch = false
	Kit.tag(safe, "SafeZone")
	Kit.decor(piece(model, cf, "CounterTop", Vector3.new(28.6, 0.4, 3.6), 0, 3.7, -4, gold, Enum.Material.Marble))
	local penny =
		Kit.marker(model, "PennySpot", CFrame.lookAt(Vector3.new(0, 1.0, -8), Vector3.new(0, 1.0, 0)), "StaffSpot")
	penny:SetAttribute("Staff", "Penny")
	-- Two tellers either side of him.
	for index, x in { -9, 9 } do
		local teller = Kit.marker(
			model,
			`Teller{index}Spot`,
			CFrame.lookAt(Vector3.new(x, 1.0, -8), Vector3.new(x, 1.0, 0)),
			"StaffSpot"
		)
		teller:SetAttribute("Staff", `Teller{index}`)
	end
	-- The vault door, set into the north wall: a dark frame, the door, and a wheel.
	local wallFace = -D / 2 + 1.5
	for _, info in
		{
			{ "VaultFrame", 0.6, 13.4, wallFace + 0.05, Color3.fromRGB(70, 70, 80) },
			{ "VaultDoor", 1, 12, wallFace + 0.3, Color3.fromRGB(150, 150, 160) },
			{ "VaultWheel", 0.6, 3, wallFace + 1, Color3.fromRGB(200, 170, 70) },
		}
	do
		local disc =
			Kit.decor(Kit.cylinder(model, info[1], info[2], info[3], Vector3.zero, info[5], Enum.Material.DiamondPlate))
		disc.CFrame = CFrame.new(0, 8, info[4]) * CFrame.Angles(0, math.rad(90), 0)
	end
	for index, x in { -20, 20 } do
		Kit.decor(Kit.cylinder(model, `Plant{index}`, 3, 3, Vector3.new(x, 2, 14), Color3.fromRGB(200, 120, 80)))
		local leaves = Kit.decor(
			Kit.part(
				model,
				`PlantLeaves{index}`,
				Vector3.one * 4,
				Vector3.new(x, 5, 14),
				Kit.Colors.Leaves,
				Enum.Material.Grass
			)
		)
		leaves.Shape = Enum.PartType.Ball
	end
	for index = 1, 2 do
		local lamp = Kit.decor(
			Kit.part(
				model,
				`Chandelier{index}`,
				Vector3.new(4, 1, 4),
				Vector3.new(index == 1 and -12 or 12, H - 2, 4),
				gold,
				Enum.Material.Neon
			)
		)
		local light = Instance.new("PointLight")
		light.Range = 36
		light.Brightness = 1.2
		light.Parent = lamp
	end
	-- Where everyone appears at the start of the run and between quotas.
	for index, x in { -8, 0, 8 } do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `BankSpawn{index}`
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.Position = Vector3.new(x, 0.6, 12)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.Neutral = true
		spawn.Duration = 0
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		spawn.Parent = model
		Kit.tag(spawn, "BankSpawn")
	end
	-- Trees on the plaza corners.
	for index, corner in
		{ Vector3.new(-40, 0.3, -40), Vector3.new(40, 0.3, -40), Vector3.new(-40, 0.3, 40), Vector3.new(40, 0.3, 40) }
	do
		Kit.tree(model, `PlazaTree{index}`, Kit.bed(model, `PlazaBed{index}`, corner, 6), 10)
	end
end

function Buildings.build(map)
	local folder = Kit.folder(map, "Buildings")
	bank(folder)
	local s = Layout.slots
	convenience(folder, "CornerStore", s.CornerStore, {
		wall = Color3.fromRGB(120, 200, 160),
		accent = Color3.fromRGB(30, 110, 70),
		fg = Color3.fromRGB(250, 240, 210),
		font = Enum.Font.Oswald,
		sign = "CORNER STORE",
		posters = { "FRESH SNACKS", "COLD DRINKS" },
	}, "CornerClerk")
	convenience(folder, "MiniMart", s.MiniMart, {
		wall = Color3.fromRGB(240, 190, 90),
		accent = Color3.fromRGB(210, 50, 45),
		fg = Color3.fromRGB(255, 220, 80),
		font = Enum.Font.LuckiestGuy,
		sign = "MINI MART",
		posters = { "2 FOR 1", "OPEN LATE" },
	}, "MiniClerk")
	hardware(folder, s.Hardware)
	clothes(folder, s.Clothes)
	gunStore(folder, s.GunStore)
	burger(folder, s.Burger)
	garage(folder, s.Garage)
	depot(folder, s.Depot)
	police(folder, s.Police)
	carWash(folder, s.CarWash)
	taxi(folder, s.Taxi)
	market(folder, s.Market)
	alley(folder, s.Alley)
	-- The small businesses: name, sign, wall, sign board, lettering colour, font, room wall.
	local white = Kit.Colors.White
	local fillers = {
		{
			"Barber",
			"FRESH CUTS",
			Color3.fromRGB(230, 230, 240),
			Color3.fromRGB(200, 40, 50),
			white,
			Enum.Font.Fondamento,
			Color3.fromRGB(220, 235, 240),
		},
		{
			"Laundromat",
			"SPIN CYCLE",
			Color3.fromRGB(180, 220, 240),
			Color3.fromRGB(60, 130, 200),
			white,
			Enum.Font.Nunito,
			Color3.fromRGB(235, 245, 250),
		},
		{
			"Cafe",
			"BEAN THERE",
			Color3.fromRGB(200, 160, 120),
			Color3.fromRGB(110, 70, 40),
			Color3.fromRGB(250, 235, 210),
			Enum.Font.PatrickHand,
			Color3.fromRGB(240, 225, 200),
		},
		{
			"Pharmacy",
			"PHARMACY",
			Color3.fromRGB(235, 245, 235),
			Color3.fromRGB(40, 160, 80),
			white,
			Enum.Font.ArimoBold,
			Color3.fromRGB(240, 250, 240),
		},
		{
			"Bakery",
			"SWEET BAKES",
			Color3.fromRGB(250, 220, 180),
			Color3.fromRGB(210, 120, 60),
			white,
			Enum.Font.IndieFlower,
			Color3.fromRGB(255, 235, 215),
		},
		{
			"Florist",
			"PETAL POWER",
			Color3.fromRGB(250, 210, 230),
			Color3.fromRGB(220, 80, 140),
			white,
			Enum.Font.AmaticSC,
			Color3.fromRGB(250, 235, 240),
		},
		{
			"PostOffice",
			"POST OFFICE",
			Color3.fromRGB(230, 90, 80),
			Color3.fromRGB(40, 60, 140),
			Color3.fromRGB(250, 220, 80),
			Enum.Font.Merriweather,
			Color3.fromRGB(240, 230, 210),
		},
		{
			"Diner",
			"ROSIE'S DINER",
			Color3.fromRGB(180, 230, 230),
			Color3.fromRGB(230, 70, 90),
			white,
			Enum.Font.DenkOne,
			Color3.fromRGB(250, 240, 230),
		},
		{
			"Gym",
			"PUMP HOUSE",
			Color3.fromRGB(90, 90, 100),
			Color3.fromRGB(240, 140, 30),
			Color3.fromRGB(30, 30, 35),
			Enum.Font.GothamBlack,
			Color3.fromRGB(200, 200, 205),
		},
		{
			"Books",
			"PAGE TURNER",
			Color3.fromRGB(150, 110, 90),
			Color3.fromRGB(70, 110, 60),
			Color3.fromRGB(245, 235, 210),
			Enum.Font.Antique,
			Color3.fromRGB(230, 215, 190),
		},
		{
			"PetShop",
			"PAWS",
			Color3.fromRGB(250, 240, 200),
			Color3.fromRGB(230, 150, 40),
			white,
			Enum.Font.Cartoon,
			Color3.fromRGB(250, 245, 225),
		},
		{
			"Toys",
			"TOY BOX",
			Color3.fromRGB(180, 200, 250),
			Color3.fromRGB(240, 90, 90),
			Color3.fromRGB(255, 230, 90),
			Enum.Font.LuckiestGuy,
			Color3.fromRGB(230, 240, 255),
		},
		{
			"Music",
			"LOUD NOTES",
			Color3.fromRGB(60, 60, 70),
			Color3.fromRGB(170, 90, 230),
			white,
			Enum.Font.PermanentMarker,
			Color3.fromRGB(70, 70, 85),
		},
	}
	for _, filler in fillers do
		frontRoom(folder, filler[1], s[filler[1]], {
			text = filler[2],
			wall = filler[3],
			accent = filler[4],
			fg = filler[5],
			font = filler[6],
			inside = filler[7],
			staff = filler[1],
			kind = filler[1],
		})
	end
	return folder
end

return Buildings
