--!strict
-- The dog walk (a door job), in three legs:
--   1 Walk them to the park on the leash. They trot beside you, sniff and sit when you stop.
--   2 Fetch: throw the ball (Throwing) and they run it down, sometimes catching it in the air,
--     and bring it back. A tip each time; more for a long throw, double for a catch.
--   3 Walk them home to the resident, who pays you.
-- On the way a squirrel or a cat turns up and the dog pulls: tap to hold them back (the TugGame
-- remote; client/TugController) for a tip, or they slip the leash and you chase them down. They
-- may also stop for a poo: scoop it for a tip, or walk off and a neighbour docks your pay.
-- Tips are Config amounts scaled like the job's pay. Everything here runs off DoorKnock's job.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Carry = require(script.Parent.Parent.Carry)
local DoorTypes = require(script.Parent.DoorTypes)
local Dogs = require(script.Parent.Parent.Dogs)
local Gestures = require(script.Parent.Parent.Gestures)
local JobKit = require(script.Parent.JobKit)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PropModels = require(script.Parent.Parent.PropModels)
local Thanks = require(script.Parent.Parent.Thanks)
local Throwing = require(script.Parent.Parent.Throwing)

type Job = DoorTypes.Job
type Kit = DoorTypes.Kit

type Stage = "ToPark" | "Fetch" | "Home"
type Mode = "Heel" | "Pull" | "Bolt" | "Poop" | "Fetch" | "Return" | "Wait"

type Walk = {
	job: Job,
	kit: Kit,
	dog: Dogs.Dog,
	name: string,
	stage: Stage,
	mode: Mode,
	modeSince: number,
	beam: Beam?,
	hand: Attachment?,
	walked: number, -- seconds walked since the last distraction
	nextDistraction: number,
	distractionsLeft: number,
	critter: BasePart?,
	tug: { meter: number, endsAt: number }?,
	boltUntil: number,
	boltGoal: Vector3?,
	boltNext: number,
	dodgeNext: number,
	fetches: number,
	ball: BasePart?, -- in the air, on the grass, or in the dog's mouth
	ballLanding: Vector3?,
	ballDownAt: number, -- os.clock() it stops bouncing
	caught: boolean,
	throwDistance: number,
	held: BasePart?, -- the ball in your hand
	poopIn: number?, -- walked seconds until they stop for one
	poop: BasePart?,
	fine: number,
	still: number, -- seconds you've stood still
	lastTick: number,
	lastSent: number, -- the last tug update sent to the walker
	keepDog: boolean, -- they're running in to the resident: don't take them away yet
}

local SLOW_ATTRIBUTE = "JobSlow" -- shared/Movement multiplies your speed by this
local PET_NAMES = { "Rex", "Biscuit", "Maple", "Buster", "Pepper", "Waffles", "Luna", "Ziggy", "Noodle", "Bear" }
local HEEL_SIDE = 2.4 -- studs to your right...
local HEEL_BACK = 0.6 -- ...and a little behind
local SNIFF_AFTER = 1.5 -- standing still this long, they sniff about...
local SIT_AFTER = 4 -- ...and then sit
local TELEPORT_STUDS = 70 -- left this far behind (you got in a car?), they catch up at once
local TUG_SEND_SECONDS = 0.15
local POOP_SECONDS = 2.4

local settings = Config.Paths.Doors.DogWalk
local remotes = Remotes.match()
local tapLimiter = RateLimiter.new(settings.Tug.MaxTapsPerSecond, 1)
local rng = Random.new()

local DogWalk = {}

local walks: { [Player]: Walk } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function feetOf(player: Player): Vector3?
	local root = CharacterUtil.getRoot(player)
	return if root then root.Position - Vector3.new(0, 3, 0) else nil
end

local function setMode(walk: Walk, mode: Mode)
	walk.mode = mode
	walk.modeSince = os.clock()
end

-- Tips scale like the job's pay (house tier, quota and twists).
local function tip(walk: Walk, base: number, label: string)
	local scale = walk.job.pay / Config.Paths.Doors.Pay.DogWalk
	PayNotice.earn(walk.job.player, math.floor(base * scale + 0.5), label, "dog walk", true, {
		streak = false,
		payoutXp = false,
	})
