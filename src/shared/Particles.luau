--!strict
-- Particle effects built in code from Roblox's own textures (nothing uploaded): presets for
-- sparkles, stars, coins, bills, confetti, fire, smoke, rings, glows, flashes, swirls, bubbles,
-- sparks and snow. Particles.burst throws a mix of them out at a point once;
-- Particles.keep leaves one running on a part or attachment (an aura, a trail's sparkle).
-- `scale` grows a preset's size and speed together; colours tint it (a ColorSequence runs
-- through colours over each particle's life).

local Debris = game:GetService("Debris")

export type Preset =
	"Sparkles"
	| "Stars"
	| "Coins"
	| "Bills"
	| "Confetti"
	| "Fire"
	| "Smoke"
	| "Ring"
	| "Glow"
	| "Flash"
	| "Vortex"
	| "Bubbles"
	| "Sparks"
	| "Snow"

export type Tint = Color3 | ColorSequence

-- One preset in a burst: `count` particles, after `delay` seconds.
export type Shot = { preset: Preset, count: number, color: Tint?, scale: number?, delay: number? }

local Particles = {}

Particles.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Flash = "rbxasset://textures/particles/explosion01_core_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
	Circle = "rbxasset://textures/whiteCircle.png",
	Star = "rbxasset://textures/sparkle.png",
}

local T = Particles.Textures
local BURST_SECONDS = 4 -- a burst's attachment is cleaned up after this long

type Spec = {
	texture: string,
	size: { number }, -- pairs: time, size
	transparency: { number }?, -- pairs: time, transparency
	lifetime: NumberRange,
	speed: NumberRange,
	spread: Vector2?,
	acceleration: Vector3?,
	drag: number?,
	spin: NumberRange?,
	light: number?,
	brightness: number?,
	squash: { number }?, -- pairs: time, squash (negative: wider than tall)
	orientation: Enum.ParticleOrientation?,
	direction: Enum.NormalId?,
}

local FLAT = Enum.ParticleOrientation.VelocityPerpendicular

