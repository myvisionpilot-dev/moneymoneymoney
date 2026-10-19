--!strict
-- The pay-boost town events: switch a boost on (EventBoosts) for the event's length, off at the
-- end. GOLDEN HOUR (legal jobs pay double), DOUBLE XP (run levels fill twice as fast) and TIP
-- FRENZY (customers tip big on top: burgers, taxis, car washes, hot dogs, deliveries, gigs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EventBoosts = require(script.Parent.Parent.EventBoosts)
local TownEvent = require(script.Parent.TownEvent)

local events = Config.Events

local function boost(
	id: string,
	title: string,
	seconds: number,
	detail: string,
	set: (on: boolean) -> ()
): TownEvent.TownEvent
	return {
		id = id,
		title = title,
		seconds = seconds,
		canStart = function(): boolean
			return true
		end,
		start = function(ctx: TownEvent.Context)
			set(true)
			ctx.announce(detail, nil)
		end,
		tick = function() end,
		stop = function()
			set(false)
		end,
	}
end

return {
	boost(
		"GoldenHour",
		"GOLDEN HOUR",
		events.GoldenHour.Seconds,
		`Legal jobs pay {events.GoldenHour.Multiplier}x!`,
		function(on: boolean)
			EventBoosts.legalPay = if on then events.GoldenHour.Multiplier else 1
		end
	),
	boost("DoubleXp", "DOUBLE XP", events.DoubleXp.Seconds, `{events.DoubleXp.Multiplier}x XP!`, function(on: boolean)
		EventBoosts.xp = if on then events.DoubleXp.Multiplier else 1
	end),
	boost("TipFrenzy", "TIP FRENZY", events.TipFrenzy.Seconds, "Customers tip big!", function(on: boolean)
		EventBoosts.tipShare = if on then events.TipFrenzy.TipShare else 0
	end),
} :: { TownEvent.TownEvent }
