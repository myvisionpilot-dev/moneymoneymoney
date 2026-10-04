-- The bank on the plaza and every shop along the main roads.
--
-- Tags placed here: BankCounter + BankSpawn + SafeZone (deposits, spawning, no blasting),
-- StaffSpot (Mr. Penny, Tony), StoreCounter + StoreZone (convenience store tills and the door
-- bell), ShopCounter with a Shop attribute (Clothes, Hardware, Garage, Guns, and each convenience
-- store's snack fridge), DeliveryDepot, AlleyDrop.

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

local function staffSpot(model, cf, who, z)
	-- Standing behind the counter, facing the customers (the shop's frame looks out the front).
	local spot = Kit.marker(model, `{who}Spot`, cf * CFrame.new(0, 0.9, z), "StaffSpot")
	spot:SetAttribute("Staff", who)
	return spot
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

-- A shop you can walk into: walls, a glass front with a door gap, roof, sign and awning.
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
	local sign = piece(
		model,
		cf,
		"Sign",
		Vector3.new(math.min(width * 0.8, 36), 3.4, 0.5),
		0,
		height - 2,
		-DEPTH / 2 - 0.3,
		style.accent
	)
	Kit.sign(sign, Enum.NormalId.Front, style.sign, style.accent)
	Kit.decor(
		piece(
			model,
			cf,
			"Awning",
			Vector3.new(DOOR + 4, 0.5, 4),
			0,
			DOOR_HEIGHT + 0.6,
			-DEPTH / 2 - 2,
			style.accent,
			Enum.Material.Fabric
		)
	)
	ceilingLight(model, cf, width * 0.5, height)
	return model, cf
end

-- Just a shopfront: a solid building with windows, a closed door, sign and awning.
local function shopfront(parent, name, slot, wall, accent, text)
	local cf = frameOf(slot)
	local width, height = slot.width - 4, 13
	local model = Kit.model(parent, name)
	Kit.quiet(piece(model, cf, "Body", Vector3.new(width, height, DEPTH - 4), 0, height / 2, 0, wall))
	local glass = Kit.decor(
		piece(
			model,
			cf,
			"Window",
			Vector3.new(width - 12, 6, 0.3),
			0,
			4.5,
			-DEPTH / 2 + 2 - 0.2,
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
	)
	glass.Transparency = 0.2
	Kit.decor(
		piece(
			model,
			cf,
			"Door",
			Vector3.new(4, 8, 0.3),
			width / 2 - 4,
			4,
			-DEPTH / 2 + 2 - 0.2,
			Kit.Colors.Wood,
			Enum.Material.Wood
		)
	)
	local sign = piece(model, cf, "Sign", Vector3.new(width * 0.8, 3, 0.4), 0, height - 2, -DEPTH / 2 + 2 - 0.3, accent)
	Kit.sign(sign, Enum.NormalId.Front, text, accent)
	Kit.decor(
		piece(model, cf, "Awning", Vector3.new(width - 6, 0.5, 3.5), 0, 8.6, -DEPTH / 2, accent, Enum.Material.Fabric)
	)
	return model
end

local function shelves(model, cf, width)
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
				Kit.decor(
					piece(
						model,
						cf,
						"Product",
						Vector3.new(1.2, 1.3, 1.8),
						x,
						y + 0.8,
						-5 + slot * 3.6,
						PRODUCT_COLORS[rng:NextInteger(1, #PRODUCT_COLORS)]
					)
				)
			end
		end
	end
end

-- A counter; `shop` makes it a ShopCounter for that shop (Clothes, Hardware, Garage, Guns...).
local function counter(model, cf, width, z, color, tag, shop)
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
	end
	return desk
end

-- Shops ---------------------------------------------------------------------------------

local function convenience(parent, name, slot, sign, wall)
	local model, cf = walkIn(parent, name, slot, { wall = wall, accent = Color3.fromRGB(220, 60, 60), sign = sign })
	counter(model, cf, 12, 12, nil, "StoreCounter")
	Kit.decor(
		piece(
			model,
			cf,
			"Register",
			Vector3.new(1.8, 1.2, 1.4),
			-3,
			4,
			12,
			Color3.fromRGB(50, 50, 60),
			Enum.Material.Metal
		)
	)
	shelves(model, cf, slot.width)
	-- The snack fridge by the door: where you buy boosts (the till at the back is for robbing).
	local fridge =
		piece(model, cf, "SnackFridge", Vector3.new(6, 7, 2.5), -12, 3.9, -15, Kit.Colors.White, Enum.Material.Metal)
	Kit.tag(fridge, "ShopCounter")
	fridge:SetAttribute("Shop", "Convenience")
	local door = Kit.decor(
		piece(
			model,
			cf,
			"FridgeGlass",
			Vector3.new(5.4, 6.2, 0.2),
			-12,
			3.9,
			-13.7,
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
	)
	door.Transparency = 0.4
	for row, y in { 2, 4, 6 } do
		for column = -2, 2 do
			Kit.decor(
				piece(
					model,
					cf,
					`Drink{row}`,
					Vector3.new(0.6, 1.2, 0.6),
					-12 + column,
					y,
					-14.6,
					PRODUCT_COLORS[(row + column) % #PRODUCT_COLORS + 1],
					Enum.Material.Neon
				)
			)
		end
	end
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
		sign = "HANDY HANK'S HARDWARE",
	})
	counter(model, cf, 14, 12, Color3.fromRGB(160, 110, 70), nil, "Hardware")
	shelves(model, cf, slot.width)
end

local function clothes(parent, slot)
	local model, cf = walkIn(
		parent,
		"Clothes",
		slot,
		{ wall = Color3.fromRGB(240, 170, 210), accent = Color3.fromRGB(200, 80, 160), sign = "BAGS" }
	)
	counter(model, cf, 12, 12, Color3.fromRGB(200, 170, 220), nil, "Clothes")
	-- Racks of bags (placeholders): a body and a strap each.
	for index, x in { -12, 0, 12 } do
		Kit.quiet(
			piece(
				model,
				cf,
				`Rack{index}`,
				Vector3.new(8, 0.3, 0.3),
				x,
				5.5,
				-4,
				Color3.fromRGB(180, 180, 190),
				Enum.Material.Metal
			)
		)
		for hanger = -3, 3, 2 do
			local color = PRODUCT_COLORS[rng:NextInteger(1, #PRODUCT_COLORS)]
			Kit.decor(
				piece(model, cf, "Bag", Vector3.new(1.6, 1.6, 0.8), x + hanger, 4, -4, color, Enum.Material.Fabric)
			)
			Kit.decor(
				piece(
					model,
					cf,
					"BagStrap",
					Vector3.new(0.2, 0.6, 0.2),
					x + hanger,
					5.1,
					-4,
					color,
					Enum.Material.Fabric
				)
			)
		end
	end
end

local function gunStore(parent, slot)
	local model, cf = walkIn(
		parent,
		"GunStore",
		slot,
		{ wall = Color3.fromRGB(90, 90, 110), accent = Color3.fromRGB(40, 180, 220), sign = "TONY'S BLASTERS" }
	)
	counter(model, cf, 16, 12, Color3.fromRGB(60, 60, 75), nil, "Guns")
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
		case.Transparency = 0.4
		Kit.decor(
			piece(
				model,
				cf,
				"Blaster",
				Vector3.new(0.8, 0.8, 2.4),
				x,
				3.1,
				-2,
				Color3.fromRGB(60, 220, 255),
				Enum.Material.Neon
			)
		)
		Kit.decor(
			piece(
				model,
				cf,
				"Blaster",
				Vector3.new(0.8, 0.8, 2.4),
				x,
				3.1,
				2,
				Color3.fromRGB(255, 120, 220),
				Enum.Material.Neon
			)
		)
	end
	staffSpot(model, cf, "Tony", 16)
end

local function burger(parent, slot)
	local model, cf = walkIn(
		parent,
		"Burger",
		slot,
		{ wall = Color3.fromRGB(250, 210, 90), accent = Color3.fromRGB(220, 60, 50), sign = "BURGER BARN" }
	)
	counter(model, cf, 18, 12, Color3.fromRGB(220, 60, 50))
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
	Kit.sign(sign, Enum.NormalId.Front, "SPEEDY'S GARAGE", accent, Color3.new(1, 1, 1))
	counter(model, cf, 8, 10, Color3.fromRGB(80, 80, 90), nil, "Garage").CFrame = cf
		* CFrame.new(-width / 2 + 6, 1.9, 10)
	Kit.decor(piece(model, cf, "TyreStack", Vector3.new(3, 4, 3), width / 2 - 4, 2.4, -12, Color3.fromRGB(30, 30, 32)))
	ceilingLight(model, cf, 16, height)
end

local function depot(parent, slot)
	local model, cf = walkIn(parent, "Depot", slot, {
		wall = Color3.fromRGB(210, 130, 60),
		accent = Color3.fromRGB(120, 70, 30),
		sign = "ZOOM DELIVERIES",
		height = 15,
	})
	counter(model, cf, 16, 12, Color3.fromRGB(176, 128, 72), "DeliveryDepot")
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

local function police(parent, slot)
	local cf = frameOf(slot)
	local width, height = slot.width - 4, 16
	local model = Kit.model(parent, "PoliceStation")
	Kit.quiet(
		piece(model, cf, "Body", Vector3.new(width, height, DEPTH - 4), 0, height / 2, 0, Color3.fromRGB(70, 100, 180))
	)
	for index, x in { -width / 4, width / 4 } do
		local glass = Kit.decor(
			piece(
				model,
				cf,
				`Window{index}`,
				Vector3.new(width / 3, 5, 0.3),
				x,
				7,
				-DEPTH / 2 + 1.8,
				Kit.Colors.Glass,
				Enum.Material.Glass
			)
		)
		glass.Transparency = 0.2
	end
	Kit.decor(piece(model, cf, "Door", Vector3.new(6, 9, 0.3), 0, 4.5, -DEPTH / 2 + 1.8, Color3.fromRGB(30, 40, 70)))
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
	Kit.sign(sign, Enum.NormalId.Front, "POLICE", Color3.fromRGB(30, 50, 120))
	Kit.decor(
		piece(
			model,
			cf,
			"LightBar",
			Vector3.new(6, 0.8, 0.8),
			0,
			height + 0.4,
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
	Kit.sign(sign, Enum.NormalId.Front, "SUDZ CAR WASH", accent)
end

local function taxi(parent, slot)
	local model, cf = walkIn(parent, "Taxi", slot, {
		wall = Color3.fromRGB(255, 210, 50),
		accent = Color3.fromRGB(40, 40, 45),
		sign = "CITY CABS",
		height = 12,
	})
	counter(model, cf, 10, 12, Color3.fromRGB(40, 40, 45))
	return model
end

local function market(parent, slot)
	local cf = frameOf(slot)
	local model = Kit.model(parent, "Market")
	piece(model, cf, "Floor", Vector3.new(slot.width, 0.4, DEPTH), 0, 0.2, 0, Kit.Colors.Plaza, Enum.Material.Pavement)
	local stripes = { Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 150, 230), Color3.fromRGB(250, 190, 50) }
	for index, x in { -14, 0, 14 } do
		Kit.quiet(
			piece(model, cf, `Stall{index}`, Vector3.new(10, 3.5, 4), x, 2, -6, Kit.Colors.Wood, Enum.Material.Wood)
		)
		for _, px in { -4.5, 4.5 } do
			Kit.decor(piece(model, cf, "Pole", Vector3.new(0.5, 9, 0.5), x + px, 4.5, -3, Kit.Colors.White))
		end
		Kit.decor(
			piece(model, cf, `Canopy{index}`, Vector3.new(11, 0.4, 7), x, 9, -5, stripes[index], Enum.Material.Fabric)
		)
	end
	local arch = piece(model, cf, "Arch", Vector3.new(36, 3.4, 0.5), 0, 12, -DEPTH / 2 + 1, Color3.fromRGB(230, 70, 70))
	Kit.sign(arch, Enum.NormalId.Front, "STREET MARKET", Color3.fromRGB(230, 70, 70))
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
	Kit.sign(sign, Enum.NormalId.Front, "STORAGE", Color3.fromRGB(90, 60, 50))
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
			gold
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
		Kit.tree(model, `PlazaTree{index}`, corner, 10)
	end
end

function Buildings.build(map)
	local folder = Kit.folder(map, "Buildings")
	bank(folder)
	local s = Layout.slots
	convenience(folder, "CornerStore", s.CornerStore, "CORNER STORE", Color3.fromRGB(120, 200, 160))
	convenience(folder, "MiniMart", s.MiniMart, "MINI MART", Color3.fromRGB(240, 190, 90))
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
	local fillers = {
		{ "Barber", "FRESH CUTS", Color3.fromRGB(230, 230, 240), Color3.fromRGB(220, 50, 60) },
		{ "Laundromat", "SPIN CYCLE", Color3.fromRGB(180, 220, 240), Color3.fromRGB(60, 130, 200) },
		{ "Cafe", "BEAN THERE", Color3.fromRGB(200, 160, 120), Color3.fromRGB(110, 70, 40) },
		{ "Pharmacy", "PHARMACY", Color3.fromRGB(235, 245, 235), Color3.fromRGB(40, 160, 80) },
		{ "Bakery", "SWEET BAKES", Color3.fromRGB(250, 220, 180), Color3.fromRGB(210, 120, 60) },
		{ "Florist", "PETAL POWER", Color3.fromRGB(250, 210, 230), Color3.fromRGB(220, 80, 140) },
		{ "PostOffice", "POST OFFICE", Color3.fromRGB(230, 90, 80), Color3.fromRGB(40, 60, 140) },
		{ "Diner", "ROSIE'S DINER", Color3.fromRGB(180, 230, 230), Color3.fromRGB(230, 70, 90) },
		{ "Gym", "PUMP HOUSE", Color3.fromRGB(90, 90, 100), Color3.fromRGB(240, 140, 30) },
		{ "Books", "PAGE TURNER", Color3.fromRGB(150, 110, 90), Color3.fromRGB(70, 110, 60) },
		{ "PetShop", "PAWS", Color3.fromRGB(250, 240, 200), Color3.fromRGB(230, 150, 40) },
		{ "Toys", "TOY BOX", Color3.fromRGB(180, 200, 250), Color3.fromRGB(240, 90, 90) },
		{ "Music", "LOUD NOTES", Color3.fromRGB(60, 60, 70), Color3.fromRGB(170, 90, 230) },
	}
	for _, filler in fillers do
		shopfront(folder, filler[1], s[filler[1]], filler[3], filler[4], filler[2])
	end
	return folder
end

return Buildings
