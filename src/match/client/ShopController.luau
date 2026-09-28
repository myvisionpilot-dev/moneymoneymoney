--!strict
-- The upgrade shop: opens from the counter in the hardware store. Paid from the cash in your bag.
-- One colourful card per upgrade; walking away closes it.

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
local CARD_SIZE = UDim2.fromOffset(134, 178)

local LOOKS: { [string]: { icon: string, color: Color3 } } = {
	Bag = { icon = "🎒", color = UI.Colors.Pink },
	Lockpick = { icon = "🔑", color = UI.Colors.Risk },
	Ride = { icon = "🏎️", color = UI.Colors.Purple },
}

local ShopController = {}

function ShopController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Shop", 45))

	local window = UI.window("🛒 UPGRADES", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(460, 0),
	}, root, true)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local bagPill = UI.pill("💵", UI.Colors.Money, { LayoutOrder = 1, Size = UDim2.fromOffset(220, 34) }, window.body)
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextColor3 = UI.Colors.Text,
		Text = "Paid from your bag, never your deposits. Upgrades last this run.",
	}, window.body)
	local cards = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, CARD_SIZE.Y.Offset),
		BackgroundTransparency = 1,
	}, window.body)
	UI.grid(cards, CARD_SIZE, 8)

	local function card(order: number, item: Types.ShopItem, carried: number)
		local look = LOOKS[item.id] or { icon = "⭐", color = UI.Colors.Info }
		local frame = UI.card(look.color, { LayoutOrder = order }, cards)
		UI.label(
			{ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), TextSize = 34, Text = look.icon },
			frame
		)
		UI.label({
			Position = UDim2.fromOffset(6, 44),
			Size = UDim2.new(1, -12, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 18,
			Text = item.title,
		}, frame)
		UI.label({
			Position = UDim2.fromOffset(6, 66),
			Size = UDim2.new(1, -12, 0, 18),
			TextSize = 14,
			TextColor3 = UI.Colors.Gold,
			Text = `Level {item.level}/{item.maxLevel}`,
		}, frame)
		UI.label({
			Position = UDim2.fromOffset(6, 84),
			Size = UDim2.new(1, -12, 0, 40),
			TextSize = 13,
			Text = if item.nextEffect then `{item.current}\n➡️ {item.nextEffect}` else `{item.current}\n(max)`,
		}, frame)

		local price = item.nextPrice
		local affordable = price ~= nil and carried >= price
		local buy = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 36),
			BackgroundColor3 = if affordable then UI.Colors.Money else UI.Colors.Grey,
			TextSize = 17,
			Text = if price then `BUY {Format.money(price)}` else "MAXED",
		}, frame)
		buy.Activated:Connect(function()
			if price then
				remotes.BuyUpgrade:fire(item.id)
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
		bagPill.Text = `{Format.money(carried)} in your bag`
		for order, item in state.items do
			card(order, item, carried)
		end
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase == "Results" or snapshot.phase == "Ended" then
			panel.Visible = false
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
