--!strict
-- The Shop's effects (client, both places), added card by card by StoreWindow:
--   rain     money falling onto one continuous pile of bundles along the bottom of a big Cred pack
--   twinkle  stars that pop up, spin and fade at random spots on a card
--   rainbow  the Rainbow Pack's colours flowing across it, with a rainbow edge running round
--   gold     a gold glint running round a card's edge and a glow behind its picture that breathes
--   burst    sparkles shooting out of a card's picture now and then
--   float    a picture bobbing gently up and down
--   wiggle   a gift button giving a little shake every few seconds
--   pulse    the BEST VALUE ribbon throbbing
--   lift     a card growing a little, outlined in white, while you point at it
--   popIn    cards springing in one after another when the Shop opens
--   shimmer  a bright band sweeping across a title
--   motes    specks of light drifting up behind the cards
-- One RenderStepped loop drives them all, only while the Shop is open, and skips cards scrolled
-- out of sight. Anything whose card is gone (the Shop rebuilds its cards) drops out by itself.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StoreKit = require(script.Parent.StoreKit)
local UI = require(script.Parent.UI)

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 212, 60)
local BILL = Vector2.new(30, 15)
local POP = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12)

export type Tint = "white" | "gold" | "rainbow" | "fire"

export type Fx = {
	rain: (card: Frame, floor: number, wide: boolean) -> (),
	twinkle: (card: Frame, count: number, tint: Tint) -> (),
	rainbow: (card: Frame) -> (),
	gold: (card: Frame) -> (),
	burst: (card: Frame, at: Vector2, tint: Tint) -> (),
	float: (picture: GuiObject) -> (),
	wiggle: (button: GuiObject) -> (),
	pulse: (ribbon: GuiObject) -> (),
	lift: (card: Frame) -> (),
	popIn: (card: Frame, order: number) -> (),
	shimmer: (label: TextLabel) -> (),
	motes: (area: Frame, count: number) -> (),
	embers: (card: Frame, count: number) -> (),
	punch: (picture: GuiObject, color: Color3) -> (),
}

type Bill = {
	image: ImageLabel,
	live: boolean,
	x: number, -- across the card (0..1)
	y: number,
	speed: number,
	spin: number,
	phase: number,
}
type Rain = { card: Frame, bills: { Bill }, land: number, nextAt: number, gap: number }
type Twinkle = { card: Frame, image: ImageLabel, tint: Tint, startAt: number, life: number, size: number }
type Spark = { image: ImageLabel, x: number, y: number, vx: number, vy: number, age: number }
type Burst = { card: Frame, at: Vector2, tint: Tint, sparks: { Spark }, nextAt: number }
type Edge = { card: Frame, gradient: UIGradient, speed: number }
type Flow = { card: Frame, shade: UIGradient }
type Breathe = { card: Frame, glow: ImageLabel, base: number }
type Float = { picture: GuiObject, base: UDim2, phase: number }
type Wiggle = { button: GuiObject, phase: number, period: number }
type Pulse = { ribbon: GuiObject, scale: UIScale, rotation: number }
type Shimmer = { label: TextLabel, gradient: UIGradient, phase: number }
type Mote = { image: ImageLabel, x: number, y: number, speed: number, phase: number }
type Ember = { card: Frame, image: ImageLabel, x: number, y: number, speed: number, phase: number, size: number }
type Punch = { picture: GuiObject, scale: UIScale, ring: Frame, edge: UIStroke, nextAt: number, startedAt: number }

local StoreFx = {}

local function alive(instance: Instance): boolean
	return instance.Parent ~= nil
end

local function sparkleImage(size: number, z: number, parent: Instance): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Sparkle"
	image.BackgroundTransparency = 1
	image.Image = StoreKit.Images.Sparkle
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromOffset(size, size)
	image.ImageTransparency = 1
	image.ZIndex = z
	image.Active = false
	image.Parent = parent
	return image
end

