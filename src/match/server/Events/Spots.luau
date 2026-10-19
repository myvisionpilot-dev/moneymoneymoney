--!strict
-- Spots round town to put things: the footpath waypoints and the taxi stops, on the ground.

local CollectionService = game:GetService("CollectionService")

local TAGS = { "PedWaypoint", "TaxiStop" }

local rng = Random.new()

local Spots = {}

function Spots.all(): { Vector3 }
	local list = {}
	for _, tag in TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("BasePart") then
				table.insert(list, instance.Position - Vector3.new(0, instance.Size.Y / 2, 0))
			end
		end
	end
	return list
end

function Spots.random(): Vector3?
	local list = Spots.all()
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

-- A random spot between `near` and `far` studs (flat distance) from `from`; failing that, the
-- one closest to that range.
function Spots.around(from: Vector3, near: number, far: number): Vector3?
	local inRange: { Vector3 } = {}
	local best: Vector3? = nil
	local bestMiss = math.huge
	for _, spot in Spots.all() do
		local distance = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z).Magnitude
		if distance >= near and distance <= far then
			table.insert(inRange, spot)
		else
			local miss = if distance < near then near - distance else distance - far
			if miss < bestMiss then
				best, bestMiss = spot, miss
			end
		end
	end
	return if #inRange > 0 then inRange[rng:NextInteger(1, #inRange)] else best
end

return Spots
