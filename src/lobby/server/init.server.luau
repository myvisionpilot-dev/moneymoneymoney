--!strict
-- Lobby server entry point.

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerSetup = require(ServerScriptService.Common.PlayerSetup)
local QueueService = require(script.QueueService)

PlayerSetup.start()
QueueService.start()
