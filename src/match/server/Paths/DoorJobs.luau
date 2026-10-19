--!strict
-- The door jobs. DoorKnock runs the knock-and-offer flow; each handler here says what the job
-- is called and what the player has to do. Chores (mow, bins, car wash) live in Chores, the dog
-- walk in DogWalk; letters are deliveries (Courier).

local Chores = require(script.Parent.Chores)
local Courier = require(script.Parent.Courier)
local DogWalk = require(script.Parent.DogWalk)
local DoorTypes = require(script.Parent.DoorTypes)

export type Kind = DoorTypes.Kind
export type House = DoorTypes.House
export type Job = DoorTypes.Job
export type Kit = DoorTypes.Kit
export type Handler = DoorTypes.Handler

-- Shared ending for travel jobs: arrive, pass the speed check, get paid.
local function arriveAndFinish(job: Job, kit: Kit, message: string)
	if not kit.arrived(job, job.targets[1]) then
		return
	end
	if kit.tooFast(job) then
		kit.fail(job, "Job voided: that was impossibly fast.")
	else
		kit.finish(job, message)
	end
end

local handlers: { [Kind]: Handler } = {
	Chore = {
		legal = true,
		title = function(house: House): string
			return Chores.title(house.resident.chore)
		end,
		begin = Chores.begin,
		tick = Chores.tick,
	},
	DogWalk = {
		legal = true,
		title = function(_house: House): string
			return "Walk the dog"
		end,
		begin = DogWalk.begin,
		tick = DogWalk.tick,
	},

	-- A letter for another house: onto their doormat (walked up or thrown).
	Letter = {
		legal = true,
		title = function(_house: House): string
			return "Deliver a letter"
		end,
		begin = function(job: Job, kit: Kit)
			local target = kit.otherDoor(job.house)
			if not target then
				kit.fail(job, "Nobody to send it to.")
				return
			end
			job.travel = (target - job.house.door.Position).Magnitude
			local drop: Courier.Drop? = nil
			local function guide()
				if drop then
					job.targets = { Courier.marker(drop) }
					kit.guide(job)
				end
			end
			drop = Courier.begin(job.player, {
				kind = "Letter",
				near = target,
				onDelivered = function(how: Courier.How)
					local delivered = drop
					if not delivered then
						return
					end
					if kit.tooFast(job) then
						kit.fail(job, "Job voided: that was impossibly fast.")
						return
					end
					Courier.reward(delivered, how, job.pay, "Letter delivered", "door job: Letter", nil)
					kit.close(job)
				end,
				onBroken = function() end, -- letters don't break
				onMoved = guide,
			})
			local started = drop
			if not started then
				kit.fail(job, "Your hands are full.")
				return
			end
			table.insert(job.cleanup, function()
				Courier.stop(started, false)
			end)
			guide()
			kit.notify(job, "Take the letter to the marked house. Throw it onto the mat for a bonus!")
			if Courier.hasGuard(started) then
				kit.notify(job, "Beware of the dog at that house! Throw it from the path.")
			end
		end,
	},

	WalletSwipe = {
		legal = false,
		title = function(_house: House): string
			return "Swipe their wallet"
		end,
		begin = function(job: Job, kit: Kit)
			kit.addHeat(job)
			kit.finish(job, "Resident's wallet swiped")
		end,
	},

	ShadyPackage = {
		legal = false,
		title = function(_house: House): string
			return "Run a shady package"
		end,
		begin = function(job: Job, kit: Kit)
			local alley = kit.alley()
			if not alley then
				kit.fail(job, "The alley drop is gone.")
				return
			end
			kit.addHeat(job) -- the police notice you as soon as you take it
			kit.carry(job, "ShadyPackage")
			job.targets = { alley }
			job.travel = (alley - job.house.door.Position).Magnitude
			kit.notify(job, "Get it to the alley. Watch out for the police!")
			kit.guide(job)
		end,
		tick = function(job: Job, kit: Kit)
			arriveAndFinish(job, kit, "Shady package dropped off")
		end,
	},

	-- A tip-off: they're away. The arrow points at the back door; getting in ends the job (the cash
	-- is inside: Paths/BreakIn).
	BreakIn = {
		legal = false,
		title = function(_house: House): string
			return "Break in while they're away"
		end,
		begin = function(job: Job, kit: Kit)
			local backDoor = job.house.backDoor
			if not backDoor then
				kit.fail(job, "This house has no back door.")
				return
			end
			job.targets = { backDoor.WorldPosition }
			kit.notify(job, "Sneak in the back door!")
			kit.guide(job)
		end,
	},
}

local DoorJobs = {}

function DoorJobs.handler(kind: Kind): Handler
	return handlers[kind]
end

function DoorJobs.title(kind: Kind, house: House): string
	return handlers[kind].title(house)
end

function DoorJobs.isLegal(kind: Kind): boolean
	return handlers[kind].legal
end

function DoorJobs.exists(kind: string): boolean
	for known in handlers do
		if known == kind then
			return true
		end
	end
	return false
end

return DoorJobs
