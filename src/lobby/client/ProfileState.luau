--!strict
-- Your latest saved profile from the server (Cred, perks, badges, daily), plus a signal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local ProfileState = {
	view = nil :: Types.ProfileView?,
	changed = Signal.new() :: Signal.Signal<Types.ProfileView>,
}

function ProfileState.start()
	Remotes.lobby().ProfileSync:onClient(function(view: Types.ProfileView)
		ProfileState.view = view
		ProfileState.changed:Fire(view)
	end)
end

return ProfileState
