--!strict
-- Things that happen to players, drawn in the world on our screen (anyone within
-- Config.Fx.WorldRange): cash bursting out of whoever just got paid (real bills that tumble to
-- the ground, coins and sparkle, and "+$1,500" over their head), a fountain at the bank in their
-- bank burst, a pillar of light when they level up, a flash of red and blue when they're
-- busted. Anyone on a hot streak burns: sparks at their feet, then flames, then a blaze.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CosmeticFx = require(Shared:WaitForChild("CosmeticFx"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Format = require(Shared:WaitForChild("Format"))
local Particles = require(Shared:WaitForChild("Particles"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local STREAK_ATTRIBUTE = "Streak"
local FX_GROUP = "Fx" -- lands on the ground, passes through people and cars (server CollisionGroups)
local BILL_GREEN = Color3.fromRGB(96, 200, 96)
local LEVEL_COLOR = Color3.fromRGB(190, 120, 255)

local streak = Config.Streak
local player = Players.LocalPlayer
local rng = Random.new()

local WorldFxController = {}

local function near(at: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - at).Magnitude <= Config.Fx.WorldRange
end

local function rootOf(who: Player): BasePart?
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Words floating up over someone's head ("+$1,500", "LEVEL 7", "BUSTED!").
local function floatText(who: Player, text: string, color: Color3, size: number?)
	local character = who.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatText"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = Config.Fx.WorldRange
	gui.Adornee = head
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Title,
		TextSize = size or 34,
		TextColor3 = color,
		Text = text,
	}, gui)
	UI.textStroke(label, 3)
	gui.Parent = player:WaitForChild("PlayerGui")
	UI.pop(label, 0.5)
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 6, 0),
	}):Play()
	task.delay(0.8, function()
		UI.tween(label, 0.6, { TextTransparency = 1 })
		local outline = label:FindFirstChild("TextOutline")
		if outline and outline:IsA("UIStroke") then
			UI.tween(outline, 0.6, { Transparency = 1 })
		end
	end)
	Debris:AddItem(gui, 1.5)
end

-- Real little bank notes thrown out of someone: they tumble, land and fade.
local function throwBills(at: Vector3, count: number)
	for _ = 1, count do
		local note = Instance.new("Part")
		note.Name = "Bill"
		note.Size = Vector3.new(0.9, 0.05, 0.45)
		note.Color = if rng:NextNumber() < 0.5 then BILL_GREEN else Color3.fromRGB(70, 170, 80)
		note.Material = Enum.Material.SmoothPlastic
		note.TopSurface = Enum.SurfaceType.Smooth
		note.BottomSurface = Enum.SurfaceType.Smooth
		note.CollisionGroup = FX_GROUP
		note.CanQuery = false
		note.CanTouch = false
		note.CastShadow = false
		note.CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)))
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		note.Parent = workspace
		local out = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		note.AssemblyLinearVelocity = out * rng:NextNumber(6, 14) + Vector3.new(0, rng:NextNumber(14, 24), 0)
		note.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(rng:NextNumber(1.8, 2.4), function()
			if note.Parent then
				TweenService:Create(note, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.3, 0.05, 0.15) })
					:Play()
			end
		end)
		Debris:AddItem(note, 3)
	end
end

local function payout(event: Types.FxEvent)
	local amount = event.amount or 0
	local scale = math.log10(math.max(amount, 100) / 100) -- 0 at $100, 2 at $10,000
	local chest = event.at + Vector3.new(0, 1.5, 0)
	throwBills(chest, math.clamp(math.floor(2 + scale * 4), 2, 12))
	Particles.burst(chest, {
		{
			preset = "Coins",
			count = math.clamp(math.floor(4 + scale * 6), 4, 18),
			color = Color3.fromRGB(255, 210, 60),
		},
		{ preset = "Sparkles", count = 8, color = Color3.fromRGB(255, 240, 160) },
	})
	if amount >= Config.Fx.BigPayout then
		Particles.burst(chest, {
			{ preset = "Flash", count = 1, color = Color3.fromRGB(255, 220, 90), scale = 0.6 },
			{ preset = "Bills", count = 16, color = BILL_GREEN },
		})
	end
	if event.player ~= player then
		floatText(event.player, `+{Format.money(amount)}`, UI.Colors.Money)
	end
end

local function deposit(event: Types.FxEvent)
	local item = if event.burst then Cosmetics.get(event.burst) else nil
	CosmeticFx.burst(event.at + Vector3.new(0, 1, 0), item)
end

