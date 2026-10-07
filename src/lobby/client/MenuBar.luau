--!strict
-- The lobby's menu bar along the bottom of the screen: UPGRADES, a big PLAY in the middle and
-- CUSTOMISATION. PLAY asks how you want to play: SOLO goes straight to town; WITH OTHERS opens
-- FIND A LOBBY (LobbyBrowser) to join a lobby or host one. While you wait in a lobby, PLAY turns
-- into LEAVE with its countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)
local QueueController = require(script.Parent.QueueController)
local ShopFrame = require(script.Parent.ShopFrame)

local SIDE_SIZE = Vector2.new(236, 68)
local PLAY_SIZE = Vector2.new(220, 84)
local GAP = 14
local BOTTOM = 14

local MenuBar = {}

-- A side button: a little 3D picture on the left, its name on the right.
local function sideButton(order: number, text: string, color: Color3, picture: string, bar: Frame): TextButton
	local button = UI.button({
		Name = text,
		LayoutOrder = order,
		Size = UDim2.fromOffset(SIDE_SIZE.X, SIDE_SIZE.Y),
		BackgroundColor3 = color,
		Text = "",
	}, bar)
	ItemModels.viewport(picture, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
	}, button, true)
	local label = UI.label({
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(1, -74, 1, 0),
		FontFace = UI.Fonts.Button,
		TextScaled = true,
		Text = text,
	}, button)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.Parent = label
	UI.textStroke(label, 2.5)
	return button
end

-- Upgrades and cosmetics bought, added up (so a new purchase can ring the till).
local function boughtCount(view: Types.ProfileView): number
	local total = #view.owned
	for _, level in view.perks do
		total += level
	end
	return total
end

function MenuBar.start(root: Frame, upgrades: UI.Window, customise: UI.Window, browser: UI.Window)
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

	local upgradesButton = sideButton(1, "UPGRADES", UI.Colors.Info, "Speed", bar)
	local play = UI.button({
		Name = "PLAY",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(PLAY_SIZE.X, PLAY_SIZE.Y),
		BackgroundColor3 = UI.Colors.Money,
		Text = "",
	}, bar)
	-- PLAY stays put: no squish when you point at it or press it.
	local squish = play:FindFirstChild("Squish")
	if squish then
		squish:Destroy()
	end
	local playText = UI.label({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = 44,
		Text = "PLAY",
	}, play)
	UI.textStroke(playText, 3.5)
	local playNote = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 20),
		FontFace = UI.Fonts.Number,
		TextSize = 17,
		Text = "",
	}, play)
	local customiseButton = sideButton(3, "CUSTOMISATION", UI.Colors.Purple, "RaceCar", bar)
	-- The side buttons catch the light now and then (PLAY stays still).
	UI.shine(upgradesButton, 4, 12)
	UI.shine(customiseButton, 4.7, 12)

	-- How do you want to play? Pops up over PLAY.
	local choice = UI.window("HOW DO YOU WANT TO PLAY?", {
		Name = "PlayChoice",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(480, 0),
	}, root, true)
	choice.title.TextSize = 22
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
		for _, panel in { upgrades.panel, customise.panel, choice.panel, browser.panel } do
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
	for _, panel in { upgrades.panel, customise.panel } do
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			QueueController.setHidden(upgrades.panel.Visible or customise.panel.Visible)
		end)
	end

	local function renderPlay(status: Types.QueueStatus?)
		if status and status.leaving then
			play.BackgroundColor3 = UI.Colors.Gold
			playText.Text = "GOING..."
			playText.TextSize = 30
			playText.Position = UDim2.new()
			playNote.Text = ""
		elseif status then
			play.BackgroundColor3 = UI.Colors.Danger
			playText.Text = "LEAVE"
			playText.TextSize = 36
			playText.Position = UDim2.fromOffset(0, -10)
		else
			play.BackgroundColor3 = UI.Colors.Money
			playText.Text = "PLAY"
			playText.TextSize = 44
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
