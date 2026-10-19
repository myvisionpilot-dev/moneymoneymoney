--!strict
-- The Lucky Wheel's maths, shared by the lobby server (which builds it and picks every spin) and
-- each client (which turns it, so everyone watches the same spin): where the wheel stands,
-- the slices' angles, where a spin stops and how it slows down. Angles are degrees clockwise
-- from the top as you face the wheel; the pointer is at the top.

local Config = require(script.Parent.Config)

local Wheel = {}

local settings = Config.Wheel

Wheel.Slices = settings.Slices
Wheel.SliceAngle = 360 / #settings.Slices
Wheel.Radius = 6.5 -- the slices; the rim sits just outside
Wheel.HubHeight = 10 -- the middle of the wheel above the floor
Wheel.Thickness = 0.5

-- The hub's frame where Config.Wheel puts it (a place without a saved wheel): X to the right and
-- Y up as you face it, Z out toward you.
function Wheel.frame(): CFrame
	local facing = settings.Facing.Unit
	local hub = settings.Position + Vector3.new(0, Wheel.HubHeight, 0)
	return CFrame.lookAt(hub, hub - facing)
end

-- Out from the hub toward `angle` (in the wheel's own frame).
function Wheel.direction(angle: number): Vector3
	local radians = math.rad(angle)
	return Vector3.new(math.sin(radians), math.cos(radians), 0)
end

-- The middle of slice `index`, before any turning.
function Wheel.centre(index: number): number
	return (index - 1) * Wheel.SliceAngle
end

-- The chance of landing on a slice (0..1).
function Wheel.chance(index: number): number
	local total = 0
	for _, slice in settings.Slices do
		total += slice.weight
	end
	return settings.Slices[index].weight / total
end

-- The slice under the pointer once the wheel has turned `angle` degrees.
function Wheel.sliceAt(angle: number): number
	local under = -angle % 360
	return math.floor((under + Wheel.SliceAngle / 2) / Wheel.SliceAngle) % #settings.Slices + 1
end

-- Where a spin starting at `from` stops so slice `index` is under the pointer: `turns` whole
-- turns and then the rest of the way, `nudge` (-1..1) off the slice's middle.
function Wheel.stopAt(from: number, index: number, turns: number, nudge: number): number
	local stop = (-Wheel.centre(index) + nudge * Wheel.SliceAngle * 0.35) % 360
	local rest = (stop - from) % 360
	return from + turns * 360 + rest
end

-- How far through its turning a spin is, `t` (0..1) of the way through its time: quick at
-- first, then slowing to a stop.
function Wheel.ease(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) ^ 4
end

-- What a slice says on the wheel and on the odds board.
function Wheel.label(slice: Config.WheelSlice): string
	if slice.jackpot then
		return "JACKPOT"
	elseif slice.cosmetic then
		return `{slice.cosmetic:upper()} ITEM`
	end
	return `{slice.cred or 0}`
end

return Wheel
