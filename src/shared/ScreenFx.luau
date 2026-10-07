--!strict
-- Celebrations drawn over the whole screen (client only, both places): a coloured flash, stars
-- bursting from a point, a big banner in the middle (one that comes while another's up crashes
-- in on top with a boom), shockwaves, shrapnel, coins and bills raining down, and a camera shake. The money effects (match client/CashFx) and the lobby shop's purchase reveal
-- are built from these. Sprites are sized for a ~600px-tall screen and scaled to this one.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local BILL_GREEN = Color3.fromRGB(96, 200, 96)
local BILL_DARK = Color3.fromRGB(34, 110, 50)
local COIN_GOLD = Color3.fromRGB(255, 205, 50)
local COIN_DARK = Color3.fromRGB(170, 115, 20)

local ScreenFx = {}

local layer: Frame? = nil
local rng = Random.new()
local shakeUntil = 0
local shakeStuds = 0
local shakeSeconds = 0.4
local shaking: RBXScriptConnection? = nil

-- How big a sprite is on this screen.
function ScreenFx.unit(): number
	local camera = workspace.CurrentCamera
	return math.clamp((if camera then camera.ViewportSize.Y else 600) / 600, 0.7, 1.8)
end

-- The see-through frame over everything that the effects are drawn in.
function ScreenFx.layer(): Frame
	if layer then
		return layer
	end
	local gui = UI.screen("ScreenFx", 55)
	local frame = UI.frame({ Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	layer = frame
	return frame
end

local function screenSize(): Vector2
	return ScreenFx.layer().AbsoluteSize
end

-- A bank note: green, outlined, a lighter band and a "$" in the middle (not parented yet).
function ScreenFx.bill(): Frame
	local size = ScreenFx.unit()
	local note = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(34 * size, 17 * size),
		BackgroundColor3 = BILL_GREEN,
		ZIndex = 5,
	})
	UI.corner(note, 3)
	UI.stroke(note, 1.5 * size, BILL_DARK)
	local band = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.72),
		BackgroundColor3 = Color3.fromRGB(140, 225, 130),
		ZIndex = 6,
	}, note)
	UI.corner(band, 8)
	UI.plain({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = 11 * size,
		TextColor3 = BILL_DARK,
		Text = "$",
		ZIndex = 7,
	}, band)
	return note
end

-- A gold coin with a "$" (not parented yet).
function ScreenFx.coin(): Frame
	local size = ScreenFx.unit()
	local disc = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20 * size, 20 * size),
		BackgroundColor3 = COIN_GOLD,
		ZIndex = 5,
	})
	UI.corner(disc, 20 * size)
	UI.stroke(disc, 1.5 * size, COIN_DARK)
	UI.plain({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = 12 * size,
		TextColor3 = COIN_DARK,
		Text = "$",
		ZIndex = 6,
	}, disc)
	return disc
end

-- The whole screen washes with `color`, fading out.
function ScreenFx.flash(color: Color3, strength: number?)
	local size = screenSize()
	local power = strength or 0.35
	local wash = UI.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - power,
		ZIndex = 1,
	}, ScreenFx.layer())
	local glow = UI.glow(color, {
		Size = UDim2.fromOffset(size.X * 1.3, size.X * 1.3),
		ImageTransparency = 1 - power * 1.6,
		ZIndex = 2,
	}, ScreenFx.layer())
	UI.tween(wash, 0.55, { BackgroundTransparency = 1 })
	UI.tween(glow, 0.7, { ImageTransparency = 1, Size = UDim2.fromOffset(size.X * 1.8, size.X * 1.8) })
	task.delay(0.8, function()
		wash:Destroy()
		glow:Destroy()
	end)
end

-- Shakes the camera for a moment (`studs` at the start, settling to nothing).
function ScreenFx.shake(studs: number, seconds: number?)
	shakeStuds = math.max(studs, if os.clock() < shakeUntil then shakeStuds else 0)
	shakeSeconds = seconds or 0.4
	shakeUntil = os.clock() + shakeSeconds
	if shaking then
		return
	end
	shaking = RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local left = shakeUntil - os.clock()
		if left > 0 then
			local power = shakeStuds * (left / shakeSeconds)
			humanoid.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * power
		elseif humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

