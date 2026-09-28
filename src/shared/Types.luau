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
}

export type RunSnapshot = {
	phase: Phase,
	quotaIndex: number,
	target: number,
	progress: number,
	phaseEndsAt: number, -- workspace:GetServerTimeNow() time
	isEndless: boolean,
	teamDeposited: number,
	players: { PlayerRow },
}

export type Notice = {
	text: string,
	kind: NoticeKind,
}

export type TonyLine = {
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

export type ShopItem = {
	id: UpgradeId,
	title: string,
	level: number, -- 0 = not bought
	maxLevel: number,
	current: string, -- what you have now, e.g. "$5,000 bag"
	nextEffect: string?, -- nil at max level
	nextPrice: number?,
}

export type ShopState = {
	items: { ShopItem },
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
	owned: { string }, -- cosmetic ids
	equipped: { [string]: string }, -- slot -> cosmetic id ("" = nothing)
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