local SPECS: { [Preset]: Spec } = {
	Sparkles = {
		texture = T.Sparkle,
		size = { 0, 0.6, 1, 0 },
		transparency = { 0, 0, 0.8, 0.2, 1, 1 },
		lifetime = NumberRange.new(0.6, 1.2),
		speed = NumberRange.new(4, 10),
		spread = Vector2.new(180, 180),
		acceleration = Vector3.new(0, -4, 0),
		drag = 2,
		spin = NumberRange.new(-90, 90),
		light = 1,
		brightness = 2,
	},
	Stars = {
		texture = T.Star,
		size = { 0, 0, 0.2, 0.7, 0.6, 0.5, 1, 0 },
		lifetime = NumberRange.new(0.8, 1.4),
		speed = NumberRange.new(2, 6),
		spread = Vector2.new(180, 180),
		drag = 1,
		spin = NumberRange.new(-120, 120),
		light = 1,
		brightness = 2,
	},
	Coins = { -- gold discs that flip as they fly
		texture = T.Circle,
		size = { 0, 0.4, 1, 0.4 },
		transparency = { 0, 0, 0.85, 0, 1, 1 },
		lifetime = NumberRange.new(1, 1.6),
		speed = NumberRange.new(14, 22),
		spread = Vector2.new(35, 35),
		acceleration = Vector3.new(0, -45, 0),
		drag = 0.5,
		squash = { 0, 0, 0.15, 2, 0.3, 0, 0.45, 2, 0.6, 0, 0.75, 2, 0.9, 0, 1, 2 },
		light = 0.25,
		brightness = 1.5,
		direction = Enum.NormalId.Top,
	},
	Bills = { -- green notes fluttering down
		texture = T.Square,
		size = { 0, 0.5, 1, 0.5 },
		transparency = { 0, 0, 0.85, 0, 1, 1 },
		lifetime = NumberRange.new(1.6, 2.4),
		speed = NumberRange.new(10, 18),
		spread = Vector2.new(50, 50),
		acceleration = Vector3.new(0, -12, 0),
		drag = 2,
		squash = { 0, -0.6, 1, -0.6 },
		spin = NumberRange.new(-260, 260),
		direction = Enum.NormalId.Top,
	},
	Confetti = { -- paper squares tumbling
		texture = T.Square,
		size = { 0, 0.25, 1, 0.25 },
		transparency = { 0, 0, 0.85, 0, 1, 1 },
		lifetime = NumberRange.new(1.5, 2.5),
		speed = NumberRange.new(15, 25),
		spread = Vector2.new(45, 45),
		acceleration = Vector3.new(0, -18, 0),
		drag = 2.5,
		squash = { 0, 0, 0.25, 1.5, 0.5, 0, 0.75, 1.5, 1, 0 },
		spin = NumberRange.new(-360, 360),
		direction = Enum.NormalId.Top,
	},
	Fire = {
		texture = T.Fire,
		size = { 0, 1.2, 1, 0.2 },
		transparency = { 0, 0.3, 1, 1 },
		lifetime = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(2, 5),
		spread = Vector2.new(15, 15),
		acceleration = Vector3.new(0, 8, 0),
		spin = NumberRange.new(-40, 40),
		light = 0.9,
		direction = Enum.NormalId.Top,
	},
	Smoke = {
		texture = T.Smoke,
		size = { 0, 1, 1, 3 },
		transparency = { 0, 0.6, 1, 1 },
		lifetime = NumberRange.new(1, 1.6),
		speed = NumberRange.new(1, 3),
		spread = Vector2.new(30, 30),
		acceleration = Vector3.new(0, 2, 0),
		spin = NumberRange.new(-20, 20),
		direction = Enum.NormalId.Top,
	},
	Ring = { -- a shockwave lying flat on the ground
		texture = T.Ring,
		size = { 0, 0.5, 1, 10 },
		transparency = { 0, 0.1, 1, 1 },
		lifetime = NumberRange.new(0.5, 0.5),
		speed = NumberRange.new(0.01, 0.01),
		orientation = FLAT,
		light = 1,
		direction = Enum.NormalId.Top,
	},
	Glow = {
		texture = T.Glow,
		size = { 0, 2, 0.3, 4, 1, 5 },
		transparency = { 0, 0.3, 1, 1 },
		lifetime = NumberRange.new(0.5, 0.5),
		speed = NumberRange.new(0, 0),
		light = 1,
	},
	Flash = {
		texture = T.Flash,
		size = { 0, 0, 0.2, 5, 1, 7 },
		transparency = { 0, 0, 1, 1 },
		lifetime = NumberRange.new(0.25, 0.25),
		speed = NumberRange.new(0, 0),
		light = 1,
		brightness = 3,
	},
	Vortex = { -- a swirl spinning on the spot
		texture = T.Vortex,
		size = { 0, 3, 1, 4 },
		transparency = { 0, 0.4, 1, 1 },
		lifetime = NumberRange.new(0.8, 0.8),
		speed = NumberRange.new(0, 0),
		spin = NumberRange.new(200, 300),
		light = 1,
	},
	Bubbles = {
		texture = T.Circle,
		size = { 0, 0.2, 1, 0.6 },
		transparency = { 0, 0.5, 1, 1 },
		lifetime = NumberRange.new(1.2, 2),
		speed = NumberRange.new(1, 3),
		spread = Vector2.new(40, 40),
		acceleration = Vector3.new(0, 3, 0),
		light = 0.5,
		direction = Enum.NormalId.Top,
	},
	Sparks = {
		texture = T.Spark,
		size = { 0, 0.4, 1, 0 },
		lifetime = NumberRange.new(0.3, 0.6),
		speed = NumberRange.new(15, 30),
		spread = Vector2.new(180, 180),
		drag = 4,
		light = 1,
		brightness = 2,
		orientation = Enum.ParticleOrientation.VelocityParallel,
	},
	Snow = {
		texture = T.Circle,
		size = { 0, 0.15, 1, 0.15 },
		transparency = { 0, 0, 1, 1 },
		lifetime = NumberRange.new(2, 3),
		speed = NumberRange.new(0.5, 1.5),
		spread = Vector2.new(180, 180),
		acceleration = Vector3.new(0, -1.5, 0),
		light = 0.3,
	},
}

