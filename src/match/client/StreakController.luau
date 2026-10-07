--!strict
-- The STREAK meter (client), on the left of the screen from your first payout: the multiplier
-- in a burning badge, how many in a row, what the next one unlocks, and a bar draining towards
-- the end of the streak (it throbs red near the end). Every payout bumps it; reaching a new
-- multiplier lights it up with a roar of fire and stars. When it runs out it goes grey, shakes
-- and fades: STREAK LOST.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local settings = Config.Streak
local WIDTH = 230
local FIRE_TOP = Color3.fromRGB(255, 220, 70)
local FIRE_MID = Color3.fromRGB(255, 120, 30)
local FIRE_LOW = Color3.fromRGB(200, 30, 30)
local COLD = Color3.fromRGB(110, 110, 125)

local StreakController = {}

local function multiplierFor(count: number): number
	local multiplier = 1
	for _, tier in settings.Tiers do
		if count >= tier.count then
			multiplier = tier.multiplier
		end
	end
	return multiplier
end

-- The next tier above `count`, if any.
local function nextTier(count: number): { count: number, multiplier: number }?
	for _, tier in settings.Tiers do
		if tier.count > count then
			return tier
		end
	end
	return nil
end

function StreakController.start()
	local root = UI.root(UI.screen("Streak", 4))
	local holder = UI.frame({
		Name = "Streak",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH, 92),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	local glow = UI.glow(FIRE_MID, {
		Size = UDim2.fromOffset(WIDTH * 1.5, 220),
		ImageTransparency = 0.5,
		ZIndex = 0,
	}, holder)
	local panel = UI.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 1,
	}, holder)
	UI.corner(panel, 14)
	local border = UI.stroke(panel, 3)
	-- Flames: a fire gradient that flickers up and down the panel.
	local flames = Instance.new("UIGradient")
	flames.Rotation = -90
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, FIRE_LOW),
		ColorSequenceKeypoint.new(0.45, FIRE_MID),
		ColorSequenceKeypoint.new(1, FIRE_TOP),
	})
	flames.Parent = panel

	local badge = UI.frame({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Color3.fromRGB(40, 15, 10),
		ZIndex = 3,
	}, panel)
	UI.corner(badge, 29)
	UI.stroke(badge, 3)
	local multiplierLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 0.6, 0),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = FIRE_TOP,
		Text = "x1",
		ZIndex = 4,
	}, badge)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 26
	fit.Parent = multiplierLabel
	UI.textStroke(multiplierLabel, 2.5)
	local title = UI.label({
		Position = UDim2.fromOffset(74, 6),
		Size = UDim2.new(1, -80, 0, 26),
		FontFace = UI.Fonts.Title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "STREAK",
		ZIndex = 3,
	}, panel)
	UI.textStroke(title, 2.5)
	local countLabel = UI.label({
		Position = UDim2.fromOffset(74, 32),
		Size = UDim2.new(1, -80, 0, 18),
		FontFace = UI.Fonts.Heading,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
	}, panel)
	local nextLabel = UI.label({
		Position = UDim2.fromOffset(74, 50),
		Size = UDim2.new(1, -80, 0, 16),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 240, 200),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
	}, panel)
	local _, timeFill = UI.bar(FIRE_TOP, {
		Position = UDim2.new(0, 8, 1, -20),
		Size = UDim2.new(1, -16, 0, 12),
		ZIndex = 3,
	}, panel)
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local shown = 0
	local endsAt = 0
	local lost = false

	-- Embers floating up off the top of the panel.
	local function ember()
		local size = math.random(4, 8)
		local dot = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, 0, 4),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = if math.random() < 0.5 then FIRE_TOP else FIRE_MID,
			ZIndex = 5,
		}, holder)
		UI.corner(dot, size)
		local seconds = 0.6 + math.random() * 0.6
		UI.tween(dot, seconds, {
			Position = UDim2.new(dot.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 0, -40 - math.random(0, 30)),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		})
		task.delay(seconds, function()
			dot:Destroy()
		end)
	end

	local function setLook(cold: boolean)
		local tint = if cold then COLD else Color3.new(1, 1, 1)
		panel.BackgroundColor3 = tint
		glow.ImageColor3 = if cold then COLD else FIRE_MID
		multiplierLabel.TextColor3 = if cold then Color3.new(1, 1, 1) else FIRE_TOP
		flames.Enabled = not cold
		border.Color = UI.Colors.Ink
	end

	local function render(count: number)
		multiplierLabel.Text = `x{multiplierFor(count)}`
		countLabel.Text = if count == 1 then "1 PAYOUT" else `{count} IN A ROW`
		local upcoming = nextTier(count)
		nextLabel.Text = if upcoming then `{upcoming.count - count} more for x{upcoming.multiplier}` else "MAXED OUT!"
	end

	local function show(count: number, ends: number)
		local before = shown
		endsAt = ends
		if count == before then
			return
		end
		shown = count
		if count <= 0 then
			if before >= 1 and not lost then
				-- STREAK LOST: grey, a shake, then gone.
				lost = true
				setLook(true)
				countLabel.Text = "STREAK LOST"
				nextLabel.Text = `It was {before} in a row`
				Sounds.play("Fail", 0.8, 0.5)
				task.spawn(function()
					for index = 1, 6 do
						holder.Position = UDim2.new(0, 10 + (if index % 2 == 0 then 6 else -6), 0.5, 0)
						task.wait(0.04)
					end
					holder.Position = UDim2.new(0, 10, 0.5, 0)
					task.wait(0.9)
					if shown <= 0 then
						UI.tween(scale, 0.25, { Scale = 0 })
						task.wait(0.25)
						if shown <= 0 then
							holder.Visible = false
						end
					end
					lost = false
				end)
			end
			return
		end
		lost = false
		setLook(false)
		holder.Visible = true
		render(count)
		if before <= 0 then
			scale.Scale = 0.3
			TweenService
				:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
		local hotter = multiplierFor(count) > multiplierFor(before)
		if hotter then
			-- A new multiplier: a roar of fire, stars out of the badge, the screen glows orange.
			Sounds.play("StreakUp")
			UI.pop(badge, 0.6)
			UI.pop(holder, 0.18)
			ScreenFx.stars(badge.AbsolutePosition + badge.AbsoluteSize / 2, 14, FIRE_TOP)
			ScreenFx.flash(FIRE_MID, 0.18)
			for _ = 1, 10 do
				ember()
			end
		else
			UI.pop(holder, 0.08)
			UI.pop(multiplierLabel, 0.25)
		end
	end

	ClientState.changed:Connect(function(_snapshot: Types.RunSnapshot)
		local me = ClientState.me()
		if me then
			show(me.streak, me.streakEndsAt)
		end
	end)

	local sinceEmber = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not holder.Visible then
			return
		end
		-- The flames flicker; hotter streaks flicker faster and throw more embers.
		local heat = math.clamp(shown / settings.InfernoCount, 0, 1)
		local now = os.clock()
		flames.Offset = Vector2.new(0, math.sin(now * (4 + heat * 6)) * 0.08 + math.sin(now * 11.3) * 0.03)
		glow.ImageTransparency = 0.55 - heat * 0.25 + math.sin(now * 5) * 0.08
		glow.Size = UDim2.fromOffset(WIDTH * (1.4 + heat * 0.4), 200 + heat * 80)
		if not lost and shown >= 2 then
			sinceEmber += dt
			local every = 0.5 - heat * 0.4
			if sinceEmber >= every then
				sinceEmber = 0
				ember()
			end
		end
		if lost then
			timeFill.Size = UDim2.fromScale(0, 1)
			return
		end
		local left = math.max(endsAt - Timing.now(), 0)
		local fraction = math.clamp(left / settings.WindowSeconds, 0, 1)
		timeFill.Size = UDim2.fromScale(fraction, 1)
		if fraction < 0.25 then
			local beat = (math.sin(now * 12) + 1) / 2
			timeFill.BackgroundColor3 = UI.Colors.Danger:Lerp(Color3.new(1, 1, 1), beat * 0.4)
		else
			timeFill.BackgroundColor3 = FIRE_TOP
		end
	end)
end

return StreakController