-- Little stars bursting out from a point on the screen.
function ScreenFx.stars(at: Vector2, count: number, color: Color3)
	local size = ScreenFx.unit()
	for _ = 1, count do
		local across = rng:NextNumber(26, 54) * size
		local star = Instance.new("ImageLabel")
		star.Name = "Star"
		star.BackgroundTransparency = 1
		star.Image = "rbxasset://textures/glow.png" -- a white starburst: small, it twinkles
		star.ImageColor3 = color
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Size = UDim2.fromOffset(across, across)
		star.Position = UDim2.fromOffset(at.X, at.Y)
		star.ZIndex = 25
		star.Parent = ScreenFx.layer()
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(90, 240) * size
		local seconds = rng:NextNumber(0.5, 0.9)
		UI.tween(star, seconds, {
			Position = UDim2.fromOffset(at.X + math.cos(angle) * reach, at.Y + math.sin(angle) * reach),
			ImageTransparency = 1,
			Rotation = rng:NextNumber(-180, 180),
			Size = UDim2.fromOffset(across * 0.4, across * 0.4),
		})
		task.delay(seconds, function()
			star:Destroy()
		end)
	end
end

-- A ring blasting outwards from a point on the screen.
function ScreenFx.shockwave(at: Vector2, color: Color3)
	local size = ScreenFx.unit()
	for index = 0, 1 do
		local ring = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(30 * size, 30 * size),
			BackgroundTransparency = 1,
			ZIndex = 19,
		}, ScreenFx.layer())
		UI.corner(ring, 2000)
		local edge = UI.stroke(ring, (10 - index * 4) * size, if index == 0 then color else Color3.new(1, 1, 1))
		local reach = (900 - index * 250) * size
		task.delay(index * 0.07, function()
			UI.tween(ring, 0.55, { Size = UDim2.fromOffset(reach, reach) })
			UI.tween(edge, 0.55, { Transparency = 1, Thickness = 1 })
		end)
		task.delay(0.7, function()
			ring:Destroy()
		end)
	end
end

