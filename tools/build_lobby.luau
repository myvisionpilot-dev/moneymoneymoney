-- Builds the Lobby: the grand hall of Penny National Bank. Run in the Lobby place (command bar
-- or MCP): require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_lobby)
-- Parts only, no scripts. Rebuilds Workspace.Map from scratch. The first time it runs, the old
-- lobby (grey floor, queue pads, Cred shop stand, kart pedestal) is moved to
-- ServerStorage.OldLobby with its tags taken off, so nothing hand-made is lost.
--
-- The hall: a checkered marble floor with a red carpet from the doors to the teller counter, a
-- row of marble columns each side, a coffered ceiling with a glowing laylight and two
-- chandeliers, tall windows, the teller counter with brass screens (Mr. Penny and two tellers
-- behind it), the vault door and the game's name on the back wall, a guard by the doors.
--
-- Tags the code looks for:
--   Leaderboard (+ Board "Cred" or "Quota")   the two boards on the side walls
--   StaffSpot (+ Staff)                        Penny, Teller1, Teller2, Guard (BankStaff)

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(script.Parent:WaitForChild("town").Kit)

-- The room, inside the walls.
local X0, X1 = -44, 44 -- side walls
local Z0, Z1 = -56, 48 -- the back wall (vault) and the front wall (doors)
local H = 30 -- floor to ceiling
local MID_Z = (Z0 + Z1) / 2
local COUNTER_Z = -38 -- the middle of the teller counter
local STAGE_TOP = 2 -- the raised floor behind the counter, so the tellers stand tall

local CREAM = Color3.fromRGB(238, 231, 214)
local GREEN = Color3.fromRGB(36, 82, 60)
local PLASTER = Color3.fromRGB(233, 223, 199)
local WOOD = Color3.fromRGB(92, 56, 34)
local WOOD_LIGHT = Color3.fromRGB(122, 78, 48)
local BRASS = Color3.fromRGB(214, 170, 72)
local STEEL = Color3.fromRGB(150, 154, 162)
local DARK_STEEL = Color3.fromRGB(70, 72, 80)
local VELVET = Color3.fromRGB(150, 22, 36)
local DAYLIGHT = Color3.fromRGB(176, 196, 214) -- frosted glass with the sun behind it
local WARM = Color3.fromRGB(255, 214, 150) -- bulbs and candles
local GOLD = Color3.fromRGB(240, 196, 60)

local M = Enum.Material

