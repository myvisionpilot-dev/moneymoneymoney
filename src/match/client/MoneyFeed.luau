--!strict
-- The money lines at the bottom of the screen: "+$10,000 | Customer served", underlined. The
-- newest sits at the bottom and pushes older ones up; each fades after a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))

local SHOW_SECONDS = 3.5
local FADE_SECONDS = 0.4
local MAX_LINES = 4
local AMOUNT_SIZE = 28
local LABEL_SIZE = 24
local LINE_HEIGHT = 40
local GAP = 10
local OVERHANG = 10 -- the underline sticks out this far past the text

local MoneyFeed = {}

local stack: Frame? = nil
local count = 0

local function getStack(): Frame
	if stack then
		return stack
	end
	local root = UI.root(UI.screen("MoneyFeed", 56))
	local frame = UI.frame({
		Name = "Lines",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90), -- clear of the backpack bar
		Size = UDim2.fromOffset(640, (LINE_HEIGHT + 4) * MAX_LINES),
		BackgroundTransparency = 1,
	}, root)
	local layout = UI.list(frame, Enum.FillDirection.Vertical, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack = frame
	return frame
end

local function width(text: string, size: number): number
	return TextService:GetTextSize(text, size, UI.Fonts.Heading, Vector2.new(2000, 200)).X + 4
end

local function addText(line: Frame, text: string, size: number, color: Color3, x: number): number
	local textWidth = width(text, size)
	local label = UI.label({
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(textWidth, LINE_HEIGHT - 6),
		Font = UI.Fonts.Heading,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = false,
	}, line)
	UI.textStroke(label, 2.5)
	return x + textWidth + GAP
end

local function fadeOut(line: Frame)
	for _, child in line:GetDescendants() do
		if child:IsA("TextLabel") then
			UI.tween(child, FADE_SECONDS, { TextTransparency = 1 })
		elseif child:IsA("UIStroke") then
			UI.tween(child, FADE_SECONDS, { Transparency = 1 })
		elseif child:IsA("Frame") then
			UI.tween(child, FADE_SECONDS, { BackgroundTransparency = 1 })
		end
	end
	task.delay(FADE_SECONDS, function()
		line:Destroy()
	end)
end

function MoneyFeed.show(amount: string, color: Color3, label: string)
	local frame = getStack()
	local lines: { Frame } = {}
	for _, child in frame:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	if #lines >= MAX_LINES then
		table.sort(lines, function(a: Frame, b: Frame)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end

	count += 1
	local line = UI.frame({ Name = "Line", BackgroundTransparency = 1, LayoutOrder = count }, frame)
	local x = addText(line, amount, AMOUNT_SIZE, color, OVERHANG)
	x = addText(line, "|", LABEL_SIZE, UI.Colors.Text, x)
	x = addText(line, label, LABEL_SIZE, UI.Colors.Text, x)
	line.Size = UDim2.fromOffset(x - GAP + OVERHANG, LINE_HEIGHT)
	local underline = UI.frame({
		Name = "Underline",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = UI.Colors.Text,
	}, line)
	UI.stroke(underline, 1.5)
	UI.pop(line, 0.2)

	task.delay(SHOW_SECONDS, function()
		if line.Parent then
			fadeOut(line)
		end
	end)
end

return MoneyFeed
