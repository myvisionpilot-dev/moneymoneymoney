--!strict
-- The people in the lobby's bank hall: Mr. Penny and two tellers behind the counter, and a
-- guard by the door. Each stands on a part tagged StaffSpot (attribute Staff = an id below),
-- facing the way the part faces, breathing on Roblox's idle animation. Scenery only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SPOT_TAG = "StaffSpot"
local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's default R15 idle

type Look = { skin: Color3, hair: number, shirt: number, pants: number }

local uniforms = Config.Outfits.Uniforms
local STAFF: { [string]: Look } = {
	Penny = {
		skin = Color3.fromRGB(241, 194, 158),
		hair = 376548738,
		shirt = uniforms.Suit.shirt,
		pants = uniforms.Suit.pants,
	},
	Teller1 = {
		skin = Color3.fromRGB(198, 134, 94),
		hair = 7193454569,
		shirt = uniforms.Suit.shirt,
		pants = uniforms.Suit.pants,
	},
	Teller2 = {
		skin = Color3.fromRGB(224, 172, 132),
		hair = 376526888,
		shirt = uniforms.Suit.shirt,
		pants = uniforms.Suit.pants,
	},
	Guard = {
		skin = Color3.fromRGB(141, 85, 56),
		hair = 62234425,
		shirt = uniforms.Police.shirt,
		pants = uniforms.Police.pants,
	},
}

local BankStaff = {}

local function describe(look: Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	for _, part in { "Head", "LeftArm", "RightArm", "Torso", "LeftLeg", "RightLeg" } do
		(description :: any)[`{part}Color`] = look.skin
	end
	description.HairAccessory = tostring(look.hair)
	description.Shirt = look.shirt
	description.Pants = look.pants
	return description
end

local function place(spot: Instance)
	local id = spot:GetAttribute("Staff")
	local look = if typeof(id) == "string" then STAFF[id] else nil
	if not look or not spot:IsA("BasePart") then
		return
	end
	task.spawn(function()
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(describe(look), Enum.HumanoidRigType.R15)
		end)
		if not ok then
			warn(`[BankStaff] couldn't dress {id}: {model}`)
			return
		end
		model.Name = id :: string
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			model:Destroy()
			return
		end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		root.Anchored = true
		local ground = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
		model:PivotTo(
			CFrame.new(ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)) * spot.CFrame.Rotation
		)
		model.Parent = workspace
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = IDLE_ANIMATION
		local loaded, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if loaded then
			track.Looped = true
			track:Play()
		end
	end)
end

function BankStaff.start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		place(spot)
	end
end

return BankStaff
