-- The 60 houses: finished outside (roof, windows, porch, lawn, driveway, bins, fence, mailbox),
-- getting bigger with each tier, and mansions at the ends of the cul-de-sacs.
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
local BIN = Color3.fromRGB(40, 110, 60)
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
		bodyX = -6,
		drive = { 28, 36 },
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
	local wall = WALLS[lot.id % #WALLS + 1]
	local roofColor = ROOFS[lot.id % #ROOFS + 1]

	local model = Kit.model(folder, `House{lot.id}`)
	local body = Kit.part(model, `House{lot.id}`, Vector3.new(W, H, D), at(bx, H / 2, Y + D / 2), wall)
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
			Vector3.new(pathWidth, 0.1, Y),
			at(bx, 0.35, Y / 2),
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
	for _, x in { -lotWidth / 2 + 0.25, lotWidth / 2 - 0.25 } do
		Kit.quiet(
			Kit.part(
				model,
				"Fence",
				Vector3.new(0.4, 3.5, lotDepth - Y),
				at(x, 1.75, Y + (lotDepth - Y) / 2),
				Kit.Colors.White
			)
		)
	end
	Kit.quiet(Kit.part(model, "Fence", Vector3.new(lotWidth, 3.5, 0.4), at(0, 1.75, lotDepth - 0.25), Kit.Colors.White))

	-- Roof: a gable along the front, in two wedges that meet at the ridge.
	local halfDepth = D / 2 + 1
	Kit.quiet(
		Kit.wedge(
			model,
			"RoofFront",
			Vector3.new(W + 2, style.roof, halfDepth),
			at(bx, H + style.roof / 2, Y - 1 + halfDepth / 2),
			roofColor
		)
	)
	Kit.quiet(
		Kit.wedge(
			model,
			"RoofBack",
			Vector3.new(W + 2, style.roof, halfDepth),
			at(bx, H + style.roof / 2, Y + D + 1 - halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
			roofColor
		)
	)
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
	for _, y in rows do
		for _, x in { bx - W / 4 - 1, bx + W / 4 + 1 } do
			local glass = Kit.decor(
				Kit.part(
					model,
					"Window",
					Vector3.new(4, 3.5, 0.3),
					at(x, y, Y - 0.15),
					Kit.Colors.Glass,
					Enum.Material.Glass
				)
			)
			glass.Transparency = 0.1
		end
		for _, side in { -1, 1 } do
			Kit.decor(
				Kit.part(
					model,
					"Window",
					Vector3.new(0.3, 3.5, 4),
					at(bx + side * (W / 2 + 0.15), y, Y + D / 2),
					Kit.Colors.Glass,
					Enum.Material.Glass
				)
			)
		end
	end

	-- Front door with a porch.
	local door =
		Kit.part(body, "Door", Vector3.new(4, 7, 0.6), at(bx, 4.1, Y - 0.3), Kit.Colors.Wood, Enum.Material.Wood)
	door.Color = Color3.fromRGB(110, 70, 45)
	Kit.quiet(
		Kit.part(model, "Step", Vector3.new(7, 0.6, 3), at(bx, 0.3, Y - 1.5), Kit.Colors.Path, Enum.Material.Concrete)
	)
	Kit.decor(Kit.part(model, "PorchRoof", Vector3.new(8, 0.4, 3.5), at(bx, 8.6, Y - 1.6), roofColor))

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
		for _, segment in { { -lotWidth / 2 + 1, bx - 4 }, { bx + 4, dx1 - 1 } } do
			local width = segment[2] - segment[1]
			Kit.quiet(
				Kit.part(
					model,
					"Hedge",
					Vector3.new(width, 3, 2),
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
