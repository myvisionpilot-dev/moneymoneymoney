--!strict
-- The bank (parts tagged SafeZone): no blasting in or out, and repo men can't tag you inside.

local CollectionService = game:GetService("CollectionService")

local SAFE_TAG = "SafeZone"

local SafeZone = {}

function SafeZone.contains(position: Vector3): boolean
	for _, zone in CollectionService:GetTagged(SAFE_TAG) do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

return SafeZone
