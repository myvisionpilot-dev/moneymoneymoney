--!strict
-- The people behind the counters: Mr. Penny at the bank, a shopkeeper in every shop (they talk
-- to you: CounterService) and someone at each job desk. Each stands on a map part tagged
-- StaffSpot (attribute Staff = their id below), facing the same way as the part. They're
-- scenery: anchored, and nobody can push them around.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NpcService = require(script.Parent.NpcService)

local SPOT_TAG = "StaffSpot"
local HEAD_HEIGHT = 6 -- studs from the floor to just above their head

type Staff = {
	name: string,
	look: NpcService.Look,
	greetings: { string }?, -- what a shopkeeper says when you walk up
}

local SKIN = {
	Color3.fromRGB(241, 194, 158),
	Color3.fromRGB(224, 172, 132),
	Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(141, 85, 56),
	Color3.fromRGB(96, 60, 40),
}

local STAFF: { [string]: Staff } = {
	Penny = {
		name = "Mr. Penny",
		look = {
			skin = SKIN[1],
			shirt = Color3.fromRGB(45, 45, 55),
			pants = Color3.fromRGB(45, 45, 55),
			hair = 376548738, -- Brown Charmer Hair
			top = Config.Outfits.Uniforms.Suit.shirt,
			bottom = Config.Outfits.Uniforms.Suit.pants,
		},
	},
	Tony = {
		name = "Tony",
		look = {
			skin = SKIN[2],
			shirt = Color3.fromRGB(30, 30, 35),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 63690008, -- Pal Hair
			top = 4047884046, -- Guitar Tee with Black Jacket
			bottom = 382538503, -- Black Jeans with Sneakers
		},
		greetings = {
			"Tony's Blasters. Stun only, nobody gets hurt. Whaddaya need?",
			"Hey, it's my favourite customer. Looking for some zap?",
		},
	},
	CornerClerk = {
		name = "Dot",
		look = {
			skin = SKIN[4],
			shirt = Color3.fromRGB(60, 170, 160),
			pants = Color3.fromRGB(60, 80, 140),
			hair = 7193454569, -- Braided Hair - Black
			top = 382537702, -- Teal Shirt
			bottom = 398634487, -- Beautiful You Jeans
		},
		greetings = {
			"Welcome to the Corner Store! What'll it be?",
			"Snacks, drinks, disguises. Don't ask about the disguises.",
		},
	},
	MiniClerk = {
		name = "Gus",
		look = {
			skin = SKIN[1],
			shirt = Color3.fromRGB(60, 100, 200),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 1103003368, -- Orange Beanie with Black Hair
			top = 398635081, -- Blue Plaid Shirt
			bottom = 382537569, -- Black Jeans
		},
		greetings = {
			"Mini Mart, how can I help?",
			"Hey! Energy drinks are fresh in. Well, fresh-ish.",
		},
	},
	Hank = {
		name = "Hank",
		look = {
			skin = SKIN[3],
			shirt = Color3.fromRGB(120, 120, 130),
			pants = Color3.fromRGB(40, 90, 50),
			hair = 62234425, -- Brown Hair
			hat = 607702162, -- Roblox Baseball Cap
			top = 144076436, -- Grey Striped Shirt with Denim Jacket
			bottom = 144076760, -- Dark Green Jeans
		},
		greetings = {
			"Howdy! Need a better lockpick? I don't ask why.",
			"Handy Hank's. If it opens things, I sell it.",
		},
	},
	Bea = {
		name = "Bea",
		look = {
			skin = SKIN[2],
			shirt = Color3.fromRGB(240, 200, 220),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 2956239660, -- Belle Of Belfast Long Red Hair
			top = 398634295, -- Pastel Starburst Top with Gray Jacket
			bottom = 398633812, -- Black Jeans with White Shoes
		},
		greetings = {
			"Welcome to BAGS! Bigger bag, bigger hauls.",
			"Looking for a bag? You came to the right place, obviously.",
		},
	},
	Speedy = {
		name = "Speedy",
		look = {
			skin = SKIN[5],
			shirt = Color3.fromRGB(40, 60, 120),
			pants = Color3.fromRGB(80, 80, 90),
			hair = 376524487, -- Blonde Spiked Hair
			hat = 417457461, -- ROBLOX 'R' Baseball Cap
			top = 144076358, -- Blue and Black Motorcycle Shirt
			bottom = 398635338, -- Ripped Skater Pants
		},
		greetings = {
			"Speedy's Garage! Here for a race?",
			"Fixer-uppers out back, races out front.",
		},
	},
	-- At the job desks: they just stand there and look busy.
	Dee = {
		name = "Dee",
		look = {
			skin = SKIN[3],
			shirt = Color3.fromRGB(200, 60, 60),
			pants = Color3.fromRGB(60, 80, 140),
			hair = 9244150641, -- Braided Hair - Cool Brown
			top = 607785314, -- ROBLOX Jacket
			bottom = 398634487, -- Beautiful You Jeans
		},
	},
	Carl = {
		name = "Carl",
		look = {
			skin = SKIN[1],
			shirt = Color3.fromRGB(240, 200, 60),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 451221329, -- True Blue Hair
			hat = 2646473721, -- Roblox Visor
			top = 3670737444, -- Roblox Shirt - Simple Pattern
			bottom = 382538503, -- Black Jeans with Sneakers
		},
	},
	Suds = {
		name = "Suds",
		look = {
			skin = SKIN[4],
			shirt = Color3.fromRGB(70, 140, 220),
			pants = Color3.fromRGB(60, 80, 140),
			hair = 376526888, -- Straight Blonde Hair
			top = 398633584, -- Denim Jacket with White Hoodie
			bottom = 382537950, -- Jean Shorts with White Shoes
		},
	},
	Hal = {
		name = "Hal",
		look = {
			skin = SKIN[2],
			shirt = Color3.fromRGB(230, 90, 60),
			pants = Color3.fromRGB(30, 30, 35),
			hair = 63690008, -- Pal Hair
			top = 4047884939, -- My Favorite Pizza Shirt
			bottom = 382537569, -- Black Jeans
		},
	},
}

