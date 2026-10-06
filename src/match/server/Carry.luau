--!strict
-- Puts a job prop (PropModels: a package, a letter, the mower, a dog...) on a player's
-- character: held in front of them, or on the ground in front (or beside them, for a dog on its
-- leash), welded so it goes where they go. Destroy the returned part to take it away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local PropModels = require(script.Parent.PropModels)

local Carry = {}

local function weld(a: BasePart, b: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = a
	joint.Part1 = b
	joint.Parent = b
end

-- A dog's leash, from the collar up to their right hand.
local function leash(character: Model, prop: BasePart)
	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGripAttachment")
	local ring = prop:FindFirstChild("Leash", true)
	if not grip or not grip:IsA("Attachment") or not ring or not ring:IsA("Attachment") then
		return
	end
	local rope = Instance.new("RopeConstraint")
	rope.Name = "Leash"
	rope.Attachment0 = grip
	rope.Attachment1 = ring
	rope.Length = (grip.WorldPosition - ring.WorldPosition).Magnitude + 0.8
	rope.Visible = true
	rope.Thickness = 0.08
	rope.Color = BrickColor.new("Really red")
	rope.Parent = prop
end

function Carry.prop(player: Player, kind: PropModels.Kind): BasePart?
	local root = CharacterUtil.getRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not character or not humanoid then
		return nil
	end
	local hold = PropModels.hold(kind)
	local base = if hold.ground
		then root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
		else root.CFrame
	local main = PropModels.build(kind)
	PropModels.moveTo(main, base * hold.offset)
	weld(root, main)
	for _, piece in main:GetDescendants() do
		if piece:IsA("BasePart") then
			weld(main, piece)
		end
	end
	main.Parent = character
	if kind == "Dog" then
		leash(character, main)
	end
	return main
end

return Carry
