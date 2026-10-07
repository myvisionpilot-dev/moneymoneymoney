--!strict
-- Every shop's window (bags, hardware, garage, convenience stores, Tony's blasters), in the
-- store style: a checkered header with the cash in your bag, and a colourful card per item: a
-- little 3D model turning in front of spinning light rays, its name, price and a Buy button.
-- Opened by "Buy" in the shopkeeper's conversation (CounterService). Paid from your bag;
-- walking away from the counter closes it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COUNTER_TAG = "ShopCounter"
local CLOSE_SLACK = 6
local CARD_SIZE = UDim2.fromOffset(154, 206)
local ART_HEIGHT = 84
local WINDOW_WIDTH = 520

local CARD_COLORS: { [string]: Color3 } = {
	Bag = Color3.fromRGB(235, 70, 110),
	Lockpick = Color3.fromRGB(245, 150, 40),
	Energy = Color3.fromRGB(240, 70, 70),
	Disguise = Color3.fromRGB(245, 190, 40),
	Candy = Color3.fromRGB(245, 130, 50),
	Gloves = Color3.fromRGB(150, 90, 240),
	Scanner = Color3.fromRGB(60, 170, 120),
	Zapper = Color3.fromRGB(40, 150, 230),
	MegaZapper = Color3.fromRGB(220, 70, 180),
}

local ShopController = {}

local function card(
	parent: Instance,
	order: number,
	item: Types.ShopItem,
	carried: number,
	locked: boolean,
	onBuy: () -> ()
)
	local _, frame =
		UI.panel(CARD_COLORS[item.id] or UI.Colors.Info, { LayoutOrder = order }, parent, CARD_SIZE.Y.Offset)

	-- The picture: the item turning slowly in front of spinning light rays.
	local art = UI.frame({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, ART_HEIGHT),
		BackgroundTransparency = 1,
	}, frame)
	UI.rays(art, 220, nil, 10)
	ItemModels.viewport(item.id, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, art, true)
	UI.label({
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 16),
		ZIndex = 3,
		TextSize = 12,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.status or "",
	}, art)

	local title = UI.label({
		Position = UDim2.fromOffset(4, ART_HEIGHT + 6),
		Size = UDim2.new(1, -8, 0, 22),
		FontFace = UI.Fonts.Title,
		TextSize = 18,
		TextWrapped = false,
		TextScaled = false,
		Text = item.title,
	}, frame)
	UI.textStroke(title, 2.5)

	-- The price, centred: a coin and the number.
	local price = item.price
	local priceRow = UI.frame({
		Position = UDim2.fromOffset(0, ART_HEIGHT + 28),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
	}, frame)
	local rowLayout = UI.list(priceRow, Enum.FillDirection.Horizontal, 5)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	if price then
		UI.iconCircle("$", UI.Colors.Gold, 18, { LayoutOrder = 1 }, priceRow)
	end
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = UI.Fonts.Number,
		TextSize = 18,
		TextWrapped = false,
		Text = if price then Format.number(price) else "",
	}, priceRow)

	UI.label({
		Position = UDim2.fromOffset(6, ART_HEIGHT + 52),
		Size = UDim2.new(1, -12, 0, 34),
		TextSize = 11,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.detail,
	}, frame)

	local canBuy = price ~= nil and not locked and carried >= price
	local buy = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -14, 0, 30),
		BackgroundColor3 = if canBuy then UI.Colors.Money else UI.Colors.Grey,
		TextSize = 19,
		Text = if price then "Buy" elseif item.kind == "Upgrade" then "Maxed" else "Yours",
	}, frame)
	buy.Activated:Connect(function()
		if price and not locked then
			onBuy()
		end
	end)
	if canBuy then
		UI.shine(buy, 2.4 + order * 0.3, 12) -- what you can afford catches the light
	end
end

function ShopController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Shop", 45))

	local window = UI.window("", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(WINDOW_WIDTH, 0),
	}, root, true)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local header = window.title.Parent :: Frame
	local bagPill = UI.pill("$", UI.Colors.Money, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(150, 32),
	}, header)
	window.title.Size = UDim2.new(1, -220, 1, 0)

	local note = UI.label({
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
	}, window.body)
	local lockedBanner = UI.card(UI.Colors.Danger, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		Visible = false,
	}, window.body)
	local lockedText = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 15 }, lockedBanner)
	local cards = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, window.body)
	UI.grid(cards, CARD_SIZE, 10)

	-- What you just tried to buy, and how it looked before: if it's changed when the shop comes
	-- back, the purchase went through and gets its moment.
	local lastBuy: { id: string, before: string, at: number }? = nil
	local function look(item: Types.ShopItem): string
		return `{item.status or ""}|{item.price or 0}`
	end

	remotes.ShopOpen:onClient(function(state: Types.ShopState)
		local attempt = lastBuy
		lastBuy = nil
		if attempt and os.clock() - attempt.at < 3 then
			for _, item in state.items do
				if item.id == attempt.id and look(item) ~= attempt.before then
					ScreenFx.stars(panel.AbsolutePosition + panel.AbsoluteSize / 2, 24, UI.Colors.Gold)
					ScreenFx.banner("PURCHASED!", UI.Colors.Money, item.title, 1.3, 0.2)
				end
			end
		end
		for _, child in cards:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local me = ClientState.me()
		local carried = if me then me.carried else 0
		window.title.Text = state.title
		bagPill.Text = Format.number(carried)
		note.Text = state.note
		lockedBanner.Visible = state.locked ~= nil
		lockedText.Text = state.locked or ""
		for order, item in state.items do
			card(cards, order, item, carried, state.locked ~= nil, function()
				lastBuy = { id = item.id, before = look(item), at = os.clock() }
				remotes.BuyItem:fire(item.id)
			end)
		end
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase == "Results" or snapshot.phase == "Ended" then
			panel.Visible = false
		end
		local me = ClientState.me()
		if panel.Visible and me then
			bagPill.Text = Format.number(me.carried) -- stays right after you buy something
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
