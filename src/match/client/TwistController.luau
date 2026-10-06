--!strict
-- This quota's twists (Config.Twists) as purple checkered cards in the top-left corner. The town
-- event's card goes in the same column, below them (EventController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local CARD_WIDTH = 190

local TwistController = {}

local column: Frame? = nil

-- The column of cards in the top-left corner (made on first use).
function TwistController.column(): Frame
	local existing = column
	if existing then
		return existing
	end
	local root = UI.root(UI.screen("Twists", 2))
	local frame = UI.frame({
		Name = "Twists",
		Position = UDim2.fromOffset(8, 6), -- the top-left corner, clear of the quota panel
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, root)
	UI.list(frame, Enum.FillDirection.Vertical, 6)
	column = frame
	return frame
end

-- A checkered card in the given colour with a title and a detail line (the event card uses it
-- too). Returns the card, its two labels and the frame they sit in (to add more lines).
function TwistController.card(
	parent: Instance,
	name: string,
	order: number,
	color: Color3
): (Frame, TextLabel, TextLabel, Frame)
	local frame, content = UI.panel(color, {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent, 160)
	UI.padding(content, 8)
	local layout = UI.list(content, Enum.FillDirection.Vertical, 2)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local heading = UI.label({
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y, -- long titles wrap
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	local detail = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	return frame, heading, detail, content
end

local function card(parent: Instance, twist: Types.TwistView, order: number): Frame
	local frame, heading, detail = TwistController.card(parent, twist.id, order, UI.Colors.Purple)
	heading.Text = `TWIST: {twist.title}`
	detail.Text = twist.detail
	UI.pop(frame, 0.1)
	return frame
end

function TwistController.start()
	local frame = TwistController.column()
	local cards: { Frame } = {}

	local shown = ""
	local function render(snapshot: Types.RunSnapshot)
		local phase = snapshot.phase
		local visible = phase == "Quota" or phase == "Intermission" or phase == "Decision"
		local ids = {}
		for _, twist in snapshot.twists do
			table.insert(ids, twist.id)
		end
		local key = if visible then table.concat(ids, ",") else ""
		if key == shown then
			return
		end
		shown = key
		for _, old in cards do
			old:Destroy()
		end
		table.clear(cards)
		if key == "" then
			return
		end
		for index, twist in snapshot.twists do
			table.insert(cards, card(frame, twist, index))
		end
		Sounds.play("Open")
	end

	ClientState.changed:Connect(render)
	if ClientState.snapshot then
		render(ClientState.snapshot)
	end
end

return TwistController
