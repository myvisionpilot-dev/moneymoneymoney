--!strict
-- Client side of first person (both places): a tiny white dot crosshair, and a free mouse
-- while a clickable panel is open. Walking and sprinting live in Movement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DOT_SIZE = 4

local FirstPerson = {}

local panels: { GuiObject } = {}
local unlockGui: ScreenGui? = nil

local function getUnlockGui(): ScreenGui
	local existing = unlockGui
	if existing then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MouseUnlock"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	unlockGui = gui
	return gui
end

-- A panel with buttons: while it's showing, the mouse is freed so players can click it.
-- (A visible GuiButton with Modal = true unlocks the mouse in first person.)
function FirstPerson.registerPanel(panel: GuiObject)
	local unlock = Instance.new("TextButton")
	unlock.Name = panel.Name
	unlock.BackgroundTransparency = 1
	unlock.Text = ""
	unlock.Size = UDim2.fromOffset(1, 1)
	unlock.Selectable = false
	unlock.Modal = true
	unlock.Visible = panel.Visible
	unlock.Parent = getUnlockGui()
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		unlock.Visible = panel.Visible
	end)
	table.insert(panels, panel)
end

local function anyPanelOpen(): boolean
	for _, panel in panels do
		if panel.Visible then
			return true
		end
	end
	return false
end

local function makeCrosshair(): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true -- true centre of the screen, where first person aims
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local outline = Instance.new("UIStroke") -- faint, so the dot still shows on white walls
	outline.Thickness = 1
	outline.Transparency = 0.7
	outline.Parent = dot
	dot.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return dot
end

function FirstPerson.start()
	local dot = makeCrosshair()
	RunService.RenderStepped:Connect(function()
		local open = anyPanelOpen()
		UserInputService.MouseIconEnabled = open
		dot.Visible = not open
	end)
end

return FirstPerson
