--!strict
-- Sends a RunSnapshot to clients whenever the run, roster or money changes (throttled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local SEND_INTERVAL = 0.2

local remotes = Remotes.match()
local readyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local SyncService = {}

local dirty = true
local lastSent = 0

function SyncService.build(): Types.RunSnapshot
	local players: { Types.PlayerRow } = {}
	for _, member in RosterService.all() do
		local account = EconomyService.get(member.userId)
		table.insert(players, {
			userId = member.userId,
			name = member.name,
			carried = if account then account.carried else 0,
			deposited = if account then account.deposited else 0,
			bagCapacity = if account then account.bagCapacity else Config.Economy.BaseBagCapacity,
			status = member.status,
			decided = member.decision ~= nil,
		})
	end
	return {
		phase = RunState.phase,
		quotaIndex = RunState.quotaIndex,
		target = RunState.target,
		progress = RunState.progress,
		phaseEndsAt = RunState.phaseEndsAt,
		isEndless = RunState.isEndless,
		teamDeposited = EconomyService.teamDeposited(),
		players = players,
	}
end

local function markDirty()
	dirty = true
end

function SyncService.start()
	RunState.changed:Connect(markDirty)
	RosterService.changed:Connect(markDirty)
	EconomyService.changed:Connect(function(_userId: number)
		dirty = true
	end)

	remotes.ClientReady:onServer(function(player: Player, _payload: unknown)
		if readyLimiter:allow(player) then
			remotes.RunSnapshot:fireClient(player, SyncService.build())
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if dirty and now - lastSent >= SEND_INTERVAL then
			dirty = false
			lastSent = now
			remotes.RunSnapshot:fireAll(SyncService.build())
		end
	end)
end

return SyncService
