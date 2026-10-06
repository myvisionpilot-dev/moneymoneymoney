--!strict
-- Little 3D models of things you can buy (a bag, a padlock, a kart, an energy drink...), built
-- from parts and shown in a ViewportFrame: the shops' item pictures (client only). They can
-- turn slowly on the spot, like on a turntable.

local RunService = game:GetService("RunService")

local SPIN_SPEED = 0.7 -- radians a second

local ItemModels = {}

type Turntable = { camera: Camera, center: Vector3, across: number, height: number, angle: number }
local turning: { [ViewportFrame]: Turntable } = setmetatable({}, { __mode = "k" }) :: any

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(dt: number)
		for view, spin in turning do
			if view.Parent and view.Visible then
				spin.angle += dt * SPIN_SPEED
				local offset =
					Vector3.new(math.sin(spin.angle) * spin.across, spin.height, math.cos(spin.angle) * spin.across)
				spin.camera.CFrame = CFrame.lookAt(spin.center + offset, spin.center)
			end
		end
	end)
end

type Piece = {
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
}

local BLACK = Color3.fromRGB(28, 28, 32)
local STEEL = Color3.fromRGB(170, 175, 185)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

local function blaster(glow: Color3): { Piece }
	return {
		{ size = Vector3.new(0.7, 0.8, 2.2), at = CFrame.identity, color = Color3.fromRGB(60, 60, 75) },
		{
			size = Vector3.new(0.45, 0.45, 1),
			at = CFrame.new(0, 0.1, -1.5),
			color = glow,
			material = Enum.Material.Neon,
		},
		{ size = Vector3.new(0.15, 0.5, 1.2), at = CFrame.new(0, 0.6, 0), color = glow, material = Enum.Material.Neon },
		{ size = Vector3.new(0.5, 1, 0.5), at = CFrame.new(0, -0.8, 0.5), color = Color3.fromRGB(60, 60, 75) },
	}
end

