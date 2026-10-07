--!strict
-- Blasters on our side. With the blaster drawn: click (or tap, or the FIRE button on touch
-- screens) to fire where you're aiming; the server decides what it hits. Everyone sees each
-- shot's zap beam in the shooter's zap colour, with a muzzle flash, a burst where it lands and
-- the blaster's own style on top (lightning, water, rings, confetti, hot air, twin neon beams,
-- gold), and stars spin over whoever got stunned. If we get zapped, we sit down
-- until the stars clear.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Particles = require(Shared:WaitForChild("Particles"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local TOOL_NAME = "Blaster"
local STUN_ATTRIBUTE = "Stunned"
local AIM_STUDS = 150 -- how far the FIRE button looks for something to aim at
local BEAM_SECONDS = 0.25
local BEAM_COLOR = Color3.fromRGB(90, 230, 255)

local BlasterController = {}

local player = Players.LocalPlayer
local equipped: Tool? = nil
local lastShot = 0
local rng = Random.new()

local function fire(target: Vector3)
	local tool = equipped
	if not tool then
		return
	end
	local cooldown = tool:GetAttribute("Cooldown")
	local now = os.clock()
	if now - lastShot < (if typeof(cooldown) == "number" then cooldown else 1) then
		return
	end
	lastShot = now
	Remotes.match().FireBlaster:fire(target)
end

-- What's in the middle of the screen (for the touch FIRE button).
local function screenCentreTarget(): Vector3
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_STUDS, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_STUDS
end

-- A glowing bar from `from` to `to` that thins and fades.
local function beamPart(
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3,
	transparency: number,
	seconds: number?
): Part
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Name = "Zap"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = transparency
	beam.Size = Vector3.new(width, width, length)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(seconds or BEAM_SECONDS), {
		Transparency = 1,
		Size = Vector3.new(width * 0.15, width * 0.15, length),
	}):Play()
	Debris:AddItem(beam, 1)
	return beam
end

-- A jagged bolt of lightning along the shot.
local function zigzag(from: Vector3, to: Vector3, color: Color3)
	local steps = 6
	local look = CFrame.lookAt(from, to)
	local last = from
	for index = 1, steps do
		local along = from:Lerp(to, index / steps)
		local wobble = if index == steps
			then Vector3.zero
			else (look.RightVector * rng:NextNumber(-1, 1) + look.UpVector * rng:NextNumber(-1, 1)) * 0.7
		local point = along + wobble
		beamPart(last, point, 0.12, Color3.new(1, 1, 1):Lerp(color, 0.4), 0, 0.18)
		last = point
	end
end

-- Puffs of a preset at points along the shot.
local function along(from: Vector3, to: Vector3, count: number, shots: { Particles.Shot })
	for index = 1, count do
		Particles.burst(from:Lerp(to, index / (count + 1)), shots)
	end
end

-- Rings that race down the beam.
local function rings(from: Vector3, to: Vector3, color: Color3)
	local look = CFrame.lookAt(from, to)
	for index = 0, 3 do
		local ring = Instance.new("Part")
		ring.Name = "RetroRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.2
		ring.Size = Vector3.new(0.15, 1.6, 1.6)
		-- Cylinders lie along X; this turns the ring to face down the beam.
		ring.CFrame = look * CFrame.Angles(0, math.rad(90), 0)
		ring.Parent = workspace
		task.delay(index * 0.05, function()
			TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
				CFrame = CFrame.lookAt(to, to + look.LookVector) * CFrame.Angles(0, math.rad(90), 0),
				Size = Vector3.new(0.1, 2.4, 2.4),
				Transparency = 0.8,
			}):Play()
		end)
		Debris:AddItem(ring, 0.6)
	end
end

