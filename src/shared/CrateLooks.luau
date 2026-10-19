--!strict
-- What Tony's lucky crates look like: a box with planks, banded edges, shiny corner caps and a
-- glowing pixel "?" on its front (-Z) and right (+X) faces. Each design is a list of pieces in the
-- crate's own space, origin in its middle, 2.4 studs a side. Used for the shop pictures
-- (ItemModels) and the crates in Tony's shop (the town builder), so it needs nothing else.

export type Piece = {
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	role: string?,
	reflectance: number?,
	transparency: number?,
	name: string?,
}

local CrateLooks = {}

local SIZE = 2.4
local BAND = 0.28
local PIXEL = 0.24
local QUESTION = {
	".###.",
	"#...#",
	"....#",
	"..##.",
	"..#..",
	".....",
	"..#..",
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The "?" on a face: `face` puts its middle on the face, looking out. Each run of pixels in a
-- row is one part.
local function question(face: CFrame, color: Color3): { Piece }
	local pieces: { Piece } = {}
	for row, line in QUESTION do
		local from = 1
		while true do
			local first, last = line:find("#+", from)
			if not first or not last then
				break
			end
			local width = last - first + 1
			table.insert(pieces, {
				size = Vector3.new(PIXEL * width, PIXEL, PIXEL * 0.6),
				at = face * CFrame.new(((first + last) / 2 - 3) * PIXEL, (4 - row) * PIXEL, 0),
				color = color,
				material = Enum.Material.Neon,
				role = "glow",
			})
			from = last + 1
		end
	end
	return pieces
end

local function crate(body: Color3, band: Color3, mark: Color3, material: Enum.Material, shine: number): { Piece }
	local half = SIZE / 2
	local pieces: { Piece } = {
		{ size = Vector3.one * SIZE, at = CFrame.identity, color = body, material = material, reflectance = shine },
	}
	-- Planks: dark grooves round the sides.
	for _, y in { -0.4, 0.4 } do
		table.insert(pieces, {
			size = Vector3.new(SIZE + 0.02, 0.06, SIZE + 0.02),
			at = CFrame.new(0, y, 0),
			color = body:Lerp(Color3.new(0, 0, 0), 0.35),
			material = material,
		})
	end
	-- A metal band down every edge.
	local edge = half - BAND / 2 + 0.03
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			for _, info in
				{
					{ Vector3.new(BAND, BAND, SIZE + 0.06), Vector3.new(a, b, 0) },
					{ Vector3.new(SIZE + 0.06, BAND, BAND), Vector3.new(0, b, a) },
					{ Vector3.new(BAND, SIZE + 0.06, BAND), Vector3.new(a, 0, b) },
				}
			do
				table.insert(pieces, {
					size = info[1],
					at = CFrame.new(info[2] * edge),
					color = band,
					material = Enum.Material.Metal,
				})
			end
		end
	end
	-- Shiny caps on the top corners.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(pieces, {
				size = Vector3.one * 0.42,
				at = CFrame.new(x * (half - 0.12), half - 0.12, z * (half - 0.12)),
				color = mark,
				material = Enum.Material.Metal,
				reflectance = 0.3,
			})
		end
	end
	local front = CFrame.new(0, 0, -half - 0.04) * CFrame.Angles(0, math.rad(180), 0)
	local side = CFrame.new(half + 0.04, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	for _, face in { front, side } do
		for _, piece in question(face, mark) do
			table.insert(pieces, piece)
		end
	end
	return pieces
end

local DESIGNS: { [string]: { Piece } } = {
	LuckyCrate = crate(rgb(190, 125, 65), rgb(95, 70, 50), rgb(255, 215, 60), Enum.Material.Wood, 0),
	GoldCrate = crate(rgb(255, 205, 50), rgb(200, 120, 30), rgb(255, 110, 200), Enum.Material.SmoothPlastic, 0.1),
	DiamondCrate = crate(rgb(150, 225, 255), rgb(235, 245, 255), rgb(170, 90, 255), Enum.Material.Ice, 0.3),
}

-- The pieces of a crate (LuckyCrate, GoldCrate, DiamondCrate), or nil.
function CrateLooks.pieces(design: string): { Piece }?
	return DESIGNS[design]
end

function CrateLooks.designs(): { string }
	local list = {}
	for id in DESIGNS do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return CrateLooks