-- Move the old lobby out of the way, once.
if not ServerStorage:FindFirstChild("OldLobby") then
	local backup = Instance.new("Folder")
	backup.Name = "OldLobby"
	local old = {}
	for _, name in { "Map", "LobbyExtras" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(old, found)
		end
	end
	for _, pad in CollectionService:GetTagged("QueuePad") do
		if pad:IsDescendantOf(workspace) and not table.find(old, pad) then
			table.insert(old, pad)
		end
	end
	for _, thing in old do
		thing.Parent = backup
		for _, item in thing:GetDescendants() do
			for _, tag in item:GetTags() do
				item:RemoveTag(tag)
			end
		end
		for _, tag in thing:GetTags() do
			thing:RemoveTag(tag)
		end
	end
	backup.Parent = ServerStorage
end
local previous = workspace:FindFirstChild("Map")
if previous then
	previous:Destroy()
end

local map = Kit.folder(workspace, "Map")
local hall = Kit.folder(map, "Hall")
local counter = Kit.folder(map, "Counter")
local vault = Kit.folder(map, "Vault")
local props = Kit.folder(map, "Props")

local function part(parent, name, size, cframe, color, material)
	return Kit.part(parent, name, size, cframe, color, material)
end

-- Upright cylinder (Kit.cylinder), and one facing along Z (a disc on the back or front wall).
local function upright(parent, name, height, diameter, position, color, material)
	return Kit.cylinder(parent, name, height, diameter, position, color, material)
end
local function disc(parent, name, thickness, diameter, position, color, material)
	local p = part(
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(parent, name, diameter, position, color, material)
	local p = part(parent, name, Vector3.one * diameter, position, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function pointLight(target, range, brightness, color)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color or WARM
	light.Parent = target
	return light
end

-- On a wall: `at` is a point on its inside face at floor height, `inward` points into the room.
-- wallBox puts a box `x` along the wall and `y` up, from `from` to `from + depth` out of it.
local function onWall(at, inward)
	return CFrame.lookAt(at, at + inward)
end
local function wallBox(parent, name, cf, x, y, width, height, from, depth, color, material)
	return part(
		parent,
		name,
		Vector3.new(width, height, depth),
		cf * CFrame.new(x, y, -(from + depth / 2)),
		color,
		material
	)
end

------------------------------------------------------------------------------------------------
-- Floor, walls and ceiling

for i = 0, (X1 - X0) / 8 - 1 do
	for j = 0, (Z1 - Z0) / 8 - 1 do
		local tile = part(
			hall,
			"Floor",
			Vector3.new(8, 1, 8),
			Vector3.new(X0 + 4 + i * 8, -0.5, Z0 + 4 + j * 8),
			if (i + j) % 2 == 0 then CREAM else GREEN,
			M.Marble
		)
		tile.CanTouch = false
	end
end

local wallHeight = H + 1 -- from a stud under the floor up to the ceiling
for _, side in { -1, 1 } do
	Kit.quiet(
		part(
			hall,
			"Wall",
			Vector3.new(2, wallHeight, Z1 - Z0 + 4),
			Vector3.new(side * (X1 + 1), H / 2 - 0.5, MID_Z),
			PLASTER,
			M.Plaster
		)
	)
end
for _, z in { Z0 - 1, Z1 + 1 } do
	Kit.quiet(
		part(hall, "Wall", Vector3.new(X1 - X0, wallHeight, 2), Vector3.new(0, H / 2 - 0.5, z), PLASTER, M.Plaster)
	)
end
Kit.quiet(
	part(hall, "Ceiling", Vector3.new(X1 - X0 + 4, 1, Z1 - Z0 + 4), Vector3.new(0, H + 0.5, MID_Z), PLASTER, M.Plaster)
)

-- The four walls' faces, for everything that hangs on them: { cframe at the middle, length }.
local walls = {
	west = { cf = onWall(Vector3.new(X0, 0, MID_Z), Vector3.xAxis), length = Z1 - Z0 },
	east = { cf = onWall(Vector3.new(X1, 0, MID_Z), -Vector3.xAxis), length = Z1 - Z0 },
	back = { cf = onWall(Vector3.new(0, 0, Z0), Vector3.zAxis), length = X1 - X0 },
	front = { cf = onWall(Vector3.new(0, 0, Z1), -Vector3.zAxis), length = X1 - X0 },
}
-- Wood panelling to a chair rail, and a cornice under the ceiling: { name, middle height,
-- height, out from the wall, depth }. Along the side walls they run the full length; along the
-- front they stop at the side walls' panelling and either side of the doors. Behind the counter
-- the back wall only has the cornice (the vault and safe boxes cover it).
local TRIMS = {
	{ "Wainscot", 2.5, 5, 0, 0.4, WOOD_LIGHT, M.Wood },
	{ "Skirting", 0.4, 0.8, 0.4, 0.2, WOOD, M.Wood },
	{ "ChairRail", 5.2, 0.4, 0, 0.6, WOOD, M.Wood },
	{ "Cornice", H - 0.6, 1.2, 0, 1.2, PLASTER, M.Plaster },
}
local DOOR_HALF = 7 -- half the door surround's width
for name, wall in walls do
	for _, trim in TRIMS do
		local inset = trim[4] + trim[5] -- where the side wall's matching trim stands out to
		local spans = { { -wall.length / 2, wall.length / 2 } }
		if name == "front" and trim[1] ~= "Cornice" then
			spans = { { -wall.length / 2 + inset, -DOOR_HALF }, { DOOR_HALF, wall.length / 2 - inset } }
		elseif name == "front" or name == "back" then
			spans = if trim[1] == "Cornice" then { { -wall.length / 2 + inset, wall.length / 2 - inset } } else {}
		elseif trim[1] == "Skirting" then
			-- It stops at the front wall's panelling (the west wall runs towards +Z, the east -Z).
			local stop = 0.4
			spans = if name == "west"
				then { { -wall.length / 2, wall.length / 2 - stop } }
				else { { -wall.length / 2 + stop, wall.length / 2 } }
		end
		for _, span in spans do
			Kit.quiet(
				wallBox(
					hall,
					trim[1],
					wall.cf,
					(span[1] + span[2]) / 2,
					trim[2],
					span[2] - span[1],
					trim[3],
					trim[4],
					trim[5],
					trim[6],
					trim[7]
				)
			)
		end
	end
end

-- Coffered ceiling: a grid of beams, and a glowing laylight in the middle of the hall.
for x = X0 + 8, X1 - 8, 8 do
	Kit.decor(part(hall, "Beam", Vector3.new(0.8, 1.2, Z1 - Z0), Vector3.new(x, H - 0.6, MID_Z), PLASTER, M.Plaster))
end
for z = Z0 + 8, Z1 - 8, 8 do
	Kit.decor(part(hall, "Beam", Vector3.new(X1 - X0, 1.2, 0.8), Vector3.new(0, H - 0.6, z), PLASTER, M.Plaster))
end
local laylight = Kit.decor(
	part(hall, "Laylight", Vector3.new(32, 0.6, 32), Vector3.new(0, H + 0.1, 4), Color3.fromRGB(226, 212, 184), M.Neon)
)
local skyLight = Instance.new("SurfaceLight")
skyLight.Face = Enum.NormalId.Bottom
skyLight.Range = 40
skyLight.Angle = 90
skyLight.Brightness = 1.6
skyLight.Color = Color3.fromRGB(255, 240, 215)
skyLight.Parent = laylight

------------------------------------------------------------------------------------------------
-- Side walls: windows, pilasters with lamps, and the leaderboards

local function window(cf)
	local width, height, bottom = 7, 13, 7
	local glass =
		Kit.decor(wallBox(hall, "WindowGlass", cf, 0, bottom + height / 2, width, height, 0, 0.2, DAYLIGHT, M.Neon))
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Range = 22
	light.Angle = 80
	light.Brightness = 1.1
	light.Color = Color3.fromRGB(255, 246, 228)
	light.Parent = glass
	local frame = {
		{ "WindowHead", 0, bottom + height + 0.4, width + 1.4, 0.8, 0.6 },
		{ "WindowSide", -(width / 2 + 0.35), bottom + height / 2, 0.7, height, 0.6 },
		{ "WindowSide", width / 2 + 0.35, bottom + height / 2, 0.7, height, 0.6 },
	}
	for _, info in frame do
		Kit.decor(wallBox(hall, info[1], cf, info[2], info[3], info[4], info[5], 0, info[6], WOOD, M.Wood))
	end
	-- Glazing bars sit on the glass.
	Kit.decor(wallBox(hall, "Mullion", cf, 0, bottom + height / 2, 0.3, height, 0.2, 0.25, WOOD, M.Wood))
	for _, y in { bottom + height * 0.36, bottom + height * 0.7 } do
		Kit.decor(wallBox(hall, "Transom", cf, 0, y, width, 0.3, 0.2, 0.2, WOOD, M.Wood))
	end
	Kit.decor(wallBox(hall, "WindowSill", cf, 0, bottom - 0.25, width + 2, 0.5, 0, 1.2, CREAM, M.Marble))
	Kit.decor(wallBox(hall, "Keystone", cf, 0, bottom + height + 1.5, 1.6, 1.4, 0, 0.7, CREAM, M.Marble))
end

-- A flat marble column on the wall with a brass lamp on it.
local function pilaster(cf)
	local top, bottom = H - 1.2, 5.4
	Kit.quiet(wallBox(hall, "Pilaster", cf, 0, (top + bottom) / 2, 2.4, top - bottom, 0, 0.6, CREAM, M.Marble))
	Kit.decor(wallBox(hall, "SconcePlate", cf, 0, 12, 0.8, 1.2, 0.6, 0.2, BRASS, M.Metal))
	Kit.decor(wallBox(hall, "SconceArm", cf, 0, 12, 0.2, 0.2, 0.8, 0.8, BRASS, M.Metal))
	local bulb = Kit.decor(ball(hall, "SconceBulb", 0.7, (cf * CFrame.new(0, 12.45, -1.6)).Position, WARM, M.Neon))
	pointLight(bulb, 16, 0.9)
end

for _, side in { "west", "east" } do
	local inward = if side == "west" then Vector3.xAxis else -Vector3.xAxis
	local x = if side == "west" then X0 else X1
	for _, z in { -48, -26, 18, 38 } do
		window(onWall(Vector3.new(x, 0, z), inward))
	end
	for _, z in { -15, 7, 28 } do
		pilaster(onWall(Vector3.new(x, 0, z), inward))
	end
	-- A leaderboard in a brass frame between the pilasters.
	local cf = onWall(Vector3.new(x, 0, -4), inward)
	Kit.decor(wallBox(hall, "BoardFrame", cf, 0, 14.5, 13, 15, 0, 0.4, BRASS, M.Metal))
	local board = Kit.quiet(
		wallBox(hall, "Leaderboard", cf, 0, 14.5, 12, 14, 0.4, 0.6, Color3.fromRGB(22, 28, 24), M.SmoothPlastic)
	)
	board:SetAttribute("Board", if side == "west" then "Cred" else "Quota")
	Kit.tag(board, "Leaderboard")
end

------------------------------------------------------------------------------------------------
-- Columns down both sides of the hall

for _, x in { -24, 24 } do
	for _, z in { -15, 7, 28 } do
		Kit.quiet(part(hall, "ColumnPlinth", Vector3.new(4.4, 1, 4.4), Vector3.new(x, 0.5, z), CREAM, M.Marble))
		Kit.quiet(upright(hall, "ColumnBase", 0.8, 4, Vector3.new(x, 1.4, z), BRASS, M.Metal))
		Kit.quiet(upright(hall, "ColumnShaft", 25, 3.2, Vector3.new(x, 14.3, z), CREAM, M.Marble))
		Kit.quiet(upright(hall, "ColumnRing", 0.6, 3.8, Vector3.new(x, 27.1, z), BRASS, M.Metal))
		Kit.quiet(part(hall, "ColumnCapital", Vector3.new(4.6, 3, 4.6), Vector3.new(x, 28.9, z), CREAM, M.Marble))
	end
end

-- Two chandeliers along the middle: brass arms with candle bulbs round a hanging rod.
for _, z in { -22, 32 } do
	local hub = Vector3.new(0, 22.5, z)
	Kit.decor(upright(hall, "ChandelierRod", H - 23.1, 0.3, Vector3.new(0, (H + 23.9) / 2, z), BRASS, M.Metal))
	Kit.decor(upright(hall, "ChandelierCrown", 0.6, 2.2, Vector3.new(0, 25.8, z), BRASS, M.Metal))
	local core = Kit.decor(ball(hall, "ChandelierHub", 1.8, hub, BRASS, M.Metal))
	pointLight(core, 48, 1.4)
	Kit.decor(ball(hall, "ChandelierDrop", 0.8, hub - Vector3.new(0, 1.4, 0), BRASS, M.Metal))
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Kit.decor(
			part(
				hall,
				"ChandelierArm",
				Vector3.new(0.2, 0.2, 3.6),
				CFrame.lookAt(hub + out * 2.2, hub + out * 4),
				BRASS,
				M.Metal
			)
		)
		local tip = hub + out * 4
		Kit.decor(upright(hall, "CandleCup", 0.4, 0.7, tip + Vector3.new(0, 0.2, 0), BRASS, M.Metal))
		Kit.decor(upright(hall, "Candle", 0.8, 0.3, tip + Vector3.new(0, 0.8, 0), CREAM, M.SmoothPlastic))
		Kit.decor(ball(hall, "Flame", 0.45, tip + Vector3.new(0, 1.35, 0), WARM, M.Neon))
	end
end

------------------------------------------------------------------------------------------------
-- The teller counter, wall to wall, with brass screens over the five teller windows

local counterFront = COUNTER_Z + 1.5
Kit.quiet(
	part(counter, "Plinth", Vector3.new(X1 - X0 - 1.4, 0.6, 3.6), Vector3.new(0, 0.3, COUNTER_Z), GREEN, M.Marble)
)
part(counter, "CounterBody", Vector3.new(X1 - X0 - 0.8, 3.5, 3), Vector3.new(0, 2.35, COUNTER_Z), WOOD, M.Wood)
Kit.quiet(
	part(counter, "CounterTop", Vector3.new(X1 - X0 - 0.8, 0.4, 3.8), Vector3.new(0, 4.3, COUNTER_Z), CREAM, M.Marble)
)
local panels = 14
local panelStep = (X1 - X0) / panels
for index = 0, panels - 1 do
	Kit.decor(
		part(
			counter,
			"CounterPanel",
			Vector3.new(panelStep - 1, 2.4, 0.25),
			Vector3.new(X0 + panelStep * (index + 0.5), 2.35, counterFront + 0.125),
			WOOD_LIGHT,
			M.Wood
		)
	)
end
-- Behind the counter the floor is a step up, so the tellers stand tall.
Kit.quiet(
	part(
		counter,
		"TellerStage",
		Vector3.new(X1 - X0 - 1.2, STAGE_TOP, COUNTER_Z - 1.5 - Z0),
		Vector3.new(0, STAGE_TOP / 2, (Z0 + COUNTER_Z - 1.5) / 2),
		Color3.fromRGB(110, 70, 44),
		M.WoodPlanks
	)
)

local screenZ = COUNTER_Z - 0.6
local bay = 13.6
local SIGNS = { "DEPOSITS", "LOANS", "MR. PENNY", "WITHDRAWALS", "SAFE BOXES" }
for index = 0, 5 do
	Kit.quiet(
		part(
			counter,
			"ScreenPost",
			Vector3.new(0.6, 7, 0.6),
			Vector3.new(-34 + index * bay, 8, screenZ),
			BRASS,
			M.Metal
		)
	)
end
Kit.quiet(part(counter, "ScreenRail", Vector3.new(68.6, 0.6, 0.8), Vector3.new(0, 11.8, screenZ), BRASS, M.Metal))
for index = 1, 5 do
	local x = -34 + (index - 0.5) * bay
	local glass = Kit.decor(
		part(
			counter,
			"ScreenGlass",
			Vector3.new(12.6, 4.4, 0.15),
			Vector3.new(x, 9.3, screenZ),
			Color3.fromRGB(200, 225, 235),
			M.Glass
		)
	)
	glass.Transparency = 0.7
	for bar = 1, 6 do
		Kit.decor(
			part(
				counter,
				"ScreenBar",
				Vector3.new(0.15, 4.4, 0.15),
				Vector3.new(x - 6.3 + bar * 1.8, 9.3, screenZ + 0.2),
				BRASS,
				M.Metal
			)
		)
	end
	local plate = Kit.decor(
		part(counter, "WindowSign", Vector3.new(12.4, 1.6, 0.3), Vector3.new(x, 12.9, screenZ), GREEN, M.SmoothPlastic)
	)
	Kit.sign(plate, Enum.NormalId.Back, SIGNS[index], GREEN, GOLD, Enum.Font.Garamond)
	-- A brass bell and a stack of slips at each window.
	Kit.decor(upright(counter, "BellBase", 0.15, 0.7, Vector3.new(x + 3.5, 4.575, COUNTER_Z + 0.8), WOOD, M.Wood))
	Kit.decor(ball(counter, "Bell", 0.55, Vector3.new(x + 3.5, 4.85, COUNTER_Z + 0.8), BRASS, M.Metal))
	Kit.decor(
		part(
			counter,
			"Slips",
			Vector3.new(1, 0.12, 1.3),
			Vector3.new(x - 3.5, 4.56, COUNTER_Z + 0.6),
			Color3.fromRGB(245, 245, 235)
		)
	)
end

-- Mr. Penny in the middle window, a teller either side, and the guard by the doors.
for _, info in { { "Penny", 0 }, { "Teller1", -bay }, { "Teller2", bay } } do
	local at = Vector3.new(info[2], STAGE_TOP + 0.5, COUNTER_Z - 3)
	local spot = Kit.marker(counter, `{info[1]}Spot`, CFrame.lookAt(at, at + Vector3.zAxis), "StaffSpot")
	spot:SetAttribute("Staff", info[1])
end
local guardAt = Vector3.new(10, 0.5, Z1 - 4)
local guard = Kit.marker(hall, "GuardSpot", CFrame.lookAt(guardAt, guardAt - Vector3.zAxis), "StaffSpot")
guard:SetAttribute("Staff", "Guard")

-- The velvet rope lane up to Mr. Penny's window.
local postTops = {}
for _, x in { -6, 6 } do
	local tops = {}
	for _, z in { -34, -28, -22 } do
		Kit.decor(upright(props, "PostBase", 0.2, 1.4, Vector3.new(x, 0.1, z), BRASS, M.Metal))
		Kit.quiet(upright(props, "Post", 3, 0.3, Vector3.new(x, 1.7, z), BRASS, M.Metal))
		local top = Kit.decor(ball(props, "PostTop", 0.6, Vector3.new(x, 3.4, z), BRASS, M.Metal))
		table.insert(tops, top)
	end
	table.insert(postTops, tops)
end
for _, tops in postTops do
	for index = 1, #tops - 1 do
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Parent = tops[index]
		b.Parent = tops[index + 1]
		local rope = Instance.new("RopeConstraint")
		rope.Attachment0 = a
		rope.Attachment1 = b
		rope.Length = (tops[index].Position - tops[index + 1].Position).Magnitude * 1.08
		rope.Visible = true
		rope.Thickness = 0.22
		rope.Color = BrickColor.new(VELVET)
		rope.Parent = tops[index]
	end
end

------------------------------------------------------------------------------------------------
-- The back wall: the vault door, the bank's name, safe deposit boxes, gold and cash

local back = walls.back.cf
local vaultY = 12
-- Layers out from the wall (studs): surround 0-0.8, ring -1.6, door -2.6, its ring and bolts
-- -2.9/-3.0, hub -3.5, wheel -3.9.
Kit.quiet(
	wallBox(
		vault,
		"VaultSurround",
		back,
		0,
		(STAGE_TOP + 23) / 2,
		22,
		23 - STAGE_TOP,
		0,
		0.8,
		DARK_STEEL,
		M.DiamondPlate
	)
)
Kit.quiet(disc(vault, "VaultRing", 0.8, 20.4, Vector3.new(0, vaultY, Z0 + 1.2), Color3.fromRGB(95, 98, 108), M.Metal))
local door = Kit.quiet(disc(vault, "VaultDoor", 1, 18.5, Vector3.new(0, vaultY, Z0 + 2.1), STEEL, M.Metal))
door.Reflectance = 0.15
Kit.decor(
	disc(vault, "VaultDoorRing", 0.3, 14, Vector3.new(0, vaultY, Z0 + 2.75), Color3.fromRGB(125, 128, 138), M.Metal)
)
Kit.decor(disc(vault, "VaultHub", 0.6, 4, Vector3.new(0, vaultY, Z0 + 3.2), BRASS, M.Metal))
for index = 0, 2 do
	local spoke = Kit.decor(
		part(
			vault,
			"VaultSpoke",
			Vector3.new(12, 0.6, 0.4),
			CFrame.new(0, vaultY, Z0 + 3.7) * CFrame.Angles(0, 0, math.rad(index * 60)),
			BRASS,
			M.Metal
		)
	)
	spoke.Reflectance = 0.1
end
for index = 0, 5 do
	local angle = index / 6 * math.pi * 2
	Kit.decor(
		ball(
			vault,
			"SpokeKnob",
			1,
			Vector3.new(math.cos(angle) * 6, vaultY + math.sin(angle) * 6, Z0 + 3.7),
			BRASS,
			M.Metal
		)
	)
end
for index = 0, 15 do
	local angle = index / 16 * math.pi * 2
	Kit.decor(
		disc(
			vault,
			"VaultBolt",
			0.4,
			0.9,
			Vector3.new(math.cos(angle) * 8.2, vaultY + math.sin(angle) * 8.2, Z0 + 2.85),
			DARK_STEEL,
			M.Metal
		)
	)
end
for _, dy in { -5, 5 } do
	Kit.decor(upright(vault, "VaultHinge", 3, 1.6, Vector3.new(10.4, vaultY + dy, Z0 + 2.1), DARK_STEEL, M.Metal))
end

-- The game's name over the vault.
Kit.decor(wallBox(vault, "TitleFrame", back, 0, 25.9, 46.8, 5.4, 0, 0.3, BRASS, M.Metal))
local title = Kit.decor(wallBox(vault, "Title", back, 0, 25.9, 46, 4.6, 0.3, 0.3, GREEN, M.SmoothPlastic))
local titleGui = Instance.new("SurfaceGui")
titleGui.Face = Enum.NormalId.Front
titleGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
titleGui.PixelsPerStud = 30
titleGui.LightInfluence = 0.2
for _, info in
	{
		{ "MONEY MONEY MONEY", Enum.Font.Arial, 0.04, 0.62, GOLD }, -- Arial: picked by hand in Studio
		{ "PENNY NATIONAL BANK  -  EST. 1926", Enum.Font.Garamond, 0.66, 0.28, CREAM },
	}
do
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.03, info[3])
	label.Size = UDim2.fromScale(0.94, info[4])
	label.Font = info[2]
	label.TextScaled = true
	label.TextColor3 = info[5]
	label.Text = info[1]
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(14, 36, 26)
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = titleGui
end
titleGui.Parent = title

-- Safe deposit boxes either side of the vault: a steel panel drawn with little doors.
for _, x in { -24, 24 } do
	local wall = Kit.quiet(wallBox(vault, "SafeBoxes", back, x, STAGE_TOP + 7, 18, 14, 0, 0.7, STEEL, M.Metal))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.1, -4, 0.125, -4)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.Parent = gui
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 4)
	end
	padding.Parent = gui
	for _ = 1, 80 do
		local box = Instance.new("Frame")
		box.BackgroundColor3 = Color3.fromRGB(176, 180, 188)
		box.BorderSizePixel = 0
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(90, 94, 104)
		edge.Thickness = 2
		edge.Parent = box
		local keyhole = Instance.new("Frame")
		keyhole.AnchorPoint = Vector2.new(0.5, 0.5)
		keyhole.Position = UDim2.fromScale(0.5, 0.5)
		keyhole.Size = UDim2.fromOffset(8, 8)
		keyhole.BackgroundColor3 = BRASS
		keyhole.BorderSizePixel = 0
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = keyhole
		keyhole.Parent = box
		box.Parent = gui
	end
	gui.Parent = wall
