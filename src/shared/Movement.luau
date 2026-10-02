--!strict
-- Client movement (both places): walk, hold Shift to sprint (on touch screens, tap the Sprint
-- button to toggle it), and vehicle speed while the server has you in a kart or car (the
-- VehicleSpeed attribute on your character). An energy drink multiplies on-foot speed (the
-- SpeedBoost attribute). The view widens a little while you're going fast.

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
local SIT_ANIMATION = "rbxassetid://2506281703" -- Roblox's default R15 sit pose
local MOVING = 0.1 -- MoveDirection length that counts as trying to move

local Movement = {}

local sprinting = false
local sprintButton: TouchButtons.TouchButton? = nil
local sitTrack: AnimationTrack? = nil
local fieldOfViewTarget = Config.Movement.FieldOfView

local function vehicleSpeed(character: Model): number?
	local value = character:GetAttribute(VEHICLE_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

-- Sitting in a kart; other players see it too (your own animations replicate).
local function setSitting(humanoid: Humanoid, sitting: boolean)
	local current = sitTrack
	if sitting and not current then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = SIT_ANIMATION
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
			sitTrack = track
		end
	elseif not sitting and current then
		current:Stop(0.2)
		sitTrack = nil
	end
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
	local speed = vehicleSpeed(character)
	if speed then
		humanoid.WalkSpeed = speed
	else
		local boost = character:GetAttribute(BOOST_ATTRIBUTE) -- the energy drink (Match only)
		local onFoot = if sprinting then Config.Movement.SprintSpeed else Config.Movement.WalkSpeed
		humanoid.WalkSpeed = onFoot * (if typeof(boost) == "number" then boost else 1)
	end
	-- Karts and cars don't jump.
	humanoid.JumpHeight = if speed then 0 else StarterPlayer.CharacterJumpHeight
	humanoid.JumpPower = if speed then 0 else StarterPlayer.CharacterJumpPower
	setSitting(humanoid, speed ~= nil)
end

-- Wider view while sprinting or driving (and actually moving), back to normal otherwise.
local function updateFieldOfView()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not character or not humanoid then
		return
	end
	local speed = vehicleSpeed(character)
	local moving = humanoid.MoveDirection.Magnitude > MOVING
	local fast = moving and (if speed then speed > 0 else sprinting)
	local target = if fast then Config.Movement.FastFieldOfView else Config.Movement.FieldOfView
	if target ~= fieldOfViewTarget then
		fieldOfViewTarget = target
		local info =
			TweenInfo.new(Config.Movement.FieldOfViewTweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(camera, info, { FieldOfView = target }):Play()
	end
end

local function onCharacter(character: Model)
	sitTrack = nil -- it belonged to the old character
	character:WaitForChild("Humanoid", 10)
	character:GetAttributeChangedSignal(VEHICLE_ATTRIBUTE):Connect(apply)
	character:GetAttributeChangedSignal(BOOST_ATTRIBUTE):Connect(apply)
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
