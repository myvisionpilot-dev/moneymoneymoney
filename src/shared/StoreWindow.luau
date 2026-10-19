--!strict
-- The Shop window (client, both places: the lobby's Shop button and the + by your Cred, and the
-- Shop button under the status panel in a run): what Robux buys, on one long screen you scroll,
-- in the store look (StoreKit):
--   -- CRED --      Cred packs (developer products): three small cards, two bigger, one wide
--   -- STRENGTH --  Strength packs, bought with Cred, laid out the same: a glove punches,
--                   embers rise, and your Strength (and its tier) is in the heading
--   -- FEATURED --  the packs (Big Baller in gold, the Rainbow Pack in rainbow)
--   -- PASSES --    every other game pass, two to a row
-- Each card has its picture in a white glow, a pink gift button and a green Robux price. A card
-- whose Config.Store id is still 0 says SOON; the rest show their price (asked of Roblox) and
-- open Roblox's purchase prompt. A Cred pack lands as Cred (serverCommon/Purchases) and a pass
-- shows OWNED (the Pass_ attributes from serverCommon/Passes); either way the window cheers.
-- StoreFx brings it to life: money raining onto piles on the three biggest Cred packs, twinkles,
-- sparkle bursts, the flowing Rainbow Pack, gold glints, floating pictures and more.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Cursor = require(script.Parent.Cursor)
local Format = require(script.Parent.Format)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)
local StoreFx = require(script.Parent.StoreFx)
local Strength = require(script.Parent.Strength)
local StoreKit = require(script.Parent.StoreKit)
local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local WINDOW_WIDTH = 760
local CHROME = StoreKit.HEADER_HEIGHT + 34 -- the title bar, the body's padding and the outline
local TOP_GAP = 12
local MIN_BODY, MAX_BODY = 232, 470
local GAP = 12
local SMALL_HEIGHT, BIG_HEIGHT, PASS_HEIGHT = 236, 256, 196
local BUY_HEIGHT = 46
local STRENGTH_COLOR = Color3.fromRGB(255, 95, 30)
local STRENGTH_BIG = Color3.fromRGB(235, 45, 55)
local ASKING, FAILED = -1, -2 -- a price we're still asking Roblox for, or couldn't get

-- The passes' card colours (featured packs have their own).
local PASS_COLORS = { -- strong, saturated colours
	Color3.fromRGB(20, 135, 255),
	Color3.fromRGB(255, 50, 135),
	Color3.fromRGB(255, 135, 0),
	Color3.fromRGB(140, 55, 255),
	Color3.fromRGB(0, 200, 185),
	Color3.fromRGB(240, 35, 50),
	Color3.fromRGB(80, 205, 0),
	Color3.fromRGB(50, 80, 255),
	Color3.fromRGB(225, 40, 225),
}

-- 100 -> "100", 25000 -> "25K", 100000 -> "100K".
local function compact(amount: number): string
	if amount >= 1_000_000 then
		return `{Format.number(amount / 1_000_000)}M`
	elseif amount >= 1_000 then
		return `{Format.number(amount / 1_000)}K`
	end
	return Format.number(amount)
end

local StoreWindow = {}

