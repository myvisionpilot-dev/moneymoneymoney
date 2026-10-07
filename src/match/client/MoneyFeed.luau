--!strict
-- The money lines at the bottom of the screen: "+$10,000 | Customer served", underlined. The
-- newest sits at the bottom and pushes older ones up; each fades after a few seconds. A big
-- payout gets a bigger, gold-shining amount; a streak payout gets a flaming "x1.5" chip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function addText(words: Frame, order: number, text: string, size: number, color: Color3, font: Font): TextLabel
	local label = UI.label({
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, LINE_HEIGHT - 6),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = font,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = false,
	}, words)
	UI.textStroke(label, 2.5)
	return label
end

-- "x1.5": the streak a payout was paid at, in a flaming pill.
local function streakChip(words: Frame, multiplier: number)
	local chip = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(0, LINE_HEIGHT - 10),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(255, 120, 30),
	}, words)
	UI.corner(chip, 10)
	UI.stroke(chip, 2.5)
	local fire = Instance.new("UIGradient")
	fire.Rotation = 90
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(230, 50, 30))
	fire.Parent = chip
	local padding = UI.padding(chip, 0)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	local text = UI.label({
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Fonts.Title,
		TextSize = 24,
		TextWrapped = false,
		Text = `x{multiplier}`,
	}, chip)
	UI.textStroke(text, 2.5)
	UI.pop(chip, 0.4)
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

export type Extras = { big: boolean?, streak: number? }

function MoneyFeed.show(amount: string, color: Color3, label: string, extras: Extras?)
	local big = extras ~= nil and extras.big == true
	local streak = if extras then extras.streak else nil
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
	-- The line grows to fit its words; the underline (scale-sized) follows it.
	local line = UI.frame({
		Name = "Line",
		BackgroundTransparency = 1,
		LayoutOrder = count,
		Size = UDim2.fromOffset(0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
	}, frame)
	local words = UI.frame({
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
	}, line)
	local padding = UI.padding(words, 0)
	padding.PaddingLeft = UDim.new(0, OVERHANG)
	padding.PaddingRight = UDim.new(0, OVERHANG)
	local layout = UI.list(words, Enum.FillDirection.Horizontal, GAP)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	local amountLabel = addText(words, 1, amount, if big then AMOUNT_SIZE + 10 else AMOUNT_SIZE, color, UI.Fonts.Number)
	if big then
		local shine = Instance.new("UIGradient")
		shine.Rotation = 90
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 200, 60))
		shine.Parent = amountLabel
	end
	addText(words, 2, "|", LABEL_SIZE, UI.Colors.Text, UI.Fonts.Body)
	addText(words, 3, label, LABEL_SIZE, UI.Colors.Text, UI.Fonts.Speech)
	if streak and streak > 1 then
		streakChip(words, streak)
	end
	local underline = UI.frame({
		Name = "Underline",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = UI.Colors.Text,
	}, line)
	UI.stroke(underline, 1.5)
	UI.pop(line, if big then 0.45 else 0.2)

	task.delay(SHOW_SECONDS, function()
		if line.Parent then
			fadeOut(line)
		end
	end)
end

return MoneyFeed
