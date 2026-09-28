--!strict
-- Shapes shared by the door-knock modules (DoorKnock, DoorJobs, Chores), kept apart so they
-- can use each other's types without requiring each other.

local Residents = require(script.Parent.Parent.Residents)

export type Kind = "Chore" | Residents.Wildcard

-- The chore props come from the map: the front lawn, two wheelie bins, the kerb they go out
-- to, and the driveway spot a car gets washed on.
export type House = {
	id: number,
	part: BasePart,
	tier: number,
	door: BasePart,
	backDoor: Attachment?,
	lawn: BasePart?,
	bins: { BasePart },
	kerb: Attachment?,
	carSpot: Attachment?,
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
	props: { Instance }, -- removed when the job ends
	pieces: { BasePart }, -- chore work still to do (long grass, bins, dirt)
	placed: { BasePart }, -- chore work left in the world for a while (bins at the kerb)
	carried: BasePart?, -- what the player is holding right now
	cleanup: { () -> () }, -- run when the job ends, however it ends
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
	carry: (job: Job, name: string, size: Vector3, color: Color3, offset: CFrame?) -> BasePart?,
	root: (job: Job) -> BasePart?,
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

return {}
