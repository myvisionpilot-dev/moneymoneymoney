--!strict
-- The Upgrades window (menu bar): what Cred buys to help in every run, on one long screen you
-- scroll, in the store look (StoreKit):
--   -- UPGRADES --  levelled perks          -- LOADOUT --  one-time unlocks for the start of a run
--   -- BADGES --    what you've earned
-- Every card has its own colour, its little 3D picture turning in a white glow, its level as a
-- row of bars, what it does now and next, and its Cred price on a big green button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)
local ShopFrame = require(script.Parent.ShopFrame)

local WINDOW_WIDTH = 760
local GAP = 12
local CARD_HEIGHT = 300
local BADGE_HEIGHT = 170
local PER_ROW = 3
local BUTTON_HEIGHT = 46

-- A colour per card, so no two neighbours look the same.
local CARD_COLORS = {
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(255, 96, 150),
	Color3.fromRGB(64, 214, 56),
	Color3.fromRGB(255, 156, 40),
	Color3.fromRGB(160, 100, 255),
	Color3.fromRGB(40, 200, 190),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(90, 120, 255),
	Color3.fromRGB(230, 90, 230),
}

type CardSpec = {
	color: Color3,
	title: string,
	picture: string, -- ItemModels id
	level: number?, -- shows the level bars when set (with max)
	max: number?,
	corner: string?, -- top left, in gold: OWNED, UNLOCK
	detail: string, -- rich text
	price: number?, -- a Cred price, or...
	word: string?, -- ...a word (MAXED, UNLOCKED)
	onPress: () -> (),
}

local UpgradesWindow = {}

