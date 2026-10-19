--!strict
-- MONEY RAIN: a green cloud parks over one part of town and bills pour out of it for
-- Events.MoneyRain.Seconds. Run underneath and walk over them to pocket them (LooseCash).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Particles = require(ReplicatedStorage.Shared.Particles)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local LooseCash = require(script.Parent.LooseCash)
local Spots = require(script.Parent.Spots)
local TownEvent = require(script.Parent.TownEvent)

local CLOUD_HEIGHT = 55
local CLOUD_COLOR = Color3.fromRGB(125, 160, 125)

local settings = Config.Events.MoneyRain
local rng = Random.new()

local cloud: Model? = nil
local center = Vector3.zero
local billValue = 0
local due = 0 -- bills owed to the ground (fractions carry over)
local lastTick = 0

local MoneyRain = {
	id = "MoneyRain",
	title = "MONEY RAIN",
	seconds = settings.Seconds,
}

function MoneyRain.canStart(): boolean
	return Spots.random() ~= nil
end

-- Big soft puffs, raining notes.
local function buildCloud(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "MoneyCloud"
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2
		local reach = if index == 10 then 0 else rng:NextNumber(8, settings.RadiusStuds * 0.55)
		local size = rng:NextNumber(14, 24)
		local puff = JobKit.prop(
			model,
			"Puff",
			Vector3.new(size, size, size),
			CFrame.new(at + Vector3.new(math.cos(angle) * reach, rng:NextNumber(-3, 4), math.sin(angle) * reach)),
			CLOUD_COLOR
		)
		puff.Shape = Enum.PartType.Ball
		puff.Transparency = 0.2
		Particles.keep(puff, "Bills", 6, nil, 1.6)
	end
	model.Parent = workspace
	return model
end

function MoneyRain.start(ctx: TownEvent.Context)
	center = Spots.random() or Vector3.zero
	billValue = math.floor(settings.BillValue * ctx.tierMultiplier + 0.5)
	due = 0
	lastTick = os.clock()
	cloud = buildCloud(center + Vector3.new(0, CLOUD_HEIGHT, 0))
	ctx.announce("Money rain! Grab the bills!", center)
end

function MoneyRain.tick()
	local now = os.clock()
	due += (now - lastTick) * settings.BillsPerSecond
	lastTick = now
	while due >= 1 do
		due -= 1
		-- Anywhere under the cloud (but not on a roof), evenly spread.
		local ground = LooseCash.groundAround(center, 0, settings.RadiusStuds)
		if ground then
			LooseCash.drop(ground, billValue, "Money rain")
		end
	end
end

function MoneyRain.stop()
	if cloud then
		cloud:Destroy()
		cloud = nil
	end
end

return MoneyRain
