--!strict
-- The door offer: the resident's greeting and their two jobs as big cards (green = legal,
-- orange = illegal), each with pay and heat, plus Walk away. Sits at the bottom so you can see
-- who answered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local OPTION_HEIGHT = 150

-- An emoji for a job, from words in its title.
local ICONS: { { word: string, icon: string } } = {
	{ word = "dog", icon = "🐕" },
	{ word = "letter", icon = "✉️" },
	{ word = "wallet", icon = "👛" },
	{ word = "package", icon = "📦" },
	{ word = "break", icon = "🔓" },
	{ word = "mow", icon = "🌱" },
	{ word = "lawn", icon = "🌱" },
	{ word = "bin", icon = "🗑️" },
	{ word = "wash", icon = "🧽" },
}

local function iconFor(option: Types.DoorOfferOption): string
	local title = option.title:lower()
	for _, entry in ICONS do
		if title:find(entry.word, 1, true) then
			return entry.icon
		end
	end
	return if option.legal then "🧹" else "🦹"
end

local DoorController = {}

function DoorController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("DoorOffer", 35))

	local window = UI.window("🚪", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(480, 0),
	}, root)
	local panel = window.panel
	FirstPerson.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local greeting = UI.label({
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
	}, window.body)

	local row = UI.frame({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
		BackgroundTransparency = 1,
	}, window.body)
	UI.list(row, Enum.FillDirection.Horizontal, 10)

	local footer = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
	}, window.body)
	local walkAway = UI.button({
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = UI.Colors.Grey,
		TextSize = 18,
		Text = "Walk away",
	}, footer)
	local countdown = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -160, 1, 0),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, footer)

	local offer: Types.DoorOffer? = nil

	local function close()
		offer = nil
		panel.Visible = false
	end

	local function choose(slot: number)
		if offer then
			remotes.ChooseDoorOffer:fire(slot)
			close()
		end
	end

	walkAway.Activated:Connect(function()
		choose(0)
	end)

	local function optionCard(option: Types.DoorOfferOption)
		local card = UI.button({
			LayoutOrder = option.slot,
			Size = UDim2.new(0.5, -5, 1, 0),
			BackgroundColor3 = if option.legal then UI.Colors.Money else UI.Colors.Risk,
			Text = "",
		}, row)
		UI.padding(card, 8)
		UI.list(card, Enum.FillDirection.Vertical, 2)
		UI.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), TextSize = 30, Text = iconFor(option) }, card)
		UI.label({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 18,
			Text = option.title,
		}, card)
		UI.label({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 36),
			TextSize = 13,
			Text = option.detail,
		}, card)
		local risk = if option.heat > 0 then `🚨 +{option.heat} heat` else "😇 No heat"
		UI.label({
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 17,
			TextColor3 = UI.Colors.Gold,
			Text = `💵 {Format.money(option.pay)}  ·  {risk}`,
		}, card)
		card.Activated:Connect(function()
			choose(option.slot)
		end)
	end

	remotes.DoorOffer:onClient(function(newOffer: Types.DoorOffer?)
		for _, child in row:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		if not newOffer then
			close()
			return
		end
		offer = newOffer
		window.title.Text = `🚪 {newOffer.residentName}`
		greeting.Text = `"{newOffer.greeting}"`
		for _, option in newOffer.options do
			optionCard(option)
		end
		panel.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		local current = offer
		if current and panel.Visible then
			countdown.Text = `⏳ Door closes in {Format.clock(current.expiresAt - Timing.now())}`
		end
	end)
end

return DoorController
