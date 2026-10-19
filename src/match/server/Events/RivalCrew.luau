--!strict
-- Rival crew (from Events.RivalCrew.FromQuota): Count gang members go after the players carrying
-- the most cash. Up close (ReachStuds) they take a swipe every SwipeSeconds or so; HitChance of
-- them land, for Damage each. Nobody dies: knocked to zero, you sit down seeing stars, back at
-- full health, minus KnockoutTakePercent of your carried cash, and they leave you alone for
-- KnockoutGraceSeconds. Fight back with the Shove prompt on each one: a shove knocks them over,
-- Hits shoves knock one out for a Reward. No fighting in the bank, or from a car.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Strength = require(ReplicatedStorage.Shared.Strength)
local EconomyService = require(script.Parent.Parent.EconomyService)
local Gestures = require(script.Parent.Parent.Gestures)
local JailService = require(script.Parent.Parent.JailService)
local Juice = require(script.Parent.Parent.Juice)
local NpcChase = require(script.Parent.Parent.NpcChase)
local NpcService = require(script.Parent.Parent.NpcService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local RunState = require(script.Parent.Parent.RunState)
local SafeZone = require(script.Parent.Parent.SafeZone)
local Shove = require(script.Parent.Parent.Shove)
local Stun = require(script.Parent.Parent.Stun)
local TownEvent = require(script.Parent.TownEvent)

local HOODIE = Color3.fromRGB(110, 40, 140)
local HOODIE_DARK = Color3.fromRGB(40, 30, 50)
local WIND_UP = 0.3 -- seconds between the swing starting and it landing

local settings = Config.Events.RivalCrew
local remotes = Remotes.match()

type Rival = {
	chaser: NpcChase.Chaser,
	target: Player?,
	hits: number,
	nextSwipeAt: number,
	downUntil: number,
	out: boolean,
}

local rivals: { Rival } = {}
local context: TownEvent.Context? = nil
local generation = 0
local restUntil: { [Player]: number } = {} -- knocked down: left alone until then
local rng = Random.new()

local RivalCrew = {
	id = "RivalCrew",
	title = "RIVAL CREW",
	seconds = settings.Seconds,
}

local function targetable(player: Player): boolean
	return Shove.canFight(player) and os.clock() >= (restUntil[player] or 0)
end

function RivalCrew.canStart(): boolean
	if RunState.quotaIndex < settings.FromQuota then
		return false
	end
	for _, player in Players:GetPlayers() do
		if RosterService.isActive(player) and not JailService.isJailed(player) then
			return true
		end
	end
	return false
end

local function countText(): string
	return `{#rivals} rival{if #rivals == 1 then "" else "s"}! Shove them!`
end

local function remove(rival: Rival)
	local index = table.find(rivals, rival)
	if index then
		table.remove(rivals, index)
	end
	rival.chaser.model:Destroy()
	local ctx = context
	if ctx then
		if #rivals == 0 then
			ctx.finish()
		else
			ctx.announce(countText(), nil)
		end
	end
end

-- The richest player the fewest rivals are already after.
local function pickTarget(): Player?
	local best: Player? = nil
	local bestScore = -math.huge
	for _, player in Players:GetPlayers() do
		if targetable(player) then
			local chasers = 0
			for _, rival in rivals do
				if rival.target == player then
					chasers += 1
				end
			end
			local score = EconomyService.account(player).carried - chasers * 1e9
			if score > bestScore then
				best, bestScore = player, score
			end
		end
	end
	return best
end

-- A player shoved this rival: down for a moment, or out cold on the last shove.
local function shoved(rival: Rival, player: Player)
	local root = CharacterUtil.getRoot(player)
	if not root or rival.out then
		return
	end
	rival.hits += 1
	rival.target = player -- they come back for whoever shoved them
	-- Strong enough, one shove does it.
	local oneShove = Strength.of(player) >= Config.Shove.OneShoveAt
	if rival.hits < settings.Hits and not oneShove then
		local tier = Shove.power(player)
		rival.downUntil = os.clock() + settings.ShoveStunSeconds * (1 + (tier - 1) * 0.25)
		Shove.knockDown(rival.chaser.model, player, settings.ShoveStunSeconds, "Shove")
		return
	end
	rival.out = true
	Shove.knockDown(rival.chaser.model, player, 2, "KnockOut", true)
	local ctx = context
	local reward = math.floor(settings.Reward * (if ctx then ctx.tierMultiplier else 1) + 0.5)
	PayNotice.earn(player, reward, "Rival knocked out", "knocked out a rival", true)
	task.delay(1.6, function()
		if rival.chaser.model.Parent then
			remotes.JobFx:fireAll({ kind = "Poof", at = rival.chaser.root.Position })
			remove(rival)
		end
	end)
end

-- Nobody dies: at zero they sit down seeing stars, back at full health, and lose some cash.
local function hurt(target: Player)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if humanoid.Health - settings.Damage > 0 then
		humanoid.Health -= settings.Damage
		Juice.sound(target, "Stun")
		return
	end
	humanoid.Health = humanoid.MaxHealth
	Stun.player(target, settings.KnockdownSeconds)
	restUntil[target] = os.clock() + settings.KnockoutGraceSeconds
	local account = EconomyService.account(target)
	local taken = EconomyService.removeCarried(target, account.carried * settings.KnockoutTakePercent, "rival crew")
	Juice.lost(target, taken, "Rivals took your cash")
end

-- A swing at whoever's in reach: it lands a moment later if they're still there.
local function swipe(rival: Rival, target: Player)
	rival.nextSwipeAt = os.clock() + settings.SwipeSeconds + rng:NextNumber()
	Gestures.play(rival.chaser.model, "Swipe")
	Sounds.at("Swipe", rival.chaser.root)
	task.delay(WIND_UP, function()
		local root = CharacterUtil.getRoot(target)
		if rival.out or not rival.chaser.model.Parent or os.clock() < rival.downUntil or not root then
			return
		end
		local reach = (root.Position - rival.chaser.root.Position).Magnitude
		if reach > settings.ReachStuds + 1.5 or not targetable(target) or SafeZone.contains(root.Position) then
			return
		end
		if rng:NextNumber() < settings.HitChance then
			remotes.JobFx:fireAll({ kind = "Pow", at = root.Position + Vector3.new(0, 1.5, 0) })
			hurt(target)
		end
	end)
end

local function spawnRival(ctx: TownEvent.Context, near: Vector3, run: number)
	task.spawn(function()
		local look = NpcService.randomLook()
		local gang = Config.Outfits.Uniforms.Gang
		look.shirt, look.pants, look.top, look.bottom = HOODIE, HOODIE_DARK, gang.shirt, gang.pants
		local chaser = NpcChase.spawn("Rival Crew", look, near, settings.MinSpawnStuds, settings.Speed)
		if not chaser then
			return
		end
		if generation ~= run then
			chaser.model:Destroy()
			return
		end
		local rival: Rival = {
			chaser = chaser,
			target = nil,
			hits = 0,
			nextSwipeAt = os.clock() + rng:NextNumber(1, 2),
			downUntil = 0,
			out = false,
		}
		Shove.prompt(chaser.root, function(player: Player)
			shoved(rival, player)
		end)
		table.insert(rivals, rival)
		ctx.announce(countText(), nil)
	end)
end

function RivalCrew.start(ctx: TownEvent.Context)
	context = ctx
	local run = generation
	ctx.announce("Rivals in town! Shove them!", nil)
	for _ = 1, settings.Count do
		local target = pickTarget()
		local root = target and CharacterUtil.getRoot(target)
		if root then
			spawnRival(ctx, root.Position, run)
		end
	end
end

function RivalCrew.tick()
	local now = os.clock()
	for _, rival in table.clone(rivals) do
		if rival.out or now < rival.downUntil then
			continue
		end
		local target = rival.target
		if not target or not targetable(target) then
			target = pickTarget()
			rival.target = target
		end
		local targetRoot = target and CharacterUtil.getRoot(target)
		if not target or not targetRoot then
			NpcChase.hold(rival.chaser)
			continue
		end
		local root = rival.chaser.root
		local distance = (targetRoot.Position - root.Position).Magnitude
		if distance > settings.ReachStuds * 0.7 then
			NpcChase.step(rival.chaser, targetRoot.Position)
		else
			NpcChase.hold(rival.chaser)
			root.CFrame =
				CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
		end
		local safe = SafeZone.contains(targetRoot.Position) or SafeZone.contains(root.Position)
		if distance <= settings.ReachStuds and now >= rival.nextSwipeAt and not safe then
			swipe(rival, target)
		end
	end
end

function RivalCrew.stop()
	generation += 1
	context = nil
	for _, rival in rivals do
		rival.out = true
		rival.chaser.model:Destroy()
	end
	table.clear(rivals)
	table.clear(restUntil)
end

return RivalCrew
