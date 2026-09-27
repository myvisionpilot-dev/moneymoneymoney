--!strict
-- The interface every money path (job or crime) implements.

export type Context = {
	isOpen: () -> boolean, -- a quota is running and this path is unlocked
	tier: () -> number, -- payout tier for the current quota
	payMultiplier: () -> number, -- TierPayoutMultiplier ^ (tier - 1)
	canWork: (player: Player) -> boolean, -- active in the run, alive, not in jail
	isBusy: (player: Player) -> boolean, -- already on a job from any path
}

export type MoneyPath = {
	id: string,
	displayName: string,
	unlockQuota: number,
	legal: boolean, -- the path's main style; door knocks offer both
	init: (context: Context) -> (),
	start: (player: Player, source: Instance?) -> (boolean, string?),
	complete: (player: Player) -> (boolean, string?),
	fail: (player: Player, reason: string) -> (), -- also cancels offers; no-op without a job
	payout: (player: Player, tier: number) -> number,
	hasJob: (player: Player) -> boolean,
	cancelAll: (reason: string) -> (),
}

return {}
