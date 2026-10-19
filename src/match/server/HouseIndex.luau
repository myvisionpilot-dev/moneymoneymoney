--!strict
-- The town's houses (parts tagged House, each with a Door), for jobs that need a front door: where
-- a delivery's doormat goes, where a guard dog's kennel sits, the nearest house to a drop-off.
-- Spots are given in the house's own terms: `across` the front (right is +), `out` from the
-- door toward the street.

local CollectionService = game:GetService("CollectionService")

local HOUSE_TAG = "House"

export type Home = {
	id: number,
	part: BasePart,
	door: BasePart,
}

local HouseIndex = {}

local homes: { Home } = {}
local known: { [BasePart]: boolean } = {}

local function add(instance: Instance)
	if not instance:IsA("BasePart") or known[instance] then
		return
	end
	local door = instance:FindFirstChild("Door")
	local id = instance:GetAttribute("HouseId")
	if door and door:IsA("BasePart") and typeof(id) == "number" then
		known[instance] = true
		table.insert(homes, { id = id, part = instance, door = door })
	end
end

function HouseIndex.start()
	for _, instance in CollectionService:GetTagged(HOUSE_TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(HOUSE_TAG):Connect(add)
end

function HouseIndex.all(): { Home }
	return homes
end

function HouseIndex.byDoor(door: BasePart): Home?
	for _, home in homes do
		if home.door == door then
			return home
		end
	end
	return nil
end

function HouseIndex.nearest(position: Vector3, within: number?): Home?
	local best: Home? = nil
	local bestDistance = within or math.huge
	for _, home in homes do
		local distance = (home.door.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = home, distance
		end
	end
	return best
end

-- A ground spot in front of the door, facing the street.
function HouseIndex.spot(home: Home, across: number, out: number): CFrame
	local door = home.door
	local floor = door.Position.Y - door.Size.Y / 2
	local outward = Vector3.new(door.CFrame.LookVector.X, 0, door.CFrame.LookVector.Z).Unit
	local right = Vector3.new(door.CFrame.RightVector.X, 0, door.CFrame.RightVector.Z).Unit
	local at = Vector3.new(door.Position.X, floor, door.Position.Z) + right * across + outward * out
	return CFrame.lookAt(at, at + outward)
end

-- Where a delivery's doormat lies: on the step, just outside the door.
function HouseIndex.mat(home: Home): CFrame
	return HouseIndex.spot(home, 0, 1.4)
end

-- How wide the house is (its front wall).
function HouseIndex.width(home: Home): number
	return home.part.Size.X
end

return HouseIndex
