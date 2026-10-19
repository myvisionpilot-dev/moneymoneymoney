--!strict
-- CASH PARADE: a float rolls round the town loop (the RaceCheckpoint parts, in Order) at
-- walking pace for Events.CashParade.Seconds, throwing bills out around it (LooseCash). Follow
-- it and scoop them up. The float is an invisible anchored marker tagged ParadeFloat that
-- client/EventPropsController dresses up; the event's marker follows it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local LooseCash = require(script.Parent.LooseCash)
local TownEvent = require(script.Parent.TownEvent)

local ROUTE_TAG = "RaceCheckpoint"
local FLOAT_TAG = "ParadeFloat"
local THROW_STUDS = { 5, 12 } -- how far from the float the bills land
local MARK_SECONDS = 1
local DETAIL = "Follow the float! Grab the cash!"

local settings = Config.Events.CashParade
local rng = Random.new()

local float: Part? = nil
local context: TownEvent.Context? = nil
local route: { Vector3 } = {}
local nextPoint = 1
local position = Vector3.zero
local billValue = 0
local lastTick, lastThrow, lastMark = 0, 0, 0

local CashParade = {
	id = "CashParade",
	title = "CASH PARADE",
	seconds = settings.Seconds,
}

local function loadRoute(): { Vector3 }
	local points: { { position: Vector3, order: number } } = {}
	for _, instance in CollectionService:GetTagged(ROUTE_TAG) do
		local order = instance:GetAttribute("Order")
		if instance:IsA("BasePart") and typeof(order) == "number" then
			table.insert(points, { position = JobKit.ground(instance).Position, order = order })
		end
	end
	table.sort(points, function(a, b)
		return a.order < b.order
	end)
	local list = {}
	for _, point in points do
		table.insert(list, point.position)
	end
	return list
end

function CashParade.canStart(): boolean
	return #loadRoute() >= 3
end

function CashParade.start(ctx: TownEvent.Context)
	context = ctx
	route = loadRoute()
	local first = rng:NextInteger(1, #route)
	position = route[first]
	nextPoint = first % #route + 1
	billValue = math.floor(settings.BillValue * ctx.tierMultiplier + 0.5)
	lastTick, lastThrow, lastMark = os.clock(), os.clock(), os.clock()
	local part = Instance.new("Part")
	part.Name = "ParadeFloat"
	part.Size = Vector3.new(10, 1, 16)
	part.CFrame = CFrame.lookAt(position, route[nextPoint])
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:AddTag(FLOAT_TAG)
	part.Parent = workspace
	float = part
	ctx.announce(DETAIL, position)
end

-- Rolls on along the loop, throws bills now and then, and keeps everyone's marker on it.
function CashParade.tick()
	local part = float
	local ctx = context
	if not part or not ctx then
		return
	end
	local now = os.clock()
	local step = settings.Speed * (now - lastTick)
	lastTick = now
	while step > 0 do
		local target = route[nextPoint]
		local toTarget = target - position
		if toTarget.Magnitude <= step then
			position = target
			step -= toTarget.Magnitude
			nextPoint = nextPoint % #route + 1
		else
			position += toTarget.Unit * step
			step = 0
		end
	end
	local ahead = route[nextPoint]
	if (ahead - position).Magnitude > 0.1 then
		part.CFrame = CFrame.lookAt(position, Vector3.new(ahead.X, position.Y, ahead.Z))
	end
	while now - lastThrow >= settings.DropEverySeconds do
		lastThrow += settings.DropEverySeconds
		local ground = LooseCash.groundAround(position, THROW_STUDS[1], THROW_STUDS[2])
		if ground then
			LooseCash.drop(ground, billValue, "Parade cash")
		end
	end
	if now - lastMark >= MARK_SECONDS then
		lastMark = now
		ctx.announce(DETAIL, position)
	end
end

function CashParade.stop()
	context = nil
	if float then
		float:Destroy()
		float = nil
	end
end

return CashParade