-- A beam of light straight up through them, a shockwave on the ground and stars. Our own beam
-- is thinner and fainter, so it doesn't block the view.
local function levelUp(event: Types.FxEvent)
	local at = event.at
	local mine = event.player == player
	local wide = if mine then 2.5 else 4.5
	local pillar = Instance.new("Part")
	pillar.Name = "LevelPillar"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = LEVEL_COLOR
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Transparency = if mine then 0.6 else 0.3
	pillar.Size = Vector3.new(60, 0.5, 0.5)
	pillar.CFrame = CFrame.new(at + Vector3.new(0, 27, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = workspace
	TweenService:Create(pillar, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(60, wide, wide),
	}):Play()
	task.delay(0.35, function()
		TweenService:Create(pillar, TweenInfo.new(0.9), { Transparency = 1, Size = Vector3.new(60, 0.2, 0.2) }):Play()
	end)
	Debris:AddItem(pillar, 1.4)
	local ground = at - Vector3.new(0, 2.6, 0)
	Particles.burst(ground, {
		{ preset = "Ring", count = 1, color = LEVEL_COLOR, scale = 1.6 },
		{ preset = "Vortex", count = 1, color = LEVEL_COLOR, scale = 1.2 },
	})
	Particles.burst(at, {
		{ preset = "Stars", count = 30, color = Color3.fromRGB(240, 210, 255), scale = 1.5 },
		{ preset = "Sparkles", count = 20, color = LEVEL_COLOR },
	})
	if event.player ~= player then
		floatText(event.player, `LEVEL {event.level or 0}`, LEVEL_COLOR, 38)
		local root = rootOf(event.player)
		if root then
			Sounds.at("LevelUp", root)
		end
	end
end

local function busted(event: Types.FxEvent)
	local at = event.at + Vector3.new(0, 1, 0)
	Particles.burst(at, {
		{ preset = "Sparks", count = 25, color = Color3.fromRGB(255, 60, 60) },
		{ preset = "Sparks", count = 25, color = Color3.fromRGB(70, 120, 255) },
		{ preset = "Flash", count = 1, color = Color3.fromRGB(255, 255, 255), scale = 0.7 },
		{ preset = "Smoke", count = 6, color = Color3.fromRGB(120, 120, 130) },
	})
	Particles.burst(event.at - Vector3.new(0, 2.6, 0), {
		{ preset = "Ring", count = 1, color = Color3.fromRGB(255, 60, 60), scale = 1.2 },
	})
	if event.player ~= player then
		floatText(event.player, "BUSTED!", UI.Colors.Danger, 38)
	end
end

-- Flames for a hot streak, on one character: rebuilt whenever its Streak changes tier.
local function burn(character: Model)
	local current = -1
	local made: { Instance } = {}
	local function refresh()
		local count = character:GetAttribute(STREAK_ATTRIBUTE)
		local value = if typeof(count) == "number" then count else 0
		local tier = if value >= streak.InfernoCount
			then 3
			elseif value >= streak.BlazeCount then 2
			elseif value >= streak.FlameCount then 1
			else 0
		if tier == current then
			return
		end
		current = tier
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
		local root = character:FindFirstChild("HumanoidRootPart")
		if tier == 0 or not root or not root:IsA("BasePart") then
			return
		end
		local feet = Instance.new("Attachment")
		feet.Name = "StreakFlames"
		feet.Position = Vector3.new(0, -2.6, 0)
		feet.Parent = root
		table.insert(made, feet)
		local orange = Color3.fromRGB(255, 140, 40)
		Particles.keep(feet, "Sparks", 6 + tier * 4, orange, 0.4)
		if tier >= 2 then
			Particles.keep(
				feet,
				"Fire",
				14 + tier * 8,
				ColorSequence.new(Color3.fromRGB(255, 230, 100), Color3.fromRGB(230, 50, 20)),
				0.7 + tier * 0.15
			)
		end
		if tier >= 3 then
			local smoke = Particles.keep(feet, "Smoke", 4, Color3.fromRGB(70, 50, 50), 0.8)
			smoke.Transparency = NumberSequence.new(0.6, 1)
			Particles.keep(root, "Sparkles", 6, Color3.fromRGB(255, 200, 80), 0.5)
		end
		local glow = Instance.new("PointLight")
		glow.Name = "StreakLight"
		glow.Color = orange
		glow.Range = 6 + tier * 4
		glow.Brightness = 0.8 + tier * 0.6
		glow.Shadows = false
		glow.Parent = root
		table.insert(made, glow)
		-- Bursting into a hotter tier throws a puff of fire.
		Particles.emit(feet, {
			{ preset = "Fire", count = 10 + tier * 6, color = orange, scale = 1.2 },
			{ preset = "Sparks", count = 16, color = Color3.fromRGB(255, 200, 80) },
		})
	end
	character:GetAttributeChangedSignal(STREAK_ATTRIBUTE):Connect(refresh)
	refresh()
end

function WorldFxController.start()
	Remotes.match().Fx:onClient(function(event: Types.FxEvent)
		if not near(event.at) then
			return
		end
		if event.kind == "Payout" then
			payout(event)
		elseif event.kind == "Deposit" then
			deposit(event)
		elseif event.kind == "LevelUp" then
			levelUp(event)
		elseif event.kind == "Busted" then
			busted(event)
		end
	end)

	local function watch(other: Player)
		if other.Character then
			task.spawn(burn, other.Character)
		end
		other.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			burn(character)
		end)
	end
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
end

return WorldFxController
