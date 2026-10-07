--!strict
-- The PLAY button: players are sent together to a reserved Match server.
--   Solo  leaves straight away, just you.
--   Host  opens a lobby that shows in everyone's FIND A LOBBY list. The host picks the party
--         size and can start early; it leaves when it's that big, or QueueWaitSeconds after it
--         opened.
--   Join  joins a lobby from the list (by its id).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local SafeTeleport = require(ServerScriptService.Common.SafeTeleport)

local POLL_SECONDS = 0.25
local TELEPORT_GRACE_SECONDS = 30 -- don't re-queue players whose teleport is in flight

type Group = {
	id: string,
	members: { Player },
	departsAt: number,
	partySize: number,
	launching: boolean,
}

local QueueService = {}

local remotes = Remotes.lobby()
local playLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local leaveLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local partySizeLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local groups: { Group } = {}
local lastStatus: { [Player]: string } = {}
local teleportingUntil: { [Player]: number } = {}
local nextId = 0
local lastList = ""

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

local function groupOf(player: Player): Group?
	for _, group in groups do
		if table.find(group.members, player) then
			return group
		end
	end
	return nil
end

local function sendStatus(player: Player, status: Types.QueueStatus?)
	local key = if status
		then `{status.count}/{status.partySize}/{status.departsAt}/{status.hostName}/{status.isHost}/{status.leaving}`
		else "none"
	if lastStatus[player] == key then
		return
	end
	lastStatus[player] = key
	remotes.QueueStatus:fireClient(player, status)
end

local function sendGroupStatus(group: Group)
	local host = group.members[1]
	for _, player in group.members do
		sendStatus(player, {
			count = #group.members,
			partySize = group.partySize,
			departsAt = group.departsAt,
			isHost = player == host,
			hostName = host.DisplayName,
			leaving = group.launching,
		})
	end
end

local function removeGroup(group: Group)
	local index = table.find(groups, group)
	if index then
		table.remove(groups, index)
	end
end

local function launch(group: Group)
	group.launching = true
	sendGroupStatus(group)
	local members = table.clone(group.members)

	task.spawn(function()
		if RunService:IsStudio() then
			for _, player in members do
				notify(
					player,
					"Teleports don't work in Studio. Open the Match place and press Play to test a run.",
					"Info"
				)
			end
		else
			local ok, accessCode = pcall(function()
				return TeleportService:ReserveServer(Config.Places.MatchPlaceId)
			end)
			local sent = false
			if ok then
				local userIds = {}
				for _, player in members do
					table.insert(userIds, player.UserId)
				end
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = accessCode
				options:SetTeleportData({ expected = userIds, partyId = HttpService:GenerateGUID(false) })
				sent = SafeTeleport.teleport(Config.Places.MatchPlaceId, members, options)
				if sent then
					for _, player in members do
						teleportingUntil[player] = os.clock() + TELEPORT_GRACE_SECONDS
					end
				end
			else
				warn(`[QueueService] ReserveServer failed: {accessCode}`)
			end
			if not sent then
				for _, player in members do
					notify(player, "Couldn't reach the town. Press PLAY to try again.", "Bad")
				end
			end
		end
		removeGroup(group)
		for _, player in members do
			sendStatus(player, nil)
		end
	end)
end

local function updateGroup(group: Group, now: number)
	if group.launching then
		return
	end
	local members = {}
	for _, player in group.members do
		if player.Parent then
			table.insert(members, player)
		end
	end
	group.members = members
	if #members == 0 then
		removeGroup(group)
		return
	end
	local ready = #members >= Config.Match.MinPlayers
	if ready and (#members >= group.partySize or now >= group.departsAt) then
		launch(group)
		return
	end
	sendGroupStatus(group)
end

-- The lobbies anyone can still join: waiting, hosted for more than one, with room.
local function listing(): { Types.GroupListing }
	local list = {}
	for _, group in groups do
		if not group.launching and group.partySize > 1 and #group.members < group.partySize then
			table.insert(list, {
				id = group.id,
				hostName = group.members[1].DisplayName,
				count = #group.members,
				partySize = group.partySize,
				departsAt = group.departsAt,
			})
		end
	end
	return list
end

-- Everyone's list, whenever it changes.
local function sendList()
	local list = listing()
	local parts = {}
	for _, entry in list do
		table.insert(parts, `{entry.id}:{entry.count}/{entry.partySize}/{entry.departsAt}/{entry.hostName}`)
	end
	local key = table.concat(parts, "|")
	if key ~= lastList then
		lastList = key
		remotes.GroupList:fireAll(list)
	end
end

local function findGroup(id: string): Group?
	for _, group in groups do
		if group.id == id then
			return group
		end
	end
	return nil
end

local function onPlay(player: Player, payload: unknown)
	if not playLimiter:allow(player) or typeof(payload) ~= "table" then
		return
	end
	local request = payload :: { [string]: unknown }
	local mode, id = request.mode, request.group
	if mode ~= "Solo" and mode ~= "Host" and mode ~= "Join" then
		return
	end
	if groupOf(player) or (teleportingUntil[player] or 0) > os.clock() then
		return
	end
	local now = Timing.now()
	local group: Group
	if mode == "Join" then
		local found = if typeof(id) == "string" then findGroup(id) else nil
		if not found or found.launching or found.partySize <= 1 or #found.members >= found.partySize then
			notify(player, "That lobby is full or already gone. Pick another, or host one!", "Info")
			return
		end
		table.insert(found.members, player)
		group = found
	else
		local solo = mode == "Solo" and Config.Match.MinPlayers <= 1
		nextId += 1
		group = {
			id = tostring(nextId),
			members = { player },
			departsAt = now + Timing.scaled(Config.Match.QueueWaitSeconds),
			partySize = if solo then 1 else Config.Match.MaxPlayers,
			launching = false,
		}
		table.insert(groups, group)
	end
	updateGroup(group, now)
	sendList()
end

-- Only the host may change the size, and never below the players already in the group.
local function onSetPartySize(player: Player, payload: unknown)
	if not partySizeLimiter:allow(player) or typeof(payload) ~= "number" then
		return
	end
	local size = payload
	if size ~= math.floor(size) then
		return
	end
	local group = groupOf(player)
	if not group or group.launching or group.members[1] ~= player then
		return
	end
	local minimum = math.max(Config.Match.MinPlayers, #group.members)
	if size < minimum or size > Config.Match.MaxPlayers then
		return
	end
	group.partySize = size
	updateGroup(group, Timing.now())
end

local function onLeaveQueue(player: Player, _payload: unknown)
	if not leaveLimiter:allow(player) then
		return
	end
	local group = groupOf(player)
	if not group or group.launching then
		return
	end
	table.remove(group.members, table.find(group.members, player) :: number)
	sendStatus(player, nil)
	updateGroup(group, Timing.now()) -- the next in line becomes the host
end

function QueueService.start()
	remotes.Play:onServer(onPlay)
	remotes.LeaveQueue:onServer(onLeaveQueue)
	remotes.SetPartySize:onServer(onSetPartySize)

	Players.PlayerAdded:Connect(function(player: Player)
		remotes.GroupList:fireClient(player, listing())
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastStatus[player] = nil
		teleportingUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			local now = Timing.now()
			for _, group in table.clone(groups) do
				updateGroup(group, now)
			end
			sendList()
			task.wait(POLL_SECONDS)
		end
	end)
end

return QueueService
