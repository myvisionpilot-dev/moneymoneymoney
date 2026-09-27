--!strict
-- Small helpers for reading a player's character safely.

local CharacterUtil = {}

function CharacterUtil.getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CharacterUtil.distanceTo(player: Player, position: Vector3): number
	local root = CharacterUtil.getRoot(player)
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

return CharacterUtil
