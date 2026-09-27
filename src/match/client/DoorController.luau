--!strict
-- The door offer panel: the resident's greeting and their two jobs (chore or wildcard),
-- each showing pay and heat, plus Walk away. Sits at the bottom so you can see who answered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local OPTION_HEIGHT = 124

local DoorController = {}

function DoorController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("DoorOffer", 35))

	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(470, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 12)
	FirstPerson.registerPanel(panel)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local name = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Font = UI.Fonts.Heading,
		TextSize = 24,
		TextColor3 = UI.Colors.Gold,
	}, panel)
	UI.textStroke(name)
	local greeting = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
	}, panel)

	local row = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
		BackgroundTransparency = 1,
	}, panel)
	UI.list(row, Enum.FillDirection.Horizontal, 10)

	local footer = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
	}, panel)
	local walkAway = UI.button({
		Size = UDim2.fromOffset(140, 36),
		BackgroundColor3 = UI.Colors.PanelLight,
		TextSize = 18,
		Text = "Walk away",
	}, footer)
	local countdown = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -150, 1, 0),
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

	local function optionButton(option: Types.DoorOfferOption)
		local button = UI.button({
			LayoutOrder = option.slot,
			Size = UDim2.new(0.5, -5, 1, 0),
			BackgroundColor3 = if option.legal then UI.Colors.Money else UI.Colors.Risk,
			Text = "",
		}, row)
		UI.padding(button, 8)
		UI.list(button, Enum.FillDirection.Vertical, 4)
		local title = UI.label({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 18,
			Text = option.title,
		}, button)
		UI.textStroke(title)
		UI.label({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 52),
			TextSize = 13,
			Text = option.detail,
		}, button)
		local risk = if option.heat > 0 then `+{option.heat} heat` else "No heat"
		local payLine = UI.label({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 20),
			Font = UI.Fonts.Heading,
			TextSize = 16,
			Text = `{Format.money(option.pay)}  ·  {risk}`,
		}, button)
		UI.textStroke(payLine)
		button.Activated:Connect(function()
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
		name.Text = newOffer.residentName
		greeting.Text = `"{newOffer.greeting}"`
		for _, option in newOffer.options do
			optionButton(option)
		end
		panel.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		local current = offer
		if current and panel.Visible then
			countdown.Text = `Door closes in {Format.clock(current.expiresAt - Timing.now())}`
		end
	end)
end

return DoorController