function UpgradesWindow.start(root: Frame): UI.Window
	local remotes = Remotes.lobby()
	local shop = ShopFrame.new(root, "Upgrades", WINDOW_WIDTH, {}, function() end)
	local window = shop.window
	local list = ShopFrame.scroller({ Size = UDim2.new(1, 0, 0, 300) }, window.body)
	local padding = UI.padding(list, 6)
	padding.PaddingRight = UDim.new(0, 14)
	UI.list(list, Enum.FillDirection.Vertical, GAP)

	local function clear()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- The level as a row of bars: gold for each level you have.
	local function levelBars(level: number, max: number, parent: Instance)
		local bars = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 158),
			Size = UDim2.new(1, -40, 0, 16),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, parent)
		local layout = UI.list(bars, Enum.FillDirection.Horizontal, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		for index = 1, max do
			local bar = UI.frame({
				LayoutOrder = index,
				Size = UDim2.new(1 / max, -4, 1, 0),
				BackgroundColor3 = if index <= level then StoreKit.Colors.Gold else UI.Colors.PanelDark,
				ZIndex = 4,
			}, bars)
			UI.corner(bar, 4)
			UI.stroke(bar, 2.5)
		end
	end

	local function card(spec: CardSpec, cred: number, row: Frame)
		local _, content = StoreKit.card(spec.color, {
			Size = UDim2.new(1 / PER_ROW, -GAP * (PER_ROW - 1) / PER_ROW, 1, 0),
		}, row, Vector2.new(0.5, 0.33), 360)
		local title = StoreKit.label({
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 32),
			TextScaled = true,
			Text = spec.title,
			ZIndex = 4,
		}, content)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 26
		limit.Parent = title
		UI.textStroke(title, 3)
		ItemModels.viewport(spec.picture, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(112, 112),
			ZIndex = 3,
		}, content, true)
		if spec.corner then
			local corner = StoreKit.label({
				Position = UDim2.fromOffset(8, 40),
				Size = UDim2.fromOffset(90, 20),
				TextSize = 15,
				TextColor3 = StoreKit.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = spec.corner,
				ZIndex = 5,
			}, content)
			UI.textStroke(corner, 2)
		end
		if spec.level and spec.max then
			levelBars(spec.level, spec.max, content)
		end
		local detail = StoreKit.label({
			Position = UDim2.fromOffset(8, if spec.level then 180 else 160),
			Size = UDim2.new(1, -16, 0, if spec.level then 56 else 76),
			FontFace = StoreKit.Fonts.ExtraBold,
			TextScaled = true,
			TextWrapped = true,
			RichText = true,
			Text = spec.detail,
			ZIndex = 4,
		}, content)
		local detailLimit = Instance.new("UITextSizeConstraint")
		detailLimit.MaxTextSize = 18
		detailLimit.Parent = detail
		UI.textStroke(detail, 2.2)
		local button = StoreKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, BUTTON_HEIGHT),
			Text = "",
		}, content)
		if spec.price then
			ShopFrame.priceButton(button, cred, spec.price)
		else
			ShopFrame.wordButton(button, spec.word or "", UI.Colors.PanelDark)
		end
		button.Activated:Connect(spec.onPress)
	end

	local function buy(view: Types.ProfileView, price: number, id: string): () -> ()
		return function()
			if view.cred >= price then
				remotes.BuyCredItem:fire(id)
			else
				Sounds.play("Fail", 1, 0.6)
			end
		end
	end

	-- Cards dealt into rows of three.
	local function grid(specs: { CardSpec }, height: number, cred: number, nextOrder: () -> number)
		local row: Frame? = nil
		for index, spec in specs do
			if (index - 1) % PER_ROW == 0 then
				local made, layout = StoreKit.row(nextOrder(), height, GAP, list)
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				row = made
			end
			if row then
				card(spec, cred, row)
			end
		end
	end

	local function render()
		local view = ProfileState.view
		if not view or not window.panel.Visible then
			return
		end
		shop.cred.Text = Format.number(view.cred)
		list.Size = UDim2.new(1, 0, 0, shop.bodyHeight())
		local scroll = list.CanvasPosition
		clear()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		StoreKit.section("UPGRADES", nextOrder(), list)
		local upgrades: { CardSpec } = {}
		for index, upgrade in Catalog.Upgrades do
			local level = view.perks[upgrade.id] or 0
			local max = Catalog.upgradeMax(upgrade.id)
			local price = Catalog.upgradePrice(upgrade.id, level)
			local now = if level > 0 then upgrade.effect(Catalog.upgradeAmount(upgrade.id, level)) else "Not yet"
			local nextUp = if price then upgrade.effect(Catalog.upgradeAmount(upgrade.id, level + 1)) else nil
			table.insert(upgrades, {
				color = CARD_COLORS[(index - 1) % #CARD_COLORS + 1],
				title = upgrade.name,
				picture = upgrade.picture,
				level = level,
				max = max,
				detail = if nextUp
					then StoreKit.highlight(if level > 0 then `Now: {now}\nNext: [{nextUp}]` else `Next: [{nextUp}]`)
					else `{now} (max)`,
				price = price,
				word = if price then nil else "MAXED",
				onPress = if price then buy(view, price, upgrade.id) else function() end,
			})
		end
		grid(upgrades, CARD_HEIGHT, view.cred, nextOrder)

		StoreKit.section("LOADOUT", nextOrder(), list)
		local unlocks: { CardSpec } = {}
		for index, unlock in Catalog.Unlocks do
			local owned = (view.perks[unlock.id] or 0) > 0
			local price = Catalog.unlockPrice(unlock.id) or 0
			table.insert(unlocks, {
				color = CARD_COLORS[(index + 3) % #CARD_COLORS + 1],
				title = unlock.name,
				picture = unlock.picture,
				corner = if owned then "OWNED" else nil,
				detail = unlock.text,
				price = if owned then nil else price,
				word = if owned then "UNLOCKED" else nil,
				onPress = if owned then function() end else buy(view, price, unlock.id),
			})
		end
		grid(unlocks, CARD_HEIGHT - 20, view.cred, nextOrder)

		StoreKit.section("BADGES", nextOrder(), list)
		local row: Frame? = nil
		for index, badge in Catalog.Badges do
			if (index - 1) % PER_ROW == 0 then
				local made, layout = StoreKit.row(nextOrder(), BADGE_HEIGHT, GAP, list)
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				row = made
			end
			local earned = table.find(view.badges, badge.id) ~= nil
			local badgeCard, content = StoreKit.card(if earned then UI.Colors.Gold else UI.Colors.Grey, {
				Size = UDim2.new(1 / PER_ROW, -GAP * (PER_ROW - 1) / PER_ROW, 1, 0),
			}, row, Vector2.new(0.5, 0.3), 260)
			if earned then
				StoreKit.paint(badgeCard, StoreKit.GoldColors)
				UI.shine(badgeCard, 3 + math.random() * 2, 8)
			end
			local name = StoreKit.label({
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 30),
				TextScaled = true,
				Text = badge.name,
				ZIndex = 4,
			}, content)
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 24
			limit.Parent = name
			UI.textStroke(name, 3)
			local text = StoreKit.label({
				Position = UDim2.fromOffset(8, 42),
				Size = UDim2.new(1, -16, 1, -100),
				FontFace = StoreKit.Fonts.ExtraBold,
				TextScaled = true,
				TextWrapped = true,
				Text = badge.text,
				ZIndex = 4,
			}, content)
			local textLimit = Instance.new("UITextSizeConstraint")
			textLimit.MaxTextSize = 17
			textLimit.Parent = text
			UI.textStroke(text, 2)
			local state = StoreKit.button({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 40),
				Active = false,
				AutoButtonColor = false,
				Text = "",
			}, content)
			ShopFrame.wordButton(
				state,
				if earned then "EARNED" else "LOCKED",
				if earned then StoreKit.Colors.Lime else UI.Colors.PanelDark
			)
		end
		list.CanvasPosition = scroll -- buying something shouldn't jump you back to the top
	end

	window.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.panel.Visible then
			list.CanvasPosition = Vector2.zero
		end
		render()
	end)
	local lastCred: number? = nil
	local lastPerks: { [string]: number }? = nil
	-- A new level or unlock: stars off the window, a banner and a cheer.
	local function celebrate(title: string, subtitle: string)
		local panel = window.panel
		ScreenFx.flash(UI.Colors.Gold, 0.18)
		ScreenFx.stars(panel.AbsolutePosition + panel.AbsoluteSize / 2, 22, UI.Colors.Gold)
		ScreenFx.banner(title, UI.Colors.Gold, subtitle, 1.6, 0.2)
		Sounds.play("Milestone")
	end
	ProfileState.changed:Connect(function(view: Types.ProfileView)
		render()
		if window.panel.Visible and lastCred and lastCred ~= view.cred then
			UI.pop(shop.cred, 0.3)
		end
		lastCred = view.cred
		local before = lastPerks
		if before and window.panel.Visible then
			for _, upgrade in Catalog.Upgrades do
				local level = view.perks[upgrade.id] or 0
				if level > (before[upgrade.id] or 0) then
					celebrate("UPGRADED!", `{upgrade.name} · level {level}`)
				end
			end
			for _, unlock in Catalog.Unlocks do
				if (view.perks[unlock.id] or 0) > 0 and (before[unlock.id] or 0) == 0 then
					celebrate("UNLOCKED!", unlock.name)
				end
			end
		end
		lastPerks = table.clone(view.perks)
	end)
	return window
end

return UpgradesWindow
