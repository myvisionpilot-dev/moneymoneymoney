--!strict
-- Tiny helpers for building UI in code (client only).
-- Build inside UI.root(): sizes are designed for a ~500px-tall phone screen and scaled up on bigger ones.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(22, 28, 24),
	PanelLight = Color3.fromRGB(44, 54, 48),
	Text = Color3.fromRGB(245, 245, 235),
	Muted = Color3.fromRGB(175, 185, 175),
	Money = Color3.fromRGB(80, 200, 105),
	Gold = Color3.fromRGB(255, 196, 50),
	Danger = Color3.fromRGB(225, 75, 65),
	Risk = Color3.fromRGB(235, 135, 40),
	Info = Color3.fromRGB(95, 160, 245),
	Stroke = Color3.fromRGB(0, 0, 0),
}

UI.Fonts = {
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
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
type Root = { frame: Frame, scale: UIScale }
local roots: { Root } = {}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	return math.clamp(camera.ViewportSize.Y / 500, 0.8, 1.6)
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

function UI.frame(props: Props?, parent: Instance?): Frame
	return place(Instance.new("Frame"), {
		BorderSizePixel = 0,
		BackgroundColor3 = UI.Colors.Panel,
	}, props, parent)
end

function UI.label(props: Props?, parent: Instance?): TextLabel
	return place(Instance.new("TextLabel"), {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = UI.Fonts.Body,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		TextWrapped = true,
	}, props, parent)
end

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
	UI.stroke(button, 2)
	return button
end

function UI.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

function UI.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or UI.Colors.Stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UI.textStroke(label: TextLabel)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = UI.Colors.Stroke
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

function UI.tween(instance: Instance, seconds: number, goals: Props): Tween
	local tween =
		TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

return UI
