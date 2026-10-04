--!strict
-- Drives the physics car you're sitting in. server/CarBuilder built it and gave your computer
-- its physics, so there's no input lag. Roblox fills in the seat's throttle and steering from
-- W/S/A/D, a gamepad's triggers and stick, or the touch stick; we add the handbrake (Space,
-- gamepad X/A, or the DRIFT button) and, every physics step, set the motors, steering, grip
-- and helper forces. The tuning is all in Config.Car.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))

local HANDBRAKE_ACTION = "Handbrake"
local FLIP_ACTION = "FlipCar"
local CORNERS = { "FL", "FR", "RL", "RR" }
local AXLES = { { "FL", "FR" }, { "RL", "RR" } }
local AXLE_SIGN = 1 -- a positive axle speed rolls the car forward (CarBuilder's axles point left)
local STEER_SIGN = -1 -- steering right (positive input) turns the wheels right
local GROUND_REACH = 0.8 -- studs below a wheel that still count as on the ground
local AIRBORNE_SECONDS = 0.15
local TIPPED = 0.3 -- the car's up vector this close to flat (or worse) counts as tipped over
local STOPPED = 4 -- studs/s
local GRIP_DROP_SECONDS = 0.08 -- the handbrake bites quickly; grip comes back over GripReturnSeconds

local settings = Config.Car
local player = Players.LocalPlayer

type Rig = {
	model: Model,
	hull: BasePart,
	seat: VehicleSeat,
	axles: { [string]: HingeConstraint },
	steers: { HingeConstraint },
	springs: { [string]: SpringConstraint },
	rolls: { [string]: VectorForce },
	wheels: { [string]: BasePart },
	downforce: VectorForce,
	radius: number,
	wheelbase: number,
	mass: number,
	params: RaycastParams,
}

local CarController = {}

local rig: Rig? = nil
local waitingSeat: VehicleSeat? = nil -- seated, but the car hasn't fully arrived yet
local handbrake = false
local steerAngle = 0
local rearGrip = settings.RearFriction
local appliedGrip = settings.RearFriction
local airborneFor = 0
local tippedFor = 0
local lastSpeed = 0 -- along the ground, last step (for DriftSlowdown)
local flipHinted = false
local driftButton: TouchButtons.TouchButton? = nil
local flipButton: TouchButtons.TouchButton? = nil

local function child(parent: Instance?, name: string): Instance?
	return if parent then parent:FindFirstChild(name) else nil
end

local function rigFor(seat: VehicleSeat): Rig?
	local model = seat.Parent
	if not model or not model:IsA("Model") or not model:GetAttribute("PhysicsCar") then
		return nil
	end
	local hull = model.PrimaryPart
	local downforce = child(hull, "Downforce")
	if not hull or not downforce or not downforce:IsA("VectorForce") then
		return nil
	end
	local axles, springs, rolls, wheels = {}, {}, {}, {}
	local steers = {}
	local mass = hull.AssemblyMass -- the body, the weight and you
	for _, corner in CORNERS do
		local wheel = model:FindFirstChild(`Wheel{corner}`)
		local axle = child(wheel, `Axle{corner}`)
		local strut = model:FindFirstChild(`Strut{corner}`)
		local spring = child(strut, `Spring{corner}`)
		local roll = hull:FindFirstChild(`Roll{corner}`)
		if
			not wheel
			or not wheel:IsA("BasePart")
			or not axle
			or not axle:IsA("HingeConstraint")
			or not strut
			or not strut:IsA("BasePart")
			or not spring
			or not spring:IsA("SpringConstraint")
			or not roll
			or not roll:IsA("VectorForce")
		then
			return nil
		end
		wheels[corner], axles[corner], springs[corner], rolls[corner] = wheel, axle, spring, roll
		mass += wheel:GetMass() + strut:GetMass()
		local knuckle = model:FindFirstChild(`Knuckle{corner}`)
		local steer = child(knuckle, `Steer{corner}`)
		if knuckle and knuckle:IsA("BasePart") and steer and steer:IsA("HingeConstraint") then
			table.insert(steers, steer)
			mass += knuckle:GetMass()
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { model, player.Character } else { model }
	return {
		model = model,
		hull = hull,
		seat = seat,
		axles = axles,
		steers = steers,
		springs = springs,
		rolls = rolls,
		wheels = wheels,
		downforce = downforce,
		radius = wheels.FL.Size.Y / 2,
		wheelbase = math.max(math.abs((wheels.FL.Position - wheels.RL.Position):Dot(hull.CFrame.LookVector)), 1),
		mass = mass,
		params = params,
	}
end

-- Moves `current` toward `target`, most of the way in about `seconds`.
local function smooth(current: number, target: number, seconds: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-dt * 3 / math.max(seconds, 1e-3)))
end

