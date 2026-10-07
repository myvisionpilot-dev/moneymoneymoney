--!strict
-- What the Cred shop's trails, auras and bank bursts look like in the world (shared/Particles).
-- CosmeticFx.trail and CosmeticFx.aura dress a character (the server does it, so everyone sees
-- them, in both places): a trail is its ribbon plus sparkle, more of it the rarer it is, plus
-- whatever its own theme throws out (fire, bills, snow...); an aura is its own mix of particles
-- and a light round you. CosmeticFx.burst is a bank burst (the client throws it at the counter).
-- Particles that should only stream out while you move carry the MoveOnly attribute.

local Cosmetics = require(script.Parent.Cosmetics)
local Particles = require(script.Parent.Particles)

type Item = Cosmetics.Item
type Shot = Particles.Shot

local CosmeticFx = {}

local MOVE_ONLY = "MoveOnly"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function colorsOf(item: Item): { Color3 }
	return item.colors or { item.color }
end

local function sequenceOf(item: Item): ColorSequence
	return Cosmetics.sequence(colorsOf(item))
end

local function attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local point = Instance.new("Attachment")
	point.Name = name
	point.Position = position
	point.Parent = parent
	return point
end

local LIGHT_DIM = 0.5 -- cosmetic lights at full strength wash characters out indoors

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local glow = Instance.new("PointLight")
	glow.Name = "CosmeticLight"
	glow.Color = color
	glow.Range = range
	glow.Brightness = brightness * LIGHT_DIM
	glow.Shadows = false
	glow.Parent = parent
	return glow
end

local function ribbon(root: BasePart, top: Attachment, bottom: Attachment, item: Item, glowing: number): Trail
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = sequenceOf(item)
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.Lifetime = 0.5
	trail.MinLength = 0.1
	trail.LightEmission = glowing
	trail.FaceCamera = true
	trail.Parent = root
	return trail
end

-- A streaming emitter: only on while you move (Style switches it).
local function stream(parent: Instance, preset: Particles.Preset, rate: number, color: Particles.Tint, scale: number?)
	local emitter = Particles.keep(parent, preset, rate, color, scale)
	emitter:SetAttribute(MOVE_ONLY, true)
	return emitter
end

-- Each trail's own theme: what it throws out behind you (at your middle or your feet).
type Theme = (middle: Attachment, feet: Attachment, item: Item) -> ()
local TRAIL_THEMES: { [string]: Theme } = {
	TrailFire = function(_middle, feet, _item)
		stream(feet, "Fire", 10, rgb(255, 150, 40), 0.6)
	end,
	TrailIce = function(middle, _feet, _item)
		stream(middle, "Snow", 8, rgb(230, 245, 255))
	end,
	TrailToxic = function(middle, _feet, _item)
		stream(middle, "Bubbles", 6, rgb(150, 240, 60))
	end,
	TrailBubbles = function(middle, _feet, _item)
		stream(middle, "Bubbles", 10, rgb(190, 240, 255), 1.2)
	end,
	TrailShadow = function(middle, _feet, _item)
		local smoke = stream(middle, "Smoke", 10, rgb(40, 30, 60), 0.7)
		smoke.LightInfluence = 0
		smoke.Transparency = NumberSequence.new(0.3, 1)
	end,
	TrailMoney = function(middle, _feet, _item)
		stream(middle, "Bills", 6, rgb(110, 210, 100), 0.6)
		stream(middle, "Coins", 2, rgb(255, 210, 60), 0.6)
	end,
	TrailLightning = function(middle, _feet, _item)
		stream(middle, "Sparks", 16, rgb(140, 220, 255), 0.6)
	end,
	TrailSnow = function(middle, _feet, _item)
		stream(middle, "Snow", 16, rgb(255, 255, 255), 1.2)
	end,
	TrailInferno = function(middle, feet, _item)
		stream(feet, "Fire", 26, ColorSequence.new(rgb(255, 230, 100), rgb(220, 40, 20)), 0.9)
		stream(middle, "Sparks", 6, rgb(255, 160, 40), 0.5)
	end,
	TrailGalaxy = function(middle, _feet, _item)
		stream(middle, "Stars", 12, ColorSequence.new(rgb(255, 150, 255), rgb(120, 90, 255)), 0.8)
		stream(middle, "Sparkles", 6, rgb(110, 170, 255), 0.7)
	end,
	TrailCoins = function(middle, _feet, _item)
		stream(middle, "Coins", 5, rgb(255, 210, 60), 0.6)
		stream(middle, "Sparkles", 8, rgb(255, 225, 120), 0.7)
	end,
	TrailGold = function(middle, _feet, _item)
		stream(middle, "Sparkles", 10, rgb(255, 225, 120), 0.7)
		stream(middle, "Coins", 2, rgb(255, 210, 60), 0.5)
	end,
	TrailRainbow = function(middle, _feet, item)
		stream(middle, "Stars", 10, sequenceOf(item), 0.7)
	end,
}

