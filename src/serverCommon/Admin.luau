--!strict
-- Who may use debug commands: the game's owner, Config.Debug.AdminUserIds, or anyone in a Studio test.
-- A group-owned game has no owner account here, so the admins are listed in Config.Debug.AdminUserIds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Admin = {}

function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Debug.AdminUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

return Admin
