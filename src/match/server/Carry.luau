--!strict
-- Puts a job prop (PropModels: a package, a letter, the mower...) on a player's character: in
-- their right hand, held in front of them in both hands, or on the ground in front, so it goes
-- where they go. Their character's JobPose says how they hold it (client/PoseController poses
-- their arms to match). Wheels and the mower's engine hang on joints the client turns. Destroy
-- the returned part to take it away.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local PropModels = require(script.Parent.PropModels)

local PROP_TAG = "JobProp"

local Carry = {}

local function weld(a: BasePart, b: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = a
	joint.Part1 = b
	joint.Parent = b
end

-- A moving piece's joint: it sits where it was built, and the client turns it.
local function hinge(main: BasePart, piece: BasePart)
	local joint = Instance.new("Motor6D")
	joint.Name = piece.Name
	joint.Part0 = main
	joint.Part1 = piece
	joint.C0 = main.CFrame:ToObjectSpace(piece.CFrame)
	joint.Parent = main
end

-- The pose of whatever they're still carrying (the newest prop), or none.
local function refreshPose(character: Model, leaving: Instance?)
	local pose: string? = nil
	for _, child in character:GetChildren() do
		if child ~= leaving and CollectionService:HasTag(child, PROP_TAG) then
			local held = child:GetAttribute("Pose")
			if typeof(held) == "string" then
				pose = held
			end
		end
	end
	character:SetAttribute("JobPose", pose)
end

function Carry.prop(player: Player, kind: PropModels.Kind): BasePart?
	local root = CharacterUtil.getRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not character or not humanoid then
		return nil
	end
	local hold = PropModels.hold(kind)
	local hand = character:FindFirstChild("RightHand")
	local main = PropModels.build(kind)
	if hold.hand and hand and hand:IsA("BasePart") then
		PropModels.moveTo(main, hand.CFrame * hold.offset)
		local grip = Instance.new("Weld")
		grip.Name = "Grip"
		grip.Part0 = hand
		grip.Part1 = main
		grip.C0 = hold.offset
		grip.Parent = main
	else
		local base = if hold.ground
			then root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
			else root.CFrame
		PropModels.moveTo(main, base * hold.offset)
		weld(root, main)
	end
	for _, piece in main:GetDescendants() do
		if piece:IsA("BasePart") then
			if PropModels.Moving[piece.Name] then
				hinge(main, piece)
			else
				weld(main, piece)
			end
		end
	end
	main:SetAttribute("Kind", kind)
	main:SetAttribute("Pose", hold.pose)
	CollectionService:AddTag(main, PROP_TAG)
	main.Destroying:Connect(function()
		if character.Parent then
			refreshPose(character, main)
		end
	end)
	main.Parent = character
	refreshPose(character)
	return main
end

return Carry
