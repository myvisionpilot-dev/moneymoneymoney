--!strict
-- Rival crew (from Events.RivalCrew.FromQuota): Count gang members with blasters go after the players carrying
-- the most cash. They walk up to StandOffStuds and shoot every ShotSeconds or so; HitChance of
-- their shots land, for Damage each. Nobody dies: knocked to zero, you sit down seeing stars,
-- back at full health, minus KnockoutTakePercent of your carried cash, and they leave you
-- alone for KnockoutGraceSeconds. Everyone without a blaster is lent a Zapper for the fight;
-- Hits zaps knock a rival out for a Reward. No shooting into or out of the bank, or at cars.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local BlasterService = require(script.Parent.Parent.BlasterService)
local EconomyService = require(script.Parent.Parent.EconomyService)
local JailService = require(script.Parent.Parent.JailService)
local Juice = require(script.Parent.Parent.Juice)
local Notifier = require(script.Parent.Parent.Notifier)
local NpcChase = require(script.Parent.Parent.NpcChase)
local NpcService = require(script.Parent.Parent.NpcService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local RunState = require(script.Parent.Parent.RunState)
local SafeZone = require(script.Parent.Parent.SafeZone)
local TownEvent = require(script.Parent.TownEvent)

local VEHICLE_ATTRIBUTE = "VehicleSpeed" -- in a kart or car
local STUN_ATTRIBUTE = "Stunned" -- already down
local HOODIE = Color3.fromRGB(110, 40, 140)
local HOODIE_DARK = Color3.fromRGB(40, 30, 50)

local settings = Config.Events.RivalCrew

type Rival = {
	chaser: NpcChase.Chaser,
	target: Player?,
	hits: number,
	nextShotAt: number,
	stunnedUntil: number,
}

local rivals: { Rival } = {}
local context: TownEvent.Context? = nil
local generation = 0
local restUntil: { [Player]: number } = {} -- knocked down: left alone until then
local lent: { Player } = {}
local rng = Random.new()

local RivalCrew = {
	id = "RivalCrew",
	title = "RIVAL CREW",
	seconds = settings.Seconds,
}

local function rivalFor(model: Model): Rival?
	for _, rival in rivals do
		if rival.chaser.model == model then
			return rival
		end
	end
	return nil
end

local function shootable(player: Player): boolean
	local character = player.Character
	return RosterService.isActive(player)
		and not JailService.isJailed(player)
		and character ~= nil
		and CharacterUtil.getRoot(player) ~= nil
		and character:GetAttribute(VEHICLE_ATTRIBUTE) == nil
		and not character:GetAttribute(STUN_ATTRIBUTE)
		and os.clock() >= (restUntil[player] or 0)
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
	return `{#rivals} rival{if #rivals == 1 then "" else "s"} with blasters. Zap them twice to knock them out!`
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
		if shootable(player) then
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

-- A player zapped this rival.
local function zapped(rival: Rival, shooter: Player, stunSeconds: number)
	rival.hits += 1
	rival.stunnedUntil = os.clock() + stunSeconds
	NpcChase.hold(rival.chaser)
	if rival.hits < settings.Hits then
		return
	end
	local ctx = context
	local reward = math.floor(settings.Reward * (if ctx then ctx.tierMultiplier else 1) + 0.5)
	PayNotice.earn(shooter, reward, "Rival knocked out", "knocked out a rival", true)
	remove(rival)
end

BlasterService.addTarget({
	isTarget = function(model: Model): boolean
		return rivalFor(model) ~= nil
	end,
	hit = function(model: Model, shooter: Player, stunSeconds: number)
		local rival = rivalFor(model)
		if rival then
			zapped(rival, shooter, stunSeconds)
		end
	end,
})

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
	BlasterService.stunPlayer(target)
	restUntil[target] = os.clock() + settings.KnockoutGraceSeconds
	local account = EconomyService.account(target)
	local taken = EconomyService.removeCarried(target, account.carried * settings.KnockoutTakePercent, "rival crew")
	Juice.lost(target, taken, "Knocked down by the rival crew")
	Notifier.send(target, "The rival crew knocked you down! They'll leave you alone for a bit.", "Bad")
end

local function headOf(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- Nothing in the way between the rival and their target.
local function clearShot(rival: Rival, target: Model, to: Vector3, from: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rival.chaser.model }
	local result = workspace:Raycast(from, to - from, params)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function shoot(rival: Rival, target: Player, character: Model)
	local rivalHead = headOf(rival.chaser.model)
	local targetHead = headOf(character)
	if not rivalHead or not targetHead then
		return
	end
	local from = rivalHead.Position
	if not clearShot(rival, character, targetHead.Position, from) then
		return
	end
	rival.nextShotAt = os.clock() + settings.ShotSeconds + rng:NextNumber()
	if rng:NextNumber() < settings.HitChance then
		BlasterService.effect(from, targetHead.Position)
		hurt(target)
	else
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
		BlasterService.effect(from, targetHead.Position + off.Unit * rng:NextNumber(3, 6))
	end
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
		local blaster = BlasterService.prop("Zapper")
		blaster.Parent = chaser.model
		chaser.humanoid:EquipTool(blaster)
		table.insert(rivals, {
			chaser = chaser,
			target = nil,
			hits = 0,
			nextShotAt = os.clock() + rng:NextNumber(1, 2),
			stunnedUntil = 0,
		})
		ctx.announce(countText(), nil)
	end)
end

function RivalCrew.start(ctx: TownEvent.Context)
	context = ctx
	local run = generation
	for _, player in Players:GetPlayers() do
		if RosterService.isActive(player) and BlasterService.lend(player) then
			table.insert(lent, player)
			Notifier.send(
				player,
				"The bank lent you a Zapper for this fight. Press 1 to draw it, click to zap.",
				"Info"
			)
		end
	end
	ctx.announce("A rival crew with blasters is in town, after your cash. Zap them back!", nil)
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
		if now < rival.stunnedUntil then
			NpcChase.hold(rival.chaser)
			continue
		end
		local target = rival.target
		if not target or not shootable(target) then
			target = pickTarget()
			rival.target = target
		end
		local character = target and target.Character
		local targetRoot = target and CharacterUtil.getRoot(target)
		if not target or not character or not targetRoot then
			NpcChase.hold(rival.chaser)
			continue
		end
		local root = rival.chaser.root
		local distance = (targetRoot.Position - root.Position).Magnitude
		if distance > settings.StandOffStuds then
			NpcChase.step(rival.chaser, targetRoot.Position)
		else
			NpcChase.hold(rival.chaser)
			root.CFrame =
				CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
		end
		local safe = SafeZone.contains(targetRoot.Position) or SafeZone.contains(root.Position)
		if distance <= settings.ShootRangeStuds and now >= rival.nextShotAt and not safe then
			shoot(rival, target, character)
		end
	end
end

function RivalCrew.stop()
	generation += 1
	context = nil
	for _, rival in rivals do
		rival.chaser.model:Destroy()
	end
	table.clear(rivals)
	for _, player in lent do
		BlasterService.takeBack(player)
	end
	table.clear(lent)
	table.clear(restUntil)
end

return RivalCrew
