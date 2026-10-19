--!strict
-- Hand-keyed body animation for jobs (no animation assets), on every character and NPC rig on
-- this screen, layered over Roblox's walk. The server says what to show with attributes
-- (server/Gestures):
--   JobPose    how they hold what they carry: both hands on a box, pushing the mower, a letter
--              in one hand, the dog's leash, digging their heels in when the dog pulls
--   Working    the prompt they're holding (its ActionText): scrubbing, knocking, hammering,
--              flipping patties, crouching to pick something up...
--   Gesture    one-off moves: a throw, a cheer when they're paid, a resident's wave, handing
--              over the cash (restarted every time GestureAt changes)
-- Arm joints take the pose over (no swinging while you carry a box); the waist, neck and root
-- add to the walk. Joint angles are in degrees: +x swings a limb forward, z out to the side
-- (negative z out for the left arm). Also turns the wheels of anything pushed (mower, bin,
-- hot-dog cart), rattles the mower's engine and sprays grass, and puts bubbles on a scrubbing
-- sponge.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Particles = require(Shared:WaitForChild("Particles"))

type Pose = { [string]: CFrame }
type Joint = Motor6D | AnimationConstraint

local PROP_TAG = "JobProp"
local BLEND_IN = 9 -- weight per second
local ADDITIVE: { [string]: boolean } = { Root = true, Waist = true, Neck = true }
local REST = CFrame.new()

local function r(x: number, y: number, z: number, drop: number?): CFrame
	return CFrame.new(0, -(drop or 0), 0) * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Holding things -------------------------------------------------------------------------

local POSES: { [string]: Pose } = {
	Carry = {
		LeftShoulder = r(30, 0, 8),
		RightShoulder = r(30, 0, -8),
		LeftElbow = r(60, 0, 0),
		RightElbow = r(60, 0, 0),
		Waist = r(4, 0, 0),
	},
	Tray = {
		LeftShoulder = r(22, 0, 6),
		RightShoulder = r(22, 0, -6),
		LeftElbow = r(68, 0, 0),
		RightElbow = r(68, 0, 0),
		LeftWrist = r(-20, 0, 0),
		RightWrist = r(-20, 0, 0),
	},
	Push = {
		LeftShoulder = r(38, 0, 6),
		RightShoulder = r(38, 0, -6),
		LeftElbow = r(22, 0, 0),
		RightElbow = r(22, 0, 0),
		Waist = r(-10, 0, 0),
	},
	Hold = {
		RightShoulder = r(40, 0, -6),
		RightElbow = r(50, 0, 0),
	},
	Leash = {
		RightShoulder = r(28, 0, 14),
		RightElbow = r(30, 0, 0),
	},
	Tug = {
		RightShoulder = r(62, 0, 10),
		LeftShoulder = r(58, 0, 25),
		RightElbow = r(12, 0, 0),
		LeftElbow = r(18, 0, 0),
		Waist = r(16, 0, 0),
		Root = r(0, 0, 0, 0.25),
	},
}

-- Working (while a prompt is held) -------------------------------------------------------

