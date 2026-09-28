--!strict
-- Stacked pop-up notices on the right side of the screen (client only): bright outlined cards
-- that bounce in.

local Types = require(script.Parent.Types)
local UI = require(script.Parent.UI)

local SHOW_SECONDS = 3.5
local MAX_TOASTS = 4

local Toasts = {}

local stack: Frame? = nil

local KIND_COLORS: { [Types.NoticeKind]: Color3 } = {
	Info = UI.Colors.Panel,
	Good = UI.Colors.Money,
	Bad = UI.Colors.Danger,
}

local KIND_ICONS: { [Types.NoticeKind]: string } = {
	Info = "💬",
	Good = "✅",
	Bad = "⚠️",
}

local function getStack(): Frame
	if stack then
		return stack
	end
	local root = UI.root(UI.screen("Toasts", 60))
	local frame = UI.frame({
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.64, 0),
		Size = UDim2.fromOffset(270, 240),
		BackgroundTransparency = 1,
	}, root)
	local layout = UI.list(frame, Enum.FillDirection.Vertical, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
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

	local toast = UI.card(KIND_COLORS[kind], {
		Name = "Toast",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = os.clock() * 1000 // 1,
	}, frame)
	UI.padding(toast, 8)
	local label = UI.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = `{KIND_ICONS[kind]} {text}`,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, toast)
	UI.pop(toast, 0.1)

	task.delay(SHOW_SECONDS, function()
		if toast.Parent then
			UI.tween(toast, 0.3, { BackgroundTransparency = 1 })
			UI.tween(label, 0.3, { TextTransparency = 1 })
			for _, child in toast:GetDescendants() do
				if child:IsA("UIStroke") then
					UI.tween(child, 0.3, { Transparency = 1 })
				end
			end
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

return Toasts