end

-- Stacks of gold bars by the vault, and two carts of cash.
for _, side in { -1, 1 } do
	local base = Vector3.new(side * 15, STAGE_TOP, Z0 + 3)
	for layer = 0, 3 do
		for index = 0, 3 - layer do
			local bar = Kit.decor(
				part(
					props,
					"GoldBar",
					Vector3.new(1.6, 0.5, 0.8),
					base + Vector3.new((index - (3 - layer) / 2) * 1.7, 0.25 + layer * 0.5, 0),
					GOLD,
					M.Metal
				)
			)
			bar.Reflectance = 0.25
		end
	end
	local cart = Vector3.new(side * 24, STAGE_TOP, Z0 + 7)
	Kit.decor(part(props, "CartShelf", Vector3.new(3.2, 0.3, 2), cart + Vector3.new(0, 1.2, 0), BRASS, M.Metal))
	Kit.decor(part(props, "CartShelf", Vector3.new(3.2, 0.3, 2), cart + Vector3.new(0, 2.6, 0), BRASS, M.Metal))
	for _, corner in
		{
			Vector3.new(-1.45, 0, -0.85),
			Vector3.new(1.45, 0, -0.85),
			Vector3.new(-1.45, 0, 0.85),
			Vector3.new(1.45, 0, 0.85),
		}
	do
		Kit.decor(
			part(
				props,
				"CartLeg",
				Vector3.new(0.2, 2.75, 0.2),
				cart + corner + Vector3.new(0, 1.625, 0),
				BRASS,
				M.Metal
			)
		)
		Kit.decor(ball(props, "CartWheel", 0.5, cart + corner + Vector3.new(0, 0.25, 0), DARK_STEEL, M.Metal))
	end
	for row = 0, 1 do
		for column = 0, 2 do
			Kit.decor(
				part(
					props,
					"CashBundle",
					Vector3.new(0.9, 0.9, 0.8),
					cart + Vector3.new(-1 + column * 1, 3.2, -0.45 + row * 0.9),
					Color3.fromRGB(110, 170, 100),
					M.SmoothPlastic
				)
			)
		end
	end
