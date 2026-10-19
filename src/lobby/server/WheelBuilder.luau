--!strict
-- Builds the Lucky Wheel in the bank hall (where Config.Wheel says), parts only, no scripts:
--   Spinner   the part that turns (clients turn it: client/WheelController): a pie slice per
--             Config.Wheel slice with its prize written on it, a gold rim with pegs between the
--             slices and light bulbs round it, a hub.
--   the rest  a stand on a round rug, a pointer at the top, a LUCKY WHEEL marquee with bulbs,
--             a board of the odds beside it, the SpinsSign (each client writes your spins on it)
--             and SpinSpot, which holds the Spin prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Studs = require(ReplicatedStorage.Shared.Studs)
local Wheel = require(ReplicatedStorage.Shared.Wheel)

local GOLD = Color3.fromRGB(255, 200, 60)
local DARK_GOLD = Color3.fromRGB(190, 130, 30)
local DEEP = Color3.fromRGB(70, 25, 90)
local RED = Color3.fromRGB(200, 35, 45)
local INK = Color3.fromRGB(20, 16, 28)
local BULB_COUNT = 16
local SIGN_BULBS = 22
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local WheelBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	Studs.dress(p)
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	Studs.dress(p)
	p.Parent = parent
	return p
end

-- A cylinder lying along `axis` (Roblox cylinders lie along X).
local function disc(
	parent: Instance,
	name: string,
	length: number,
	across: number,
	at: Vector3,
	axis: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local side = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local up = side:Cross(axis).Unit
	local p = part(parent, name, Vector3.new(length, across, across), CFrame.fromMatrix(at, axis, up), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(
	parent: Instance,
	name: string,
	size: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(parent, name, Vector3.one * size, CFrame.new(at), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A right triangle with its square corner at `corner`, one side `along` (length `a`) and the
-- other `toward` (length `b`), `thick` deep along `axis`: half of a pie slice or the pointer.
local function triangle(
	parent: Instance,
	name: string,
	frame: CFrame,
	corner: Vector3,
	along: Vector3,
	a: number,
	toward: Vector3,
	b: number,
	thick: number,
	color: Color3
): WedgePart
	-- A WedgePart's square corner is at local (-Y/2, +Z/2); its sides run up +Y and along -Z.
	local y = along.Unit
	local z = -toward.Unit
	local x = y:Cross(z)
	local centre = corner + y * (a / 2) - z * (b / 2)
	return wedge(parent, name, Vector3.new(thick, a, b), frame * CFrame.fromMatrix(centre, x, y, z), color)
end

local function surface(target: BasePart, face: Enum.NormalId, pixels: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
	for key, value in props do
		(label :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A slice: two right triangles meeting along its middle, and its prize written along it.
local function slice(spinner: Instance, frame: CFrame, index: number)
	local info = Wheel.Slices[index]
	local u = Wheel.direction(Wheel.centre(index))
	local v = Wheel.direction(Wheel.centre(index) + 90) -- clockwise across it
	local half = math.rad(Wheel.SliceAngle / 2)
	local reach = Wheel.Radius * math.cos(half)
	local width = Wheel.Radius * math.sin(half)
	for _, side in { v, -v } do
		local piece = triangle(spinner, "Slice", frame, u * reach, side, width, -u, reach, Wheel.Thickness, info.color)
		piece:SetAttribute("Slice", index)
	end
	-- The label: a see-through card on the front, its writing running out from the hub.
	local length = Wheel.Radius * 0.62
	local at = u * (Wheel.Radius * 0.55) + Vector3.new(0, 0, Wheel.Thickness / 2 + 0.03)
	local card =
		part(spinner, "Label", Vector3.new(length, 1.7, 0.05), frame * CFrame.fromMatrix(at, -u, -v), info.color)
	card.Transparency = 1
	local gui = surface(card, Enum.NormalId.Front, 60)
	if info.cred and not info.jackpot then
		text(gui, {
			Size = UDim2.fromScale(0.62, 1),
			Position = UDim2.fromScale(0.38, 0),
			Text = Format.number(info.cred),
		})
		text(gui, {
			Size = UDim2.fromScale(0.36, 0.55),
			Position = UDim2.fromScale(0.02, 0.22),
			Text = "CRED",
			TextColor3 = Color3.fromRGB(255, 240, 170),
		})
	else
		text(gui, {
			Size = UDim2.fromScale(0.96, 0.9),
			Position = UDim2.fromScale(0.02, 0.05),
			Text = Wheel.label(info),
			TextColor3 = if info.jackpot then Color3.fromRGB(120, 40, 10) else Color3.new(1, 1, 1),
		})
	end
end

-- The turning part: slices, rim, pegs, bulbs and hub, all in the wheel's own frame.
local function spinner(root: Model, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Spinner"
	for index = 1, #Wheel.Slices do
		slice(model, frame, index)
	end
	local rim = Wheel.Radius + 0.3
	local front = Wheel.Thickness / 2
	-- The gold rim: short blocks all the way round.
	local blocks = 36
	for index = 0, blocks - 1 do
		local angle = index * 360 / blocks
		local out = Wheel.direction(angle)
		local along = Wheel.direction(angle + 90)
		local length = 2 * math.pi * rim / blocks * 1.08
		part(
			model,
			"Rim",
			Vector3.new(length, 0.8, 1.1),
			frame * CFrame.fromMatrix(out * rim, along, out),
			GOLD,
			Enum.Material.SmoothPlastic
		)
	end
	-- Pegs between the slices (the pointer clicks over them) and bulbs between the pegs.
	for index = 0, #Wheel.Slices - 1 do
		local angle = (index + 0.5) * Wheel.SliceAngle
		disc(
			model,
			"Peg",
			0.9,
			0.42,
			(frame * CFrame.new(Wheel.direction(angle) * rim + Vector3.new(0, 0, front + 0.55))).Position,
			frame.LookVector * -1,
			Color3.new(1, 1, 1),
			Enum.Material.Metal
		)
	end
	for index = 0, BULB_COUNT - 1 do
		local angle = index * 360 / BULB_COUNT
		local bulb = ball(
			model,
			"Bulb",
			0.5,
			(frame * CFrame.new(Wheel.direction(angle) * rim + Vector3.new(0, 0, front + 0.35))).Position,
			Color3.fromRGB(255, 245, 200),
			Enum.Material.Neon
		)
		bulb:SetAttribute("Index", index)
	end
	-- The hub: a gold drum with a red cap and a gold button.
	local axis = -frame.LookVector -- out toward you
	disc(model, "Hub", 1.3, 2.6, frame.Position + axis * 0.2, axis, GOLD, Enum.Material.SmoothPlastic)
	disc(model, "HubCap", 0.4, 1.7, frame.Position + axis * 0.95, axis, RED)
	ball(model, "HubButton", 0.8, frame.Position + axis * 1.1, GOLD, Enum.Material.SmoothPlastic)
	model.WorldPivot = frame
	model.Parent = root
	return model
end

-- The pointer at the top: a red arrowhead pointing down at the slices, with a gold ball on top.
local function pointer(root: Model, frame: CFrame)
	local tip = Wheel.Radius - 0.3
	local top = Wheel.Radius + 1.8
	local depth = Wheel.Thickness / 2 + 0.9
	local corner = Vector3.new(0, top, depth)
	for _, side in { Vector3.xAxis, -Vector3.xAxis } do
		triangle(root, "Pointer", frame, corner, side, 1.1, -Vector3.yAxis, top - tip, 0.5, RED)
	end
	part(root, "PointerCap", Vector3.new(2.4, 0.4, 0.6), frame * CFrame.new(0, top + 0.2, depth), GOLD)
	ball(root, "PointerBall", 0.9, (frame * CFrame.new(0, top + 0.75, depth)).Position, GOLD)
end

-- A LUCKY WHEEL marquee over the wheel, bulbs all round its edge.
local function marquee(root: Model, frame: CFrame)
	local y = Wheel.Radius + 3.9
	local board = part(root, "Marquee", Vector3.new(13, 3, 0.6), frame * CFrame.new(0, y, -0.4), DEEP)
	part(root, "MarqueeFrame", Vector3.new(13.6, 3.6, 0.4), frame * CFrame.new(0, y, -0.65), GOLD)
	local gui = surface(board, Enum.NormalId.Back, 40)
	text(gui, {
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.05, 0.1),
		Text = "LUCKY WHEEL",
		TextColor3 = GOLD,
	})
	for index = 0, SIGN_BULBS - 1 do
		local t = index / SIGN_BULBS
		local x, yOff = 0, 0
		if t < 0.5 then
			x, yOff = -6.5 + t * 2 * 13, 1.8 -- along the top
		else
			x, yOff = 6.5 - (t - 0.5) * 2 * 13, -1.8 -- back along the bottom
		end
		local bulb =
			ball(root, "SignBulb", 0.42, (frame * CFrame.new(x, y + yOff, -0.1)).Position, GOLD, Enum.Material.Neon)
		bulb:SetAttribute("Index", index)
	end
end

-- The stand: a round rug, a base, a post behind the wheel up to the marquee, legs, an axle.
local function stand(root: Model, frame: CFrame)
	local floor = -Wheel.HubHeight
	local rug = disc(
		root,
		"Rug",
		0.1,
		15,
		(frame * CFrame.new(0, floor + 0.05, 1.5)).Position,
		Vector3.yAxis,
		Color3.fromRGB(150, 25, 40),
		Enum.Material.Fabric
	)
	rug.CanQuery = false
	disc(root, "RugTrim", 0.08, 15.8, (frame * CFrame.new(0, floor + 0.03, 1.5)).Position, Vector3.yAxis, GOLD)
	local base = part(root, "Base", Vector3.new(10, 1.2, 5), frame * CFrame.new(0, floor + 0.6, -1), DEEP)
	base.CanCollide = true
	part(root, "BaseTrim", Vector3.new(10.4, 0.3, 5.4), frame * CFrame.new(0, floor + 1.25, -1), GOLD)
	local post = part(
		root,
		"Post",
		Vector3.new(1.4, Wheel.HubHeight + Wheel.Radius + 4, 1.4),
		frame * CFrame.new(0, (floor + Wheel.Radius + 4) / 2, -1.4),
		DARK_GOLD
	)
	post.CanCollide = true
	for _, side in { -1, 1 } do
		local from = Vector3.new(side * 4, floor + 1.2, -1.4)
		local to = Vector3.new(side * 0.6, -1.4, -1.4)
		local along = to - from
		part(
			root,
			"Leg",
			Vector3.new(0.9, along.Magnitude, 0.9),
			frame * CFrame.fromMatrix((from + to) / 2, along.Unit:Cross(Vector3.zAxis), along.Unit),
			DARK_GOLD
		)
	end
	disc(root, "Axle", 1.6, 0.9, (frame * CFrame.new(0, 0, -0.9)).Position, frame.LookVector, GOLD)
end

-- Your spins, written on the base by your own client (SpinsSign), and where to press Spin.
local function front(root: Model, frame: CFrame)
	local floor = -Wheel.HubHeight
	local sign = part(root, "SpinsSign", Vector3.new(7, 1.6, 0.3), frame * CFrame.new(0, floor + 2.4, 1.6), INK)
	part(root, "SpinsSignFrame", Vector3.new(7.4, 2, 0.2), frame * CFrame.new(0, floor + 2.4, 1.4), GOLD)
	local gui = surface(sign, Enum.NormalId.Back, 50)
	gui.Name = "Spins"
	text(gui, {
		Name = "Text",
		Size = UDim2.fromScale(0.94, 0.8),
		Position = UDim2.fromScale(0.03, 0.1),
		Text = "SPIN!",
		TextColor3 = GOLD,
	})
	local spot = part(root, "SpinSpot", Vector3.new(2, 2, 2), frame * CFrame.new(0, floor + 3, 4), GOLD)
	spot.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Lucky Wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
end

-- The odds, slice by slice, on a board to the wheel's right.
local function oddsBoard(root: Model, frame: CFrame)
	local floor = -Wheel.HubHeight
	local width, height = 6.6, 8.6
	local at = CFrame.new(10, floor + 5.2, 0.5) * CFrame.Angles(0, math.rad(-15), 0)
	local board = part(root, "OddsBoard", Vector3.new(width, height, 0.4), frame * at, DEEP)
	board.MaterialVariant = "" -- plain, so the writing reads cleanly
	part(root, "OddsFrame", Vector3.new(width + 0.4, height + 0.4, 0.3), frame * at * CFrame.new(0, 0, -0.2), GOLD)
	part(root, "OddsPost", Vector3.new(0.6, 1.2, 0.6), frame * at * CFrame.new(0, -height / 2 - 0.5, -0.2), DARK_GOLD)
	local gui = surface(board, Enum.NormalId.Back, 40)
	local pixels = Vector2.new(width, height) * 40
	local margin = 14
	text(gui, {
		Size = UDim2.fromOffset(pixels.X - margin * 2, 40),
		Position = UDim2.fromOffset(margin, 8),
		Text = "ODDS",
		TextColor3 = GOLD,
	})
	local rows = {}
	for index, info in Wheel.Slices do
		table.insert(rows, { index = index, chance = Wheel.chance(index), info = info })
	end
	table.sort(rows, function(a, b)
		return a.chance > b.chance
	end)
	local rowHeight = 30
	for order, row in rows do
		local y = 56 + (order - 1) * (rowHeight + 2)
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(20, 20)
		swatch.Position = UDim2.fromOffset(margin, y + 5)
		swatch.BackgroundColor3 = row.info.color
		swatch.BorderSizePixel = 0
		swatch.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = swatch
		local name = if row.info.jackpot
			then "Jackpot"
			elseif row.info.cred then Format.cred(row.info.cred)
			else (Wheel.label(row.info):lower():gsub("^%l", string.upper))
		text(gui, {
			Size = UDim2.fromOffset(pixels.X - margin * 2 - 30 - 64, rowHeight),
			Position = UDim2.fromOffset(margin + 28, y),
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(gui, {
			Size = UDim2.fromOffset(62, rowHeight),
			Position = UDim2.fromOffset(pixels.X - margin - 62, y),
			Text = string.format("%g%%", math.floor(row.chance * 1000 + 0.5) / 10),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = GOLD,
		})
	end
	text(gui, {
		Size = UDim2.fromOffset(pixels.X - margin * 2, 26),
		Position = UDim2.fromOffset(margin, pixels.Y - 36),
		Text = "Free spins only",
		TextColor3 = Color3.fromRGB(205, 208, 222),
	})
end

-- Builds it (once) and returns the model.
function WheelBuilder.build(): Model
	local existing = workspace:FindFirstChild("LuckyWheel")
	if existing then
		existing:Destroy()
	end
	local frame = Wheel.frame()
	local root = Instance.new("Model")
	root.Name = "LuckyWheel"
	root:SetAttribute("Angle", 0)
	stand(root, frame)
	spinner(root, frame)
	pointer(root, frame)
	marquee(root, frame)
	front(root, frame)
	oddsBoard(root, frame)
	root.Parent = workspace
	return root
end

return WheelBuilder