-- A trail on a character's root: the ribbon from shoulder height to the knees, glowing more and
-- sparkling more the rarer it is, plus its theme. Returns everything it made.
function CosmeticFx.trail(root: BasePart, item: Item): { Instance }
	local made: { Instance } = {}
	local top = attachment(root, "TrailTop", Vector3.new(0, 1, 0.4))
	local bottom = attachment(root, "TrailBottom", Vector3.new(0, -1.6, 0.4))
	local middle = attachment(root, "TrailMiddle", Vector3.new(0, -0.3, 0.6))
	local feet = attachment(root, "TrailFeet", Vector3.new(0, -2.6, 0.4))
	table.insert(made, top)
	table.insert(made, bottom)
	table.insert(made, middle)
	table.insert(made, feet)
	local rare = item.tier ~= "Common"
	local epic = item.tier == "Epic" or item.tier == "Legendary"
	local legendary = item.tier == "Legendary"
	table.insert(made, ribbon(root, top, bottom, item, if legendary then 0.6 elseif epic then 0.4 else 0.1))
	if epic then
		-- A bright core streak down the middle of the ribbon.
		local coreTop = attachment(root, "TrailCoreTop", Vector3.new(0, 0.4, 0.45))
		local coreBottom = attachment(root, "TrailCoreBottom", Vector3.new(0, -1, 0.45))
		table.insert(made, coreTop)
		table.insert(made, coreBottom)
		local core = ribbon(root, coreTop, coreBottom, item, 1)
		core.Color = ColorSequence.new(Color3.new(1, 1, 1), colorsOf(item)[1])
		core.Transparency = NumberSequence.new(0.2, 1)
		core.Lifetime = 0.35
		table.insert(made, core)
	end
	if rare and not TRAIL_THEMES[item.id] then
		stream(middle, "Sparkles", if epic then 8 else 4, sequenceOf(item), 0.6)
	end
	local theme = TRAIL_THEMES[item.id]
	if theme then
		theme(middle, feet, item)
	end
	if legendary then
		stream(middle, "Stars", 4, Color3.new(1, 1, 1), 0.5)
		table.insert(made, light(root, colorsOf(item)[1], 10, 1.2))
	end
	return made
end

-- Each aura: what it throws out round you. `body` is the root (particles fill it), `feet`
-- an attachment under it, `head` one over it.
type Aura = (body: BasePart, feet: Attachment, head: Attachment, item: Item) -> ()

local function flat(emitter: ParticleEmitter)
	emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	emitter.Speed = NumberRange.new(0.01, 0.01)
	emitter.EmissionDirection = Enum.NormalId.Top
end

-- Body particles hang round you in a cloud instead of flying off.
local function around(emitter: ParticleEmitter): ParticleEmitter
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.6, 0)
	emitter.Drag = 1
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	return emitter
end

