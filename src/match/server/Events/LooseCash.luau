--!strict
-- Loose cash for the town events (money rain, the parade, the money tornado). Bills on the
-- ground are invisible anchored markers tagged LooseCash, with their Value and when they land
-- (LandsAt, server time); client/LooseCashController draws each one fluttering down and spinning
-- on the ground, and the pop when someone pockets it. Walk within Events.LooseCash.GrabStuds of
-- a landed bill to pocket it. What each player picks up (and what LooseCash.owe adds) is paid
-- every PaySeconds as one money line that doesn't touch the streak (Events.LooseCash).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Timing = require(ReplicatedStorage.Shared.Timing)
local JailService = require(script.Parent.Parent.JailService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)

local TAG = "LooseCash"
local CHECK_SECONDS = 0.1
local SKY = 160 -- rays look down from this high for the ground

local settings = Config.Events.LooseCash
local rng = Random.new()

type Bill = { part: Part, value: number, label: string, landsAt: number, goneAt: number }
type Owed = { amount: number, label: string }

local LooseCash = {}

local bills: { Bill } = {}
local owed: { [Player]: Owed } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = "LooseCash"
	created.Parent = workspace
	folder = created
	return created
end

-- The ground under (x, z), or nil off the map or where the first thing below is a roof, a
-- tree or anything else up high (Events.LooseCash.MaxGroundY): nothing lands where you can't
-- reach it. Ignores people, animals and the bills themselves.
function LooseCash.ground(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	local ignore: { Instance } = { getFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { "NPCs", "Animals" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, SKY, z), Vector3.new(0, -SKY - 20, 0), params)
	return if hit and hit.Position.Y <= settings.MaxGroundY then hit.Position else nil
end

-- Somewhere on the ground between `near` and `far` studs (flat) from `center`, spread evenly
-- over the area; it tries a few spots before giving up (everything there is a roof).
function LooseCash.groundAround(center: Vector3, near: number, far: number, tries: number?): Vector3?
	for _ = 1, tries or 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = math.sqrt(rng:NextNumber(near * near, far * far))
		local ground = LooseCash.ground(center.X + math.cos(angle) * reach, center.Z + math.sin(angle) * reach)
		if ground then
			return ground
		end
	end
	return nil
end

-- A bill worth `value` lands at `at` (on the ground) after LandSeconds; `label` names it on
-- the money line ("Money rain").
function LooseCash.drop(at: Vector3, value: number, label: string)
	local part = Instance.new("Part")
	part.Name = "Bill"
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local landsAt = Timing.now() + settings.LandSeconds
	part:SetAttribute("Value", value)
	part:SetAttribute("LandsAt", landsAt)
	part:AddTag(TAG)
	part.Parent = getFolder()
	table.insert(bills, {
		part = part,
		value = value,
		label = label,
		landsAt = landsAt,
		goneAt = landsAt + settings.LifeSeconds,
	})
end

-- Adds to what they're paid at the next payout (the tornado pays this way).
function LooseCash.owe(player: Player, amount: number, label: string)
	local entry = owed[player]
	if entry then
		entry.amount += amount
		entry.label = label
	else
		owed[player] = { amount = amount, label = label }
	end
end

local function payOut()
	for player, entry in owed do
		local amount = math.floor(entry.amount + 0.5)
		if amount > 0 and player.Parent then
			PayNotice.earn(player, amount, entry.label, "loose cash", true, { streak = false, payoutXp = false })
		end
	end
	table.clear(owed)
end

-- Every bill gone (the quota's over), and what's owed paid now.
function LooseCash.clear()
	for _, bill in bills do
		bill.part:Destroy()
	end
	table.clear(bills)
	payOut()
end

-- Everyone who can pick up cash (in the run, out of jail) and where they are.
function LooseCash.people(): { { player: Player, at: Vector3 } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.getRoot(player)
		if root and RosterService.isActive(player) and not JailService.isJailed(player) then
			table.insert(list, { player = player, at = root.Position })
		end
	end
	return list
end

local function check()
	if #bills == 0 then
		return
	end
	local now = Timing.now()
	local people = LooseCash.people()
	local reach = settings.GrabStuds
	for index = #bills, 1, -1 do
		local bill = bills[index]
		if now >= bill.goneAt then
			bill.part:Destroy()
			table.remove(bills, index)
		elseif now >= bill.landsAt then
			local spot = bill.part.Position
			for _, person in people do
				local offset = person.at - spot
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and math.abs(offset.Y) < 8 then
					-- Who got it, for the pop on their screen (set before it goes).
					bill.part:SetAttribute("Collector", person.player.UserId)
					bill.part:Destroy()
					table.remove(bills, index)
					LooseCash.owe(person.player, bill.value, bill.label)
					break
				end
			end
		end
	end
end

function LooseCash.start()
	local sinceCheck, sincePay = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		sincePay += dt
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			check()
		end
		if sincePay >= settings.PaySeconds then
			sincePay = 0
			payOut()
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		owed[player] = nil
	end)
end

return LooseCash