local MOTIONS: { [string]: (t: number) -> Pose } = {
	Work = function(t)
		local s, c = math.sin(t * 10), math.cos(t * 10)
		return {
			LeftShoulder = r(55 + 6 * s, 0, 8),
			RightShoulder = r(55 - 6 * s, 0, -8),
			LeftElbow = r(50 + 8 * c, 0, 0),
			RightElbow = r(50 - 8 * c, 0, 0),
		}
	end,
	Knock = function(t)
		local k = math.abs(math.sin(t * 8))
		return { RightShoulder = r(75 + 10 * k, 0, -10), RightElbow = r(70 - 25 * k, 0, 0) }
	end,
	Scrub = function(t)
		return {
			RightShoulder = r(70 + 10 * math.sin(t * 9), 0, -12 + 16 * math.cos(t * 9)),
			RightElbow = r(35, 0, 0),
			LeftShoulder = r(25, 0, 8),
			Waist = r(-8, 0, 0),
		}
	end,
	Hammer = function(t)
		local k = math.max(0, math.sin(t * 7)) ^ 0.6
		return {
			RightShoulder = r(130 - 70 * k, 0, -10),
			RightElbow = r(30 + 20 * (1 - k), 0, 0),
			LeftShoulder = r(45, 0, 10),
			Waist = r(-10, 0, 0),
		}
	end,
	Wrench = function(t)
		return {
			RightShoulder = r(60, 0, -10),
			RightElbow = r(55, 40 * math.sin(t * 8), 0),
			LeftShoulder = r(55, 0, 12),
			LeftElbow = r(45, 0, 0),
			Waist = r(-12, 0, 0),
		}
	end,
	Shake = function(t)
		local s = math.sin(t * 14)
		return {
			LeftShoulder = r(45 + 10 * s, 0, 6),
			RightShoulder = r(45 + 10 * s, 0, -6),
			LeftElbow = r(45, 0, 0),
			RightElbow = r(45, 0, 0),
		}
	end,
	Pour = function(t)
		return {
			RightShoulder = r(70, 0, -10),
			RightElbow = r(40, 0, 0),
			RightWrist = r(0, 0, -35 - 10 * math.sin(t * 4)),
			LeftShoulder = r(40, 0, 10),
			LeftElbow = r(60, 0, 0),
		}
	end,
	Flip = function(t)
		local k = math.max(0, math.sin(t * 5))
		return {
			RightShoulder = r(50, 0, -6),
			RightElbow = r(40 + 30 * k, 0, 0),
			RightWrist = r(25 * k, 0, 0),
		}
	end,
	Lever = function(t)
		return { RightShoulder = r(110 - 50 * (0.5 + 0.5 * math.sin(t * 3)), 0, -10), RightElbow = r(20, 0, 0) }
	end,
	Fiddle = function(t)
		return {
			LeftShoulder = r(60, 0, 12),
			RightShoulder = r(60, 0, -12),
			LeftElbow = r(55 + 10 * math.sin(t * 13), 0, 0),
			RightElbow = r(55 + 10 * math.sin(t * 13 + 2), 0, 0),
			Waist = r(-15, 0, 0),
			Neck = r(-15, 0, 0),
		}
	end,
	Pry = function(t)
		local s = math.sin(t * 4)
		return {
			LeftShoulder = r(70, 0, 10),
			RightShoulder = r(70, 0, -10),
			LeftElbow = r(20 + 15 * s, 0, 0),
			RightElbow = r(20 + 15 * s, 0, 0),
			Waist = r(10 + 6 * s, 0, 0),
		}
	end,
	Photo = function(_t)
		return {
			RightShoulder = r(100, 0, -28),
			RightElbow = r(95, 0, 0),
			LeftShoulder = r(100, 0, 28),
			LeftElbow = r(95, 0, 0),
			Neck = r(-6, 0, 0),
		}
	end,
	Pick = function(t)
		return {
			Root = r(-12, 0, 0, 1.0),
			Waist = r(-30, 0, 0),
			LeftHip = r(70, 0, 0),
			RightHip = r(70, 0, 0),
			LeftKnee = r(-95, 0, 0),
			RightKnee = r(-95, 0, 0),
			RightShoulder = r(55 + 8 * math.sin(t * 8), 0, -10),
			RightElbow = r(15, 0, 0),
			LeftShoulder = r(25, 0, 10),
		}
	end,
	Reach = function(t)
		return {
			RightShoulder = r(35, 0, 20 + 6 * math.sin(t * 10)),
			RightElbow = r(15, 0, 0),
			Waist = r(-6, -15, 0),
		}
	end,
	Cuff = function(_t)
		return {
			LeftShoulder = r(70, 0, 15),
			RightShoulder = r(70, 0, -15),
			LeftElbow = r(40, 0, 0),
			RightElbow = r(40, 0, 0),
			Waist = r(-10, 0, 0),
		}
	end,
	Grab = function(_t)
		return {
			LeftShoulder = r(45, 0, 8),
			RightShoulder = r(45, 0, -8),
			LeftElbow = r(35, 0, 0),
			RightElbow = r(35, 0, 0),
			Waist = r(-8, 0, 0),
		}
	end,
	Serve = function(_t)
		return { RightShoulder = r(75, 0, -8), RightElbow = r(15, 0, 0) }
	end,
}

