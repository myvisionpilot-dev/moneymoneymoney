--!strict
-- Latest RunSnapshot from the server, plus a signal when it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Types = require(Shared:WaitForChild("Types"))

local ClientState = {
	snapshot = nil :: Types.RunSnapshot?,
	changed = Signal.new() :: Signal.Signal<Types.RunSnapshot>,
}

function ClientState.me(): Types.PlayerRow?
	local snapshot = ClientState.snapshot
	if not snapshot then
		return nil
	end
	for _, row in snapshot.players do
		if row.userId == Players.LocalPlayer.UserId then
			return row
		end
	end
	return nil
end

function ClientState.phase(): Types.Phase
	local snapshot = ClientState.snapshot
	return if snapshot then snapshot.phase else "Waiting"
end

function ClientState.start()
	local remotes = Remotes.match()
	remotes.RunSnapshot:onClient(function(snapshot: Types.RunSnapshot)
		ClientState.snapshot = snapshot
		ClientState.changed:Fire(snapshot)
	end)
	remotes.ClientReady:fire(nil)
end

return ClientState
