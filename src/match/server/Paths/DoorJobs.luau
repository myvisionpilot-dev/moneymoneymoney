--!strict
-- The door jobs. DoorKnock runs the knock-and-offer flow; each handler here says what the job
-- is called and what the player has to do. Chores (mow, bins, car wash) live in Chores.

local Chores = require(script.Parent.Chores)
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
			return "Walk the dog to the park"
		end,
		begin = function(job: Job, kit: Kit)
			local park = kit.park()
			if not park then
				kit.fail(job, "The park is closed today.")
				return
			end
			kit.carry(job, "Dog")
			job.targets = { park }
			job.travel = (park - job.house.door.Position).Magnitude * 2
			kit.guide(job)
		end,
		tick = function(job: Job, kit: Kit)
			if job.stage == 1 then
				if kit.arrived(job, job.targets[1]) then
					job.stage = 2
					job.targets = { job.house.door.Position }
					kit.notify(job, "Good dog! Now take them home.")
					kit.guide(job)
				end
			else
				arriveAndFinish(job, kit, "Dog walked to the park")
			end
		end,
	},

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
			kit.carry(job, "Letter")
			job.targets = { target }
			job.travel = (target - job.house.door.Position).Magnitude
			kit.guide(job)
		end,
		tick = function(job: Job, kit: Kit)
			arriveAndFinish(job, kit, "Letter delivered next door")
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
			kit.prompt(job, backDoor, "Break in", kit.breakInHold(job.player), function(prompt: ProximityPrompt)
				prompt:Destroy()
				kit.addHeat(job)
				kit.finish(job, "House broken into")
			end)
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

return DoorJobs
