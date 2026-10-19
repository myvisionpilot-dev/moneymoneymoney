--!strict
-- Arrests: lose Police.CaughtLosePercent of carried cash, heat cleared, and into the cell. Pick
-- its lock to get out (JailLock), or wait Police.JailSeconds (less of both with the Cred shop's
-- Insurance and Good Lawyer, and the Bail Money pass caps the wait). Everyone is let out when
-- the quota ends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Passes = require(ServerScriptService.Common.Passes)
local Perks = require(ServerScriptService.Common.Perks)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local HustleService = require(script.Parent.HustleService)
local JailLock = require(script.Parent.JailLock)
local Juice = require(script.Parent.Juice)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local TutorialState = require(script.Parent.TutorialState)
local WorldFx = require(script.Parent.WorldFx)

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
	JailLock.take(player)
	local exit = taggedCFrame(EXIT_TAG)
	if exit and player.Parent then
		MovementGuard.teleport(player, CFrame.new(exit.Position + Vector3.new(0, 4, 0)))
	end
	JailService.changed:Fire(player)
	Notifier.send(player, message, "Info")
end

function JailService.arrest(player: Player, byWhom: string)
	-- (In the tutorial the cops chase you, but you can't be caught.)
	if jailed[player] or not RosterService.isActive(player) or TutorialState.isIn(player) then
		return
	end
	local account = EconomyService.account(player)
	local free = HustleService.useFreeBust(player) -- Second Chance
	local lost = if free
		then 0
		else EconomyService.removeCarried(
			player,
			account.carried * math.max(Config.Police.CaughtLosePercent - Perks.amount(player, "Insurance"), 0),
			`arrested by {byWhom}`
		)
	HeatService.clear(player)
	-- The Good Lawyer upgrade takes seconds off (down to a minimum).
	local seconds = math.ceil(Config.Police.JailSeconds * HustleService.jailMultiplier(player))
	seconds = math.max(seconds - Perks.amount(player, "Lawyer"), math.min(seconds, Config.CredShop.MinJailSeconds))
	if Passes.has(player, "BailMoney") then
		seconds = math.min(seconds, Config.Store.BailSeconds)
	end
	jailed[player] = Timing.now() + seconds
	WorldFx.busted(player) -- where they got caught, before the cell
	putInCell(player)
	JailLock.give(player, function()
		release(player, "You picked the lock! You're out.")
	end)
	JailService.arrested:Fire(player)
	JailService.changed:Fire(player)
	Juice.lost(player, lost, `Busted by {byWhom}`)
	local kept = if free then " Second Chance: you kept your cash." else ""
	Notifier.send(player, `Busted! Pick the lock to get out, or wait {seconds}s.{kept}`, "Bad")
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
