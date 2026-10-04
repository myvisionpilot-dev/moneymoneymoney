--!strict
-- The leap a pedestrian does to get out of a car's way. The server does the dash itself
-- (server/NpcService.dodge) and sets the NPC's Dodging attribute; every client then plays this
-- hand-keyed animation on its own copy of the rig, layered over their walk: a startled flinch,
-- a dive, landing in a crouch, a wobble, and standing back up. Joint angles are in degrees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DODGE_ATTRIBUTE = "Dodging"

type Pose = { [string]: CFrame } -- joint (Motor6D) name -> offset on top of its rest pose
type Playing = { started: number, joints: { [string]: Motor6D }, rest: { [Motor6D]: CFrame } }

local function turn(x: number, y: number, z: number, drop: number?): CFrame
	return CFrame.new(0, -(drop or 0), 0) * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Times are shares of Config.Dodge.Seconds. Arms and legs: +x swings them forward, z out.
local KEYFRAMES: { { at: number, pose: Pose } } = {
	{ at = 0, pose = {} },
	{ -- Startled: lean back, arms fly up and out, knees give a little.
		at = 0.1,
		pose = {
			Root = turn(8, 0, 0, 0.2),
			Waist = turn(6, 0, 0),
			Neck = turn(15, 0, 0),
			LeftShoulder = turn(30, 0, -70),
			RightShoulder = turn(30, 0, 70),
			LeftHip = turn(20, 0, 0),
			RightHip = turn(20, 0, 0),
			LeftKnee = turn(-30, 0, 0),
			RightKnee = turn(-30, 0, 0),
		},
	},
	{ -- The dive: body pitched forward, arms stretched ahead, legs trailing.
		at = 0.3,
		pose = {
			Root = turn(-35, 0, 0, -0.3),
			Waist = turn(-15, 0, 0),
			Neck = turn(20, 0, 0),
			LeftShoulder = turn(165, 0, -15),
			RightShoulder = turn(165, 0, 15),
			LeftHip = turn(-25, 0, 0),
			RightHip = turn(10, 0, 0),
			LeftKnee = turn(-50, 0, 0),
			RightKnee = turn(-40, 0, 0),
		},
	},
	{ -- Landing in a crouch, arms out for balance.
		at = 0.5,
		pose = {
			Root = turn(-15, 0, 0, 0.9),
			Waist = turn(-10, 0, 0),
			Neck = turn(5, 0, 0),
			LeftShoulder = turn(40, 0, -60),
			RightShoulder = turn(40, 0, 60),
			LeftHip = turn(60, 0, 0),
			RightHip = turn(60, 0, 0),
			LeftKnee = turn(-80, 0, 0),
			RightKnee = turn(-80, 0, 0),
		},
	},
	{ -- A wobble: leaning, one arm windmilling.
		at = 0.72,
		pose = {
			Root = turn(5, 0, 8, 0.3),
			Waist = turn(0, 0, -12),
			Neck = turn(-5, 0, 10),
			LeftShoulder = turn(120, 0, -40),
			RightShoulder = turn(-20, 0, 80),
			LeftHip = turn(20, 0, 0),
			RightHip = turn(20, 0, 0),
			LeftKnee = turn(-25, 0, 0),
			RightKnee = turn(-25, 0, 0),
		},
	},
	{ at = 1, pose = {} }, -- back on their feet
}

local DodgeController = {}

local playing: { [Model]: Playing } = {}

local function ease(t: number): number
	return 0.5 - math.cos(math.pi * t) / 2
end

local function poseAt(name: string, share: number): CFrame
	for index = 1, #KEYFRAMES - 1 do
		local from, to = KEYFRAMES[index], KEYFRAMES[index + 1]
		if share <= to.at then
			local t = ease((share - from.at) / math.max(to.at - from.at, 1e-3))
			return (from.pose[name] or CFrame.identity):Lerp(to.pose[name] or CFrame.identity, t)
		end
	end
	return CFrame.identity
end

local function start(model: Model)
	if playing[model] then
		return
	end
	local joints: { [string]: Motor6D } = {}
	local rest: { [Motor6D]: CFrame } = {}
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") then
			joints[joint.Name] = joint
			rest[joint] = joint.C0
		end
	end
	playing[model] = { started = os.clock(), joints = joints, rest = rest }
end

local function stop(model: Model, current: Playing)
	for joint, c0 in current.rest do
		joint.C0 = c0
	end
	playing[model] = nil
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal(DODGE_ATTRIBUTE):Connect(function()
		if model:GetAttribute(DODGE_ATTRIBUTE) then
			start(model)
		end
	end)
end

function DodgeController.start()
	task.spawn(function()
		local folder = workspace:WaitForChild("NPCs", math.huge)
		for _, model in folder:GetChildren() do
			watch(model)
		end
		folder.ChildAdded:Connect(watch) -- including NPCs streaming back in
	end)

	RunService.RenderStepped:Connect(function()
		local seconds = Config.Dodge.Seconds
		for model, current in playing do
			local share = (os.clock() - current.started) / seconds
			if share >= 1 or not model.Parent then
				stop(model, current)
			else
				for name, joint in current.joints do
					local c0 = current.rest[joint]
					if c0 then
						joint.C0 = c0 * poseAt(name, share)
					end
				end
			end
		end
	end)
end

return DodgeController
