--!strict
-- Builds the inside of a house for a break-in (Paths/BreakIn), far above town where nobody sees
-- it, when someone gets in. Parts only, no scripts. You come in by the door at the near end,
-- through a hallway, across one (a mansion: two) bands of red lasers, to where the cash is.
--   Normal houses (tiers 1 and 2): one living-room layout, recoloured house by house.
--   Rich houses (tier 3): a bigger lounge with a fireplace, a piano and a bar, in dark colours.
--   Mansions: a grand hall and a vault, two laser bands, loads of cash.
-- The lasers come from BreakInLasers (a different layout per house). Room space: x across (+ is
-- left as you walk in), y up from the floor, z away from the door.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Particles = require(ReplicatedStorage.Shared.Particles)
local Studs = require(ReplicatedStorage.Shared.Studs)
local BreakInLasers = require(script.Parent.BreakInLasers)

local LASER_TAG = "Laser"
local ZONE_TAG = "IndoorZone" -- shared/IndoorGrade softens the light in here
local LASER_RED = Color3.fromRGB(255, 30, 40)
local BEAM = 0.24 -- the beam you mustn't touch...
local GLOW = 0.7 -- ...and the soft glow round it (just for show)
local WOOD = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local MARBLE = Enum.Material.Marble
local NEON = Enum.Material.Neon

export type Room = {
	model: Model,
	spawn: CFrame, -- just inside the door, facing in
	exit: BasePart, -- the door back out
	lasers: { BasePart },
	piles: { BasePart }, -- each pile's main bundle (its Value attribute is filled in by BreakIn)
}

local BreakInRooms = {}

