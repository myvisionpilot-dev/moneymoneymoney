--!strict
-- Stacked pop-up notices on the right side of the screen (left on touch screens; client only):
-- checkered cards in the shop style, blue for info, green for good news, red for bad.

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Types)
local UI = require(script.Parent.UI)

local SHOW_SECONDS = 3.5
local MAX_TOASTS = 4

local Toasts = {}

local stack: Frame? = nil

local KIND_COLORS: { [Types.NoticeKind]: Color3 } = {
	Info = UI.Colors.Panel,
	Good = Color3.fromRGB(60, 175, 75),
	Bad = UI.Colors.Danger,
}

local function getStack(): Frame
	if stack then
		return stack
	end
	local root = UI.root(UI.screen("Toasts", 60))
	-- On touch screens the right side belongs to the jump and Sprint buttons, so use the left.
	local touch = UserInputService.TouchEnabled
	local frame = UI.frame({
		Name = "Stack",
		AnchorPoint = Vector2.new(if touch then 0 else 1, 0.5),
		Position = if touch then UDim2.new(0, 10, 0.62, 0) else UDim2.new(1, -10, 0.64, 0),
		Size = UDim2.fromOffset(270, 240),
		BackgroundTransparency = 1,
	}, root)
	local layout = UI.list(frame, Enum.FillDirection.Vertical, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = if touch then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
	stack = frame
	return frame
end

function Toasts.show(text: string, kind: Types.NoticeKind)
	local frame = getStack()

	local toasts = {}
	for _, child in frame:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		toasts[1]:Destroy()
	end

	-- A checkered card in the kind's colour; it slides out to the side when it's done.
	local toast = UI.frame({
		Name = "Toast",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = os.clock() * 1000 // 1,
	}, frame)
	local card, content = UI.panel(KIND_COLORS[kind], {
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, toast, 120)
	UI.padding(content, 9)
	UI.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	UI.pop(toast, 0.06)

	task.delay(SHOW_SECONDS, function()
		if toast.Parent then
			local away = if UserInputService.TouchEnabled then -300 else 300
			UI.tween(card, 0.3, { Position = UDim2.fromOffset(away, 0) })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

return Toasts