end

local function fx(kind: "Catch" | "Sparkle" | "Poof", at: Vector3)
	remotes.JobFx:fireAll({ kind = kind, at = at })
end

local function setTitle(walk: Walk, title: string, target: Vector3)
	walk.job.title = title
	walk.job.targets = { target }
	walk.kit.guide(walk.job)
end

-- The leash ---------------------------------------------------------------------------

local function handAttachment(walk: Walk): Attachment?
	local existing = walk.hand
	if existing and existing.Parent then
		return existing
	end
	local character = walk.job.player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end
	local grip = hand:FindFirstChild("RightGripAttachment")
	local attachment = Instance.new("Attachment")
	attachment.Name = "LeashHand"
	attachment.Position = if grip and grip:IsA("Attachment") then grip.Position else Vector3.new(0, -0.4, 0)
	attachment.Parent = hand
	walk.hand = attachment
	return attachment
end

local function makeBeam(walk: Walk, to: Attachment?)
	local collar = Dogs.attachment(walk.dog, "Leash")
	if walk.beam then
		walk.beam:Destroy()
		walk.beam = nil
	end
	if not collar or not to then
		return
	end
	local beam = Instance.new("Beam")
	beam.Name = "LeashLine"
	beam.Attachment0 = collar
	beam.Attachment1 = to
	beam.Width0 = 0.18
	beam.Width1 = 0.18
	beam.Segments = 14
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(220, 45, 45))
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam:SetAttribute("LeashStuds", settings.LeashStuds)
	beam.Parent = walk.dog.model
	walk.beam = beam
end

local function leash(walk: Walk)
	makeBeam(walk, handAttachment(walk))
	Gestures.pose(walk.job.player, "Leash")
end

-- Off the leash: it drags along behind them (or goes, for fetch).
local function unleash(walk: Walk, trailing: boolean)
	makeBeam(walk, if trailing then Dogs.attachment(walk.dog, "LeashTrail") else nil)
	local pose = Gestures.posing(walk.job.player)
	if pose == "Leash" or pose == "Tug" then
		Gestures.pose(walk.job.player, nil)
	end
end

-- Somewhere open to run to, about `reach` studs away roughly along `direction` (not into a house).
local function openSpot(from: Vector3, direction: Vector3, reach: number): Vector3
	local base = math.atan2(direction.Z, direction.X)
	for attempt = 0, 7 do
		local turn = (if attempt % 2 == 0 then 1 else -1) * math.ceil(attempt / 2) * 0.6
		local spot = from + Vector3.new(math.cos(base + turn), 0, math.sin(base + turn)) * reach
		if Dogs.open(spot) then
			return spot
		end
	end
	return from
end

-- Critters ------------------------------------------------------------------------------

local function scamper(part: BasePart, from: Vector3, away: Vector3)
	local direction = flat(away)
	direction = if direction.Magnitude > 0.1 then direction.Unit else Vector3.new(1, 0, 0)
	local goal = Dogs.groundAt(from + direction * 26 + Vector3.new(0, 1, 0), 3) or (from + direction * 26)
	local seconds = Throwing.fly(part, part.CFrame, CFrame.lookAt(goal, goal + direction), {
		hopping = true,
		height = 0.8,
		seconds = 1.3,
	})
	task.delay(seconds + 0.1, function()
		part:Destroy()
	end)
end

local function endTug(walk: Walk)
	walk.tug = nil
	local character = walk.job.player.Character
	if character then
		character:SetAttribute(SLOW_ATTRIBUTE, nil)
	end
	if walk.job.player.Parent then
		remotes.TugGame:fireClient(walk.job.player, nil)
	end
end

local function sendTug(walk: Walk)
	local tug = walk.tug
	local critter = walk.critter
	if tug and walk.job.player.Parent then
		remotes.TugGame:fireClient(walk.job.player, {
			critter = if critter and critter.Name == "Cat" then "CAT!" else "SQUIRREL!",
			meter = tug.meter,
			endsAt = tug.endsAt,
			tap = settings.Tug.PerTap,
			pull = settings.Tug.PullPerSecond,
		})
	end
end