-- `bottom` is how much of the screen to leave free under the window (the lobby's menu bar).
function StoreWindow.start(root: Frame, bottom: number): UI.Window
	local player = Players.LocalPlayer
	local window = StoreKit.window("Shop", {
		Name = "Store",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -bottom),
		Size = UDim2.fromOffset(WINDOW_WIDTH, 0),
	}, root)
	Cursor.registerPanel(window.panel)
	-- As tall as the screen allows (in the UI's own pixels, before scaling).
	local function bodyHeight(): number
		local scale = root:FindFirstChildOfClass("UIScale")
		local virtual = root.AbsoluteSize.Y / (if scale then scale.Scale else 1)
		return math.clamp(math.floor(virtual - bottom - CHROME - TOP_GAP), MIN_BODY, MAX_BODY)
	end
	local list = StoreKit.scroller({ Size = UDim2.new(1, 0, 0, 300) }, window.body)
	local padding = UI.padding(list, 6)
	padding.PaddingRight = UDim.new(0, 14) -- room for the scroll bar
	UI.list(list, Enum.FillDirection.Vertical, GAP)
	-- Specks of light drifting up behind the cards (a fixed-size frame, so they can't stretch the body).
	local motesArea = UI.frame({
		Name = "Motes",
		Size = UDim2.new(1, 0, 0, 300),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
	}, window.body)
	local fx = StoreFx.new(window.panel, list)
	fx.motes(motesArea, 22)
	fx.shimmer(window.title)
	local intro = false -- the Shop is opening: the cards pop in
	local cardOrder = 0
	-- What every card gets: it lifts when you point at it, and pops in when the Shop opens.
	local function liven(card: Frame)
		fx.lift(card)
		if intro then
			cardOrder += 1
			fx.popIn(card, cardOrder)
		end
	end

	-- Robux prices, asked of Roblox once each ("Product:123" / "GamePass:456"); a label waiting
	-- for one is filled in when it comes.
	local prices: { [string]: number } = {}
	local waiting: { [string]: { TextLabel } } = {}
	local function priceText(price: number): string
		return if price == FAILED then "BUY" else Format.number(price)
	end
	local function showPrice(label: TextLabel, kind: Enum.InfoType, id: number)
		local key = `{kind.Name}:{id}`
		local price = prices[key]
		if price and price ~= ASKING then
			label.Text = priceText(price)
			return
		end
		label.Text = "..."
		waiting[key] = waiting[key] or {}
		table.insert(waiting[key], label)
		if price == ASKING then
			return
		end
		prices[key] = ASKING
		task.spawn(function()
			local ok, info = pcall(function(): any
				return MarketplaceService:GetProductInfo(id, kind)
			end)
			local robux = ok and typeof(info) == "table" and info.PriceInRobux
			prices[key] = if typeof(robux) == "number" then robux else FAILED
			local labels = waiting[key]
			if labels then
				for _, waitingLabel in labels do
					if waitingLabel.Parent then
						waitingLabel.Text = priceText(prices[key])
					end
				end
			end
			waiting[key] = nil
		end)
	end

	local function owns(key: string): boolean
		return player:GetAttribute(`Pass_{key}`) == true
	end

	local function soon()
		Sounds.play("Fail", 1, 0.6)
		Toasts.show("Coming soon!", "Info")
	end

	-- The gift button and the price along the bottom of a card.
	local function buyRow(content: Frame, kind: Enum.InfoType, id: number, owned: boolean, onBuy: () -> ())
		local gift = StoreKit.giftButton({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -10),
			Size = UDim2.fromOffset(56, BUY_HEIGHT),
		}, content)
		gift.Activated:Connect(function()
			Toasts.show("Gifting is coming soon!", "Info")
		end)
		fx.wiggle(gift)
		local buy = StoreKit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.new(1, -86, 0, BUY_HEIGHT),
			BackgroundColor3 = UI.Colors.PanelDark,
			Text = "",
		}, content)
		if not owned then
			StoreKit.lime(buy)
			UI.shine(buy, 4 + math.random() * 2.5, 8)
		end
		if owned then
			StoreKit.iconText(buy, nil, "OWNED", 24)
		elseif id > 0 then
			showPrice(StoreKit.iconText(buy, StoreKit.Images.Robux, "...", 26), kind, id)
		else
			StoreKit.iconText(buy, nil, "SOON", 24)
		end
		buy.Activated:Connect(function()
			if owned then
				return
			elseif id > 0 then
				onBuy()
			else
				soon()
			end
		end)
	end

	-- A Cred pack: the picture big in its glow, "25K CRED" over its bottom edge, then the buttons.
	-- The big ones (`big`) have money raining down their sides onto piles of cash.
	local function credCard(pack: Config.CredPack, width: UDim, height: number, row: Frame, big: boolean)
		local card, content = StoreKit.card(StoreKit.Colors.Green, {
			Size = UDim2.new(width, UDim.new(1, 0)),
		}, row, Vector2.new(0.5, 0.36), height * 1.6)
		liven(card)
		local art = height - BUY_HEIGHT - 30
		local picture = StoreKit.image(StoreKit.art(pack.picture), {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(art, art),
			ZIndex = 3,
		}, content)
		fx.float(picture)
		fx.twinkle(card, if big then 6 else 4, "white")
		if big then
			fx.rain(card, height - BUY_HEIGHT - 10, width.Scale >= 1)
		end
		if pack.tag then
			fx.gold(card) -- the best value glints
			fx.burst(card, Vector2.new(0.5, 0.36), "gold")
		end
		-- The amount sits over the bottom of the picture, like a price tag on the pile.
		StoreKit.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -BUY_HEIGHT - 12),
			Size = UDim2.new(1, -12, 0, 38),
			TextSize = 32,
			Text = `{compact(pack.cred)} CRED`,
			ZIndex = 4,
		}, content)
		if pack.tag then
			local ribbon = UI.frame({
				Position = UDim2.fromOffset(-6, 10),
				Size = UDim2.fromOffset(150, 30),
				Rotation = -8,
				BackgroundColor3 = UI.Colors.Danger,
				ZIndex = 5,
			}, content)
			UI.corner(ribbon, 6)
			UI.stroke(ribbon, 3)
			StoreKit.label({ Size = UDim2.fromScale(1, 1), TextSize = 18, Text = pack.tag, ZIndex = 6 }, ribbon)
			fx.pulse(ribbon)
		end
		buyRow(content, Enum.InfoType.Product, pack.id, false, function()
			MarketplaceService:PromptProductPurchase(player, pack.id)
		end)
	end

	-- A Strength pack: its picture big in its glow (throwing a punch now and then),
	-- embers rising, "+150 STRENGTH" over its bottom edge, then the buttons.
	local function strengthCard(
		index: number,
		pack: Config.StrengthPack,
		width: UDim,
		height: number,
		row: Frame,
		big: boolean
	)
		local color = if big then STRENGTH_BIG else STRENGTH_COLOR
		local card, content = StoreKit.card(color, {
			Size = UDim2.new(width, UDim.new(1, 0)),
		}, row, Vector2.new(0.5, 0.36), height * 1.6)
		if pack.tag then
			StoreKit.paint(card, StoreKit.GoldColors)
		end
		liven(card)
		local art = height - BUY_HEIGHT - 30
		local picture = StoreKit.image(StoreKit.art(pack.picture), {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(art, art),
			ZIndex = 3,
		}, content)
		fx.float(picture)
		fx.punch(picture, Color3.fromRGB(255, 230, 120))
		fx.embers(card, if big then 16 else 9)
		fx.twinkle(card, if big then 6 else 3, "fire")
		if big then
			fx.burst(card, Vector2.new(0.5, 0.36), "fire")
		end
		if pack.tag then
			fx.gold(card)
			fx.burst(card, Vector2.new(0.5, 0.36), "gold")
		end
		StoreKit.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -BUY_HEIGHT - 12),
			Size = UDim2.new(1, -12, 0, 38),
			TextSize = 30,
			Text = `+{compact(pack.strength)} STRENGTH`,
			ZIndex = 4,
		}, content)
		if pack.tag then
			local ribbon = UI.frame({
				Position = UDim2.fromOffset(-6, 10),
				Size = UDim2.fromOffset(150, 30),
				Rotation = -8,
				BackgroundColor3 = UI.Colors.Danger,
				ZIndex = 5,
			}, content)
			UI.corner(ribbon, 6)
			UI.stroke(ribbon, 3)
			StoreKit.label({ Size = UDim2.fromScale(1, 1), TextSize = 18, Text = pack.tag, ZIndex = 6 }, ribbon)
			fx.pulse(ribbon)
		end
		-- The price in Cred, on a button as wide as the card (lime when you can afford it).
		local balance = player:GetAttribute("CredBalance")
		local afford = typeof(balance) == "number" and balance >= pack.price
		local buy = StoreKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, BUY_HEIGHT),
			BackgroundColor3 = UI.Colors.PanelDark,
			Text = "",
		}, content)
		if afford then
			StoreKit.lime(buy)
			UI.shine(buy, 4 + math.random() * 2.5, 8)
		end
		StoreKit.iconText(buy, StoreKit.Images.CredCoin, Format.number(pack.price), 26)
		buy.Activated:Connect(function()
			local now = player:GetAttribute("CredBalance")
			if typeof(now) ~= "number" or now < pack.price then
				Sounds.play("Fail", 1, 0.6)
				Toasts.show("Not enough Cred!", "Bad")
				return
			end
			local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyStrength") :: RemoteEvent
			remote:FireServer(index)
		end)
	end

	-- A pass: its picture on the left, the name and what it does on the right, then the buttons.
	local function passCard(pass: Config.Pass, color: Color3, row: Frame)
		local owned = owns(pass.key)
		local card, content = StoreKit.card(color, {
			Size = UDim2.new(0.5, -GAP / 2, 1, 0),
		}, row, Vector2.new(0.17, 0.4), 300)
		if pass.featured == "Gold" then
			StoreKit.paint(card, StoreKit.GoldColors)
		elseif pass.featured == "Rainbow" then
			StoreKit.paint(card, StoreKit.Rainbow)
		end
		liven(card)
		if pass.featured then
			UI.shine(card, 3 + math.random(), 8)
			local tint: StoreFx.Tint = if pass.featured == "Rainbow" then "rainbow" else "gold"
			if pass.featured == "Rainbow" then
				fx.rainbow(card) -- its colours flow, and a rainbow runs round its edge
			else
				fx.gold(card)
			end
			fx.twinkle(card, 8, tint)
			fx.burst(card, Vector2.new(0.17, 0.4), tint)
		else
			fx.twinkle(card, 3, "white")
		end
		local art = PASS_HEIGHT - BUY_HEIGHT - 30
		local picture = StoreKit.image(StoreKit.art(pass.picture), {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(art, art),
			ZIndex = 3,
		}, content)
		fx.float(picture)
		local title = StoreKit.label({
			Position = UDim2.fromOffset(art + 16, 8),
			Size = UDim2.new(1, -art - 24, 0, 36),
			TextScaled = true,
			Text = pass.name,
			ZIndex = 4,
		}, content)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 30
		limit.Parent = title
		UI.textStroke(title, 3)
		local detail = StoreKit.label({
			Position = UDim2.fromOffset(art + 16, 48),
			Size = UDim2.new(1, -art - 24, 0, PASS_HEIGHT - BUY_HEIGHT - 66),
			FontFace = StoreKit.Fonts.ExtraBold,
			TextScaled = true,
			TextWrapped = true,
			RichText = true,
			Text = StoreKit.highlight(pass.text),
			ZIndex = 4,
		}, content)
		local detailLimit = Instance.new("UITextSizeConstraint")
		detailLimit.MaxTextSize = 22
		detailLimit.Parent = detail
		UI.textStroke(detail, 2.5)
		if owned then
			local tag = StoreKit.label({
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(90, 22),
				TextSize = 16,
				TextColor3 = StoreKit.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "OWNED",
				ZIndex = 5,
			}, content)
			UI.textStroke(tag, 2)
		end
		buyRow(content, Enum.InfoType.GamePass, pass.id, owned, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
	end

	local function clear()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function render()
		if not window.panel.Visible then
			return
		end
		list.Size = UDim2.new(1, 0, 0, bodyHeight())
		motesArea.Size = list.Size
		cardOrder = 0
		local scroll = list.CanvasPosition
		clear()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		fx.shimmer(StoreKit.section("CRED", nextOrder(), list, StoreKit.Colors.GreenLight))
		local packs = Config.Store.CredPacks
		local rows = { { 1, 2, 3 }, { 4, 5 }, { 6 } }
		for _, indices in rows do
			local count = #indices
			local height = if count == 3 then SMALL_HEIGHT else BIG_HEIGHT
			local row = StoreKit.row(nextOrder(), height, GAP, list)
			for _, index in indices do
				local pack = packs[index]
				if pack then
					local big = index > #packs - 3 -- the three biggest
					credCard(pack, UDim.new(1 / count, -GAP * (count - 1) / count), height, row, big)
				end
			end
		end

		local mine = Strength.of(player)
		local _, tier = Strength.tier(mine)
		local heading = StoreKit.section(
			`STRENGTH: {Format.number(mine)} ({(tier.name:gsub("!", ""))})`,
			nextOrder(),
			list,
			STRENGTH_COLOR
		)
		fx.shimmer(heading)
		local strengthPacks = Config.Store.StrengthPacks
		for _, indices in rows do
			local count = #indices
			local height = if count == 3 then SMALL_HEIGHT else BIG_HEIGHT
			local row = StoreKit.row(nextOrder(), height, GAP, list)
			for _, index in indices do
				local pack = strengthPacks[index]
				if pack then
					local big = index > #strengthPacks - 3
					strengthCard(index, pack, UDim.new(1 / count, -GAP * (count - 1) / count), height, row, big)
				end
			end
		end

		local featured, others = {}, {}
		for _, pass in Config.Store.Passes do
			table.insert(if pass.featured then featured else others, pass)
		end
		local function passRows(title: string, passes: { Config.Pass }, colorFrom: number)
			if #passes == 0 then
				return
			end
			fx.shimmer(StoreKit.section(title, nextOrder(), list))
			for index = 1, #passes, 2 do
				local row, layout = StoreKit.row(nextOrder(), PASS_HEIGHT, GAP, list)
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				for offset = 0, 1 do
					local pass = passes[index + offset]
					if pass then
						passCard(pass, PASS_COLORS[(colorFrom + index + offset - 2) % #PASS_COLORS + 1], row)
					end
				end
			end
		end
		passRows("FEATURED", featured, 1)
		passRows("PASSES", others, 1)
		list.CanvasPosition = scroll -- buying something shouldn't jump you back to the top
	end

	-- Something bought: stars off the window, a banner and a cheer. Once: a pack sets several
	-- passes at the same moment.
	local lastCheer = 0
	local function celebrate(title: string, subtitle: string)
		if os.clock() - lastCheer < 1 then
			return
		end
		lastCheer = os.clock()
		local panel = window.panel
		ScreenFx.flash(UI.Colors.Gold, 0.18)
		ScreenFx.stars(panel.AbsolutePosition + panel.AbsoluteSize / 2, 26, UI.Colors.Gold)
		ScreenFx.banner(title, UI.Colors.Gold, subtitle, 1.8, 0.2)
		Sounds.play("Purchase")
		Sounds.play("Milestone")
	end

	window.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.panel.Visible then
			list.CanvasPosition = Vector2.zero
			intro = true
		end
		render()
		intro = false
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			if not purchased or userId ~= player.UserId then
				return
			end
			for _, pack in Config.Store.CredPacks do
				if pack.id > 0 and pack.id == productId then
					celebrate(`+{Format.number(pack.cred)} CRED!`, "Spend it in Upgrades or Customise")
				end
			end
		end
	)
	local lastStrength: number? = Strength.of(player)
	player.AttributeChanged:Connect(function(name: string)
		if name == "Strength" then
			local now = Strength.of(player)
			if lastStrength and now > lastStrength and window.panel.Visible then
				celebrate(`+{Format.number(now - lastStrength)} STRENGTH!`, "Your shove hits harder")
			end
			lastStrength = now
			render()
			return
		elseif name == "CredBalance" then
			render() -- what you can afford
			return
		end
		if name:sub(1, 5) ~= "Pass_" then
			return
		end
		render()
		local key = name:sub(6)
		if owns(key) and window.panel.Visible then
			for _, pass in Config.Store.Passes do
				if pass.key == key then
					celebrate("UNLOCKED!", pass.name)
				end
			end
		end
	end)
	return window
end

return StoreWindow
