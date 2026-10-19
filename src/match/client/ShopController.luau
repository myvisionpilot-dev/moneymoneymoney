--!strict
-- Every shop's window (bags, hardware, convenience stores, Tony's crates): a store window
-- with the shop's name (and a little picture of what it sells) over the top edge, the cash in
-- your bag, and a store card per item: its name, a little 3D model turning in sunburst rays,
-- what it does and its price on a button.
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
local CARD_SIZE = UDim2.fromOffset(140, 214)
local CARD_GAP = 10
local ART_TOP = 28
local ART_HEIGHT = 86
local MIN_WIDTH = 460 -- room for the longest shop name
local CHROME_WIDTH = 40 -- the window's frame and the inset's padding

local CARD_COLORS: { [string]: Color3 } = {
	Bag = Color3.fromRGB(235, 70, 110),
	Lockpick = Color3.fromRGB(245, 150, 30),
	Energy = Color3.fromRGB(70, 190, 50),
	Disguise = Color3.fromRGB(240, 185, 20),
	Candy = Color3.fromRGB(245, 120, 40),
	Gloves = Color3.fromRGB(150, 85, 240),
	Scanner = Color3.fromRGB(40, 170, 130),
	LuckyCrate = Color3.fromRGB(215, 135, 55),
	GoldCrate = Color3.fromRGB(235, 175, 25),
	DiamondCrate = Color3.fromRGB(70, 185, 235),
}

local ShopController = {}

-- A store card: the name on top, the item turning in sunburst rays, what it does, and its
-- price on a button (green when you can afford it).
local function card(
	parent: Instance,
	order: number,
	item: Types.ShopItem,
	carried: number,
	locked: boolean,
	onBuy: () -> ()
)
	local _, frame = UI.itemCard(
		CARD_COLORS[item.id] or UI.Colors.Info,
		{ LayoutOrder = order },
		parent,
		(ART_TOP + ART_HEIGHT / 2) / CARD_SIZE.Y.Offset
	)
	local title = UI.label({
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0, 26),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		Text = item.title,
	}, frame)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = title
	UI.textStroke(title, 2.8)

	local art = UI.frame({
		Position = UDim2.fromOffset(6, ART_TOP),
		Size = UDim2.new(1, -12, 0, ART_HEIGHT),
		BackgroundTransparency = 1,
	}, frame)
	ItemModels.viewport(item.id, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, art, true)
	UI.label({
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -4, 0, 16),
		ZIndex = 3,
		FontFace = UI.Fonts.Heading,
		TextSize = 12,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.status or "",
	}, art)

	UI.label({
		Position = UDim2.fromOffset(6, ART_TOP + ART_HEIGHT + 2),
		Size = UDim2.new(1, -12, 0, 56),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = item.kind == "Crate", -- a crate's odds, each rarity in its colour
		Text = item.detail,
	}, frame)

	local price = item.price
	local canBuy = price ~= nil and not locked and carried >= price
	local buy = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -14, 0, 34),
		BackgroundColor3 = if canBuy then UI.Colors.Money else UI.Colors.Grey,
	}, frame)
	if price then
		UI.price(buy, "$", Format.number(price))
	else
		UI.price(buy, nil, if item.kind == "Upgrade" then "MAXED" else "YOURS")
	end
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
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(MIN_WIDTH, 0),
	}, root, true)
	local panel = window.panel
	window.title.TextSize = 38
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	-- The note, with the cash in your bag on the right.
	local top = UI.frame({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
	}, window.body)
	local note = UI.label({
		Size = UDim2.new(1, -170, 1, 0),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, top)
	local bagPill = UI.pill("$", UI.Colors.Money, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(160, 34),
	}, top)
	local lockedBanner = UI.card(UI.Colors.Danger, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		Visible = false,
	}, window.body)
	local lockedText = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 16 }, lockedBanner)
	local cards = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, window.body)
	UI.grid(cards, CARD_SIZE, CARD_GAP)

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
		window.icon:ClearAllChildren()
		if state.items[1] then
			ItemModels.viewport(state.items[1].id, { Size = UDim2.fromScale(1, 1) }, window.icon, true)
		end
		bagPill.Text = Format.number(carried)
		note.Text = state.note
		lockedBanner.Visible = state.locked ~= nil
		-- One row of cards: the window is as wide as they need.
		local across = #state.items * (CARD_SIZE.X.Offset + CARD_GAP) - CARD_GAP + CHROME_WIDTH
		panel.Size = UDim2.fromOffset(math.max(MIN_WIDTH, across), 0)
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
