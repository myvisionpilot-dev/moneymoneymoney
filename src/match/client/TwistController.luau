--!strict
-- This quota's twists (Config.Twists) as purple cards just left of the quota panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local CARD_WIDTH = 200

local TwistController = {}

local function card(parent: Instance, twist: Types.TwistView, order: number)
	local frame = UI.card(UI.Colors.Purple, {
		Name = twist.id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	UI.padding(frame, 8)
	UI.list(frame, Enum.FillDirection.Vertical, 2)
	local heading = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = UI.Fonts.Heading,
		TextSize = 20,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `TWIST: {twist.title}`,
	}, frame)
	UI.textStroke(heading, 2.5)
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = twist.detail,
	}, frame)
	UI.pop(frame, 0.2)
end

function TwistController.start()
	local root = UI.root(UI.screen("Twists", 2))
	local column = UI.frame({
		Name = "Twists",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -178, 0, 6), -- the quota panel is 340 wide, centred
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, root)
	UI.list(column, Enum.FillDirection.Vertical, 6)

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
		for _, child in column:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if key == "" then
			return
		end
		for index, twist in snapshot.twists do
			card(column, twist, index)
		end
		Sounds.play("Open")
	end

	ClientState.changed:Connect(render)
	if ClientState.snapshot then
		render(ClientState.snapshot)
	end
end

return TwistController
