--!strict
-- Queue pads: players standing on a pad are sent together to a reserved Match server.
-- A pad leaves when it is full or QueueWaitSeconds after the first player steps on.

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
local PAD_HEIGHT = 10 -- studs above the pad that count as standing on it
local RESET_SECONDS = 5 -- pad pause after a launch
local TELEPORT_GRACE_SECONDS = 30 -- don't re-queue players whose teleport is in flight

type Pad = {
	part: BasePart,
	members: { Player },
	departsAt: number?,
	launching: boolean,
	label: TextLabel,
}

local QueueService = {}

local remotes = Remotes.lobby()
local leaveLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local pads: { Pad } = {}
local lastStatus: { [Player]: string } = {}
local warnedFull: { [Player]: boolean } = {}
local teleportingUntil: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

local function makeLabel(part: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "QueueLabel"
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffset = Vector3.new(0, 7, 0)
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

local function isOnPad(part: BasePart, player: Player): boolean
	local root = CharacterUtil.getRoot(player)
	if not root then
		return false
	end
	local offset = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y >= 0 and offset.Y <= PAD_HEIGHT
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
	local key = if status then `{status.count}/{status.departsAt}` else "none"
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
		if player.Parent and isOnPad(pad.part, player) then
			table.insert(members, player)
		end
	end
	for _, player in Players:GetPlayers() do
		local teleporting = (teleportingUntil[player] or 0) > os.clock()
		if not teleporting and not table.find(members, player) and not padOf(player) and isOnPad(pad.part, player) then
			if #members < Config.Match.MaxPlayers then
				table.insert(members, player)
				warnedFull[player] = nil
			elseif not warnedFull[player] then
				warnedFull[player] = true
				notify(player, "This pad is full. Try the other one!", "Info")
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
		pad.label.Text = "STEP ON TO PLAY"
		return
	end

	local departsAt = pad.departsAt or (now + Timing.scaled(Config.Match.QueueWaitSeconds))
	pad.departsAt = departsAt
	local ready = #members >= Config.Match.MinPlayers
	if ready and (#members >= Config.Match.MaxPlayers or now >= departsAt) then
		launch(pad)
		return
	end

	pad.label.Text = `{#members}/{Config.Match.MaxPlayers}  ·  {Format.clock(departsAt - now)}`
	for _, player in members do
		sendStatus(player, { count = #members, max = Config.Match.MaxPlayers, departsAt = departsAt })
	end
end

local function addPad(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	table.insert(pads, {
		part = instance,
		members = {},
		departsAt = nil,
		launching = false,
		label = makeLabel(instance),
	})
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
	-- Step them off the front edge of the pad.
	local exit = pad.part.CFrame * CFrame.new(0, 3, pad.part.Size.Z / 2 + 6)
	character:PivotTo(exit)
end

function QueueService.start()
	for _, instance in CollectionService:GetTagged(PAD_TAG) do
		addPad(instance)
	end
	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(addPad)

	remotes.LeaveQueue:onServer(onLeaveQueue)

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
