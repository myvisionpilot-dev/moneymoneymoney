--!strict
-- What the lobby's two shop windows (UPGRADES, CUSTOMISATION) share: a window that sits just
-- above the menu bar with your Cred in its title bar and tabs along its bottom, a body as tall
-- as the screen allows, and the buy button's look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(Shared:WaitForChild("UI"))

local ShopFrame = {}

ShopFrame.BAR_SPACE = 112 -- the menu bar at the bottom of the screen, plus a gap
local CHROME = 172 -- the window's header, tabs, padding and gaps round the body
local TOP_GAP = 10
local MIN_BODY, MAX_BODY = 232, 430

export type Tab = { key: string, text: string }

export type Shop = {
	window: UI.Window,
	cred: TextLabel,
	tabs: { [string]: TextButton },
	bodyHeight: () -> number,
}

-- How much height the body gets on this screen (in the UI's own pixels, before scaling).
local function bodyHeight(root: Frame): number
	local scale = root:FindFirstChildOfClass("UIScale")
	local virtual = root.AbsoluteSize.Y / (if scale then scale.Scale else 1)
	return math.clamp(math.floor(virtual - ShopFrame.BAR_SPACE - CHROME - TOP_GAP), MIN_BODY, MAX_BODY)
end

function ShopFrame.new(root: Frame, title: string, width: number, tabs: { Tab }, onTab: (key: string) -> ()): Shop
	local window = UI.window(title, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(width, 0),
	}, root, true)
	Cursor.registerPanel(window.panel)

	-- Your Cred sits in the title bar, next to the X.
	window.title.Size = UDim2.new(1, -240, 1, 0)
	local cred = UI.pill("C", UI.Colors.Gold, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(170, 34),
	}, window.title.Parent)

	local bar = UI.frame({
		Name = "Tabs",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, window.panel)
	UI.list(bar, Enum.FillDirection.Horizontal, 6)
	local buttons: { [string]: TextButton } = {}
	for order, tab in tabs do
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1 / #tabs, -5, 1, 0),
			TextSize = 15,
			BackgroundColor3 = UI.Colors.PanelDark,
			Text = tab.text,
		}, bar)
		button.Activated:Connect(function()
			onTab(tab.key)
		end)
		buttons[tab.key] = button
	end

	return {
		window = window,
		cred = cred,
		tabs = buttons,
		bodyHeight = function(): number
			return bodyHeight(root)
		end,
	}
end

function ShopFrame.showTab(shop: Shop, current: string)
	for key, button in shop.tabs do
		button.BackgroundColor3 = if key == current then UI.Colors.Gold else UI.Colors.PanelDark
	end
end

-- A see-through list that scrolls up and down.
function ShopFrame.scroller(props: UI.Props, parent: Instance): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UI.Colors.Ink
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	for key, value in props do
		(list :: any)[key] = value
	end
	list.Parent = parent
	return list
end

-- What a buy button says and its colour: green when you can afford it, grey when you can't.
function ShopFrame.buyLook(cred: number, price: number): (string, Color3, boolean)
	local affordable = cred >= price
	return `{Format.number(price)} Cred`, if affordable then UI.Colors.Money else UI.Colors.Grey, affordable
end

return ShopFrame
