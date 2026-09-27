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

export type DeliveryJob = {
	dropoffPosition: Vector3,
	endsAt: number,
	payout: number,
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
