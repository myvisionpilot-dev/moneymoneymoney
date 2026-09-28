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
		AdvanceWhenMet = true, -- filling a quota starts the next one straight away (the cash-out choice still comes after CashOutAfterQuota)
		QuotaPaidBannerSeconds = 6, -- how long the "quota paid" panel shows when the next quota starts straight away
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
		CopSpeed = 35, -- studs/s on foot: as fast as sprinting
		CarFromStar = 2, -- the cop for this star and above comes in a police car
		CarSpeed = 55, -- catches a level-1 ride, matches level 2, loses level 3
		TagRangeStuds = 4,
		CarTagRangeStuds = 8, -- a car pulls you over from a little further away
		RepathSeconds = 1,
		MinSpawnStuds = 60, -- police appear at the nearest patrol point at least this far from you
		CarMinSpawnStuds = 150, -- police cars start further out, so you get a head start
		SpotHiddenStuds = 30, -- a cop this close finds you in a bush; further away, they lose you
		SearchRadiusStuds = 55, -- cops who lost you circle this far from where they last saw you
		CarTurnSpeed = 5, -- radians/s: police cars swing round instead of snapping
		LightFlashSeconds = 0.4,
	},
	Heat = {
		DecayDelaySeconds = 20, -- heat starts draining this long after your last crime
		HidingDecayMultiplier = 4, -- hidden in a bush (and not spotted): drains this much faster, straight away
		Steal = 0.5,
		Pickpocket = 0.5,
		WalletSwipe = 0.5,
		ShadyPackage = 1,
		BreakIn = { 1, 1.5, 2 }, -- by house tier
		StoreRobbery = 2,
		CarTheft = 1.5,
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
			Racing = 1,
			StoreRobbery = 2,
			BountyHunting = 2,
			CarTheft = 2,
		},
		Delivery = {
			BasePayout = 1_500, -- tier-1 pay per delivery
			TimeLimitSeconds = 90,
			MaxSpeedStudsPerSecond = 80, -- faster than this voids the job; keep above the top ride speed
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
			MaxSpeedStudsPerSecond = 80, -- faster than this voids a travel job; keep above the top ride speed
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
		Racing = {
			KartSpeed = 50, -- everyone races the same kart
			Laps = 2,
			GatherSeconds = 15, -- after the first racer joins, others have this long to join
			CountdownSeconds = 3,
			TimeLimitSeconds = 120,
			CooldownSeconds = 20, -- the track rests after each race
			JoinRangeStuds = 12,
			LeaveRangeStuds = 60, -- walk this far from the start while gathering and you're out
			CheckpointRadiusStuds = 18,
			Pay = { 3_000, 1_800, 900 }, -- tier-1 pay for 1st / 2nd / 3rd (solo: gold / silver / bronze)
			ParSeconds = { 48, 54, 62 }, -- gold / silver / bronze (a perfect line is ~43s); slower than bronze pays nothing
		},
		BountyHunting = {
			PerStar = 1_000, -- tier-1 reward per star of the player you arrest
			MinStars = 2, -- players with this many stars can be arrested by teammates
			HoldSeconds = 1.5,
			RangeStuds = 8,
		},
		CarTheft = {
			Pay = 3_000, -- tier-1 pay from the chop shop
			HoldSeconds = 4, -- breaking into a parked car
			RangeStuds = 8,
			DriveSpeed = 50,
			TimeLimitSeconds = 150, -- to get the car to the chop shop
			RespawnSeconds = 90, -- a new car parks in an empty spot after this long
			ChopRadiusStuds = 12, -- how close to the chop shop bay counts as delivered
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
		Ride = { -- levels 1-3: kart speed in studs/s (sprinting is 35)
			{ speed = 45, price = 2_500 },
			{ speed = 55, price = 10_000 },
			{ speed = 65, price = 35_000 },
		},
	},
	Movement = {
		WalkSpeed = 25,
		SprintSpeed = 35, -- while holding Shift (or the Sprint touch button)
		FieldOfView = 70,
		FastFieldOfView = 78, -- while sprinting or driving: a little wider so speed feels faster
		FieldOfViewTweenSeconds = 0.3,
		SlackPercent = 0.25,
		LagAllowanceStuds = 6, -- extra distance allowed per check for network bursts
		CheckSeconds = 0.5,
		MaxAirStuds = 16, -- higher than this above the ground for MaxAirChecks checks in a row is flying
		MaxAirChecks = 3,
	},
	Profiles = {
		StoreName = "Players_v1", -- the DataStore every profile lives in
		StudioPrefix = "Studio_", -- Studio tests save to their own stores, never the live ones
	},
	Daily = {
		Reward = 150, -- Cred for finishing the day's challenge
		StreakBonusPerDay = 25, -- extra Cred per day of streak...
		MaxStreakBonusDays = 7, -- ...up to this many days
		-- One challenge a day, the same for everyone (by UTC date). best = progress is your best
		-- single value (e.g. highest quota) rather than a running total.
		Challenges = {
			{ stat = "Delivery", goal = 5, text = "Make 5 deliveries" },
			{ stat = "Chore", goal = 4, text = "Do 4 chores for residents" },
			{ stat = "Pickpocket", goal = 6, text = "Pickpocket 6 pedestrians" },
			{ stat = "RaceWin", goal = 1, text = "Win a race (or set a gold time)" },
			{ stat = "Escape", goal = 2, text = "Lose the police in a bush twice" },
			{ stat = "ChopShop", goal = 1, text = "Sell a car to the chop shop" },
			{ stat = "QuotaCleared", goal = 3, best = true, text = "Clear quota 3 in a run" },
			{ stat = "StoreRobbery", goal = 2, text = "Rob 2 stores" },
		},
	},
	Cosmetics = {
		ShopRangeStuds = 14,
		Prices = { -- Cred; items and looks are in shared/Catalog
			paint_cherry = 400,
			paint_ocean = 400,
			paint_lime = 400,
			paint_midnight = 800,
			paint_gold = 2_000,
			trail_cash = 800,
			trail_fire = 1_500,
			trail_rainbow = 3_000,
			title_hustler = 300,
			title_bigshot = 1_000,
			title_favourite = 2_500,
			title_kingpin = 5_000,
			hat_cap = 600,
			hat_tophat = 1_500,
			hat_crown = 4_000,
		} :: { [string]: number },
	},
	Badges = {
		GettingSeriousQuota = 3,
		LoadedCred = 10_000, -- lifetime Cred earned
		RegularStreakDays = 7,
		MvpMinPlayers = 2,
	},
	Leaderboards = {
		Size = 10,
		RefreshSeconds = 60,
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