local function setAxle(axle: HingeConstraint, speed: number, torque: number)
	axle.AngularVelocity = speed * AXLE_SIGN
	axle.MotorMaxTorque = torque
end

local function power(car: Rig, speed: number, throttle: number, top: number)
	local r = car.radius
	local perWheel = car.mass * r / 2 -- torque on one wheel of a pair for 1 stud/s² of push
	local frontSpeed, frontTorque = 0, 0 -- free to roll
	local rearSpeed, rearTorque = 0, perWheel * settings.EngineBraking -- coasting
	local brakeFront = perWheel * settings.Braking * settings.FrontBrakeShare
	local brakeRear = perWheel * settings.Braking * (1 - settings.FrontBrakeShare)
	if top <= 0 then
		frontTorque, rearTorque = brakeFront, brakeRear -- engine locked (a race countdown)
	elseif (throttle > 0.05 and speed > -STOPPED) or (throttle < -0.05 and speed < STOPPED) then
		-- Driving the way you're pushing: strong off the line, fading toward the top.
		local reversing = throttle < 0
		local cap = if reversing then top * settings.ReverseShare else top
		local fade = math.max(settings.MinTorqueShare, 1 - math.min(math.abs(speed) / cap, 1) ^ settings.TorqueFade)
		rearSpeed = (if reversing then -cap else cap) / r
		rearTorque = perWheel * settings.Acceleration * fade * math.abs(throttle)
	elseif math.abs(throttle) > 0.05 then
		-- Pushing against the way you're rolling: brakes, more at the front.
		frontTorque = brakeFront * math.abs(throttle)
		rearTorque = brakeRear * math.abs(throttle)
	end
	if handbrake and top > 0 then
		if throttle > 0.05 then
			rearTorque *= settings.DriftThrottle -- keep some power to hold the slide
		else
			rearSpeed, rearTorque = 0, perWheel * settings.Braking * settings.DriftBrake
		end
	end
	setAxle(car.axles.FL, frontSpeed, frontTorque)
	setAxle(car.axles.FR, frontSpeed, frontTorque)
	setAxle(car.axles.RL, rearSpeed, rearTorque)
	setAxle(car.axles.RR, rearSpeed, rearTorque)
end

local function updateGrip(car: Rig, dt: number)
	local target = if handbrake then settings.DriftFriction else settings.RearFriction
	local seconds = if target < rearGrip then GRIP_DROP_SECONDS else settings.GripReturnSeconds
	rearGrip = smooth(rearGrip, target, seconds, dt)
	if math.abs(rearGrip - appliedGrip) > 0.02 or (rearGrip ~= appliedGrip and rearGrip == target) then
		appliedGrip = rearGrip
		local grip = PhysicalProperties.new(settings.WheelDensity, rearGrip, 0, 100, 100)
		car.wheels.RL.CustomPhysicalProperties = grip
		car.wheels.RR.CustomPhysicalProperties = grip
	end
end

-- Pushes up the side that's squashed more and down the other, so it barely leans.
local function antiRoll(car: Rig, up: Vector3)
	for _, pair in AXLES do
		local left, right = car.springs[pair[1]], car.springs[pair[2]]
		local push = settings.AntiRoll * left.Stiffness * (right.CurrentLength - left.CurrentLength)
		car.rolls[pair[1]].Force = up * push
		car.rolls[pair[2]].Force = -up * push
	end
