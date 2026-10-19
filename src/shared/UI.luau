--!strict
-- Helpers for building UI in code (client only), in one style: Fredoka One everywhere, white
-- with a thick black outline, and a subtle checkerboard over panels and buttons.
--   Store windows (UI.window): a bright blue frame round a pale inset, the title sticking up
--   over the top edge with a little 3D picture and icon tabs beside it, a red X on the corner.
--   Things for sale sit on bright cards (UI.itemCard) with sunburst rays behind them (UI.rays).
--   HUD and pop-up panels (UI.panel with UI.Colors.Panel): dark see-through checkered boxes in
--   a black outline; coloured panels get the checker in a darker shade of their colour.
--   Buttons are chunky and checkered with a darker lip along the bottom, and squish and click.
-- No emoji: icons are drawn (UI.iconCircle) or are little 3D models (ItemModels).
-- Build inside UI.root(): sizes are designed for a ~500px-tall phone screen and scaled up on bigger ones.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local Sounds = require(script.Parent.Sounds)

local UI = {}

local INK = Color3.fromRGB(16, 16, 22)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

UI.Colors = {
	Ink = INK, -- every outline
	Stroke = INK,
	Panel = Color3.fromRGB(32, 32, 40), -- the dark see-through panels (HUD, pop-ups)
	PanelDark = Color3.fromRGB(18, 18, 24), -- boxes inside them, quiet buttons
	PanelLight = Color3.fromRGB(78, 80, 96),
	Rim = Color3.fromRGB(74, 74, 88), -- the grey line just inside a dark panel's outline
	Window = Color3.fromRGB(60, 168, 245), -- a store window's blue frame...
	WindowInner = Color3.fromRGB(222, 242, 255), -- ...the pale inset inside it...
	WindowEdge = Color3.fromRGB(28, 104, 190), -- ...and its edge
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(205, 208, 222),
	Money = Color3.fromRGB(120, 222, 48),
	Gold = Color3.fromRGB(255, 216, 74),
	Danger = Color3.fromRGB(255, 70, 85),
	Risk = Color3.fromRGB(255, 154, 61),
	Info = Color3.fromRGB(70, 160, 245),
	Pink = Color3.fromRGB(255, 92, 147),
	Purple = Color3.fromRGB(168, 107, 255),
	Grey = Color3.fromRGB(150, 152, 165),
	Track = Color3.fromRGB(12, 12, 16), -- behind a bar's fill
	Speech = Color3.fromRGB(14, 14, 18), -- subtitle boxes (see-through)
}

-- White-on-clear pictures, tinted with ImageColor3.
UI.Images = {
	Checker = "rbxassetid://91640003672861", -- two squares on the diagonal: tiled into a checkerboard
	Sunburst = "rbxassetid://112844625988491", -- wedges of light from the middle, fading out
	Glow = "rbxassetid://87755377966973", -- a soft round glow
}

-- Everything is in Fredoka One; the names say what each is for (set with FontFace, not Font).
local FREDOKA = Font.fromEnum(Enum.Font.FredokaOne)
UI.Fonts = {
	Title = FREDOKA, -- window titles, the quota, big banners
	Button = FREDOKA,
	Heading = FREDOKA, -- card and row names
	Number = FREDOKA, -- timers, money, prices
	Body = FREDOKA, -- everything you read
	Speech = FREDOKA, -- what people say
	Serif = FREDOKA, -- Mr. Penny, the bank
}

-- A darker shade of a colour (card outlines in their own colour).
function UI.shade(color: Color3, amount: number?): Color3
	return color:Lerp(BLACK, amount or 0.5)
end

local function grey(value: number): Color3
	return Color3.new(value, value, value)
end

export type Props = { [string]: any }

local function apply<T>(instance: T, props: Props?): T
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	return instance
end

local function place<T>(instance: T, defaults: Props, props: Props?, parent: Instance?): T
	apply(instance, defaults)
	apply(instance, props)
	if parent then
		(instance :: any).Parent = parent
	end
	return instance
end

-- Screen-size scaling: each root is a virtual screen of (viewport / scale), then scaled back up.
-- The virtual screen is at least ~500 tall and MIN_WIDTH wide, so the top panels never overlap,
-- then everything is shrunk by Config.UI (less on touch screens, so buttons stay tappable).
type Root = { frame: Frame, scale: UIScale }
local roots: { Root } = {}

local MIN_WIDTH = 800

