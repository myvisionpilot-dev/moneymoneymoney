--!strict
-- Little 3D models of things you can buy (a bag, a padlock, a race car, an energy drink...), built
-- from parts and shown in a ViewportFrame: the shops' item pictures. They can turn slowly on the
-- spot, like on a turntable, and wear a cosmetic (a race car in its paint or underglow, a blaster
-- in its zap colour). The bags come from shared/BagLooks, and the server builds the bag you
-- wear in a run from these too.

local RunService = game:GetService("RunService")

local BagLooks = require(script.Parent.BagLooks)
local BlasterLooks = require(script.Parent.BlasterLooks)
local Cosmetics = require(script.Parent.Cosmetics)

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

-- role: "body" or "trim" (repainted by a paint), "glow" (recoloured by a zap).
type Piece = BlasterLooks.Piece

local BLACK = Color3.fromRGB(28, 28, 32)
local STEEL = Color3.fromRGB(170, 175, 185)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

local GLASS = Color3.fromRGB(35, 40, 55)

-- A little race car like the ones the garage lends you (VehicleModels' sedan): painted body
-- and roof, glass cabin, bumpers, lights, wheels with hubcaps.
local function raceCar(): { Piece }
	local red = Color3.fromRGB(225, 60, 60)
	local pieces: { Piece } = {
		{ size = Vector3.new(2.2, 0.95, 4.4), at = CFrame.new(0, 0.73, 0), color = red, role = "body" },
		{ size = Vector3.new(2, 0.75, 2.05), at = CFrame.new(0, 1.56, 0.3), color = GLASS, transparency = 0.15 },
		{ size = Vector3.new(2.1, 0.1, 2.15), at = CFrame.new(0, 1.96, 0.3), color = red, role = "body" },
		{
			size = Vector3.new(2, 0.75, 0.45),
			at = CFrame.new(0, 1.56, -0.95),
			color = GLASS,
			transparency = 0.15,
			shape = Enum.PartType.Wedge,
		},
		{
			size = Vector3.new(2, 0.75, 0.37),
			at = CFrame.new(0, 1.56, 1.51) * CFrame.Angles(0, math.pi, 0),
			color = GLASS,
			transparency = 0.15,
			shape = Enum.PartType.Wedge,
		},
		{ size = Vector3.new(1.25, 0.26, 0.04), at = CFrame.new(0, 0.65, -2.21), color = BLACK },
	}
	for _, z in { -2.25, 2.25 } do
		table.insert(
			pieces,
			{ size = Vector3.new(2.3, 0.26, 0.18), at = CFrame.new(0, 0.44, z), color = BLACK, role = "trim" }
		)
	end
	for _, side in { -1, 1 } do
		table.insert(pieces, {
			size = Vector3.new(0.45, 0.18, 0.05),
			at = CFrame.new(side * 0.76, 0.96, -2.215),
			color = Color3.fromRGB(255, 244, 200),
			material = Enum.Material.Neon,
		})
		table.insert(pieces, {
			size = Vector3.new(0.45, 0.16, 0.05),
			at = CFrame.new(side * 0.76, 0.96, 2.215),
			color = Color3.fromRGB(230, 30, 40),
			material = Enum.Material.Neon,
		})
		for _, z in { -1.4, 1.4 } do
			table.insert(pieces, {
				size = Vector3.new(0.37, 0.82, 0.82),
				at = CFrame.new(side * 1.15, 0.41, z),
				color = BLACK,
				shape = Enum.PartType.Cylinder,
			})
			table.insert(pieces, {
				size = Vector3.new(0.4, 0.45, 0.45),
				at = CFrame.new(side * 1.15, 0.41, z),
				color = STEEL,
				material = Enum.Material.Metal,
				shape = Enum.PartType.Cylinder,
			})
		end
	end
	return pieces
end

local MODELS: { [string]: { Piece } } = {
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
	RaceCar = raceCar(),
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
	Speed = { -- a running shoe (the lobby's speed buff)
		{ size = Vector3.new(1.2, 0.5, 2.6), at = CFrame.identity, color = Color3.fromRGB(240, 240, 240) },
		{ size = Vector3.new(1.15, 0.8, 1.4), at = CFrame.new(0, 0.6, 0.55), color = Color3.fromRGB(230, 70, 60) },
		{ size = Vector3.new(1.15, 0.45, 1.2), at = CFrame.new(0, 0.4, -0.7), color = Color3.fromRGB(230, 70, 60) },
		{ size = Vector3.new(1.25, 0.15, 2.7), at = CFrame.new(0, -0.3, 0), color = BLACK },
	},
}

local GREEN = Color3.fromRGB(80, 180, 90)
local GOLD = Color3.fromRGB(240, 195, 60)
local WOOD = Color3.fromRGB(150, 100, 60)

-- The rest of the Cred shop's pictures: upgrades and unlocks.
local MORE: { [string]: { Piece } } = {
	Cash = { -- a banded stack of bills
		{ size = Vector3.new(2.6, 0.18, 1.3), at = CFrame.identity, color = GREEN },
		{
			size = Vector3.new(2.6, 0.18, 1.3),
			at = CFrame.new(0.1, 0.2, 0.05) * CFrame.Angles(0, 0.12, 0),
			color = Color3.fromRGB(100, 200, 110),
		},
		{
			size = Vector3.new(2.6, 0.18, 1.3),
			at = CFrame.new(-0.05, 0.4, -0.05) * CFrame.Angles(0, -0.08, 0),
			color = GREEN,
		},
		{ size = Vector3.new(0.5, 0.62, 1.36), at = CFrame.new(0, 0.2, 0), color = Color3.fromRGB(245, 240, 220) },
	},
	Mower = { -- a push mower: honest work
		{ size = Vector3.new(2.2, 0.6, 2.4), at = CFrame.identity, color = Color3.fromRGB(210, 50, 45) },
		{ size = Vector3.new(1, 0.7, 1), at = CFrame.new(0, 0.65, -0.2), color = BLACK },
		{
			size = Vector3.new(0.3, 0.8, 0.8),
			at = CFrame.new(-1.2, -0.3, -0.9),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 0.8, 0.8),
			at = CFrame.new(1.2, -0.3, -0.9),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 0.8, 0.8),
			at = CFrame.new(-1.2, -0.3, 0.9),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 0.8, 0.8),
			at = CFrame.new(1.2, -0.3, 0.9),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.15, 2.4, 0.15),
			at = CFrame.new(-0.7, 1.2, 1.6) * CFrame.Angles(-0.5, 0, 0),
			color = STEEL,
		},
		{
			size = Vector3.new(0.15, 2.4, 0.15),
			at = CFrame.new(0.7, 1.2, 1.6) * CFrame.Angles(-0.5, 0, 0),
			color = STEEL,
		},
		{ size = Vector3.new(1.6, 0.2, 0.2), at = CFrame.new(0, 2.25, 2.15), color = BLACK },
	},
	Mask = { -- a robber's eye mask
		{ size = Vector3.new(2.8, 0.8, 0.3), at = CFrame.identity, color = BLACK },
		{ size = Vector3.new(0.6, 0.3, 0.1), at = CFrame.new(-0.65, 0.05, -0.16), color = Color3.new(1, 1, 1) },
		{ size = Vector3.new(0.6, 0.3, 0.1), at = CFrame.new(0.65, 0.05, -0.16), color = Color3.new(1, 1, 1) },
		{
			size = Vector3.new(0.8, 0.15, 0.15),
			at = CFrame.new(-1.7, 0.1, 0.1) * CFrame.Angles(0, 0, 0.3),
			color = BLACK,
		},
		{
			size = Vector3.new(0.8, 0.15, 0.15),
			at = CFrame.new(1.7, 0.1, 0.1) * CFrame.Angles(0, 0, -0.3),
			color = BLACK,
		},
	},
	Gavel = { -- a judge's gavel on its block
		{
			size = Vector3.new(1.8, 0.8, 0.8),
			at = CFrame.new(0, 0.6, 0),
			color = WOOD,
			material = Enum.Material.Wood,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.25, 0.25, 2.4),
			at = CFrame.new(0, 0.6, 1.4),
			color = Color3.fromRGB(120, 80, 45),
			material = Enum.Material.Wood,
		},
		{
			size = Vector3.new(0.4, 1.8, 1.8),
			at = CFrame.new(0, -0.4, 0.3) * UP,
			color = Color3.fromRGB(110, 70, 40),
			material = Enum.Material.Wood,
			shape = Enum.PartType.Cylinder,
		},
	},
	Shield = { -- a shield with a gold rim
		{ size = Vector3.new(2, 2.4, 0.3), at = CFrame.identity, color = Color3.fromRGB(50, 110, 220) },
		{
			size = Vector3.new(1.4, 1.4, 0.3),
			at = CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(45)),
			color = Color3.fromRGB(50, 110, 220),
		},
		{
			size = Vector3.new(2.2, 0.25, 0.35),
			at = CFrame.new(0, 1.2, 0),
			color = GOLD,
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(0.3, 1.6, 0.35),
			at = CFrame.new(0, 0, -0.05),
			color = GOLD,
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(1.4, 0.3, 0.35),
			at = CFrame.new(0, 0.3, -0.05),
			color = GOLD,
			material = Enum.Material.Metal,
		},
	},
	Tag = { -- a price tag on a string
		{ size = Vector3.new(1.6, 2.2, 0.15), at = CFrame.identity, color = Color3.fromRGB(255, 205, 60) },
		{
			size = Vector3.new(1.14, 1.14, 0.15),
			at = CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(45)),
			color = Color3.fromRGB(255, 205, 60),
		},
		{
			size = Vector3.new(0.2, 0.3, 0.3),
			at = CFrame.new(0, 1.3, -0.05) * CFrame.Angles(0, math.rad(90), 0),
			color = BLACK,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.1, 1.4, 0.1),
			at = CFrame.new(0.3, 2.1, 0) * CFrame.Angles(0, 0, -0.4),
			color = Color3.fromRGB(240, 240, 240),
		},
		{ size = Vector3.new(0.9, 0.2, 0.05), at = CFrame.new(0, -0.2, -0.1), color = Color3.fromRGB(200, 60, 50) },
	},
	Coins = { -- a stack of gold coins
		{
			size = Vector3.new(0.3, 1.6, 1.6),
			at = CFrame.new(0, 0, 0) * UP,
			color = GOLD,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 1.6, 1.6),
			at = CFrame.new(0.05, 0.32, 0.03) * UP,
			color = GOLD,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 1.6, 1.6),
			at = CFrame.new(-0.04, 0.64, -0.02) * UP,
			color = GOLD,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 1.6, 1.6),
			at = CFrame.new(0.03, 0.96, 0.04) * UP,
			color = GOLD,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(0.3, 1.6, 1.6),
			at = CFrame.new(1.6, 0.3, -0.4) * CFrame.Angles(0, 0.4, 0.5),
			color = GOLD,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
	},
	Cards = { -- four cards fanned out: more choices
		{
			size = Vector3.new(1.2, 1.8, 0.05),
			at = CFrame.new(-0.9, 0, 0.15) * CFrame.Angles(0, 0, 0.45),
			color = Color3.fromRGB(230, 70, 70),
		},
		{
			size = Vector3.new(1.2, 1.8, 0.05),
			at = CFrame.new(-0.3, 0.15, 0.05) * CFrame.Angles(0, 0, 0.15),
			color = Color3.fromRGB(70, 140, 235),
		},
		{
			size = Vector3.new(1.2, 1.8, 0.05),
			at = CFrame.new(0.3, 0.15, -0.05) * CFrame.Angles(0, 0, -0.15),
			color = Color3.fromRGB(80, 190, 90),
		},
		{
			size = Vector3.new(1.2, 1.8, 0.05),
			at = CFrame.new(0.9, 0, -0.15) * CFrame.Angles(0, 0, -0.45),
			color = Color3.fromRGB(170, 100, 240),
		},
	},
}
for id, pieces in MORE do
	MODELS[id] = pieces
