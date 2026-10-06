-- The 60 houses: finished outside (slate roof with a fascia, framed windows with shutters and
-- sills, a stone base, porch with posts and a light, flower beds, lawn, driveway, bins, fence,
-- mailbox; every third one brick),
-- getting bigger with each tier, and mansions facing the dead-end streets. Faces that would
-- line up with the grass or each other are nudged apart so they don't flicker.
--
-- Each house body is tagged House (attributes HouseId, Tier) and holds what the jobs need:
-- Door (part), Lawn (part), Bin1/Bin2 (parts), BackDoor/Kerb/CarSpot (attachments).
-- A DeliveryDropoff pad sits on each front path.

local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)

local Houses = {}

local WALLS = {
	Color3.fromRGB(180, 210, 235),
	Color3.fromRGB(235, 200, 170),
	Color3.fromRGB(200, 235, 190),
	Color3.fromRGB(235, 180, 200),
	Color3.fromRGB(225, 225, 170),
	Color3.fromRGB(210, 195, 240),
	Color3.fromRGB(245, 245, 235),
}
local ROOFS = {
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(90, 70, 60),
	Color3.fromRGB(70, 80, 100),
	Color3.fromRGB(60, 100, 70),
}
local BRICKS = { Color3.fromRGB(170, 95, 75), Color3.fromRGB(150, 110, 90), Color3.fromRGB(185, 140, 110) }
local SHUTTERS = {
	Color3.fromRGB(40, 70, 110),
	Color3.fromRGB(60, 100, 60),
	Color3.fromRGB(120, 50, 45),
	Color3.fromRGB(50, 50, 55),
}
local FLOWERS = { Color3.fromRGB(240, 90, 120), Color3.fromRGB(250, 210, 70), Color3.fromRGB(170, 110, 240) }
local TRIM = Color3.fromRGB(248, 248, 244)
local WINDOW_GLASS = Color3.fromRGB(70, 100, 140)
local BIN = Color3.fromRGB(40, 110, 60)
local BIN_LID = Color3.fromRGB(30, 85, 45)
local STONE = Color3.fromRGB(236, 232, 220)
local GOLD = Color3.fromRGB(240, 196, 60)

-- Per tier: house body width/depth/wall height, roof height, front yard depth, driveway x-range.
local STYLES = {
	{ width = 22, depth = 18, height = 11, roof = 6, yard = 20, bodyX = -4, drive = { 12, 19 } },
	{ width = 26, depth = 20, height = 12, roof = 7, yard = 20, bodyX = -4, drive = { 12, 19 } },
	{ width = 30, depth = 22, height = 19, roof = 8, yard = 20, bodyX = -6, drive = { 12, 19 }, upstairs = true },
	{
		width = 52,
		depth = 30,
		height = 24,
		roof = 10,
		yard = 34,
		bodyX = 0, -- the gate and front door line up with the road
		drive = { 30, 38 },
		upstairs = true,
		mansion = true,
	},
}

local function attachment(parent, name, worldCFrame)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = parent
	a.WorldCFrame = worldCFrame
	return a
end

-- A front window on the wall whose outside face is at z (lot space, the street is -Z): a white
-- frame, dark glass with a cross of glazing bars, a sill and a shutter either side.
local function frontWindow(model, at, x, y, z, shutter)
	Kit.decor(Kit.part(model, "WindowFrame", Vector3.new(4.8, 4.3, 0.2), at(x, y, z - 0.12), TRIM))
	local glass = Kit.decor(
		Kit.part(model, "Window", Vector3.new(4, 3.5, 0.2), at(x, y, z - 0.25), WINDOW_GLASS, Enum.Material.Glass)
	)
	glass.Reflectance = 0.15
	Kit.decor(Kit.part(model, "GlazingBar", Vector3.new(0.2, 3.5, 0.1), at(x, y, z - 0.42), TRIM))
	Kit.decor(Kit.part(model, "GlazingBar", Vector3.new(4, 0.2, 0.1), at(x, y, z - 0.42), TRIM))
	Kit.decor(Kit.part(model, "Sill", Vector3.new(5.2, 0.3, 0.7), at(x, y - 2.32, z - 0.37), TRIM))
	for _, side in { -1, 1 } do
		Kit.decor(Kit.part(model, "Shutter", Vector3.new(1.2, 3.9, 0.2), at(x + side * 3.1, y, z - 0.12), shutter))
	end