local function distraction(walk: Walk)
	local player = walk.job.player
	local root = CharacterUtil.getRoot(player)
	if not root then
		return
	end
	walk.distractionsLeft -= 1
	walk.walked = 0
	walk.nextDistraction = rng:NextNumber(settings.DistractionGapSeconds[1], settings.DistractionGapSeconds[2])
	local ahead = flat(root.CFrame.LookVector)
	ahead = if ahead.Magnitude > 0.1 then ahead.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-ahead.Z, 0, ahead.X)
	local spot = root.Position + ahead * rng:NextNumber(14, 18) + side * rng:NextNumber(-7, 7)
	local ground = Dogs.groundAt(spot, 4) or (root.Position - Vector3.new(0, 3, 0) + ahead * 16)
	local cat = rng:NextNumber() < settings.CatChance
	local facing = CFrame.lookAt(ground, Vector3.new(walk.dog.position.X, ground.Y, walk.dog.position.Z))
	local critter = PropModels.loose(
		if cat then "Cat" else "Squirrel",
		facing * CFrame.new(0, if cat then 0.7 else 0, 0),
		workspace
	)
	critter.Name = if cat then "Cat" else "Squirrel"
	walk.critter = critter
	if cat then
		Sounds.at("Meow", critter)
	end
	Dogs.bark(walk.dog, true)
	setMode(walk, "Pull")
	walk.tug = { meter = settings.Tug.Start, endsAt = Timing.now() + settings.Tug.Seconds }
	local character = player.Character
	if character then
		character:SetAttribute(SLOW_ATTRIBUTE, settings.TugSlow)
	end
	Gestures.pose(player, "Tug")
	sendTug(walk)
end

local function heldBack(walk: Walk)
	endTug(walk)
	local critter = walk.critter
	walk.critter = nil
	if critter then
		scamper(critter, critter.Position, critter.Position - walk.dog.position)
	end
	setMode(walk, "Heel")
	leash(walk)
	walk.kit.notify(walk.job, `Good dog! You held {walk.name} back.`)
	tip(walk, settings.GoodDogTip, "Good dog!")
end

local function bolted(walk: Walk)
	endTug(walk)
	local critter = walk.critter
	walk.critter = nil
	local away = if critter then flat(critter.Position - walk.dog.position) else flat(walk.dog.heading)
	if critter then
		scamper(critter, critter.Position, away)
	end
	walk.boltGoal = openSpot(walk.dog.position, if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0), 30)
	walk.boltNext = os.clock() + 2.5
	walk.boltUntil = Timing.now() + settings.BoltSeconds
	setMode(walk, "Bolt")
	unleash(walk, true)
	Dogs.bark(walk.dog, true)
	walk.kit.notify(walk.job, `{walk.name} slipped the leash! Catch them before they run home!`)
	setTitle(walk, `Catch {walk.name}!`, walk.dog.position)
end

local function caughtUp(walk: Walk)
	setMode(walk, "Heel")
	leash(walk)
	walk.boltGoal = nil
	Dogs.bark(walk.dog)
	walk.kit.notify(walk.job, `Gotcha! {walk.name}'s back on the leash.`)
	if walk.stage == "ToPark" then
		setTitle(walk, `Walk {walk.name} to the park`, walk.kit.park() or walk.dog.position)
	else
		setTitle(walk, `Walk {walk.name} home`, walk.job.house.door.Position)
	end
end

-- The poo -------------------------------------------------------------------------------

local function poop(walk: Walk)
	local behind = walk.dog.position - walk.dog.heading * 1.6 * walk.dog.scale
	local ground = Dogs.groundAt(behind, 2) or behind
	local mess = PropModels.place("Poop", CFrame.new(ground), workspace)
	walk.poop = mess
	JobKit.prompt(
		mess,
		{ action = "Scoop the poop", object = walk.name, hold = 0.8, owner = walk.job.player },
		function()
			if walk.poop ~= mess then
				return
			end
			walk.poop = nil
			fx("Sparkle", mess.Position)
			mess:Destroy()
			tip(walk, settings.ScoopTip, "Scooped the poop")
		end
	)
	walk.kit.notify(walk.job, `Oops! {walk.name} left you a present. Scoop it up!`)
end

