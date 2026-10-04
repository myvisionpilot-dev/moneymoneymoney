--!strict
-- Turns a body from VehicleModels into a physics car (no fake sliding): its Hull becomes the
-- solid, invisible frame everything else is welded to, a heavy plate under the floor keeps it
-- upright, and each wheel hangs on a slider and a spring. The back wheels are driven, the
-- front ones steer. client/CarController does the driving; the server only builds the car,
-- tunes the springs for its weight and hands it to the driver.
-- Corners are FL, FR, RL, RR: Wheel* (the ball that touches the road), Tyre* (the look),
-- Slide*, Spring*, Steer* (front), Axle*, Roll* (anti-roll).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local CollisionGroups = require(script.Parent.CollisionGroups)

local settings = Config.Car
local CORNERS = { "FL", "FR", "RL", "RR" } -- VehicleModels' Wheel1..Wheel4
local SPRING_LENGTH = 2 -- from a wheel's hub up to where its spring meets the hull
local HUB_SIZE = Vector3.new(0.6, 0.6, 0.6)
local HUB_DENSITY = 5 -- hubs light enough to bounce, heavy enough to keep the physics steady
local HULL_DENSITY = 0.4
local STEER_LIMIT = 45

local CarBuilder = {}

function CarBuilder.grip(friction: number): PhysicalProperties
	return PhysicalProperties.new(settings.WheelDensity, friction, 0, 100, 100)
end

