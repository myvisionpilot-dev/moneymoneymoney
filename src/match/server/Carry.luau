--!strict
-- Welds a small prop (package, letter, dog...) in front of a player's character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)

local Carry = {}

function Carry.attach(player: Player, name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart?
	local root = CharacterUtil.getRoot(player)
	local character = player.Character
	if not root or not character then
		return nil
	end
	local prop = Instance.new("Part")
	prop.Name = name
	prop.Size = size
	prop.Color = color
	prop.Material = material or Enum.Material.SmoothPlastic
	prop.CanCollide = false
	prop.CanQuery = false
	prop.CanTouch = false
	prop.Massless = true
	prop.CFrame = root.CFrame * CFrame.new(0, 0, -1.4)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = prop
	weld.Parent = prop
	prop.Parent = character
	return prop
end

return Carry
