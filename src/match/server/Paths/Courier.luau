--!strict
-- Deliveries, however they start (the depot's packages, letters for residents, rush parcels from
-- your phone): it goes on the house's WELCOME mat. Walk it up and put it down, or throw it from
-- the path (Throwing): on the mat pays a bonus, on the porch is fine, anywhere else is a miss
-- you have to go and pick up. Fragile parcels crack when you crash into something, land hard
-- from a big drop, get zapped or bitten, or get thrown anywhere but the mat; the last crack
-- smashes them. Some houses have a guard dog (GuardDogs) that makes you drop what you carry.
-- Deliveries one after another build a chain (Config.Paths.Courier.ChainSeconds) that pays more.
-- The job that started it decides the pay: it calls Courier.reward when the drop is delivered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Carry = require(script.Parent.Parent.Carry)
local Dogs = require(script.Parent.Parent.Dogs)
local Gestures = require(script.Parent.Parent.Gestures)
local GuardDogs = require(script.Parent.Parent.GuardDogs)
local HouseIndex = require(script.Parent.Parent.HouseIndex)
local JobKit = require(script.Parent.JobKit)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PropModels = require(script.Parent.Parent.PropModels)
local Thanks = require(script.Parent.Parent.Thanks)
local Throwing = require(script.Parent.Parent.Throwing)

local COURIER_ATTRIBUTE = "Courier" -- carrying a delivery (guard dogs go for you)
local LEFT_SECONDS = 1.5 -- after the resident goes in, the parcel and mat go too
local REST_HEIGHT: { [string]: number } = { Package = 0.65, Letter = 0.06 }

export type How = "Mat" | "Porch" | "Hand"
export type Kind = "Package" | "Letter"

export type Options = {
	kind: Kind,
	near: Vector3, -- a drop-off pad or a front door: the nearest house gets it
	fragile: boolean?,
	onDelivered: (how: How) -> (),
	onBroken: () -> (),
	onMoved: (() -> ())?, -- it's somewhere else now (a missed throw, dropped it): update the guide
}

export type Drop = {
	player: Player,
	options: Options,
	home: HouseIndex.Home?,
	mat: BasePart,
	spot: Vector3, -- the middle of the mat's top
	carried: BasePart?, -- in your hands
	loose: BasePart?, -- in the air, on the ground, or delivered on the porch
	hits: number, -- cracks left before a fragile parcel smashes
	over: boolean,
	guard: GuardDogs.Guard?,
	spec: Throwing.Spec?,
	lastBump: number,
	lastSpeed: number,
	lastDirection: Vector3,
	lastFall: number,
	connections: { RBXScriptConnection },
}

local settings = Config.Paths.Courier
local remotes = Remotes.match()
local rng = Random.new()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local Courier = {}

local drops: { [Player]: Drop } = {}
local chains: { [Player]: { count: number, at: number } } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function soundAt(name: string, at: Vector3)
	local spot = Instance.new("Attachment")
	spot.Parent = workspace.Terrain
	spot.WorldPosition = at
	Sounds.at(name, spot)
	task.delay(4, function()
		spot:Destroy()
	end)
end

local function setCourier(drop: Drop, on: boolean)
	local character = drop.player.Character
	if character then
		character:SetAttribute(COURIER_ATTRIBUTE, if on then true else nil)
	end
end

local function cracksTaken(drop: Drop): number
	return settings.Fragile.Hits - drop.hits
end

local carry: (drop: Drop) -> ()

-- Lying where it fell: hold E on it to pick it back up.
local function lyingThere(drop: Drop, part: BasePart)
	JobKit.prompt(part, {
		action = "Pick up",
		object = if drop.options.kind == "Letter" then "Letter" else "Parcel",
		hold = 0.3,
		owner = drop.player,
	}, function()
		if drop.over or drop.loose ~= part then
			return
		end
		part:Destroy()
		drop.loose = nil
		carry(drop)
		local moved = drop.options.onMoved
		if moved then
			moved()
		end
	end)
end