-- Each blaster's own look for its shot (on top of the beam, flash and impact every shot has).
type Style = (from: Vector3, to: Vector3, color: Color3) -> ()
local STYLES: { [string]: Style } = {
	Zapper = function(from, to, color)
		zigzag(from, to, color)
	end,
	MegaZapper = function(from, to, color)
		zigzag(from, to, color)
		zigzag(from, to, color)
		beamPart(from, to, 0.9, color, 0.6, 0.35)
		Particles.burst(to, { { preset = "Ring", count = 1, color = color, scale = 0.7 } })
	end,
	SquirtZapper = function(from, to, _color)
		local water = Color3.fromRGB(140, 210, 255)
		along(from, to, 4, { { preset = "Bubbles", count = 3, color = water } })
		Particles.burst(to, {
			{ preset = "Bubbles", count = 14, color = water, scale = 1.3 },
			{ preset = "Snow", count = 20, color = Color3.fromRGB(220, 240, 255), scale = 2 },
		})
	end,
	ToyBrick = function(_from, to, _color)
		local shots: { Particles.Shot } = {}
		for _, brick in
			{
				Color3.fromRGB(230, 50, 50),
				Color3.fromRGB(60, 130, 230),
				Color3.fromRGB(255, 205, 40),
				Color3.fromRGB(70, 190, 80),
			}
		do
			table.insert(shots, { preset = "Confetti", count = 6, color = brick, scale = 0.6 })
		end
		table.insert(shots, { preset = "Stars", count = 6, color = Color3.new(1, 1, 1) })
		Particles.burst(to, shots)
	end,
	RetroRay = function(from, to, color)
		rings(from, to, color)
	end,
	HairDryer = function(from, to, _color)
		along(from, to, 3, {
			{ preset = "Smoke", count = 1, color = Color3.fromRGB(255, 220, 190), scale = 0.5 },
			{ preset = "Fire", count = 1, color = Color3.fromRGB(255, 150, 60), scale = 0.4 },
		})
		Particles.burst(to, { { preset = "Sparks", count = 14, color = Color3.fromRGB(255, 160, 60) } })
	end,
	NeonRipper = function(from, to, color)
		local look = CFrame.lookAt(from, to)
		local side = look.RightVector * 0.3
		beamPart(from + side, to + side, 0.12, Color3.fromRGB(255, 60, 160), 0)
		beamPart(from - side, to - side, 0.12, Color3.fromRGB(60, 230, 255), 0)
		along(from, to, 3, { { preset = "Sparks", count = 4, color = color, scale = 0.4 } })
	end,
	GoldPlated = function(from, to, _color)
		local gold = Color3.fromRGB(255, 210, 60)
		along(from, to, 4, { { preset = "Sparkles", count = 3, color = gold, scale = 0.6 } })
		Particles.burst(to, { { preset = "Coins", count = 12, color = gold, scale = 0.7 } })
	end,
}

-- A glowing zap from the blaster to where it stopped, a flash at the muzzle, a burst where it
-- lands and a crackle, in the shooter's zap colour and their blaster's own style.
local function drawShot(shot: Types.BlasterFx)
	local from = shot.muzzle or shot.from
	local length = (shot.to - from).Magnitude
	if length < 0.1 then
		return
	end
	local color = shot.color or BEAM_COLOR -- the shooter's zap colour from the Cred shop
	local core = beamPart(from, shot.to, 0.3, Color3.new(1, 1, 1):Lerp(color, 0.5), 0)
	beamPart(from, shot.to, 0.7, color, 0.55)
	Sounds.at("Zap", core)
	Particles.burst(from, {
		{ preset = "Flash", count = 1, color = color, scale = 0.25 },
		{ preset = "Sparks", count = 6, color = color, scale = 0.35 },
	})
	Particles.burst(shot.to, {
		{ preset = "Sparks", count = 12, color = color, scale = 0.5 },
		{ preset = "Flash", count = 1, color = color, scale = 0.35 },
	})
	local style = STYLES[shot.design or "Zapper"] or STYLES.Zapper
	style(from, shot.to, color)
end

-- Spinning stars over a stunned cop or player.
local function showStars(model: Model, seconds: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Stars"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local stars = UI.label({ Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "* * *" }, gui)
	gui.Adornee = head
	gui.Parent = player:WaitForChild("PlayerGui")
	Sounds.at("Stun", head)
	-- Real little stars twinkling round their head too.
	local halo = Instance.new("Attachment")
	halo.Name = "StunStars"
	halo.Position = Vector3.new(0, 1.4, 0)
	halo.Parent = head
	local twinkle = Particles.keep(halo, "Stars", 10, Color3.fromRGB(255, 230, 90), 0.5)
	twinkle.SpreadAngle = Vector2.new(180, 15)
	twinkle.Speed = NumberRange.new(1.5, 2.5)
	Debris:AddItem(halo, seconds)
	TweenService
		:Create(
			stars,
			TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 15 }
		)
		:Play()
	Debris:AddItem(gui, seconds)
end

-- Zapped: sit down (fall over) until the stars clear, then get back up.
local function watchStun(character: Model)
	character:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if character:GetAttribute(STUN_ATTRIBUTE) then
			humanoid.PlatformStand = true
		else
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function BlasterController.start()
	local remotes = Remotes.match()
	local mouse = player:GetMouse()

	local fireButton = if TouchButtons.enabled()
		then TouchButtons.add("", "FIRE", 3, function()
			fire(screenCentreTarget())
		end)
		else nil
	if fireButton then
		fireButton.button.Visible = false
	end

	local function onEquipped(tool: Tool)
		equipped = tool
		tool.Activated:Connect(function()
			if equipped == tool then
				fire(mouse.Hit.Position)
			end
		end)
		if fireButton then
			fireButton.button.Visible = true
		end
	end
	local function onUnequipped()
		equipped = nil
		if fireButton then
			fireButton.button.Visible = false
		end
	end

	local function watchCharacter(character: Model)
		onUnequipped()
		watchStun(character)
		character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") and child.Name == TOOL_NAME then
				onEquipped(child)
			end
		end)
		character.ChildRemoved:Connect(function(child: Instance)
			if child == equipped then
				onUnequipped()
			end
		end)
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	remotes.BlasterFx:onClient(function(shot: Types.BlasterFx)
		drawShot(shot)
		local hit = shot.hit
		if hit and hit.Parent and shot.stunSeconds > 0 then
			showStars(hit, shot.stunSeconds)
		end
	end)
end

return BlasterController