end

------------------------------------------------------------------------------------------------
-- The front: doors, a clock and two cameras

local front = walls.front.cf
Kit.quiet(wallBox(hall, "DoorSurround", front, 0, 8, 14, 16, 0, 0.7, WOOD, M.Wood))
for _, side in { -1, 1 } do
	Kit.quiet(wallBox(hall, "DoorLeaf", front, side * 3.05, 7, 6, 14, 0.7, 0.4, WOOD_LIGHT, M.Wood))
	Kit.decor(wallBox(hall, "DoorGlass", front, side * 3.05, 8.5, 4, 9, 1.1, 0.2, DAYLIGHT, M.Neon))
	Kit.decor(wallBox(hall, "PushBar", front, side * 3.05, 6, 3, 0.3, 1.3, 0.3, BRASS, M.Metal))
end
Kit.decor(disc(hall, "Fanlight", 0.45, 12, Vector3.new(0, 16, Z1 - 0.425), DAYLIGHT, M.Neon))
for _, x in { -26, 26 } do
	window(onWall(Vector3.new(x, 0, Z1), -Vector3.zAxis))
end
for _, x in { -36, -14, 14, 36 } do
	pilaster(onWall(Vector3.new(x, 0, Z1), -Vector3.zAxis))
end
-- A clock over the doors, at ten past ten.
local clockY = 25
Kit.decor(disc(hall, "ClockRim", 0.3, 5.6, Vector3.new(0, clockY, Z1 - 0.15), BRASS, M.Metal))
Kit.decor(
	disc(hall, "ClockFace", 0.4, 5, Vector3.new(0, clockY, Z1 - 0.3), Color3.fromRGB(250, 248, 238), M.SmoothPlastic)
)
for _, hand in { { 1.8, 60 }, { 1.3, -60 } } do
	local length = hand[1]
	local angle = math.rad(hand[2])
	Kit.decor(
		part(
			hall,
			"ClockHand",
			Vector3.new(0.25, length, 0.1),
			CFrame.new(0, clockY, Z1 - 0.55) * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, 0),
			Color3.fromRGB(30, 30, 34)
		)
	)
