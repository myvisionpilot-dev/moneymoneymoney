-- The inside of the bank, dressed like the lobby's hall (tools/build_lobby.luau): a checkered
-- green and cream marble floor, plaster walls over wood panelling with a chair rail, marble
-- pilasters with brass lamps, tall frosted windows, a coffered ceiling, two brass chandeliers
-- and the bank's name over the vault. Parts only, no scripts.
--
-- BankInterior.dress(bank) adds it all to the Bank model in a folder called Interior (built
-- again from scratch each time). It swaps out the old plain floor and neon chandeliers only if
-- they're still the builder's own; the vault and anything else on the walls are left alone.

local Kit = require(script.Parent.Kit)

local BankInterior = {}

-- The room (see Buildings' bank): inside faces of the walls, floor and ceiling heights, doors.
local WALL_X, WALL_Z = 28.5, 20.5
local LINING = 0.1 -- plaster over the stone walls
local ROOM_X, ROOM_Z = WALL_X - LINING, WALL_Z - LINING
local FLOOR_Y, CEILING_Y = 0.5, 20
local DOOR_HALF, DOOR_TOP = 6, 12
local VAULT_HALF = 7.6 -- the panelling stops either side of the vault
local CHANDELIERS = { Vector3.new(-12, 0, 4), Vector3.new(12, 0, 4) }

local CREAM = Color3.fromRGB(238, 231, 214)
local GREEN = Color3.fromRGB(36, 82, 60)
local PLASTER = Color3.fromRGB(233, 223, 199)
local WOOD = Color3.fromRGB(92, 56, 34)
local WOOD_LIGHT = Color3.fromRGB(122, 78, 48)
local BRASS = Color3.fromRGB(214, 170, 72)
local DAYLIGHT = Color3.fromRGB(176, 196, 214)
local WARM = Color3.fromRGB(255, 214, 150)
local GOLD = Color3.fromRGB(240, 196, 60)

local M = Enum.Material

local function ball(parent, name, diameter, position, color, material)
	local p = Kit.part(parent, name, Vector3.one * diameter, position, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function pointLight(target, range, brightness)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = WARM
	light.Parent = target
end

-- A box on a wall: `cf` is on the wall's stone face at ground level facing into the room; the
-- box sits `x` along the wall and `y` up, from `from` to `from + depth` out of the wall.
local function wallBox(parent, name, cf, x, y, width, height, from, depth, color, material)
	return Kit.part(
		parent,
		name,
		Vector3.new(width, height, depth),
		cf * CFrame.new(x, y, -(from + depth / 2)),
		color,
		material
	)
end

-- The builder's own floor and chandeliers, if nobody has changed them since.
local function isStock(part, size)
	return part and part:IsA("BasePart") and (part.Size - size).Magnitude < 0.01
end

local function floor(folder)
	-- Tile edges stay clear of the doorways' sides (x and z = 6), where they'd meet the walls'.
	local xs = { -29.8, -27, -21, -15, -9, -3, 3, 9, 15, 21, 27, 29.8 }
	local zs = { -21.8, -21, -15, -9, -3, 3, 9, 15, 21, 21.8 }
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local width, depth = xs[i + 1] - xs[i], zs[j + 1] - zs[j]
			local tile = Kit.part(
				folder,
				"Floor",
				Vector3.new(width, FLOOR_Y, depth),
				Vector3.new(xs[i] + width / 2, FLOOR_Y / 2, zs[j] + depth / 2),
				if (i + j) % 2 == 0 then CREAM else GREEN,
				M.Marble
			)
			tile.CanTouch = false
		end
	end
end

-- Plaster over the stone inside, leaving the doorways open.
local function lining(folder, walls)
	local function sheet(wall, from, to, bottom)
		Kit.quiet(
			wallBox(
				folder,
				"Plaster",
				wall.cf,
				(from + to) / 2,
				(bottom + CEILING_Y) / 2,
				to - from,
				CEILING_Y - bottom,
				0,
				LINING,
				PLASTER,
				M.Plaster
			)
		)
	end
	sheet(walls.north, -ROOM_X, ROOM_X, FLOOR_Y)
	for _, name in { "south", "west", "east" } do
		local wall = walls[name]
		local edge = if name == "south" then ROOM_X else WALL_Z
		sheet(wall, -edge, -DOOR_HALF, FLOOR_Y)
		sheet(wall, DOOR_HALF, edge, FLOOR_Y)
		sheet(wall, -DOOR_HALF, DOOR_HALF, DOOR_TOP)
	end
end

-- Wood panelling to a chair rail, a skirting board and a cornice: { name, middle height,
-- height, out from the plaster, depth }.
local TRIMS = {
	{ "Wainscot", FLOOR_Y + 2.5, 5, 0, 0.4, WOOD_LIGHT, M.Wood },
	{ "Skirting", FLOOR_Y + 0.4, 0.8, 0.4, 0.2, WOOD, M.Wood },
	{ "ChairRail", FLOOR_Y + 5.2, 0.4, 0, 0.6, WOOD, M.Wood },
	{ "Cornice", CEILING_Y - 0.6, 1.2, 0, 1.2, PLASTER, M.Plaster },
}

local function trims(folder, walls)
	for name, wall in walls do
		local side = name == "west" or name == "east"
		for _, trim in TRIMS do
			local low = trim[1] ~= "Cornice"
			-- Side walls run into the corners; the north and south walls stop at their trims.
			local reach = if side then ROOM_Z else ROOM_X - (trim[4] + trim[5])
			if side and trim[1] == "Skirting" then
				reach = ROOM_Z - 0.4 -- at the north and south panelling
			end
			local gap = if not low then 0 elseif name == "north" then VAULT_HALF else DOOR_HALF
			local spans = if gap > 0 then { { -reach, -gap }, { gap, reach } } else { { -reach, reach } }
			for _, span in spans do
				Kit.quiet(
					wallBox(
						folder,
						trim[1],
						wall.cf,
						(span[1] + span[2]) / 2,
						trim[2],
						span[2] - span[1],
						trim[3],
						LINING + trim[4],
						trim[5],
						trim[6],
						trim[7]
					)
				)
			end
		end
	end
end

-- A flat marble column from the chair rail to the cornice, with a brass lamp on it.
local function pilaster(folder, cf, x)
	local bottom, top = FLOOR_Y + 5.4, CEILING_Y - 1.2
	Kit.quiet(wallBox(folder, "Pilaster", cf, x, (top + bottom) / 2, 2.4, top - bottom, LINING, 0.6, CREAM, M.Marble))
	local lampY = FLOOR_Y + 9
	Kit.decor(wallBox(folder, "SconcePlate", cf, x, lampY, 0.8, 1.2, LINING + 0.6, 0.2, BRASS, M.Metal))
	Kit.decor(wallBox(folder, "SconceArm", cf, x, lampY, 0.2, 0.2, LINING + 0.8, 0.8, BRASS, M.Metal))
	local bulb = Kit.decor(
		ball(folder, "SconceBulb", 0.7, (cf * CFrame.new(x, lampY + 0.45, -(LINING + 1.6))).Position, WARM, M.Neon)
	)
	pointLight(bulb, 14, 0.8)
end

-- A tall frosted window glowing with daylight, in a wood frame with glazing bars.
local function window(folder, cf, x)
	local width, height, bottom = 6, 9, FLOOR_Y + 6.5
	local glass = Kit.decor(
		wallBox(folder, "WindowGlass", cf, x, bottom + height / 2, width, height, LINING, 0.2, DAYLIGHT, M.Neon)
	)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Range = 18
	light.Angle = 80
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 246, 228)
	light.Parent = glass
	for _, info in
		{
			{ "WindowHead", x, bottom + height + 0.4, width + 1.4, 0.8 },
			{ "WindowSide", x - (width / 2 + 0.35), bottom + height / 2, 0.7, height },
			{ "WindowSide", x + width / 2 + 0.35, bottom + height / 2, 0.7, height },
		}
	do
		Kit.decor(wallBox(folder, info[1], cf, info[2], info[3], info[4], info[5], LINING, 0.6, WOOD, M.Wood))
	end
	Kit.decor(wallBox(folder, "Mullion", cf, x, bottom + height / 2, 0.3, height, LINING + 0.2, 0.25, WOOD, M.Wood))
	Kit.decor(wallBox(folder, "Transom", cf, x, bottom + height * 0.55, width, 0.3, LINING + 0.2, 0.2, WOOD, M.Wood))
	Kit.decor(wallBox(folder, "WindowSill", cf, x, bottom - 0.25, width + 2, 0.5, LINING, 1.2, CREAM, M.Marble))
	Kit.decor(wallBox(folder, "Keystone", cf, x, bottom + height + 1.5, 1.6, 1.4, LINING, 0.7, CREAM, M.Marble))
end

-- The bank's name over the vault.
local function nameBoard(folder, cf)
	local y = CEILING_Y - 3.1
	Kit.decor(wallBox(folder, "NameFrame", cf, 0, y, 16.8, 3.4, LINING, 0.3, BRASS, M.Metal))
	local board = Kit.decor(wallBox(folder, "NameBoard", cf, 0, y, 16, 2.6, LINING + 0.3, 0.3, GREEN, M.SmoothPlastic))
	Kit.sign(board, Enum.NormalId.Front, "PENNY NATIONAL BANK", GREEN, GOLD, Enum.Font.Garamond)
end

local function ceiling(folder)
	for z = -16, 16, 8 do
		Kit.decor(
			Kit.part(
				folder,
				"Beam",
				Vector3.new(ROOM_X * 2, 1.2, 0.8),
				Vector3.new(0, CEILING_Y - 0.6, z),
				PLASTER,
				M.Plaster
			)
		)
	end
	for x = -24, 24, 8 do
		Kit.decor(
			Kit.part(
				folder,
				"Beam",
				Vector3.new(0.8, 1.2, ROOM_Z * 2),
				Vector3.new(x, CEILING_Y - 0.6, 0),
				PLASTER,
				M.Plaster
			)
		)
	end
	-- Brass chandeliers: arms with candle bulbs round a hanging rod.
	for _, at in CHANDELIERS do
		local hub = Vector3.new(at.X, CEILING_Y - 4.5, at.Z)
		Kit.decor(Kit.cylinder(folder, "ChandelierRod", 3.5, 0.3, hub + Vector3.new(0, 2.75, 0), BRASS, M.Metal))
		Kit.decor(Kit.cylinder(folder, "ChandelierCrown", 0.6, 2.2, hub + Vector3.new(0, 2.5, 0), BRASS, M.Metal))
		local core = Kit.decor(ball(folder, "ChandelierHub", 1.8, hub, BRASS, M.Metal))
		pointLight(core, 36, 1.3)
		Kit.decor(ball(folder, "ChandelierDrop", 0.8, hub - Vector3.new(0, 1.4, 0), BRASS, M.Metal))
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			Kit.decor(
				Kit.part(
					folder,
					"ChandelierArm",
					Vector3.new(0.2, 0.2, 3.6),
					CFrame.lookAt(hub + out * 2.2, hub + out * 4),
					BRASS,
					M.Metal
				)
			)
			local tip = hub + out * 4
			Kit.decor(Kit.cylinder(folder, "CandleCup", 0.4, 0.7, tip + Vector3.new(0, 0.2, 0), BRASS, M.Metal))
			Kit.decor(Kit.cylinder(folder, "Candle", 0.8, 0.3, tip + Vector3.new(0, 0.8, 0), CREAM, M.SmoothPlastic))
			Kit.decor(ball(folder, "Flame", 0.45, tip + Vector3.new(0, 1.35, 0), WARM, M.Neon))
		end
	end
end

function BankInterior.dress(bank)
	-- The plain floor and neon chandeliers it replaces (only if they're still as built).
	if isStock(bank:FindFirstChild("Floor"), Vector3.new(59.6, 0.5, 43.6)) then
		bank.Floor:Destroy()
	end
	for index = 1, 2 do
		local old = bank:FindFirstChild(`Chandelier{index}`)
		if isStock(old, Vector3.new(4, 1, 4)) then
			old:Destroy()
		end
	end
	local previous = bank:FindFirstChild("Interior")
	if previous then
		previous:Destroy()
	end
	local folder = Kit.folder(bank, "Interior")

	local function onWall(at, inward)
		return { cf = CFrame.lookAt(at, at + inward) }
	end
	-- Each wall's frame of reference: on its stone face at ground level (y = 0), facing in.
	local walls = {
		north = onWall(Vector3.new(0, 0, -WALL_Z), Vector3.zAxis),
		south = onWall(Vector3.new(0, 0, WALL_Z), -Vector3.zAxis),
		west = onWall(Vector3.new(-WALL_X, 0, 0), Vector3.xAxis),
		east = onWall(Vector3.new(WALL_X, 0, 0), -Vector3.xAxis),
	}

	floor(folder)
	lining(folder, walls)
	trims(folder, walls)
	for _, name in { "west", "east" } do
		for _, x in { -7.4, 7.4 } do
			pilaster(folder, walls[name].cf, x)
		end
		for _, x in { -14.5, 14.5 } do
			window(folder, walls[name].cf, x)
		end
	end
	for _, x in { -10, 10 } do
		pilaster(folder, walls.north.cf, x)
	end
	for _, x in { -20, 20 } do
		window(folder, walls.north.cf, x)
	end
	for _, x in { -18, -7.4, 7.4, 18 } do
		pilaster(folder, walls.south.cf, x)
	end
	nameBoard(folder, walls.north.cf)
	ceiling(folder)

	local count = 0
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			count += 1
		end
	end
	return `Bank interior dressed: {count} parts`
end

return BankInterior
