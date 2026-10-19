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
	if jackpot then
		ScreenFx.boom()
		Sounds.play("Fanfare")
		ScreenFx.rain(50)
	elseif item then
		Sounds.play("Badge")
	else
		Sounds.play("Purchase")
	end
	task.wait(SHOW_SECONDS)
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

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
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
					{ preset = "Sparkles", count = 24, color = slice.color },
					{ preset = "Stars", count = 12, color = UI.Colors.Gold },
					{ preset = "Confetti", count = if slice.jackpot then 60 else 20, color = slice.color },
				})
				Sounds.at(if slice.jackpot then "Fanfare" else "Ding", hub)
			else
				angle = to
			end
		end
		if angle ~= shownAngle then
			shownAngle = angle
			spinner:PivotTo(turned(angle))
			local under = Wheel.sliceAt(angle)
			if spinning and under ~= lastSlice then
				Sounds.at("Click", hub)
			end
			lastSlice = under
		end
		local clock = os.clock()
		if clock >= nextStep then
			step += 1
			nextStep = clock + (if spinning then 0.08 else 0.45)
			lights(root, spinner, step)
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
