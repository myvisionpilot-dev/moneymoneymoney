--!strict
-- The UPGRADES window (menu bar): what Cred buys to help in every run.
--   Upgrades  levelled perks        Loadout  one-time unlocks for the start of a run
--   Badges    what you've earned
-- Each card shows a little 3D picture turning in front of light rays, what it does now and
-- next, and a buy button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))
local ProfileState = require(script.Parent.ProfileState)
local ShopFrame = require(script.Parent.ShopFrame)

local WINDOW_WIDTH = 700
local CARD_SIZE = UDim2.fromOffset(150, 214)
local CARD_GAP = 8
local ART_HEIGHT = 88

local TABS: { ShopFrame.Tab } = {
	{ key = "Upgrades", text = "Upgrades" },
	{ key = "Loadout", text = "Loadout" },
	{ key = "Badges", text = "Badges" },
}

local BLURBS = {
	Upgrades = "Kept for good, and they help in every run.",
	Loadout = "Start every run with a little extra.",
	Badges = "What you've done so far.",
}

-- A colour per card, so the grid isn't all one colour.
local CARD_COLORS = {
	Color3.fromRGB(70, 150, 230),
	Color3.fromRGB(235, 90, 110),
	Color3.fromRGB(60, 175, 90),
	Color3.fromRGB(245, 150, 40),
	Color3.fromRGB(150, 90, 240),
	Color3.fromRGB(40, 170, 170),
}

type CardSpec = {
	color: Color3,
	title: string,
	corner: string, -- top left of the picture: the level, or whether it's unlocked
	detail: string,
	picture: string,
	button: string,
	buttonColor: Color3,
	onPress: () -> (),
}

local UpgradesWindow = {}

