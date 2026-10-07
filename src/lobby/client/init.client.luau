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
require(script:WaitForChild("ProfileHud")).start()

-- The menu bar and the windows it opens share one screen.
local root = UI.root(UI.screen("Menu", 10))
require(script:WaitForChild("QueueController")).start(root)
local upgrades = require(script:WaitForChild("UpgradesWindow")).start(root)
local customise = require(script:WaitForChild("CustomiseWindow")).start(root)
local browser = require(script:WaitForChild("LobbyBrowser")).start(root)
require(script:WaitForChild("MenuBar")).start(root, upgrades, customise, browser)
require(script:WaitForChild("ProfileState")).start()