local function computeScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local fit = math.clamp(math.min(viewport.Y / 500, viewport.X / MIN_WIDTH), 0.8, 1.6)
	return fit * (if UserInputService.TouchEnabled then Config.UI.TouchScale else Config.UI.Scale)
end

local function fit(root: Root)
	local value = computeScale()
	root.scale.Scale = value
	root.frame.Size = UDim2.fromScale(1 / value, 1 / value)
end

local function refreshRoots()
	for _, root in roots do
		fit(root)
	end
end

local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshRoots)
	end
	refreshRoots()
end

if Players.LocalPlayer then
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

-- A full-screen container whose children are sized for a phone and scaled to fit.
function UI.root(gui: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local root = { frame = frame, scale = scale }
	table.insert(roots, root)
	fit(root)
	frame.Parent = gui
	return frame
end

function UI.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UI.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
	return corner
end

-- A thick dark border round a frame or button.
function UI.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Thickness = thickness or 3
	stroke.Color = color or INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- The black outline round text (every label and button gets one; this sets how thick). On a
-- button it goes on the label that shows the button's text (see UI.button).
function UI.textStroke(label: TextLabel | TextButton, thickness: number?)
	local target: TextLabel | TextButton = label
	local face = label:FindFirstChild("Face")
	if label:IsA("TextButton") and face and face:IsA("TextLabel") then
		target = face
	end
	local stroke = target:FindFirstChild("TextOutline")
	if not stroke then
		local created = Instance.new("UIStroke")
		created.Name = "TextOutline"
		created.Color = INK
		created.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		created.Parent = target
		stroke = created
	end
	if stroke and stroke:IsA("UIStroke") then
		local size = target.TextSize
		stroke.Thickness = thickness
			or (
				if size >= 36
					then 3.5
					elseif size >= 24 then 3
					elseif size >= 18 then 2.4
					elseif size >= 14 then 1.8
					else 1.4
			)
	end
end

-- Lighter at the top, darker at the bottom.
function UI.gradient(parent: Instance, darken: number?): UIGradient
	local bottom = 1 - (darken or 0.22)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(WHITE, grey(bottom))
	gradient.Parent = parent
	return gradient
end

-- Like UI.gradient, with a hard glossy edge across the middle: the candy look.
function UI.gloss(parent: Instance, darken: number?): UIGradient
	local bottom = 1 - (darken or 0.24)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, grey(1)),
		ColorSequenceKeypoint.new(0.47, grey(0.97)),
		ColorSequenceKeypoint.new(0.53, grey(0.86)),
		ColorSequenceKeypoint.new(1, grey(bottom)),
	})
	gradient.Parent = parent
	return gradient
end

-- Bright at the top, a little darker lower down, then a darker lip along the bottom edge:
-- a chunky button you could press in.
function UI.lip(parent: Instance, darken: number?): UIGradient
	local low = 1 - (darken or 0.38)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, grey(1)),
		ColorSequenceKeypoint.new(0.8, grey(0.87)),
		ColorSequenceKeypoint.new(0.83, grey(low + 0.04)),
		ColorSequenceKeypoint.new(1, grey(low)),
	})
	gradient.Parent = parent
	return gradient
end

-- A soft round glow behind or over something: tint it with `color`.
function UI.glow(color: Color3, props: Props?, parent: Instance?): ImageLabel
	return place(Instance.new("ImageLabel"), {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = UI.Images.Glow,
		ImageColor3 = color,
		ImageTransparency = 0.2,
	}, props, parent)
end