end

local function step(car: Rig, dt: number)
	local hull = car.hull
	local cframe = hull.CFrame
	local up = cframe.UpVector
	local velocity = hull.AssemblyLinearVelocity
	local speed = velocity:Dot(cframe.LookVector)
	local topValue = car.model:GetAttribute("TopSpeed")
	local top = if typeof(topValue) == "number" then topValue else 0
	local share = if top > 0 then math.clamp(math.abs(speed) / top, 0, 1) else 0
	local throttle, steer = car.seat.ThrottleFloat, car.seat.SteerFloat

	power(car, speed, throttle, top)
	updateGrip(car, dt)
	antiRoll(car, up)

	-- How sideways we're sliding (radians, + = moving to the left of where the nose points),
	-- and how far into a drift the back end is (0 = full grip, 1 = handbrake grip).
	local sliding = velocity - up * velocity:Dot(up)
	local slip = 0
	if speed > STOPPED * 3 then
		local direction = sliding.Unit
		slip = math.atan2(cframe.LookVector:Cross(direction):Dot(up), cframe.LookVector:Dot(direction))
	end
	local gripRange = settings.RearFriction - settings.DriftFriction
	local drift = if gripRange > 0 then 1 - math.clamp((rearGrip - settings.DriftFriction) / gripRange, 0, 1) else 0

	-- Steering tightens as you speed up (35° parked, 8° flat out) and never asks for more grip
	-- than CornerGrip, so going into a corner hot pushes wide instead of snapping round. In a
	-- drift the front wheels follow the slide by themselves and your steering nudges it.
	local maxAngle = settings.SteerAngleSlow + (settings.SteerAngleFast - settings.SteerAngleSlow) * share
	if speed * speed > 1 then
		local gripAngle = math.deg(math.atan(car.wheelbase * settings.CornerGrip / (speed * speed)))
		maxAngle = math.min(maxAngle, gripAngle)
	end
	local driving = steer * maxAngle
	local drifting = steer * settings.DriftSteer - math.deg(slip) * settings.CounterSteer
	steerAngle = smooth(steerAngle, driving + (drifting - driving) * drift, settings.SteerSeconds, dt)
	for _, hinge in car.steers do
		hinge.TargetAngle = steerAngle * STEER_SIGN
	end

	local grounded = 0
	for _, wheel in car.wheels do
		if workspace:Raycast(wheel.Position, -up * (car.radius + GROUND_REACH), car.params) then
			grounded += 1
		end
	end
	car.downforce.Force = if grounded > 0
		then Vector3.new(0, -settings.Downforce * car.mass * workspace.Gravity * share * share, 0)
		else Vector3.zero

	-- In the air: calm the spin and tip back level, so it lands on its wheels.
	airborneFor = if grounded == 0 then airborneFor + dt else 0
	local spin = hull.AssemblyAngularVelocity
	local previousSpeed = lastSpeed
	lastSpeed = sliding.Magnitude
	if airborneFor > AIRBORNE_SECONDS then
		local target = up:Cross(Vector3.yAxis) * settings.AirLevelling + Vector3.yAxis * spin.Y
		spin = spin:Lerp(target, 1 - math.exp(-settings.AirSpinDamping * dt))
		hull.AssemblyAngularVelocity = spin
	elseif grounded >= 3 then
		-- On the road it turns at the rate its front wheels ask for, so bumps and the looser
		-- back end don't knock it off line. Drifting fades this out.
		local wanted = -speed * math.tan(math.rad(steerAngle)) / car.wheelbase
		local blend = (1 - math.exp(-settings.YawAssist * dt)) * (1 - drift)
		spin += up * (wanted - spin:Dot(up)) * blend
		-- Past DriftMaxAngle the nose is turned back toward where you're going: no spinning out.
		local excess = math.abs(slip) - math.rad(settings.DriftMaxAngle)
		if excess > 0 then
			spin += up * (math.sign(slip) * excess / math.max(dt, 1e-3) * settings.DriftCatch)
		end
		hull.AssemblyAngularVelocity = spin
		-- Drifting on the throttle keeps most of its speed (an arcade slide, not a skid).
		local floor = previousSpeed - settings.DriftSlowdown * dt
		if drift > 0.5 and throttle > 0.05 and lastSpeed > STOPPED * 3 and lastSpeed < floor then
			hull.AssemblyLinearVelocity = velocity + sliding.Unit * (floor - lastSpeed)
			lastSpeed = floor
		end
	end
	if spin.Magnitude > settings.MaxSpin then
		hull.AssemblyAngularVelocity = spin.Unit * settings.MaxSpin
	end

	local tipped = up.Y < TIPPED and velocity.Magnitude < STOPPED
	tippedFor = if tipped then tippedFor + dt else 0
	local canFlip = tippedFor >= settings.FlipAfterSeconds
	if flipButton then
		flipButton.button.Visible = canFlip
	end
	if canFlip and not flipHinted then
		Toasts.show("Stuck? Press F (or tap FLIP) to put your car back on its wheels.", "Info")
	end
	flipHinted = canFlip