local function attach(part: BasePart, name: string, world: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = part.CFrame:ToObjectSpace(world)
	attachment.Parent = part
	return attachment
end

local function weld(a: BasePart, b: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = a
	joint.Part1 = b
	joint.Parent = b
end

local function hub(model: Model, name: string, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = HUB_SIZE
	part.CFrame = cframe
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CustomPhysicalProperties = PhysicalProperties.new(HUB_DENSITY, 0.3, 0, 1, 1)
	part.Parent = model
	return part
end

-- One corner: hull -> slider + spring -> strut (-> steering knuckle) -> axle -> wheel.
local function corner(model: Model, hull: BasePart, wheel: BasePart, name: string, ground: CFrame)
	local front = name == "FL" or name == "FR"
	local radius = wheel.Size.Y / 2
	local center = wheel.Position
	-- Sliders and steering turn about the car's up axis; axles about its left axis.
	local vertical = CFrame.fromMatrix(center, ground.UpVector, ground.LookVector)
	local sideways = CFrame.fromMatrix(center, -ground.RightVector, ground.UpVector)

	local strut = hub(model, `Strut{name}`, vertical)
	local slide = Instance.new("PrismaticConstraint")
	slide.Name = `Slide{name}`
	slide.Attachment0 = attach(hull, `Slide{name}`, vertical)
	slide.Attachment1 = attach(strut, "Slide", vertical)
	slide.LimitsEnabled = true
	slide.UpperLimit = settings.SuspensionUp * radius
	slide.LowerLimit = -settings.SuspensionDown * radius
	slide.Restitution = 0
	slide.Parent = strut

	local top = attach(hull, `SpringTop{name}`, vertical + ground.UpVector * SPRING_LENGTH)
	local spring = Instance.new("SpringConstraint")
	spring.Name = `Spring{name}`
	spring.Attachment0 = top
	spring.Attachment1 = attach(strut, "Spring", vertical)
	spring.Parent = strut

	local roll = Instance.new("VectorForce")
	roll.Name = `Roll{name}`
	roll.Attachment0 = top
	roll.RelativeTo = Enum.ActuatorRelativeTo.World
	roll.ApplyAtCenterOfMass = false
	roll.Force = Vector3.zero
	roll.Parent = hull

	local carrier: BasePart = strut
	if front then
		local knuckle = hub(model, `Knuckle{name}`, vertical)
		local steer = Instance.new("HingeConstraint")
		steer.Name = `Steer{name}`
		steer.Attachment0 = attach(strut, "Steer", vertical)
		steer.Attachment1 = attach(knuckle, "Steer", vertical)
		steer.ActuatorType = Enum.ActuatorType.Servo
		steer.AngularSpeed = 20
		steer.AngularResponsiveness = 100
		steer.LimitsEnabled = true
		steer.LowerAngle = -STEER_LIMIT
		steer.UpperAngle = STEER_LIMIT
		steer.Parent = knuckle
		carrier = knuckle
	end

	-- The wheel you see is a cylinder riding on an invisible ball: balls roll smoothly over the
	-- seams between road parts, where a cylinder's edge can catch and kick the car sideways.
	local tyre = wheel
	tyre.Name = `Tyre{name}`
	local ball = Instance.new("Part")
	ball.Name = `Wheel{name}`
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	ball.CFrame = tyre.CFrame
	ball.Transparency = 1
	ball.CanTouch = false
	ball.CustomPhysicalProperties = CarBuilder.grip(if front then settings.FrontFriction else settings.RearFriction)
	ball.Parent = model
	weld(ball, tyre)
	local axle = Instance.new("HingeConstraint")
	axle.Name = `Axle{name}`
	axle.Attachment0 = attach(carrier, "Axle", sideways)
	axle.Attachment1 = attach(ball, "Axle", sideways)
	axle.ActuatorType = Enum.ActuatorType.Motor
	axle.MotorMaxTorque = 0 -- free to roll until CarController drives or brakes it
	axle.AngularVelocity = 0
	axle.Parent = ball

	local noRub = Instance.new("NoCollisionConstraint")
	noRub.Part0 = ball
	noRub.Part1 = hull
	noRub.Parent = ball
	model:SetAttribute("WheelRadius", radius)
end

-- Builds the car with its ground point at `ground`. The body must have Hull, Seat and Wheel1-4.
function CarBuilder.build(body: Model, ground: CFrame, topSpeed: number): Model?
	local hull = body:FindFirstChild("Hull")
	local seatMark = body:FindFirstChild("Seat")
	if not hull or not hull:IsA("BasePart") or not seatMark or not seatMark:IsA("BasePart") then
		return nil
	end
	body:PivotTo(ground)

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = seatMark.Size
	seat.CFrame = seatMark.CFrame
	seat.Color = seatMark.Color
	seat.Transparency = seatMark.Transparency
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0 -- the constraints do the driving, not the seat
	seat.Parent = body
	seatMark:Destroy()

	hull.Massless = false
	hull.CanCollide = true
	hull.CustomPhysicalProperties = PhysicalProperties.new(HULL_DENSITY, 0.3, 0, 1, 1)
	body.PrimaryPart = hull
	hull.PivotOffset = hull.CFrame:ToObjectSpace(ground) -- the car's pivot stays its ground point
	local ballast = hub(body, "Ballast", hull.CFrame * CFrame.new(0, -hull.Size.Y / 2 + 0.2, 0))
	ballast.Size = Vector3.new(hull.Size.X * 0.6, 0.3, hull.Size.Z * 0.5)
	ballast.CustomPhysicalProperties = PhysicalProperties.new(settings.BallastDensity, 0.3, 0, 1, 1)

	for _, descendant in body:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= hull and not descendant.Name:match("^Wheel") then
			if descendant ~= ballast then
				descendant.Massless = true
				descendant.CanCollide = false
			end
			descendant.CanTouch = false
			weld(hull, descendant)
		end
	end
	for index, name in CORNERS do
		local wheel = body:FindFirstChild(`Wheel{index}`)
		if wheel and wheel:IsA("BasePart") then
			corner(body, hull, wheel, name, ground)
		end
	end

	local center = attach(hull, "Center", hull.CFrame)
	local downforce = Instance.new("VectorForce")
	downforce.Name = "Downforce"
	downforce.Attachment0 = center
	downforce.RelativeTo = Enum.ActuatorRelativeTo.World
	downforce.ApplyAtCenterOfMass = true
	downforce.Force = Vector3.zero
	downforce.Parent = hull

	for _, descendant in body:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	body:SetAttribute("PhysicsCar", true)
	body:SetAttribute("TopSpeed", topSpeed)
	body:SetAttribute("HalfWidth", hull.Size.X / 2 + 1)
	body.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the driver needs every part at once
	CollisionGroups.car(body)
	return body
end

-- Springs that hold this car (plus its driver) at the height it was built at, bouncing at
-- Car.SuspensionHz. Call before the driver sits.
function CarBuilder.tune(car: Model, driverMass: number)
	local hull = car.PrimaryPart
	if not hull then
		return
	end
	local sprung = hull.AssemblyMass + driverMass
	local perCorner = sprung / 4
	local omega = 2 * math.pi * settings.SuspensionHz
	local stiffness = perCorner * omega * omega
	local damping = 2 * settings.DampingRatio * math.sqrt(stiffness * perCorner)
	local sag = perCorner * workspace.Gravity / stiffness
	local total = sprung
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("SpringConstraint") then
			descendant.Stiffness = stiffness
			descendant.Damping = damping
			descendant.FreeLength = SPRING_LENGTH + sag
		elseif descendant:IsA("HingeConstraint") and descendant.ActuatorType == Enum.ActuatorType.Servo then
			descendant.ServoMaxTorque = sprung * 2000
		elseif descendant:IsA("BasePart") and descendant.AssemblyRootPart ~= hull then
			total += descendant:GetMass()
		end
	end
	car:SetAttribute("Mass", total)
	car:SetAttribute("SpringStiffness", stiffness)
end

-- The driver's computer runs the car's physics from now on.
function CarBuilder.giveTo(car: Model, player: Player)
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("BasePart") then
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
end

return CarBuilder
