--!strict
-- A big "RUN!!" under the quota panel while you're wanted (HudController turns it on and off).
-- Its background fades from dark red to light red and it throbs a little. Hidden inside a house
-- you broke into (the alarm has its own screen there).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))

local DARK = Color3.fromRGB(70, 0, 4)
local LIGHT = Color3.fromRGB(255, 92, 92)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local THROB = 0.04 -- how much bigger it gets at the top of each beat
local BEATS = 3 -- per second

local RunBanner = {}

local player = Players.LocalPlayer
local banner: Frame? = nil
local scale: UIScale? = nil
local wanted = false

local function build()
	local gui = UI.screen("RunBanner", 4)
	local root = UI.root(gui)
	local frame = UI.frame({
		Name = "Run",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100), -- under the quota panel
		Size = UDim2.fromOffset(380, 84),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, root)
	UI.corner(frame, 14)
	UI.stroke(frame, 3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(DARK, LIGHT)
	gradient.Rotation = 90 -- dark at the top, light at the bottom
	gradient.Parent = frame
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
		TextSize = 62,
		Text = "RUN!!",
	}, frame)
	UI.textStroke(label, 3)
	local throb = Instance.new("UIScale")
	throb.Parent = frame
	banner, scale = frame, throb
end

local function inside(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Inside") ~= nil
end

function RunBanner.set(on: boolean)
	if on == wanted then
		return
	end
	wanted = on
	if on and banner then
		UI.pop(banner, 0.3)
	end
end

function RunBanner.start()
	build()
	RunService.RenderStepped:Connect(function()
		local frame, throb = banner, scale
		if not frame or not throb then
			return
		end
		frame.Visible = wanted and not inside()
		if frame.Visible then
			throb.Scale = 1 + THROB * math.abs(math.sin(os.clock() * math.pi * BEATS))
		end
	end)
end

return RunBanner