type Palette = {
	wall: Color3,
	floor: Color3,
	sofa: Color3,
	rug: Color3,
	accent: Color3,
	trim: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GOLD = rgb(255, 200, 60)
local DARK_WOOD = rgb(90, 58, 38)
local BLACK = rgb(28, 28, 32)

local NORMAL: { Palette } = {
	{
		wall = rgb(236, 222, 196),
		floor = rgb(176, 124, 78),
		sofa = rgb(70, 110, 190),
		rug = rgb(200, 70, 70),
		accent = rgb(250, 200, 80),
		trim = rgb(250, 250, 245),
	},
	{
		wall = rgb(200, 230, 210),
		floor = rgb(150, 105, 70),
		sofa = rgb(220, 120, 60),
		rug = rgb(70, 150, 120),
		accent = rgb(240, 240, 240),
		trim = rgb(250, 250, 245),
	},
	{
		wall = rgb(235, 205, 225),
		floor = rgb(196, 160, 120),
		sofa = rgb(120, 80, 170),
		rug = rgb(250, 190, 90),
		accent = rgb(90, 200, 200),
		trim = rgb(250, 250, 245),
	},
	{
		wall = rgb(210, 225, 245),
		floor = rgb(120, 90, 70),
		sofa = rgb(200, 60, 70),
		rug = rgb(60, 90, 170),
		accent = rgb(250, 220, 90),
		trim = rgb(250, 250, 245),
	},
	{
		wall = rgb(245, 235, 200),
		floor = rgb(170, 140, 100),
		sofa = rgb(60, 140, 90),
		rug = rgb(230, 120, 60),
		accent = rgb(200, 80, 140),
		trim = rgb(250, 250, 245),
	},
	{
		wall = rgb(225, 215, 240),
		floor = rgb(140, 100, 80),
		sofa = rgb(240, 180, 50),
		rug = rgb(110, 70, 160),
		accent = rgb(80, 170, 240),
		trim = rgb(250, 250, 245),
	},
}
local RICH: { Palette } = {
	{
		wall = rgb(40, 52, 86),
		floor = rgb(92, 56, 36),
		sofa = rgb(150, 30, 45),
		rug = rgb(200, 170, 90),
		accent = GOLD,
		trim = rgb(240, 220, 160),
	},
	{
		wall = rgb(32, 72, 56),
		floor = rgb(110, 70, 45),
		sofa = rgb(225, 205, 165),
		rug = rgb(120, 30, 40),
		accent = GOLD,
		trim = rgb(240, 220, 160),
	},
	{
		wall = rgb(72, 40, 72),
		floor = rgb(64, 42, 30),
		sofa = rgb(44, 44, 54),
		rug = rgb(220, 190, 120),
		accent = GOLD,
		trim = rgb(240, 220, 160),
	},
}
local MANSION: { Palette } = {
	{
		wall = rgb(238, 226, 204),
		floor = rgb(226, 216, 198),
		sofa = rgb(170, 30, 40),
		rug = rgb(190, 25, 35),
		accent = GOLD,
		trim = GOLD,
	},
	{
		wall = rgb(214, 224, 240),
		floor = rgb(218, 224, 234),
		sofa = rgb(40, 70, 150),
		rug = rgb(30, 60, 150),
		accent = rgb(220, 225, 235),
		trim = rgb(220, 225, 235),
	},
}

-- The room being built: its frame (floor level, the door's middle), size and the model.
type Build = { frame: CFrame, model: Model, width: number, depth: number, height: number, palette: Palette }

local function part(
	build: Build,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	Studs.dress(p)
	p.Parent = build.model
	return p
end

-- A piece of furniture's own frame: standing on the floor at (x, z), turned `turn` degrees.
local function spot(build: Build, x: number, z: number, turn: number?): CFrame
	return build.frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(turn or 0), 0)
end

-- A block in a furniture frame: (x, z) its middle, y its bottom.
local function piece(
	build: Build,
	at: CFrame,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(build, name, size, at * CFrame.new(x, y + size.Y / 2, z), color, material)
	p.CanQuery = false
	return p
end

-- Shell ---------------------------------------------------------------------------------

local function shell(build: Build, floorMaterial: Enum.Material)
	local w, d, h, pal = build.width, build.depth, build.height, build.palette
	local f = build.frame
	part(build, "Floor", Vector3.new(w + 2, 1, d + 2), f * CFrame.new(0, -0.5, d / 2), pal.floor, floorMaterial)
	part(
		build,
		"Ceiling",
		Vector3.new(w + 2, 1, d + 2),
		f * CFrame.new(0, h + 0.5, d / 2),
		pal.wall:Lerp(Color3.new(1, 1, 1), 0.55)
	)
	for _, side in { -1, 1 } do
		part(build, "Wall", Vector3.new(1, h, d + 2), f * CFrame.new(side * (w / 2 + 0.5), h / 2, d / 2), pal.wall)
		part(build, "Skirting", Vector3.new(0.3, 0.9, d), f * CFrame.new(side * (w / 2 - 0.15), 0.45, d / 2), pal.trim)
	end
	for _, z in { -0.5, d + 0.5 } do
		part(build, "Wall", Vector3.new(w + 2, h, 1), f * CFrame.new(0, h / 2, z), pal.wall)
	end
	part(build, "Skirting", Vector3.new(w, 0.9, 0.3), f * CFrame.new(0, 0.45, d - 0.15), pal.trim)
	-- The softer indoor light (shared/IndoorGrade) covers the whole room.
	local zone = part(build, "Zone", Vector3.new(w + 4, h + 4, d + 4), f * CFrame.new(0, h / 2, d / 2), pal.wall)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	CollectionService:AddTag(zone, ZONE_TAG)
end

-- A ceiling light: a glowing panel with a lamp behind it.
local function ceilingLight(build: Build, x: number, z: number, range: number)
	local glow = part(
		build,
		"CeilingLight",
		Vector3.new(5, 0.3, 5),
		build.frame * CFrame.new(x, build.height - 0.15, z),
		rgb(255, 245, 220),
		NEON
	)
	glow.CanQuery = false
	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = range
	light.Color = rgb(255, 240, 215)
	light.Shadows = true
	light.Parent = glow
end

-- A window on a side wall with curtains (it shows a pale sky).
local function window(build: Build, side: number, z: number)
	local x = side * (build.width / 2 - 0.05)
	local at = spot(build, x, z, if side < 0 then 90 else -90)
	piece(build, at, "WindowFrame", Vector3.new(6, 5, 0.2), 0, 4, 0, build.palette.trim)
	local pane = piece(build, at, "Window", Vector3.new(5.2, 4.2, 0.2), 0, 4.4, 0.08, rgb(150, 200, 250), NEON)
	pane.Transparency = 0.25
	for _, dx in { -3.3, 3.3 } do
		piece(build, at, "Curtain", Vector3.new(1.4, 6, 0.3), dx, 3.2, 0.25, build.palette.accent, FABRIC)
	end
end

local function painting(build: Build, side: number, z: number, y: number, color: Color3)
	local x = side * (build.width / 2 - 0.05)
	local at = spot(build, x, z, if side < 0 then 90 else -90)
	piece(build, at, "PictureFrame", Vector3.new(5, 3.6, 0.2), 0, y, 0, GOLD, METAL)
	piece(build, at, "Picture", Vector3.new(4.2, 2.8, 0.2), 0, y + 0.4, 0.08, color)
end

-- The way back out, at the near end.
local function exitDoor(build: Build): BasePart
	local at = spot(build, 0, 0.05, 0)
	piece(build, at, "DoorFrame", Vector3.new(5.4, 8.2, 0.3), 0, 0, 0, build.palette.trim)
	local door = piece(build, at, "ExitDoor", Vector3.new(4.4, 7.6, 0.4), 0, 0, 0.2, DARK_WOOD, WOOD)
	piece(build, at, "Knob", Vector3.new(0.4, 0.4, 0.4), 1.6, 3.6, 0.5, GOLD, METAL)
	door.CanQuery = true
	return door
end

-- Furniture -----------------------------------------------------------------------------

local function sofa(build: Build, x: number, z: number, turn: number, color: Color3, length: number?)
	local at = spot(build, x, z, turn)
	local l = length or 9
	piece(build, at, "Sofa", Vector3.new(l, 1.6, 3.4), 0, 0, 0, color:Lerp(BLACK, 0.2), FABRIC)
	piece(build, at, "SofaBack", Vector3.new(l, 2.8, 0.9), 0, 0, -1.25, color, FABRIC)
	for _, dx in { -l / 2 + 0.45, l / 2 - 0.45 } do
		piece(build, at, "SofaArm", Vector3.new(0.9, 2.4, 3.4), dx, 0, 0, color, FABRIC)
	end
	for k = 0, 1 do
		piece(
			build,
			at,
			"Cushion",
			Vector3.new(l / 2 - 1, 0.5, 2.4),
			(k - 0.5) * (l / 2 - 0.5),
			1.6,
			0.3,
			color:Lerp(rgb(255, 255, 255), 0.1),
			FABRIC
		)
	end
end

local function coffeeTable(build: Build, x: number, z: number, top: Color3)
	local at = spot(build, x, z)
	piece(build, at, "TableTop", Vector3.new(6, 0.35, 3), 0, 1.5, 0, top, WOOD)
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -1.1, 1.1 } do
			piece(build, at, "TableLeg", Vector3.new(0.35, 1.5, 0.35), dx, 0, dz, top:Lerp(BLACK, 0.3), WOOD)
		end
	end
end

local function tv(build: Build, x: number, z: number, turn: number)
	local at = spot(build, x, z, turn)
	piece(build, at, "TvStand", Vector3.new(8, 1.8, 1.8), 0, 0, 0, DARK_WOOD, WOOD)
	piece(build, at, "Tv", Vector3.new(7, 4, 0.4), 0, 1.8, -0.2, BLACK)
	local screen = piece(build, at, "TvScreen", Vector3.new(6.4, 3.5, 0.1), 0, 2.05, 0.04, rgb(60, 120, 200), NEON)
	screen.Transparency = 0.2
end

local function rug(build: Build, x: number, z: number, w: number, d: number, color: Color3)
	local at = spot(build, x, z)
	piece(build, at, "Rug", Vector3.new(w, 0.1, d), 0, 0, 0, color, FABRIC)
	piece(
		build,
		at,
		"RugBorder",
		Vector3.new(w - 1.2, 0.12, d - 1.2),
		0,
		0,
		0,
		color:Lerp(rgb(255, 255, 255), 0.25),
		FABRIC
	)
end

local function bookshelf(build: Build, x: number, z: number, turn: number, wood: Color3)
	local at = spot(build, x, z, turn)
	piece(build, at, "ShelfBack", Vector3.new(6, 8, 0.3), 0, 0, -0.65, wood, WOOD)
	for _, dx in { -2.85, 2.85 } do
		piece(build, at, "ShelfSide", Vector3.new(0.3, 8, 1.6), dx, 0, 0, wood, WOOD)
	end
	local colors = { rgb(200, 60, 60), rgb(60, 110, 200), rgb(70, 170, 90), rgb(230, 190, 60), rgb(150, 80, 180) }
	for level = 0, 3 do
		piece(build, at, "Shelf", Vector3.new(5.4, 0.25, 1.4), 0, level * 2.4, 0, wood, WOOD)
		if level < 3 then
			for k = 0, 5 do
				local tall = 1.4 + (k * 7 % 5) * 0.12
				piece(
					build,
					at,
					"Book",
					Vector3.new(0.55, tall, 1.1),
					-2.2 + k * 0.62,
					level * 2.4 + 0.25,
					0,
					colors[(k + level) % #colors + 1]
				)
			end
		end
	end
end

local function plant(build: Build, x: number, z: number, size: number?)
	local at = spot(build, x, z)
	local s = size or 1
	piece(build, at, "Pot", Vector3.new(1.8, 1.8, 1.8) * s, 0, 0, 0, rgb(190, 110, 70))
	piece(build, at, "Leaves", Vector3.new(2.8, 2.8, 2.8) * s, 0, 1.8 * s, 0, rgb(80, 180, 50))
	piece(build, at, "Leaves", Vector3.new(1.8, 1.8, 1.8) * s, 0.4 * s, 4.3 * s, 0.2 * s, rgb(100, 200, 60))
end

local function lamp(build: Build, x: number, z: number, shade: Color3)
	local at = spot(build, x, z)
	piece(build, at, "LampBase", Vector3.new(1.4, 0.3, 1.4), 0, 0, 0, BLACK, METAL)
	piece(build, at, "LampPole", Vector3.new(0.3, 5, 0.3), 0, 0.3, 0, BLACK, METAL)
	local top = piece(build, at, "LampShade", Vector3.new(2, 1.5, 2), 0, 5.2, 0, shade, FABRIC)
	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 14
	light.Color = rgb(255, 220, 170)
	light.Parent = top
end

local function cabinet(build: Build, x: number, z: number, turn: number, wood: Color3, width: number?)
	local at = spot(build, x, z, turn)
	local w = width or 5
	piece(build, at, "Cabinet", Vector3.new(w, 3, 1.8), 0, 0, 0, wood, WOOD)
	for k = 0, 1 do
		piece(
			build,
			at,
			"Drawer",
			Vector3.new(w - 0.6, 1.1, 0.1),
			0,
			0.3 + k * 1.3,
			0.92,
			wood:Lerp(rgb(255, 255, 255), 0.15),
			WOOD
		)
	end
end

local function armchair(build: Build, x: number, z: number, turn: number, color: Color3)
	sofa(build, x, z, turn, color, 4)
end

local function fireplace(build: Build, x: number, z: number, stone: Color3)
	local at = spot(build, x, z, 0)
	piece(build, at, "Fireplace", Vector3.new(9, 6, 2), 0, 0, 0, stone, Enum.Material.Cobblestone)
	piece(build, at, "Hearth", Vector3.new(5, 3.4, 0.4), 0, 0.4, -0.85, BLACK)
	piece(build, at, "Mantle", Vector3.new(10, 0.5, 2.6), 0, 6, 0, DARK_WOOD, WOOD)
	local logs = piece(build, at, "Logs", Vector3.new(3, 0.6, 0.6), 0, 0.5, -0.4, rgb(100, 60, 30), WOOD)
	Particles.keep(logs, "Fire", 18, rgb(255, 150, 40), 0.6)
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 18
	light.Color = rgb(255, 160, 80)
	light.Parent = logs
end

local function piano(build: Build, x: number, z: number, turn: number)
	local at = spot(build, x, z, turn)
	piece(build, at, "Piano", Vector3.new(6, 2.4, 5), 0, 1.4, 0, BLACK, Enum.Material.Glass)
	piece(build, at, "PianoKeys", Vector3.new(5, 0.3, 1), 0, 3.4, -2.4, rgb(250, 250, 250))
	for _, dx in { -2.4, 2.4 } do
		piece(build, at, "PianoLeg", Vector3.new(0.5, 1.4, 0.5), dx, 0, 1.8, BLACK)
	end
	piece(build, at, "PianoLeg", Vector3.new(0.5, 1.4, 0.5), 0, 0, -1.8, BLACK)
	piece(build, at, "Bench", Vector3.new(3.4, 1.6, 1.4), 0, 0, -4, BLACK)
end

local function bar(build: Build, x: number, z: number, turn: number, wood: Color3)
	local at = spot(build, x, z, turn)
	piece(build, at, "Bar", Vector3.new(2, 3.6, 12), 0, 0, 0, wood, WOOD)
	piece(build, at, "BarTop", Vector3.new(2.6, 0.3, 12.4), 0, 3.6, 0, BLACK, MARBLE)
	for k = -2, 2 do
		piece(build, at, "Stool", Vector3.new(1.4, 0.4, 1.4), -2.2, 2.4, k * 2.4, rgb(150, 30, 40), FABRIC)
		piece(build, at, "StoolLeg", Vector3.new(0.3, 2.4, 0.3), -2.2, 0, k * 2.4, BLACK, METAL)
	end
	local colors = { rgb(60, 150, 70), rgb(160, 60, 40), rgb(220, 190, 80) }
	for k = -3, 3 do
		local bottle = piece(
			build,
			at,
			"Bottle",
			Vector3.new(0.5, 1.4, 0.5),
			0.3,
			3.9,
			k * 1.3,
			colors[(k + 4) % 3 + 1],
			Enum.Material.Glass
		)
		bottle.Transparency = 0.2
	end
end

local function column(build: Build, x: number, z: number, color: Color3)
	local at = spot(build, x, z)
	piece(build, at, "ColumnBase", Vector3.new(3.4, 1, 3.4), 0, 0, 0, color, MARBLE)
	piece(build, at, "Column", Vector3.new(2.6, build.height - 2, 2.6), 0, 1, 0, color, MARBLE)
	piece(build, at, "ColumnTop", Vector3.new(3.6, 1, 3.6), 0, build.height - 1, 0, GOLD, METAL)
end

local function chandelier(build: Build, x: number, z: number)
	local at = spot(build, x, z)
	local h = build.height
	piece(build, at, "ChandelierChain", Vector3.new(0.3, 3, 0.3), 0, h - 3, 0, GOLD, METAL)
	local hub = piece(build, at, "Chandelier", Vector3.new(4, 1.2, 4), 0, h - 4.2, 0, GOLD, METAL)
	for k = 0, 5 do
		local angle = k / 6 * math.pi * 2
		local candle = piece(
			build,
			at,
			"Candle",
			Vector3.new(0.4, 0.9, 0.4),
			math.cos(angle) * 2.6,
			h - 3.6,
			math.sin(angle) * 2.6,
			rgb(255, 245, 200),
			NEON
		)
		candle.CanCollide = false
	end
	local light = Instance.new("PointLight")
	light.Brightness = 1.6
	light.Range = 40
	light.Color = rgb(255, 235, 200)
	light.Parent = hub
end

local function goldStack(build: Build, x: number, z: number, turn: number)
	local at = spot(build, x, z, turn)
	for row = 0, 2 do
		for k = 0, 2 - row do
			piece(
				build,
				at,
				"GoldBar",
				Vector3.new(1.8, 0.6, 0.9),
				(k - (2 - row) / 2) * 1.9,
				row * 0.6,
				0,
				GOLD,
				METAL
			)
		end
	end
end

local function vaultDoor(build: Build, z: number)
	local at = spot(build, 0, z, 0)
	local door = piece(build, at, "VaultDoor", Vector3.new(1, 14, 14), 0, 2, 0, rgb(170, 175, 185), METAL)
	door.Shape = Enum.PartType.Cylinder
	door.CFrame = at * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0)
	local hub = piece(build, at, "VaultHub", Vector3.new(1.2, 3, 3), 0, 7.5, -0.6, GOLD, METAL)
	hub.Shape = Enum.PartType.Cylinder
	hub.CFrame = at * CFrame.new(0, 9, -0.5) * CFrame.Angles(0, math.rad(90), 0)
	for k = 0, 2 do
		local spoke = piece(build, at, "VaultSpoke", Vector3.new(9, 0.5, 0.4), 0, 8.75, -0.9, GOLD, METAL)
		spoke.CFrame = at * CFrame.new(0, 9, -0.9) * CFrame.Angles(0, 0, math.rad(k * 60))
	end
end

-- A hazard stripe across the floor where the lasers start.
local function hazard(build: Build, z: number)
	local at = spot(build, 0, z)
	piece(build, at, "Hazard", Vector3.new(build.width, 0.06, 0.8), 0, 0, 0, rgb(250, 190, 30))
	for k = 0, math.floor(build.width / 3) - 1 do
		local stripe =
			piece(build, at, "HazardStripe", Vector3.new(1.2, 0.07, 0.8), -build.width / 2 + 1.5 + k * 3, 0, 0, BLACK)
		stripe.CanCollide = false
	end
end

-- Cash ------------------------------------------------------------------------------------

local CASH = rgb(130, 210, 70)
local BAND = rgb(245, 235, 190)

-- A little pile of bundles at (x, y, z) (y: what it sits on), in its own model. Returns its main
-- bundle.
local function pile(build: Build, x: number, y: number, z: number, turn: number?): BasePart
	local at = spot(build, x, z, turn) * CFrame.new(0, y, 0)
	local main = part(build, "Cash", Vector3.new(1.9, 0.5, 1), at * CFrame.new(0, 0.25, 0), CASH)
	local band = part(build, "CashBand", Vector3.new(0.5, 0.52, 1.02), at * CFrame.new(0, 0.25, 0), BAND)
	local top = part(
		build,
		"CashTop",
		Vector3.new(1.9, 0.5, 1),
		at * CFrame.new(0.15, 0.75, 0.05) * CFrame.Angles(0, math.rad(18), 0),
		CASH
	)
	local group = Instance.new("Model")
	group.Name = "CashPile"
	for _, p in { main, band, top } do
		p.CanCollide = false
		p.Parent = group
	end
	group.Parent = build.model
	local sparkle = Particles.keep(main, "Sparkles", 2, rgb(255, 245, 160), 0.4)
	sparkle.Name = "CashSparkle"
	return main
end

-- Lasers ----------------------------------------------------------------------------------

local function laserPart(build: Build, size: Vector3, cframe: CFrame): BasePart
	local beam = part(build, "Laser", size, cframe, LASER_RED, NEON)
	beam.Shape = Enum.PartType.Cylinder
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Transparency = 0.1
	CollectionService:AddTag(beam, LASER_TAG)
	local glow = part(build, "LaserGlow", Vector3.new(size.X, GLOW, GLOW), cframe, LASER_RED, NEON)
	glow.Shape = Enum.PartType.Cylinder
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CastShadow = false
	glow.Transparency = 0.8
	local weld = Instance.new("ObjectValue")
	weld.Name = "GlowPart"
	weld.Value = glow
	weld.Parent = beam
	return beam
end

local function emitter(build: Build, cframe: CFrame): BasePart
	local box = part(build, "LaserEmitter", Vector3.new(0.7, 0.7, 0.7), cframe, rgb(50, 52, 60), METAL)
	box.CanCollide = false
	box.CanQuery = false
	return box
end

-- A beam straight across the room at depth z, height y, from x0 to x1.
local function across(
	build: Build,
	z: number,
	y: number,
	x0: number,
	x1: number,
	lasers: { BasePart },
	sweep: { [string]: any }?
)
	local f = build.frame
	local length = x1 - x0
	local beam = laserPart(build, Vector3.new(length, BEAM, BEAM), f * CFrame.new((x0 + x1) / 2, y, z))
	table.insert(lasers, beam)
	local parts: { Instance } = { beam }
	local glow = beam:FindFirstChild("GlowPart")
	if glow and glow:IsA("ObjectValue") and glow.Value then
		table.insert(parts, glow.Value)
	end
	local half = build.width / 2
	for _, x in { x0, x1 } do
		if math.abs(math.abs(x) - half) < 0.01 then -- on a wall: a little box it shines from
			table.insert(parts, emitter(build, f * CFrame.new(x - math.sign(x) * 0.3, y, z)))
		end
	end
	if sweep then
		for _, p in parts do
			for key, value in sweep do
				p:SetAttribute(key, value)
			end
		end
	end
end

local function post(build: Build, x: number, z: number, lasers: { BasePart })
	local f = build.frame
	local h = build.height
	local beam =
		laserPart(build, Vector3.new(h, BEAM, BEAM), f * CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(90)))
	table.insert(lasers, beam)
	for _, y in { 0.2, h - 0.2 } do
		emitter(build, f * CFrame.new(x, y, z))
	end
end

-- One laser layout over the band from z0 to z1.
local function lasersIn(build: Build, layout: BreakInLasers.Layout, z0: number, z1: number, lasers: { BasePart })
	hazard(build, z0 - 0.6)
	local half = build.width / 2
	local depth = z1 - z0
	for _, beam in layout.beams do
		local z = z0 + beam.z * depth
		local heights: { number } = beam.y or { 2.7 }
		if beam.kind == "Wall" then
			for _, y in heights do
				across(build, z, y, -half, half, lasers)
			end
		elseif beam.kind == "Gap" then
			local middle = (beam.x or 0) * build.width
			local gap = (beam.gap or 6) / 2
			for _, y in heights do
				across(build, z, y, -half, middle - gap, lasers)
				across(build, z, y, middle + gap, half, lasers)
			end
		elseif beam.kind == "Post" then
			post(build, (beam.x or 0) * build.width, z, lasers)
		elseif beam.kind == "Sweep" then
			for _, y in heights do
				across(build, z, y, -half, half, lasers, {
					SweepDir = (build.frame.Rotation * Vector3.zAxis),
					SweepAmp = (beam.swing or 0.3) * depth,
					SweepPeriod = beam.period or 5,
					SweepPhase = beam.phase or 0,
				})
			end
		end
	end
end

-- Layouts ---------------------------------------------------------------------------------

-- Tiers 1 and 2: a hallway, the lasers, then the living room.
local function normal(build: Build, houseId: number, lasers: { BasePart }): { BasePart }
	local pal = build.palette
	shell(build, WOOD)
	local piles = {}
	-- Hallway: a coat rack, a shoe mat, a side table with a little cash on it.
	rug(build, 0, 4, 6, 4, pal.rug)
	cabinet(build, 14.5, 5, -90, DARK_WOOD, 4)
	table.insert(piles, pile(build, 14.5, 3, 5, 10))
	plant(build, -14.5, 6)
	ceilingLight(build, 0, 5, 30)
	lasersIn(build, BreakInLasers.forHouse(houseId), 10, 28, lasers)
	ceilingLight(build, 0, 19, 30)
	-- The living room.
	rug(build, 0, 37.5, 18, 12, pal.rug)
	sofa(build, 0, 33.2, 0, pal.sofa)
	coffeeTable(build, 0, 38.5, DARK_WOOD)
	table.insert(piles, pile(build, 0.4, 0.1, 38.5, -12)) -- under the coffee table
	tv(build, 0, 45, 180)
	table.insert(piles, pile(build, -6.4, 0, 45, 30)) -- beside the TV
	bookshelf(build, -16.2, 40, 90, DARK_WOOD)
	table.insert(piles, pile(build, -16.2, 7.45, 40, 90)) -- on top of the bookshelf
	cabinet(build, 15.5, 37, -90, pal.floor:Lerp(BLACK, 0.2))
	table.insert(piles, pile(build, 15.5, 3, 37, 80)) -- on the sideboard
	table.insert(piles, pile(build, 2.5, 0, 30.9, 0)) -- behind the sofa
	armchair(build, 11, 43, -140, pal.accent)
	lamp(build, -7, 33, pal.accent)
	plant(build, 14.5, 44.5)
	window(build, -1, 33)
	window(build, 1, 30)
	painting(build, 1, 42, 6, pal.accent)
	ceilingLight(build, 0, 38, 36)
	return piles
end

-- Tier 3: a bigger, darker lounge.
local function rich(build: Build, houseId: number, lasers: { BasePart }): { BasePart }
	local pal = build.palette
	shell(build, WOOD)
	local piles = {}
	plant(build, -19, 5, 1.2)
	plant(build, 19, 5, 1.2)
	cabinet(build, 19.5, 8.5, -90, DARK_WOOD, 4)
	table.insert(piles, pile(build, 19.5, 3, 8.5, 0))
	painting(build, -1, 6, 6, pal.sofa)
	ceilingLight(build, 0, 5, 34)
	lasersIn(build, BreakInLasers.forHouse(houseId), 11, 31, lasers)
	ceilingLight(build, 0, 21, 34)
	-- The lounge.
	rug(build, 0, 46, 22, 16, pal.rug)
	fireplace(build, 0, 56.9, rgb(150, 145, 140))
	table.insert(piles, pile(build, 3, 6.5, 56.6, 0)) -- on the mantle
	sofa(build, -7.5, 46, 90, pal.sofa)
	sofa(build, 7.5, 46, -90, pal.sofa)
	coffeeTable(build, 0, 46, DARK_WOOD)
	table.insert(piles, pile(build, -0.3, 0.1, 46, 20)) -- under the coffee table
	piano(build, -15, 37, 30)
	table.insert(piles, pile(build, -17, 1.6, 33.5, 30)) -- on the piano bench
	bar(build, 18.5, 46, 0, DARK_WOOD)
	table.insert(piles, pile(build, 20.6, 0, 43, 90)) -- behind the bar
	bookshelf(build, -21.2, 50, 90, DARK_WOOD)
	table.insert(piles, pile(build, -21.2, 7.45, 50, 90)) -- on top of the bookshelf
	armchair(build, -16, 55, 150, pal.accent)
	table.insert(piles, pile(build, -19.5, 0, 56.5, 40)) -- behind the armchair
	cabinet(build, 17, 56.9, 180, DARK_WOOD, 6)
	table.insert(piles, pile(build, 17, 3, 56.9, 0)) -- on the drinks cabinet
	lamp(build, 12, 55, pal.trim)
	painting(build, -1, 42, 7, pal.accent)
	painting(build, 1, 34, 7, pal.sofa)
	window(build, -1, 34)
	ceilingLight(build, 0, 40, 40)
	ceilingLight(build, 0, 52, 40)
	return piles
end

-- Mansions: the hall, lasers, a grand hall, more lasers, the vault.
local function mansion(build: Build, houseId: number, lasers: { BasePart }): { BasePart }
	local pal = build.palette
	shell(build, MARBLE)
	local piles = {}
	local w = build.width
	-- A red carpet runs the whole way in.
	rug(build, 0, 50, 8, 98, pal.rug)
	-- Entrance.
	plant(build, -28, 6, 1.4)
	plant(build, 28, 6, 1.4)
	cabinet(build, -29.5, 9, 90, DARK_WOOD, 4)
	cabinet(build, 29.5, 9, -90, DARK_WOOD, 4)
	table.insert(piles, pile(build, -29.5, 3, 9, 0))
	table.insert(piles, pile(build, 29.5, 3, 9, 0))
	ceilingLight(build, 0, 5, 40)
	lasersIn(build, BreakInLasers.forHouse(houseId), 12, 33, lasers)
	ceilingLight(build, -14, 22, 36)
	ceilingLight(build, 14, 22, 36)
	-- The grand hall.
	for _, z in { 37, 45, 53 } do
		column(build, -w / 2 + 6, z, pal.trim:Lerp(rgb(255, 255, 255), 0.6))
		column(build, w / 2 - 6, z, pal.trim:Lerp(rgb(255, 255, 255), 0.6))
	end
	chandelier(build, 0, 45)
	sofa(build, -18, 45, 90, pal.sofa)
	sofa(build, 18, 45, -90, pal.sofa)
	table.insert(piles, pile(build, -18.4, 1.6, 44, 90)) -- on a sofa
	table.insert(piles, pile(build, 18.4, 1.6, 46, -90))
	coffeeTable(build, -12, 45, DARK_WOOD)
	table.insert(piles, pile(build, -12, 0.1, 45, 10)) -- under the table
	table.insert(piles, pile(build, -w / 2 + 3, 0, 41, 0)) -- behind a column
	table.insert(piles, pile(build, w / 2 - 3, 0, 49, 0))
	painting(build, -1, 41, 8, pal.sofa)
	painting(build, 1, 49, 8, pal.sofa)
	lasersIn(build, BreakInLasers.forHouse(houseId, 5), 57, 77, lasers)
	ceilingLight(build, -14, 67, 36)
	ceilingLight(build, 14, 67, 36)
	-- The vault: gold, and cash everywhere.
	vaultDoor(build, 99.4)
	for _, info in { { -20, 84 }, { 20, 84 }, { -24, 94 }, { 24, 94 } } do
		goldStack(build, info[1], info[2], 15)
	end
	for _, info in
		{
			{ -12, 82 },
			{ 12, 82 },
			{ -6, 88 },
			{ 6, 88 },
			{ 0, 84 },
			{ -14, 95 },
			{ 14, 95 },
			{ -26, 88 },
			{ 26, 88 },
		}
	do
		cabinet(build, info[1], info[2], 180, rgb(120, 125, 135), 3)
		table.insert(piles, pile(build, info[1], 3, info[2], (info[1] * 7) % 40))
	end
	chandelier(build, 0, 88)
	ceilingLight(build, -18, 90, 40)
	ceilingLight(build, 18, 90, 40)
	return piles
end

-- Builds house `houseId`'s inside (its tier says which layout) with its door at `origin`.
function BreakInRooms.build(houseId: number, tier: number, origin: Vector3, parent: Instance): Room
	local model = Instance.new("Model")
	model.Name = `House{houseId}`
	local width, depth, height, palette, layout
	if tier >= 4 then
		width, depth, height = 64, 100, 22
		palette, layout = MANSION[houseId % #MANSION + 1], mansion
	elseif tier == 3 then
		width, depth, height = 44, 58, 16
		palette, layout = RICH[houseId % #RICH + 1], rich
	else
		width, depth, height = 34, 46, 13
		palette, layout = NORMAL[houseId % #NORMAL + 1], normal
	end
	local build: Build = {
		frame = CFrame.new(origin),
		model = model,
		width = width,
		depth = depth,
		height = height,
		palette = palette,
	}
	local lasers: { BasePart } = {}
	local piles = layout(build, houseId, lasers)
	local exit = exitDoor(build)
	model.WorldPivot = build.frame
	model.Parent = parent
	local spawnAt = build.frame * CFrame.new(0, 3, 3.5)
	return {
		model = model,
		spawn = CFrame.lookAt(spawnAt.Position, spawnAt.Position + build.frame.LookVector * -1),
		exit = exit,
		lasers = lasers,
		piles = piles,
	}
end

return BreakInRooms
