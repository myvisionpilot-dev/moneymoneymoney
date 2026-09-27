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
		HoldSeconds = 0.5,
	},
	Police = {
		MaxHeat = 3,
		HeatDecayPerSecond = 0.02, -- while not committing crimes
		CaughtLosePercent = 0.30, -- of carried cash
		JailSeconds = 30,
		CopsPerStar = 1,
		MaxCops = 6, -- across the whole town
		CopSpeed = 30, -- studs/s: faster than walking (25), slower than sprinting (35)
		TagRangeStuds = 4,
		RepathSeconds = 1,
		MinSpawnStuds = 60, -- police appear at the nearest patrol point at least this far from you
	},
	Heat = {
		DecayDelaySeconds = 20, -- heat starts draining this long after your last crime
		HidingDecayMultiplier = 4,
		Steal = 0.5,
		Pickpocket = 0.5,
		WalletSwipe = 0.5,
		ShadyPackage = 1,
		BreakIn = { 1, 1.5, 2 }, -- by house tier
		StoreRobbery = 2,
	},
	Economy = {
		TierPayoutMultiplier = 2.2, -- each unlocked tier pays ~2.2x the previous
		BaseBagCapacity = 5_000, -- max carried cash before upgrades
		DepositRangeStuds = 12, -- max distance from Tony's desk
		MaxPayoutTier = 5, -- payouts stop rising after this quota
	},
	Paths = {
		Unlocks = { -- quota each money path opens at
			Delivery = 1,
			DoorKnock = 1,
			Pickpocket = 1,
			StoreRobbery = 2,
		},
		Delivery = {
			BasePayout = 1_500, -- tier-1 pay per delivery
			TimeLimitSeconds = 90,
			MaxSpeedStudsPerSecond = 40, -- faster than this voids the job; keep above Movement.SprintSpeed
			DropoffRadiusStuds = 8,
			PromptRangeStuds = 10,
			MinDropoffDistance = 60, -- skip drop-offs closer than this to the depot
		},
		Doors = {
			HouseRestSeconds = 90, -- after a knock, that house won't answer for this long
			OfferSeconds = 15, -- time to pick an offer
			KnockRangeStuds = 8,
			JobTimeLimitSeconds = 90,
			TargetRadiusStuds = 7, -- how close counts as arriving
			ChoreHoldSeconds = 2,
			BaseBreakInHoldSeconds = 6, -- lockpick upgrades shorten this
			MaxSpeedStudsPerSecond = 40, -- faster than this voids a travel job; keep above Movement.SprintSpeed
			MinLetterDistance = 100,
			HouseTierPayMultiplier = { 1, 1.3, 1.6 },
			Pay = { -- tier-1 pay before house and quota multipliers
				Chore = 900,
				DogWalk = 1_200,
				Letter = 1_200,
				WalletSwipe = 700,
				ShadyPackage = 2_200,
			},
			BreakInPay = { 1_800, 3_000, 4_500 }, -- by house tier (no house multiplier)
		},
		Pickpocket = {
			Pay = 300,
			Pedestrians = 8,
			CooldownSeconds = 60, -- per pedestrian
			RangeStuds = 7,
			HoldSeconds = 0.4,
			WalkSpeed = 8,
		},
		StoreRobbery = {
			Pay = 4_000,
			HoldSeconds = 8,
			CooldownSeconds = 120, -- per store
			RangeStuds = 8,
		},
	},
	Shop = {
		RangeStuds = 14, -- must be near the counter to buy
		Bag = { -- levels 1-3
			{ capacity = 15_000, price = 2_000 },
			{ capacity = 40_000, price = 8_000 },
			{ capacity = 100_000, price = 30_000 },
		},
		Lockpick = { -- levels 1-3: break-in hold time
			{ holdSeconds = 4.5, price = 1_500 },
			{ holdSeconds = 3, price = 6_000 },
			{ holdSeconds = 2, price = 20_000 },
		},
	},
	Movement = {
		WalkSpeed = 25,
		SprintSpeed = 35, -- while holding Shift (or the Sprint touch button)
		SlackPercent = 0.25,
		LagAllowanceStuds = 6, -- extra distance allowed per check for network bursts
		CheckSeconds = 0.5,
	},
	Security = {
		PromptsPerSecond = 3, -- per player, per prompt type
		RemotesPerSecond = 4, -- per player, per remote
		HoldTolerance = 0.8, -- a hold must last at least this share of HoldDuration
	},
	Debug = {
		Enabled = false,
		TimerScale = 0.1, -- speeds up all run timers in debug
		AdminUserIds = { 1913433940 } :: { number }, -- extra debug-command accounts (TinTinTerryy3)
		StudioAutoStartSeconds = 10, -- Studio test starts this long after the first player joins
	},
}