end
for _, side in { -1, 1 } do
	local mount = Vector3.new(side * (X1 - 1.5), 26, Z1 - 1.5)
	Kit.decor(part(hall, "CameraMount", Vector3.new(0.4, 1, 0.4), mount + Vector3.new(0, 0.5, 0), DARK_STEEL, M.Metal))
	Kit.decor(
		part(
			hall,
			"Camera",
			Vector3.new(0.9, 0.9, 1.8),
			CFrame.lookAt(mount, Vector3.new(0, 4, 0)),
			Color3.fromRGB(235, 235, 235)
		)
	)
end

------------------------------------------------------------------------------------------------
-- The hall: a red carpet, the bank's seal where you appear, desks, benches and palms

Kit.quiet(
	part(
		props,
		"Carpet",
		Vector3.new(10, 0.12, Z1 - 2 - (counterFront + 2)),
		Vector3.new(0, 0.06, (Z1 - 2 + counterFront + 2) / 2),
		VELVET,
		M.Carpet
	)
)
for _, side in { -1, 1 } do
	Kit.decor(
		part(
			props,
			"CarpetTrim",
			Vector3.new(0.5, 0.14, Z1 - 2 - (counterFront + 2)),
			Vector3.new(side * 5.25, 0.07, (Z1 - 2 + counterFront + 2) / 2),
			GOLD,
			M.Fabric
		)
	)
