--!strict
-- Lobby client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))

require(Shared:WaitForChild("Sounds")).preload()
require(Shared:WaitForChild("Music")).start()
require(Shared:WaitForChild("Cursor")).start()
require(Shared:WaitForChild("Movement")).start()
require(Shared:WaitForChild("Rainbow")).start()
require(Shared:WaitForChild("IndoorGrade")).start(true, 0.25) -- the hall is indoors (a light touch)
require(Shared:WaitForChild("ChatTags")).start()
local shopButtons = require(script:WaitForChild("ProfileHud")).start()

-- The menu bar and the windows it opens share one screen.
local root = UI.root(UI.screen("Menu", 10))
require(script:WaitForChild("QueueController")).start(root)
local upgrades = require(script:WaitForChild("UpgradesWindow")).start(root)
local customise = require(script:WaitForChild("CustomiseWindow")).start(root)
local browser = require(script:WaitForChild("LobbyBrowser")).start(root)
local barSpace = require(script:WaitForChild("ShopFrame")).BAR_SPACE
local store = require(Shared:WaitForChild("StoreWindow")).start(root, barSpace) -- the Shop (in runs too)
local boosts = require(script:WaitForChild("BoostsWindow")).start(root) -- invite friends, join the group
require(script:WaitForChild("MenuBar")).start(root, upgrades, customise, browser, store, shopButtons, boosts)
require(script:WaitForChild("ProfileState")).start()
require(script:WaitForChild("WheelController")).start(root) -- the Lucky Wheel in the hall
