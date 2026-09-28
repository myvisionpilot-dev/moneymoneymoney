--!strict
-- The shop door bell: plays when you walk into a store (parts tagged StoreZone).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local ZONE_TAG = "StoreZone"
local CHECK_SECONDS = 0.2

local StoreChimeController = {}

local function inside(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

function StoreChimeController.start()
	local current: BasePart? = nil
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local found: BasePart? = nil
			if root and root:IsA("BasePart") then
				for _, zone in CollectionService:GetTagged(ZONE_TAG) do
					if zone:IsA("BasePart") and inside(zone, root.Position) then
						found = zone
						break
					end
				end
			end
			if found and found ~= current then
				Sounds.play("StoreBell")
			end
			current = found
		end
	end)
end

return StoreChimeController
