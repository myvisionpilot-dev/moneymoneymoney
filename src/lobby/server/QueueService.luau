--!strict
-- Queue pads: players standing on a pad are sent together to a reserved Match server.
-- The first player on a pad (the host) picks the party size. The pad leaves when it
-- reaches that size, or QueueWaitSeconds after the first player steps on.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local SafeTeleport = require(ServerScriptService.Common.SafeTeleport)

local PAD_TAG = "QueuePad"
local POLL_SECONDS = 0.25
local PAD_HEIGHT = 10 -- how far below a player we look for the pad
local RESET_SECONDS = 5 -- pad pause after a launch
local TELEPORT_GRACE_SECONDS = 30 -- don't re-queue players whose teleport is in flight

type Pad = {
	part: BasePart,
	members: { Player },
	departsAt: number?,
	launching: boolean,
	label: TextLabel,
	partySize: number,
	rayParams: RaycastParams,
}

local QueueService = {}

local remotes = Remotes.lobby()
local leaveLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local partySizeLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local pads: { Pad } = {}
local lastStatus: { [Player]: string } = {}
local warnedFull: { [Player]: boolean } = {}
local teleportingUntil: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

-- Half the part's size along world axes, whatever its rotation (cylinders lie on their side).
local function worldHalfSize(part: BasePart): Vector3
	local cframe, half = part.CFrame, part.Size / 2
	local x, y, z = cframe.XVector * half.X, cframe.YVector * half.Y, cframe.ZVector * half.Z
	return Vector3.new(
		math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
		math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
		math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
	)
end

local function makeLabel(part: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "QueueLabel"
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, worldHalfSize(part).Y + 6, 0)
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = part
	return label
end

-- A ray straight down from the player must hit the pad, so any shape or rotation works.
local function isOnPad(pad: Pad, player: Player): boolean
	local root = CharacterUtil.getRoot(player)
	if not root then
		return false
	end
	return workspace:Raycast(root.Position, Vector3.new(0, -PAD_HEIGHT, 0), pad.rayParams) ~= nil
end

local function padOf(player: Player): Pad?
	for _, pad in pads do
		if table.find(pad.members, player) then
			return pad
		end
	end
	return nil
end

local function sendStatus(player: Player, status: Types.QueueStatus?)
	local key = if status
		then `{status.count}/{status.partySize}/{status.departsAt}/{status.hostName}/{status.isHost}`
		else "none"
	if lastStatus[player] == key then
		return
	end
	lastStatus[player] = key
	remotes.QueueStatus:fireClient(player, status)
end

local function launch(pad: Pad)
	pad.launching = true
	local group = table.clone(pad.members)
	pad.label.Text = "LEAVING..."

	task.spawn(function()
		for _, player in group do
			sendStatus(player, nil)
		end

		if RunService:IsStudio() then
			for _, player in group do
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
				for _, player in group do
					table.insert(userIds, player.UserId)
				end
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = accessCode
				options:SetTeleportData({ expected = userIds, partyId = HttpService:GenerateGUID(false) })
				sent = SafeTeleport.teleport(Config.Places.MatchPlaceId, group, options)
				if sent then
					for _, player in group do
						teleportingUntil[player] = os.clock() + TELEPORT_GRACE_SECONDS
					end
				end
			else
				warn(`[QueueService] ReserveServer failed: {accessCode}`)
			end
			if not sent then
				for _, player in group do
					notify(player, "Couldn't reach Tony's town. Step on the pad to try again.", "Bad")
				end
			end
		end

		task.wait(RESET_SECONDS)
		pad.members = {}
		pad.departsAt = nil
		pad.partySize = Config.Match.MaxPlayers
		pad.launching = false
	end)
end

local function updatePad(pad: Pad, now: number)
	if pad.launching then
		return
	end

	-- Keep the existing order, drop anyone who stepped off, then add newcomers.
	local members = {}
	for _, player in pad.members do
		if player.Parent and isOnPad(pad, player) then
			table.insert(members, player)
		end
	end
	for _, player in Players:GetPlayers() do
		local teleporting = (teleportingUntil[player] or 0) > os.clock()
		if not teleporting and not table.find(members, player) and not padOf(player) and isOnPad(pad, player) then
			if #members < pad.partySize then
				table.insert(members, player)
				warnedFull[player] = nil
			elseif not warnedFull[player] then
				warnedFull[player] = true
				notify(player, `This pad is set to {pad.partySize} player(s). Try the other one!`, "Info")
			end
		end
	end
	for _, player in pad.members do
		if not table.find(members, player) then
			sendStatus(player, nil)
		end
	end
	pad.members = members

	if #members == 0 then
		pad.departsAt = nil
		pad.partySize = Config.Match.MaxPlayers -- the next host starts from the default
		pad.label.Visible = false -- empty pads show nothing
		return
	end

	local departsAt = pad.departsAt or (now + Timing.scaled(Config.Match.QueueWaitSeconds))
	pad.departsAt = departsAt
	local ready = #members >= Config.Match.MinPlayers
	if ready and (#members >= pad.partySize or now >= departsAt) then
		launch(pad)
		return
	end

	pad.label.Visible = true
	pad.label.Text = `{#members}/{pad.partySize}  ·  {Format.clock(departsAt - now)}`
	local host = members[1]
	for _, player in members do
		sendStatus(player, {
			count = #members,
			partySize = pad.partySize,
			departsAt = departsAt,
			isHost = player == host,
			hostName = host.DisplayName,
		})
	end
end

local function addPad(instance: Instance)
	if not instance:IsA("BasePart") then
		warn(`[QueueService] {instance:GetFullName()} is tagged QueuePad but isn't a part; tag its base part instead`)
		return
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { instance }
	table.insert(pads, {
		part = instance,
		members = {},
		departsAt = nil,
		launching = false,
		label = makeLabel(instance),
		partySize = Config.Match.MaxPlayers,
		rayParams = rayParams,
	})
end

-- Only the host may change the size, and never below the players already on the pad.
local function onSetPartySize(player: Player, payload: unknown)
	if not partySizeLimiter:allow(player) or typeof(payload) ~= "number" then
		return
	end
	local size = payload
	if size ~= math.floor(size) then
		return
	end
	local pad = padOf(player)
	if not pad or pad.launching or pad.members[1] ~= player then
		return
	end
	local minimum = math.max(Config.Match.MinPlayers, #pad.members)
	if size < minimum or size > Config.Match.MaxPlayers then
		return
	end
	pad.partySize = size
	updatePad(pad, Timing.now())
end

local function onLeaveQueue(player: Player, _payload: unknown)
	if not leaveLimiter:allow(player) then
		return
	end
	local pad = padOf(player)
	local character = player.Character
	if not pad or pad.launching or not character then
		return
	end
	-- Step them off the pad's +Z edge in world space (works for rotated pads too).
	local half = worldHalfSize(pad.part)
	character:PivotTo(CFrame.new(pad.part.Position + Vector3.new(0, half.Y + 3, half.Z + 6)))
end

function QueueService.start()
	for _, instance in CollectionService:GetTagged(PAD_TAG) do
		addPad(instance)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(addPad)

	remotes.LeaveQueue:onServer(onLeaveQueue)
	remotes.SetPartySize:onServer(onSetPartySize)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastStatus[player] = nil
		warnedFull[player] = nil
		teleportingUntil[player] = nil
	end)

	task.spawn(function()
		while true do
			local now = Timing.now()
			for _, pad in pads do
				updatePad(pad, now)
			end
			task.wait(POLL_SECONDS)
		end
	end)
end

return QueueService
