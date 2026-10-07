--!strict
-- Run levels (Config.Levels): every payout gives XP, levels come quickly at first and slow
-- down, and each one pays a little more for the rest of the run (PayNotice asks
-- LevelService.payMultiplier). Every CredEvery levels also pays saved Cred. A level-up is a big
-- moment: a banner on your screen (Juice), a pillar of light everyone nearby sees (WorldFx),
-- and the RunLevel attribute on your character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Profiles = require(ServerScriptService.Common.Profiles)
local Juice = require(script.Parent.Juice)
local WorldFx = require(script.Parent.WorldFx)

local ATTRIBUTE = "RunLevel"

type State = { level: number, xp: number }

local settings = Config.Levels

local LevelService = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { level = 1, xp = 0 }
		states[player] = state
	end
	return state
end

-- XP from `level` to the next (0 at the top).
function LevelService.needed(level: number): number
	if level >= settings.MaxLevel then
		return 0
	end
	return math.floor(settings.FirstLevelXp * settings.Growth ^ (level - 1) + 0.5)
end

function LevelService.level(player: Player): number
	return stateOf(player).level
end

function LevelService.xp(player: Player): number
	return stateOf(player).xp
end

function LevelService.payMultiplier(player: Player): number
	return 1 + settings.PayPerLevel * (stateOf(player).level - 1)
end

local function reached(player: Player, level: number)
	local character = player.Character
	if character then
		character:SetAttribute(ATTRIBUTE, level)
	end
	local cred = 0
	if level % settings.CredEvery == 0 then
		local data = Profiles.get(player)
		if data then
			cred = settings.CredReward * (level // settings.CredEvery)
			Profiles.addCred(player, data, cred, `run level {level}`)
			Profiles.markChanged(player)
		end
	end
	Juice.levelUp(player, level, cred)
	WorldFx.levelUp(player, level)
end

-- After a payout of `amount` (what they earned, whether or not it all fit in the bag).
function LevelService.earned(player: Player, amount: number)
	local state = stateOf(player)
	if state.level >= settings.MaxLevel then
		return
	end
	state.xp += settings.XpPerPayout + math.floor(amount / settings.XpPerDollars)
	while state.level < settings.MaxLevel and state.xp >= LevelService.needed(state.level) do
		state.xp -= LevelService.needed(state.level)
		state.level += 1
		reached(player, state.level)
	end
	if state.level >= settings.MaxLevel then
		state.xp = 0
	end
	LevelService.changed:Fire(player)
end

function LevelService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:SetAttribute(ATTRIBUTE, stateOf(player).level)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

return LevelService