end

local sealAt = Vector3.new(0, 0, 22)
Kit.decor(upright(props, "SealRing", 0.24, 14, sealAt + Vector3.new(0, 0.12, 0), BRASS, M.Metal))
local seal = Kit.decor(upright(props, "Seal", 0.3, 12.4, sealAt + Vector3.new(0, 0.15, 0), GREEN, M.Marble))
-- Turned so the $ reads the right way up from the doors.
seal.CFrame = CFrame.new(seal.Position) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(0, 0, math.rad(90))
local sealGui = Instance.new("SurfaceGui")
sealGui.Face = Enum.NormalId.Right -- an upright cylinder's top
sealGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sealGui.PixelsPerStud = 25
local sign = Instance.new("TextLabel")
sign.BackgroundTransparency = 1
sign.Size = UDim2.fromScale(1, 1)
sign.Font = Enum.Font.LuckiestGuy
sign.TextScaled = true
sign.TextColor3 = GOLD
sign.Text = "$"
local signPadding = Instance.new("UIPadding")
signPadding.PaddingTop = UDim.new(0.1, 0)
signPadding.PaddingBottom = UDim.new(0.1, 0)
signPadding.Parent = sign
sign.Parent = sealGui
sealGui.Parent = seal

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 0.2, 8)
spawn.Position = sealAt + Vector3.new(0, 0.5, 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanQuery = false
spawn.Neutral = true
spawn.Duration = 0
local decal = spawn:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end
spawn.Parent = map

-- Writing desks with green banker's lamps.
for _, x in { -14, 14 } do
	local at = Vector3.new(x, 0, 2)
	Kit.quiet(part(props, "DeskBase", Vector3.new(5, 3.4, 2), at + Vector3.new(0, 1.7, 0), WOOD, M.Wood))
	Kit.quiet(part(props, "DeskTop", Vector3.new(7, 0.3, 3), at + Vector3.new(0, 3.55, 0), CREAM, M.Marble))
	Kit.decor(upright(props, "LampBase", 0.15, 0.8, at + Vector3.new(0, 3.775, -0.6), BRASS, M.Metal))
	Kit.decor(part(props, "LampStem", Vector3.new(0.12, 0.9, 0.12), at + Vector3.new(0, 4.3, -0.6), BRASS, M.Metal))
	local shade = Kit.decor(
		part(
			props,
			"LampShade",
			Vector3.new(1.6, 0.6, 0.6),
			at + Vector3.new(0, 4.9, -0.6),
			Color3.fromRGB(30, 120, 70),
			M.Glass
		)
	)
	shade.Shape = Enum.PartType.Cylinder
	shade.Transparency = 0.1
	pointLight(shade, 9, 1.2)
	for index, offset in { -2.2, 2.2 } do
		Kit.decor(
			part(
				props,
				"Slip",
				Vector3.new(0.9, 0.05, 1.2),
				CFrame.new(at + Vector3.new(offset, 3.725, 0.4)) * CFrame.Angles(0, math.rad(index * 9 - 14), 0),
				Color3.fromRGB(245, 245, 235)
			)
		)
	end
end

-- Benches under the windows, backs to the wall.
for _, side in { -1, 1 } do
	for _, z in { -26, 18 } do
		local x = side * (X1 - 4)
		Kit.quiet(part(props, "BenchSeat", Vector3.new(2.2, 0.4, 8), Vector3.new(x, 1.9, z), VELVET, M.Leather))
		Kit.quiet(part(props, "BenchFrame", Vector3.new(2.2, 0.3, 8), Vector3.new(x, 1.55, z), WOOD, M.Wood))
		for _, dz in { -3.6, 3.6 } do
			Kit.quiet(part(props, "BenchEnd", Vector3.new(2.2, 1.4, 0.4), Vector3.new(x, 0.7, z + dz), WOOD, M.Wood))
		end
		Kit.quiet(part(props, "BenchBack", Vector3.new(0.4, 2.4, 8), Vector3.new(x + side * 1.3, 3.1, z), WOOD, M.Wood))
	end
end

-- Potted palms in the corners.
for _, at in { Vector3.new(-39, 0, 44), Vector3.new(39, 0, 44), Vector3.new(-39, 0, -33), Vector3.new(39, 0, -33) } do
	Kit.quiet(upright(props, "Pot", 2.4, 2.6, at + Vector3.new(0, 1.2, 0), BRASS, M.Metal))
	Kit.decor(upright(props, "Soil", 0.1, 2.3, at + Vector3.new(0, 2.45, 0), Color3.fromRGB(70, 50, 35), M.Ground))
	Kit.decor(upright(props, "Trunk", 5, 0.5, at + Vector3.new(0, 5, 0), Kit.Colors.Trunk, M.Wood))
	local top = at + Vector3.new(0, 7.5, 0)
	for index = 0, 6 do
		local angle = index / 7 * math.pi * 2
		Kit.decor(
			part(
				props,
				"Frond",
				Vector3.new(1.2, 0.15, 4.5),
				CFrame.new(top)
					* CFrame.Angles(0, angle, 0)
					* CFrame.Angles(math.rad(-28), 0, 0)
					* CFrame.new(0, 0, -2.1),
				Color3.fromRGB(56, 130, 60),
				M.LeafyGrass
			)
		)
	end
end

local count = 0
for _, item in map:GetDescendants() do
	if item:IsA("BasePart") then
		count += 1
	end
end
return `Lobby built: Penny National Bank, {count} parts`
