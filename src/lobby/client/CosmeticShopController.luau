--!strict
-- The cosmetics shop: a grid of item cards for kart paint, trails, titles and hats (buy with
-- Cred, then wear), plus a Badges tab showing what you've earned. Tabs sit along the bottom.
-- Opens from the stand; walking away closes it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)

local SHOP_TAG = "CosmeticShop"
local CLOSE_SLACK = 8
local BADGES_TAB = "Badges"
local CARD_SIZE = UDim2.fromOffset(108, 136)
local CARD_GAP = 8
local VISIBLE_ROWS = 2

local TABS: { [string]: { icon: string, color: Color3 } } = {
	Paint = { icon = "🏎️", color = UI.Colors.Pink },
	Trail = { icon = "✨", color = UI.Colors.Purple },
	Title = { icon = "🏷️", color = UI.Colors.Info },
	Hat = { icon = "🎩", color = UI.Colors.Risk },
	[BADGES_TAB] = { icon = "🏅", color = UI.Colors.Gold },
}

local HAT_ICONS: { [string]: string } = { Cap = "🧢", TopHat = "🎩", Crown = "👑" }

local CosmeticShopController = {}

-- The top of an item card: what the cosmetic looks like.
local function preview(item: Catalog.Cosmetic, card: Frame)
	local area = UI.frame({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
	}, card)
	if item.slot == "Paint" then
		local swatch = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = item.colors[1],
		}, area)
		UI.corner(swatch, 22)
		UI.stroke(swatch, 3)
		UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 24, Text = "🏎️" }, swatch)
	elseif item.slot == "Trail" then
		local strip = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(84, 20),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, area)
		UI.corner(strip, 10)
		UI.stroke(strip, 3)
		local keypoints = {}
		for index, color in item.colors do
			local time = if #item.colors == 1 then 0 else (index - 1) / (#item.colors - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, item.colors[1]))
		end
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(keypoints)
		gradient.Parent = strip
	elseif item.slot == "Title" then
		local tag = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundColor3 = UI.Colors.Ink,
		}, area)
		UI.corner(tag, 8)
		UI.label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 15,
			TextColor3 = item.colors[1],
			Text = item.text or item.name,
		}, tag)
	else
		UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 36, Text = HAT_ICONS[item.hat or ""] or "🎩" }, area)
	end
end