-- Behind the small businesses' windows, the bank's tellers and the police front desk: everyday
-- clothes picked from the outfit lists (the tellers in suits, the sergeant in uniform).
local EXTRA_STAFF: { { id: string, name: string, uniform: string? } } = {
	{ id = "Barber", name = "Sal" },
	{ id = "Laundromat", name = "Wendy" },
	{ id = "Cafe", name = "Jo" },
	{ id = "Pharmacy", name = "Dr. Reed" },
	{ id = "Bakery", name = "Maud" },
	{ id = "Florist", name = "Lily" },
	{ id = "PostOffice", name = "Pete" },
	{ id = "Diner", name = "Rosie" },
	{ id = "Gym", name = "Max" },
	{ id = "Books", name = "Iris" },
	{ id = "PetShop", name = "Pip" },
	{ id = "Toys", name = "Ted" },
	{ id = "Music", name = "Ziggy" },
	{ id = "Teller1", name = "Ms. Coin", uniform = "Suit" },
	{ id = "Teller2", name = "Mr. Stack", uniform = "Suit" },
	{ id = "Sergeant", name = "Sgt. Bell", uniform = "Police" },
}
local outfits = Config.Outfits
for index, extra in EXTRA_STAFF do
	local uniform = if extra.uniform then (outfits.Uniforms :: any)[extra.uniform] else nil
	STAFF[extra.id] = {
		name = extra.name,
		look = {
			skin = SKIN[index % #SKIN + 1],
			shirt = Color3.fromRGB(80, 80, 90),
			pants = Color3.fromRGB(40, 40, 50),
			hair = outfits.Hair[(index * 5) % #outfits.Hair + 1],
			top = if uniform then uniform.shirt else outfits.Shirts[(index * 3) % #outfits.Shirts + 1],
			bottom = if uniform then uniform.pants else outfits.Pants[(index * 7) % #outfits.Pants + 1],
		},
	}
end

local StaffService = {}

local rigs: { [string]: Model } = {}
local restingArms: { [Instance]: CFrame } = {}

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
		rigs[who :: string] = model
	end)
end

-- Their name and what they say when you walk up (nil for anyone who doesn't talk).
function StaffService.info(who: string): (string?, { string }?)
	local staff = STAFF[who]
	if not staff then
		return nil, nil
	end
	return staff.name, staff.greetings
end

-- Just above a staff member's head (by their id, e.g. "Penny"), for what they say.
function StaffService.headAt(who: string): Vector3?
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		if spot:GetAttribute("Staff") == who and spot:IsA("BasePart") then
			return spot.Position - Vector3.new(0, spot.Size.Y / 2, 0) + Vector3.new(0, HEAD_HEIGHT, 0)
		end
	end
	return nil
end

-- Hands up (during a robbery), or back down.
function StaffService.handsUp(who: string, up: boolean)
	local model = rigs[who]
	if not model then
		return
	end
	for _, side in { "Right", "Left" } do
		local arm = model:FindFirstChild(`{side}UpperArm`)
		local joint = arm and arm:FindFirstChild(`{side}Shoulder`)
		local raise = CFrame.Angles(math.rad(165), 0, if side == "Right" then -0.25 else 0.25)
		-- Older rigs use a Motor6D; newer ones an AnimationConstraint between two attachments.
		if joint and joint:IsA("Motor6D") then
			local resting = restingArms[joint] or joint.C0
			restingArms[joint] = resting
			joint.C0 = if up then resting * raise else resting
		elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
			local shoulder = joint.Attachment0 :: Attachment
			local resting = restingArms[shoulder] or shoulder.CFrame
			restingArms[shoulder] = resting
			shoulder.CFrame = if up then resting * raise else resting
		end
	end
end

function StaffService.start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		place(spot)
	end
end

return StaffService