local MODELS: { [string]: { Piece } } = {
	Bag = { -- a duffel bag
		{
			size = Vector3.new(3, 1.6, 1.6),
			at = CFrame.identity,
			color = Color3.fromRGB(150, 90, 50),
			material = Enum.Material.Fabric,
		},
		{ size = Vector3.new(3.05, 0.2, 0.3), at = CFrame.new(0, 0.8, 0), color = BLACK },
		{ size = Vector3.new(0.25, 0.9, 0.25), at = CFrame.new(-0.7, 1.2, 0), color = BLACK },
		{ size = Vector3.new(0.25, 0.9, 0.25), at = CFrame.new(0.7, 1.2, 0), color = BLACK },
		{ size = Vector3.new(1.65, 0.25, 0.25), at = CFrame.new(0, 1.6, 0), color = BLACK },
	},
	Lockpick = { -- a padlock with two picks
		{
			size = Vector3.new(1.6, 1.4, 0.6),
			at = CFrame.identity,
			color = Color3.fromRGB(230, 180, 60),
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(0.25, 0.9, 0.25),
			at = CFrame.new(-0.5, 1.1, 0),
			color = STEEL,
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(0.25, 0.9, 0.25),
			at = CFrame.new(0.5, 1.1, 0),
			color = STEEL,
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(1.25, 0.25, 0.25),
			at = CFrame.new(0, 1.55, 0),
			color = STEEL,
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(0.12, 2.2, 0.12),
			at = CFrame.new(0.9, -0.4, 0.4) * CFrame.Angles(0, 0, math.rad(35)),
			color = STEEL,
		},
		{
			size = Vector3.new(0.12, 2.2, 0.12),
			at = CFrame.new(1.1, -0.3, 0.4) * CFrame.Angles(0, 0, math.rad(55)),
			color = STEEL,
		},
	},
	Ride = { -- a go-kart
		{ size = Vector3.new(2.2, 0.4, 3.6), at = CFrame.identity, color = Color3.fromRGB(225, 60, 60) },
		{ size = Vector3.new(2.2, 0.7, 1), at = CFrame.new(0, 0.5, -1.4), color = Color3.fromRGB(225, 60, 60) },
		{ size = Vector3.new(1.4, 1, 0.3), at = CFrame.new(0, 0.7, 1.1), color = BLACK },
		{
			size = Vector3.new(0.4, 0.9, 0.9),
			at = CFrame.new(-1.3, -0.1, -1.2),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.4, 0.9, 0.9),
			at = CFrame.new(1.3, -0.1, -1.2),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.4, 0.9, 0.9),
			at = CFrame.new(-1.3, -0.1, 1.2),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.4, 0.9, 0.9),
			at = CFrame.new(1.3, -0.1, 1.2),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
	},
	Energy = { -- a can
		{
			size = Vector3.new(2.4, 1.3, 1.3),
			at = UP,
			color = STEEL,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(1.2, 1.34, 1.34),
			at = UP,
			color = Color3.fromRGB(80, 230, 90),
			material = Enum.Material.Neon,
			shape = Enum.PartType.Cylinder,
		},
	},
	Disguise = { -- a cap and sunglasses
		{
			size = Vector3.new(0.7, 1.8, 1.8),
			at = UP,
			color = Color3.fromRGB(50, 60, 80),
			shape = Enum.PartType.Cylinder,
		},
		{ size = Vector3.new(1.6, 0.15, 1), at = CFrame.new(0, -0.3, -1.1), color = Color3.fromRGB(50, 60, 80) },
		{ size = Vector3.new(0.7, 0.4, 0.15), at = CFrame.new(-0.45, -0.85, -0.9), color = BLACK },
		{ size = Vector3.new(0.7, 0.4, 0.15), at = CFrame.new(0.45, -0.85, -0.9), color = BLACK },
		{ size = Vector3.new(0.3, 0.1, 0.1), at = CFrame.new(0, -0.8, -0.9), color = BLACK },
	},
	Candy = { -- a wrapped chocolate bar
		{ size = Vector3.new(2.6, 0.5, 1.2), at = CFrame.identity, color = Color3.fromRGB(110, 60, 35) },
		{ size = Vector3.new(1.6, 0.55, 1.25), at = CFrame.identity, color = Color3.fromRGB(240, 80, 140) },
		{ size = Vector3.new(0.3, 0.4, 1.4), at = CFrame.new(-1.45, 0, 0), color = Color3.fromRGB(240, 80, 140) },
		{ size = Vector3.new(0.3, 0.4, 1.4), at = CFrame.new(1.45, 0, 0), color = Color3.fromRGB(240, 80, 140) },
	},
	Gloves = { -- a pair of gloves
		{
			size = Vector3.new(1, 1.2, 0.4),
			at = CFrame.new(-0.7, 0, 0),
			color = BLACK,
			material = Enum.Material.Fabric,
		},
		{
			size = Vector3.new(0.9, 0.7, 0.35),
			at = CFrame.new(-0.7, 0.9, 0),
			color = BLACK,
			material = Enum.Material.Fabric,
		},
		{
			size = Vector3.new(0.3, 0.6, 0.35),
			at = CFrame.new(-1.3, 0.2, 0) * CFrame.Angles(0, 0, math.rad(30)),
			color = BLACK,
		},
		{
			size = Vector3.new(1, 1.2, 0.4),
			at = CFrame.new(0.7, -0.2, 0.3),
			color = BLACK,
			material = Enum.Material.Fabric,
		},
		{
			size = Vector3.new(0.9, 0.7, 0.35),
			at = CFrame.new(0.7, 0.7, 0.3),
			color = BLACK,
			material = Enum.Material.Fabric,
		},
		{
			size = Vector3.new(0.3, 0.6, 0.35),
			at = CFrame.new(1.3, 0, 0.3) * CFrame.Angles(0, 0, math.rad(-30)),
			color = BLACK,
		},
	},
	Scanner = { -- a police radio
		{ size = Vector3.new(1.1, 1.9, 0.6), at = CFrame.identity, color = Color3.fromRGB(45, 45, 52) },
		{
			size = Vector3.new(0.8, 0.5, 0.05),
			at = CFrame.new(0, 0.45, -0.3),
			color = Color3.fromRGB(90, 230, 120),
			material = Enum.Material.Neon,
		},
		{
			size = Vector3.new(1.4, 0.15, 0.15),
			at = CFrame.new(-0.3, 1.6, 0) * UP,
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{ size = Vector3.new(0.3, 0.3, 0.3), at = CFrame.new(0.3, 1.05, 0), color = Color3.fromRGB(220, 60, 60) },
	},
	Zapper = blaster(Color3.fromRGB(60, 220, 255)),
	MegaZapper = blaster(Color3.fromRGB(255, 110, 220)),
	Speed = { -- a running shoe (the lobby's speed buff)
		{ size = Vector3.new(1.2, 0.5, 2.6), at = CFrame.identity, color = Color3.fromRGB(240, 240, 240) },
		{ size = Vector3.new(1.15, 0.8, 1.4), at = CFrame.new(0, 0.6, 0.55), color = Color3.fromRGB(230, 70, 60) },
		{ size = Vector3.new(1.15, 0.45, 1.2), at = CFrame.new(0, 0.4, -0.7), color = Color3.fromRGB(230, 70, 60) },
		{ size = Vector3.new(1.25, 0.15, 2.7), at = CFrame.new(0, -0.3, 0), color = BLACK },
	},
}

function ItemModels.has(id: string): boolean
	return MODELS[id] ~= nil
end

local function build(id: string): Model?
	local pieces = MODELS[id]
	if not pieces then
		return nil
	end
	local model = Instance.new("Model")
	for _, piece in pieces do
		local part = Instance.new("Part")
		part.Anchored = true
		part.Shape = piece.shape or Enum.PartType.Block
		part.Size = piece.size
		part.CFrame = piece.at
		part.Color = piece.color
		part.Material = piece.material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	return model
end

-- A ViewportFrame showing the item from a three-quarter angle (empty for an unknown id);
-- `spin` turns it slowly.
function ItemModels.viewport(id: string, props: { [string]: any }?, parent: Instance?, spin: boolean?): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(170, 170, 180)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -2, -1)
	if props then
		for key, value in props do
			(view :: any)[key] = value
		end
	end
	local model = build(id)
	if model then
		model.Parent = view
		local box, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		local distance = size.Magnitude / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 0.9
		local direction = Vector3.new(1.1, 0.7, -1.3).Unit * distance
		camera.CFrame = CFrame.lookAt(box.Position + direction, box.Position)
		camera.Parent = view
		view.CurrentCamera = camera
		if spin then
			turning[view] = {
				camera = camera,
				center = box.Position,
				across = Vector2.new(direction.X, direction.Z).Magnitude,
				height = direction.Y,
				angle = math.atan2(direction.X, direction.Z),
			}
		end
	end
	view.Parent = parent
	return view
end

return ItemModels
