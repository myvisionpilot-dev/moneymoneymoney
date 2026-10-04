--!strict
-- Pedestrians get out of the way: anyone standing in a moving car's path, up to about a second
-- ahead of it, leaps aside (NpcService.dodge). Cars pass through people anyway
-- (CollisionGroups), so a slow reaction never hurts anyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NpcService = require(script.Parent.NpcService)
local VehicleService = require(script.Parent.VehicleService)

local CHECK_SECONDS = 0.1

local settings = Config.Dodge
local rng = Random.new()

local DodgeService = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function check(car: Model)
	local hull = car.PrimaryPart
	if not hull then
		return
	end
	local velocity = flat(hull.AssemblyLinearVelocity)
	local speed = velocity.Magnitude
	if speed < settings.MinCarSpeed then
		return
	end
	local direction = velocity.Unit
	local reach = speed * settings.LookAheadSeconds + settings.ExtraStuds
	local halfWidth = car:GetAttribute("HalfWidth")
	local clear = (if typeof(halfWidth) == "number" then halfWidth else 3) + settings.ClearStuds
	for _, pedestrian in NpcService.pedestrians() do
		local root = pedestrian:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = flat(root.Position - hull.Position)
			local along = offset:Dot(direction)
			local side = offset - direction * along
			if along > -2 and along < reach and side.Magnitude < clear then
				-- Away from the car's line; straight ahead of it, pick a side.
				local away = if side.Magnitude > 0.5
					then side.Unit
					else direction:Cross(Vector3.yAxis) * (if rng:NextNumber() < 0.5 then 1 else -1)
				NpcService.dodge(pedestrian, away)
			end
		end
	end
end

function DodgeService.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, car in VehicleService.cars() do
				check(car)
			end
		end
	end)
end

return DodgeService
