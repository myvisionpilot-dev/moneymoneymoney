--!strict
-- Helpers for building UI in code (client only), all in the shop style: colourful glossy panels
-- with a faint checkerboard (UI.panel, UI.window), bold outlined text, 3D buttons that click,
-- and spinning light rays behind things for sale (UI.rays). No emoji: icons are drawn
-- (UI.iconCircle) or are little 3D models (ItemModels).
-- Build inside UI.root(): sizes are designed for a ~500px-tall phone screen and scaled up on bigger ones.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local Sounds = require(script.Parent.Sounds)

local UI = {}

local INK = Color3.fromRGB(22, 33, 62)

UI.Colors = {
	Ink = INK, -- every outline
	Stroke = INK,
	Panel = Color3.fromRGB(47, 155, 255), -- windows
	PanelDark = Color3.fromRGB(29, 95, 184),
	PanelLight = Color3.fromRGB(150, 205, 255), -- inner areas, rows, inactive buttons
	Inner = Color3.fromRGB(207, 238, 255), -- the light inset behind cards
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(215, 232, 255),
	Money = Color3.fromRGB(90, 210, 90),
	Gold = Color3.fromRGB(255, 216, 74),
	Danger = Color3.fromRGB(255, 77, 94),
	Risk = Color3.fromRGB(255, 154, 61),
	Info = Color3.fromRGB(95, 160, 245),
	Pink = Color3.fromRGB(255, 92, 147),
	Purple = Color3.fromRGB(168, 107, 255),
	Grey = Color3.fromRGB(154, 165, 177),
	Track = Color3.fromRGB(16, 40, 92), -- behind a bar's fill
	Speech = Color3.fromRGB(14, 14, 18), -- subtitle boxes (see-through)
}

-- Different jobs get different type (set with FontFace, not Font).
UI.Fonts = {
	Title = Font.fromEnum(Enum.Font.LuckiestGuy), -- window titles, the quota, big banners
	Button = Font.fromEnum(Enum.Font.LuckiestGuy),
	Heading = Font.fromEnum(Enum.Font.GothamBlack), -- card and row names
	Number = Font.fromEnum(Enum.Font.FredokaOne), -- timers, money, prices
	Body = Font.fromName("BuilderSans", Enum.FontWeight.Bold), -- everything you read
	Speech = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold), -- what people say
	Serif = Font.fromName("Merriweather", Enum.FontWeight.Bold), -- Mr. Penny, the bank
}

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

-- The dark outline round text (every label and button gets one; this makes it thicker).
function UI.textStroke(label: TextLabel | TextButton, thickness: number?)
	local stroke = label:FindFirstChild("TextOutline")
	if not stroke then
		local created = Instance.new("UIStroke")
		created.Name = "TextOutline"
		created.Color = INK
		created.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		created.Parent = label
		stroke = created
	end
	if stroke and stroke:IsA("UIStroke") then
		stroke.Thickness = thickness or (if label.TextSize >= 24 then 2.5 elseif label.TextSize >= 16 then 1.8 else 1.2)
	end
end

-- Lighter at the top, darker at the bottom: the glossy 3D look.
function UI.gradient(parent: Instance, darken: number?): UIGradient
	local bottom = 1 - (darken or 0.22)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom))
	gradient.Parent = parent
	return gradient
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

-- A chunky 3D button: glossy, outlined, squishes when pressed and clicks.
function UI.button(props: Props?, parent: Instance?): TextButton
	local button = place(Instance.new("TextButton"), {
		BorderSizePixel = 0,
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.Money,
		FontFace = UI.Fonts.Button,
		TextColor3 = UI.Colors.Text,
		TextSize = 22,
		TextWrapped = true,
	}, props, parent)
	UI.corner(button, 12)
	UI.stroke(button, 3)
	UI.textStroke(button)
	UI.gradient(button)

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

-- A colourful card (shop items, offers): bright, glossy, outlined.
function UI.card(color: Color3, props: Props?, parent: Instance?): Frame
	local card = UI.frame(props, parent)
	card.BackgroundColor3 = color
	UI.corner(card, 14)
	UI.stroke(card, 3)
	UI.gradient(card, 0.18)
	return card