-- Which motion each job prompt (by its ActionText) shows; anything else is "Work".
local ACTIONS: { [string]: string } = {
	Knock = "Knock",
	Scrub = "Scrub",
	["Scrape it off"] = "Scrub",
	["Bang out dent"] = "Hammer",
	["Fit tyre"] = "Wrench",
	Fry = "Shake",
	["Pour shake"] = "Pour",
	["Add patty"] = "Flip",
	["Take patty"] = "Flip",
	["Pull rinse lever"] = "Lever",
	["Break in"] = "Fiddle",
	["Steal car"] = "Fiddle",
	["Pry the doors"] = "Pry",
	["Snap a photo"] = "Photo",
	["Pick up"] = "Pick",
	["Grab the cat"] = "Pick",
	["Scoop the poop"] = "Pick",
	["Grab the cash"] = "Pick",
	Pickpocket = "Reach",
	Steal = "Reach",
	Arrest = "Cuff",
	["Grab bin"] = "Grab",
	["Sell hot dog"] = "Serve",
	["Serve order"] = "Serve",
}

-- One-off moves ---------------------------------------------------------------------------

type Gesture = { seconds: number, keys: { { at: number, pose: Pose } } }

local CHEER_UP: Pose = {
	LeftShoulder = r(165, 0, -25),
	RightShoulder = r(165, 0, 25),
	LeftElbow = r(15, 0, 0),
	RightElbow = r(15, 0, 0),
	Root = r(0, 0, 0, -0.3),
}
local WAVE_UP = r(0, 0, 155)