local AURAS: { [string]: Aura } = {
	AuraSparkle = function(body, _feet, _head, _item)
		around(Particles.keep(body, "Sparkles", 14, ColorSequence.new(rgb(255, 255, 255), rgb(255, 220, 120)), 1))
		around(Particles.keep(body, "Stars", 4, rgb(255, 245, 200), 1))
	end,
	AuraBubbles = function(_body, feet, _head, _item)
		Particles.keep(feet, "Bubbles", 10, rgb(190, 240, 255), 1.6)
	end,
	AuraHearts = function(body, feet, _head, _item)
		around(Particles.keep(body, "Stars", 10, rgb(255, 130, 190), 1.1))
		Particles.keep(feet, "Bubbles", 5, rgb(255, 160, 210), 1.4)
		light(body, rgb(255, 110, 170), 10, 1.2)
	end,
	AuraToxic = function(body, feet, _head, _item)
		Particles.keep(feet, "Bubbles", 12, rgb(150, 240, 60), 1.5)
		local smoke = Particles.keep(feet, "Smoke", 3, rgb(110, 200, 50), 1.1)
		smoke.Transparency = NumberSequence.new(0.6, 1)
		light(body, rgb(140, 240, 60), 11, 1.4)
	end,
	AuraFlame = function(body, feet, _head, _item)
		Particles.keep(feet, "Fire", 30, ColorSequence.new(rgb(255, 230, 100), rgb(230, 50, 20)), 1.1)
		around(Particles.keep(body, "Sparks", 6, rgb(255, 170, 50), 0.6))
		light(body, rgb(255, 130, 40), 14, 2)
	end,
	AuraFrost = function(body, _feet, head, _item)
		local snow = Particles.keep(head, "Snow", 18, rgb(255, 255, 255), 1.8)
		snow.SpreadAngle = Vector2.new(70, 70)
		around(Particles.keep(body, "Sparkles", 8, rgb(190, 230, 255), 0.9))
		light(body, rgb(150, 210, 255), 12, 1.6)
	end,
	AuraMoney = function(body, _feet, head, _item)
		local bills = Particles.keep(head, "Bills", 6, rgb(110, 210, 100), 0.9)
		bills.Speed = NumberRange.new(2, 5)
		bills.SpreadAngle = Vector2.new(80, 80)
		around(Particles.keep(body, "Coins", 2, rgb(255, 210, 60), 0.8))
		light(body, rgb(110, 220, 100), 10, 1.2)
	end,
	AuraStorm = function(body, feet, _head, _item)
		around(Particles.keep(body, "Sparks", 14, rgb(150, 220, 255), 0.8))
		local swirl = Particles.keep(feet, "Vortex", 2, rgb(100, 170, 255), 1.6)
		flat(swirl)
		light(body, rgb(110, 180, 255), 14, 2)
	end,
	AuraGolden = function(body, feet, _head, _item)
		local glow = around(Particles.keep(body, "Glow", 1.5, rgb(255, 210, 80), 1.2))
		glow.Transparency = NumberSequence.new(0.45, 1)
		around(Particles.keep(body, "Sparkles", 16, rgb(255, 225, 120), 1))
		Particles.keep(feet, "Coins", 2.5, rgb(255, 210, 60), 0.8)
		light(body, rgb(255, 205, 80), 14, 2.2)
	end,
	AuraGalaxy = function(body, feet, _head, _item)
		around(Particles.keep(body, "Stars", 14, ColorSequence.new(rgb(255, 160, 255), rgb(130, 90, 255)), 1.1))
		local swirl = Particles.keep(feet, "Vortex", 2, rgb(150, 90, 255), 1.7)
		flat(swirl)
		around(Particles.keep(body, "Sparkles", 8, rgb(110, 170, 255), 0.9))
		light(body, rgb(150, 90, 255), 14, 1.8)
	end,
}
-- An aura on a character (round its root). Returns everything it made that isn't inside the
-- root's own emitters: the attachments; the emitters and lights all carry the CosmeticAura name.
function CosmeticFx.aura(root: BasePart, item: Item): { Instance }
	local made: { Instance } = {}
	local feet = attachment(root, "AuraFeet", Vector3.new(0, -2.8, 0))
	local head = attachment(root, "AuraHead", Vector3.new(0, 3.2, 0))
	table.insert(made, feet)
	table.insert(made, head)
	local before: { [Instance]: boolean } = {}
	for _, child in root:GetChildren() do
		before[child] = true
	end
	local build = AURAS[item.id] or AURAS.AuraSparkle
	build(root, feet, head, item)
	for _, child in root:GetChildren() do
		if not before[child] then
			table.insert(made, child)
		end
	end
	return made
end

-- What each bank burst throws out (around a point at chest height).
type Burst = (at: Vector3, item: Item?) -> ()

local function ring(color: Color3, scale: number?): Shot
	return { preset = "Ring", count = 1, color = color, scale = scale }
end

