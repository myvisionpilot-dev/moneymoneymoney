--!strict
-- Pick a hustle: three purple cards in the middle of the screen a few seconds into each new
-- quota. Click one and it lasts the rest of the run; when the timer runs out the server picks
-- one for you. The game keeps going while it's open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local CARD_HEIGHT = 128

local HustleController = {}

local function stackText(option: Types.HustleView): string
	if option.stacks > 0 then
		return `You have {option.stacks}/{option.max}`
	end
	return if option.max > 1 then `New! Stacks to {option.max}` else "New!"
end

function HustleController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Hustles", 40))

	local window = UI.window("PICK A HUSTLE", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(560, 0),
	}, root)
	local panel = window.panel
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local row = UI.frame({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,
	}, window.body)
	UI.list(row, Enum.FillDirection.Horizontal, 10)

	local countdown = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
	}, window.body)

	local offer: Types.HustleOffer? = nil

	local function close()
		offer = nil
		panel.Visible = false
	end

	local function card(option: Types.HustleView, index: number)
		local button = UI.button({
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -7, 1, 0),
			BackgroundColor3 = UI.Colors.Purple,
			Text = "",
		}, row)
		UI.padding(button, 8)
		UI.list(button, Enum.FillDirection.Vertical, 4)
		local title = UI.label({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Font = UI.Fonts.Heading,
			TextSize = 19,
			TextColor3 = UI.Colors.Gold,
			Text = option.title,
		}, button)
		UI.textStroke(title, 2.5)
		UI.label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), TextSize = 14, Text = option.detail }, button)
		UI.label({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 20),
			Font = UI.Fonts.Heading,
			TextSize = 14,
			TextColor3 = if option.stacks > 0 then UI.Colors.Money else UI.Colors.Muted,
			Text = stackText(option),
		}, button)
		button.Activated:Connect(function()
			if offer then
				remotes.PickHustle:fire(option.id)
				close()
			end
		end)
	end

	remotes.HustleOffer:onClient(function(newOffer: Types.HustleOffer?)
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
		for index, option in newOffer.options do
			card(option, index)
		end
		panel.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		local current = offer
		if current and panel.Visible then
			countdown.Text = `Lasts all run. A random one is picked in {Format.clock(current.endsAt - Timing.now())}`
		end
	end)
end

return HustleController
