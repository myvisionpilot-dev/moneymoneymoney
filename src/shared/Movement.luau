--!strict
-- Client movement (both places): walk, hold Shift to sprint (on touch screens, tap the Sprint
-- button to toggle it). While the server has you in a car (the VehicleSpeed attribute on your
-- character) you're sitting in its seat, so there's no jumping (that would hop you out). An
-- energy drink (the SpeedBoost attribute) and the speed shop's buff (SpeedBuff) multiply
-- on-foot speed, up to Movement.MaxSpeedMultiplier. The view widens a little while you're
-- going fast.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local TouchButtons = require(script.Parent.TouchButtons)
local UI = require(script.Parent.UI)

local SPRINT_ACTION = "Sprint"
local VEHICLE_ATTRIBUTE = "VehicleSpeed"
local BOOST_ATTRIBUTE = "SpeedBoost"
local BUFF_ATTRIBUTE = "SpeedBuff"
local MOVING = 0.1 -- MoveDirection length that counts as trying to move
local DRIVING_FAST = 20 -- studs/s in a car that counts as going fast

local Movement = {}

local sprinting = false
local sprintButton: TouchButtons.TouchButton? = nil
local fieldOfViewTarget = Config.Movement.FieldOfView

local function vehicleSpeed(character: Model): number?
	local value = character:GetAttribute(VEHICLE_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

local function multiplier(character: Model, attribute: string): number
	local value = character:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 1
end

local function apply()
	if sprintButton then
		sprintButton.button.BackgroundColor3 = if sprinting then UI.Colors.Gold else UI.Colors.Panel
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local driving = vehicleSpeed(character) ~= nil
	local onFoot = if sprinting then Config.Movement.SprintSpeed else Config.Movement.WalkSpeed
	local boost = multiplier(character, BOOST_ATTRIBUTE) * multiplier(character, BUFF_ATTRIBUTE)
	humanoid.WalkSpeed = onFoot * math.min(boost, Config.Movement.MaxSpeedMultiplier)
	-- No jumping in a car (it would hop you out of the seat).
	humanoid.JumpHeight = if driving then 0 else StarterPlayer.CharacterJumpHeight
	humanoid.JumpPower = if driving then 0 else StarterPlayer.CharacterJumpPower
end

-- Wider view while sprinting or driving (and actually moving), back to normal otherwise.
local function updateFieldOfView()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not character or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local fast = if vehicleSpeed(character)
		then root.AssemblyLinearVelocity.Magnitude > DRIVING_FAST
		else humanoid.MoveDirection.Magnitude > MOVING and sprinting
	local target = if fast then Config.Movement.FastFieldOfView else Config.Movement.FieldOfView
	if target ~= fieldOfViewTarget then
		fieldOfViewTarget = target
		local info =
			TweenInfo.new(Config.Movement.FieldOfViewTweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(camera, info, { FieldOfView = target }):Play()
	end
end

local function onCharacter(character: Model)
	character:WaitForChild("Humanoid", 10)
	character:GetAttributeChangedSignal(VEHICLE_ATTRIBUTE):Connect(apply)
	character:GetAttributeChangedSignal(BOOST_ATTRIBUTE):Connect(apply)
	character:GetAttributeChangedSignal(BUFF_ATTRIBUTE):Connect(apply)
	apply()
end

function Movement.start()
	ContextActionService:BindAction(
		SPRINT_ACTION,
		function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				sprinting = true
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				sprinting = false
			end
			apply()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	-- Holding a button while steering with the other thumb is awkward, so on touch it toggles.
	if TouchButtons.enabled() then
		sprintButton = TouchButtons.add("🏃", "SPRINT", 1, function()
			sprinting = not sprinting
			apply()
		end)
	end

	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	-- Alt-tabbing while holding Shift never sends the release, so stop sprinting on focus loss.
	UserInputService.WindowFocusReleased:Connect(function()
		sprinting = false
		apply()
	end)
	RunService.RenderStepped:Connect(updateFieldOfView)
end

return Movement