local BURSTS: { [string]: Burst } = {
	BurstCoins = function(at, _item)
		Particles.burst(at, {
			{ preset = "Coins", count = 40, color = rgb(255, 210, 60), scale = 1.2 },
			{ preset = "Sparkles", count = 20, color = rgb(255, 230, 120) },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(255, 210, 60)) })
	end,
	BurstConfetti = function(at, item)
		local shots: { Shot } = {}
		local colors: { Color3 } = if item then colorsOf(item) else { Color3.new(1, 1, 1) }
		for _, color in colors do
			table.insert(shots, { preset = "Confetti", count = 18, color = color, scale = 1.2 })
		end
		table.insert(shots, { preset = "Sparkles", count = 10, color = Color3.new(1, 1, 1) })
		Particles.burst(at, shots)
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(255, 255, 255)) })
	end,
	BurstBills = function(at, _item)
		Particles.burst(at, {
			{ preset = "Bills", count = 24, color = rgb(110, 210, 100), scale = 1.3 },
			{ preset = "Bills", count = 12, color = rgb(60, 160, 70), scale = 1.3 },
			{ preset = "Coins", count = 10, color = rgb(255, 210, 60) },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(90, 210, 90)) })
	end,
	BurstHearts = function(at, _item)
		Particles.burst(at, {
			{ preset = "Stars", count = 30, color = rgb(255, 120, 180), scale = 1.4 },
			{ preset = "Bubbles", count = 16, color = rgb(255, 160, 210), scale = 1.4 },
			{ preset = "Glow", count = 1, color = rgb(255, 110, 170), scale = 1.2 },
		})
	end,
	BurstFireworks = function(at, item)
		local colors = if item then colorsOf(item) else { Color3.new(1, 1, 1) }
		for index, offset in { Vector3.new(-4, 10, 0), Vector3.new(4, 13, 2), Vector3.new(0, 16, -3) } do
			local color = colors[(index - 1) % #colors + 1]
			Particles.burst(at + offset, {
				{ preset = "Sparks", count = 45, color = color, scale = 1.4, delay = index * 0.35 },
				{ preset = "Flash", count = 1, color = color, scale = 0.8, delay = index * 0.35 },
				{ preset = "Stars", count = 12, color = Color3.new(1, 1, 1), delay = index * 0.35 + 0.1 },
			})
		end
		Particles.burst(at, { { preset = "Sparks", count = 20, color = rgb(255, 230, 150), scale = 0.7 } })
	end,
	BurstStars = function(at, _item)
		Particles.burst(at, {
			{ preset = "Stars", count = 45, color = rgb(255, 240, 160), scale = 1.5 },
			{ preset = "Sparkles", count = 20, color = Color3.new(1, 1, 1) },
		})
	end,
	BurstFrost = function(at, _item)
		Particles.burst(at, {
			{ preset = "Snow", count = 70, color = rgb(255, 255, 255), scale = 2.5 },
			{ preset = "Glow", count = 1, color = rgb(150, 220, 255), scale = 1.4 },
			{ preset = "Sparkles", count = 24, color = rgb(190, 235, 255) },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(150, 220, 255), 1.4) })
	end,
	BurstInferno = function(at, _item)
		Particles.burst(at, {
			{ preset = "Fire", count = 30, color = ColorSequence.new(rgb(255, 230, 90), rgb(200, 30, 20)), scale = 2 },
			{ preset = "Sparks", count = 40, color = rgb(255, 160, 40) },
			{ preset = "Smoke", count = 8, color = rgb(80, 60, 60), scale = 1.5 },
			{ preset = "Flash", count = 1, color = rgb(255, 140, 40) },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(255, 120, 30), 1.3) })
	end,
	BurstGalaxy = function(at, _item)
		Particles.burst(at, {
			{ preset = "Vortex", count = 2, color = rgb(150, 90, 255), scale = 1.5 },
			{
				preset = "Stars",
				count = 50,
				color = ColorSequence.new(rgb(255, 160, 255), rgb(110, 170, 255)),
				scale = 1.4,
			},
			{ preset = "Sparkles", count = 30, color = rgb(140, 120, 255) },
			{ preset = "Glow", count = 1, color = rgb(150, 90, 255), scale = 1.5 },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(160, 100, 255), 1.6) })
	end,
	BurstThunder = function(at, _item)
		Particles.burst(at, {
			{ preset = "Sparks", count = 80, color = rgb(150, 220, 255), scale = 1.5 },
			{ preset = "Flash", count = 1, color = rgb(220, 240, 255), scale = 1.3 },
			{ preset = "Sparkles", count = 30, color = rgb(110, 200, 255) },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(110, 200, 255), 1.6) })
	end,
	BurstStorm = function(at, _item)
		Particles.burst(at, {
			{ preset = "Bills", count = 40, color = rgb(110, 210, 100), scale = 1.5 },
			{ preset = "Coins", count = 40, color = rgb(255, 210, 60), scale = 1.4 },
			{ preset = "Flash", count = 1, color = rgb(255, 220, 90), scale = 1.2 },
			{ preset = "Vortex", count = 1, color = rgb(255, 210, 60), scale = 1.4 },
			{ preset = "Stars", count = 25, color = Color3.new(1, 1, 1), scale = 1.2 },
		})
		Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(255, 210, 60), 1.8) })
	end,
}

-- A deposit at the bank: their bank burst, or a small gold one if they don't wear one.
function CosmeticFx.burst(at: Vector3, item: Item?)
	local build = if item then BURSTS[item.id] else nil
	if build then
		build(at, item)
		return
	end
	Particles.burst(at, {
		{ preset = "Coins", count = 16, color = rgb(255, 210, 60) },
		{ preset = "Sparkles", count = 10, color = rgb(255, 230, 120) },
	})
	Particles.burst(at - Vector3.new(0, 2.6, 0), { ring(rgb(255, 210, 60), 0.7) })
end

CosmeticFx.MoveOnly = MOVE_ONLY

return CosmeticFx
