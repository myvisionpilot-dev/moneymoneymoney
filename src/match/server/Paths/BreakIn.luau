--!strict
-- Break-ins: every house has a back door. Hold E there to pick the lock (shorter with a lockpick,
-- gloves and the rest: ShopService.breakInHoldSeconds) and you're in its living room
-- (BreakInRooms builds it far above town; everyone who breaks into that house meanwhile shares
-- it). Grab the cash hidden round the room, but don't touch a red laser (your own screen tells us
-- if you do: client/BreakInController): the alarm goes, the rest of the cash is locked away, you
-- get Heat.BreakIn, the police head for the back door, and in AlarmSeconds you're put outside.
-- You keep what you grabbed. Leave by the door you came in. A house that was robbed (or set off)
-- rests for RestSeconds.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local BreakInRooms = require(script.Parent.Parent.BreakInRooms)
local DoorKnock = require(script.Parent.DoorKnock)
local HeatService = require(script.Parent.Parent.HeatService)
local JailService = require(script.Parent.Parent.JailService)
local MoneyPath = require(script.Parent.MoneyPath)
local MovementGuard = require(script.Parent.Parent.MovementGuard)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local ShopService = require(script.Parent.Parent.ShopService)
local Stats = require(script.Parent.Parent.Stats)
local TutorialState = require(script.Parent.Parent.TutorialState)

local HOUSE_TAG = "House"
local DOOR_PROMPT = "BreakInPrompt" -- client/BreakInController sets its hold time to yours
local INSIDE_ATTRIBUTE = "Inside" -- on your character: the house you're in
local OUTSIDE_ATTRIBUTE = "OutsideAt" -- on your character: its back door (where the police wait)
local HOLD_ATTRIBUTE = "BreakInHold" -- on you: how long you take to pick a back door
local ALARM_ATTRIBUTE = "AlarmEndsAt" -- on the room: when everyone is put outside
local PROMPT_RANGE = 8
local GRAB_RANGE = 6
local RANGE_SLACK = 3
local STREAM_SECONDS = 3
local TICK_SECONDS = 0.5

local settings = Config.Paths.BreakIn
local remotes = Remotes.match()
local tripLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local promptLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)

type House = {
	id: number,
	tier: number,
	door: BasePart, -- the back door we put on
	prompt: ProximityPrompt,
	outside: CFrame, -- where you come back out, facing away from the house
	restUntil: number,
	visit: Visit?,
}