-- One knock on a fragile parcel. False if that smashed it (the job's off).
local function crack(drop: Drop, at: Vector3): boolean
	if drop.over or not drop.options.fragile then
		return true
	end
	drop.hits -= 1
	drop.lastBump = os.clock()
	local holder = drop.carried or drop.loose
	if drop.hits > 0 then
		remotes.JobFx:fireAll({ kind = "Crack", at = at })
		soundAt("Crack", at)
		if holder then
			PropModels.fragile(holder, cracksTaken(drop))
		end
		Notifier.send(drop.player, `CRACK! Careful, it's fragile: {drop.hits} more and it smashes.`, "Bad")
		return true
	end
	remotes.JobFx:fireAll({ kind = "Smash", at = at })
	soundAt("Smash", at)
	if holder then
		holder:Destroy()
	end
	drop.carried = nil
	drop.loose = nil
	drop.options.onBroken()
	return false
end

local function deliver(drop: Drop, how: How)
	if drop.over then
		return
	end
	drop.options.onDelivered(how)
end

local function landed(drop: Drop, part: BasePart, landing: Vector3)
	if drop.over or drop.loose ~= part then
		return
	end
	local letter = drop.options.kind == "Letter"
	soundAt(if letter then "Rustle" else "Thud", landing)
	local miss = flat(landing - drop.spot).Magnitude
	local level = math.abs(landing.Y - drop.spot.Y) < 3
	local how: How? = if miss <= settings.MatStuds and level
		then "Mat"
		elseif miss <= settings.PorchStuds and level then "Porch"
		else nil
	if how ~= "Mat" and not crack(drop, landing) then
		return
	end
	if how == "Mat" then
		part.CFrame = CFrame.new(drop.spot + Vector3.new(0, REST_HEIGHT[drop.options.kind], 0)) * part.CFrame.Rotation
	end
	if how then
		deliver(drop, how)
		return
	end
	lyingThere(drop, part)
	Notifier.send(drop.player, "Missed the porch! Grab it and try again.", "Info")
	local moved = drop.options.onMoved
	if moved then
		moved()
	end
end

local function thrown(drop: Drop, landing: Vector3, from: CFrame)
	local carried = drop.carried
	if drop.over or not carried then
		return
	end
	carried:Destroy()
	drop.carried = nil
	setCourier(drop, false)
	Throwing.clear(drop.player, drop.spec)
	local kind: PropModels.Kind = drop.options.kind
	local part = PropModels.loose(kind, from, workspace)
	if drop.options.fragile then
		PropModels.fragile(part, cracksTaken(drop))
	end
	drop.loose = part
	local letter = kind == "Letter"
	local rest = CFrame.new(landing + Vector3.new(0, REST_HEIGHT[kind], 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local seconds = Throwing.fly(part, from, rest, {
		spin = if letter then 3 else 1.1,
		flat = letter,
		hops = if letter then 0 else 1,
	})
	task.delay(seconds, function()
		landed(drop, part, landing)
	end)
end

carry = function(drop: Drop)
	local prop = Carry.prop(drop.player, drop.options.kind)
	if not prop then
		return
	end
	if drop.options.fragile then
		PropModels.fragile(prop, cracksTaken(drop))
	end
	drop.carried = prop
	setCourier(drop, true)
	local spec: Throwing.Spec = {
		kind = drop.options.kind,
		range = settings.ThrowStuds,
		target = drop.spot,
		onThrow = function(landing: Vector3, from: CFrame)
			thrown(drop, landing, from)
		end,
	}
	drop.spec = spec
	Throwing.set(drop.player, spec)
end

-- Knocked out of their hands (a guard dog): it lands beside them.
local function knocked(drop: Drop)
	local carried = drop.carried
	local root = CharacterUtil.getRoot(drop.player)
	if drop.over or not carried or not root then
		return
	end
	carried:Destroy()
	drop.carried = nil
	setCourier(drop, false)
	Throwing.clear(drop.player, drop.spec)
	local kind: PropModels.Kind = drop.options.kind
	local from = root.CFrame * CFrame.new(0, 0.5, -1.2)
	local aside = root.Position + root.CFrame.RightVector * rng:NextNumber(-3, 3) - root.CFrame.LookVector * 3
	local ground = Dogs.groundAt(aside) or (root.Position - Vector3.new(0, 3, 0))
	local part = PropModels.loose(kind, from, workspace)
	if drop.options.fragile then
		PropModels.fragile(part, cracksTaken(drop))
	end
	drop.loose = part
	local rest = CFrame.new(ground + Vector3.new(0, REST_HEIGHT[kind], 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local seconds = Throwing.fly(part, from, rest, { height = 3, spin = 1.6, hops = 1 })
	Notifier.send(drop.player, "CHOMP! The guard dog made you drop it. Grab it and get clear!", "Bad")
	if not crack(drop, root.Position) then
		return
	end
	task.delay(seconds, function()
		if not drop.over and drop.loose == part then
			lyingThere(drop, part)
		end
	end)
	local moved = drop.options.onMoved
	if moved then
		moved()
	end
end

-- Starts a delivery for `player`: the mat goes down at the house nearest `options.near`, and the
-- parcel (or letter) goes in their hands.
function Courier.begin(player: Player, options: Options): Drop?
	local old = drops[player]
	if old then
		Courier.stop(old, false)
	end
	local home = HouseIndex.nearest(options.near, 45)
	local place = if home then HouseIndex.mat(home) else CFrame.new(Dogs.groundAt(options.near) or options.near)
	local mat = PropModels.place("Doormat", place, workspace)
	local drop: Drop = {
		player = player,
		options = options,
		home = home,
		mat = mat,
		spot = place.Position + Vector3.new(0, 0.13, 0),
		carried = nil,
		loose = nil,
		hits = settings.Fragile.Hits,
		over = false,
		guard = nil,
		spec = nil,
		lastBump = 0,
		lastSpeed = 0,
		lastDirection = Vector3.zero,
		lastFall = 0,
		connections = {},
	}
	drops[player] = drop
	carry(drop)
	if not drop.carried then
		Courier.stop(drop, false)
		return nil
	end
	if home and (GuardDogs.at(home) or rng:NextNumber() < settings.GuardDogs.Chance) then
		drop.guard = GuardDogs.hire(home)
	end
	local character = player.Character
	if character then
		table.insert(
			drop.connections,
			character:GetAttributeChangedSignal("Stunned"):Connect(function()
				local root = CharacterUtil.getRoot(player)
				if character:GetAttribute("Stunned") and drop.carried and root then
					crack(drop, root.Position)
				end
			end)
		)
	end
	return drop
end

-- Where to go next: the mat, or wherever it's lying.
function Courier.marker(drop: Drop): Vector3
	local loose = drop.loose
	return if loose and not drop.over then loose.Position else drop.spot
end

function Courier.hasGuard(drop: Drop): boolean
	return drop.guard ~= nil
end

-- Ends a delivery. `delivered`: the parcel stays on the porch while the resident comes out.
function Courier.stop(drop: Drop, delivered: boolean)
	if drop.over then
		return
	end
	drop.over = true
	if drops[drop.player] == drop then
		drops[drop.player] = nil
	end
	for _, connection in drop.connections do
		connection:Disconnect()
	end
	Throwing.clear(drop.player, drop.spec)
	setCourier(drop, false)
	if drop.carried then
		drop.carried:Destroy()
		drop.carried = nil
	end
	local guard = drop.guard
	if guard then
		GuardDogs.release(guard)
	end
	local leftovers: { Instance } = { drop.mat }
	if drop.loose then
		table.insert(leftovers, drop.loose)
	end
	local function tidy()
		for _, thing in leftovers do
			thing:Destroy()
		end
	end
	if delivered then
		task.delay(settings.ThanksSeconds + LEFT_SECONDS, tidy)
	else
		tidy()
	end
end

-- The delivery chain: this delivery's place in it and what that pays (x1, x1.1, ...).
local function chain(player: Player): (number, number)
	local now = Timing.now()
	local previous = chains[player]
	local count = if previous and now - previous.at <= settings.ChainSeconds then previous.count + 1 else 1
	chains[player] = { count = count, at = now }
	return count, math.min(1 + settings.ChainStep * (count - 1), settings.ChainMax)
end

-- Pays a delivered drop: `base` (already at this quota), x the chain and the fragile bonus, the
-- mat bonus as its own money line; the resident comes to the door to wave. Then ends it.
function Courier.reward(drop: Drop, how: How, base: number, label: string, reason: string, stat: string?): number
	local player = drop.player
	local count, multiplier = chain(player)
	local fragile = if drop.options.fragile then 1 + settings.Fragile.PayBonus else 1
	local amount = math.floor(base * multiplier * fragile + 0.5)
	local line = if how == "Hand" then label elseif how == "Mat" then `{label}: bullseye!` else `{label}: on the porch`
	if count > 1 then
		line = `{line} (chain x{count})`
	end
	local added = JobKit.pay(player, amount, line, reason, stat)
	if how == "Mat" then
		PayNotice.earn(
			player,
			math.floor(base * settings.MatBonus + 0.5),
			"Right on the mat!",
			reason,
			true,
			{ streak = false, payoutXp = false }
		)
		remotes.JobFx:fireAll({ kind = "Sparkle", at = drop.spot })
	end
	if count > 1 then
		Notifier.send(
			player,
			`Delivery chain x{count}! Deliver again within {settings.ChainSeconds}s to keep it going.`,
			"Good"
		)
	end
	local home = drop.home
	if home then
		Thanks.atDoor(home.door, home.id, player, how == "Hand")
	end
	Courier.stop(drop, true)
	return added
end

-- Something solid right where they were heading (so stopping dead was a crash, not letting go
-- of the keys).
local function hitAhead(player: Player, root: BasePart, direction: Vector3): boolean
	if direction.Magnitude < 0.5 then
		return false
	end
	local skip: { Instance } = {}
	local character = player.Character
	if character then
		table.insert(skip, character)
	end
	for _, name in { "Animals", "NPCs" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(skip, found)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(root.Position, direction.Unit * 2.4, params)
	return hit ~= nil and hit.Instance.CanCollide
end

local function watchBumps(player: Player, drop: Drop)
	local root = CharacterUtil.getRoot(player)
	local character = player.Character
	if not root or not character or not drop.carried then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = flat(velocity).Magnitude
	local fragile = settings.Fragile
	if os.clock() - drop.lastBump >= fragile.CooldownSeconds then
		local driving = character:GetAttribute("VehicleSpeed") ~= nil
		local stopped = drop.lastSpeed >= fragile.BumpSpeed and speed <= drop.lastSpeed * fragile.BumpKeep
		local crashed = stopped and (driving or hitAhead(player, root, drop.lastDirection))
		local landedHard = drop.lastFall <= -fragile.FallSpeed and velocity.Y > -8
		if crashed or landedHard then
			crack(drop, root.Position)
		end
	end
	drop.lastSpeed = speed
	if speed > 1 then
		drop.lastDirection = flat(velocity).Unit
	end
	drop.lastFall = velocity.Y
end

-- Walked it up to the mat: put it down there.
local function checkHand(player: Player, drop: Drop)
	local carried = drop.carried
	local root = CharacterUtil.getRoot(player)
	if not carried or not root then
		return
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	if flat(feet - drop.spot).Magnitude > settings.HandStuds or math.abs(feet.Y - drop.spot.Y) > 4 then
		return
	end
	carried:Destroy()
	drop.carried = nil
	setCourier(drop, false)
	Throwing.clear(player, drop.spec)
	local kind: PropModels.Kind = drop.options.kind
	local placed = PropModels.place(kind, CFrame.new(drop.spot + Vector3.new(0, REST_HEIGHT[kind], 0)), workspace)
	if drop.options.fragile then
		PropModels.fragile(placed, cracksTaken(drop))
	end
	drop.loose = placed
	Gestures.playFor(player, "HandOver")
	soundAt(if kind == "Letter" then "Rustle" else "Thud", drop.spot)
	deliver(drop, "Hand")
end

function Courier.start()
	GuardDogs.bit:Connect(function(player: Player)
		local drop = drops[player]
		if drop then
			knocked(drop)
		end
	end)
	RunService.Heartbeat:Connect(function()
		for player, drop in drops do
			if not player.Parent then
				Courier.stop(drop, false)
			elseif not drop.over then
				if drop.options.fragile then
					watchBumps(player, drop)
				end
				if not drop.over then
					checkHand(player, drop)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		chains[player] = nil
	end)
end

return Courier
