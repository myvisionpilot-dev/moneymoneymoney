--!strict
-- While you're in a bush: leafy green edges on the screen and a short line saying whether
-- the police can see you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local LEAF = Color3.fromRGB(40, 110, 45)
local EDGE = 0.2 -- share of the screen each leafy edge covers

local HidingController = {}

local function edge(parent: Instance, rotation: number, anchor: Vector2, position: UDim2, size: UDim2)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = LEAF
	frame.BorderSizePixel = 0
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation -- solid at the screen edge, fading inward
	gradient.Transparency = NumberSequence.new(0.3, 1)
	gradient.Parent = frame
	frame.Parent = parent
end

function HidingController.start()
	local leaves = UI.screen("Leaves", -1)
	leaves.IgnoreGuiInset = true
	leaves.Enabled = false
	edge(leaves, 0, Vector2.zero, UDim2.fromScale(0, 0), UDim2.fromScale(EDGE, 1))
	edge(leaves, 180, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(EDGE, 1))
	edge(leaves, 90, Vector2.zero, UDim2.fromScale(0, 0), UDim2.fromScale(1, EDGE))
	edge(leaves, 270, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, EDGE))

	local root = UI.root(UI.screen("HidingHint", 5))
	local hint = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(420, 30),
		Font = UI.Fonts.Heading,
		TextSize = 22,
		Visible = false,
	}, root)
	UI.textStroke(hint)

	ClientState.changed:Connect(function(_snapshot: Types.RunSnapshot)
		local me = ClientState.me()
		local hiding = me ~= nil and me.hiding
		leaves.Enabled = hiding
		hint.Visible = hiding
		if not me or not hiding then
			return
		end
		if me.spotted then
			hint.Text = "SPOTTED! A cop can see you!"
			hint.TextColor3 = UI.Colors.Danger
		elseif me.heat > 0 then
			hint.Text = "Hidden! The police lost you."
			hint.TextColor3 = UI.Colors.Money
		else
			hint.Text = "Hiding spot: lose the police here."
			hint.TextColor3 = UI.Colors.Text
		end
	end)
end

return HidingController
