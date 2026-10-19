--!strict
-- What the pay-boost town events have switched on right now (Events/PayBoosts sets them, and
-- puts them back when the event ends). PayNotice and LevelService read them.

return {
	legalPay = 1, -- GOLDEN HOUR: every legal job pays this much more
	xp = 1, -- DOUBLE XP: run levels fill this much faster
	tipShare = 0, -- TIP FRENZY: customers tip this share of the pay on top
}