local GESTURES: { [string]: Gesture } = {
	Throw = {
		seconds = 0.62,
		keys = {
			{ at = 0, pose = {} },
			{
				at = 0.35,
				pose = {
					RightShoulder = r(-55, 0, 35),
					RightElbow = r(70, 0, 0),
					LeftShoulder = r(40, 0, -20),
					Waist = r(0, -30, 0),
				},
			},
			{
				at = 0.55,
				pose = {
					RightShoulder = r(150, 0, -10),
					RightElbow = r(10, 0, 0),
					LeftShoulder = r(-10, 0, -10),
					Waist = r(-8, 25, 0),
				},
			},
			{ at = 0.78, pose = { RightShoulder = r(100, 0, -5), RightElbow = r(20, 0, 0), Waist = r(-5, 15, 0) } },
			{ at = 1, pose = {} },
		},
	},
	Cheer = {
		seconds = 1.2,
		keys = {
			{ at = 0, pose = {} },
			{ at = 0.18, pose = CHEER_UP },
			{
				at = 0.38,
				pose = {
					LeftShoulder = r(140, 0, -20),
					RightShoulder = r(140, 0, 20),
					LeftElbow = r(45, 0, 0),
					RightElbow = r(45, 0, 0),
				},
			},
			{ at = 0.58, pose = CHEER_UP },
			{ at = 0.85, pose = CHEER_UP },
			{ at = 1, pose = {} },
		},
	},
	Wave = {
		seconds = 1.8,
		keys = {
			{ at = 0, pose = {} },
			{ at = 0.12, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, 25) } },
			{ at = 0.26, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, -25) } },
			{ at = 0.4, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, 25) } },
			{ at = 0.54, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, -25) } },
			{ at = 0.68, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, 25) } },
			{ at = 0.84, pose = { RightShoulder = WAVE_UP, RightElbow = r(0, 0, 0) } },
			{ at = 1, pose = {} },
		},
	},
	HandOver = {
		seconds = 1.0,
		keys = {
			{ at = 0, pose = {} },
			{ at = 0.25, pose = { RightShoulder = r(80, 0, -6), RightElbow = r(10, 0, 0) } },
			{ at = 0.75, pose = { RightShoulder = r(80, 0, -6), RightElbow = r(10, 0, 0) } },
			{ at = 1, pose = {} },
		},
	},
	-- Both hands shoved out in front (pushing a rival away).
	Shove = {
		seconds = 0.5,
		keys = {
			{ at = 0, pose = {} },
			{
				at = 0.25,
				pose = {
					LeftShoulder = r(55, 0, -10),
					RightShoulder = r(55, 0, 10),
					LeftElbow = r(80, 0, 0),
					RightElbow = r(80, 0, 0),
					Waist = r(5, 0, 0),
				},
			},
			{
				at = 0.5,
				pose = {
					LeftShoulder = r(95, 0, -8),
					RightShoulder = r(95, 0, 8),
					LeftElbow = r(0, 0, 0),
					RightElbow = r(0, 0, 0),
					Waist = r(-14, 0, 0),
				},
			},
			{ at = 1, pose = {} },
		},
	},
	-- A big swing of one arm across the body (a rival's grab at your bag).
	Swipe = {
		seconds = 0.55,
		keys = {
			{ at = 0, pose = {} },
			{ at = 0.4, pose = { RightShoulder = r(110, 0, 45), RightElbow = r(30, 0, 0), Waist = r(0, 30, 0) } },
			{ at = 0.7, pose = { RightShoulder = r(85, 0, -45), RightElbow = r(5, 0, 0), Waist = r(-6, -25, 0) } },
			{ at = 1, pose = {} },
		},
	},
}

-- Rigs ------------------------------------------------------------------------------------

type Rig = {
	model: Model,
	joints: { [string]: Joint },
	pose: string?,
	poseWeight: number,
	shownPose: string?, -- what's blending out when the pose changes
	motion: string?,
	motionWeight: number,
	shownMotion: string?,
	motionStarted: number,
	gesture: string?,
	gestureStarted: number,
	touched: { [Joint]: boolean },
	animator: Animator?,
	fresh: boolean, -- an animation is playing (it set the joints this frame); else start from rest
}

local PoseController = {}

