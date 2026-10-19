--!strict
-- MONEY TORNADO: a whirlwind full of cash wanders the streets (from spot to spot round town)
-- for Events.MoneyTornado.Seconds. Stand inside it and it pays you every second (LooseCash.owe,
-- paid in lumps). It's an invisible anchored marker tagged MoneyTornado that
-- client/EventPropsController turns into the twister; the howl comes from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local LooseCash = require(script.Parent.LooseCash)
local Spots = require(script.Parent.Spots)
local TownEvent = require(script.Parent.TownEvent)

local TAG = "MoneyTornado"
local WANDER_STUDS = { 40, 160 } -- how far each leg goes
local MARK_SECONDS = 1
local DETAIL = "Stand in the tornado to get paid!"

local settings = Config.Events.MoneyTornado

local anchor: Part? = nil
local context: TownEvent.Context? = nil
local position = Vector3.zero
local target = Vector3.zero
local perSecond = 0
local lastTick, lastMark = 0, 0

local MoneyTornado = {
	id = "MoneyTornado",
	title = "MONEY TORNADO",
	seconds = settings.Seconds,
}

function MoneyTornado.canStart(): boolean
	return #Spots.all() >= 2
end

function MoneyTornado.start(ctx: TownEvent.Context)
	context = ctx
	position = Spots.random() or Vector3.zero
	target = Spots.around(position, WANDER_STUDS[1], WANDER_STUDS[2]) or position
	perSecond = settings.PayPerSecond * ctx.tierMultiplier
	lastTick, lastMark = os.clock(), os.clock()
	local part = Instance.new("Part")
	part.Name = "MoneyTornado"
	part.Size = Vector3.new(2, 2, 2)
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Radius", settings.RadiusStuds)
	part:AddTag(TAG)
	part.Parent = workspace
	anchor = part
	Sounds.at("Wind", part, true)
	ctx.announce(DETAIL, position)
end

function MoneyTornado.tick()
	local part = anchor
	local ctx = context
	if not part or not ctx then
		return
	end
	local now = os.clock()
	local dt = now - lastTick
	lastTick = now
	-- Wander: head for the next spot, then pick another.
	local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	local step = settings.Speed * dt
	if flat.Magnitude <= step then
		position = Vector3.new(target.X, target.Y, target.Z)
		target = Spots.around(position, WANDER_STUDS[1], WANDER_STUDS[2]) or position
	else
		position += flat.Unit * step
		position = Vector3.new(position.X, target.Y, position.Z)
	end
	part.CFrame = CFrame.new(position)
	-- Anyone standing in it gets paid for the time they were in.
	for _, person in LooseCash.people() do
		local offset = person.at - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= settings.RadiusStuds and offset.Y < 30 then
			LooseCash.owe(person.player, perSecond * dt, "Money tornado")
		end
	end
	if now - lastMark >= MARK_SECONDS then
		lastMark = now
		ctx.announce(DETAIL, position)
	end
end

function MoneyTornado.stop()
	context = nil
	if anchor then
		anchor:Destroy()
		anchor = nil
	end
end

return MoneyTornado