local function tintColor(tint: Tint): Color3
	if tint == "gold" then
		return GOLD:Lerp(WHITE, math.random() * 0.4)
	elseif tint == "rainbow" then
		return Color3.fromHSV(math.random(), 0.75, 1)
	elseif tint == "fire" then
		return Color3.fromRGB(255, 90, 20):Lerp(Color3.fromRGB(255, 230, 90), math.random())
	end
	return WHITE
end

-- One UIScale per card, shared by the pop-in and the hover lift.
local function scaleOf(card: GuiObject): UIScale
	local existing = card:FindFirstChild("FxScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "FxScale"
	scale.Parent = card
	return scale
end

-- A coloured line just inside a card's black outline, its colours running round it.
local function edgeLine(card: Frame, colors: ColorSequence, thickness: number): UIGradient
	local rim = UI.frame({
		Name = "FxEdge",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Active = false,
	}, card)
	UI.corner(rim, 6)
	local stroke = UI.stroke(rim, thickness, WHITE)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colors
	gradient.Parent = stroke
	return gradient
end

-- A rainbow with `count` stops, `shift` round the colour wheel.
local function rainbowColors(shift: number, count: number, saturation: number): ColorSequence
	local keys = {}
	for index = 0, count - 1 do
		local t = index / (count - 1)
		table.insert(keys, ColorSequenceKeypoint.new(t, Color3.fromHSV((t + shift) % 1, saturation, 1)))
	end
	return ColorSequence.new(keys)
end

-- `panel` is the Shop window (nothing runs while it's shut), `view` the list the cards scroll in.
function StoreFx.new(panel: GuiObject, view: GuiObject): Fx
	local rains: { Rain } = {}
	local twinkles: { Twinkle } = {}
	local bursts: { Burst } = {}
	local edges: { Edge } = {}
	local flows: { Flow } = {}
	local breathes: { Breathe } = {}
	local floats: { Float } = {}
	local wiggles: { Wiggle } = {}
	local pulses: { Pulse } = {}
	local shimmers: { Shimmer } = {}
	local motes: { Mote } = {}
	local embers: { Ember } = {}
	local punches: { Punch } = {}

	-- Is this card (at least partly) in the visible part of the list?
	local function onScreen(card: GuiObject): boolean
		local top, bottom = view.AbsolutePosition.Y, view.AbsolutePosition.Y + view.AbsoluteSize.Y
		local y = card.AbsolutePosition.Y
		return y + card.AbsoluteSize.Y > top and y < bottom
	end

	-- Drops the entries whose instance is gone.
	local function prune<T>(list: { T }, key: (T) -> Instance)
		for index = #list, 1, -1 do
			if not alive(key(list[index])) then
				table.remove(list, index)
			end
		end
	end

	local fx = {}

	function fx.rain(card: Frame, floor: number, wide: boolean)
		local group = Instance.new("CanvasGroup")
		group.Name = "MoneyRain"
		group.Size = UDim2.fromScale(1, 1)
		group.BackgroundTransparency = 1
		group.ZIndex = 2
		group.Parent = card
		UI.corner(group, 8)

		-- One continuous pile of bundles right along the bottom: a front row sitting on the floor, a
		-- second row a little higher and darker behind it, and a few on top, each bundle its own
		-- picture, turned this way and that. The same card always gets the same pile.
		local pile = UI.frame({
			Name = "Pile",
			Position = UDim2.fromOffset(0, floor + 10),
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, group)
		local width = if wide then 96 else 78
		local height = width / StoreKit.BUNDLE_RATIO
		local random = Random.new(if wide then 7 else math.floor(floor))
		local pictures = { StoreKit.Images.Bundle, StoreKit.Images.BundleBack, StoreKit.Images.BundleUp }
		local function lay(count: number, raise: number, shade: number, z: number, scatter: boolean)
			for index = 1, count do
				local image = Instance.new("ImageLabel")
				image.Name = "Bundle"
				image.BackgroundTransparency = 1
				image.Image = pictures[random:NextInteger(1, #pictures)]
				image.ScaleType = Enum.ScaleType.Fit
				image.AnchorPoint = Vector2.new(0.5, 1)
				local x = if scatter then random:NextNumber(0.08, 0.92) else (index - 0.5) / count
				image.Position =
					UDim2.new(x + random:NextNumber(-0.015, 0.015), 0, 0, -raise + random:NextNumber(-4, 4))
				local size = width * random:NextNumber(0.9, 1.1)
				image.Size = UDim2.fromOffset(size, size / StoreKit.BUNDLE_RATIO)
				image.Rotation = random:NextNumber(-14, 14)
				image.ImageColor3 = Color3.new(shade, shade, shade)
				image.ZIndex = z
				image.Parent = pile
			end
		end
		local front = if wide then 12 else 6
		lay(if wide then 5 else 3, height * 0.85, 0.74, 1, true)
		lay(front + 1, height * 0.45, 0.86, 2, false)
		lay(front, 0, 1, 3, false)

		local entry: Rain = {
			card = card,
			bills = {},
			land = floor + 10 - height * 1.25,
			nextAt = 0,
			gap = if wide then 0.065 else 0.1, -- seconds between bills (plus up to as much again)
		}
		for _ = 1, if wide then 30 else 16 do
			local image = Instance.new("ImageLabel")
			image.Name = "Bill"
			image.BackgroundTransparency = 1
			image.Image = StoreKit.Images.Bill
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Size = UDim2.fromOffset(BILL.X, BILL.Y)
			image.Visible = false
			image.ZIndex = 2
			image.Parent = group
			table.insert(entry.bills, { image = image, live = false, x = 0, y = 0, speed = 0, spin = 0, phase = 0 })
		end
		-- Start with some already falling, so it never looks like it's just begun.
		for index, bill in entry.bills do
			if index % 2 == 0 then
				bill.live = true
				bill.x = 0.03 + math.random() * 0.94
				bill.y = math.random() * entry.land
				bill.speed = 80 + math.random() * 45
				bill.spin = (math.random() - 0.5) * 420
				bill.phase = math.random() * 6
				bill.image.Rotation = math.random(0, 359)
				bill.image.Visible = true
			end
		end
		table.insert(rains, entry)
	end
	function fx.twinkle(card: Frame, count: number, tint: Tint)
		local layer = UI.frame({
			Name = "Twinkles",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Active = false,
		}, card)
		for _ = 1, count do
			table.insert(twinkles, {
				card = card,
				image = sparkleImage(0, 5, layer),
				tint = tint,
				startAt = os.clock() + math.random() * 1.6,
				life = 0.7 + math.random() * 0.5,
				size = 14 + math.random() * 12,
			})
		end
	end

	function fx.rainbow(card: Frame)
		local shade = card:FindFirstChild("Shade")
		if shade and shade:IsA("UIGradient") then
			table.insert(flows, { card = card, shade = shade })
		end
		table.insert(edges, { card = card, gradient = edgeLine(card, rainbowColors(0, 8, 0.9), 3), speed = 140 })
	end

	function fx.gold(card: Frame)
		local glint = ColorSequence.new({
			ColorSequenceKeypoint.new(0, GOLD),
			ColorSequenceKeypoint.new(0.4, GOLD),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.6, GOLD),
			ColorSequenceKeypoint.new(1, GOLD),
		})
		table.insert(edges, { card = card, gradient = edgeLine(card, glint, 3), speed = 110 })
		local glow = card:FindFirstChild("Glow")
		if glow and glow:IsA("ImageLabel") then
			table.insert(breathes, { card = card, glow = glow, base = glow.ImageTransparency })
		end
	end

	function fx.burst(card: Frame, at: Vector2, tint: Tint)
		local layer = UI.frame({
			Name = "Burst",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Active = false,
		}, card)
		local sparks = {}
		for _ = 1, 9 do
			table.insert(sparks, { image = sparkleImage(0, 5, layer), x = 0, y = 0, vx = 0, vy = 0, age = 99 })
		end
		table.insert(
			bursts,
			{ card = card, at = at, tint = tint, sparks = sparks, nextAt = os.clock() + math.random() * 2 }
		)
	end

	function fx.float(picture: GuiObject)
		table.insert(floats, { picture = picture, base = picture.Position, phase = math.random() * 6 })
	end

	function fx.wiggle(button: GuiObject)
		table.insert(wiggles, { button = button, phase = math.random() * 4, period = 3.5 + math.random() * 1.5 })
	end

	function fx.pulse(ribbon: GuiObject)
		table.insert(pulses, { ribbon = ribbon, scale = scaleOf(ribbon), rotation = ribbon.Rotation })
	end

	function fx.lift(card: Frame)
		local scale = scaleOf(card)
		local border = card:FindFirstChild("Border")
		local color = if border and border:IsA("UIStroke") then border.Color else UI.Colors.Ink
		card.MouseEnter:Connect(function()
			TweenService:Create(scale, HOVER, { Scale = 1.035 }):Play()
			if border and border:IsA("UIStroke") then
				TweenService:Create(border, HOVER, { Color = WHITE, Thickness = 4.5 }):Play()
			end
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
			if border and border:IsA("UIStroke") then
				TweenService:Create(border, HOVER, { Color = color, Thickness = 3.5 }):Play()
			end
		end)
	end

	function fx.popIn(card: Frame, order: number)
		local scale = scaleOf(card)
		scale.Scale = 0.55
		task.delay(order * 0.045, function()
			if alive(card) then
				TweenService:Create(scale, POP, { Scale = 1 }):Play()
			end
		end)
	end

	function fx.shimmer(label: TextLabel)
		local color = label.TextColor3
		local bright = if color == WHITE then Color3.fromRGB(255, 236, 140) else WHITE
		label.TextColor3 = WHITE -- the gradient does the colouring (it can only darken)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.4, color),
			ColorSequenceKeypoint.new(0.5, bright),
			ColorSequenceKeypoint.new(0.6, color),
			ColorSequenceKeypoint.new(1, color),
		})
		gradient.Offset = Vector2.new(1, 0)
		gradient.Parent = label
		table.insert(shimmers, { label = label, gradient = gradient, phase = math.random() * 3 })
	end

	function fx.motes(area: Frame, count: number)
		for _ = 1, count do
			local image = sparkleImage(4 + math.random() * 6, 1, area)
			image.ImageTransparency = 0.5
			table.insert(motes, {
				image = image,
				x = math.random(),
				y = math.random(),
				speed = 0.04 + math.random() * 0.06,
				phase = math.random() * 6,
			})
		end
	end

	-- Fire sparks rising from the bottom of a card, swaying as they go.
	function fx.embers(card: Frame, count: number)
		local layer = UI.frame({
			Name = "Embers",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
			Active = false,
		}, card)
		for _ = 1, count do
			local image = sparkleImage(0, 2, layer)
			table.insert(embers, {
				card = card,
				image = image,
				x = math.random(),
				y = math.random(),
				speed = 0.25 + math.random() * 0.35,
				phase = math.random() * 6,
				size = 8 + math.random() * 10,
			})
		end
	end

	-- Every few seconds the picture throws a punch: it lunges big and a shockwave ring blasts out.
	function fx.punch(picture: GuiObject, color: Color3)
		local ring = UI.frame({
			Name = "PunchRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Active = false,
		}, picture)
		UI.corner(ring, 999)
		local edge = UI.stroke(ring, 6, color)
		edge.Transparency = 1
		table.insert(punches, {
			picture = picture,
			scale = scaleOf(picture),
			ring = ring,
			edge = edge,
			nextAt = os.clock() + 1 + math.random() * 2.5,
			startedAt = -99,
		})
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if not panel.Visible then
			return
		end
		local now = os.clock()

		prune(rains, function(entry: Rain): Instance
			return entry.card
		end)
		for _, entry in rains do
			if not onScreen(entry.card) then
				continue
			end
			if now >= entry.nextAt then
				entry.nextAt = now + entry.gap * (1 + math.random())
				for _, bill in entry.bills do
					if not bill.live then
						bill.live = true
						bill.x = 0.03 + math.random() * 0.94
						bill.y = -12
						bill.speed = 80 + math.random() * 45
						bill.spin = (math.random() - 0.5) * 420
						bill.phase = math.random() * 6
						local size = 0.8 + math.random() * 0.45
						bill.image.Size = UDim2.fromOffset(BILL.X * size, BILL.Y * size)
						bill.image.Rotation = math.random(0, 359)
						bill.image.Visible = true
						break
					end
				end
			end
			for _, bill in entry.bills do
				if bill.live then
					bill.y += bill.speed * dt
					local image = bill.image
					image.Position = UDim2.new(bill.x, math.sin(now * 3 + bill.phase) * 6, 0, bill.y)
					image.Rotation += bill.spin * dt
					local left = entry.land - bill.y
					image.ImageTransparency = if left < 16 then 1 - math.max(left, 0) / 16 else 0
					if bill.y >= entry.land then
						bill.live = false
						image.Visible = false
					end
				end
			end
		end

		prune(twinkles, function(entry: Twinkle): Instance
			return entry.image
		end)
		for _, entry in twinkles do
			local p = (now - entry.startAt) / entry.life
			local image = entry.image
			if p >= 1 then
				entry.startAt = now + math.random() * 1.4
				entry.life = 0.7 + math.random() * 0.5
				entry.size = 14 + math.random() * 12
				image.Position = UDim2.fromScale(0.05 + math.random() * 0.9, 0.06 + math.random() * 0.62)
				image.ImageColor3 = tintColor(entry.tint)
				image.ImageTransparency = 1
			elseif p >= 0 and onScreen(entry.card) then
				local s = math.sin(p * math.pi)
				image.Size = UDim2.fromOffset(entry.size * s, entry.size * s)
				image.Rotation = p * 140
				image.ImageTransparency = 1 - s
			end
		end

		prune(bursts, function(entry: Burst): Instance
			return entry.card
		end)
		for _, entry in bursts do
			if now >= entry.nextAt and onScreen(entry.card) then
				entry.nextAt = now + 2.4 + math.random()
				local size = entry.card.AbsoluteSize
				local aspect = if size.Y > 0 then size.X / size.Y else 1
				for index, spark in entry.sparks do
					local angle = (index / #entry.sparks) * math.pi * 2 + math.random() * 0.4
					local speed = 0.28 + math.random() * 0.22
					spark.x, spark.y = entry.at.X, entry.at.Y
					spark.vx = math.cos(angle) * speed
					spark.vy = math.sin(angle) * speed * aspect - 0.25
					spark.age = 0
					spark.image.ImageColor3 = tintColor(entry.tint)
				end
			end
			for _, spark in entry.sparks do
				if spark.age < 0.75 then
					spark.age += dt
					spark.x += spark.vx * dt
					spark.y += spark.vy * dt
					spark.vy += 0.9 * dt
					local fade = spark.age / 0.75
					local size = 18 * (1 - fade * 0.6)
					spark.image.Position = UDim2.fromScale(spark.x, spark.y)
					spark.image.Size = UDim2.fromOffset(size, size)
					spark.image.Rotation = spark.age * 300
					spark.image.ImageTransparency = fade
				else
					spark.image.ImageTransparency = 1
				end
			end
		end

		prune(edges, function(entry: Edge): Instance
			return entry.card
		end)
		for _, entry in edges do
			entry.gradient.Rotation = (now * entry.speed) % 360
		end
		prune(flows, function(entry: Flow): Instance
			return entry.card
		end)
		for _, entry in flows do
			if onScreen(entry.card) then
				entry.shade.Color = rainbowColors(now * 0.12, 9, 0.85)
			end
		end
		prune(breathes, function(entry: Breathe): Instance
			return entry.card
		end)
		for _, entry in breathes do
			entry.glow.ImageTransparency = math.clamp(entry.base + 0.12 + math.sin(now * 2.2) * 0.12, 0, 1)
		end

		prune(floats, function(entry: Float): Instance
			return entry.picture
		end)
		for _, entry in floats do
			entry.picture.Position = entry.base + UDim2.fromOffset(0, math.sin(now * 2 + entry.phase) * 4)
			entry.picture.Rotation = math.sin(now * 1.4 + entry.phase) * 2.5
		end
		prune(wiggles, function(entry: Wiggle): Instance
			return entry.button
		end)
		for _, entry in wiggles do
			local p = (now + entry.phase) % entry.period
			entry.button.Rotation = if p < 0.5 then math.sin(p * 42) * 10 * (1 - p / 0.5) else 0
		end
		prune(pulses, function(entry: Pulse): Instance
			return entry.ribbon
		end)
		for _, entry in pulses do
			entry.scale.Scale = 1 + math.sin(now * 4) * 0.06
			entry.ribbon.Rotation = entry.rotation + math.sin(now * 2.2) * 3
		end
		prune(shimmers, function(entry: Shimmer): Instance
			return entry.label
		end)
		for _, entry in shimmers do
			local p = ((now + entry.phase) % 3.2) / 3.2
			entry.gradient.Offset = Vector2.new(if p < 0.4 then -1 + p / 0.4 * 2 else 1, 0)
		end

		for _, mote in motes do
			mote.y -= mote.speed * dt
			if mote.y < 0 then
				mote.y = 1
				mote.x = math.random()
			end
			mote.image.Position = UDim2.fromScale(mote.x + math.sin(now * 0.8 + mote.phase) * 0.012, mote.y)
			mote.image.ImageTransparency = 0.35 + 0.4 * (0.5 + 0.5 * math.sin(now * 3 + mote.phase))
		end

		prune(embers, function(entry: Ember): Instance
			return entry.image
		end)
		for _, ember in embers do
			ember.y -= ember.speed * dt
			if ember.y < -0.05 then
				ember.y = 1.05
				ember.x = math.random()
				ember.image.ImageColor3 = tintColor("fire")
			end
			if onScreen(ember.card) then
				local life = math.clamp(ember.y, 0, 1)
				local size = ember.size * (0.4 + life * 0.6)
				ember.image.Size = UDim2.fromOffset(size, size)
				ember.image.Position = UDim2.fromScale(ember.x + math.sin(now * 2.5 + ember.phase) * 0.03, ember.y)
				ember.image.Rotation = now * 90 + ember.phase * 40
				ember.image.ImageTransparency = 1 - life * 0.9
			end
		end

		prune(punches, function(entry: Punch): Instance
			return entry.picture
		end)
		for _, entry in punches do
			if now >= entry.nextAt and onScreen(entry.picture) then
				entry.nextAt = now + 2.6 + math.random() * 1.6
				entry.startedAt = now
			end
			local t = now - entry.startedAt
			-- Wind up (shrink), strike (big), settle.
			if t < 0.12 then
				entry.scale.Scale = 1 - t / 0.12 * 0.12
			elseif t < 0.22 then
				entry.scale.Scale = 0.88 + (t - 0.12) / 0.1 * 0.47
			elseif t < 0.6 then
				entry.scale.Scale = 1.35 - (t - 0.22) / 0.38 * 0.35
			else
				entry.scale.Scale = 1
			end
			if t >= 0.18 and t < 0.75 then
				local p = (t - 0.18) / 0.57
				local size = 20 + p * 230
				entry.ring.Size = UDim2.fromOffset(size, size)
				entry.edge.Transparency = p
				entry.edge.Thickness = 7 * (1 - p) + 1
			else
				entry.edge.Transparency = 1
			end
		end
	end)

	return fx
end

return StoreFx
