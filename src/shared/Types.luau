--!strict
-- Shared types for run state and remote payloads.

export type Phase = "Waiting" | "Intro" | "Quota" | "Intermission" | "Decision" | "Results" | "Ended"
export type PlayerStatus = "Active" | "CashedOut" | "Finished" | "Left"
export type Decision = "CashOut" | "Continue"
export type NoticeKind = "Info" | "Good" | "Bad"
export type EndReason = "CashedOut" | "Failed"

export type PlayerRow = {
	userId: number,
	name: string,
	carried: number,
	deposited: number,
	bagCapacity: number,
	status: PlayerStatus,
	decided: boolean,
	heat: number, -- 0 to Police.MaxHeat; whole numbers are stars
	hiding: boolean, -- in a bush
	spotted: boolean, -- in a bush, but a cop is close enough to see you
	jailedUntil: number, -- 0 when free
	stolen: number, -- total stolen from teammates this run
	rideLevel: number, -- 0 = no ride bought
	riding: boolean,
	bounty: number, -- what a teammate earns for arresting you (0 = can't be arrested)
	boosts: { [string]: number }, -- BoostId -> when it wears off (server time)
}

-- A quota twist (Config.Twists), as the HUD shows it.
export type TwistView = {
	id: string,
	title: string,
	detail: string,
}

export type RunSnapshot = {
	phase: Phase,
	quotaIndex: number,
	target: number,
	progress: number,
	phaseEndsAt: number, -- workspace:GetServerTimeNow() time
	isEndless: boolean,
	teamDeposited: number,
	twists: { TwistView }, -- this quota's twists (none in quota 1)
	players: { PlayerRow },
}

export type Notice = {
	text: string,
	kind: NoticeKind,
}

export type PennyLine = {
	text: string,
}

-- Where to go for your current job. Every job (delivery, chores, errands...) uses this.
export type JobGuide = {
	title: string,
	markers: { Vector3 }, -- the first one gets the guide beam
	endsAt: number,
	pay: number,
}

export type DoorOfferOption = {
	slot: number, -- 1 or 2
	title: string,
	detail: string,
	legal: boolean,
	pay: number,
	heat: number,
}

export type DoorOffer = {
	residentName: string,
	greeting: string,
	options: { DoorOfferOption },
	expiresAt: number,
}

export type UpgradeId = "Bag" | "Lockpick" | "Ride"
export type BoostId = "Energy" | "Disguise" | "Candy" | "Gloves" | "Scanner"
export type BlasterId = "Zapper" | "MegaZapper"
export type ShopId = "Convenience" | "Clothes" | "Hardware" | "Garage" | "Guns"
export type ShopItemKind = "Upgrade" | "Boost" | "Blaster"

export type ShopItem = {
	id: string, -- an UpgradeId, BoostId or BlasterId
	kind: ShopItemKind,
	title: string,
	detail: string, -- what it does (upgrades: what you have -> what's next)
	status: string?, -- a short line such as "Level 1/3", "Active 3:12" or "Yours"
	price: number?, -- nil when there's nothing left to buy
}

export type ShopState = {
	shop: ShopId,
	title: string,
	note: string,
	items: { ShopItem },
	locked: string?, -- set while the shop isn't open yet (the items still show)
}

-- A blaster shot, for everyone's screen: the beam, and who (if anyone) got stunned.
export type BlasterFx = {
	from: Vector3,
	to: Vector3,
	hit: Model?,
	stunSeconds: number,
}

export type RaceState = "Gathering" | "Countdown" | "Racing"

-- Sent to each racer; nil means you're not in a race.
export type RaceUpdate = {
	state: RaceState,
	racers: number,
	solo: boolean, -- a solo race is a time trial against the par times
	startsAt: number, -- Gathering: when the countdown begins; otherwise when the race starts (GO)
	endsAt: number, -- Racing: the time limit
	checkpoint: number, -- checkpoints passed so far
	total: number, -- checkpoints in the whole race (every lap)
	laps: number,
	place: number, -- 1 = leading
	parSeconds: { number }, -- gold, silver, bronze
}

export type Contribution = {
	userId: number,
	name: string,
	deposited: number,
	share: number,
}

export type QuotaResult = {
	quotaIndex: number,
	passed: boolean,
	target: number,
	total: number,
	contributions: { Contribution },
	nextQuotaIndex: number,
	nextTarget: number,
	endsAt: number,
	rolledOver: boolean, -- the next quota already started (no break)
}

export type DecisionPrompt = {
	quotaIndex: number,
	prizeNow: number,
	prizeIfFail: number,
	nextQuotaIndex: number,
	nextTarget: number,
	endsAt: number,
}

export type ResultRow = {
	userId: number,
	name: string,
	deposited: number,
	share: number,
	prize: number,
	status: PlayerStatus,
}

export type RunResults = {
	reason: EndReason,
	highestQuota: number,
	yourPrize: number,
	mvpUserId: number?,
	snakeUserId: number?,
	players: { ResultRow },
	endsAt: number,
}

-- Moments the client dresses up with sounds and effects. Money kinds show as a line at the
-- bottom of the screen: "+$10,000 | Customer served".
export type JuiceKind = "Paid" | "Spent" | "Lost" | "Deposited" | "BagFull" | "Sound"

export type JuiceEvent = {
	kind: JuiceKind,
	amount: number?, -- money kinds (BagFull: what didn't fit)
	label: string?, -- money kinds: a few words on what happened
	sound: string?, -- Sound: a Config.Sounds name
}

-- The pickpocket minigame: one round per zone. The needle bounces along the bar at the round's
-- speed (bar lengths per second); press while it's inside the zone.
export type PickpocketZone = {
	start: number, -- 0 to 1 along the bar
	width: number,
	speed: number,
}

export type PickpocketGame = {
	target: string, -- the pedestrian's name
	zones: { PickpocketZone },
	roundSeconds: number,
	pauseSeconds: number,
}

-- Your saved profile, as the lobby shows it.
export type DailyView = {
	text: string,
	progress: number,
	goal: number,
	reward: number, -- Cred for finishing it today (streak bonus included)
	done: boolean,
}

export type ProfileView = {
	cred: number,
	lifetimeCred: number,
	highestQuota: number,
	runs: number,
	perks: { [string]: number }, -- perk id -> level bought
	badges: { string }, -- earned badge ids
	daily: DailyView,
	streak: number, -- days in a row (0 if it lapsed)
}

export type QueueStatus = {
	count: number,
	partySize: number, -- the pad leaves once this many are on it
	departsAt: number,
	isHost: boolean, -- the first player on the pad picks the party size
	hostName: string,
}

return {}