local function checkMess(walk: Walk)
	local mess = walk.poop
	local feet = feetOf(walk.job.player)
	if not mess or not feet or flat(feet - mess.Position).Magnitude < settings.MessStuds then
		return
	end
	walk.poop = nil
	walk.fine += settings.MessFine
	walk.kit.notify(walk.job, `A neighbour saw you leave that! -{math.floor(settings.MessFine * 100)}% off this walk.`)
	for _, prompt in mess:GetChildren() do
		if prompt:IsA("ProximityPrompt") then
			prompt:Destroy()
		end
	end
	task.delay(20, function()
		mess:Destroy()
	end)
end

-- Fetch ---------------------------------------------------------------------------------

local throwBall: (walk: Walk) -> ()

local function inPark(walk: Walk, point: Vector3): Vector3
	local park = walk.kit.park()
	if not park then
		return point
	end
	local half = settings.ParkHalfSize
	return Vector3.new(
		math.clamp(point.X, park.X - half[1], park.X + half[1]),
		point.Y,
		math.clamp(point.Z, park.Z - half[2], park.Z + half[2])
	)
end

local function thrown(walk: Walk, landing: Vector3, from: CFrame)
	local held = walk.held
	if walk.stage ~= "Fetch" or walk.mode ~= "Wait" or not held then
		return
	end
	held:Destroy()
	walk.held = nil
	Throwing.clear(walk.job.player)
	local spot = inPark(walk, landing)
	local ground = Dogs.groundAt(spot + Vector3.new(0, 2, 0), 4) or spot
	local distance = flat(ground - from.Position).Magnitude
	local air = Throwing.airTime((ground - from.Position).Magnitude)
	local run = flat(ground - walk.dog.position).Magnitude / settings.FetchSpeed
	walk.caught = run + 0.1 < air
	walk.throwDistance = distance
	walk.ballLanding = ground
	local ball = PropModels.loose("Ball", from, workspace)
	walk.ball = ball
	local seconds = Throwing.fly(ball, from, CFrame.new(ground + Vector3.new(0, 0.35, 0)), {
		spin = 2,
		hops = if walk.caught then 0 else 2,
	})
	walk.ballDownAt = os.clock() + seconds
	Sounds.at("Squeak", ball)
	setMode(walk, "Fetch")
	Dogs.bark(walk.dog)
end

-- Into the dog's mouth (welded to its jaw).
local function grabBall(walk: Walk)
	local ball = walk.ball
	local mouth = Dogs.mouth(walk.dog)
	if not ball or not mouth then
		return
	end
	ball.Anchored = false
	ball.CFrame = mouth.WorldCFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = mouth.Parent :: BasePart
	weld.Part1 = ball
	weld.Parent = ball
	Sounds.at("Squeak", ball)
	if walk.caught then
		Dogs.hop(walk.dog, 1.6, 0.4)
		fx("Catch", ball.Position)
	end
	setMode(walk, "Return")
end

local function fetched(walk: Walk)
	local ball = walk.ball
	walk.ball = nil
	if ball then
		ball:Destroy()
	end
	walk.fetches += 1
	local base = settings.FetchTip + settings.FetchTipPerStud * walk.throwDistance
	if walk.caught then
		tip(walk, base * settings.CatchMultiplier, `Caught it! {math.floor(walk.throwDistance)} studs`)
	else
		tip(walk, base, `Fetch! {math.floor(walk.throwDistance)} studs`)
	end
	if walk.fetches >= settings.Fetches then
		walk.stage = "Home"
		setMode(walk, "Heel")
		leash(walk)
		walk.walked = 0
		walk.kit.notify(walk.job, `Good game! Now walk {walk.name} home.`)
		setTitle(walk, `Walk {walk.name} home`, walk.job.house.door.Position)
	else
		setMode(walk, "Wait")
		throwBall(walk)
	end
end

throwBall = function(walk: Walk)
	local held = Carry.prop(walk.job.player, "Ball")
	if not held then
		return
	end
	walk.held = held
	table.insert(walk.job.props, held)
	Throwing.set(walk.job.player, {
		kind = "Ball",
		range = settings.ThrowStuds,
		target = nil,
		onThrow = function(landing: Vector3, from: CFrame)
			thrown(walk, landing, from)
		end,
	})
