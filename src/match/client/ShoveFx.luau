--!strict
-- What a shove looks like (JobFx "Shove" and "KnockOut", from server/Shove), bigger the
-- stronger the shover (their Strength tier, `power`):
--   1 SHOVE!    a gust from the shover's hands, a ring of air and stars
--   2 STRONG!   + dust kicked up off the ground, orange sparks, a harder thump
--   3 MIGHTY!   + a shockwave racing across the ground, crackling bolts, a white flash
--   4 TITAN!    + a second shockwave, chunks of studded ground flying, a boom
-- The shover's own screen also shakes (and flashes, from MIGHTY up). A knock-out adds a K.O.!

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Particles = require(Shared:WaitForChild("Particles"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Studs = require(Shared:WaitForChild("Studs"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local TIER_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 160, 40),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(255, 70, 200),
}
local WORD_COLORS = {
	UI.Colors.Gold,
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(90, 210, 255),
	Color3.fromRGB(255, 80, 210),
}

local ShoveFx = {}

local rng = Random.new()

local function effectPart(name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace
	return part
end

-- A word popping up over the hit, then floating off.
local function word(at: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Part")
	anchor.Name = "ShoveWord"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 2.5, 0))
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(60 * size, 22 * size)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Adornee = anchor
	board.Parent = anchor
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextScaled = true,
		FontFace = UI.Fonts.Title,
		TextColor3 = color,
		Rotation = rng:NextNumber(-10, 10),
	}, board)
	UI.textStroke(label, 3)
	UI.pop(label, 0.8)
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + Vector3.new(0, 3, 0),
	}):Play()
	task.delay(0.7, function()
		UI.tween(label, 0.4, { TextTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1.2)
end

-- Streaks of air from the shover's hands to the one they hit.
local function gust(from: Vector3, to: Vector3, color: Color3, count: number)
	local look = CFrame.lookAt(from + Vector3.new(0, 1.5, 0), to)
	local length = (to - from).Magnitude
	for index = 1, count do
		local side = look.RightVector * rng:NextNumber(-1, 1) + look.UpVector * rng:NextNumber(-0.8, 0.8)
		local start = look.Position + side * 0.8
		local streak =
			effectPart("Gust", Vector3.new(0.12, 0.12, 2.5), CFrame.lookAt(start, start + look.LookVector), color, 0.2)
		task.delay(index * 0.02, function()
			TweenService:Create(streak, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(start + look.LookVector * length, start + look.LookVector * (length + 1)),
				Size = Vector3.new(0.05, 0.05, 5),
				Transparency = 1,
			}):Play()
		end)
		Debris:AddItem(streak, 0.5)
	end
end

-- A ring of light racing out across the ground: short glowing bars round a circle, flying
-- outward and fading.
local function shockwave(at: Vector3, color: Color3, reach: number, delay: number)
	task.delay(delay, function()
		local ground = at - Vector3.new(0, 2.8, 0)
		local count = 28
		local tween = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		for index = 1, count do
			local angle = index / count * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local bar = effectPart(
				"Shockwave",
				Vector3.new(0.9, 0.25, 0.35),
				CFrame.lookAt(ground + out, ground + out * 2) * CFrame.Angles(0, math.rad(90), 0),
				color,
				0.1
			)
			local finish = ground + out * reach / 2
			TweenService:Create(bar, tween, {
				CFrame = CFrame.lookAt(finish, finish + out) * CFrame.Angles(0, math.rad(90), 0),
				Size = Vector3.new(reach * math.pi / count * 1.1, 0.12, 0.2),
				Transparency = 1,
			}):Play()
			Debris:AddItem(bar, 0.65)
		end
	end)
end

-- Jagged bolts crackling out from the hit.
local function bolts(at: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1)).Unit
		local last = at
		for step = 1, 4 do
			local point = at
				+ direction * step * 1.4
				+ Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6))
			local length = (point - last).Magnitude
			local bit = effectPart(
				"Bolt",
				Vector3.new(0.14, 0.14, length),
				CFrame.lookAt((last + point) / 2, point),
				Color3.new(1, 1, 1):Lerp(color, 0.5),
				0
			)
			TweenService:Create(bit, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			Debris:AddItem(bit, 0.3)
			last = point
		end
	end
end

-- Chunks of studded ground flying up and tumbling down.
local function chunks(at: Vector3, count: number)
	local ground = at - Vector3.new(0, 3, 0)
	for _ = 1, count do
		local size = rng:NextNumber(0.6, 1.3)
		local chunk = Instance.new("Part")
		chunk.Name = "Chunk"
		chunk.Size = Vector3.one * size
		chunk.Color = Color3.fromRGB(96, 200, 36):Lerp(Color3.fromRGB(140, 110, 70), rng:NextNumber())
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-2, 2), 0.5, rng:NextNumber(-2, 2)))
		Studs.dress(chunk)
		chunk.Parent = workspace
		chunk.AssemblyLinearVelocity =
			Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(28, 45), rng:NextNumber(-18, 18))
		chunk.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		Debris:AddItem(chunk, 2.5)
	end
end

function ShoveFx.play(event: Types.JobFx)
	local at = event.at
	local power = math.clamp(event.power or 1, 1, 4)
	local from = event.from or at
	local color = TIER_COLORS[power]
	local mine = event.by == Players.LocalPlayer.UserId
	local knockOut = event.kind == "KnockOut"
	local tiers = Config.Shove.Tiers

	gust(from, at, color, 3 + power * 2)
	Particles.burst(at, {
		{ preset = "Stars", count = 8 + power * 4, color = Color3.fromRGB(255, 225, 90), scale = 0.8 + power * 0.2 },
		{ preset = "Ring", count = 1, color = color, scale = 0.4 + power * 0.25 },
	})
	if power >= 2 then
		Particles.burst(at - Vector3.new(0, 2.5, 0), {
			{
				preset = "Smoke",
				count = 6 + power * 2,
				color = Color3.fromRGB(225, 210, 180),
				scale = 0.8 + power * 0.2,
			},
			{ preset = "Sparks", count = 10 + power * 4, color = color },
		})
	end
	if power >= 3 then
		shockwave(at, color, 18 + power * 6, 0)
		bolts(at, color, 3 + power)
		Particles.burst(at, { { preset = "Flash", count = 1, color = Color3.new(1, 1, 1), scale = 0.6 } })
	end
	if power >= 4 then
		shockwave(at, Color3.new(1, 1, 1), 40, 0.12)
		chunks(at, 10)
		Particles.burst(at, { { preset = "Confetti", count = 30, color = color, scale = 1.2 } })
		Sounds.at("Boom", workspace.Terrain)
	end
	local tier = tiers[power]
	word(
		at,
		if knockOut then "K.O.!" else tier.name,
		if knockOut then UI.Colors.Money else WORD_COLORS[power],
		2.2 + power * 0.5
	)
	if knockOut then
		Particles.burst(at, {
			{ preset = "Stars", count = 22, color = Color3.fromRGB(255, 225, 90), scale = 1.3 },
			{ preset = "Ring", count = 1, color = UI.Colors.Gold, scale = 0.9 },
		})
	end
	if mine then
		ScreenFx.shake(0.25 + power * 0.18, 0.2 + power * 0.06)
		if power >= 3 then
			ScreenFx.flash(color, 0.15 + power * 0.05)
		end
		if power >= 4 then
			ScreenFx.boom()
		end
	end
end

return ShoveFx
