--!strict
-- The interface every money path (job or crime) implements.

export type Context = {
	isOpen: () -> boolean, -- a quota is running and this path is unlocked
	tier: () -> number, -- payout tier for the current quota
	canWork: (player: Player) -> boolean, -- active in the run and alive
}

export type MoneyPath = {
	id: string,
	displayName: string,
	unlockQuota: number,
	legal: boolean,
	init: (context: Context) -> (),
	start: (player: Player) -> (boolean, string?),
	complete: (player: Player) -> (boolean, string?),
	fail: (player: Player, reason: string) -> (),
	payout: (player: Player, tier: number) -> number,
	cancelAll: (reason: string) -> (),
}

return {}
