--!strict
-- Lobby server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Common = ServerScriptService.Common

require(Common.PlayerSetup).start()
require(Common.Profiles).start()
require(Common.ProfileSync).start(Remotes.lobby().ProfileSync)
require(Common.Perks).start()
require(script.QueueService).start()
require(script.PerkShopService).start()
require(script.LeaderboardBoards).start()
