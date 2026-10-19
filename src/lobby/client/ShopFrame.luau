--!strict
-- What the lobby's windows (Shop, Upgrades, Customise) share: a store window (StoreKit) that
-- sits just above the menu bar, your Cred in gold on its title bar, tabs (if any) as square
-- picture buttons beside the title, a body as tall as the screen allows, and the buttons' look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local UI = require(Shared:WaitForChild("UI"))

local ShopFrame = {}

ShopFrame.BAR_SPACE = 112 -- the menu bar at the bottom of the screen, plus a gap
local CHROME = 96 -- the window's title bar, its padding and outline
local TOP_GAP = 12
local MIN_BODY, MAX_BODY = 232, 470
local TAB_SIZE = 50
local TAB_COLORS = {
	UI.Colors.Info,
	UI.Colors.Danger,
	UI.Colors.Gold,
	UI.Colors.Money,
	UI.Colors.Purple,
	UI.Colors.Risk,
	UI.Colors.Pink,
	Color3.fromRGB(40, 190, 180),
}

-- `draw` puts the tab's little picture in the frame it's given.
export type Tab = { key: string, text: string, draw: ((art: Frame) -> ())? }

export type Shop = {
	window: UI.Window,
	cred: TextLabel, -- the amount on the title bar
	credPill: Frame, -- the coin and the amount together
	tabs: { [string]: TextButton },
	bodyHeight: () -> number,
}

-- How much height the body gets on this screen (in the UI's own pixels, before scaling).
local function bodyHeight(root: Frame): number
	local scale = root:FindFirstChildOfClass("UIScale")
	local virtual = root.AbsoluteSize.Y / (if scale then scale.Scale else 1)
	return math.clamp(math.floor(virtual - ShopFrame.BAR_SPACE - CHROME - TOP_GAP), MIN_BODY, MAX_BODY)
end

-- A square tab: its colour, its picture and its name along the bottom.
local function tabButton(order: number, tab: Tab, parent: Instance): TextButton
	local button = StoreKit.button({
		Name = tab.key,
		LayoutOrder = order,
		Size = UDim2.fromOffset(TAB_SIZE, TAB_SIZE),
		BackgroundColor3 = TAB_COLORS[(order - 1) % #TAB_COLORS + 1],
		Text = "",
		ZIndex = 6,
	}, parent)
	local art = UI.frame({
		Name = "Art",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 1, -16),
		BackgroundTransparency = 1,
		ZIndex = 7,
	}, button)
	if tab.draw then
		tab.draw(art)
	end
	local caption = StoreKit.label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 6, 0, 14),
		TextScaled = true,
		Text = tab.text:upper(),
		ZIndex = 8,
	}, button)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 12
	limit.Parent = caption
	UI.textStroke(caption, 1.6)
	local lift = Instance.new("UIScale")
	lift.Name = "Lift"
	lift.Parent = art
	return button
end

function ShopFrame.new(root: Frame, title: string, width: number, tabs: { Tab }, onTab: (key: string) -> ()): Shop
	local window = StoreKit.window(title, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(width, 0),
	}, root)
	Cursor.registerPanel(window.panel)

	local buttons: { [string]: TextButton } = {}
	for order, tab in tabs do
		local button = tabButton(order, tab, window.tabs)
		button.Activated:Connect(function()
			onTab(tab.key)
		end)
		buttons[tab.key] = button
	end

	-- Your Cred: a coin and the amount in gold, on the title bar left of the X.
	local pill = UI.frame({
		Name = "Cred",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -70, 0.5, 0),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, window.header)
	local layout = UI.list(pill, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	StoreKit.image(StoreKit.Images.CredCoin, { LayoutOrder = 1, Size = UDim2.fromOffset(40, 40), ZIndex = 6 }, pill)
	local cred = StoreKit.label({
		Name = "Amount",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 30,
		TextColor3 = StoreKit.Colors.Gold,
		Text = "",
		ZIndex = 6,
	}, pill)
	UI.textStroke(cred, 3)

	return {
		window = window,
		cred = cred,
		credPill = pill,
		tabs = buttons,
		bodyHeight = function(): number
			return bodyHeight(root)
		end,
	}
end

-- The tab you're on stands out: a white outline, its picture a little bigger.
function ShopFrame.showTab(shop: Shop, current: string)
	for key, button in shop.tabs do
		local selected = key == current
		local border = button:FindFirstChild("Border")
		if border and border:IsA("UIStroke") then
			border.Color = if selected then Color3.new(1, 1, 1) else UI.Colors.Ink
			border.Thickness = if selected then 4 else 3
		end
		local art = button:FindFirstChild("Art")
		local lift = art and art:FindFirstChild("Lift")
		if lift and lift:IsA("UIScale") then
			lift.Scale = if selected then 1.15 else 1
		end
		local caption = button:FindFirstChild("Caption")
		if caption and caption:IsA("TextLabel") then
			caption.TextColor3 = if selected then StoreKit.Colors.Gold else UI.Colors.Text
		end
	end
end

-- A see-through list that scrolls up and down.
ShopFrame.scroller = StoreKit.scroller

-- Puts a Cred price on a button: green with the coin when you can afford it, grey when you
-- can't. Returns whether you can.
function ShopFrame.priceButton(button: TextButton, cred: number, price: number): boolean
	local affordable = cred >= price
	if affordable then
		StoreKit.lime(button)
	else
		button.BackgroundColor3 = UI.Colors.Grey
	end
	StoreKit.iconText(button, StoreKit.Images.CredCoin, Format.number(price))
	return affordable
end

-- A button that says something instead of a price (OWNED, MAXED, WEAR...).
function ShopFrame.wordButton(button: TextButton, text: string, color: Color3)
	button.BackgroundColor3 = color
	StoreKit.iconText(button, nil, text)
end

return ShopFrame
