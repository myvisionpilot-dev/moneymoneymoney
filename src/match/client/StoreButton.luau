--!strict
-- The Shop in a run: a lime glitter Shop button under the status panel (top right) opens the same
-- Shop window as the lobby's (shared/StoreWindow), so Cred packs and game passes can be bought
-- without leaving town. serverCommon/Purchases and Passes run in the match too, so whatever's
-- bought works straight away (Mega Bag grows your bag on the spot: server/Loadout).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local StoreWindow = require(Shared:WaitForChild("StoreWindow"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local BOTTOM = 24 -- room left under the window

local StoreButton = {}

function StoreButton.start()
	local column = HudController.rightColumn()
	if not column then
		return
	end
	local root = UI.root(UI.screen("Store", 48))
	local window = StoreWindow.start(root, BOTTOM)
	local button = StoreKit.glitterIconButton("Shop", StoreKit.Images.Cart, StoreKit.Glitter.Lime, {
		Name = "Shop",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(150, 56),
	}, column)
	Cursor.registerPanel(button)
	button.Activated:Connect(function()
		window.panel.Visible = not window.panel.Visible
	end)
end

return StoreButton
