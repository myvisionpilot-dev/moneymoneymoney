--!strict
-- Client side of first person (both places): a tiny white dot crosshair, hold Shift (or the
-- Sprint touch button) to sprint, and a free mouse while a clickable panel is open.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)

local SPRINT_ACTION = "Sprint"
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

local function setSprinting(sprinting: boolean)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if sprinting then Config.Movement.SprintSpeed else Config.Movement.WalkSpeed
	end
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

	ContextActionService:BindAction(
		SPRINT_ACTION,
		function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				setSprinting(true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				setSprinting(false)
			end
			return Enum.ContextActionResult.Sink
		end,
		true, -- adds a Sprint button on touch screens
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle(SPRINT_ACTION, "Sprint")

	Players.LocalPlayer.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("Humanoid", 10)
		setSprinting(false)
	end)
	-- Alt-tabbing while holding Shift never sends the release, so stop sprinting on focus loss.
	UserInputService.WindowFocusReleased:Connect(function()
		setSprinting(false)
	end)

	RunService.RenderStepped:Connect(function()
		local open = anyPanelOpen()
		UserInputService.MouseIconEnabled = open
		dot.Visible = not open
	end)
end

return FirstPerson
