--!strict
-- Grey-box vehicle bodies built from parts (no Creator Store models): a go-kart, a car and a
-- police car. Each model is built around its ground point, facing -Z, with Wheel1-4 (front
-- left, front right, back left, back right), an invisible Hull box inside the wheels and a
-- Seat: CarBuilder turns karts and cars into physics cars from those. Police cars are still
-- welded under their (humanoid) cop and never collide.

local VehicleModels = {}

local BLACK = Color3.fromRGB(25, 25, 30)

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model
	return part
end

-- Cylinders roll along X, so wheels need no rotation.
local function wheels(model: Model, radius: number, width: number, x: number, frontZ: number, backZ: number)
	for index, position in
		{
			Vector3.new(-x, radius, frontZ),
			Vector3.new(x, radius, frontZ),
			Vector3.new(-x, radius, backZ),
			Vector3.new(x, radius, backZ),
		}
	do
		piece(
			model,
			`Wheel{index}`,
			Vector3.new(width, radius * 2, radius * 2),
			position,
			BLACK,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
end

local function sideLabel(part: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(400, 80)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(35, 70, 160)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

function VehicleModels.kart(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Kart"
	piece(model, "Chassis", Vector3.new(4.2, 0.6, 7.2), Vector3.new(0, 0.8, -0.4), color)
	piece(model, "Hood", Vector3.new(4.2, 1.2, 2.2), Vector3.new(0, 1.5, -3.2), color)
	piece(model, "Seat", Vector3.new(3, 0.6, 2.4), Vector3.new(0, 1.4, 0.9), BLACK)
	piece(model, "SeatBack", Vector3.new(3.2, 2, 0.6), Vector3.new(0, 2.1, 2.2), BLACK)
	piece(model, "Hull", Vector3.new(3.4, 1.2, 6.8), Vector3.new(0, 1.25, -0.4), color).Transparency = 1
	wheels(model, 0.8, 0.8, 2.5, -2.6, 2)
	model.WorldPivot = CFrame.identity
	return model
end

-- A plain sedan: lower and upper body, glass cabin, headlights, wheels.
local function sedan(name: string, lowerColor: Color3, upperColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	piece(model, "Lower", Vector3.new(6, 1.4, 12), Vector3.new(0, 1.4, 0), lowerColor)
	piece(model, "Upper", Vector3.new(6, 1.2, 12), Vector3.new(0, 2.7, 0), upperColor)
	local cabin = piece(
		model,
		"Cabin",
		Vector3.new(5.4, 2, 5.6),
		Vector3.new(0, 4.3, 0.8),
		Color3.fromRGB(35, 40, 55),
		Enum.Material.Glass
	)
	cabin.Transparency = 0.15
	piece(model, "Hull", Vector3.new(4.8, 2.4, 11.6), Vector3.new(0, 2.1, 0), lowerColor).Transparency = 1
	piece(model, "Seat", Vector3.new(2.4, 0.4, 2.2), Vector3.new(0, 1.6, 0.9), BLACK).Transparency = 1
	for index, x in { -2, 2 } do
		piece(
			model,
			`Headlight{index}`,
			Vector3.new(1.2, 0.5, 0.2),
			Vector3.new(x, 2.6, -6.05),
			Color3.fromRGB(255, 240, 180),
			Enum.Material.Neon
		)
	end
	wheels(model, 1.1, 1, 3.1, -3.8, 3.8)
	model.WorldPivot = CFrame.identity
	return model
end

-- A parked or stolen car.
function VehicleModels.car(color: Color3): Model
	return sedan("Car", color, color)
end

-- A City Cabs taxi: yellow, with a TAXI sign on the roof.
function VehicleModels.taxi(): Model
	local yellow = Color3.fromRGB(255, 205, 40)
	local model = sedan("Taxi", yellow, yellow)
	local upper = model:FindFirstChild("Upper")
	if upper and upper:IsA("BasePart") then
		sideLabel(upper, Enum.NormalId.Left, "CITY CABS")
		sideLabel(upper, Enum.NormalId.Right, "CITY CABS")
	end
	local sign = piece(model, "RoofSign", Vector3.new(2.6, 0.9, 1), Vector3.new(0, 5.75, 0.8), Color3.new(1, 1, 1))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		sideLabel(sign, face, "TAXI")
	end
	return model
end

function VehicleModels.policeCar(): Model
	local model = sedan("PoliceCar", BLACK, Color3.fromRGB(240, 240, 240))
	local upper = model:FindFirstChild("Upper")
	if upper and upper:IsA("BasePart") then
		sideLabel(upper, Enum.NormalId.Left, "POLICE")
		sideLabel(upper, Enum.NormalId.Right, "POLICE")
	end
	local red = Color3.fromRGB(255, 40, 40)
	local blue = Color3.fromRGB(40, 90, 255)
	piece(model, "LightRed", Vector3.new(1.6, 0.5, 1), Vector3.new(-0.9, 5.55, 0.8), red, Enum.Material.Neon)
	piece(model, "LightBlue", Vector3.new(1.6, 0.5, 1), Vector3.new(0.9, 5.55, 0.8), blue, Enum.Material.Neon)
	return model
end

-- Welds a vehicle under a character: wheels on the ground, facing where the character faces.
function VehicleModels.attach(model: Model, root: BasePart, humanoid: Humanoid, parent: Instance)
	local drop = humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(root.CFrame * CFrame.new(0, -drop, 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = parent
end

return VehicleModels
