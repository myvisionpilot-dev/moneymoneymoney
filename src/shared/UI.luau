--!strict
-- Helpers for building UI in code (client only), in the game's chunky style: bubbly outlined
-- text, bright panels with thick dark borders, colourful cards and 3D buttons that click.
-- Build inside UI.root(): sizes are designed for a ~500px-tall phone screen and scaled up on bigger ones.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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
}

UI.Fonts = {
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.FredokaOne,
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
-- The virtual screen is at least ~500 tall and MIN_WIDTH wide, so the top panels never overlap.
type Root = { frame: Frame, scale: UIScale }
local roots: { Root } = {}

local MIN_WIDTH = 800

local function computeScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.Y / 500, viewport.X / MIN_WIDTH), 0.8, 1.6)
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
		stroke.Thickness = thickness or (if label.TextSize >= 24 then 2.5 elseif label.TextSize >= 15 then 2 else 1.5)
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
		Font = UI.Fonts.Body,
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
		Font = UI.Fonts.Heading,
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

-- A window like a game shop: a blue panel, a title bar with an optional red X, and a light
-- inset for the content. Size it with props (width + AutomaticSize Y works well).
function UI.window(title: string, props: Props?, parent: Instance?, closable: boolean?): Window
	local panel = UI.frame({
		BackgroundColor3 = UI.Colors.Panel,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, parent)
	apply(panel, props)
	UI.corner(panel, 18)
	UI.stroke(panel, 4)
	UI.gradient(panel, 0.15)
	UI.padding(panel, 10)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local header = UI.frame({
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
	}, panel)
	local titleLabel = UI.label({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Font = UI.Fonts.Heading,
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
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = UI.Colors.Danger,
			TextSize = 22,
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
		BackgroundColor3 = UI.Colors.Inner,
	}, panel)
	UI.corner(body, 14)
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

-- A rounded pill with an emoji and a number (money, Cred).
function UI.pill(icon: string, color: Color3, props: Props?, parent: Instance?): TextLabel
	local pill = UI.frame({
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	apply(pill, props)
	UI.corner(pill, 17)
	UI.stroke(pill, 3)
	UI.label({
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.fromOffset(30, 34),
		TextSize = 20,
		Text = icon,
	}, pill)
	return UI.label({
		Name = "Amount",
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextSize = 20,
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
