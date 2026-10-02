--!strict
-- Every shop's window (clothes, hardware, garage, convenience stores, Tony's blasters): the
-- server sends what that shop sells, and we show one colourful card per item. Paid from the
-- cash in your bag; walking away from the counter closes it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COUNTER_TAG = "ShopCounter"
local CLOSE_SLACK = 6
local CARD_SIZE = UDim2.fromOffset(134, 196)

local CARD_COLORS: { [string]: Color3 } = {
	Bag = UI.Colors.Pink,
	Lockpick = UI.Colors.Risk,
	Ride = UI.Colors.Purple,
	Energy = UI.Colors.Gold,
	Disguise = UI.Colors.Grey,
	Candy = UI.Colors.Pink,
	Gloves = UI.Colors.Risk,
	Scanner = UI.Colors.Info,
	Zapper = UI.Colors.Info,
	MegaZapper = UI.Colors.Purple,
}

local ShopController = {}

function ShopController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Shop", 45))

	local window = UI.window("", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(460, 0),
	}, root, true)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local bagPill = UI.pill("💵", UI.Colors.Money, { LayoutOrder = 1, Size = UDim2.fromOffset(220, 34) }, window.body)
	local note = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
	}, window.body)
	local lockedBanner = UI.card(UI.Colors.Danger, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 34),
		Visible = false,
	}, window.body)
	local lockedText = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 15 }, lockedBanner)
	local cards = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, window.body)
	UI.grid(cards, CARD_SIZE, 8)

	local function card(order: number, item: Types.ShopItem, carried: number, locked: boolean)
		local frame = UI.card(CARD_COLORS[item.id] or UI.Colors.Info, { LayoutOrder = order }, cards)
		UI.label(
			{ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), TextSize = 34, Text = item.icon },
			frame
		)
		UI.label({
			Position = UDim2.fromOffset(6, 44),
			Size = UDim2.new(1, -12, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 17,
			Text = item.title,
		}, frame)
		UI.label({
			Position = UDim2.fromOffset(6, 66),
			Size = UDim2.new(1, -12, 0, 18),
			TextSize = 13,
			TextColor3 = UI.Colors.Gold,
			Text = item.status or "",
		}, frame)
		UI.label({
			Position = UDim2.fromOffset(6, 86),
			Size = UDim2.new(1, -12, 0, 58),
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = item.detail,
		}, frame)

		local price = item.price
		local canBuy = price ~= nil and not locked and carried >= price
		local buy = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 36),
			BackgroundColor3 = if canBuy then UI.Colors.Money else UI.Colors.Grey,
			TextSize = 17,
			Text = if price then `BUY {Format.money(price)}` elseif item.kind == "Upgrade" then "MAXED" else "YOURS",
		}, frame)
		buy.Activated:Connect(function()
			if price and not locked then
				remotes.BuyItem:fire(item.id)
			end
		end)
	end

	remotes.ShopOpen:onClient(function(state: Types.ShopState)
		for _, child in cards:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local me = ClientState.me()
		local carried = if me then me.carried else 0
		window.title.Text = state.title
		bagPill.Text = `{Format.money(carried)} in your bag`
		note.Text = state.note
		lockedBanner.Visible = state.locked ~= nil
		lockedText.Text = state.locked or ""
		for order, item in state.items do
			card(order, item, carried, state.locked ~= nil)
		end
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase == "Results" or snapshot.phase == "Ended" then
			panel.Visible = false
		end
		local me = ClientState.me()
		if panel.Visible and me then
			bagPill.Text = `{Format.money(me.carried)} in your bag` -- stays right after you buy something
		end
	end)

	-- Walking away from the counter closes the shop.
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if not panel.Visible or not character then
			return
		end
		local position = character:GetPivot().Position
		for _, counter in CollectionService:GetTagged(COUNTER_TAG) do
			if
				counter:IsA("BasePart")
				and (counter.Position - position).Magnitude <= Config.Shop.RangeStuds + CLOSE_SLACK
			then
				return
			end
		end
		panel.Visible = false
	end)
end

return ShopController
