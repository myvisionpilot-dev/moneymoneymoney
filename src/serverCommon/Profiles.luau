--!strict
-- Saved player profiles (both places) through ProfileStore, which session-locks them: a profile
-- is only ever open on one server, so teleporting Lobby -> Match -> Lobby can't lose or duplicate
-- Cred. Loads on join, saves on leave and every few minutes. Studio saves to its own stores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local ProfileStore = require(script.Parent.Vendor.ProfileStore) :: any

export type Data = {
	Cred: number,
	LifetimeCred: number,
	HighestQuota: number,
	Runs: number,
	Perks: { [string]: number }, -- perk id -> level bought (0 = none)
	Badges: { [string]: number }, -- badge id -> os.time() when earned
	Daily: { Day: number, Progress: number, Done: boolean },
	Streak: { Count: number, LastDay: number },
}

local TEMPLATE: Data = {
	Cred = 0,
	LifetimeCred = 0,
	HighestQuota = 0,
	Runs = 0,
	Perks = { Speed = 0 },
	Badges = {},
	Daily = { Day = 0, Progress = 0, Done = false },
	Streak = { Count = 0, LastDay = 0 },
}

local Profiles = {
	loaded = Signal.new() :: Signal.Signal<Player>,
	changed = Signal.new() :: Signal.Signal<Player>, -- fire through Profiles.markChanged
}

-- Store names, kept apart in Studio so tests never touch live saves or leaderboards.
function Profiles.storeName(base: string): string
	return if RunService:IsStudio() then Config.Profiles.StudioPrefix .. base else base
end

local store = ProfileStore.New(Profiles.storeName(Config.Profiles.StoreName), TEMPLATE)
local profiles: { [Player]: any } = {}
local leaving: { [Player]: boolean } = {}

function Profiles.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data :: Data else nil
end

-- Yields until the player's profile has loaded (nil if they leave or it takes too long).
function Profiles.waitFor(player: Player, timeoutSeconds: number): Data?
	local deadline = os.clock() + timeoutSeconds
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.25)
	end
	return Profiles.get(player)
end

-- Every Cred change goes through here and is logged. Earnings also count toward lifetime Cred.
function Profiles.addCred(player: Player, data: Data, amount: number, reason: string)
	local whole = math.floor(amount)
	if whole == 0 then
		return
	end
	data.Cred = math.max(0, data.Cred + whole)
	if whole > 0 then
		data.LifetimeCred += whole
	end
	print(`[Cred] {player.Name} {if whole > 0 then "+" else ""}{whole} ({reason}) -> {data.Cred}`)
end

function Profiles.markChanged(player: Player)
	if profiles[player] then
		Profiles.changed:Fire(player)
	end
end

-- Saves right away (after a run pays out) instead of waiting for the next auto-save.
function Profiles.save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

local function load(player: Player)
	local profile = store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("We couldn't load your save. Please rejoin!")
		end
		return
	end
	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players and not leaving[player] then
			player:Kick("Your save was opened on another server. Please rejoin!")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	local data = profile.Data :: Data
	print(`[Profiles] {player.Name} loaded: {data.Cred} Cred, {data.Runs} runs`)
	Profiles.loaded:Fire(player)
	Profiles.changed:Fire(player)
end

function Profiles.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player: Player)
		leaving[player] = true
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
		task.defer(function()
			leaving[player] = nil
		end)
	end)
end

return Profiles
