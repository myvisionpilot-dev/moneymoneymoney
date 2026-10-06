--!strict
-- The interface every town event implements (EventService runs them, one at a time).

export type Context = {
	endsAt: number,
	tierMultiplier: number, -- pay scales with the quota like jobs
	-- Everyone's banner (and the spot to mark, if any).
	announce: (detail: string, marker: Vector3?) -> (),
	-- One player's own banner instead of everyone's (nil detail: back to everyone's).
	announceTo: (player: Player, detail: string?, marker: Vector3?) -> (),
	finish: () -> (), -- ends the event now
}

export type TownEvent = {
	id: string,
	title: string,
	seconds: number,
	canStart: () -> boolean,
	start: (ctx: Context) -> (), -- may yield
	tick: () -> (), -- every EventService tick while it's on (often nothing to do)
	stop: () -> (), -- clean up, however it ended
}

return {}