end

export type Window = {
	panel: Frame, -- the whole window (toggle Visible on this)
	title: TextLabel,
	body: Frame, -- the light inset: put content here
	close: TextButton?,
}

-- A subtle checkerboard over a frame (window headers, shop cards), clipped to its rounded
-- corners. Only on frames without a layout (the pattern would be laid out like content).
function UI.checker(parent: GuiObject, cell: number?, radius: number?, width: number?, height: number?): CanvasGroup
	local size = cell or 22
	local group = Instance.new("CanvasGroup")
	group.Name = "Checker"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.ZIndex = 0
	group.GroupTransparency = 0.88
	UI.corner(group, radius or 14)
	-- Generous: screen scaling makes AbsoluteSize smaller or bigger than the frame's own size,
	-- and before it's laid out there's only its offsets to go on.
	local wide = width or math.max(parent.AbsoluteSize.X * 1.6, parent.Size.X.Offset, 240)
	local tall = height or math.max(parent.AbsoluteSize.Y * 1.6, parent.Size.Y.Offset, 60)
	local columns = math.ceil(wide / size) + 1
	local rows = math.ceil(tall / size) + 1
	for row = 0, rows - 1 do
		for column = row % 2, columns - 1, 2 do
			local tile = Instance.new("Frame")
			tile.BorderSizePixel = 0
			tile.BackgroundColor3 = Color3.new(1, 1, 1)
			tile.Position = UDim2.fromOffset(column * size, row * size)
			tile.Size = UDim2.fromOffset(size, size)
			tile.Parent = group
		end
	end
	group.Parent = parent
	return group
end

-- A coloured panel in the shop style: rounded, outlined, glossy, with the checkerboard over it.
-- Put content (and any layout) in the see-through `content` frame it returns, not the panel:
-- it fills the panel, or grows with it when the panel has AutomaticSize Y. `tall` is how far
-- down the checkerboard goes on a panel that grows.
function UI.panel(color: Color3, props: Props?, parent: Instance?, tall: number?): (Frame, Frame)
	local panel = UI.frame({ BackgroundColor3 = color })
	apply(panel, props)
	UI.corner(panel, 12)
	UI.stroke(panel, 3)
	UI.gradient(panel, 0.2)
	local grows = panel.AutomaticSize == Enum.AutomaticSize.Y
	-- Grid cells and scale sizes aren't known yet, so the pattern goes wide enough for most.
	UI.checker(panel, 18, 12, math.max(panel.Size.X.Offset, 360), if grows then tall or 240 else nil)
	local content = UI.frame({
		Name = "Content",
		Size = if grows then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1),
		AutomaticSize = if grows then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, panel)
	if grows then
		-- The checkerboard's tiles would stretch an automatically sized panel, so it takes its
		-- height from the content instead (AbsoluteSize is on screen, Size before scaling).
		panel.AutomaticSize = Enum.AutomaticSize.None
		local function fitContent()
			local width = panel.Size.X.Offset
			if width > 0 and panel.AbsoluteSize.X > 0 then
				local height = content.AbsoluteSize.Y * width / panel.AbsoluteSize.X
				panel.Size = UDim2.new(panel.Size.X, UDim.new(0, math.ceil(height)))
			end
		end
		content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitContent)
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitContent)
	end
	panel.Parent = parent
	return panel, content
end

-- Light rays slowly spinning behind something (a shop item): soft beams through the centre and
-- a glow, clipped to `parent`'s rounded corners. `size` is how wide they spread (in pixels).
local spinners: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(dt: number)
		for spinner, speed in spinners do
			if spinner.Parent then
				spinner.Rotation = (spinner.Rotation + speed * dt) % 360
			end
		end
	end)
end

