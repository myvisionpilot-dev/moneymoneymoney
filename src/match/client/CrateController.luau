--!strict
-- Opening a crate from Tony's (server/CrateService has already handed the prize over): the
-- crate drops in on a dark screen, shakes harder and harder while a glow builds behind it (in
-- the prize's rarity colour near the end), then bursts in a flash, a shockwave and splinters,
-- and the prize turns on sunburst rays with its rarity and name. Click (or wait) to close.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local STAGE = 260 -- the crate's picture, in virtual pixels
local SHOW_SECONDS = 3.6 -- the prize stays up this long unless you click
local SPLINTERS: { [string]: { Color3 } } = {
	LuckyCrate = { Color3.fromRGB(190, 125, 65), Color3.fromRGB(120, 80, 45), Color3.fromRGB(255, 215, 60) },
	GoldCrate = { Color3.fromRGB(255, 205, 50), Color3.fromRGB(200, 120, 30), Color3.fromRGB(255, 110, 200) },
	DiamondCrate = { Color3.fromRGB(150, 225, 255), Color3.fromRGB(235, 245, 255), Color3.fromRGB(170, 90, 255) },
}
local DUST = { Color3.fromRGB(200, 190, 170), Color3.fromRGB(160, 150, 135) }
local CHEERS: { [string]: string } = { Common = "NICE!", Rare = "RARE!", Epic = "EPIC!", Legendary = "LEGENDARY!" }

local CrateController = {}

local queue: { Types.CrateReveal } = {}
local busy = false

local function centreOf(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

local function spin(image: GuiObject, speed: number): RBXScriptConnection
	return RunService.RenderStepped:Connect(function(dt: number)
		image.Rotation = (image.Rotation + speed * dt) % 360
	end)
end

local function play(root: Frame, reveal: Types.CrateReveal)
	local prize = Crates.prize(reveal.prize)
	local tier = reveal.tier :: Crates.Tier
	local color = Crates.TierColors[tier] or UI.Colors.Gold
	local big = tier == "Epic" or tier == "Legendary"
	-- The shop window steps aside while it opens.
	local shop = Players.LocalPlayer.PlayerGui:FindFirstChild("Shop")
	local hidShop = shop ~= nil and shop:IsA("ScreenGui") and shop.Enabled
	if hidShop and shop and shop:IsA("ScreenGui") then
		shop.Enabled = false
	end

	local shade = UI.frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
	}, root)
	UI.tween(shade, 0.25, { BackgroundTransparency = 0.25 })
	local stage = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(STAGE, STAGE),
		BackgroundTransparency = 1,
	}, shade)

	-- The glow that builds up behind the crate.
	local glow = UI.glow(Color3.new(1, 1, 1), {
		Size = UDim2.fromOffset(STAGE * 0.6, STAGE * 0.6),
		ImageTransparency = 0.7,
		ZIndex = 1,
	}, stage)
	local crate = ItemModels.viewport(reveal.crate, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.6),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, stage, true)
	Sounds.play("Whoosh", 1.1, 0.7)
	TweenService:Create(crate, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	task.wait(0.45)
	-- It lands: a thud, a puff of dust and a little jolt.
	Sounds.play("Thud", 1, 0.8)
	local landedAt = centreOf(stage) + Vector2.new(0, STAGE * 0.35)
	ScreenFx.debris(landedAt, 10, DUST)
	ScreenFx.shockwave(landedAt, Color3.new(1, 1, 1))
	ScreenFx.shake(0.15, 0.15)

	-- Rays fade in behind the crate and spin up as it shakes.
	local tease = Instance.new("ImageLabel")
	tease.Name = "Tease"
	tease.AnchorPoint = Vector2.new(0.5, 0.5)
	tease.Position = UDim2.fromScale(0.5, 0.5)
	tease.Size = UDim2.fromOffset(STAGE * 1.6, STAGE * 1.6)
	tease.BackgroundTransparency = 1
	tease.Image = UI.Images.Sunburst
	tease.ImageTransparency = 1
	tease.ZIndex = 1
	tease.Parent = stage

	-- Shake: harder, faster ticks and rattles, the glow swelling (and turning the rarity colour),
	-- sparks leaking out, and a rising rush of wind.
	local seconds = Config.Crates.RevealSeconds
	local started = os.clock()
	local nextTick = 0
	local nextSpark = 0
	local rattle = 0
	local rng = Random.new()
	local rush = Sounds.loop("Wind", 0.5)
	while true do
		local t = (os.clock() - started) / seconds
		if t >= 1 then
			break
		end
		local amp = 2 + 16 * t * t
		crate.Position = UDim2.new(0.5, rng:NextNumber(-amp, amp), 0.5, rng:NextNumber(-amp, amp) * 0.6)
		crate.Rotation = rng:NextNumber(-amp, amp) * 0.8
		local size = STAGE * (0.6 + 0.9 * t)
		local tint = Color3.new(1, 1, 1):Lerp(color, math.clamp((t - 0.45) * 2.5, 0, 1))
		glow.Size = UDim2.fromOffset(size, size)
		glow.ImageTransparency = 0.7 - 0.5 * t
		glow.ImageColor3 = tint
		tease.ImageTransparency = 1 - 0.6 * t
		tease.ImageColor3 = tint
		tease.Rotation = (tease.Rotation + (30 + 330 * t) * (1 / 60)) % 360
		if rush then
			rush.PlaybackSpeed = 0.6 + 1.1 * t
		end
		if os.clock() >= nextTick then
			rattle += 1
			if rattle % 2 == 0 then
				Sounds.play("LockRattle", 0.9 + t * 0.6, 0.6)
			else
				Sounds.play("Click", 0.9 + t * 0.7, 0.7)
			end
			nextTick = os.clock() + 0.28 - 0.2 * t
		end
		if t > 0.25 and os.clock() >= nextSpark then
			local edge = centreOf(stage) + Vector2.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4)) * STAGE
			ScreenFx.stars(edge, 2 + math.floor(t * 4), tint)
			nextSpark = os.clock() + 0.3 - 0.22 * t
		end
		RunService.RenderStepped:Wait()
	end
	if rush then
		rush:Destroy()
	end
	tease:Destroy()

	-- Pop!
	local centre = centreOf(stage)
	crate:Destroy()
	Sounds.play("Smash", 1, 0.8)
	Sounds.play("Crack", 1.2, 0.6)
	ScreenFx.flash(color, if big then 0.6 else 0.4)
	ScreenFx.shockwave(centre, color)
	task.delay(0.12, function()
		ScreenFx.shockwave(centre, Color3.new(1, 1, 1))
	end)
	ScreenFx.debris(centre, 34, SPLINTERS[reveal.crate] or { color })
	ScreenFx.stars(centre, if big then 48 else 26, color)
	ScreenFx.shake(0.25, 0.2)
	if tier == "Legendary" then
		Sounds.play("Fanfare")
		ScreenFx.boom()
		ScreenFx.shake(0.8, 0.5)
		ScreenFx.rain(50)
		task.spawn(function()
			-- Fireworks all over the screen.
			local size = root.AbsoluteSize
			for index = 1, 7 do
				task.wait(0.22)
				local at = root.AbsolutePosition
					+ Vector2.new(size.X * rng:NextNumber(0.15, 0.85), size.Y * rng:NextNumber(0.12, 0.6))
				local hue = if index % 2 == 0 then UI.Colors.Gold else color
				ScreenFx.stars(at, 22, hue)
				ScreenFx.shockwave(at, hue)
				Sounds.play("Crack", rng:NextNumber(1.3, 1.8), 0.5)
			end
		end)
	elseif tier == "Epic" then
		ScreenFx.boom()
		Sounds.play("LevelUp", 1, 0.8)
		ScreenFx.shake(0.5, 0.35)
		ScreenFx.rain(24)
		task.delay(0.3, function()
			ScreenFx.stars(centre, 30, UI.Colors.Gold)
			ScreenFx.shockwave(centre, color)
		end)
	elseif tier == "Rare" then
		Sounds.play("LevelUp", 1.1, 0.7)
		Sounds.play("Purchase")
	else
		Sounds.play("Purchase")
	end

	-- The prize on turning rays.
	glow.ImageColor3 = color
	glow.ImageTransparency = 0.25
	glow.Size = UDim2.fromOffset(STAGE * 1.3, STAGE * 1.3)
	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(STAGE * 2.2, STAGE * 2.2)
	rays.BackgroundTransparency = 1
	rays.Image = UI.Images.Sunburst
	rays.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	rays.ImageTransparency = 0.35
	rays.ZIndex = 1
	rays.Parent = stage
	local turning = spin(rays, 22)

	local holder = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, stage)
	local grow = Instance.new("UIScale")
	grow.Scale = 0.1
	grow.Parent = holder
	ItemModels.viewport(if prize then prize.picture else reveal.prize, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, holder, true)
	TweenService:Create(grow, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local cheer = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(420, 44),
		FontFace = UI.Fonts.Title,
		TextSize = 40,
		TextColor3 = color,
		Text = CHEERS[tier] or "NICE!",
		ZIndex = 5,
	}, stage)
	UI.textStroke(cheer, 4)
	UI.pop(cheer, 0.5)
	local name = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(460, 40),
		FontFace = UI.Fonts.Title,
		TextSize = 34,
		Text = if prize then prize.title else reveal.prize,
		ZIndex = 5,
	}, stage)
	UI.textStroke(name, 3.5)
	UI.pop(name, 0.4)
	local line = if reveal.swapped then "Already maxed: every treat instead" elseif prize then prize.text else ""
	UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 44),
		Size = UDim2.fromOffset(460, 24),
		TextSize = 20,
		TextColor3 = UI.Colors.Muted,
		Text = line,
		ZIndex = 5,
	}, stage)

	-- Close on a click or tap, or after a while.
	local closed = false
	local inputs = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			closed = true
		end
	end)
	local shownAt = os.clock()
	local rng = Random.new()
	local nextTwinkle = 0
	-- While it's up the prize bobs and the glow breathes, with twinkles round it.
	local function idle()
		local age = os.clock() - shownAt
		holder.Position = UDim2.new(0.5, 0, 0.5, math.sin(age * 3) * 6)
		glow.ImageTransparency = 0.25 + 0.15 * math.sin(age * 4)
		if os.clock() >= nextTwinkle then
			local around = centreOf(stage) + Vector2.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.55, 0.55)) * STAGE
			ScreenFx.stars(around, if big then 5 else 3, if rng:NextNumber() < 0.5 then color else UI.Colors.Gold)
			nextTwinkle = os.clock() + (if big then 0.15 else 0.3)
		end
	end
	while os.clock() - shownAt < 0.6 do -- a click right at the pop doesn't skip it
		idle()
		task.wait(0.03)
	end
	closed = false
	while not closed and os.clock() - shownAt < SHOW_SECONDS do
		idle()
		task.wait(0.03)
	end
	inputs:Disconnect()
	turning:Disconnect()
	UI.tween(shade, 0.2, { BackgroundTransparency = 1 })
	TweenService:Create(grow, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.2)
	shade:Destroy()
	if hidShop and shop and shop:IsA("ScreenGui") then
		shop.Enabled = true
	end
end

function CrateController.start()
	local root = UI.root(UI.screen("CrateReveal", 50))
	Remotes.match().CrateOpened:onClient(function(reveal: Types.CrateReveal)
		table.insert(queue, reveal)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			while #queue > 0 do
				play(root, table.remove(queue, 1) :: Types.CrateReveal)
			end
			busy = false
		end)
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		table.clear(queue)
	end)
end

return CrateController
