--!strict
-- Every tunable number in the game. Tune from playtests; never hard-code these elsewhere.

return {
	Places = {
		LobbyPlaceId = 89656922694625,
		MatchPlaceId = 80496708814164,
	},
	Match = {
		MinPlayers = 1,
		MaxPlayers = 6,
		QueueWaitSeconds = 20,
		StartingCash = 500,
		QuotaDurationSeconds = 420, -- 7 minutes
		IntermissionSeconds = 20,
		DecisionSeconds = 20,
		Quotas = { 50_000, 150_000, 300_000, 600_000, 1_000_000 },
		CashOutAfterQuota = 5,
		EndlessQuotaMultiplier = 1.6,
		CarryOverExcess = true,
		PlayerCountScale = { [1] = 0.35, [2] = 0.55, [3] = 0.70, [4] = 0.80, [5] = 0.90, [6] = 1.00 },
		FailKeepPercent = 0.25,
		IntroSeconds = 8,
		ResultsSeconds = 12,
		ArrivalTimeoutSeconds = 30, -- start without players who never arrive
		TonyWarningSeconds = { 180, 60 },
	},
	Prizes = {
		CredPerPlayerPerQuota = { 100, 250, 500, 900, 1500 },
	},
	Steal = {
		GraceSeconds = 120, -- no stealing at the start of quota 1
		Percent = 0.25, -- of the victim's carried cash
		CapPercentOfQuota = 0.10, -- max per steal
		CooldownSeconds = 45,
		RangeStuds = 8,
	},
	Police = {
		MaxHeat = 3,
		HeatDecayPerSecond = 0.02, -- while not committing crimes
		CaughtLosePercent = 0.30, -- of carried cash
		JailSeconds = 30,
	},
	Economy = {
		TierPayoutMultiplier = 2.2, -- each unlocked tier pays ~2.2x the previous
		BaseBagCapacity = 5_000, -- max carried cash before upgrades
		DepositRangeStuds = 12, -- max distance from Tony's desk
		MaxPayoutTier = 5, -- payouts stop rising after this quota
	},
	Paths = {
		Delivery = {
			BasePayout = 1_500, -- tier-1 pay per delivery
			TimeLimitSeconds = 90,
			MaxSpeedStudsPerSecond = 24, -- faster than this voids the job
			DropoffRadiusStuds = 8,
			PromptRangeStuds = 10,
			MinDropoffDistance = 60, -- skip drop-offs closer than this to the depot
		},
	},
	Security = {
		PromptsPerSecond = 3, -- per player, per prompt type
		RemotesPerSecond = 4, -- per player, per remote
	},
	Debug = {
		Enabled = false,
		TimerScale = 0.1, -- speeds up all run timers in debug
		AdminUserIds = { 1913433940 } :: { number }, -- extra debug-command accounts (TinTinTerryy3)
		StudioAutoStartSeconds = 10, -- Studio test starts this long after the first player joins
	},
}