-- A bright streak that sweeps across `target` now and then (every `every` seconds, or only when
-- you call the returned function), in its rounded corners. It's a white sheet over the target
-- that's see-through except for a slanted band of its gradient, slid from one side to the other
-- (a moving child frame instead would stretch panels that size themselves to their content).
function UI.shine(target: GuiObject, every: number?, radius: number?): () -> ()
	local sheet = UI.frame({
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		ZIndex = 50,
		Active = false,
	}, target)
	UI.corner(sheet, radius or 12)
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.36, 1),
		NumberSequenceKeypoint.new(0.47, 0.6),
		NumberSequenceKeypoint.new(0.53, 0.6),
		NumberSequenceKeypoint.new(0.64, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(-1, 0) -- off the left edge: nothing shows
	band.Parent = sheet
	local function sweep()
		band.Offset = Vector2.new(-1, 0)
		TweenService:Create(
			band,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	end
	if every then
		task.spawn(function()
			while sheet.Parent do
				task.wait(every)
				if target.Visible then
					sweep()
				end
			end
		end)
	end
	return sweep
end

-- Numbers that roll to a new value instead of jumping (money, XP): `format` turns the number
-- on its way into the label's text. The first call just sets it.
type Roll = { from: number, to: number, startedAt: number, seconds: number, format: (number) -> string }
-- Plain tables, emptied as labels are destroyed (weak-keyed ones let Luau drop labels still on
-- screen, so a number could stop rolling).
local rolling: { [TextLabel]: Roll } = {}
local shown: { [TextLabel]: number } = {}

function UI.roll(label: TextLabel, value: number, format: (number) -> string, seconds: number?)
	local current = shown[label]
	if current == nil then
		label.Destroying:Once(function()
			rolling[label] = nil
			shown[label] = nil
		end)
	end
	if current == nil or current == value then
		shown[label] = value
		rolling[label] = nil
		label.Text = format(value)
		return
	end
	rolling[label] = { from = current, to = value, startedAt = os.clock(), seconds = seconds or 0.6, format = format }
end

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for label, roll in rolling do
			local t = math.clamp((now - roll.startedAt) / roll.seconds, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			local value = roll.from + (roll.to - roll.from) * eased
			shown[label] = value
			label.Text = roll.format(math.floor(value + 0.5))
			if t >= 1 then
				shown[label] = roll.to
				rolling[label] = nil
			end
		end
	end)
end

function UI.frame(props: Props?, parent: Instance?): Frame
	return place(Instance.new("Frame"), {
		BorderSizePixel = 0,
		BackgroundColor3 = UI.Colors.Panel,
	}, props, parent)
end

function UI.label(props: Props?, parent: Instance?): TextLabel
	local label = place(Instance.new("TextLabel"), {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = UI.Fonts.Body,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		TextWrapped = true,
	}, props, parent)
	UI.textStroke(label)
	return label
end

-- A little bounce (for buttons, money and anything that just changed).
function UI.pop(target: GuiObject, amount: number?)
	local scale = target:FindFirstChild("Pop")
	if not scale then
		local created = Instance.new("UIScale")
		created.Name = "Pop"
		created.Parent = target
		scale = created
	end
	if scale and scale:IsA("UIScale") then
		scale.Scale = 1 + (amount or 0.15)
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

-- A button's text is drawn by a label inside it ("Face"), so it sits over the checkerboard: set
-- Text, TextSize and the rest on the button as usual and the face copies them.
local FACE_COPIES = {
	"Text",
	"TextSize",
	"TextColor3",
	"FontFace",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"RichText",
	"TextTruncate",
	"LineHeight",
}

local function face(button: TextButton): TextLabel
	local label = place(Instance.new("TextLabel"), {
		Name = "Face",
		Size = UDim2.fromScale(1, 0.92), -- a touch above the lip
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, nil, button)
	for _, key in FACE_COPIES do
		(label :: any)[key] = (button :: any)[key]
		button:GetPropertyChangedSignal(key :: any):Connect(function()
			(label :: any)[key] = (button :: any)[key]
		end)
	end
	button.TextTransparency = 1
	-- A text size limit put on the button belongs on the face.
	button.ChildAdded:Connect(function(child: Instance)
		if child:IsA("UITextSizeConstraint") then
			child.Parent = label
		end
	end)
	return label
end

-- A chunky 3D button: checkered, outlined, a darker lip along the bottom and a glassy
-- highlight across the top; it squishes when pressed and clicks.
function UI.button(props: Props?, parent: Instance?): TextButton
	local button = place(Instance.new("TextButton"), {
		BorderSizePixel = 0,
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.Money,
		FontFace = UI.Fonts.Button,
		TextColor3 = UI.Colors.Text,
		TextSize = 22,
		TextWrapped = true,
	}, props)
	UI.corner(button, 12)
	UI.stroke(button, 3)
	UI.lip(button)
	UI.checker(button, 10, 12, BLACK, 0.9)
	local highlight = UI.frame({
		Name = "Highlight",
		Position = UDim2.fromOffset(5, 3),
		Size = UDim2.new(1, -10, 0.36, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.84,
		ZIndex = 2,
	}, button)
	UI.corner(highlight, 8)
	face(button)
	UI.textStroke(button)
	button.Parent = parent

	local squish = Instance.new("UIScale")
	squish.Name = "Squish"
	squish.Parent = button
	local function scaleTo(value: number)
		TweenService:Create(squish, TweenInfo.new(0.08), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		scaleTo(1.04)
	end)
	button.MouseLeave:Connect(function()
		scaleTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		scaleTo(0.94)
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(1)
	end)
	button.Activated:Connect(function()
		Sounds.play("Click")
	end)
	return button
end

-- A colourful box (offers, notices): bright, outlined, lighter at the top. Fine with a layout
-- inside (no checkerboard: that would be laid out too).
function UI.card(color: Color3, props: Props?, parent: Instance?): Frame
	local card = UI.frame(props, parent)
	card.BackgroundColor3 = color
	UI.corner(card, 14)
	UI.stroke(card, 3)
	UI.gradient(card, 0.18)
	return card
end

-- The checkerboard: one tiled picture over a frame, clipped to its rounded corners. White
-- squares lighten (the dark panels), black ones shade (colours). Only on frames without a
-- layout (the pattern would be laid out like content).
function UI.checker(
	parent: GuiObject,
	cell: number?,
	radius: number?,
	color: Color3?,
	transparency: number?
): ImageLabel
	local size = cell or 14
	local tiles = place(Instance.new("ImageLabel"), {
		Name = "Checker",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UI.Images.Checker,
		ImageColor3 = color or WHITE,
		ImageTransparency = transparency or 0.955,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(size * 2, size * 2),
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ZIndex = 1,
		Active = false,
	}, nil, parent)
	UI.corner(tiles, radius or 12)
	return tiles
end

-- The thin grey line just inside a dark panel's black outline.
local function rim(parent: GuiObject, radius: number)
	local line = UI.frame({
		Name = "Rim",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, parent)
	UI.corner(line, radius - 2)
	UI.stroke(line, 2, UI.Colors.Rim)
end

-- A panel: UI.Colors.Panel (or PanelDark) makes the dark see-through checkered box with a grey
-- rim inside its black outline; any other colour is bright, checkered a shade darker.
-- Put content (and any layout) in the see-through `content` frame it returns, not the panel:
-- it fills the panel, or grows with it when the panel has AutomaticSize Y.
function UI.panel(color: Color3, props: Props?, parent: Instance?): (Frame, Frame)
	local dark = color == UI.Colors.Panel or color == UI.Colors.PanelDark
	local panel = UI.frame({ BackgroundColor3 = color, BackgroundTransparency = if dark then 0.12 else 0 })
	apply(panel, props)
	UI.corner(panel, 12)
	UI.stroke(panel, 3)
	if dark then
		rim(panel, 12)
		UI.checker(panel, 14, 12)
	else
		UI.gradient(panel, 0.2)
		UI.checker(panel, 14, 12, BLACK, 0.93)
	end
	-- A panel that grows (AutomaticSize Y) grows with its content (the checkerboard and rim are
	-- scale-sized, so they just fill it).
	local grows = panel.AutomaticSize == Enum.AutomaticSize.Y
	local content = UI.frame({
		Name = "Content",
		Size = if grows then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1),
		AutomaticSize = if grows then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, panel)
	panel.Parent = parent
	return panel, content
end

-- Sunburst rays slowly turning behind something (a shop item), with a soft white glow in the
-- middle, clipped to `parent`'s rounded corners. `size` is how wide they spread (in pixels),
-- `centre` where the middle is (scale, 0..1; the centre of `parent` by default).
local spinners: { [GuiObject]: number } = {} -- emptied as they're destroyed (see UI.roll)

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(dt: number)
		for spinner, speed in spinners do
			if spinner.Parent then
				spinner.Rotation = (spinner.Rotation + speed * dt) % 360
			end
		end
	end)
end

function UI.rays(parent: GuiObject, size: number, color: Color3?, radius: number?, centre: Vector2?): CanvasGroup
	local at = centre or Vector2.new(0.5, 0.5)
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Rays"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ZIndex = 1
	UI.corner(clip, radius or 12)
	local spinner = place(Instance.new("ImageLabel"), {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = UI.Images.Sunburst,
		ImageColor3 = color or WHITE,
		ImageTransparency = 0.5,
	}, nil, clip)
	place(Instance.new("ImageLabel"), {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset(size * 0.42, size * 0.42),
		BackgroundTransparency = 1,
		Image = UI.Images.Glow,
		ImageColor3 = WHITE,
		ImageTransparency = 0.3,
	}, nil, clip)
	spinners[spinner] = 14 -- degrees a second
	spinner.Destroying:Once(function()
		spinners[spinner] = nil
	end)
	clip.Parent = parent
	return clip
end

-- A store card for something you can have: bright, outlined in a darker shade of itself, with
-- sunburst rays (a lighter shade) behind where its picture goes. Content goes in the frame it
-- returns, over the rays. `raysY` is how far down the rays' middle sits (0..1).
function UI.itemCard(color: Color3, props: Props?, parent: Instance?, raysY: number?): (Frame, Frame)
	local card = UI.frame({ BackgroundColor3 = color })
	apply(card, props)
	UI.corner(card, 14)
	UI.stroke(card, 3.5, UI.shade(color, 0.5))
	UI.gradient(card, 0.16)
	UI.rays(card, 460, color:Lerp(WHITE, 0.6), 14, Vector2.new(0.5, raysY or 0.4))
	local content = UI.frame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, card)
	card.Parent = parent
	return card, content
end

-- A rounded bar with a coloured, checkered fill and outlined text over it (the HUD's bars).
function UI.bar(color: Color3, props: Props?, parent: Instance?): (Frame, Frame, TextLabel)
	local track = UI.frame({ BackgroundColor3 = UI.Colors.Track })
	apply(track, props)
	UI.corner(track, 8)
	UI.stroke(track, 2.5)
	local fill = UI.frame({ Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, track)
	UI.corner(fill, 8)
	UI.lip(fill, 0.34)
	UI.checker(fill, 8, 8, BLACK, 0.9)
	-- A glassy highlight along the top of the fill.
	local shineStrip = UI.frame({
		Name = "Highlight",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0.3, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6,
		ZIndex = 2,
	}, fill)
	UI.corner(shineStrip, 4)
	local text = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 13, ZIndex = 2, Text = "" }, track)
	track.Parent = parent
	return track, fill, text
end

export type Window = {
	panel: Frame, -- the whole window (toggle Visible on this)
	title: TextLabel,
	header: Frame, -- the strip along the top edge: pin things to the title bar here
	icon: Frame, -- left of the title: put a little 3D picture in it and it shows
	tabs: Frame, -- right of the title: tab buttons go here, in a row
	body: Frame, -- the pale inset: put content here
	close: TextButton?,
}

local TITLE_ROOM = 28 -- the header's height inside the window (the title sticks up above it)

-- A store window: a blue frame round a pale inset, the title in big outlined letters sticking
-- up over the top edge (a little picture and tabs can sit beside it) and a red X on the
-- top-right corner. Size it with props (width + AutomaticSize Y works well).
function UI.window(title: string, props: Props?, parent: Instance?, closable: boolean?): Window
	local panel = UI.frame({
		BackgroundColor3 = UI.Colors.Window,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, parent)
	apply(panel, props)
	UI.corner(panel, 18)
	UI.stroke(panel, 4)
	UI.gradient(panel, 0.22)
	local padding = UI.padding(panel, 10)
	padding.PaddingTop = UDim.new(0, 6)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local header = UI.frame({
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, TITLE_ROOM),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, panel)
	-- The title row sticks up over the top edge: picture, title, tabs.
	local row = UI.frame({
		Name = "Row",
		Position = UDim2.fromOffset(-4, -40),
		Size = UDim2.new(1, if closable then -54 else 4, 0, 64),
		BackgroundTransparency = 1,
	}, header)
	local rowLayout = UI.list(row, Enum.FillDirection.Horizontal, 8)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = UI.frame({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(62, 62),
		Rotation = -8,
		BackgroundTransparency = 1,
		Visible = false,
	}, row)
	icon.ChildAdded:Connect(function()
		icon.Visible = true
	end)
	local titleLabel = UI.label({
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Fonts.Title,
		TextSize = 42,
		TextWrapped = false,
		Text = title,
	}, row)
	UI.textStroke(titleLabel, 4)
	local tabs = UI.frame({
		Name = "Tabs",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 62),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, row)
	local tabLayout = UI.list(tabs, Enum.FillDirection.Horizontal, 8)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local close: TextButton? = nil
	if closable then
		local button = UI.button({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 18, 0, -30),
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = UI.Colors.Danger,
			TextSize = 34,
			Text = "X",
		}, header)
		UI.textStroke(button, 3)
		button.Activated:Connect(function()
			panel.Visible = false
		end)
		close = button
	end

	local body = UI.frame({
		Name = "Body",
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.WindowInner,
	}, panel)
	UI.corner(body, 12)
	UI.stroke(body, 3, UI.Colors.WindowEdge)
	UI.gradient(body, 0.1)
	UI.padding(body, 10)

	-- It springs open (from small, overshooting a little) with a whoosh.
	local opening = Instance.new("UIScale")
	opening.Name = "Opening"
	opening.Parent = panel
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			opening.Scale = 0.72
			TweenService
				:Create(opening, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			Sounds.play("Open")
		end
	end)
	return {
		panel = panel,
		title = titleLabel,
		header = header,
		icon = icon,
		tabs = tabs,
		body = body,
		close = close,
	}
end

-- Puts a window's title in the middle of its top edge (windows without a picture or tabs).
function UI.centreTitle(window: Window)
	local row = window.title.Parent
	local layout = row and row:FindFirstChildOfClass("UIListLayout")
	if row and row:IsA("Frame") and layout then
		row.Size = UDim2.new(1, 8, 0, 64)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

-- Puts a price on a button: a coin with `glyph` on it and the amount beside it, together in
-- the middle (glyph nil: just the text). Replaces whatever price was there.
function UI.price(button: TextButton, glyph: string?, text: string, coinColor: Color3?)
	local old = button:FindFirstChild("Price")
	if old then
		old:Destroy()
	end
	button.Text = ""
	local row = UI.frame({
		Name = "Price",
		Size = UDim2.fromScale(1, 0.92),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, button)
	local layout = UI.list(row, Enum.FillDirection.Horizontal, 5)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local height = button.Size.Y.Offset
	local textSize = math.clamp(math.floor(height * 0.56), 14, 26)
	if glyph then
		UI.iconCircle(glyph, coinColor or UI.Colors.Gold, math.floor(textSize * 1.05), {
			LayoutOrder = 1,
			ZIndex = 4,
		}, row)
	end
	local amount = UI.label({
		Name = "Amount",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, textSize + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Fonts.Number,
		TextSize = textSize,
		TextWrapped = false,
		Text = text,
		ZIndex = 4,
	}, row)
	UI.textStroke(amount, if textSize >= 20 then 2.6 else 2)
end

-- Plain text with no outline (subtitles, glyphs in icon circles).
function UI.plain(props: Props?, parent: Instance?): TextLabel
	return place(Instance.new("TextLabel"), {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = UI.Fonts.Body,
		TextColor3 = UI.Colors.Text,
		TextSize = 14,
		TextWrapped = true,
	}, props, parent)
end

-- A round badge with a short glyph in it ("$", "+", "!"): the HUD's icons.
function UI.iconCircle(glyph: string, color: Color3, size: number, props: Props?, parent: Instance?): Frame
	local circle = UI.frame({ Size = UDim2.fromOffset(size, size), BackgroundColor3 = color }, parent)
	apply(circle, props)
	UI.corner(circle, size)
	UI.stroke(circle, if size >= 24 then 2.5 else 2)
	UI.gradient(circle, 0.25)
	local text = UI.plain({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = math.floor(size * 0.66),
		TextColor3 = UI.Colors.Text,
		Text = glyph,
		ZIndex = circle.ZIndex,
	}, circle)
	UI.textStroke(text, if size >= 24 then 1.8 else 1.3)
	return circle
end

-- A dark checkered box with a coin glyph and an amount in colour (money, Cred).
function UI.pill(glyph: string, color: Color3, props: Props?, parent: Instance?): TextLabel
	local pill = UI.frame({
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
	}, parent)
	apply(pill, props)
	UI.corner(pill, 10)
	UI.stroke(pill, 3)
	UI.checker(pill, 10, 10)
	UI.iconCircle(glyph, UI.Colors.Gold, 26, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		ZIndex = 2,
	}, pill)
	local amount = UI.label({
		Name = "Amount",
		FontFace = UI.Fonts.Number,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -42, 1, 0),
		TextSize = 21,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 2,
	}, pill)
	UI.textStroke(amount, 2.6)
	return amount
end

function UI.padding(parent: Instance, pixels: number): UIPadding
	local padding = Instance.new("UIPadding")
	local size = UDim.new(0, pixels)
	padding.PaddingTop = size
	padding.PaddingBottom = size
	padding.PaddingLeft = size
	padding.PaddingRight = size
	padding.Parent = parent
	return padding
end

function UI.list(parent: Instance, direction: Enum.FillDirection, gap: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap or 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = parent
	return layout
end

function UI.grid(parent: Instance, cellSize: UDim2, gap: number?): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize
	layout.CellPadding = UDim2.fromOffset(gap or 8, gap or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = parent
	return layout
end

function UI.tween(instance: Instance, seconds: number, goals: Props): Tween
	local tween =
		TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

return UI
