--!strict
-- Repo men, from Repo.FromQuota: the bank's debt collectors go after anyone carrying more than
-- Repo.BagFraction of their bag (Repo Repellent raises it). A warning first, then one turns up
-- at a patrol point at least Repo.MinSpawnStuds away and chases on foot (slower than a
-- sprint). A tag takes Repo.TakePercent of the cash you carry (not inside the bank). He gives
-- up once you bank or spend it, after Repo.ChaseSeconds, or when the quota ends. A blaster
-- freezes him like a cop. No weapons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local EconomyService = require(script.Parent.EconomyService)
local HustleService = require(script.Parent.HustleService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local NpcChase = require(script.Parent.NpcChase)
local NpcService = require(script.Parent.NpcService)
local Notifier = require(script.Parent.Notifier)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local SafeZone = require(script.Parent.SafeZone)

local TICK_SECONDS = 0.1
local CHECK_SECONDS = 1
local SUIT = Color3.fromRGB(35, 35, 42)
local SUIT_DARK = Color3.fromRGB(22, 22, 28)

type Repo = {
	chaser: NpcChase.Chaser,
	target: Player,
	givesUpAt: number, -- os.clock()
	stunnedUntil: number,
}

local settings = Config.Repo

local RepoService = {}

local repos: { Repo } = {}
local building: { [Player]: boolean } = {} -- a repo man is being dressed for them
local warnedAt: { [Player]: number } = {}
local restUntil: { [Player]: number } = {} -- os.clock(): no repo man for them before this

local function repoFor(player: Player): Repo?
	for _, repo in repos do
		if repo.target == player then
			return repo
		end
	end
	return nil
end

-- Carrying more than they should, during a late-game quota.
local function overLimit(player: Player): boolean
	if
		RunState.phase ~= "Quota"
		or RunState.quotaIndex < settings.FromQuota
		or not RosterService.isActive(player)
		or JailService.isJailed(player)
	then
		return false
	end
	local account = EconomyService.account(player)
	return account.carried > account.bagCapacity * HustleService.repoFraction(player)
end

local function remove(repo: Repo, rest: boolean)
	local index = table.find(repos, repo)
	if index then
		table.remove(repos, index)
	end
	repo.chaser.model:Destroy()
	if rest then
		restUntil[repo.target] = os.clock() + settings.CooldownSeconds
	end
end

local function spawnRepo(target: Player)
	local root = CharacterUtil.getRoot(target)
	if not root then
		return
	end
	building[target] = true
	task.spawn(function()
		local look = NpcService.randomLook()
		local suit = Config.Outfits.Uniforms.Suit
		look.shirt, look.pants, look.top, look.bottom, look.hat = SUIT, SUIT_DARK, suit.shirt, suit.pants, nil
		local chaser = NpcChase.spawn("Repo Man", look, root.Position, settings.MinSpawnStuds, settings.Speed)
		building[target] = nil
		if not chaser then
			return
		end
		if not overLimit(target) or repoFor(target) then
			chaser.model:Destroy()
			return
		end
		table.insert(repos, {
			chaser = chaser,
			target = target,
			givesUpAt = os.clock() + settings.ChaseSeconds,
			stunnedUntil = 0,
		})
	end)
end

local function tag(repo: Repo)
	local target = repo.target
	local account = EconomyService.account(target)
	local taken = EconomyService.removeCarried(target, account.carried * settings.TakePercent, "repo man")
	Juice.lost(target, taken, "Repo man took a cut")
	Sounds.at("Whistle", repo.chaser.root)
	remove(repo, true)
end

local function chase(repo: Repo)
	local target = repo.target
	local targetRoot = CharacterUtil.getRoot(target)
	if not targetRoot or not repo.chaser.model.Parent or not overLimit(target) then
		remove(repo, true)
		if target.Parent and targetRoot and RunState.phase == "Quota" and not JailService.isJailed(target) then
			Notifier.send(target, "The repo man gave up. Your cash is safe for now.", "Good")
		end
		return
	end
	if os.clock() >= repo.givesUpAt then
		remove(repo, true)
		Notifier.send(target, "You lost the repo man!", "Good")
		return
	end
	if os.clock() < repo.stunnedUntil then
		NpcChase.hold(repo.chaser)
		return
	end
	local distance = NpcChase.step(repo.chaser, targetRoot.Position)
	if distance <= settings.TagRangeStuds then
		if SafeZone.contains(targetRoot.Position) then
			NpcChase.hold(repo.chaser) -- waits by you while you're in the bank
		else
			tag(repo)
		end
	end
end

-- Warns anyone carrying too much, then sends a repo man after them.
local function check()
	local now = os.clock()
	local count = #repos
	for _ in building do
		count += 1
	end
	for _, player in Players:GetPlayers() do
		if not overLimit(player) or repoFor(player) or building[player] or now < (restUntil[player] or 0) then
			warnedAt[player] = nil
			continue
		end
		local warned = warnedAt[player]
		if not warned then
			if count < settings.MaxInTown then
				warnedAt[player] = now
				Notifier.send(
					player,
					"A repo man is coming for the cash in your bag! Bank it, outrun him or zap him.",
					"Bad"
				)
				Juice.sound(player, "Wanted")
			end
		elseif now - warned >= settings.WarnSeconds and count < settings.MaxInTown then
			warnedAt[player] = nil
			count += 1
			spawnRepo(player)
		end
	end
end

function RepoService.isRepo(model: Model): boolean
	for _, repo in repos do
		if repo.chaser.model == model then
			return true
		end
	end
	return false
end

-- Zapped by a blaster: he stands still until then.
function RepoService.stun(model: Model, seconds: number)
	for _, repo in repos do
		if repo.chaser.model == model then
			repo.stunnedUntil = os.clock() + seconds
			NpcChase.hold(repo.chaser)
		end
	end
end

function RepoService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local repo = repoFor(player)
		if repo then
			remove(repo, false)
		end
		warnedAt[player], restUntil[player], building[player] = nil, nil, nil
	end)
	task.spawn(function()
		local sinceCheck = 0
		while true do
			sinceCheck += task.wait(TICK_SECONDS)
			if sinceCheck >= CHECK_SECONDS then
				sinceCheck = 0
				check()
			end
			for _, repo in table.clone(repos) do
				if table.find(repos, repo) then
					chase(repo)
				end
			end
		end
	end)
end

return RepoService