end

local function flip()
	local car = rig
	if not car or tippedFor < settings.FlipAfterSeconds then
		return
	end
	local pivot = car.model:GetPivot()
	local look = pivot.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = pivot.UpVector * Vector3.new(1, 0, 1) -- nose pointing straight up or down
	end
	local facing = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local position = pivot.Position + Vector3.new(0, 3, 0)
	car.model:PivotTo(CFrame.lookAt(position, position + facing))
	for _, part in car.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	tippedFor = 0
end

local function onHandbrake(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	handbrake = state ~= Enum.UserInputState.End and state ~= Enum.UserInputState.Cancel
	return Enum.ContextActionResult.Sink -- and Space doesn't jump you out of the seat
end

local function onFlip(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		flip()
	end
	return Enum.ContextActionResult.Sink
end

local function begin(car: Rig)
	rig = car
	handbrake, steerAngle, airborneFor, tippedFor, flipHinted, lastSpeed = false, 0, 0, 0, false, 0
	rearGrip, appliedGrip = settings.RearFriction, settings.RearFriction
	local high = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(
		HANDBRAKE_ACTION,
		onHandbrake,
		false,
		high,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonX,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindActionAtPriority(FLIP_ACTION, onFlip, false, high, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	if driftButton then
		driftButton.button.Visible = true
	end
end

local function finish()
	rig = nil
	handbrake = false
	ContextActionService:UnbindAction(HANDBRAKE_ACTION)
	ContextActionService:UnbindAction(FLIP_ACTION)
	if driftButton then
		driftButton.button.Visible = false
	end
	if flipButton then
		flipButton.button.Visible = false
	end
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local function refresh()
		local seat = humanoid.SeatPart
		if rig then
			finish()
		end
		waitingSeat = if seat and seat:IsA("VehicleSeat") then seat else nil
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refresh)
	refresh()
end

function CarController.start()
	if TouchButtons.enabled() then
		local drift = TouchButtons.add("💨", "DRIFT", 4, function() end)
		drift.button.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				handbrake = true
			end
		end)
		drift.button.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				handbrake = false
			end
		end)
		drift.button.Visible = false
		driftButton = drift
		local flipper = TouchButtons.add("🔄", "FLIP", 5, flip)
		flipper.button.Visible = false
		flipButton = flipper
	end

	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		if rig then
			finish()
		end
		waitingSeat = nil
		watchCharacter(character)
	end)

	RunService.Stepped:Connect(function(_time: number, dt: number)
		local seat = waitingSeat
		if seat then
			-- The seat can arrive before the rest of the car; keep looking until it's all here.
			local ready = rigFor(seat)
			if ready then
				waitingSeat = nil
				begin(ready)
			end
		end
		local car = rig
		if not car then
			return
		end
		if not car.model.Parent or not car.hull.Parent then
			finish()
			return
		end
		step(car, dt)
	end)
end

return CarController
