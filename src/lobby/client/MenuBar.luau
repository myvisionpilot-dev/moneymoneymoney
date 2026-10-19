--!strict
-- The lobby's menu bar along the bottom of the screen, in the store look (StoreKit): Upgrades, a
-- big PLAY in the middle and Customise. PLAY asks how you want to play: SOLO goes straight to town; WITH OTHERS opens
-- FIND A LOBBY (LobbyBrowser) to join a lobby or host one. While you wait in a lobby, PLAY turns
-- into LEAVE with its countdown. The Shop button (ProfileHud, top left) and the + by your Cred
-- (bottom left) open the Shop, one window at a time like the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileHud = require(script.Parent.ProfileHud)
local ProfileState = require(script.Parent.ProfileState)
local QueueController = require(script.Parent.QueueController)
local ShopFrame = require(script.Parent.ShopFrame)

local SIDE_SIZE = Vector2.new(236, 68)
local PLAY_SIZE = Vector2.new(220, 84)
local GAP = 14
local BOTTOM = 14

local MenuBar = {}

-- Upgrades and cosmetics bought, added up (so a new purchase can ring the till).
local function boughtCount(view: Types.ProfileView): number
	local total = #view.owned
	for _, level in view.perks do
		total += level
	end
	return total
end

function MenuBar.start(
	root: Frame,
	upgrades: UI.Window,
	customise: UI.Window,
	browser: UI.Window,
	store: UI.Window,
	shopButtons: ProfileHud.Buttons,
	boosts: UI.Window
)
	local bar = UI.frame({
		Name = "MenuBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(SIDE_SIZE.X * 2 + PLAY_SIZE.X + GAP * 2, PLAY_SIZE.Y),
		BackgroundTransparency = 1,
	}, root)
	local layout = UI.list(bar, Enum.FillDirection.Horizontal, GAP)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	Cursor.registerPanel(bar)

	-- All three are glitter buttons (the user's reference): Upgrades blue, PLAY green, Customise purple.
	local upgradesButton = StoreKit.glitterIconButton("Upgrades", "Speed", StoreKit.Glitter.Blue, {
		Name = "Upgrades",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(SIDE_SIZE.X, SIDE_SIZE.Y),
	}, bar)
	local play = StoreKit.glitterButton(StoreKit.Glitter.Green, {
		Name = "PLAY",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(PLAY_SIZE.X, PLAY_SIZE.Y),
	}, bar)
	-- PLAY stays put: no squish when you point at it or press it.
	local squish = play:FindFirstChild("Squish")
	if squish then
		squish:Destroy()
	end
	local playText = StoreKit.glitterText(play, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 46,
		Text = "PLAY",
	})
	local playNote = StoreKit.glitterText(play, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -12, 0, 20),
		TextSize = 18,
		Text = "",
	})
	local customiseButton = StoreKit.glitterIconButton("Customise", "RaceCar", StoreKit.Glitter.Purple, {
		Name = "Customise",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(SIDE_SIZE.X, SIDE_SIZE.Y),
	}, bar)

	-- How do you want to play? Pops up over PLAY.
	local choice = StoreKit.window("How do you want to play?", {
		Name = "PlayChoice",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(520, 0),
	}, root)
	choice.title.TextSize = 26
	Cursor.registerPanel(choice.panel)
	UI.list(choice.body, Enum.FillDirection.Horizontal, 10)
	local function option(order: number, title: string, note: string, color: Color3): TextButton
		local button = UI.button({
			Name = title,
			LayoutOrder = order,
			Size = UDim2.new(0.5, -5, 0, 92),
			BackgroundColor3 = color,
			Text = "",
		}, choice.body)
		local heading = UI.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 36),
			FontFace = UI.Fonts.Button,
			TextSize = 30,
			Text = title,
		}, button)
		UI.textStroke(heading, 3)
		UI.label({
			Position = UDim2.fromOffset(8, 48),
			Size = UDim2.new(1, -16, 0, 36),
			TextSize = 14,
			Text = note,
		}, button)
		return button
	end
	local solo = option(1, "SOLO", "Just you. Off you go!", UI.Colors.Money)
	local group =
		option(2, "WITH OTHERS", `Find a lobby or host one: up to {Config.Match.MaxPlayers} players`, UI.Colors.Info)
	UI.shine(solo, 3, 12)
	UI.shine(group, 3.4, 12)

	local function closeAll(except: GuiObject?)
		for _, panel in { upgrades.panel, customise.panel, choice.panel, browser.panel, store.panel, boosts.panel } do
			if panel ~= except then
				panel.Visible = false
			end
		end
	end
	local function toggle(panel: GuiObject)
		local open = not panel.Visible
		closeAll(panel)
		panel.Visible = open
	end

	upgradesButton.Activated:Connect(function()
		toggle(upgrades.panel)
	end)
	customiseButton.Activated:Connect(function()
		toggle(customise.panel)
	end)
	for _, button in { shopButtons.shop, shopButtons.plus } do
		button.Activated:Connect(function()
			toggle(store.panel)
		end)
	end
	shopButtons.boosts.Activated:Connect(function()
		toggle(boosts.panel)
	end)
	play.Activated:Connect(function()
		local status = QueueController.status
		if status and status.leaving then
			return
		elseif status then
			QueueController.leave()
		else
			toggle(choice.panel)
		end
	end)
	solo.Activated:Connect(function()
		closeAll()
		QueueController.play({ mode = "Solo" })
	end)
	group.Activated:Connect(function()
		closeAll(browser.panel)
		browser.panel.Visible = true
	end)

	-- The group panel hides while a shop window is open (PLAY still shows the countdown).
	for _, panel in { upgrades.panel, customise.panel, store.panel, boosts.panel } do
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			QueueController.setHidden(
				upgrades.panel.Visible or customise.panel.Visible or store.panel.Visible or boosts.panel.Visible
			)
		end)
	end

	local function renderPlay(status: Types.QueueStatus?)
		if status and status.leaving then
			StoreKit.glitterPaint(play, StoreKit.Glitter.Gold)
			playText.Text = "GOING..."
			playText.TextSize = 30
			playText.Position = UDim2.new()
			playNote.Text = ""
		elseif status then
			StoreKit.glitterPaint(play, StoreKit.Glitter.Red)
			playText.Text = "LEAVE"
			playText.TextSize = 36
			playText.Position = UDim2.fromOffset(0, -10)
		else
			StoreKit.glitterPaint(play, StoreKit.Glitter.Green)
			playText.Text = "PLAY"
			playText.TextSize = 46
			playText.Position = UDim2.new()
			playNote.Text = ""
		end
	end
	QueueController.changed:Connect(function(status: Types.QueueStatus?)
		if status then
			choice.panel.Visible = false
			browser.panel.Visible = false
		end
		renderPlay(status)
	end)
	renderPlay(QueueController.status)

	RunService.RenderStepped:Connect(function()
		local status = QueueController.status
		if status and not status.leaving then
			playNote.Text = `{status.count}/{status.partySize}  ·  {Format.clock(QueueController.secondsLeft())}`
		end
	end)

	-- The till rings when you buy something.
	local bought = if ProfileState.view then boughtCount(ProfileState.view) else -1
	ProfileState.changed:Connect(function(view: Types.ProfileView)
		local count = boughtCount(view)
		if bought >= 0 and count > bought then
			Sounds.play("Purchase")
		end
		bought = count
	end)
end

return MenuBar