type Visit = {
	house: House,
	room: BreakInRooms.Room,
	inside: { [Player]: boolean },
	piles: { [BasePart]: number }, -- what's left, and what each is worth
	alarmEndsAt: number?,
	robbed: boolean, -- some cash went, or the alarm did: the house rests afterwards
	moving: number, -- players on their way in or out (the room stays till they're through)
}

local houses: { House } = {}
local inside: { [Player]: Visit } = {}
local entering: { [Player]: boolean } = {}
local context: MoneyPath.Context? = nil

local doorFolder = Instance.new("Folder")
doorFolder.Name = "BreakInDoors"
local roomFolder = Instance.new("Folder")
roomFolder.Name = "BreakInRooms"

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("BreakIn used before init")
	end
	return current
end

-- Back doors ------------------------------------------------------------------------------

local DOOR_COLORS = { -- by tier
	Color3.fromRGB(150, 92, 52),
	Color3.fromRGB(120, 70, 45),
	Color3.fromRGB(40, 58, 92),
	Color3.fromRGB(34, 32, 38),
}
local TRIM = Color3.fromRGB(240, 236, 226)
local KNOB = Color3.fromRGB(255, 200, 60)
local MAT = Color3.fromRGB(120, 84, 56)

local function doorPart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	collide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A door, its frame, a knob, a mat and a little lamp on the back wall, `back` being the house's
-- BackDoor attachment (just outside the wall, at standing height).
local function buildDoor(id: number, tier: number, back: Attachment, look: Vector3): (BasePart, CFrame)
	local out = -Vector3.new(look.X, 0, look.Z).Unit
	local ground = back.WorldPosition.Y - 3
	local wall = Vector3.new(back.WorldPosition.X, ground, back.WorldPosition.Z) - out * 1.5
	local right = out:Cross(Vector3.yAxis)
	local function at(o: number, y: number, x: number?): CFrame
		local position = wall + out * o + Vector3.yAxis * y + right * (x or 0)
		return CFrame.lookAt(position, position + out)
	end
	local model = Instance.new("Model")
	model.Name = `BackDoor{id}`
	local color = DOOR_COLORS[math.clamp(tier, 1, #DOOR_COLORS)]
	local door = doorPart(model, "Door", Vector3.new(4, 7, 0.3), at(0.15, 3.5), color, true)
	for _, y in { 5.2, 2.1 } do
		doorPart(model, "Panel", Vector3.new(2.8, 2.3, 0.06), at(0.32, y), color:Lerp(Color3.new(), 0.18), false)
	end
	for _, x in { -2.2, 2.2 } do
		doorPart(model, "Frame", Vector3.new(0.4, 7.4, 0.42), at(0.2, 3.7, x), TRIM, true)
	end
	doorPart(model, "Frame", Vector3.new(4.8, 0.4, 0.42), at(0.2, 7.2), TRIM, true)
	local knob = doorPart(model, "Knob", Vector3.new(0.45, 0.45, 0.45), at(0.42, 3.3, 1.4), KNOB, false)
	knob.Shape = Enum.PartType.Ball
	knob.Material = Enum.Material.Metal
	local mat = doorPart(model, "Mat", Vector3.new(3.4, 0.12, 1.8), at(1.25, 0.06), MAT, false)
	mat.Material = Enum.Material.Fabric
	local lamp =
		doorPart(model, "Lamp", Vector3.new(0.7, 0.7, 0.7), at(0.45, 8.1), Color3.fromRGB(255, 226, 150), false)
	lamp.Shape = Enum.PartType.Ball
	lamp.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 0.35
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp
	model.Parent = doorFolder
	return door, at(3, 3)
end

-- Rooms -----------------------------------------------------------------------------------

local function roomOrigin(id: number): Vector3
	local slot = id - 1
	return Vector3.new(5_000 + (slot % 10) * settings.Spacing, settings.Height, (slot // 10) * settings.Spacing)
end

local function hide(laser: BasePart)
	laser.Transparency = 1
	local glow = laser:FindFirstChild("GlowPart")
	if glow and glow:IsA("ObjectValue") and glow.Value and glow.Value:IsA("BasePart") then
		glow.Value.Transparency = 1
	end
end

local leave: (player: Player, message: string?) -> ()

-- Takes the room down once nobody's in it or on their way through.
local function closeIfEmpty(visit: Visit)
	local house = visit.house
	if house.visit ~= visit or next(visit.inside) ~= nil or visit.moving > 0 then
		return
	end
	house.visit = nil
	visit.room.model:Destroy()
	if visit.robbed then
		house.restUntil = Timing.now() + settings.RestSeconds
	end
end

local function pilesLeft(visit: Visit): number
	local left = 0
	for _ in visit.piles do
		left += 1
	end
	return left
end

local function grab(visit: Visit, player: Player, cash: BasePart, prompt: ProximityPrompt)
	local value = visit.piles[cash]
	if
		not value
		or inside[player] ~= visit
		or visit.alarmEndsAt
		or not PromptGuard.held(prompt, player)
		or CharacterUtil.distanceTo(player, cash.Position) > GRAB_RANGE + RANGE_SLACK
	then
		return
	end
	visit.piles[cash] = nil
	visit.robbed = true
	local pile = cash.Parent
	Sounds.at("CashGrab", visit.room.exit)
	if pile and pile ~= visit.room.model then
		pile:Destroy()
	else
		cash:Destroy()
	end
	PayNotice.earn(player, value, "Cash found", "break-in", false)
	local left = pilesLeft(visit)
	visit.room.model:SetAttribute("PilesLeft", left)
	if left == 0 then
		for someone in visit.inside do
			Notifier.send(someone, "That's all of it! Head back out the door.", "Good")
		end
	end
end

local function open(house: House): Visit
	local room = BreakInRooms.build(house.id, house.tier, roomOrigin(house.id), roomFolder)
	room.model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local visit: Visit = {
		house = house,
		room = room,
		inside = {},
		piles = {},
		alarmEndsAt = nil,
		robbed = false,
		moving = 0,
	}
	local total = settings.Cash[math.clamp(house.tier, 1, #settings.Cash)]
		* getContext().payMultiplier("BreakIn", false)
	local each = math.max(math.floor(total / math.max(#room.piles, 1) + 0.5), 1)
	for _, cash in room.piles do
		visit.piles[cash] = each
		cash:SetAttribute("Value", each)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GrabPrompt"
		prompt.ActionText = "Grab"
		prompt.ObjectText = ""
		prompt.HoldDuration = settings.GrabHoldSeconds
		prompt.MaxActivationDistance = GRAB_RANGE
		prompt.RequiresLineOfSight = false
		PromptGuard.watch(prompt)
		prompt.Triggered:Connect(function(player: Player)
			if promptLimiter:allow(player) then
				grab(visit, player, cash, prompt)
			end
		end)
		prompt.Parent = cash
	end
	room.model:SetAttribute("Piles", #room.piles)
	room.model:SetAttribute("PilesLeft", #room.piles)

	local exit = Instance.new("ProximityPrompt")
	exit.Name = "LeavePrompt"
	exit.ActionText = "Leave"
	exit.ObjectText = ""
	exit.HoldDuration = 0.4
	exit.MaxActivationDistance = PROMPT_RANGE
	exit.RequiresLineOfSight = false
	PromptGuard.watch(exit)
	exit.Triggered:Connect(function(player: Player)
		if inside[player] == visit and PromptGuard.held(exit, player) then
			leave(player, nil)
		end
	end)
	exit.Parent = room.exit

	house.visit = visit
	return visit
end

-- In and out -------------------------------------------------------------------------------

local function setAttributes(character: Model?, house: House?)
	if character then
		character:SetAttribute(INSIDE_ATTRIBUTE, if house then house.id else nil)
		character:SetAttribute(OUTSIDE_ATTRIBUTE, if house then house.outside.Position else nil)
	end
end

-- Forgets them: puts them back outside first, unless `stay` (they've gone, died or been jailed).
local function forget(player: Player, stay: boolean)
	local visit = inside[player]
	if not visit then
		return
	end
	inside[player] = nil
	visit.inside[player] = nil
	local character = player.Character
	if stay or not character then
		setAttributes(character, nil)
		closeIfEmpty(visit)
		return
	end
	local out = visit.house.outside
	visit.moving += 1
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(out.Position, STREAM_SECONDS)
		end)
		if player.Character == character and not inside[player] then
			if not JailService.isJailed(player) then
				MovementGuard.teleport(player, out)
				Sounds.at("DoorOpen", visit.house.door)
			end
			setAttributes(character, nil)
		end
		visit.moving -= 1
		closeIfEmpty(visit)
	end)
end

leave = function(player: Player, message: string?)
	forget(player, false)
	if message then
		Notifier.send(player, message, "Info")
	end
end

local function enter(player: Player, house: House): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, "It's locked up tight. Try again when a quota starts."
	end
	if TutorialState.isIn(player) then
		return false, "Finish the tutorial first."
	end
	if not ctx.canWork(player) or inside[player] or entering[player] then
		return false, nil
	end
	if ctx.isBusy(player) and DoorKnock.jobKind(player) ~= "BreakIn" then
		return false, "Finish your current job first."
	end
	if CharacterUtil.distanceTo(player, house.door.Position) > PROMPT_RANGE + RANGE_SLACK then
		return false, nil
	end
	local now = Timing.now()
	if house.restUntil > now then
		return false, `Already cleaned out. Try again in {math.ceil(house.restUntil - now)}s.`
	end
	local visit = house.visit or open(house)
	if visit.alarmEndsAt then
		return false, "The alarm's going off in there!"
	end
	local character = player.Character
	entering[player] = true
	visit.moving += 1
	pcall(function()
		player:RequestStreamAroundAsync(visit.room.spawn.Position, STREAM_SECONDS)
	end)
	entering[player] = nil
	visit.moving -= 1
	if
		house.visit ~= visit
		or visit.alarmEndsAt
		or player.Character ~= character
		or not character
		or not ctx.canWork(player)
	then
		closeIfEmpty(visit)
		return false, nil
	end
	inside[player] = visit
	visit.inside[player] = true
	setAttributes(character, house)
	Sounds.at("LockOpen", house.door)
	MovementGuard.teleport(player, visit.room.spawn)
	if DoorKnock.jobKind(player) == "BreakIn" then
		DoorKnock.closeJob(player) -- the tip-off's done: they're in
	end
	Stats.record(player, "BreakIn")
	return true, "Find the cash. Don't touch the lasers!"
end

local function trip(player: Player)
	local visit = inside[player]
	if not visit or visit.alarmEndsAt then
		return
	end
	local house = visit.house
	visit.alarmEndsAt = Timing.now() + settings.AlarmSeconds
	visit.robbed = true
	local model = visit.room.model
	model:SetAttribute(ALARM_ATTRIBUTE, visit.alarmEndsAt)
	for _, laser in visit.room.lasers do
		hide(laser)
	end
	-- The rest of the cash is locked away.
	for cash in visit.piles do
		local pile = cash.Parent
		if pile and pile ~= model then
			pile:Destroy()
		end
	end
	table.clear(visit.piles) -- (PilesLeft stays as it was: the panel still shows what was found)
	Sounds.at("Alarm", visit.room.exit, true)
	Sounds.at("Alarm", house.door)
	HeatService.add(player, Config.Heat.BreakIn[math.clamp(house.tier, 1, #Config.Heat.BreakIn)])
	for someone in visit.inside do
		Notifier.send(
			someone,
			if someone == player
				then "You tripped the alarm! The police are coming. Get out!"
				else "Someone tripped the alarm! Get out!",
			"Bad"
		)
	end
end

-- Setup -----------------------------------------------------------------------------------

local function setupHouse(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local id = instance:GetAttribute("HouseId")
	local tier = instance:GetAttribute("Tier")
	local back = instance:FindFirstChild("BackDoor")
	if typeof(id) ~= "number" or not back or not back:IsA("Attachment") then
		return
	end
	for _, house in houses do
		if house.id == id then
			return
		end
	end
	local houseTier = if typeof(tier) == "number" then tier else 1
	local door, outside = buildDoor(id, houseTier, back, instance.CFrame.LookVector)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = DOOR_PROMPT
	prompt.ActionText = "Break in"
	prompt.ObjectText = "" -- no names on houses
	prompt.HoldDuration = Config.Paths.Doors.BaseBreakInHoldSeconds
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	PromptGuard.watch(prompt)
	local house: House = {
		id = id,
		tier = houseTier,
		door = door,
		prompt = prompt,
		outside = outside,
		restUntil = 0,
		visit = nil,
	}
	prompt.Triggered:Connect(function(player: Player)
		if
			not promptLimiter:allow(player)
			or not PromptGuard.held(prompt, player, ShopService.breakInHoldSeconds(player))
		then
			return
		end
		local _, message = enter(player, house)
		if message then
			Notifier.send(player, message, if inside[player] then "Info" else "Bad")
		end
	end)
	prompt.Parent = door
	table.insert(houses, house)
end

local function tick()
	local now = Timing.now()
	for _, house in houses do
		house.prompt.Enabled = house.restUntil <= now
		local visit = house.visit
		if visit and visit.alarmEndsAt and now >= visit.alarmEndsAt then
			for player in table.clone(visit.inside) do
				leave(player, "You slipped out the back!")
			end
		end
	end
	-- How long each of them takes to pick a back door (it can change with a boost or a twist).
	for _, player in Players:GetPlayers() do
		local seconds = math.floor(ShopService.breakInHoldSeconds(player) * 100 + 0.5) / 100
		if player:GetAttribute(HOLD_ATTRIBUTE) ~= seconds then
			player:SetAttribute(HOLD_ATTRIBUTE, seconds)
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	doorFolder.Parent = workspace
	roomFolder.Parent = workspace
	for _, instance in CollectionService:GetTagged(HOUSE_TAG) do
		setupHouse(instance)
	end
	CollectionService:GetInstanceAddedSignal(HOUSE_TAG):Connect(setupHouse)
	remotes.TripLaser:onServer(function(player: Player)
		if tripLimiter:allow(player) then
			trip(player)
		end
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			forget(player, true)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		forget(player, true)
		entering[player] = nil
	end)
	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceTick += dt
		if sinceTick >= TICK_SECONDS then
			sinceTick = 0
			tick()
		end
	end)
end

local function start(player: Player, source: Instance?): (boolean, string?)
	for _, house in houses do
		if source == house.door then
			return enter(player, house)
		end
	end
	return false, nil
end

local function complete(_player: Player): (boolean, string?)
	return false, "Leave by the door you came in."
end

local function fail(player: Player, _reason: string)
	forget(player, JailService.isJailed(player))
end

local function payout(_player: Player, _tier: number): number
	return 0
end

local function hasJob(player: Player): boolean
	return inside[player] ~= nil
end

local function cancelAll(_reason: string)
	for player in table.clone(inside) do
		leave(player, nil)
	end
end

local BreakIn: MoneyPath.MoneyPath = {
	id = "BreakIn",
	displayName = "Break-ins",
	unlockQuota = Config.Paths.Unlocks.BreakIn,
	legal = false,
	init = init,
	start = start,
	complete = complete,
	fail = fail,
	payout = payout,
	hasJob = hasJob,
	cancelAll = cancelAll,
}

-- Debug (/breakin): out of any house they're in, to house `id`'s back door and straight in (it
-- stops resting first).
local function debugEnter(player: Player, id: number): (boolean, string?)
	for _, house in houses do
		if house.id == id then
			forget(player, true)
			house.restUntil = 0
			MovementGuard.teleport(player, house.outside)
			return enter(player, house)
		end
	end
	return false, "No house with that number"
end

return {
	path = BreakIn,
	debugEnter = debugEnter,
}