function UpgradesWindow.start(root: Frame): UI.Window
	local remotes = Remotes.lobby()
	local currentTab = "Upgrades"
	local toTop = true -- a new tab, or the window just opened: start at the top of the list
	local render: () -> ()

	local shop = ShopFrame.new(root, "UPGRADES", WINDOW_WIDTH, TABS, function(key: string)
		currentTab = key
		toTop = true
		render()
	end)
	local window = shop.window
	UI.list(window.body, Enum.FillDirection.Vertical, 6)
	local blurb = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		Text = "",
	}, window.body)
	local list = ShopFrame.scroller({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 300) }, window.body)
	UI.padding(list, 4)
	local layout = UI.grid(list, CARD_SIZE, CARD_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local function clearList()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- A store-style card: picture with rays, name, what it does, and one button.
	local function card(order: number, spec: CardSpec)
		local _, frame = UI.panel(spec.color, { LayoutOrder = order }, list, CARD_SIZE.Y.Offset)
		local art = UI.frame({
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, ART_HEIGHT),
			BackgroundTransparency = 1,
		}, frame)
		UI.rays(art, 220, nil, 10)
		ItemModels.viewport(spec.picture, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, art, true)
		UI.label({
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0, 16),
			ZIndex = 3,
			FontFace = UI.Fonts.Heading,
			TextSize = 11,
			TextColor3 = UI.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = spec.corner,
		}, art)
		local title = UI.label({
			Position = UDim2.fromOffset(4, ART_HEIGHT + 8),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = UI.Fonts.Title,
			TextScaled = true,
			Text = spec.title,
		}, frame)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 18
		limit.Parent = title
		UI.label({
			Position = UDim2.fromOffset(6, ART_HEIGHT + 32),
			Size = UDim2.new(1, -12, 0, 44),
			TextSize = 12,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = spec.detail,
		}, frame)
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -7),
			Size = UDim2.new(1, -14, 0, 30),
			BackgroundColor3 = spec.buttonColor,
			TextSize = 16,
			Text = spec.button,
		}, frame)
		button.Activated:Connect(spec.onPress)
	end

	local function buyButton(view: Types.ProfileView, price: number, id: string): (string, Color3, () -> ())
		local text, color, affordable = ShopFrame.buyLook(view.cred, price)
		return text,
			color,
			function()
				if affordable then
					remotes.BuyCredItem:fire(id)
				else
					Sounds.play("Fail", 1, 0.6)
				end
			end
	end

	local function renderUpgrades(view: Types.ProfileView)
		for order, upgrade in Catalog.Upgrades do
			local level = view.perks[upgrade.id] or 0
			local maxLevel = Catalog.upgradeMax(upgrade.id)
			local price = Catalog.upgradePrice(upgrade.id, level)
			local now = if level > 0 then upgrade.effect(Catalog.upgradeAmount(upgrade.id, level)) else "Not yet"
			local nextUp = if price then upgrade.effect(Catalog.upgradeAmount(upgrade.id, level + 1)) else nil
			local text, color, press = "Maxed", UI.Colors.Grey, function() end
			if price then
				text, color, press = buyButton(view, price, upgrade.id)
			end
			card(order, {
				color = CARD_COLORS[order % #CARD_COLORS + 1],
				title = upgrade.name,
				corner = `LEVEL {level}/{maxLevel}`,
				detail = if nextUp then `Now: {now}\nNext: {nextUp}` else `{now} (max)`,
				picture = upgrade.picture,
				button = text,
				buttonColor = color,
				onPress = press,
			})
		end
	end

	local function renderLoadout(view: Types.ProfileView)
		for order, unlock in Catalog.Unlocks do
			local owned = (view.perks[unlock.id] or 0) > 0
			local text, color, press = "Unlocked", UI.Colors.PanelDark, function() end
			if not owned then
				text, color, press = buyButton(view, Catalog.unlockPrice(unlock.id) or 0, unlock.id)
			end
			card(order, {
				color = CARD_COLORS[(order + 2) % #CARD_COLORS + 1],
				title = unlock.name,
				corner = if owned then "OWNED" else "UNLOCK",
				detail = unlock.text,
				picture = unlock.picture,
				button = text,
				buttonColor = color,
				onPress = press,
			})
		end
	end

	local function renderBadges(view: Types.ProfileView)
		for order, badge in Catalog.Badges do
			local earned = table.find(view.badges, badge.id) ~= nil
			local badgePanel, frame = UI.panel(
				if earned then UI.Colors.Gold else UI.Colors.Grey,
				{ LayoutOrder = order },
				list,
				CARD_SIZE.Y.Offset
			)
			if earned then
				UI.shine(badgePanel, 3 + math.random() * 2, 12)
			end
			UI.label({
				Position = UDim2.fromOffset(4, 10),
				Size = UDim2.new(1, -8, 0, 40),
				FontFace = UI.Fonts.Title,
				TextSize = 16,
				Text = badge.name,
			}, frame)
			UI.label({
				Position = UDim2.fromOffset(6, 56),
				Size = UDim2.new(1, -12, 1, -100),
				TextSize = 13,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = badge.text,
			}, frame)
			UI.label({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -10, 0, 24),
				FontFace = UI.Fonts.Title,
				TextSize = 16,
				Text = if earned then "EARNED" else "LOCKED",
			}, frame)
		end
	end

	function render()
		local view = ProfileState.view
		if not view or not window.panel.Visible then
			return
		end
		shop.cred.Text = Format.cred(view.cred)
		blurb.Text = BLURBS[currentTab] or ""
		ShopFrame.showTab(shop, currentTab)
		list.Size = UDim2.new(1, 0, 0, shop.bodyHeight() - 24)
		local scroll = if toTop then Vector2.zero else list.CanvasPosition
		toTop = false
		clearList()
		if currentTab == "Upgrades" then
			renderUpgrades(view)
		elseif currentTab == "Loadout" then
			renderLoadout(view)
		else
			renderBadges(view)
		end
		list.CanvasPosition = scroll -- buying something shouldn't jump you back to the top
	end

	window.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		toTop = true
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
