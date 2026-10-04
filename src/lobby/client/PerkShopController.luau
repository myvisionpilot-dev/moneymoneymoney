--!strict
-- The speed shop: a card per perk (buy the next level with Cred; it's yours for good), plus a
-- Badges tab showing what you've earned. Tabs sit along the bottom. Opens from the stand;
-- walking away closes it.

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

local SHOP_TAG = "PerkShop"
local CLOSE_SLACK = 8
local PERKS_TAB = "Perks"
local BADGES_TAB = "Badges"
local CARD_SIZE = UDim2.fromOffset(150, 186) -- badges
local PERK_CARD_SIZE = UDim2.fromOffset(230, 186)
local CARD_GAP = 8
local VISIBLE_ROWS = 2

local TABS = {
	{ key = PERKS_TAB, text = "Upgrades" },
	{ key = BADGES_TAB, text = "Badges" },
}

local PerkShopController = {}

local function multiplierText(level: number): string
	return `{string.format("%.1f", Catalog.speedMultiplier(level))}x speed`
end

-- Every perk level you've bought, added up (so a new purchase can ding).
local function levelsOf(view: Types.ProfileView): number
	local total = 0
	for _, level in view.perks do
		total += level
	end
	return total
end

function PerkShopController.start()
	local remotes = Remotes.lobby()
	local root = UI.root(UI.screen("PerkShop", 40))

	local window = UI.window("SPEED SHOP", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 0),
	}, root, true)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	-- Your Cred sits in the title bar, next to the X.
	window.title.Size = UDim2.new(1, -230, 1, 0)
	local credPill = UI.pill("", UI.Colors.Gold, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(170, 34),
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
	local grid = UI.grid(list, CARD_SIZE, CARD_GAP)

	-- Tabs along the bottom of the window, below the light inset.
	local tabs = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, panel)
	UI.list(tabs, Enum.FillDirection.Horizontal, 6)

	local currentTab = PERKS_TAB
	local tabButtons: { [string]: TextButton } = {}

	local function clearList()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function perkCard(order: number, perk: Catalog.Perk, view: Types.ProfileView)
		local level = view.perks[perk.id] or 0
		local maxLevel = Catalog.perkMaxLevel(perk.id)
		local price = Catalog.perkPrice(perk.id, level)
		local card = UI.card(UI.Colors.Info, { LayoutOrder = order }, list)
		UI.label({
			Position = UDim2.fromOffset(6, 8),
			Size = UDim2.new(1, -12, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 17,
			Text = perk.name,
		}, card)
		UI.label({
			Position = UDim2.fromOffset(6, 32),
			Size = UDim2.new(1, -12, 0, 18),
			TextSize = 13,
			TextColor3 = UI.Colors.Gold,
			Text = `Level {level}/{maxLevel}`,
		}, card)
		UI.label({
			Position = UDim2.fromOffset(6, 54),
			Size = UDim2.new(1, -12, 0, 76),
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = if price
				then `{perk.text}\nNow: {multiplierText(level)}\nNext: {multiplierText(level + 1)}`
				else `{perk.text}\n{multiplierText(level)} (max)`,
		}, card)
		local affordable = price ~= nil and view.cred >= price
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -14, 0, 36),
			TextSize = 15,
			BackgroundColor3 = if affordable then UI.Colors.Money else UI.Colors.Grey,
			Text = if price then `BUY {Format.cred(price)}` else "MAXED",
		}, card)
		button.Activated:Connect(function()
			if affordable then
				remotes.BuyPerk:fire(perk.id)
			else
				Sounds.play("Fail", 1, 0.6)
			end
		end)
	end

	local function badgeCard(order: number, badge: Catalog.Badge, earned: boolean)
		local card = UI.card(if earned then UI.Colors.Gold else UI.Colors.Grey, { LayoutOrder = order }, list)
		UI.label({
			Position = UDim2.fromOffset(4, 8),
			Size = UDim2.new(1, -8, 0, 36),
			Font = UI.Fonts.Heading,
			TextSize = 15,
			Text = badge.name,
		}, card)
		UI.label({
			Position = UDim2.fromOffset(5, 48),
			Size = UDim2.new(1, -10, 1, -90),
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = badge.text,
		}, card)
		UI.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -10, 0, 24),
			Font = UI.Fonts.Heading,
			TextSize = 15,
			Text = if earned then "EARNED" else "LOCKED",
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
		local badges = currentTab == BADGES_TAB
		grid.CellSize = if badges then CARD_SIZE else PERK_CARD_SIZE
		grid.HorizontalAlignment = if badges then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center
		if badges then
			for order, badge in Catalog.Badges do
				badgeCard(order, badge, table.find(view.badges, badge.id) ~= nil)
			end
		else
			for order, perk in Catalog.Perks do
				perkCard(order, perk, view)
			end
		end
	end

	for order, tab in TABS do
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			TextSize = 14,
			BackgroundColor3 = UI.Colors.PanelDark,
			Text = tab.text,
		}, tabs)
		button.Activated:Connect(function()
			currentTab = tab.key
			list.CanvasPosition = Vector2.zero
			render()
		end)
		tabButtons[tab.key] = button
	end

	remotes.OpenPerkShop:onClient(function()
		panel.Visible = true
		render()
	end)

	-- A cash-register ding when you buy a level.
	local boughtLevels = if ProfileState.view then levelsOf(ProfileState.view) else -1
	local lastCred: number? = nil
	ProfileState.changed:Connect(function(view: Types.ProfileView)
		local levels = levelsOf(view)
		if boughtLevels >= 0 and levels > boughtLevels then
			Sounds.play("Purchase")
		end
		boughtLevels = levels
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
				and (stand.Position - position).Magnitude <= Config.Perks.ShopRangeStuds + CLOSE_SLACK
			then
				return
			end
		end
		panel.Visible = false
	end)
end

return PerkShopController
