--!strict
-- Who is in the run: expected arrivals, then Active / CashedOut / Finished / Left.
-- Players who leave mid-run forfeit their prize; their deposits still count for the team.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local SafeTeleport = require(ServerScriptService.Common.SafeTeleport)
local Notifier = require(script.Parent.Notifier)

local TONY_SPAWN_TAG = "TonySpawn"
local IS_STUDIO = RunService:IsStudio()

export type Member = {
	player: Player,
	userId: number,
	name: string,
	status: Types.PlayerStatus,
	decision: Types.Decision?,
}

local RosterService = {
	changed = Signal.new() :: Signal.Signal<()>,
	firstArrivalAt = nil :: number?,
	startingCount = 0,
	locked = false,
}

local members: { Member } = {} -- in join order
local expected: { number }? = nil

local function isReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function RosterService.get(player: Player): Member?
	for _, member in members do
		if member.player == player then
			return member
		end
	end
	return nil
end

function RosterService.all(): { Member }
	return table.clone(members)
end

function RosterService.active(): { Member }
	local list = {}
	for _, member in members do
		if member.status == "Active" then
			table.insert(list, member)
		end
	end
	return list
end

function RosterService.isActive(player: Player): boolean
	local member = RosterService.get(player)
	return member ~= nil and member.status == "Active"
end

function RosterService.setStatus(player: Player, status: Types.PlayerStatus)
	local member = RosterService.get(player)
	if member and member.status ~= status then
		member.status = status
		RosterService.changed:Fire()
	end
end

function RosterService.lock()
	RosterService.locked = true
	RosterService.startingCount = #RosterService.active()
	RosterService.changed:Fire()
end

function RosterService.allArrived(): boolean
	local list = expected
	if not list then
		return false
	end
	for _, userId in list do
		if not Players:GetPlayerByUserId(userId) then
			return false
		end
	end
	return true
end

function RosterService.sendToLobby(players: { Player })
	if #players == 0 then
		return
	end
	local sent = SafeTeleport.teleport(Config.Places.LobbyPlaceId, players)
	if not sent and IS_STUDIO then
		for _, player in players do
			Notifier.send(player, "Studio: this is where you'd go back to the lobby. Stop the test to reset.", "Info")
		end
	end
end

-- Moves every active player to Tony's office.
function RosterService.gatherAtTony()
	local spawns = {}
	for _, instance in CollectionService:GetTagged(TONY_SPAWN_TAG) do
		if instance:IsA("BasePart") then
			table.insert(spawns, instance)
		end
	end
	if #spawns == 0 then
		return
	end
	for index, member in RosterService.active() do
		local character = member.player.Character
		if character then
			local spawn = spawns[(index - 1) % #spawns + 1]
			local spread = (index - 1) // #spawns * 4
			character:PivotTo(spawn.CFrame * CFrame.new(spread, 4, 0))
		end
	end
end

local function readExpected(player: Player)
	if expected then
		return
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return
	end
	local teleportData = joinData.TeleportData :: any -- untrusted shape; validated below
	if typeof(teleportData) ~= "table" or typeof(teleportData.expected) ~= "table" then
		return
	end
	local list = {}
	for _, userId in teleportData.expected do
		if typeof(userId) == "number" then
			table.insert(list, userId)
		end
	end
	expected = list
end

local function onPlayerAdded(player: Player)
	if not IS_STUDIO and not isReservedServer() then
		-- Only the Lobby's reserved servers host runs.
		RosterService.sendToLobby({ player })
		return
	end
	if RosterService.locked then
		task.delay(3, function()
			Notifier.send(player, "This run already started. Sending you back to the lobby.", "Info")
			task.wait(3)
			if player.Parent then
				RosterService.sendToLobby({ player })
			end
		end)
		return
	end
	readExpected(player)
	table.insert(members, {
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		status = "Active",
		decision = nil,
	})
	if not RosterService.firstArrivalAt then
		RosterService.firstArrivalAt = Timing.now()
	end
	RosterService.changed:Fire()
end

local function onPlayerRemoving(player: Player)
	local member = RosterService.get(player)
	if member and member.status == "Active" then
		member.status = "Left"
		RosterService.changed:Fire()
	end
end

function RosterService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return RosterService