end

-- The dog's brain (every frame) ---------------------------------------------------------

local function heel(walk: Walk, dt: number, feet: Vector3, root: BasePart)
	local dog = walk.dog
	local ahead = flat(root.CFrame.LookVector)
	ahead = if ahead.Magnitude > 0.1 then ahead.Unit else dog.heading
	local right = Vector3.new(-ahead.Z, 0, ahead.X)
	local spot = feet + right * HEEL_SIDE - ahead * HEEL_BACK
	local gap = flat(spot - dog.position).Magnitude
	if gap > TELEPORT_STUDS then
		Dogs.teleport(dog, Dogs.groundAt(spot, 4) or spot)
		return
	end
	local moving = flat(root.AssemblyLinearVelocity).Magnitude > 2
	walk.still = if moving then 0 else walk.still + dt
	if gap > 1.2 then
		Dogs.go(dog, spot, math.clamp(gap * 5, 6, if gap > 8 then settings.CatchUpSpeed else settings.HeelSpeed))
		Dogs.state(dog, if dog.moving > 18 then "Run" else "Trot")
	else
		Dogs.go(dog, nil)
		Dogs.lookAt(dog, feet + ahead * 6)
		Dogs.state(dog, if walk.still > SIT_AFTER then "Sit" elseif walk.still > SNIFF_AFTER then "Sniff" else "Idle")
	end
end

local function brain(walk: Walk, dt: number)
	local dog = walk.dog
	local player = walk.job.player
	local root = CharacterUtil.getRoot(player)
	if not root then
		Dogs.go(dog, nil)
		return
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	local mode = walk.mode
	if mode == "Heel" then
		heel(walk, dt, feet, root)
	elseif mode == "Pull" then
		local critter = walk.critter
		local toward = if critter then flat(critter.Position - feet) else dog.heading
		toward = if toward.Magnitude > 0.1 then toward.Unit else dog.heading
		Dogs.go(dog, feet + toward * (settings.LeashStuds - 1), 30)
		Dogs.lookAt(dog, if critter then critter.Position else feet + toward * 20)
		Dogs.state(dog, "Pull")
	elseif mode == "Poop" then
		Dogs.go(dog, nil)
		Dogs.state(dog, "Poop")
	elseif mode == "Bolt" then
		local now = os.clock()
		local away = flat(dog.position - feet)
		if away.Magnitude < 14 and away.Magnitude > 0.1 and now >= walk.dodgeNext then
			-- Too close: dart off to the side and away.
			local side = Vector3.new(-away.Z, 0, away.X) * (if rng:NextNumber() < 0.5 then -1 else 1)
			walk.boltGoal = openSpot(dog.position, (away.Unit + side.Unit * 0.7).Unit, 18)
			walk.boltNext = now + 2.2
			walk.dodgeNext = now + settings.BoltDodgeSeconds
		elseif now >= walk.boltNext or not walk.boltGoal then
			local angle = rng:NextNumber(0, math.pi * 2)
			walk.boltGoal =
				openSpot(dog.position, Vector3.new(math.cos(angle), 0, math.sin(angle)), rng:NextNumber(14, 24))
			walk.boltNext = now + rng:NextNumber(2, 3)
		end
		-- They tire as they go.
		local tired = math.clamp(1 - (walk.boltUntil - Timing.now()) / settings.BoltSeconds, 0, 1)
		Dogs.go(dog, walk.boltGoal, settings.BoltSpeed + (settings.BoltTiredSpeed - settings.BoltSpeed) * tired)
		Dogs.state(dog, if tired > 0.6 then "Trot" else "Run")
	elseif mode == "Fetch" then
		local landing = walk.ballLanding
		if landing then
			Dogs.go(dog, landing, settings.FetchSpeed)
			Dogs.state(dog, "Run")
			local close = flat(landing - dog.position).Magnitude < 1.8
			if close and (os.clock() >= walk.ballDownAt or walk.caught) then
				if walk.caught and os.clock() < walk.ballDownAt - 0.05 then
					Dogs.go(dog, nil) -- wait for it under the ball
				else
					grabBall(walk)
				end
			end
		end
	elseif mode == "Return" then
		local ahead = flat(root.CFrame.LookVector)
		ahead = if ahead.Magnitude > 0.1 then ahead.Unit else Vector3.new(0, 0, -1)
		local spot = feet + ahead * 2.6
		Dogs.go(dog, spot, settings.ReturnSpeed)
		Dogs.state(dog, "Carry")
		if flat(spot - dog.position).Magnitude < 1.5 then
			fetched(walk)
		end
	elseif mode == "Wait" then
		local ahead = flat(root.CFrame.LookVector)
		ahead = if ahead.Magnitude > 0.1 then ahead.Unit else Vector3.new(0, 0, -1)
		local spot = feet + ahead * 3
		if flat(spot - dog.position).Magnitude > 1.5 then
			Dogs.go(dog, spot, settings.HeelSpeed)
			Dogs.state(dog, "Trot")
		else
			Dogs.go(dog, nil)
			Dogs.lookAt(dog, feet)
			Dogs.state(dog, "Beg")
		end
	end
