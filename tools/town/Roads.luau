-- Roads, footpaths, the bank plaza and the cul-de-sac turning circles.

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
	table.sort(cuts, function(p, q)
		return p[1] < q[1]
	end)
	return cuts
end

local function footpaths(parent, road)
	for _, side in { -1, 1 } do
		local startAt = road.from - EDGE
		local endAt = road.to + EDGE
		if road.plazaEnd == "from" then
			startAt = road.from
		elseif road.plazaEnd == "to" then
			endAt = road.to
		end
		if road.bulbEnd == "from" then
			startAt = road.from + EDGE
		elseif road.bulbEnd == "to" then
			endAt = road.to - EDGE
		end
		local cursor = startAt
		for _, cut in blocked(road, side) do
			strip(
				parent,
				"Footpath",
				road.axis,
				road.at + side * PATH_OFFSET,
				cursor,
				math.min(cut[1], endAt),
				Layout.PATH,
				Layout.PATH_TOP,
				0.5,
				Kit.Colors.Path,
				Enum.Material.Concrete
			)
			cursor = math.max(cursor, cut[2])
		end
		strip(
			parent,
			"Footpath",
			road.axis,
			road.at + side * PATH_OFFSET,
			cursor,
			endAt,
			Layout.PATH,
			Layout.PATH_TOP,
			0.5,
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
	end
end

function Roads.build(map)
	local folder = Kit.folder(map, "Roads")

	for _, road in Layout.roads do
		-- The surface runs through junctions (half a road width past each end).
		local a = if road.plazaEnd == "from" then road.from else road.from - HALF
		local b = if road.plazaEnd == "to" then road.to else road.to + HALF
		if road.bulbEnd == "from" then
			a = road.from
		elseif road.bulbEnd == "to" then
			b = road.to
		end
		strip(
			folder,
			"Road",
			road.axis,
			road.at,
			a,
			b,
			Layout.ROAD,
			Layout.ROAD_TOP,
			0.2,
			Kit.Colors.Road,
			Enum.Material.Asphalt
		)
		footpaths(folder, road)
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

	-- Turning circles: a ring of footpath under a round patch of road.
	for index, center in Layout.bulbs do
		Kit.cylinder(
			folder,
			`TurningCirclePath{index}`,
			0.5,
			Layout.BULB_PATH_RADIUS * 2,
			center + Vector3.new(0, 0.25, 0),
			Kit.Colors.Path,
			Enum.Material.Concrete
		)
		Kit.cylinder(
			folder,
			`TurningCircle{index}`,
			0.56,
			Layout.BULB_RADIUS * 2,
			center + Vector3.new(0, 0.28, 0),
			Kit.Colors.Road,
			Enum.Material.Asphalt
		)
	end
	return folder
end

return Roads
