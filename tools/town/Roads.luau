-- Roads, footpaths, the bank plaza and the pavement at each dead end. East-west pieces run
-- through junctions; north-south pieces stop where they meet one, so no two flat surfaces
-- overlap (overlapping parts flicker).

local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)

local Roads = {}

local HALF, EDGE = Layout.HALF, Layout.EDGE
local PATH_OFFSET = HALF + Layout.PATH / 2

-- A flat strip along an axis between `a` and `b`, centred across the axis at `across`.
local function strip(parent, name, axis, across, a, b, width, top, thickness, color, material)
	local length = b - a
	if length <= 0.5 then
		return nil
	end
	local middle = (a + b) / 2
	local y = top - thickness / 2
	local size = if axis == "x" then Vector3.new(length, thickness, width) else Vector3.new(width, thickness, length)
	local position = if axis == "x" then Vector3.new(middle, y, across) else Vector3.new(across, y, middle)
	return Kit.part(parent, name, size, position, color, material)
end

-- The pieces of a to b left over once every cut ({ from, to }) is taken out.
local function remaining(a, b, cuts)
	table.sort(cuts, function(p, q)
		return p[1] < q[1]
	end)
	local pieces = {}
	local cursor = a
	for _, cut in cuts do
		if cut[1] > cursor then
			table.insert(pieces, { cursor, math.min(cut[1], b) })
		end
		cursor = math.max(cursor, cut[2])
	end
	if cursor < b then
		table.insert(pieces, { cursor, b })
	end
	return pieces
end

-- Where a road's footpath on one side (-1 or 1) is cut by crossing roads. A crossing road cuts
-- it only if it meets this road, sits along this footpath, and carries on over to that side
-- (so a T-junction leaves the far footpath whole).
local function blocked(road, side)
	local cuts = {}
	for _, other in Layout.roads do
		if other.axis ~= road.axis then
			local meets = other.from <= road.at + HALF and other.to >= road.at - HALF
			local alongside = other.at >= road.from - EDGE and other.at <= road.to + EDGE
			local extends = if side < 0 then other.from < road.at - HALF else other.to > road.at + HALF
			if meets and alongside and extends then
				table.insert(cuts, { other.at - HALF, other.at + HALF })
			end
		end
	end
	return cuts
end

-- One road's surface: { axis, across, a, b, width }.
local function surface(road)
	local a = if road.plazaEnd == "from" or road.deadEnd == "from" then road.from else road.from - HALF
	local b = if road.plazaEnd == "to" or road.deadEnd == "to" then road.to else road.to + HALF
	return { axis = road.axis, across = road.at, a = a, b = b, width = Layout.ROAD }
end

-- One road's footpaths, both sides.
local function footpaths(road, list)
	for _, side in { -1, 1 } do
		local startAt = if road.plazaEnd == "from" or road.deadEnd == "from" then road.from else road.from - EDGE
		local endAt = if road.plazaEnd == "to" or road.deadEnd == "to" then road.to else road.to + EDGE
		for _, piece in remaining(startAt, endAt, blocked(road, side)) do
			table.insert(list, {
				axis = road.axis,
				across = road.at + side * PATH_OFFSET,
				a = piece[1],
				b = piece[2],
				width = Layout.PATH,
			})
		end
	end
end

-- North-south strips lose whatever an east-west strip already covers.
local function clip(strips)
	local result = {}
	for _, piece in strips do
		if piece.axis == "x" then
			table.insert(result, piece)
		else
			local left, right = piece.across - piece.width / 2, piece.across + piece.width / 2
			local cuts = {}
			for _, other in strips do
				if other.axis == "x" and math.min(other.b, right) - math.max(other.a, left) > 0.01 then
					table.insert(cuts, { other.across - other.width / 2, other.across + other.width / 2 })
				end
			end
			for _, rest in remaining(piece.a, piece.b, cuts) do
				table.insert(
					result,
					{ axis = "z", across = piece.across, a = rest[1], b = rest[2], width = piece.width }
				)
			end
		end
	end
	return result
end

function Roads.build(map)
	local folder = Kit.folder(map, "Roads")

	local surfaces, paths = {}, {}
	for _, road in Layout.roads do
		table.insert(surfaces, surface(road))
		footpaths(road, paths)
	end
	-- Pavement across each dead end, the width of the mansion in front of it.
	for _, deadEnd in Layout.deadEnds do
		local side = math.sign(deadEnd.Z)
		table.insert(paths, {
			axis = "x",
			across = deadEnd.Z + side * Layout.PATH / 2,
			a = deadEnd.X - Layout.MANSION_WIDTH / 2,
			b = deadEnd.X + Layout.MANSION_WIDTH / 2,
			width = Layout.PATH,
		})
	end

	for _, piece in clip(surfaces) do
		strip(
			folder,
			"Road",
			piece.axis,
			piece.across,
			piece.a,
			piece.b,
			piece.width,
			Layout.ROAD_TOP,
			0.2,
			Kit.Colors.Road,
			Enum.Material.Asphalt
		)
	end
	for _, piece in clip(paths) do
		strip(
			folder,
			"Footpath",
			piece.axis,
			piece.across,
			piece.a,
			piece.b,
			piece.width,
			Layout.PATH_TOP,
			0.5,
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	end

	-- The bank plaza.
	Kit.part(
		folder,
		"Plaza",
		Vector3.new(Layout.PLAZA * 2, 0.3, Layout.PLAZA * 2),
		Vector3.new(0, 0.15, 0),
		Kit.Colors.Plaza,
		Enum.Material.Pavement
	)
	return folder
end

return Roads
