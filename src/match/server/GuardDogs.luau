--!strict
-- Guard dogs on chains: a kennel beside the porch and a BEWARE OF THE DOG sign by the path. They
-- doze until a courier (anyone carrying a delivery: the Courier character attribute) comes
-- within AggroStuds of the kennel, then charge, barking, as far as the chain lets them. If they
-- catch you they bite (GuardDogs.bit: Courier makes you drop what you're carrying), trot back
-- and settle down for CalmSeconds. A few houses keep one all game (street dogs, so some streets
-- are worse than others); a delivery's house sometimes gets one just for that delivery.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Dogs = require(script.Parent.Dogs)
local HouseIndex = require(script.Parent.HouseIndex)
local PropModels = require(script.Parent.PropModels)

local COURIER_ATTRIBUTE = "Courier"
local BARK_EVERY = 1.3
local GIVE_UP_SLACK = 5 -- studs past the end of the chain before it gives up on you
local LEAVE_SECONDS = 8 -- a delivery's own guard dog stays this long after the delivery
local GUARD_NAMES = { "Brutus", "Tank", "Chomper", "Duke", "Rocky", "Bruno", "Major", "Spike" }

export type Guard = {
	home: HouseIndex.Home,
	dog: Dogs.Dog,
	props: { Instance },
	kennel: Vector3,
	bed: Vector3, -- where it lies, in front of the kennel
	outward: Vector3,
	calmUntil: number,
	target: Player?,
	lastBark: number,
	street: boolean,
	users: number, -- deliveries using it right now
}

local settings = Config.Paths.Courier.GuardDogs
local remotes = Remotes.match()
local rng = Random.new()

local GuardDogs = {
	bit = Signal.new() :: Signal.Signal<Player>,
}

local guards: { [HouseIndex.Home]: Guard } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isCourier(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(COURIER_ATTRIBUTE) == true
end

local function nearestCourier(guard: Guard): Player?
	local best: Player? = nil
	local bestDistance = settings.AggroStuds
	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.getRoot(player)
		if root and isCourier(player) then
			local distance = flat(root.Position - guard.kennel).Magnitude
			if distance < bestDistance and math.abs(root.Position.Y - guard.kennel.Y) < 12 then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function think(guard: Guard)
	local dog = guard.dog
	local now = os.clock()
	local target = guard.target
	local root = target and CharacterUtil.getRoot(target)
	if target and (not root or not isCourier(target)) then
		target, root = nil, nil
		guard.target = nil
	end
	if not target and now >= guard.calmUntil then
		target = nearestCourier(guard)
		root = target and CharacterUtil.getRoot(target)
		if target then
			guard.target = target
			guard.lastBark = now
			Dogs.bark(dog, true)
		end
	end
	if target and root then
		local feet = root.Position - Vector3.new(0, 3, 0)
		local fromKennel = flat(feet - guard.kennel)
		if fromKennel.Magnitude > settings.ChainStuds + GIVE_UP_SLACK then
			guard.target = nil
			guard.calmUntil = now + 1.5
			Dogs.state(dog, "Trot")
			return
		end
		local goal = feet
		if fromKennel.Magnitude > settings.ChainStuds then
			goal = guard.kennel + fromKennel.Unit * settings.ChainStuds
		end
		Dogs.go(dog, goal, settings.Speed)
		Dogs.state(dog, "Charge")
		if now - guard.lastBark >= BARK_EVERY then
			guard.lastBark = now
			Dogs.bark(dog)
		end
		if flat(feet - dog.position).Magnitude <= settings.BiteStuds then
			guard.target = nil
			guard.calmUntil = now + settings.CalmSeconds
			Dogs.hop(dog, 1.2, 0.35)
			Dogs.bark(dog, true)
			remotes.JobFx:fireAll({ kind = "Chomp", at = root.Position })
			GuardDogs.bit:Fire(target)
		end
		return
	end
	-- Back to bed.
	if flat(guard.bed - dog.position).Magnitude > 1 then
		Dogs.go(dog, guard.bed, settings.Speed * 0.45)
		Dogs.state(dog, "Trot")
	else
		Dogs.go(dog, nil)
		Dogs.lookAt(dog, guard.bed + guard.outward * 10)
		Dogs.state(dog, "Lie")
	end
end

local function ground(spot: CFrame): CFrame
	local hit = Dogs.groundAt(spot.Position + Vector3.new(0, 1, 0), 3)
	return if hit then CFrame.new(hit) * spot.Rotation else spot
end

local function make(home: HouseIndex.Home, street: boolean): Guard
	local side = -(HouseIndex.width(home) / 2 - 3.5)
	local kennelAt = ground(HouseIndex.spot(home, side, 5.5))
	local props: { Instance } = {}
	table.insert(props, PropModels.place("Kennel", kennelAt, workspace))
	table.insert(props, PropModels.place("DogSign", ground(HouseIndex.spot(home, -3.2, 12)), workspace))
	local outward = kennelAt.LookVector
	local bed = kennelAt.Position + outward * 2.8
	local dog = Dogs.spawn("Guard", CFrame.lookAt(bed, bed + outward), GUARD_NAMES[rng:NextInteger(1, #GUARD_NAMES)])
	Dogs.state(dog, "Lie")
	local guard: Guard = {
		home = home,
		dog = dog,
		props = props,
		kennel = kennelAt.Position,
		bed = bed,
		outward = outward,
		calmUntil = 0,
		target = nil,
		lastBark = 0,
		street = street,
		users = 0,
	}
	dog.brain = function()
		think(guard)
	end
	guards[home] = guard
	return guard
end

local function remove(guard: Guard)
	if guards[guard.home] == guard then
		guards[guard.home] = nil
	end
	Dogs.remove(guard.dog)
	for _, thing in guard.props do
		thing:Destroy()
	end
end

function GuardDogs.at(home: HouseIndex.Home): Guard?
	return guards[home]
end

-- A guard dog for a delivery at this house (the street dog if it already has one).
function GuardDogs.hire(home: HouseIndex.Home): Guard
	local guard = guards[home] or make(home, false)
	guard.users += 1
	return guard
end

function GuardDogs.release(guard: Guard)
	guard.users = math.max(0, guard.users - 1)
	if guard.street then
		return
	end
	task.delay(LEAVE_SECONDS, function()
		if guard.users == 0 and guards[guard.home] == guard then
			remove(guard)
		end
	end)
end

function GuardDogs.start()
	task.delay(5, function()
		local homes = table.clone(HouseIndex.all())
		for _ = 1, math.min(settings.StreetDogs, #homes) do
			local home = table.remove(homes, rng:NextInteger(1, #homes))
			if home then
				make(home, true)
			end
		end
	end)
end

return GuardDogs
