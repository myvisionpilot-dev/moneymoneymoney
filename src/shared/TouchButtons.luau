--!strict
-- Big round buttons for touch screens (both places), stacked up beside Roblox's jump button so
-- the right thumb finds them. Callers only add them on touch devices (TouchButtons.enabled).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local GAP = 10
local SIZE_OF_JUMP = 0.85 -- our buttons are a little smaller than the jump button
local FALLBACK_SIZE = 70 -- before Roblox's touch controls appear
local FALLBACK_RIGHT = 110
local FALLBACK_BOTTOM = 20
local LAYOUT_SECONDS = 0.5

export type TouchButton = {
	button: TextButton,
	icon: TextLabel,
	label: TextLabel,
	order: number,
}

local TouchButtons = {}

local gui: ScreenGui? = nil
local buttons: { TouchButton } = {}

function TouchButtons.enabled(): boolean
	return UserInputService.TouchEnabled
end

local function jumpButton(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	return if jump and jump:IsA("GuiObject") then jump else nil
end

-- Beside the jump button (it keeps its place even while hidden in a kart), then upward.
local function layout()
	local screen = gui
	if not screen then
		return
	end
	local size: number, right: number, bottom: number
	local jump = jumpButton()
	local touchGui = jump and jump:FindFirstAncestorOfClass("ScreenGui")
	if jump and touchGui then
		screen.IgnoreGuiInset = touchGui.IgnoreGuiInset -- same origin, so positions line up
		size = jump.AbsoluteSize.X * SIZE_OF_JUMP
		right = jump.AbsolutePosition.X - GAP
		bottom = jump.AbsolutePosition.Y + jump.AbsoluteSize.Y
	else
		size = FALLBACK_SIZE
		right = screen.AbsoluteSize.X - FALLBACK_RIGHT
		bottom = screen.AbsoluteSize.Y - FALLBACK_BOTTOM
	end
	table.sort(buttons, function(a, b)
		return a.order < b.order
	end)
	local slot = 0
	for _, entry in buttons do
		if entry.button.Visible then
			entry.button.Size = UDim2.fromOffset(size, size)
			entry.button.Position = UDim2.fromOffset(right - size, bottom - size - slot * (size + GAP))
			slot += 1
		end
	end
end

local function getGui(): ScreenGui
	local existing = gui
	if existing then
		return existing
	end
	local created = Instance.new("ScreenGui")
	created.Name = "TouchButtons"
	created.ResetOnSpawn = false
	created.DisplayOrder = 5
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created
	task.spawn(function()
		while true do
			layout() -- cheap, and catches the touch controls appearing or the screen rotating
			task.wait(LAYOUT_SECONDS)
		end
	end)
	return created
end

-- A round button with a word on it (and a short glyph above it, if given: "" for none). Lower
-- `order` sits nearer the jump button.
function TouchButtons.add(icon: string, text: string, order: number, onPress: () -> ()): TouchButton
	local button = UI.button({
		Name = text,
		BackgroundColor3 = UI.Colors.Panel,
		Text = "",
		AutoButtonColor = false,
	}, getGui())
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	local iconLabel = UI.label({
		Position = UDim2.fromScale(0.15, 0.08),
		Size = UDim2.fromScale(0.7, 0.52),
		TextScaled = true,
		Text = icon,
	}, button)
	local label = UI.label({
		Position = if icon == "" then UDim2.fromScale(0.1, 0.35) else UDim2.fromScale(0.1, 0.6),
		Size = if icon == "" then UDim2.fromScale(0.8, 0.3) else UDim2.fromScale(0.8, 0.26),
		FontFace = UI.Fonts.Button,
		TextScaled = true,
		Text = text,
	}, button)
	button.Activated:Connect(onPress)
	local entry: TouchButton = { button = button, icon = iconLabel, label = label, order = order }
	table.insert(buttons, entry)
	button:GetPropertyChangedSignal("Visible"):Connect(layout)
	layout()
	return entry
end

return TouchButtons
