--!strict
-- The five door jobs. DoorKnock runs the knock-and-offer flow; each handler here says what
-- the job is called and what the player has to do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Residents = require(script.Parent.Parent.Residents)

export type Kind = "Chore" | Residents.Wildcard

export type House = {
	id: number,
	part: BasePart,
	tier: number,
	door: BasePart,
	backDoor: Attachment?,
	choreSpots: { Attachment },
	resident: Residents.Resident,
	restUntil: number,
}

export type Job = {
	player: Player,
	house: House,
	kind: Kind,
	startedAt: number,
	endsAt: number,
	stage: number,
	targets: { Vector3 }, -- where to go next; the first gets the guide beam
	prompts: { ProximityPrompt },
	props: { BasePart },
	pay: number,
	heat: number,
	heatApplied: boolean,
	travel: number, -- straight-line studs the job needs, for the speed check
}

-- What DoorKnock lets a handler do.
export type Kit = {
	guide: (job: Job) -> (),
	finish: (job: Job, message: string) -> (),
	fail: (job: Job, reason: string) -> (),
	addHeat: (job: Job) -> (),
	notify: (job: Job, text: string) -> (),
	prompt: (
		job: Job,
		parent: Instance,
		action: string,
		holdSeconds: number,
		onDone: (prompt: ProximityPrompt) -> ()
	) -> ProximityPrompt,
	carry: (job: Job, name: string, size: Vector3, color: Color3) -> (),
	arrived: (job: Job, position: Vector3) -> boolean,
	tooFast: (job: Job) -> boolean,
	park: () -> Vector3?,
	alley: () -> Vector3?,
	otherDoor: (house: House) -> Vector3?,
	breakInHold: (player: Player) -> number,
}

export type Handler = {
	legal: boolean,
	title: (house: House) -> string,
	begin: (job: Job, kit: Kit) -> (),
	tick: ((job: Job, kit: Kit) -> ())?,
}

local CHORE_TITLES: { [Residents.Chore]: string } = {
	Mow = "Mow the lawn",
	Bins = "Take out the bins",
	CarWash = "Wash the car",
}

local CHORE_ACTIONS: { [Residents.Chore]: string } = {
	Mow = "Mow",
	Bins = "Grab bin",
	CarWash = "Scrub",
}

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
			return CHORE_TITLES[house.resident.chore]
		end,
		begin = function(job: Job, kit: Kit)
			local action = CHORE_ACTIONS[job.house.resident.chore]
			for _, spot in job.house.choreSpots do
				local position = spot.WorldPosition
				table.insert(job.targets, position)
				kit.prompt(job, spot, action, Config.Paths.Doors.ChoreHoldSeconds, function(prompt: ProximityPrompt)
					prompt:Destroy()
					local index = table.find(job.targets, position)
					if index then
						table.remove(job.targets, index)
					end
					if #job.targets == 0 then
						kit.finish(job, "Chore done!")
					else
						kit.guide(job)
					end
				end)
			end
			if #job.targets == 0 then
				kit.finish(job, "Chore done!")
			else
				kit.guide(job)
			end
		end,
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
			kit.carry(job, "Dog", Vector3.new(1.2, 1.2, 2), Color3.fromRGB(150, 100, 60))
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
				arriveAndFinish(job, kit, "The dog had a lovely time!")
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
			kit.carry(job, "Letter", Vector3.new(1.2, 0.2, 1.6), Color3.fromRGB(245, 240, 225))
			job.targets = { target }
			job.travel = (target - job.house.door.Position).Magnitude
			kit.guide(job)
		end,
		tick = function(job: Job, kit: Kit)
			arriveAndFinish(job, kit, "Letter delivered!")
		end,
	},

	WalletSwipe = {
		legal = false,
		title = function(_house: House): string
			return "Swipe their wallet"
		end,
		begin = function(job: Job, kit: Kit)
			kit.addHeat(job)
			kit.finish(job, "Wallet swiped!")
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
			kit.carry(job, "ShadyPackage", Vector3.new(1.4, 1, 1.4), Color3.fromRGB(40, 40, 45))
			job.targets = { alley }
			job.travel = (alley - job.house.door.Position).Magnitude
			kit.notify(job, "Get it to the alley. Watch out for the police!")
			kit.guide(job)
		end,
		tick = function(job: Job, kit: Kit)
			arriveAndFinish(job, kit, "Package dropped. Nobody saw a thing.")
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
				kit.finish(job, "In and out. Nice haul!")
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
