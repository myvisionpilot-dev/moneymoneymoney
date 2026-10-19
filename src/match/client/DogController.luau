--!strict
-- Brings the dogs to life (server/Dogs moves them; this moves their joints on this screen): legs
-- trot or gallop with how fast they go, the tail wags, ears flop, the head sniffs about or looks
-- up, the jaw opens to bark and pant. Their DogState picks the body: Idle, Trot, Run, Sniff,
-- Sit, Beg, Lie, Pull (straining at the leash), Poop, Carry (ball in mouth), Charge (a guard
-- dog). Also lets a leash sag when it's slack and pulls it straight when it's tight.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DOG_TAG = "Dog"
local DOWN = Vector3.new(0, -1, 0)
local UP = Vector3.new(0, 1, 0)
local ACROSS = Vector3.new(1, 0, 0)
local HAPPY: { [string]: boolean } = { Idle = true, Trot = true, Run = true, Sit = true, Beg = true, Carry = true }

type Dog = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	tongue: BasePart?,
	scale: number,
	phase: number,
	speed: number,
	last: Vector3,
	barkStarted: number,
	clock: number,
	settle: { [string]: CFrame }, -- each joint's last pose, so state changes ease over
}

local DogController = {}

local dogs: { [Model]: Dog } = {}

local function r(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function add(model: Instance)
	if not model:IsA("Model") or dogs[model] then
		return
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints: { [string]: Motor6D } = {}
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") then
			joints[joint.Name] = joint
		end
	end
	local tongue = model:FindFirstChild("Tongue", true)
	local scale = model:GetAttribute("DogScale")
	local dog: Dog = {
		model = model,
		root = root,
		joints = joints,
		tongue = if tongue and tongue:IsA("BasePart") then tongue else nil,
		scale = if typeof(scale) == "number" then scale else 1,
		phase = math.random() * 6,
		speed = 0,
		last = root.Position,
		barkStarted = 0,
		clock = math.random() * 10,
		settle = {},
	}
	model:GetAttributeChangedSignal("BarkAt"):Connect(function()
		dog.barkStarted = os.clock()
	end)
	dogs[model] = dog
end

-- What each joint should be doing right now.
local function posed(dog: Dog, state: string): { [string]: CFrame }
	local t = dog.clock
	local speed = dog.speed
	local s = dog.scale
	local pose: { [string]: CFrame } = {}
	local galloping = speed > 20 or state == "Charge"
	local moving = speed > 1.5 or state == "Pull"
	local amp = if state == "Pull" then 28 else math.clamp(speed / 14, 0, 1) * (if galloping then 50 else 34)
	local swing = math.sin(dog.phase)

	-- Legs and body.
	if state == "Sit" or state == "Beg" then
		local up = if state == "Beg" then 40 else 25
		pose.Spine = CFrame.new(0, -0.1 * s, 0) * r(up, 0, 0)
		pose.FrontLeft = r(if state == "Beg" then 70 else -up, 0, 0)
		pose.FrontRight = r(if state == "Beg" then 60 + 10 * math.sin(t * 8) else -up, 0, 0)
		pose.BackLeft = r(70, 0, 0)
		pose.BackRight = r(70, 0, 0)
	elseif state == "Lie" then
		pose.Spine = CFrame.new(0, -0.72 * s, 0)
		pose.FrontLeft = r(82, 0, 0)
		pose.FrontRight = r(82, 0, 0)
		pose.BackLeft = r(-82, 0, 0)
		pose.BackRight = r(-82, 0, 0)
	elseif state == "Poop" then
		pose.Spine = CFrame.new(0, -0.05 * s, 0) * r(18, 0, 1.5 * math.sin(t * 30))
		pose.FrontLeft = r(-18, 0, 0)
		pose.FrontRight = r(-18, 0, 0)
		pose.BackLeft = r(35, 0, 0)
		pose.BackRight = r(35, 0, 0)
	elseif moving then
		local bob = if galloping then math.abs(swing) * 0.16 else math.abs(swing) * 0.07
		local lean = if state == "Pull" then -8 else (if galloping then 6 * swing else 0)
		pose.Spine = CFrame.new(0, bob * s, 0) * r(lean, 0, 0)
		if galloping then
			pose.FrontLeft = r(swing * amp, 0, 0)
			pose.FrontRight = r(math.sin(dog.phase + 0.4) * amp, 0, 0)
			pose.BackLeft = r(-swing * amp, 0, 0)
			pose.BackRight = r(-math.sin(dog.phase + 0.4) * amp, 0, 0)
		else
			pose.FrontLeft = r(swing * amp, 0, 0)
			pose.BackRight = r(swing * amp, 0, 0)
			pose.FrontRight = r(-swing * amp, 0, 0)
			pose.BackLeft = r(-swing * amp, 0, 0)
		end
	else
		pose.Spine = CFrame.new(0, math.sin(t * 2) * 0.02 * s, 0) -- breathing
		pose.FrontLeft = CFrame.identity
		pose.FrontRight = CFrame.identity
		pose.BackLeft = CFrame.identity
		pose.BackRight = CFrame.identity
	end

	-- Head.
	local barking = os.clock() - dog.barkStarted < 0.3
	if state == "Sniff" then
		pose.Neck = r(-35 + 5 * math.sin(t * 6), 20 * math.sin(t * 1.7), 0)
	elseif state == "Pull" then
		pose.Neck = r(12, 0, 0)
	elseif state == "Charge" then
		pose.Neck = r(-6, 0, 0)
	elseif state == "Sit" or state == "Beg" then
		pose.Neck = r(10, 0, 10 * math.sin(t * 1.3))
	elseif state == "Lie" then
		pose.Neck = r(-22, 15 * math.sin(t * 0.4), 0)
	elseif state == "Idle" then
		pose.Neck = r(0, 25 * math.sin(t * 0.7), 0)
	else
		pose.Neck = r(2 * math.sin(dog.phase * 2), 0, 0)
	end
	if barking then
		pose.Neck = pose.Neck * r(10, 0, 0)
	end

	-- Jaw: barking, panting, or holding the ball.
	local panting = speed > 12 or state == "Pull" or state == "Charge" or state == "Beg"
	local jaw = 0
	if barking then
		jaw = -32
	elseif state == "Carry" then
		jaw = -14
	elseif panting then
		jaw = -14 + 5 * math.sin(t * 14)
	end
	pose.Jaw = r(jaw, 0, 0)
	local tongue = dog.tongue
	if tongue then
		tongue.Transparency = if panting and not barking and state ~= "Carry" then 0 else 1
	end

	-- Ears flop back when they run and bounce with each stride.
	local back = -math.clamp(speed / 30, 0, 1) * 40
	local bounce = 8 * math.sin(dog.phase * 2)
	pose.LeftEar = r(back + bounce, 0, 0)
	pose.RightEar = r(back - bounce, 0, 0)

	-- Tail.
	local wagSpeed, wagAmount = 16, 35
	if state == "Sniff" then
		wagSpeed, wagAmount = 8, 20
	elseif state == "Pull" then
		wagSpeed, wagAmount = 22, 14
	elseif state == "Lie" then
		wagSpeed, wagAmount = 4, 14
	elseif state == "Charge" or state == "Poop" then
		wagSpeed, wagAmount = 0, 0
	elseif not HAPPY[state] then
		wagSpeed, wagAmount = 10, 20
	end
	local lift = if state == "Poop" or state == "Pull" then -25 else 0
	pose.Tail = r(lift, wagAmount * math.sin(t * wagSpeed), 0)
	return pose
end

local function stepDog(dog: Dog, dt: number)
	local position = dog.root.Position
	local moved = Vector3.new(position.X - dog.last.X, 0, position.Z - dog.last.Z).Magnitude
	dog.last = position
	dog.speed += (moved / math.max(dt, 1e-3) - dog.speed) * math.min(1, dt * 10)
	dog.clock += dt
	local state = dog.model:GetAttribute("DogState")
	local name = if typeof(state) == "string" then state else "Idle"
	local stride = 2.2 * dog.scale
	if name == "Pull" then
		dog.phase += dt * 14
	else
		dog.phase += dt * (dog.speed / stride) * math.pi * 2
	end
	local ease = math.min(1, dt * 12)
	for joint, target in posed(dog, name) do
		local motor = dog.joints[joint]
		if motor then
			local from = dog.settle[joint] or CFrame.identity
			local value = from:Lerp(target, ease)
			dog.settle[joint] = value
			motor.Transform = value
		end
	end
end

-- A leash: droops when slack, straight when tight.
local function stepLeash(beam: Beam)
	local a0, a1 = beam.Attachment0, beam.Attachment1
	if not a0 or not a1 then
		return
	end
	local length = beam:GetAttribute("LeashStuds")
	local full = if typeof(length) == "number" then length else 9
	local distance = (a1.WorldPosition - a0.WorldPosition).Magnitude
	local sag = if a1.Name == "LeashTrail" then 0.4 else math.clamp((full - distance) * 0.3, 0, 1.3)
	a0.WorldCFrame = CFrame.fromMatrix(a0.WorldPosition, DOWN, ACROSS)
	a1.WorldCFrame = CFrame.fromMatrix(a1.WorldPosition, UP, ACROSS)
	beam.CurveSize0 = sag
	beam.CurveSize1 = sag
end

function DogController.start()
	for _, model in CollectionService:GetTagged(DOG_TAG) do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal(DOG_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(DOG_TAG):Connect(function(model: Instance)
		if model:IsA("Model") then
			dogs[model] = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		for model, dog in dogs do
			if not model.Parent then
				dogs[model] = nil
			else
				stepDog(dog, dt)
				local leash = model:FindFirstChild("LeashLine")
				if leash and leash:IsA("Beam") then
					stepLeash(leash)
				end
			end
		end
	end)
end

return DogController