local rigs: { [Model]: Rig } = {}

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function rigFor(model: Model): Rig
	local existing = rigs[model]
	if existing then
		return existing
	end
	local joints: { [string]: Joint } = {}
	for _, joint in model:GetDescendants() do
		-- Characters here use AnimationConstraint joints (Roblox's newer rig); built rigs, Motor6Ds.
		local motor = joint:IsA("Motor6D") and joint.Part0 ~= nil and joint.Part0:IsDescendantOf(model)
		if joint:IsA("AnimationConstraint") or motor then
			joints[joint.Name] = joint :: Joint
		end
	end
	local rig: Rig = {
		model = model,
		joints = joints,
		pose = nil,
		poseWeight = 0,
		shownPose = nil,
		motion = nil,
		motionWeight = 0,
		shownMotion = nil,
		motionStarted = 0,
		gesture = nil,
		gestureStarted = 0,
		touched = {},
		animator = nil,
		fresh = false,
	}
	rigs[model] = rig
	return rig
end

local function readPose(rig: Rig)
	local pose = rig.model:GetAttribute("JobPose")
	rig.pose = if typeof(pose) == "string" and POSES[pose] then pose else nil
	if rig.pose then
		rig.shownPose = rig.pose
	end
end

local function readWorking(rig: Rig)
	local action = rig.model:GetAttribute("Working")
	if typeof(action) == "string" then
		rig.motion = ACTIONS[action] or "Work"
		rig.shownMotion = rig.motion
		rig.motionStarted = os.clock()
	else
		rig.motion = nil
	end
end

local function readGesture(rig: Rig)
	local name = rig.model:GetAttribute("Gesture")
	if typeof(name) == "string" and GESTURES[name] then
		rig.gesture = name
		rig.gestureStarted = os.clock()
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local function ensure(): Rig
		return rigFor(model)
	end
	model:GetAttributeChangedSignal("JobPose"):Connect(function()
		readPose(ensure())
	end)
	model:GetAttributeChangedSignal("Working"):Connect(function()
		readWorking(ensure())
	end)
	model:GetAttributeChangedSignal("GestureAt"):Connect(function()
		readGesture(ensure())
	end)
	if model:GetAttribute("JobPose") then
		readPose(ensure())
	end
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

local function setTransform(joint: Joint, value: CFrame)
	if joint:IsA("AnimationConstraint") then
		joint.Transform = value
		return
	end
	local motor = joint :: Motor6D
	motor.Transform = value
end

local function keyed(gesture: Gesture, share: number, name: string): CFrame
	local keys = gesture.keys
	for index = 1, #keys - 1 do
		local from, to = keys[index], keys[index + 1]
		if share <= to.at then
			local t = smooth((share - from.at) / math.max(to.at - from.at, 1e-3))
			return (from.pose[name] or CFrame.identity):Lerp(to.pose[name] or CFrame.identity, t)
		end
	end
	return CFrame.identity
end

-- Puts one layer on the joints it names.
local function layer(rig: Rig, pose: Pose, weight: number, out: { [Joint]: CFrame })
	if weight <= 0.001 then
		return
	end
	for name, target in pose do
		local joint = rig.joints[name]
		if joint then
			local current = out[joint] or (if rig.fresh then joint.Transform else CFrame.identity)
			out[joint] = if ADDITIVE[name] then current * REST:Lerp(target, weight) else current:Lerp(target, weight)
			rig.touched[joint] = true
		end
	end
end

local function step(rig: Rig, dt: number): boolean
	local now = os.clock()
	local idle = not rig.pose and not rig.motion and not rig.gesture
	if idle and rig.poseWeight < 0.001 and rig.motionWeight < 0.001 and next(rig.touched) == nil then
		return false
	end
	if not rig.animator then
		local humanoid = rig.model:FindFirstChildOfClass("Humanoid")
		rig.animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	end
	local animator = rig.animator
	rig.fresh = animator ~= nil and #animator:GetPlayingAnimationTracks() > 0
	local blend = math.min(1, dt * BLEND_IN)
	rig.poseWeight += ((if rig.pose then 1 else 0) - rig.poseWeight) * blend
	rig.motionWeight += ((if rig.motion then 1 else 0) - rig.motionWeight) * blend
	local out: { [Joint]: CFrame } = {}
	local shownPose = rig.pose or rig.shownPose
	if shownPose and rig.poseWeight > 0.001 then
		layer(rig, POSES[shownPose], rig.poseWeight, out)
	end
	local shownMotion = rig.motion or rig.shownMotion
	if shownMotion and rig.motionWeight > 0.001 then
		layer(rig, MOTIONS[shownMotion](now - rig.motionStarted), rig.motionWeight, out)
	end
	local gestureName = rig.gesture
	if gestureName then
		local gesture = GESTURES[gestureName]
		local share = (now - rig.gestureStarted) / gesture.seconds
		if share >= 1 then
			rig.gesture = nil
		else
			local envelope = smooth(share / 0.22) * smooth((1 - share) / 0.2)
			local pose: Pose = {}
			for _, key in gesture.keys do
				for name in key.pose do
					pose[name] = keyed(gesture, share, name)
				end
			end
			layer(rig, pose, envelope, out)
		end
	end
	for joint, value in out do
		setTransform(joint, value)
	end
	local busy = rig.gesture ~= nil or rig.poseWeight > 0.001 or rig.motionWeight > 0.001
	if not busy then
		-- Nothing left to show: let go of the joints (an NPC without a walk playing keeps
		-- whatever we last set otherwise).
		for joint in rig.touched do
			setTransform(joint, CFrame.identity)
		end
		table.clear(rig.touched)
	end
	return busy
end

-- Pushed and carried props ---------------------------------------------------------------

type Prop = {
	main: BasePart,
	wheels: { { joint: Motor6D, radius: number, angle: number } },
	engine: Motor6D?,
	spray: ParticleEmitter?,
	bubbles: ParticleEmitter?,
}

local props: { [BasePart]: Prop } = {}

local function addProp(instance: Instance)
	if not instance:IsA("BasePart") or props[instance] then
		return
	end
	local prop: Prop = { main = instance, wheels = {}, engine = nil, spray = nil, bubbles = nil }
	for _, joint in instance:GetChildren() do
		if joint:IsA("Motor6D") and joint.Part1 then
			if joint.Name == "Engine" then
				prop.engine = joint
			else
				table.insert(prop.wheels, { joint = joint, radius = math.max(joint.Part1.Size.Y / 2, 0.2), angle = 0 })
			end
		end
	end
	local kind = instance:GetAttribute("Kind")
	if kind == "Mower" then
		local nozzle = Instance.new("Attachment")
		nozzle.Position = Vector3.new(0, -0.2, -1.4)
		nozzle.Parent = instance
		prop.spray = Particles.keep(nozzle, "Confetti", 0, Color3.fromRGB(95, 175, 70), 0.55)
	elseif kind == "Sponge" then
		prop.bubbles = Particles.keep(instance, "Bubbles", 0, Color3.new(1, 1, 1), 0.8)
	end
	props[instance] = prop
end

local function stepProp(prop: Prop, dt: number)
	local main = prop.main
	local velocity = main.AssemblyLinearVelocity
	local ground = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = ground.Magnitude
	local forward = if ground:Dot(main.CFrame.LookVector) >= 0 then 1 else -1
	for _, wheel in prop.wheels do
		wheel.angle -= forward * speed * dt / wheel.radius
		wheel.joint.Transform = CFrame.Angles(wheel.angle, 0, 0)
	end
	local engine = prop.engine
	if engine then
		local shake = if speed > 1 then 0.05 else 0.02
		engine.Transform =
			CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, (math.random() - 0.5) * shake)
	end
	local spray = prop.spray
	if spray then
		spray.Rate = if speed > 3 then 30 else 0
	end
	local bubbles = prop.bubbles
	if bubbles then
		local character = main:FindFirstAncestorOfClass("Model")
		local working = character and character:GetAttribute("Working")
		bubbles.Rate = if typeof(working) == "string" and ACTIONS[working] == "Scrub" then 24 else 0
	end
end

function PoseController.start()
	local function watchPlayer(player: Player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	task.spawn(function()
		local folder = workspace:WaitForChild("NPCs", math.huge)
		for _, model in folder:GetChildren() do
			watch(model)
		end
		folder.ChildAdded:Connect(watch)
	end)

	for _, instance in CollectionService:GetTagged(PROP_TAG) do
		addProp(instance)
	end
	CollectionService:GetInstanceAddedSignal(PROP_TAG):Connect(addProp)
	CollectionService:GetInstanceRemovedSignal(PROP_TAG):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			props[instance] = nil
		end
	end)

	-- After the walk animation has set the joints this frame, before they're drawn.
	RunService.PreSimulation:Connect(function(dt: number)
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
			else
				step(rig, dt)
			end
		end
		for main, prop in props do
			if not main.Parent then
				props[main] = nil
			else
				stepProp(prop, dt)
			end
		end
	end)
end

return PoseController