end

-- The job -------------------------------------------------------------------------------

local function cleanUp(walk: Walk)
	if walks[walk.job.player] == walk then
		walks[walk.job.player] = nil
	end
	endTug(walk)
	Throwing.clear(walk.job.player)
	if Gestures.posing(walk.job.player) == "Leash" or Gestures.posing(walk.job.player) == "Tug" then
		Gestures.pose(walk.job.player, nil)
	end
	local leftovers: { Instance? } = { walk.critter, walk.ball, walk.hand, walk.beam }
	for index = 1, 4 do
		local thing = leftovers[index]
		if thing then
			thing:Destroy()
		end
	end
	local mess = walk.poop
	if mess then
		task.delay(10, function()
			mess:Destroy()
		end)
	end
	if walk.dog.alive and not walk.keepDog then
		Dogs.remove(walk.dog)
	end
end

function DogWalk.begin(job: Job, kit: Kit)
	local park = kit.park()
	if not park then
		kit.fail(job, "The park is closed today.")
		return
	end
	job.endsAt = job.startedAt + settings.TimeLimitSeconds
	local door = job.house.door
	local outward = flat(door.CFrame.LookVector).Unit
	local floor = door.Position.Y - door.Size.Y / 2
	local feet = Vector3.new(door.Position.X, floor, door.Position.Z)
		+ outward * 3
		+ flat(door.CFrame.RightVector).Unit * 1.5
	local name = PET_NAMES[(job.house.id % #PET_NAMES) + 1]
	local dog = Dogs.spawn("Pet", CFrame.lookAt(feet, feet + outward), name)
	local walk: Walk = {
		job = job,
		kit = kit,
		dog = dog,
		name = name,
		stage = "ToPark",
		mode = "Heel",
		modeSince = os.clock(),
		beam = nil,
		hand = nil,
		walked = 0,
		nextDistraction = rng:NextNumber(settings.DistractionGapSeconds[1], settings.DistractionGapSeconds[2]),
		distractionsLeft = rng:NextInteger(settings.Distractions[1], settings.Distractions[2]),
		critter = nil,
		tug = nil,
		boltUntil = 0,
		boltGoal = nil,
		boltNext = 0,
		dodgeNext = 0,
		fetches = 0,
		ball = nil,
		ballLanding = nil,
		ballDownAt = 0,
		caught = false,
		throwDistance = 0,
		held = nil,
		poopIn = if rng:NextNumber() < settings.PoopChance then rng:NextNumber(8, 28) else nil,
		poop = nil,
		fine = 0,
		still = 0,
		lastTick = os.clock(),
		lastSent = 0,
		keepDog = false,
	}
	walks[job.player] = walk
	dog.brain = function(_dog: Dogs.Dog, dt: number)
		brain(walk, dt)
	end
	table.insert(job.cleanup, function()
		cleanUp(walk)
	end)
	leash(walk)
	Dogs.bark(dog)
	job.travel = (park - door.Position).Magnitude * 2
	kit.notify(job, `Walk {name} to the park for a game of fetch. Watch out for squirrels!`)
	setTitle(walk, `Walk {name} to the park`, park)
end

local function finishWalk(walk: Walk)
	local job, kit = walk.job, walk.kit
	if kit.tooFast(job) then
		kit.fail(job, "Job voided: that was impossibly fast.")
		return
	end
	-- They run up to the door and in; the resident pays (DoorKnock's thank-you).
	local dog = walk.dog
	walk.keepDog = true
	dog.brain = nil
	unleash(walk, false)
	Dogs.go(dog, Thanks.doorstep(job.house.door).Position - Vector3.new(0, 3, 0), 16)
	Dogs.state(dog, "Trot")
	task.delay(2.5, function()
		if dog.alive then
			Dogs.remove(dog)
		end
	end)
	job.pay = math.floor(job.pay * math.max(0, 1 - walk.fine) + 0.5)
	kit.finish(job, if walk.fine > 0 then "Dog walked (messy)" else "Dog walked")
end

function DogWalk.tick(job: Job, kit: Kit)
	local walk = walks[job.player]
	if not walk or walk.job ~= job then
		return
	end
	local now = os.clock()
	local dt = now - walk.lastTick
	walk.lastTick = now
	local player = job.player
	local root = CharacterUtil.getRoot(player)
	if not root then
		return
	end
	checkMess(walk)
	local mode = walk.mode
	if mode == "Pull" then
		local tug = walk.tug
		if tug then
			tug.meter += settings.Tug.PullPerSecond * dt
			walk.lastSent = os.clock()
			sendTug(walk)
			if tug.meter <= 0 then
				heldBack(walk)
			elseif tug.meter >= 1 then
				bolted(walk)
			elseif Timing.now() >= tug.endsAt then
				if tug.meter < 0.5 then
					heldBack(walk)
				else
					bolted(walk)
				end
			end
		end
		return
	elseif mode == "Bolt" then
		local feet = root.Position - Vector3.new(0, 3, 0)
		if flat(feet - walk.dog.position).Magnitude <= settings.CatchStuds then
			caughtUp(walk)
		elseif Timing.now() >= walk.boltUntil then
			kit.fail(job, `{walk.name} ran home without you. No pay for that walk.`)
		else
			job.targets = { walk.dog.position }
			kit.guide(job)
		end
		return
	elseif mode == "Poop" then
		if now - walk.modeSince >= POOP_SECONDS then
			poop(walk)
			setMode(walk, "Heel")
		end
		return
	elseif mode ~= "Heel" then
		return
	end

	-- On the leash: count walking time toward the next squirrel (and the poo).
	local moving = flat(root.AssemblyLinearVelocity).Magnitude > 4
	if moving and walk.stage ~= "Fetch" then
		walk.walked += dt
		local poopIn = walk.poopIn
		if poopIn then
			walk.poopIn = poopIn - dt
			if poopIn - dt <= 0 then
				walk.poopIn = nil
				setMode(walk, "Poop")
				return
			end
		end
		if walk.distractionsLeft > 0 and walk.walked >= walk.nextDistraction then
			distraction(walk)
			return
		end
	end
	if walk.stage == "ToPark" then
		local park = kit.park()
		if park and flat(root.Position - park).Magnitude <= settings.ParkStuds then
			walk.stage = "Fetch"
			unleash(walk, false)
			setMode(walk, "Wait")
			throwBall(walk)
			kit.notify(job, `Fetch time! Click where to throw the ball for {walk.name} ({settings.Fetches} throws).`)
			setTitle(walk, `Play fetch with {walk.name}`, park)
		end
	elseif walk.stage == "Home" then
		if kit.arrived(job, job.house.door.Position) then
			finishWalk(walk)
		end
	end
end

function DogWalk.start()
	remotes.TugTap:onServer(function(player: Player)
		local walk = walks[player]
		local tug = walk and walk.tug
		if not walk or not tug or not tapLimiter:allow(player) then
			return
		end
		tug.meter -= settings.Tug.PerTap
		if tug.meter <= 0 then
			heldBack(walk)
		elseif os.clock() - walk.lastSent >= TUG_SEND_SECONDS then
			walk.lastSent = os.clock()
			sendTug(walk)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local walk = walks[player]
		if walk then
			cleanUp(walk)
		end
	end)
end

return DogWalk
