--!strict
-- Sends each player a ProfileView (Cred, cosmetics, badges, daily challenge) whenever their
-- profile changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Daily = require(script.Parent.Daily)
local Profiles = require(script.Parent.Profiles)

local ProfileSync = {}

function ProfileSync.view(data: Profiles.Data): Types.ProfileView
	local owned = {}
	for id in data.Owned do
		table.insert(owned, id)
	end
	local badges = {}
	for id in data.Badges do
		table.insert(badges, id)
	end
	return {
		cred = data.Cred,
		lifetimeCred = data.LifetimeCred,
		highestQuota = data.HighestQuota,
		runs = data.Runs,
		owned = owned,
		equipped = table.clone(data.Equipped),
		badges = badges,
		daily = Daily.view(data),
		streak = Daily.streak(data),
	}
end

function ProfileSync.start(remote: Remotes.ToClient<Types.ProfileView>)
	Profiles.changed:Connect(function(player: Player)
		local data = Profiles.get(player)
		if data and player.Parent then
			remote:fireClient(player, ProfileSync.view(data))
		end
	end)
end

return ProfileSync
