--!strict
-- C (L1 on a controller, the CRAWL button on touch screens) lies you down flat, and again gets you
-- up; so does jumping. Lying down you crawl (shared/Movement), low enough to slip under a break-in
-- laser, and the camera drops with you. Not while you're in a car. We lie down on our own screen
-- straight away and tell the server, which shows everyone else.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local UI = require(Shared:WaitForChild("UI"))

local PRONE_ACTION = "Prone"
local PRONE_ATTRIBUTE = "Prone"
local VEHICLE_ATTRIBUTE = "VehicleSpeed"
local STUN_ATTRIBUTE = "Stunned"
local CAMERA_DROP = Vector3.new(0, -2.4, 0)

local ProneController = {}

local player = Players.LocalPlayer
local button: TouchButtons.TouchButton? = nil

local function isProne(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(PRONE_ATTRIBUTE) == true
end

local function show(down: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		TweenService
			:Create(humanoid, TweenInfo.new(0.25), { CameraOffset = if down then CAMERA_DROP else Vector3.zero })
			:Play()
	end
	if button then
		button.button.BackgroundColor3 = if down then UI.Colors.Gold else UI.Colors.Panel
	end
end

local function set(down: boolean)
	local character = player.Character
	if not character then
		return
	end
	if down and (character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil or character:GetAttribute(STUN_ATTRIBUTE)) then
		return
	end
	if down == isProne() then
		return
	end
	character:SetAttribute(PRONE_ATTRIBUTE, if down then true else nil) -- ours at once; the server's follows
	Remotes.match().SetProne:fire(down)
	Sounds.play("Rustle", if down then 0.9 else 1.15, 0.6)
	show(down)
end

local function watch(character: Model)
	show(false)
	character:GetAttributeChangedSignal(PRONE_ATTRIBUTE):Connect(function()
		show(isProne())
	end)
end

function ProneController.start()
	ContextActionService:BindAction(
		PRONE_ACTION,
		function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				set(not isProne())
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.C,
		Enum.KeyCode.ButtonL1
	)
	if TouchButtons.enabled() then
		button = TouchButtons.add("", "CRAWL", 6, function()
			set(not isProne())
		end)
	end
	-- Jumping gets you up.
	UserInputService.JumpRequest:Connect(function()
		if isProne() then
			set(false)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return ProneController