function UI.rays(parent: GuiObject, size: number, color: Color3?, radius: number?): CanvasGroup
	local tint = color or Color3.new(1, 1, 1)
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Rays"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ZIndex = 1
	UI.corner(clip, radius or 12)

	-- The glow: soft circles, brightest in the middle.
	for index, fraction in { 0.75, 0.5, 0.3 } do
		local glow = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * fraction, size * fraction),
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.88 - index * 0.06,
		}, clip)
		UI.corner(glow, size)
	end

	-- The beams: each one runs right through the middle, so 8 make 16 rays.
	local spinner = UI.frame({
		Name = "Spinner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, clip)
	local beams = 8
	for index = 0, beams - 1 do
		local wide = index % 2 == 0
		local beam = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, if wide then size * 0.13 else size * 0.06),
			BackgroundColor3 = tint,
			Rotation = index * 180 / beams,
		}, spinner)
		-- Bright in the middle, fading to nothing at both ends.
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, if wide then 0.72 else 0.8),
			NumberSequenceKeypoint.new(0.5, if wide then 0.5 else 0.62),
			NumberSequenceKeypoint.new(0.7, if wide then 0.72 else 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = beam
	end
	spinners[spinner] = 25 -- degrees a second
	clip.Parent = parent
	return clip
end

-- A rounded bar with a coloured fill and outlined text over it (the HUD's bars).
function UI.bar(color: Color3, props: Props?, parent: Instance?): (Frame, Frame, TextLabel)
	local track = UI.frame({ BackgroundColor3 = UI.Colors.Track })
	apply(track, props)
	UI.corner(track, 8)
	UI.stroke(track, 2)
	local fill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, track)
	UI.corner(fill, 8)
	UI.gradient(fill, 0.25)
	local text = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 13, ZIndex = 2, Text = "" }, track)
	track.Parent = parent
	return track, fill, text
end

-- A window in the shop style: a blue panel with a checkered header strip (bold title and an
-- optional red X) over a darker blue area for the content. Size it with props (width +
-- AutomaticSize Y works well).
function UI.window(title: string, props: Props?, parent: Instance?, closable: boolean?): Window
	local panel = UI.frame({
		BackgroundColor3 = UI.Colors.PanelDark,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, parent)
	apply(panel, props)
	UI.corner(panel, 16)
	UI.stroke(panel, 4)
	UI.padding(panel, 8)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local header = UI.frame({
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.Panel,
		ClipsDescendants = true,
	}, panel)
	UI.corner(header, 12)
	UI.stroke(header, 3)
	UI.checker(header, 22, 12, math.max(panel.Size.X.Offset, 480), 44)
	local titleLabel = UI.label({
		Name = "Title",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -64, 1, 0),
		FontFace = UI.Fonts.Title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, header)
	UI.textStroke(titleLabel, 3)

	local close: TextButton? = nil
	if closable then
		local button = UI.button({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = UI.Colors.Danger,
			TextSize = 20,
			Text = "X",
		}, header)
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
		BackgroundColor3 = UI.Colors.Panel,
	}, panel)
	UI.corner(body, 12)
	UI.stroke(body, 3)
	UI.padding(body, 10)

	-- A little pop and whoosh whenever it opens.
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			UI.pop(panel, 0.06)
			Sounds.play("Open")
		end
	end)
	return { panel = panel, title = titleLabel, body = body, close = close }
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
	UI.stroke(circle, 2)
	UI.plain({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = math.floor(size * 0.62),
		TextColor3 = UI.Colors.Text,
		Text = glyph,
	}, circle)
	return circle
end

-- A rounded pill with a coin glyph and an amount (money, Cred).
function UI.pill(glyph: string, color: Color3, props: Props?, parent: Instance?): TextLabel
	local pill = UI.frame({
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	apply(pill, props)
	UI.corner(pill, 17)
	UI.stroke(pill, 3)
	UI.iconCircle(glyph, UI.Colors.Gold, 24, { Position = UDim2.fromOffset(5, 5) }, pill)
	return UI.label({
		Name = "Amount",
		FontFace = UI.Fonts.Number,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -42, 1, 0),
		TextSize = 19,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, pill)
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
