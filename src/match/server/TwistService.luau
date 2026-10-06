--!strict
-- Quota twists: from Twists.FromQuota each quota rolls one rule change (two in endless quotas
-- from Twists.DoubleFromQuota), never one from the quota before. Plus the late-game pressure
-- from Pressure.FromQuota: faster cops, and more of them. Pay, heat, police and shops ask here
-- for their multipliers.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local RunState = require(script.Parent.RunState)

type Twist = Config.Twist

local settings = Config.Twists
local pressure = Config.Pressure
local LIST = settings.List
local NIGHT_TWEEN = TweenInfo.new(6, Enum.EasingStyle.Sine)

local TwistService = {
	changed = Signal.new() :: Signal.Signal<()>,
}

local active: { Twist } = {}
local dayTime = Lighting.ClockTime
local rng = Random.new()

local function product(field: (twist: Twist) -> number?): number
	local total = 1
	for _, twist in active do
		total *= field(twist) or 1
	end
	return total
end

local function setNight(night: boolean)
	local goal = if night then settings.NightClockTime else dayTime
	if Lighting.ClockTime ~= goal then
		TweenService:Create(Lighting, NIGHT_TWEEN, { ClockTime = goal }):Play()
	end
end

local function apply(list: { Twist })
	active = list
	local night = false
	for _, twist in list do
		night = night or twist.night == true
	end
	setNight(night)
	TwistService.changed:Fire()
end

-- Picks this quota's twists (none before Twists.FromQuota) and returns them.
function TwistService.roll(quotaIndex: number): { Types.TwistView }
	if quotaIndex < settings.FromQuota then
		apply({})
		return TwistService.views()
	end
	local count = if quotaIndex >= settings.DoubleFromQuota then 2 else 1
	local pool: { Twist } = {}
	for _, twist in LIST do
		if not table.find(active, twist) then
			table.insert(pool, twist)
		end
	end
	local picked: { Twist } = {}
	for _ = 1, math.min(count, #pool) do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)) :: Twist)
	end
	apply(picked)
	return TwistService.views()
end

-- Debug: force one twist by id (or none with nil). Returns false for an unknown id.
function TwistService.force(id: string?): boolean
	if id == nil then
		apply({})
		return true
	end
	for _, twist in LIST do
		if twist.id:lower() == id:lower() then
			apply({ twist })
			return true
		end
	end
	return false
end

function TwistService.clear()
	apply({})
end

function TwistService.views(): { Types.TwistView }
	local views = {}
	for _, twist in active do
		table.insert(views, { id = twist.id, title = twist.title, detail = twist.detail })
	end
	return views
end

-- Pay for a money path id or door job kind (illegal jobs also get any crimePay).
function TwistService.payMultiplier(kind: string, legal: boolean): number
	return product(function(twist: Twist): number?
		local pay = twist.pay
		local byKind = if pay then pay[kind] else nil
		return (byKind or 1) * (if legal then 1 else twist.crimePay or 1)
	end)
end

function TwistService.heatMultiplier(): number
	return product(function(twist: Twist): number?
		return twist.heat
	end)
end

function TwistService.crimeHoldMultiplier(): number
	return product(function(twist: Twist): number?
		return twist.crimeHold
	end)
end

function TwistService.spotMultiplier(): number
	return product(function(twist: Twist): number?
		return twist.spot
	end)
end

function TwistService.shopPriceMultiplier(): number
	return product(function(twist: Twist): number?
		return twist.shopPrice
	end)
end

-- Quotas from Pressure.FromQuota on (1 at that quota, 2 at the next...).
local function pressureSteps(): number
	return math.max(0, RunState.quotaIndex - pressure.FromQuota + 1)
end

function TwistService.copSpeedMultiplier(): number
	local building = math.min(1 + pressure.CopSpeedPerQuota * pressureSteps(), pressure.MaxCopSpeed)
	return building * product(function(twist: Twist): number?
		return twist.copSpeed
	end)
end

function TwistService.copsPerStar(): number
	local base = Config.Police.CopsPerStar + pressure.CopsPerStarPerQuota * pressureSteps()
	return base * product(function(twist: Twist): number?
		return twist.cops
	end)
end

return TwistService
