--!strict
-- The Lucky Wheel on our screen (server/WheelService picks every spin; we only draw it):
--   it turns by the wheel's spin attributes, so everyone sees the same spin, ticking past each
--   peg and slowing to a stop; its bulbs chase round (faster while it turns) and the slice it
--   lands on bursts with sparkles.
--   On our own spin the camera swings round to face it, and when it stops the prize pops up:
--   Cred, or the cosmetic we won.
--   The sign on its base shows our spins, or how long until the next free one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Format = require(Shared:WaitForChild("Format"))
local Particles = require(Shared:WaitForChild("Particles"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local Wheel = require(Shared:WaitForChild("Wheel"))

local BULB_ON = Color3.fromRGB(255, 245, 200)
local BULB_OFF = Color3.fromRGB(120, 90, 40)
local CAMERA_BACK = 22 -- studs in front of the wheel the camera sits on our spin
local SHOW_SECONDS = 3.5
local FLICK = math.rad(22) -- how far the pointer kicks as a peg goes past
local FINALE = 0.82 -- share of the spin after which the bulbs flash together (the drumroll)
local SPARKS_PER_SPEED = 0.12 -- rim sparkles a second per degree a second of turning
local BLINK_SECONDS = 2.4 -- the winning slice blinks this long

local WheelController = {}

local player = Players.LocalPlayer

-- Chasing bulbs: every other one lit, swapping each step.
local function lights(root: Model, spinner: Model, step: number)
	for _, holder in { spinner, root } do
		for _, bulb in holder:GetChildren() do
			if bulb:IsA("BasePart") and (bulb.Name == "Bulb" or bulb.Name == "SignBulb") then
				local index = bulb:GetAttribute("Index")
				local lit = typeof(index) == "number" and (index + step) % 2 == 0
				bulb.Color = if lit then BULB_ON else BULB_OFF
			end
		end
	end
end

-- All bulbs on or off together (the drumroll at the end of a spin).
local function allLights(root: Model, spinner: Model, on: boolean)
	for _, holder in { spinner, root } do
		for _, bulb in holder:GetChildren() do
			if bulb:IsA("BasePart") and (bulb.Name == "Bulb" or bulb.Name == "SignBulb") then
				bulb.Color = if on then BULB_ON else BULB_OFF
			end
		end
	end
end

-- The pointer kicks sideways as a peg passes, then springs back.
type Pointer = { parts: { [BasePart]: CFrame }, pivot: CFrame, axis: Vector3, kick: number }

local function makePointer(root: Model, frame: CFrame): Pointer?
	local ball = root:FindFirstChild("PointerBall")
	if not ball or not ball:IsA("BasePart") then
		return nil
	end
	local parts: { [BasePart]: CFrame } = {}
	for _, child in root:GetChildren() do
		if
			child:IsA("BasePart")
			and (child.Name == "Pointer" or child.Name == "PointerCap" or child.Name == "PointerBall")
		then
			parts[child] = child.CFrame
		end
	end
	return { parts = parts, pivot = CFrame.new(ball.Position), axis = frame.LookVector, kick = 0 }
end

local function drawPointer(pointer: Pointer, dt: number)
	pointer.kick *= math.exp(-dt * 14)
	local turn = pointer.pivot * CFrame.fromAxisAngle(pointer.axis, pointer.kick) * pointer.pivot:Inverse()
	for part, base in pointer.parts do
		part.CFrame = turn * base
	end
end

-- The winning slice blinks white and back.
local function blink(spinner: Model, index: number, color: Color3)
	local pieces: { BasePart } = {}
	for _, child in spinner:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Slice" and child:GetAttribute("Slice") == index then
			table.insert(pieces, child)
		end
	end
	task.spawn(function()
		local started = os.clock()
		local lit = false
		while os.clock() - started < BLINK_SECONDS do
			lit = not lit
			for _, piece in pieces do
				piece.Color = if lit then color:Lerp(Color3.new(1, 1, 1), 0.7) else color
				piece.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			task.wait(0.16)
		end
		for _, piece in pieces do
			piece.Color = color
			piece.Material = Enum.Material.SmoothPlastic
		end
	end)
end

-- Bursts going off in the air round the wheel, one after another.
local function fireworks(frame: CFrame, count: number, colors: { Color3 }, hub: BasePart)
	local rng = Random.new()
	task.spawn(function()
		for index = 1, count do
			local offset = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(5, 12), rng:NextNumber(1, 4))
			local color = colors[(index - 1) % #colors + 1]
			Particles.burst((frame * CFrame.new(offset)).Position, {
				{ preset = "Sparkles", count = 30, color = color, scale = 1.4 },
				{ preset = "Stars", count = 10, color = color },
				{ preset = "Ring", count = 1, color = color, scale = 2 },
			})
			local pop = Sounds.at("Crack", hub)
			if pop then
				pop.PlaybackSpeed = rng:NextNumber(1.3, 1.8)
			end
			task.wait(rng:NextNumber(0.18, 0.32))
		end
	end)
end

-- What the sign on the base says for us.
local function signText(): string
	local spins = player:GetAttribute("WheelSpins")
	if typeof(spins) == "number" and spins > 0 then
		return `{spins} FREE SPIN{if spins == 1 then "" else "S"}!`
	end
	local at = player:GetAttribute("WheelDailyAt")
	if typeof(at) ~= "number" then
		return "SPIN!"
	end
	local left = math.max(0, at - workspace:GetServerTimeNow())
	return string.format("FREE SPIN IN %d:%02d:%02d", left // 3600, left % 3600 // 60, left % 60)
end

-- The prize, in the middle of the screen on sunburst rays.
local function reveal(root: Frame, result: Types.WheelResult)
	local slice = Config.Wheel.Slices[result.slice]
	local item = if result.cosmetic then Cosmetics.get(result.cosmetic) else nil
	local jackpot = slice ~= nil and slice.jackpot == true
	local color = if item then Cosmetics.TierColors[item.tier] elseif slice then slice.color else UI.Colors.Gold
	local stage = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
	}, root)
	local rays = Instance.new("ImageLabel")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(520, 520)
	rays.BackgroundTransparency = 1
	rays.Image = UI.Images.Sunburst
	rays.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
	rays.ImageTransparency = 0.3
	rays.Parent = stage
	local turning = RunService.RenderStepped:Connect(function(dt: number)
		rays.Rotation = (rays.Rotation + 25 * dt) % 360
	end)
	UI.glow(color, { Size = UDim2.fromOffset(300, 300), ImageTransparency = 0.2 }, stage)
	local grow = Instance.new("UIScale")
	grow.Scale = 0.1
	grow.Parent = stage
	TweenService:Create(grow, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local big = if item then "NEW ITEM!" elseif jackpot then "JACKPOT!" else `+{Format.number(result.cred)}`
	local small = if item then `{item.name} ({item.tier})` else "CRED"
	local title = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 70),
		FontFace = UI.Fonts.Title,
		TextSize = 62,
		TextColor3 = if jackpot then UI.Colors.Gold else Color3.new(1, 1, 1),
		Text = big,
	}, stage)
	UI.textStroke(title, 5)
	local subtitle = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(440, 36),
		FontFace = UI.Fonts.Title,
		TextSize = 30,
		TextColor3 = if item then color else UI.Colors.Gold,
		Text = if jackpot then `+{Format.cred(result.cred)}` else small,
	}, stage)
	UI.textStroke(subtitle, 3.5)

	local centre = stage.AbsolutePosition + stage.AbsoluteSize / 2
	ScreenFx.flash(color, if jackpot then 0.6 else 0.35)
	ScreenFx.stars(centre, if jackpot then 44 else 24, color)
	ScreenFx.shockwave(centre, color)
	task.delay(0.15, function()
		ScreenFx.shockwave(centre, Color3.new(1, 1, 1))
	end)
	if jackpot then
		ScreenFx.boom()
		ScreenFx.shake(0.6, 0.5)
		Sounds.play("Fanfare")
		ScreenFx.rain(70)
	elseif item then
		Sounds.play("Badge")
		Sounds.play("LevelUp", 1, 0.7)
		ScreenFx.rain(16)
	else
		Sounds.play("Purchase")
		ScreenFx.rain(math.clamp(result.cred // 20, 10, 40))
	end
	-- Cred counts up, with the coins pouring.
	if not item and result.cred > 0 then
		local label = if jackpot then subtitle else title
		local function shown(value: number): string
			return "+" .. (if jackpot then Format.cred(value) else Format.number(value))
		end
		Sounds.play("CoinPour", 1, 0.8)
		UI.roll(label, 0, shown)
		UI.roll(label, result.cred, shown, 1.1)
	end
	-- Twinkles round the prize and a throb while it's up.
	local shownAt = os.clock()
	local rng = Random.new()
	while os.clock() - shownAt < SHOW_SECONDS do
		local around = centre + Vector2.new(rng:NextNumber(-170, 170), rng:NextNumber(-130, 130))
		ScreenFx.stars(around, 3, if rng:NextNumber() < 0.5 then color else UI.Colors.Gold)
		grow.Scale = 1 + 0.04 * math.sin((os.clock() - shownAt) * 6)
		task.wait(0.25)
	end
	grow.Scale = 1
	TweenService:Create(grow, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.2)
	turning:Disconnect()
	stage:Destroy()
end

-- Swings our camera round to face the wheel for our own spin, and back after.
local function watchSpin(frame: CFrame, seconds: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local goal =
		CFrame.lookAt((frame * CFrame.new(0, -1, CAMERA_BACK)).Position, frame.Position + Vector3.new(0, -1, 0))
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
		:Play()
	task.delay(seconds + 1.2, function()
		camera.CameraType = Enum.CameraType.Custom
	end)
end

function WheelController.start(screenRoot: Frame)
	local root = workspace:WaitForChild("LuckyWheel") :: Model
	local spinner = root:WaitForChild("Spinner") :: Model
	local sign = root:WaitForChild("SpinsSign")
	local signLabel = sign:WaitForChild("Spins"):WaitForChild("Text") :: TextLabel
	local hub = spinner:WaitForChild("Hub") :: BasePart
	-- Where the wheel stands: wherever it was placed (only our own screen ever turns it).
	local frame = spinner.WorldPivot
	local function turned(angle: number): CFrame
		return frame * CFrame.Angles(0, 0, -math.rad(angle))
	end

	local shownAngle: number? = nil
	local spinStart = 0
	local landed = true
	local lastSlice = 0
	local step = 0
	local nextStep = 0
	local pointer = makePointer(root, frame)
	-- A light in the hub (brighter while it turns, a flash when it lands) and sparkles flying
	-- off the rim under the pointer, as many as the wheel is fast.
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Parent = hub
	local rimSpot = Instance.new("Attachment")
	rimSpot.WorldPosition = (frame * CFrame.new(0, Wheel.Radius, 0.8)).Position
	rimSpot.Parent = workspace.Terrain
	local sparks = Particles.keep(rimSpot, "Sparkles", 0, Color3.new(1, 1, 1), 2.4)
	local stars = Particles.keep(rimSpot, "Stars", 0, UI.Colors.Gold, 1.6)
	local flashUntil = 0

	-- Everyone sees a spin start: a whoosh and a puff of sparkles from the hub.
	root:GetAttributeChangedSignal("SpinStart"):Connect(function()
		Sounds.at("Whoosh", hub)
		Particles.burst(hub.Position, {
			{ preset = "Sparkles", count = 20, color = UI.Colors.Gold },
			{ preset = "Ring", count = 1, color = Color3.new(1, 1, 1), scale = 1.6 },
		})
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		local progress = 1
		local start = root:GetAttribute("SpinStart")
		local from = root:GetAttribute("SpinFrom")
		local to = root:GetAttribute("SpinTo")
		local seconds = root:GetAttribute("SpinSeconds")
		local angle = (root:GetAttribute("Angle") :: number?) or 0
		local spinning = false
		if
			typeof(start) == "number"
			and typeof(from) == "number"
			and typeof(to) == "number"
			and typeof(seconds) == "number"
		then
			local t = (now - start) / seconds
			progress = t
			if t < 1 then
				spinning = true
				angle = from + (to - from) * Wheel.ease(t)
				if start ~= spinStart then
					spinStart = start
					landed = false
				end
			elseif not landed then
				landed = true
				angle = to
				-- Landed: the slice under the pointer bursts.
				local index = Wheel.sliceAt(to)
				local slice = Config.Wheel.Slices[index]
				local at = (turned(to) * CFrame.new(Wheel.direction(Wheel.centre(index)) * Wheel.Radius * 0.6)).Position
				Particles.burst(at, {
					{ preset = "Sparkles", count = 36, color = slice.color },
					{ preset = "Stars", count = 16, color = UI.Colors.Gold },
					{ preset = "Confetti", count = if slice.jackpot then 90 else 30, color = slice.color },
					{ preset = "Coins", count = if slice.jackpot then 40 else 14 },
					{ preset = "Ring", count = 1, color = slice.color, scale = 3 },
				})
				Sounds.at(if slice.jackpot then "Fanfare" else "Ding", hub)
				Sounds.at("Coins", hub)
				blink(spinner, index, slice.color)
				fireworks(
					frame,
					if slice.jackpot then 9 else 3,
					{ slice.color, UI.Colors.Gold, Color3.new(1, 1, 1) },
					hub
				)
				if slice.jackpot then
					Sounds.at("Boom", hub)
				end
				flashUntil = os.clock() + 0.6
				light.Brightness = 8
			else
				angle = to
			end
		end
		if angle ~= shownAngle then
			local speed = if shownAngle and dt > 0 then math.abs(angle - shownAngle) / dt else 0
			sparks.Rate = if spinning then speed * SPARKS_PER_SPEED else 0
			stars.Rate = sparks.Rate * 0.25
			shownAngle = angle
			spinner:PivotTo(turned(angle))
			local under = Wheel.sliceAt(angle)
			if spinning and under ~= lastSlice then
				-- A peg goes past: tick (higher and louder near the end) and kick the pointer.
				local tick = Sounds.at("Click", hub)
				if tick then
					tick.PlaybackSpeed = 0.9 + 0.5 * progress
				end
				if pointer then
					pointer.kick = FLICK
				end
			end
			lastSlice = under
		else
			sparks.Rate = 0
			stars.Rate = 0
		end
		if pointer then
			drawPointer(pointer, dt)
		end
		-- The hub light: warm while it turns, pulsing in the finale, a flash as it lands.
		local clock = os.clock()
		if clock < flashUntil then
			light.Brightness = math.max(light.Brightness - dt * 12, 1)
		elseif spinning then
			light.Brightness = if progress > FINALE then 2 + 2 * math.abs(math.sin(clock * 18)) else 1.5
		else
			light.Brightness = math.max(light.Brightness - dt * 4, 0)
		end
		if clock >= nextStep then
			step += 1
			if spinning and progress > FINALE then
				-- The drumroll: every bulb flashes together.
				nextStep = clock + 0.06
				allLights(root, spinner, step % 2 == 0)
			else
				nextStep = clock + (if spinning then 0.08 else 0.45)
				lights(root, spinner, step)
			end
		end
	end)

	-- The sign: our spins (or the countdown to the next free one).
	task.spawn(function()
		while true do
			signLabel.Text = signText()
			task.wait(1)
		end
	end)

	-- Our spin: face the wheel; our prize when it stops.
	root:GetAttributeChangedSignal("SpinStart"):Connect(function()
		local seconds = root:GetAttribute("SpinSeconds")
		if root:GetAttribute("SpinBy") == player.UserId and typeof(seconds) == "number" then
			watchSpin(frame, seconds)
		end
	end)
	Remotes.lobby().WheelResult:onClient(function(result: Types.WheelResult)
		task.spawn(reveal, screenRoot, result)
	end)
end

return WheelController