end

-- A side window on the wall whose outside face is at x = side * edge.
local function sideWindow(model, at, edge, side, y, z)
	Kit.decor(Kit.part(model, "WindowFrame", Vector3.new(0.2, 4.3, 4.8), at(side * (edge + 0.12), y, z), TRIM))
	local glass = Kit.decor(
		Kit.part(
			model,
			"Window",
			Vector3.new(0.2, 3.5, 4),
			at(side * (edge + 0.25), y, z),
			WINDOW_GLASS,
			Enum.Material.Glass
		)
	)
	glass.Reflectance = 0.15
end

local function house(folder, lot)
	local style = STYLES[lot.tier]
	local lotWidth = if style.mansion then Layout.MANSION_WIDTH else Layout.LOT_WIDTH
	local lotDepth = if style.mansion then Layout.MANSION_DEPTH else Layout.LOT_DEPTH
	-- Lot space: x across the street front, z from the street (0) back into the lot.
	local cf = CFrame.lookAt(lot.front, lot.front - lot.inward)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local W, D, H, Y = style.width, style.depth, style.height, style.yard
	local bx = style.bodyX
	local dx1, dx2 = style.drive[1], style.drive[2]
	local brick = lot.id % 3 == 0
	local wall = if brick then BRICKS[lot.id % #BRICKS + 1] else WALLS[lot.id % #WALLS + 1]
	local roofColor = ROOFS[lot.id % #ROOFS + 1]
	local shutter = SHUTTERS[lot.id % #SHUTTERS + 1]

	local model = Kit.model(folder, `House{lot.id}`)
	-- The front wall sits 0.1 in front of the back garden's edge.
	local body = Kit.part(
		model,
		`House{lot.id}`,
		Vector3.new(W, H, D + 0.1),
		at(bx, H / 2, Y + D / 2 - 0.05),
		wall,
		if brick then Enum.Material.Brick else Enum.Material.SmoothPlastic
	)
	body:SetAttribute("HouseId", lot.id)
	body:SetAttribute("Tier", lot.tier)
	Kit.tag(body, "House")

	-- Grounds: front lawn (the one you mow), back garden, path, driveway, fence.
	local lawnFrom = -lotWidth / 2 + 0.5
	local lawnTo = if style.mansion then -10 else dx1 - 0.5
	local lawn = Kit.part(
		body,
		"Lawn",
		Vector3.new(lawnTo - lawnFrom, 0.3, Y - 1),
		at((lawnFrom + lawnTo) / 2, 0.15, Y / 2),
		Kit.Colors.Grass,
		Enum.Material.Grass
	)
	Kit.quiet(lawn)
	if style.mansion then
		Kit.quiet(
			Kit.part(
				model,
				"FrontGrass",
				Vector3.new(dx1 - 1 - lawnTo, 0.3, Y - 1),
				at((lawnTo + dx1 - 1) / 2, 0.15, Y / 2),
				Kit.Colors.Grass,
				Enum.Material.Grass
			)
		)
	end
	Kit.quiet(
		Kit.part(
			model,
			"Garden",
			Vector3.new(lotWidth, 0.3, lotDepth - Y),
			at(0, 0.15, Y + (lotDepth - Y) / 2),
			Kit.Colors.DarkGrass,
			Enum.Material.Grass
		)
	)
	local pathWidth = if style.mansion then 6 else 3
	Kit.quiet(
		Kit.part(
			model,
			"Path",
			Vector3.new(pathWidth, 0.1, Y - 0.2),
			at(bx, 0.35, (Y - 0.2) / 2),
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	)
	Kit.quiet(
		Kit.part(
			model,
			"Driveway",
			Vector3.new(dx2 - dx1, 0.1, Y + D * 0.6),
			at((dx1 + dx2) / 2, 0.35, (Y + D * 0.6) / 2),
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	)
	-- Side fences stop just short of the garden's edges and tuck inside the (taller) back fence.
	for _, x in { -lotWidth / 2 + 0.25, lotWidth / 2 - 0.25 } do
		Kit.quiet(
			Kit.part(
				model,
				"Fence",
				Vector3.new(0.4, 3.5, lotDepth - Y - 0.4),
				at(x, 1.75, Y + (lotDepth - Y) / 2),
				Kit.Colors.White
			)
		)
	end
	Kit.quiet(
		Kit.part(model, "Fence", Vector3.new(lotWidth - 0.2, 3.6, 0.4), at(0, 1.8, lotDepth - 0.25), Kit.Colors.White)
	)

	-- Roof: a gable along the front, in two wedges that meet at the ridge.
	local halfDepth = D / 2 + 1
	Kit.quiet(
		Kit.wedge(
			model,
			"RoofFront",
			Vector3.new(W + 2, style.roof, halfDepth),
			at(bx, H + style.roof / 2, Y - 1 + halfDepth / 2),
			roofColor,
			Enum.Material.Slate
		)
	)
	Kit.decor(Kit.part(model, "Fascia", Vector3.new(W + 2.2, 0.6, 0.25), at(bx, H + 0.05, Y - 1.12), TRIM))
	Kit.quiet(
		Kit.wedge(
			model,
			"RoofBack",
			Vector3.new(W + 2, style.roof, halfDepth),
			at(bx, H + style.roof / 2, Y + D + 1 - halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
			roofColor,
			Enum.Material.Slate
		)
	)
	-- A stone base all round, and white boards up the front corners.
	Kit.quiet(
		Kit.part(
			model,
			"Foundation",
			Vector3.new(W + 0.4, 1, D + 0.4),
			at(bx, 0.55, Y + D / 2 - 0.05),
			Color3.fromRGB(150, 150, 155),
			Enum.Material.Slate
		)
	)
	for _, side in { -1, 1 } do
		Kit.decor(
			Kit.part(
				model,
				"CornerBoard",
				Vector3.new(0.5, H - 0.05, 0.5),
				at(bx + side * (W / 2 + 0.05), (H - 0.05) / 2, Y - 0.1),
				TRIM
			)
		)
	end
	Kit.decor(
		Kit.part(
			model,
			"Chimney",
			Vector3.new(2, style.roof, 2),
			at(bx + W / 4, H + style.roof * 0.6, Y + D * 0.7),
			Kit.Colors.Brick,
			Enum.Material.Brick
		)
	)

	-- Windows: front and sides, plus an upstairs row on the bigger houses.
	local rows = if style.upstairs then { 5, H * 0.72 } else { 5 }
	local function sideAt(x, y, z)
		return at(bx + x, y, z)
	end
	for row, y in rows do
		for _, x in { bx - W / 4 - 1, bx + W / 4 + 1 } do
			frontWindow(model, at, x, y, Y - 0.1, shutter)
			-- A flower bed under each downstairs window.
			if row == 1 then
				Kit.quiet(
					Kit.part(
						model,
						"FlowerBed",
						Vector3.new(4.8, 0.5, 1.3),
						at(x, 0.57, Y - 1.0),
						Color3.fromRGB(95, 70, 50),
						Enum.Material.Ground
					)
				)
				for index, dx in { -1.4, 0, 1.4 } do
					local flower = Kit.decor(
						Kit.part(
							model,
							"Flower",
							Vector3.one * 0.8,
							at(x + dx, 1.15, Y - 1.0),
							FLOWERS[(lot.id + index) % #FLOWERS + 1]
						)
					)
					flower.Shape = Enum.PartType.Ball
				end
			end
		end
		for _, side in { -1, 1 } do
			sideWindow(model, sideAt, W / 2, side, y, Y + D / 2)
		end
	end

	-- Front door with a porch (a mansion's stands on its steps).
	local doorY = if style.mansion then 4.5 else 4.1
	local door =
		Kit.part(body, "Door", Vector3.new(4, 7, 0.6), at(bx, doorY, Y - 0.3), Kit.Colors.Wood, Enum.Material.Wood)
	door.Color = Color3.fromRGB(110, 70, 45)
	Kit.quiet(
		Kit.part(
			model,
			"Step",
			Vector3.new(7, 0.6, 2.9),
			at(bx, 0.3, Y - 1.55),
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	)
	Kit.decor(Kit.part(model, "PorchRoof", Vector3.new(8, 0.4, 3.5), at(bx, 8.6, Y - 1.6), roofColor))
	Kit.decor(Kit.part(model, "DoorFrame", Vector3.new(5.2, 7.9, 0.15), at(bx, doorY + 0.3, Y - 0.2), TRIM))
	local knob = Kit.decor(
		Kit.part(
			model,
			"DoorKnob",
			Vector3.one * 0.35,
			at(bx + 1.4, doorY, Y - 0.65),
			Color3.fromRGB(230, 190, 60),
			Enum.Material.Metal
		)
	)
	knob.Shape = Enum.PartType.Ball
	Kit.decor(
		Kit.part(
			model,
			"PorchLight",
			Vector3.new(0.5, 0.7, 0.4),
			at(bx - 3, 7.9, Y - 0.35),
			Color3.fromRGB(255, 230, 160),
			Enum.Material.Neon
		)
	)
	if not style.mansion then
		for _, side in { -1, 1 } do
			Kit.quiet(
				Kit.part(model, "PorchPost", Vector3.new(0.5, 8.05, 0.5), at(bx + side * 3.6, 4.33, Y - 3.05), TRIM)
			)
		end
	end

	-- Mailbox with the house number.
	local mx = -lotWidth / 2 + 3
	Kit.decor(
		Kit.part(model, "MailboxPost", Vector3.new(0.4, 3, 0.4), at(mx, 1.8, 1.5), Kit.Colors.Wood, Enum.Material.Wood)
	)
	local box =
		Kit.decor(Kit.part(model, "Mailbox", Vector3.new(1.6, 1.2, 2), at(mx, 3.6, 1.5), Color3.fromRGB(40, 60, 140)))
	Kit.sign(box, Enum.NormalId.Front, tostring(lot.id), Color3.fromRGB(40, 60, 140))

	-- Bins beside the house, and the kerb they get wheeled out to.
	local binX = (bx + W / 2 + dx1) / 2
	for index = 1, 2 do
		local bin = Kit.part(body, `Bin{index}`, Vector3.new(2, 3, 2), at(binX, 1.8, Y + 1.5 + index * 3), BIN)
		bin.CanTouch = false
		-- A wheelie bin: a lid and two wheels at the back (inside the bin part, so they go with it).
		Kit.decor(Kit.part(bin, "Lid", Vector3.new(2.2, 0.25, 2.3), bin.CFrame * CFrame.new(0, 1.6, 0.05), BIN_LID))
		for _, x in { -0.8, 0.8 } do
			local wheel = Kit.decor(
				Kit.part(
					bin,
					"Wheel",
					Vector3.new(0.3, 0.8, 0.8),
					bin.CFrame * CFrame.new(x, -1.1, 1),
					Color3.fromRGB(25, 25, 30)
				)
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	attachment(body, "Kerb", at(dx1 - 3, 0.5, -3))
	attachment(body, "CarSpot", at((dx1 + dx2) / 2, 0.35, Y / 2 + 2))
	attachment(body, "BackDoor", at(bx, 3, Y + D + 1.5))

	-- Delivery drop-off on the front path.
	local pad =
		Kit.part(model, `Dropoff{lot.id}`, Vector3.new(5, 0.12, 5), at(bx, 0.42, 8), Kit.Colors.Pad, Enum.Material.Neon)
	pad.Transparency = 0.4
	pad.CanCollide = false
	pad.CanQuery = false
	Kit.tag(pad, "DeliveryDropoff")

	-- Somewhere to hide in some back gardens.
	if lot.id % 4 == 3 then
		Kit.bush(model, "Bush", (at(-lotWidth / 4, 0.3, lotDepth - 12)).Position)
	end

	if style.mansion then
		-- Columns and a portico, a balcony, gate posts, hedges and a fountain.
		for _, x in { -14, -6, 6, 14 } do
			Kit.quiet(
				Kit.cylinder(
					model,
					"Column",
					H * 0.75,
					2.4,
					at(bx + x, H * 0.375, Y - 3).Position,
					STONE,
					Enum.Material.Limestone
				)
			)
		end
		Kit.quiet(
			Kit.part(
				model,
				"Portico",
				Vector3.new(34, 1.2, 7),
				at(bx, H * 0.75 + 0.6, Y - 3),
				STONE,
				Enum.Material.Limestone
			)
		)
		Kit.decor(
			Kit.part(
				model,
				"BalconyRail",
				Vector3.new(34, 2, 0.4),
				at(bx, H * 0.75 + 2.2, Y - 6.3),
				GOLD,
				Enum.Material.Metal
			)
		)
		Kit.quiet(Kit.part(model, "Steps", Vector3.new(12, 1, 6), at(bx, 0.5, Y - 3), STONE, Enum.Material.Limestone))
		-- Hedges stop at the gate posts (and short of the mailbox), a little thinner than them.
		for _, segment in { { -lotWidth / 2 + 5, bx - 5 }, { bx + 5, dx1 - 1 } } do
			local width = segment[2] - segment[1]
			Kit.quiet(
				Kit.part(
					model,
					"Hedge",
					Vector3.new(width, 3, 1.8),
					at((segment[1] + segment[2]) / 2, 1.8, 1.5),
					Kit.Colors.Leaves,
					Enum.Material.LeafyGrass
				)
			)
		end
		for _, x in { bx - 4, bx + 4 } do
			Kit.quiet(
				Kit.part(model, "GatePost", Vector3.new(2, 5, 2), at(x, 2.8, 1.5), STONE, Enum.Material.Limestone)
			)
			local ball =
				Kit.decor(Kit.part(model, "GateBall", Vector3.one * 1.6, at(x, 6, 1.5), GOLD, Enum.Material.Metal))
			ball.Shape = Enum.PartType.Ball
		end
		local fountain = at((lawnTo + dx1) / 2, 0, Y / 2).Position
		Kit.quiet(
			Kit.cylinder(
				model,
				"FountainBasin",
				1.2,
				10,
				fountain + Vector3.new(0, 0.9, 0),
				STONE,
				Enum.Material.Limestone
			)
		)
		Kit.decor(
			Kit.cylinder(
				model,
				"FountainWater",
				0.2,
				8.6,
				fountain + Vector3.new(0, 1.45, 0),
				Color3.fromRGB(90, 170, 240),
				Enum.Material.Glass
			)
		)
		Kit.quiet(
			Kit.cylinder(
				model,
				"FountainPillar",
				5,
				1.4,
				fountain + Vector3.new(0, 3, 0),
				STONE,
				Enum.Material.Limestone
			)
		)
	end
	return model
end

function Houses.build(map)
	local folder = Kit.folder(map, "Houses")
	for _, lot in Layout.lots do
		house(folder, lot)
	end
	return folder
end

return Houses
