--!strict
-- Arrests: lose Police.CaughtLosePercent of carried cash, heat cleared, Police.JailSeconds in the cell.
-- Everyone is let out when the quota ends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)

local CELL_TAG = "JailCell"
local EXIT_TAG = "JailExit"
local ESCAPE_STUDS = 14 -- further than this from the cell gets you put back

local JailService = {
	arrested = Signal.new() :: Signal.Signal<Player>,
	changed = Signal.new() :: Signal.Signal<Player>,
}

local jailed: { [Player]: number } = {} -- player -> release time (Timing.now())

local function taggedCFrame(tag: string): CFrame?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance.CFrame
		end
	end
	return nil
end

function JailService.isJailed(player: Player): boolean
	return jailed[player] ~= nil
end

function JailService.releaseAt(player: Player): number
	return jailed[player] or 0
end

local function putInCell(player: Player)
	local cell = taggedCFrame(CELL_TAG)
	if cell then
		MovementGuard.teleport(player, CFrame.new(cell.Position + Vector3.new(0, 4, 0)))
	end
end

local function release(player: Player, message: string)
	if not jailed[player] then
		return
	end
	jailed[player] = nil
	local exit = taggedCFrame(EXIT_TAG)
	if exit and player.Parent then
		MovementGuard.teleport(player, CFrame.new(exit.Position + Vector3.new(0, 4, 0)))
	end
	JailService.changed:Fire(player)
	Notifier.send(player, message, "Info")
end

function JailService.arrest(player: Player, byWhom: string)
	if jailed[player] or not RosterService.isActive(player) then
		return
	end
	local account = EconomyService.account(player)
	local lost =
		EconomyService.removeCarried(player, account.carried * Config.Police.CaughtLosePercent, `arrested by {byWhom}`)
	HeatService.clear(player)
	jailed[player] = Timing.now() + Config.Police.JailSeconds
	putInCell(player)
	JailService.arrested:Fire(player)
	JailService.changed:Fire(player)
	Notifier.send(
		player,
		`Busted! You lost {Format.money(lost)} and you're in jail for {Config.Police.JailSeconds}s.`,
		"Bad"
	)
	Notifier.others(player, `{player.DisplayName} got busted by {byWhom}!`, "Info")
end

function JailService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		jailed[player] = nil
	end)

	-- Respawning doesn't break you out.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if jailed[player] then
				task.defer(putInCell, player)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	RunState.changed:Connect(function()
		if RunState.phase ~= "Quota" then
			for player in jailed do
				release(player, "The quota's over, so the police let you go.")
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = Timing.now()
			local cell = taggedCFrame(CELL_TAG)
			for player, releaseAt in jailed do
				local character = player.Character
				if now >= releaseAt then
					release(player, "You're out of jail. Behave!")
				elseif
					cell
					and character
					and (character:GetPivot().Position - cell.Position).Magnitude > ESCAPE_STUDS
				then
					putInCell(player)
				end
			end
		end
	end)
end

return JailService
