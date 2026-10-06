--!strict
-- Vehicle bodies built from parts (no Creator Store models): a go-kart, a sedan (parked,
-- stolen, taxi, police) and the armoured truck. Each model is built around its ground point,
-- facing -Z, with Wheel1-4 (front left, front right, back left, back right), an invisible Hull
-- box inside the wheels and a Seat: CarBuilder turns karts and cars into physics cars from those.
-- Hubcaps are named WheelCap* and welded to their wheel, so they bounce and steer with it.
-- Painted panels carry the Paint attribute (CarFlip's respray). Police cars are still welded
-- under their (humanoid) cop and never collide.

local VehicleModels = {}

local BLACK = Color3.fromRGB(25, 25, 30)
local TRIM = Color3.fromRGB(45, 45, 52)
local CHROME = Color3.fromRGB(200, 205, 212)
local GLASS = Color3.fromRGB(35, 40, 55)
local HEADLIGHT = Color3.fromRGB(255, 244, 200)
local TAILLIGHT = Color3.fromRGB(230, 30, 40)

local function setup(
	part: BasePart,
	model: Model,
	name: string,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	part.Name = name
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model
end

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	position: Vector3 | CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	setup(part, model, name, if typeof(position) == "CFrame" then position else CFrame.new(position), color, material)
	return part
end

-- A sloped piece: full height at its back (+Z), down to nothing at its front.
local function wedge(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Size = size
	setup(part, model, name, cframe, color, material)
	return part
end

local function paint(part: BasePart): BasePart
	part:SetAttribute("Paint", true)
	return part
end

-- Tyres with silver hubcaps. Cylinders roll along X, so they need no rotation.
local function wheels(model: Model, radius: number, width: number, x: number, frontZ: number, backZ: number)
	for index, position in
		{
			Vector3.new(-x, radius, frontZ),
			Vector3.new(x, radius, frontZ),
			Vector3.new(-x, radius, backZ),
			Vector3.new(x, radius, backZ),
		}
	do
		local wheel = piece(
			model,
			`Wheel{index}`,
			Vector3.new(width, radius * 2, radius * 2),
			position,
			BLACK,
			nil,
			Enum.PartType.Cylinder
		)
		local cap = piece(
			model,
			`WheelCap{index}`,
			Vector3.new(width + 0.06, radius * 1.1, radius * 1.1),
			position,
			CHROME,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = wheel
		weld.Part1 = cap
		weld.Parent = cap
	end
end

local function sideLabel(part: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(400, 80)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(35, 70, 160)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

function VehicleModels.kart(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Kart"
	piece(model, "Chassis", Vector3.new(3.6, 0.35, 7), Vector3.new(0, 0.75, -0.3), TRIM, Enum.Material.Metal)
	paint(piece(model, "Hood", Vector3.new(2.6, 0.9, 2.6), Vector3.new(0, 1.35, -2.9), color))
	paint(wedge(model, "Nose", Vector3.new(2.6, 0.9, 1.2), CFrame.new(0, 1.35, -4.8), color))
	for _, side in { -1, 1 } do
		paint(piece(model, "SidePod", Vector3.new(0.9, 0.7, 2.4), Vector3.new(side * 1.85, 1.25, 0), color))
	end
	piece(model, "FrontBar", Vector3.new(4.4, 0.3, 0.3), Vector3.new(0, 0.95, -5.55), BLACK, Enum.Material.Metal)
	piece(model, "RearBar", Vector3.new(4.4, 0.3, 0.3), Vector3.new(0, 0.95, 3.75), BLACK, Enum.Material.Metal)
	piece(
		model,
		"Column",
		Vector3.new(0.2, 0.2, 1.4),
		CFrame.new(0, 1.85, -1.3) * CFrame.Angles(math.rad(-35), 0, 0),
		TRIM
	)
	piece(
		model,
		"SteeringWheel",
		Vector3.new(0.15, 1, 1),
		CFrame.new(0, 2.2, -0.75) * CFrame.Angles(math.rad(-35), math.rad(90), 0),
		BLACK,
		nil,
		Enum.PartType.Cylinder
	)
	piece(model, "Seat", Vector3.new(3, 0.6, 2.4), Vector3.new(0, 1.4, 0.9), BLACK)
	piece(model, "SeatBack", Vector3.new(2.8, 1.9, 0.5), Vector3.new(0, 2.15, 2.15), BLACK, Enum.Material.Fabric)
	piece(model, "Engine", Vector3.new(2, 1, 1.1), Vector3.new(0, 1.45, 3), CHROME, Enum.Material.DiamondPlate)
	for _, x in { -0.55, 0.55 } do
		piece(
			model,
			"Exhaust",
			Vector3.new(1.2, 0.3, 0.3),
			CFrame.new(x, 1.5, 3.9) * CFrame.Angles(0, math.rad(90), 0),
			CHROME,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	piece(model, "Hull", Vector3.new(3.4, 1.2, 6.8), Vector3.new(0, 1.25, -0.4), color).Transparency = 1
	wheels(model, 0.8, 1, 2.4, -2.6, 2)
	model.WorldPivot = CFrame.identity
	return model
end

-- A sedan: lower and upper body, a glass cabin with pillars and a roof, a raked windscreen and
-- rear window, bumpers, grille, lights, plates, mirrors, door handles and hubcaps. The body's
-- outside matches CarDirt's patches.
local function sedan(name: string, lowerColor: Color3, upperColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	paint(piece(model, "Lower", Vector3.new(6, 1.4, 12), Vector3.new(0, 1.4, 0), lowerColor))
	paint(piece(model, "Upper", Vector3.new(6, 1.2, 12), Vector3.new(0, 2.7, 0), upperColor))
	local cabin = piece(model, "Cabin", Vector3.new(5.4, 2, 5.6), Vector3.new(0, 4.3, 0.8), GLASS, Enum.Material.Glass)
	cabin.Transparency = 0.15
	paint(piece(model, "Roof", Vector3.new(5.7, 0.25, 5.9), Vector3.new(0, 5.425, 0.8), upperColor))
	for _, side in { -1, 1 } do
		for _, z in { -1.94, 0.8, 3.54 } do
			paint(piece(model, "Pillar", Vector3.new(0.3, 2, 0.36), Vector3.new(side * 2.67, 4.3, z), upperColor))
		end
		paint(piece(model, "Mirror", Vector3.new(0.8, 0.4, 0.35), Vector3.new(side * 3.05, 3.6, -1.7), upperColor))
		for _, z in { -0.6, 1.8 } do
			piece(
				model,
				"Handle",
				Vector3.new(0.08, 0.15, 0.5),
				Vector3.new(side * 3.03, 2.85, z),
				TRIM,
				Enum.Material.Metal
			)
		end
		piece(
			model,
			"Headlight",
			Vector3.new(1.2, 0.5, 0.15),
			Vector3.new(side * 2.05, 2.6, -6.05),
			HEADLIGHT,
			Enum.Material.Neon
		).Name =
			`Headlight{if side < 0 then 1 else 2}`
		piece(
			model,
			"TailLight",
			Vector3.new(1.2, 0.45, 0.15),
			Vector3.new(side * 2.05, 2.6, 6.05),
			TAILLIGHT,
			Enum.Material.Neon
		)
	end
	local windscreen =
		wedge(model, "Windscreen", Vector3.new(5.4, 2, 1.2), CFrame.new(0, 4.3, -2.6), GLASS, Enum.Material.Glass)
	windscreen.Transparency = 0.15
	local rear = wedge(
		model,
		"RearWindow",
		Vector3.new(5.4, 2, 1),
		CFrame.new(0, 4.3, 4.1) * CFrame.Angles(0, math.pi, 0),
		GLASS,
		Enum.Material.Glass
	)
	rear.Transparency = 0.15
	for _, z in { -6.1, 6.1 } do
		piece(model, "Bumper", Vector3.new(6.2, 0.7, 0.5), Vector3.new(0, 1.2, z), TRIM)
		piece(
			model,
			"Plate",
			Vector3.new(1.4, 0.45, 0.06),
			Vector3.new(0, 1.2, z + math.sign(z) * 0.28),
			Color3.new(1, 1, 1)
		)
	end
	piece(model, "Grille", Vector3.new(3.4, 0.7, 0.1), Vector3.new(0, 1.75, -6.04), BLACK)
	piece(model, "Hull", Vector3.new(4.8, 2.4, 11.6), Vector3.new(0, 2.1, 0), lowerColor).Transparency = 1
	piece(model, "Seat", Vector3.new(2.4, 0.4, 2.2), Vector3.new(0, 1.6, 0.9), BLACK).Transparency = 1
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
	local sign = piece(model, "RoofSign", Vector3.new(2.6, 0.9, 1), Vector3.new(0, 6, 0.8), Color3.new(1, 1, 1))
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
	piece(model, "LightBase", Vector3.new(3.6, 0.3, 1.1), Vector3.new(0, 5.7, 0.8), TRIM)
	piece(
		model,
		"LightRed",
		Vector3.new(1.6, 0.45, 0.9),
		Vector3.new(-0.9, 6.075, 0.8),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	piece(
		model,
		"LightBlue",
		Vector3.new(1.6, 0.45, 0.9),
		Vector3.new(0.9, 6.075, 0.8),
		Color3.fromRGB(40, 90, 255),
		Enum.Material.Neon
	)
	piece(model, "PushBar", Vector3.new(4, 1.2, 0.3), Vector3.new(0, 1.7, -6.55), BLACK, Enum.Material.Metal)
	return model
end

-- The armoured cash truck (a town event): a grey box van with SECURE CASH on the sides and
-- BackDoors to crack open.
function VehicleModels.armouredTruck(): Model
	local grey = Color3.fromRGB(95, 100, 108)
	local model = Instance.new("Model")
	model.Name = "ArmouredTruck"
	piece(model, "Lower", Vector3.new(7, 1.6, 16), Vector3.new(0, 1.6, 0), BLACK)
	local box =
		piece(model, "Box", Vector3.new(7, 6.5, 10.5), Vector3.new(0, 5.65, 2.5), grey, Enum.Material.DiamondPlate)
	sideLabel(box, Enum.NormalId.Left, "SECURE CASH", Color3.fromRGB(240, 200, 60))
	sideLabel(box, Enum.NormalId.Right, "SECURE CASH", Color3.fromRGB(240, 200, 60))
	piece(model, "Cab", Vector3.new(7, 4.5, 5.2), Vector3.new(0, 4.65, -5.2), grey)
	local windscreen =
		piece(model, "Windscreen", Vector3.new(6.4, 2, 0.2), Vector3.new(0, 5.6, -7.85), GLASS, Enum.Material.Glass)
	windscreen.Transparency = 0.15
	for _, side in { -1, 1 } do
		local window = piece(
			model,
			"SideWindow",
			Vector3.new(0.2, 1.6, 2.6),
			Vector3.new(side * 3.55, 5.7, -5.4),
			GLASS,
			Enum.Material.Glass
		)
		window.Transparency = 0.15
		piece(model, "Mirror", Vector3.new(0.5, 0.8, 0.4), Vector3.new(side * 3.8, 5.4, -7.3), TRIM)
		piece(
			model,
			"Headlight",
			Vector3.new(1.3, 0.6, 0.15),
			Vector3.new(side * 2.4, 3.2, -7.88),
			HEADLIGHT,
			Enum.Material.Neon
		)
		piece(
			model,
			"TailLight",
			Vector3.new(0.9, 0.5, 0.15),
			Vector3.new(side * 2.9, 2.15, 8.05),
			TAILLIGHT,
			Enum.Material.Neon
		)
	end
	piece(model, "Grille", Vector3.new(3.4, 1.4, 0.15), Vector3.new(0, 3.4, -7.88), BLACK)
	piece(model, "Bumper", Vector3.new(7.4, 0.9, 0.6), Vector3.new(0, 1.4, -8.2), TRIM, Enum.Material.Metal)
	piece(model, "Bumper", Vector3.new(7.4, 0.9, 0.6), Vector3.new(0, 1.4, 8.2), TRIM, Enum.Material.Metal)
	piece(
		model,
		"BackDoors",
		Vector3.new(6.4, 5.8, 0.4),
		Vector3.new(0, 5.6, 7.85),
		Color3.fromRGB(80, 85, 92),
		Enum.Material.DiamondPlate
	)
	wheels(model, 1.3, 1.2, 3.4, -5, 5)
	model.WorldPivot = CFrame.identity
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