end
-- Tony's blasters and the custom ones (shared/BlasterLooks).
for _, id in BlasterLooks.designs() do
	MODELS[id] = BlasterLooks.pieces(id) :: { Piece }
end
-- The bags (shared/BagLooks).
for _, id in BagLooks.designs() do
	MODELS[id] = BagLooks.pieces(id) :: { Piece }
end

function ItemModels.has(id: string): boolean
	return MODELS[id] ~= nil
end

-- Dresses a built model in a cosmetic: a paint repaints the body and trim, an underglow adds a
-- neon slab underneath (tagged RainbowGlow when it cycles), a zap colour recolours the glow.
local function dress(model: Model, look: Cosmetics.Item)
	if look.slot == "Paint" then
		Cosmetics.paint(model, look)
	elseif look.slot == "Glow" then
		local box, size = model:GetBoundingBox()
		local glow = Instance.new("Part")
		glow.Name = "Underglow"
		glow.Anchored = true
		glow.Size = Vector3.new(size.X * 0.8, 0.12, size.Z * 0.8)
		glow.CFrame = box * CFrame.new(0, -size.Y / 2 - 0.1, 0)
		glow.Color = look.color
		glow.Material = Enum.Material.Neon
		if look.rainbow then
			glow:AddTag("RainbowGlow")
		end
		glow.Parent = model
	elseif look.slot == "Zap" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Role") == "glow" then
				part.Color = look.color
				if look.rainbow then
					part:AddTag("RainbowGlow")
				end
			end
		end
	end
end

-- The picture as a Model (anchored, at the origin), optionally wearing a cosmetic. Nil for an
-- unknown id.
function ItemModels.model(id: string, look: Cosmetics.Item?): Model?
	local pieces = MODELS[id]
	if not pieces then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	for _, piece in pieces do
		local part = Instance.new("Part")
		part.Name = piece.name or "Part"
		part.Anchored = true
		part.Shape = piece.shape or Enum.PartType.Block
		part.Size = piece.size
		part.CFrame = piece.at
		part.Color = piece.color
		part.Material = piece.material or Enum.Material.SmoothPlastic
		part.Reflectance = piece.reflectance or 0
		part.Transparency = piece.transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if piece.role then
			part:SetAttribute("Role", piece.role)
		end
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity -- the origin the pieces were laid out from
	if look then
		dress(model, look)
	end
	return model
end

-- A ViewportFrame showing the item from a three-quarter angle (empty for an unknown id);
-- `spin` turns it slowly, `look` dresses it in a cosmetic.
function ItemModels.viewport(
	id: string,
	props: { [string]: any }?,
	parent: Instance?,
	spin: boolean?,
	look: Cosmetics.Item?
): ViewportFrame
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
	local model = ItemModels.model(id, look)
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
