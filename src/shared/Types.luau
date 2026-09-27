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
	hiding: boolean,
	jailedUntil: number, -- 0 when free
	stolen: number, -- total stolen from teammates this run
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

export type UpgradeId = "Bag" | "Lockpick"

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

export type QueueStatus = {
	count: number,
	partySize: number, -- the pad leaves once this many are on it
	departsAt: number,
	isHost: boolean, -- the first player on the pad picks the party size
	hostName: string,
}

return {}