-- Chunks of colour flying out from a point (the shrapnel of a crash).
function ScreenFx.debris(at: Vector2, count: number, colors: { Color3 })
	local size = ScreenFx.unit()
	for index = 1, count do
		local across = rng:NextNumber(8, 18) * size
		local chunk = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(across, across * rng:NextNumber(0.5, 1)),
			BackgroundColor3 = colors[(index - 1) % #colors + 1],
			Rotation = rng:NextNumber(0, 360),
			ZIndex = 24,
		}, ScreenFx.layer())
		UI.corner(chunk, 3)
		UI.stroke(chunk, 1.5)
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = rng:NextNumber(220, 560) * size
		local seconds = rng:NextNumber(0.6, 1)
		TweenService:Create(chunk, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(at.X + math.cos(angle) * reach, at.Y + math.sin(angle) * reach + 80 * size),
			Rotation = chunk.Rotation + rng:NextNumber(-540, 540),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(seconds, function()
			chunk:Destroy()
		end)
	end
end

-- Big centre-screen banners. One that comes while another's still up waits until CRASH_GAP
-- after it (so they come in the order they happened) and then CRASHES in on top: it slams down
-- from huge, knocks the old one flying, and the screen booms, flashes and shakes with a
-- shockwave, shrapnel and a storm of stars.
local CRASH_GAP = 0.75
type Shown = { holder: Frame, scale: UIScale, endsAt: number, knocked: boolean }
local onScreen: Shown? = nil
local nextStart = 0

local function fade(shown: Shown, rise: number, seconds: number)
	local holder = shown.holder
	UI.tween(holder, seconds, { Position = UDim2.fromScale(0.5, holder.Position.Y.Scale - rise) })
	for _, child in holder:GetDescendants() do
		if child:IsA("TextLabel") then
			UI.tween(child, seconds, { TextTransparency = 1 })
		elseif child:IsA("ImageLabel") then
			UI.tween(child, seconds, { ImageTransparency = 1 })
		elseif child:IsA("UIStroke") then
			UI.tween(child, seconds, { Transparency = 1 })
		end
	end
	task.delay(seconds + 0.05, function()
		holder:Destroy()
	end)
end

-- The old banner gets smashed out of the way: it spins, shrinks and drops.
local function knockAway(shown: Shown)
	shown.knocked = true
	local spin = if rng:NextNumber() < 0.5 then -1 else 1
	UI.tween(shown.scale, 0.3, { Scale = 0.55 })
	UI.tween(shown.holder, 0.3, { Rotation = 14 * spin })
	fade(shown, -0.12, 0.3)
end

local function build(text: string, color: Color3, subtitle: string?, seconds: number, y: number, crash: boolean)
	local size = ScreenFx.unit()
	local middle = screenSize() * Vector2.new(0.5, y)
	local holder = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromOffset(560 * size, 120 * size),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, ScreenFx.layer())
	local glow = UI.glow(color, {
		Size = UDim2.fromOffset(380 * size, 380 * size),
		ImageTransparency = 0.35,
		ZIndex = 20,
	}, holder)
	local title = UI.label({
		Size = UDim2.new(1, 0, 0, 70 * size),
		FontFace = UI.Fonts.Title,
		TextSize = (if crash then 72 else 64) * size,
		TextColor3 = color,
		Text = text,
		ZIndex = 22,
	}, holder)
	UI.textStroke(title, 4 * size)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 220)),
		ColorSequenceKeypoint.new(1, Color3.new(0.75, 0.75, 0.75)),
	})
	shine.Rotation = 90
	shine.Parent = title
	if subtitle then
		local line = UI.label({
			Position = UDim2.fromOffset(0, 70 * size),
			Size = UDim2.new(1, 0, 0, 30 * size),
			FontFace = UI.Fonts.Heading,
			TextSize = 24 * size,
			Text = subtitle,
			ZIndex = 22,
		}, holder)
		UI.textStroke(line, 2.5 * size)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
	if crash then
		-- Slams down from huge, then the impact.
		scale.Scale = 3
		holder.Rotation = rng:NextNumber(-8, 8)
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 })
			:Play()
		TweenService
			:Create(holder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = 0 })
			:Play()
		task.delay(0.16, function()
			Sounds.play("Boom")
			ScreenFx.shake(1.1, 0.6)
			ScreenFx.flash(Color3.new(1, 1, 1), 0.5)
			ScreenFx.flash(color, 0.3)
			ScreenFx.shockwave(middle, color)
			ScreenFx.debris(middle, 30, { color, UI.Colors.Gold, Color3.new(1, 1, 1) })
			ScreenFx.stars(middle, 40, color)
			ScreenFx.stars(middle, 20, Color3.new(1, 1, 1))
			scale.Scale = 1.12
			TweenService
				:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end)
	else
		ScreenFx.stars(middle, 18, color)
		ScreenFx.stars(middle, 8, Color3.new(1, 1, 1))
		scale.Scale = 0.2
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		Sounds.play("Whoosh", 1.1, 0.8)
	end
	local shown: Shown = { holder = holder, scale = scale, endsAt = os.clock() + seconds, knocked = false }
	task.delay(seconds, function()
		if not shown.knocked then
			fade(shown, 0.08, 0.5)
		end
	end)
	return shown
end

-- Big centre-screen text that pops in over a glow with stars bursting out, then floats up and
-- fades; if another is still up it crashes in on top (see above). `height` is how far down the
-- screen it sits (0.36 by default).
function ScreenFx.banner(text: string, color: Color3, subtitle: string?, seconds: number?, height: number?)
	local now = os.clock()
	local startAt = math.max(now, nextStart)
	nextStart = startAt + CRASH_GAP
	local function go()
		local before = onScreen
		local crash = before ~= nil
			and not before.knocked
			and before.holder.Parent ~= nil
			and os.clock() < before.endsAt
		if crash and before then
			knockAway(before)
		end
		onScreen = build(text, color, subtitle, seconds or 1.6, height or 0.36, crash)
	end
	if startAt > now then
		task.delay(startAt - now, go)
	else
		go()
	end
end
-- Coins (and a few bills) pouring down the whole screen.
function ScreenFx.rain(count: number)
	local size = screenSize()
	for index = 1, count do
		local piece = if index % 3 == 0 then ScreenFx.bill() else ScreenFx.coin()
		local x = rng:NextNumber(0.05, 0.95) * size.X
		piece.Position = UDim2.fromOffset(x, -30)
		piece.Rotation = rng:NextNumber(0, 360)
		piece.Parent = ScreenFx.layer()
		local seconds = rng:NextNumber(1, 1.7)
		task.delay(index * 0.02, function()
			UI.tween(piece, seconds, {
				Position = UDim2.fromOffset(x + rng:NextNumber(-60, 60), size.Y + 40),
				Rotation = piece.Rotation + rng:NextNumber(-400, 400),
			})
		end)
		task.delay(index * 0.02 + seconds, function()
			piece:Destroy()
		end)
	end
end

return ScreenFx