local function sequence(values: { number }, scale: number?): NumberSequence
	local points = {}
	for index = 1, #values, 2 do
		table.insert(points, NumberSequenceKeypoint.new(values[index], values[index + 1] * (scale or 1)))
	end
	return NumberSequence.new(points)
end

local function tint(color: Tint?): ColorSequence
	if typeof(color) == "ColorSequence" then
		return color
	elseif typeof(color) == "Color3" then
		return ColorSequence.new(color)
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

-- A switched-off emitter for a preset (Emit it, or switch it on with a Rate).
function Particles.make(preset: Preset, color: Tint?, scale: number?): ParticleEmitter
	local spec = SPECS[preset]
	local k = scale or 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = preset
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = spec.texture
	emitter.Color = tint(color)
	emitter.Size = sequence(spec.size, k)
	emitter.Transparency = sequence(spec.transparency or { 0, 0, 1, 1 })
	emitter.Lifetime = spec.lifetime
	emitter.Speed = NumberRange.new(spec.speed.Min * k, spec.speed.Max * k)
	emitter.SpreadAngle = spec.spread or Vector2.zero
	emitter.Acceleration = (spec.acceleration or Vector3.zero) * k
	emitter.Drag = spec.drag or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = spec.spin or NumberRange.new(0, 0)
	emitter.LightEmission = spec.light or 0
	emitter.LightInfluence = if spec.light then 0 else 1
	emitter.Brightness = spec.brightness or 1
	emitter.Squash = sequence(spec.squash or { 0, 0, 1, 0 })
	emitter.Orientation = spec.orientation or Enum.ParticleOrientation.FacingCamera
	emitter.EmissionDirection = spec.direction or Enum.NormalId.Top
	return emitter
end

-- A preset left running on `parent` (a part or attachment) at `rate` particles a second.
function Particles.keep(parent: Instance, preset: Preset, rate: number, color: Tint?, scale: number?): ParticleEmitter
	local emitter = Particles.make(preset, color, scale)
	emitter.Rate = rate
	emitter.Enabled = true
	emitter.Parent = parent
	return emitter
end

-- Throws out each shot once from `parent` (a part or attachment); the emitters go afterwards.
function Particles.emit(parent: Instance, shots: { Shot })
	for _, shot in shots do
		local emitter = Particles.make(shot.preset, shot.color, shot.scale)
		emitter.Parent = parent
		local function go()
			if emitter.Parent then
				emitter:Emit(shot.count)
			end
		end
		if shot.delay and shot.delay > 0 then
			task.delay(shot.delay, go)
		else
			go()
		end
		Debris:AddItem(emitter, (shot.delay or 0) + emitter.Lifetime.Max + 0.5)
	end
end

-- Throws out each shot once at a point in the world (`at` facing up, unless it's a CFrame).
function Particles.burst(at: Vector3 | CFrame, shots: { Shot }): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "Burst"
	attachment.Parent = workspace.Terrain
	attachment.WorldCFrame = if typeof(at) == "CFrame" then at else CFrame.new(at)
	Particles.emit(attachment, shots)
	local longest = 0
	for _, shot in shots do
		longest = math.max(longest, shot.delay or 0)
	end
	Debris:AddItem(attachment, BURST_SECONDS + longest)
	return attachment
end

return Particles
