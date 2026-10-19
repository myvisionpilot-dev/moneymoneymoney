--!strict
-- The big moving things in town events (client), built here from parts and gliding after the
-- server's invisible markers: the CASH PARADE float (pink and gold, a giant spinning coin,
-- balloons, confetti and bills flying off it) and the MONEY TORNADO (a green twister of
-- spinning rings with bills whirling round it; standing in it shakes your screen a little).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Particles = require(Shared:WaitForChild("Particles"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local UI = require(Shared:WaitForChild("UI"))

local FOLLOW = 6 -- how quickly a prop catches up with its marker (higher: snappier)
local PINK = Color3.fromRGB(240, 90, 175)
local GOLD = Color3.fromRGB(255, 205, 60)
local TWISTER_LOW = Color3.fromRGB(70, 110, 75) -- dark at the bottom...
local TWISTER_HIGH = Color3.fromRGB(175, 225, 160) -- ...light at the top
local BILL_GREEN = Color3.fromRGB(96, 200, 96)
local RINGS = 14
local ORBITING_BILLS = 34
local TORNADO_HEIGHT = 50
local SWAY = 0.45 -- how far each ring up the funnel swings out (studs per ring)

type Prop = {
	marker: BasePart,
	model: Model,
	at: CFrame, -- where it's drawn now (it eases toward the marker)
	spinning: { { part: Part, offset: CFrame, speed: number, sway: number } },
	orbit: { { part: Part, radius: number, height: number, speed: number, phase: number } },
	tornado: boolean,
}

local EventPropsController = {}

local props: { [BasePart]: Prop } = {}
local lastShake = 0

local function part(model: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- The parade float, its pieces laid out from its middle on the ground (facing -Z).
local function buildFloat(prop: Prop)
	local model = prop.model
	local function fixed(p: Part, offset: CFrame)
		table.insert(prop.spinning, { part = p, offset = offset, speed = 0, sway = 0 })
	end
	fixed(part(model, "Deck", Vector3.new(10, 2.2, 16), PINK), CFrame.new(0, 1.6, 0))
	fixed(part(model, "Skirt", Vector3.new(10.4, 1.2, 16.4), GOLD), CFrame.new(0, 0.6, 0))
	for _, x in { -5, 5 } do
		fixed(part(model, "Rail", Vector3.new(0.4, 0.8, 16), GOLD), CFrame.new(x, 3.1, 0))
	end
	-- The giant coin, turning on a pole.
	fixed(part(model, "Pole", Vector3.new(0.6, 6, 0.6), GOLD), CFrame.new(0, 5.7, 2))
	local coin = part(model, "Coin", Vector3.new(0.8, 7, 7), GOLD, Enum.PartType.Cylinder)
	coin.Material = Enum.Material.Metal
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Right
	face.LightInfluence = 0
	face.CanvasSize = Vector2.new(200, 200)
	local sign = UI.label({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 245, 200),
		Text = "$",
	}, face)
	UI.textStroke(sign, 6)
	face.Parent = coin
	local back = face:Clone()
	back.Face = Enum.NormalId.Left
	back.Parent = coin
	table.insert(prop.spinning, { part = coin, offset = CFrame.new(0, 10, 2), speed = 1.6, sway = 0 })
	-- Money stacks and balloons.
	for index, spot in
		{ Vector3.new(-3, 3.2, -5), Vector3.new(3, 3.2, -5), Vector3.new(-3, 3.2, 6), Vector3.new(3, 3.2, 6) }
	do
		fixed(part(model, "Stack", Vector3.new(2, 1.6, 1.2), BILL_GREEN), CFrame.new(spot))
		local balloon = part(
			model,
			"Balloon",
			Vector3.new(2.4, 2.4, 2.4),
			UI.Colors.Info:Lerp(PINK, (index - 1) / 3),
			Enum.PartType.Ball
		)
		balloon.Material = Enum.Material.Glass
		fixed(balloon, CFrame.new(spot + Vector3.new(0, 7 + index % 2, 0)))
		fixed(
			part(model, "String", Vector3.new(0.08, 6, 0.08), Color3.new(1, 1, 1)),
			CFrame.new(spot + Vector3.new(0, 4, 0))
		)
	end
	local deck = model:FindFirstChild("Deck") :: BasePart
	Particles.keep(deck, "Confetti", 18, nil, 1.4)
	Particles.keep(deck, "Bills", 10, nil, 1.3)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 22
	light.Brightness = 2
	light.Parent = coin
end

-- The twister: thin rings widening toward the top, each spinning and swaying out of line so
-- the funnel twists, dark at the bottom and light at the top, with bills whirling round.
local function buildTornado(prop: Prop)
	local model = prop.model
	for index = 1, RINGS do
		local t = (index - 1) / (RINGS - 1)
		local width = 5 + t * t * 30
		local color = TWISTER_LOW:Lerp(TWISTER_HIGH, t)
		local ring = part(model, "Ring", Vector3.new(2, width, width), color, Enum.PartType.Cylinder)
		ring.Transparency = 0.3 + t * 0.35
		ring.Material = Enum.Material.Neon
		local offset = CFrame.new(0, 1.5 + t * TORNADO_HEIGHT, 0) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(prop.spinning, { part = ring, offset = offset, speed = 5 - t * 3, sway = index * SWAY })
		if index % 3 == 1 then
			Particles.keep(ring, "Vortex", 4, color, 2 + t * 3)
		end
	end
	local base = model:FindFirstChild("Ring") :: BasePart
	Particles.keep(base, "Smoke", 14, Color3.fromRGB(150, 170, 140), 3)
	Particles.keep(base, "Bills", 10, nil, 1.6)
	for _ = 1, ORBITING_BILLS do
		local bill = part(model, "Bill", Vector3.new(2.2, 0.08, 1.1), BILL_GREEN)
		table.insert(prop.orbit, {
			part = bill,
			radius = math.random(3, 14),
			height = math.random(2, TORNADO_HEIGHT),
			speed = 2 + math.random() * 3,
			phase = math.random() * math.pi * 2,
		})
	end
end

local function add(marker: Instance, tornado: boolean)
	if not marker:IsA("BasePart") or props[marker] then
		return
	end
	local model = Instance.new("Model")
	model.Name = if tornado then "MoneyTornadoFx" else "ParadeFloatFx"
	local prop: Prop = {
		marker = marker,
		model = model,
		at = marker.CFrame,
		spinning = {},
		orbit = {},
		tornado = tornado,
	}
	if tornado then
		buildTornado(prop)
	else
		buildFloat(prop)
	end
	model.Parent = workspace
	props[marker] = prop
end

local function remove(marker: Instance)
	if not marker:IsA("BasePart") then
		return
	end
	local prop = props[marker]
	if prop then
		props[marker] = nil
		prop.model:Destroy()
	end
end

function EventPropsController.start()
	for _, kind in { { tag = "ParadeFloat", tornado = false }, { tag = "MoneyTornado", tornado = true } } do
		for _, marker in CollectionService:GetTagged(kind.tag) do
			add(marker, kind.tornado)
		end
		CollectionService:GetInstanceAddedSignal(kind.tag):Connect(function(marker: Instance)
			add(marker, kind.tornado)
		end)
		CollectionService:GetInstanceRemovedSignal(kind.tag):Connect(remove)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local clock = os.clock()
		local alpha = 1 - math.exp(-dt * FOLLOW)
		local character = Players.LocalPlayer.Character
		local me = character and character:GetPivot().Position
		for marker, prop in props do
			prop.at = prop.at:Lerp(marker.CFrame, alpha)
			local base = if prop.tornado then CFrame.new(prop.at.Position) else prop.at
			for _, entry in prop.spinning do
				local spin = if entry.speed ~= 0 then CFrame.Angles(0, clock * entry.speed, 0) else CFrame.identity
				local sway = if entry.sway ~= 0
					then CFrame.new(
						math.sin(clock * 1.7 + entry.sway) * entry.sway,
						0,
						math.cos(clock * 1.3 + entry.sway) * entry.sway
					)
					else CFrame.identity
				entry.part.CFrame = base * sway * spin * entry.offset
			end
			for _, entry in prop.orbit do
				local angle = clock * entry.speed + entry.phase
				local spot = base.Position
					+ Vector3.new(math.cos(angle) * entry.radius, entry.height, math.sin(angle) * entry.radius)
				entry.part.CFrame = CFrame.new(spot) * CFrame.Angles(angle, angle * 2, 0)
			end
			-- Standing in the twister rattles the camera.
			if prop.tornado and me then
				local radius = marker:GetAttribute("Radius")
				local offset = me - prop.at.Position
				local inside = Vector3.new(offset.X, 0, offset.Z).Magnitude
					<= (if typeof(radius) == "number" then radius else 12)
				if inside and clock - lastShake > 0.5 then
					lastShake = clock
					ScreenFx.shake(0.18, 0.4)
				end
			end
		end
	end)
end

return EventPropsController
