--!strict
-- The people behind the counters: Mr. Penny at the bank and Tony at his blaster shop. Each
-- stands on a map part tagged StaffSpot (attribute Staff = "Penny" or "Tony"), facing the same
-- way as the part. They're scenery: anchored, and nobody can push them around.

local CollectionService = game:GetService("CollectionService")

local NpcService = require(script.Parent.NpcService)

local SPOT_TAG = "StaffSpot"

type Staff = { name: string, look: NpcService.Look }

local STAFF: { [string]: Staff } = {
	Penny = {
		name = "Mr. Penny",
		look = {
			skin = Color3.fromRGB(241, 194, 158),
			shirt = Color3.fromRGB(45, 45, 55), -- a dark suit
			pants = Color3.fromRGB(45, 45, 55),
			hair = 376548738, -- Brown Charmer Hair
			bottom = 382537569, -- Black Jeans
		},
	},
	Tony = {
		name = "Tony",
		look = {
			skin = Color3.fromRGB(224, 172, 132),
			shirt = Color3.fromRGB(30, 30, 35),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 63690008, -- Pal Hair
			top = 4047884046, -- Guitar Tee with Black Jacket
			bottom = 382538503, -- Black Jeans with Sneakers
		},
	},
}

local StaffService = {}

local function place(spot: Instance)
	local who = spot:GetAttribute("Staff")
	local staff = if typeof(who) == "string" then STAFF[who] else nil
	if not staff or not spot:IsA("BasePart") then
		return
	end
	task.spawn(function()
		local model = NpcService.makeRig(staff.name, staff.look)
		local ground = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
		NpcService.place(model, CFrame.new(ground + Vector3.new(0, 3, 0)) * spot.CFrame.Rotation)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
	end)
end

function StaffService.start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		place(spot)
	end
end

return StaffService
