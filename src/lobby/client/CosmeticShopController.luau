--!strict
-- The cosmetics shop panel: tabs for kart paint, trails, titles and hats (buy with Cred, then
-- equip), plus a Badges tab showing what you've earned. Opens from the stand; walking away
-- closes it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)

local SHOP_TAG = "CosmeticShop"
local CLOSE_SLACK = 8
local BADGES_TAB = "Badges"
local ROW_HEIGHT = 50
local VISIBLE_ROWS = 5

local CosmeticShopController = {}

function CosmeticShopController.start()
	local remotes = Remotes.lobby()
	local root = UI.root(UI.screen("Cosmetics", 40))

	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 14)
	FirstPerson.registerPanel(panel)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = UI.Fonts.Heading,
		TextSize = 28,
		TextColor3 = UI.Colors.Gold,
		Text = "COSMETICS",
	}, panel)
	UI.textStroke(title)
	local balance = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
	}, panel)

	local tabs = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, panel)
	UI.list(tabs, Enum.FillDirection.Horizontal, 6)

	-- Scrolls, so a long list (badges) never runs off a small screen.
	local list = Instance.new("ScrollingFrame")
	list.LayoutOrder = 4
	list.Size = UDim2.new(1, 0, 0, VISIBLE_ROWS * (ROW_HEIGHT + 6))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	UI.list(list, Enum.FillDirection.Vertical, 6)

	local close = UI.button({
		LayoutOrder = 5,
		Size = UDim2.fromOffset(140, 38),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "Close",
	}, panel)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local currentTab = Catalog.Slots[1] :: string
	local tabButtons: { [string]: TextButton } = {}

	local function clearList()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function row(order: number): Frame
		local frame = UI.frame({
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT), -- room for the scroll bar
			BackgroundColor3 = UI.Colors.PanelLight,
		}, list)
		UI.corner(frame, 10)
		return frame
	end

	local function itemRow(order: number, item: Catalog.Cosmetic, view: Types.ProfileView)
		local frame = row(order)
		local swatch = UI.frame({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = item.colors[1],
		}, frame)
		UI.corner(swatch, 14)
		UI.label({
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -220, 1, 0),
			Font = UI.Fonts.Heading,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = item.name,
		}, frame)

		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		local price = Catalog.price(item.id) or 0
		local affordable = view.cred >= price
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(160, 38),
			TextSize = 17,
			BackgroundColor3 = if wearing
				then UI.Colors.Gold
				elseif owned or affordable then UI.Colors.Money
				else UI.Colors.PanelLight,
			Text = if wearing then "WEARING (take off)" elseif owned then "WEAR" else `BUY {Format.number(price)}`,
		}, frame)
		button.Activated:Connect(function()
			if owned then
				remotes.EquipCosmetic:fire(item.id)
			else
				remotes.BuyCosmetic:fire(item.id)
			end
		end)
	end

	local function badgeRow(order: number, badge: Catalog.Badge, earned: boolean)
		local frame = row(order)
		UI.label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -130, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if earned then UI.Colors.Gold else UI.Colors.Text,
			Text = badge.name,
		}, frame)
		UI.label({
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -130, 0, 18),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = badge.text,
		}, frame)
		UI.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 24),
			Font = UI.Fonts.Heading,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if earned then UI.Colors.Money else UI.Colors.Muted,
			Text = if earned then "EARNED" else "Locked",
		}, frame)
	end

	local function render()
		local view = ProfileState.view
		if not view then
			return
		end
		balance.Text = `You have {Format.cred(view.cred)}. Win runs to earn more.`
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == currentTab then UI.Colors.Gold else UI.Colors.PanelLight
		end
		clearList()
		if currentTab == BADGES_TAB then
			for order, badge in Catalog.Badges do
				badgeRow(order, badge, table.find(view.badges, badge.id) ~= nil)
			end
			return
		end
		local order = 0
		for _, item in Catalog.Cosmetics do
			if item.slot == currentTab then
				order += 1
				itemRow(order, item, view)
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
			TextSize = 15,
			BackgroundColor3 = UI.Colors.PanelLight,
			Text = tab.text,
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
	ProfileState.changed:Connect(function(_view: Types.ProfileView)
		if panel.Visible then
			render()
		end
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