function CosmeticShopController.start()
	local remotes = Remotes.lobby()
	local root = UI.root(UI.screen("Cosmetics", 40))

	local window = UI.window("🎨 COSMETICS", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 0),
	}, root, true)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	-- Your Cred sits in the title bar, next to the X.
	window.title.Size = UDim2.new(1, -210, 1, 0)
	local credPill = UI.pill("⭐", UI.Colors.Gold, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
	}, window.title.Parent)

	-- Scrolls, so a long list (badges) never runs off a small screen.
	local list = Instance.new("ScrollingFrame")
	list.LayoutOrder = 1
	list.Size = UDim2.new(1, 0, 0, VISIBLE_ROWS * (CARD_SIZE.Y.Offset + CARD_GAP) + 4)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UI.Colors.Ink
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window.body
	UI.padding(list, 4)
	UI.grid(list, CARD_SIZE, CARD_GAP)

	-- Tabs along the bottom of the window, below the light inset.
	local tabs = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, panel)
	UI.list(tabs, Enum.FillDirection.Horizontal, 6)

	local currentTab = Catalog.Slots[1] :: string
	local tabButtons: { [string]: TextButton } = {}

	local function clearList()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function itemCard(order: number, item: Catalog.Cosmetic, view: Types.ProfileView)
		local look = TABS[item.slot]
		local card = UI.card(look.color, { LayoutOrder = order }, list)
		preview(item, card)
		UI.label({
			Position = UDim2.fromOffset(4, 56),
			Size = UDim2.new(1, -8, 0, 32),
			Font = UI.Fonts.Heading,
			TextSize = 15,
			Text = item.name,
		}, card)

		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		local price = Catalog.price(item.id) or 0
		local affordable = view.cred >= price
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -14, 0, 36),
			TextSize = if owned then 16 else 13,
			BackgroundColor3 = if wearing
				then UI.Colors.Gold
				elseif owned then UI.Colors.Info
				elseif affordable then UI.Colors.Money
				else UI.Colors.Grey,
			Text = if wearing then "✅ ON" elseif owned then "WEAR" else `BUY\n⭐ {Format.number(price)}`,
		}, card)
		button.Activated:Connect(function()
			if owned then
				remotes.EquipCosmetic:fire(item.id)
			elseif affordable then
				remotes.BuyCosmetic:fire(item.id)
			else
				Sounds.play("Fail", 1, 0.6)
			end
		end)
	end

	local function badgeCard(order: number, badge: Catalog.Badge, earned: boolean)
		local card = UI.card(if earned then UI.Colors.Gold else UI.Colors.Grey, { LayoutOrder = order }, list)
		UI.label({
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 38),
			TextSize = 32,
			Text = if earned then "🏅" else "🔒",
		}, card)
		UI.label({
			Position = UDim2.fromOffset(4, 44),
			Size = UDim2.new(1, -8, 0, 32),
			Font = UI.Fonts.Heading,
			TextSize = 14,
			Text = badge.name,
		}, card)
		UI.label({
			Position = UDim2.fromOffset(5, 78),
			Size = UDim2.new(1, -10, 1, -84),
			TextSize = 12,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = badge.text,
		}, card)
	end

	local function render()
		local view = ProfileState.view
		if not view then
			return
		end
		credPill.Text = Format.cred(view.cred)
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == currentTab then UI.Colors.Gold else UI.Colors.PanelDark
		end
		clearList()
		if currentTab == BADGES_TAB then
			for order, badge in Catalog.Badges do
				badgeCard(order, badge, table.find(view.badges, badge.id) ~= nil)
			end
			return
		end
		local order = 0
		for _, item in Catalog.Cosmetics do
			if item.slot == currentTab then
				order += 1
				itemCard(order, item, view)
			end
		end
	end

	local tabList: { { key: string, text: string } } = {}
	for _, slot in Catalog.Slots do
		table.insert(tabList, { key = slot, text = Catalog.SlotNames[slot] })
	end
	table.insert(tabList, { key = BADGES_TAB, text = "Badges" })
	for order, tab in tabList do
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1 / #tabList, -5, 1, 0),
			TextSize = 14,
			BackgroundColor3 = UI.Colors.PanelDark,
			Text = `{TABS[tab.key].icon} {tab.text}`,
		}, tabs)
		button.Activated:Connect(function()
			currentTab = tab.key
			list.CanvasPosition = Vector2.zero
			render()
		end)
		tabButtons[tab.key] = button
	end

	remotes.OpenCosmetics:onClient(function()
		panel.Visible = true
		render()
	end)

	-- A cash-register ding when something new lands in your collection.
	local ownedCount = if ProfileState.view then #ProfileState.view.owned else -1
	local lastCred: number? = nil
	ProfileState.changed:Connect(function(view: Types.ProfileView)
		if ownedCount >= 0 and #view.owned > ownedCount then
			Sounds.play("Purchase")
		end
		ownedCount = #view.owned
		if panel.Visible then
			render()
			if lastCred and lastCred ~= view.cred then
				UI.pop(credPill, 0.3)
			end
		end
		lastCred = view.cred
	end)

	-- Walking away from the stand closes the shop.
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if not panel.Visible or not character then
			return
		end
		local position = character:GetPivot().Position
		for _, stand in CollectionService:GetTagged(SHOP_TAG) do
			if
				stand:IsA("BasePart")
				and (stand.Position - position).Magnitude <= Config.Cosmetics.ShopRangeStuds + CLOSE_SLACK
			then
				return
			end
		end
		panel.Visible = false
	end)
end

return CosmeticShopController
