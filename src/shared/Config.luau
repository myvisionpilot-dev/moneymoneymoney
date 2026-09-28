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
		QuotaBaseSeconds = 420, -- quota 1 lasts 7 minutes...
		QuotaExtraSecondsPerQuota = 120, -- ...and each quota after gets 2 more (9, 11, 13...)
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
		WarningSeconds = { 180, 60 }, -- Mr. Penny warns you at these times left
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
		PickpocketFail = 1, -- they spotted you: a whole star
		WalletSwipe = 0.5,
		ShadyPackage = 1,
		BreakIn = { 1, 1.5, 2, 2.5 }, -- by house tier (4 = mansion)
		StoreRobbery = 2,
		CarTheft = 1.5,
	},
	Economy = {
		TierPayoutMultiplier = 2.2, -- each unlocked tier pays ~2.2x the previous
		BaseBagCapacity = 5_000, -- max carried cash before upgrades
		DepositRangeStuds = 12, -- max distance from the bank counter
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
			BaseBreakInHoldSeconds = 6, -- lockpick upgrades shorten this
			MaxSpeedStudsPerSecond = 80, -- faster than this voids a travel job; keep above the top ride speed
			MinLetterDistance = 100,
			HouseTierPayMultiplier = { 1, 1.3, 1.6, 2.2 }, -- tiers get richer away from the bank; 4 = mansion
			-- Chores you actually do: mow every patch of long grass, wheel both bins to the kerb,
			-- scrub every dirt spot off the car.
			Chores = {
				MowPatchStuds = 7, -- the lawn is split into patches about this size
				MowReachStuds = 3.5, -- the mower cuts a patch when you're this close to its middle
				BinHoldSeconds = 0.5,
				ScrubHoldSeconds = 1.2,
				DirtSpots = 5,
				CleanupSeconds = 20, -- bins go back and the washed car drives off after this long
			},
			Pay = { -- tier-1 pay before house and quota multipliers
				Chore = 900,
				DogWalk = 1_200,
				Letter = 1_200,
				WalletSwipe = 700,
				ShadyPackage = 2_200,
			},
			BreakInPay = { 1_800, 3_000, 4_500, 8_000 }, -- by house tier (no house multiplier)
		},
		Pickpocket = {
			MinPay = 150, -- tier-1 wallet range; big wallets are rare
			MaxPay = 1_000,
			PayRarity = 3, -- higher = big wallets rarer (pay = min + (max - min) * random^rarity)
			FatWallet = 700, -- tier-1 amount that counts as a fat wallet
			Pedestrians = 12,
			CooldownSeconds = 60, -- per pedestrian
			RangeStuds = 7,
			HoldSeconds = 0.4,
			WalkSpeed = 8,
			-- The minigame: a needle sweeps a bar; press when it's in the green, once per round.
			Minigame = {
				ZoneWidths = { 0.24, 0.18, 0.13 }, -- share of the bar, one per round
				Speeds = { 0.9, 1.25, 1.6 }, -- bar lengths per second
				RoundSeconds = 4, -- press within this long each round
				PauseSeconds = 0.35, -- between rounds
				Tolerance = 0.03, -- forgiveness either side of the zone
				LatencySlack = 0.5, -- seconds of network lag allowed on the whole game
			},
		},
		StoreRobbery = {
			Pay = 4_000,
			HoldSeconds = 8,
			CooldownSeconds = 120, -- per store
			RangeStuds = 8,
			AlarmSeconds = 15, -- the store alarm rings this long
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
	-- The next-step hints and marker (no tutorial): see GuideController.
	Guide = {
		HurrySeconds = 60, -- this close to the deadline, with cash in your bag, you're told to pay the bank
	},
	-- Roblox's normal camera: scroll or pinch to zoom, all the way in for first person.
	Camera = {
		MinZoom = 0.5,
		MaxZoom = 40,
	},
	UI = {
		Scale = 0.75, -- everything on screen, on computers
		TouchScale = 0.9, -- phones and tablets shrink less so buttons stay easy to tap
	},
	-- What NPCs wear: free catalog items made by Roblox (checked to load in Studio).
	Outfits = {
		Hair = {
			63690008, -- Pal Hair
			451221329, -- True Blue Hair
			376548738, -- Brown Charmer Hair
			376524487, -- Blonde Spiked Hair
			62234425, -- Brown Hair
			7193454569, -- Braided Hair - Black
			376526888, -- Straight Blonde Hair
			9244148336, -- Braided Hair - Blonde
			9244150641, -- Braided Hair - Cool Brown
			7193455510, -- Braided Hair - Red
			2956239660, -- Belle Of Belfast Long Red Hair
			1103003368, -- Orange Beanie with Black Hair
		},
		Hats = {
			607702162, -- Roblox Baseball Cap
			417457461, -- ROBLOX 'R' Baseball Cap
			2646473721, -- Roblox Visor
		},
		HatChance = 0.2,
		Shirts = {
			3670737444, -- Roblox Shirt - Simple Pattern
			144076358, -- Blue and Black Motorcycle Shirt
			398635081, -- Blue Plaid Shirt
			4047884939, -- My Favorite Pizza Shirt
			144076436, -- Grey Striped Shirt with Denim Jacket
			382537085, -- I <3 Pizza Shirt
			382537702, -- Teal Shirt
			607785314, -- ROBLOX Jacket
			398633584, -- Denim Jacket with White Hoodie
			4047884046, -- Guitar Tee with Black Jacket
			398634295, -- Pastel Starburst Top with Gray Jacket
		},
		Pants = {
			398634487, -- Beautiful You Jeans
			144076760, -- Dark Green Jeans
			398633812, -- Black Jeans with White Shoes
			382538503, -- Black Jeans with Sneakers
			382537569, -- Black Jeans
			382537806, -- Jean Shorts
			382537950, -- Jean Shorts with White Shoes
			398635338, -- Ripped Skater Pants
		},
	},
	-- Sound effects from Roblox's audio library (ProSoundEffects and APM are Roblox-licensed).
	Sounds = {
		Click = { id = 122835655736085, volume = 0.5 },
		Open = { id = 9126047581, volume = 0.35 },
		Paid = { id = 135483737426662, volume = 0.6 },
		Deposit = { id = 120891770644830, volume = 0.6 },
		Purchase = { id = 9118777639, volume = 0.6 },
		StoreBell = { id = 9125935023, volume = 0.6 },
		Alarm = { id = 138656991212198, volume = 0.7 },
		Siren = { id = 4832498807, volume = 0.45 },
		Knock = { id = 138990412937492, volume = 0.8 },
		Whistle = { id = 9117260548, volume = 0.6 },
		JailDoor = { id = 9117911726, volume = 0.7 },
		Wanted = { id = 1846885714, volume = 0.4 },
		Fail = { id = 125909120236588, volume = 0.45 },
		Ding = { id = 18448089848, volume = 0.5 },
		Beep = { id = 9117060347, volume = 0.5 },
		Horn = { id = 9114075424, volume = 0.35 },
		Fanfare = { id = 1840091947, volume = 0.45 },
		Badge = { id = 1841980129, volume = 0.45 },
		Rustle = { id = 9114519078, volume = 0.5 },
		Swipe = { id = 9126283592, volume = 0.6 },
	} :: { [string]: { id: number, volume: number } },
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
