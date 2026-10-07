--!strict
-- Every tunable number in the game. Tune from playtests; never hard-code these elsewhere.

-- A quota twist (see Twists below).
export type Twist = {
	id: string,
	title: string,
	detail: string,
	pay: { [string]: number }?,
	crimePay: number?,
	heat: number?,
	cops: number?,
	copSpeed: number?,
	crimeHold: number?,
	spot: number?,
	shopPrice: number?,
	night: boolean?,
}

-- A hustle: a run perk (see Hustles below). value is what each stack adds.
export type Hustle = {
	id: string,
	title: string,
	detail: string,
	max: number,
	value: number,
}

return {
	Places = {
		LobbyPlaceId = 89656922694625,
		MatchPlaceId = 80496708814164,
	},
	Match = {
		MinPlayers = 1,
		MaxPlayers = 6,
		QueueWaitSeconds = 60, -- a hosted lobby leaves this long after it opens (the host can start it sooner)
		StartingCash = 500,
		QuotaSeconds = { 420, 540, 600, 660, 720 }, -- clock per quota; endless quotas get the last one
		-- Beating a quota early: everyone gets a bonus in their bag when the next quota starts,
		-- PercentPerMinute of the next target per whole minute left (up to MaxMinutes), split
		-- between the players.
		EarlyBonus = { PercentPerMinute = 0.02, MaxMinutes = 5 },
		IntermissionSeconds = 20,
		DecisionSeconds = 20,
		Quotas = { 50_000, 150_000, 300_000, 600_000, 1_000_000 },
		CashOutAfterQuota = 3, -- the cash-out vote comes after this quota and every one after it
		AdvanceWhenMet = true, -- filling a quota starts the next one straight away (the cash-out choice still comes after CashOutAfterQuota)
		QuotaPaidBannerSeconds = 8, -- how long the "quota paid" screens show (then the hustle pick) when the next quota starts straight away
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
		CaughtLosePercent = 0.30, -- of carried cash
		JailSeconds = 30,
		CopsPerStar = 1,
		MaxCops = 6, -- across the whole town
		OutlineColor = Color3.fromRGB(255, 40, 40), -- every cop (and police car) is outlined in this, seen through walls
		CopSpeed = 35, -- studs/s on foot: as fast as sprinting
		CarFromStar = 2, -- the cop for this star and above comes in a police car
		CarSpeed = 85, -- police cars: well past a sprint, slower than a race car
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
	-- Each quota from FromQuota rolls one twist (two from DoubleFromQuota, in endless), never
	-- the same as last quota's. pay: multipliers by money path id or door job kind; crimePay:
	-- every illegal job; heat: heat gained; cops: cops per star; copSpeed; crimeHold: break-in
	-- and robbery hold times; spot: how close a cop must be to find you in a bush; shopPrice;
	-- night: dark for the whole quota.
	Twists = {
		FromQuota = 2,
		DoubleFromQuota = 6,
		NightClockTime = 21,
		List = {
			{
				id = "RushHour",
				title = "RUSH HOUR",
				detail = "Taxi fares and deliveries pay double.",
				pay = { Taxi = 2, Delivery = 2 },
			},
			{
				id = "Heatwave",
				title = "HEATWAVE",
				detail = "Burgers, hot dogs and car washes pay double. Cops are slow in the heat.",
				pay = { BurgerBarn = 2, FoodStand = 2, CarWash = 2 },
				copSpeed = 0.8,
			},
			{
				id = "Crackdown",
				title = "CRACKDOWN",
				detail = "Crimes pay 1.5x, but there are more cops and heat builds faster.",
				crimePay = 1.5,
				heat = 1.5,
				cops = 1.5,
			},
			{
				id = "Blackout",
				title = "BLACKOUT",
				detail = "Night falls. Break-ins and robberies are twice as quick, and cops lose you sooner.",
				crimeHold = 0.5,
				spot = 0.6,
				night = true,
			},
			{
				id = "Payday",
				title = "PAYDAY",
				detail = "Everyone just got paid: wallets are twice as fat.",
				pay = { Pickpocket = 2, WalletSwipe = 2 },
			},
			{
				id = "CarShow",
				title = "CAR SHOW",
				detail = "Flipped cars and the chop shop pay 1.75x.",
				pay = { CarFlip = 1.75, CarTheft = 1.75 },
			},
			{
				id = "SaleDay",
				title = "SALE DAY",
				detail = "Every shop in town is 40% off.",
				shopPrice = 0.6,
			},
		} :: { Twist },
	},
	-- Hustles: every time a quota is paid, each player picks one of Offered random run perks
	-- (PickSeconds, or one is picked for them). They last the whole run; some stack up to max.
	Hustles = {
		Offered = 3,
		PickSeconds = 30,
		List = {
			{
				id = "SmoothTalker",
				title = "Smooth Talker",
				detail = "Legal jobs pay 20% more.",
				max = 3,
				value = 0.2,
			},
			{
				id = "StickyFingers",
				title = "Sticky Fingers",
				detail = "Crimes pay 20% more.",
				max = 3,
				value = 0.2,
			},
			{ id = "DeepPockets", title = "Deep Pockets", detail = "Your bag holds 50% more.", max = 2, value = 0.5 },
			{
				id = "LuckyBreak",
				title = "Lucky Break",
				detail = "1 in 10 jobs pays double.",
				max = 2,
				value = 0.1,
			},
			{ id = "Ghost", title = "Ghost", detail = "Your heat clears twice as fast.", max = 2, value = 1 },
			{ id = "CoolHead", title = "Cool Head", detail = "Crimes give you 25% less heat.", max = 2, value = 0.25 },
			{
				id = "SecondChance",
				title = "Second Chance",
				detail = "Keep your cash the first time you're busted each quota.",
				max = 1,
				value = 1,
			},
			{ id = "EscapeArtist", title = "Escape Artist", detail = "Half the time in jail.", max = 1, value = 0.5 },
			{ id = "Haggler", title = "Haggler", detail = "Shops charge you 25% less.", max = 2, value = 0.25 },
			{
				id = "Interest",
				title = "Interest",
				detail = "Your deposits count 5% extra toward the quota.",
				max = 3,
				value = 0.05,
			},
			{ id = "FleetFeet", title = "Fleet Feet", detail = "Walk and sprint 10% faster.", max = 2, value = 0.1 },
			{
				id = "Safecracker",
				title = "Safecracker",
				detail = "Break-ins take half as long.",
				max = 1,
				value = 0.5,
			},
			{
				id = "RepoRepellent",
				title = "Repo Repellent",
				detail = "Repo men leave you alone until your bag is 80% full.",
				max = 1,
				value = 0.8,
			},
			{
				id = "Allowance",
				title = "Allowance",
				detail = "Start every quota with 3% of the target in your bag.",
				max = 2,
				value = 0.03,
			},
		} :: { Hustle },
	},
	-- Town events: one at a time during a quota, never in its first FirstAfterSeconds, with a
	-- random MinGapSeconds..MaxGapSeconds gap after each. Pay is at quota 1 and scales with the
	-- quota like jobs (Economy.TierPayoutMultiplier).
	Events = {
		FirstAfterSeconds = 60,
		MinGapSeconds = 120,
		MaxGapSeconds = 180,
		-- The ALERT that drops down from under the quota panel when an event starts, in the
		-- event's colour (Sounds.EventAlert plays when it lands).
		Alert = {
			Seconds = 5.5, -- how long it stays down
			Colors = {
				CashDrop = Color3.fromRGB(55, 185, 75),
				HappyHour = Color3.fromRGB(240, 170, 20),
				FireSale = Color3.fromRGB(240, 90, 25),
				VipFare = Color3.fromRGB(185, 65, 225),
				ArmouredTruck = Color3.fromRGB(140, 15, 30),
				RivalCrew = Color3.fromRGB(215, 30, 50),
				HustleOff = Color3.fromRGB(30, 145, 230),
			} :: { [string]: Color3 },
		},
		CashDrop = { Seconds = 60, Pay = 3_000, FallSeconds = 3, RangeStuds = 10 }, -- first to grab it
		HappyHour = { Seconds = 90, Bonus = 0.25 }, -- deposits count this much extra toward the quota
		FireSale = { Seconds = 90, Discount = 0.5 }, -- one shop
		VipFare = { Seconds = 150, Multiplier = 3, MinTripStuds = 300 }, -- x a normal taxi fare, any car
		ArmouredTruck = {
			FromQuota = 2, -- crimes start then
			Seconds = 150,
			Speed = 18, -- slower than walking, so you can keep up with it
			Pries = 8, -- prompt holds to crack the back doors (two people do it twice as fast)
			PryHoldSeconds = 1.5,
			Pay = 12_000, -- split by how many pries each person did
			Heat = 2, -- spread over the pries
			RangeStuds = 12,
		},
		-- 2+ players: whoever earns the most from jobs while it's on wins Prize.
		HustleOff = { Seconds = 120, Prize = 5_000, MinPlayers = 2 },
		-- A gang with blasters. Everyone without a blaster gets a Zapper for the fight.
		RivalCrew = {
			FromQuota = 3,
			Seconds = 90,
			Count = 3,
			Speed = 24, -- they walk up to blaster range (a bit slower than you)
			Hits = 2, -- zaps to knock one out...
			Reward = 1_500, -- ...for this
			ShootRangeStuds = 60,
			StandOffStuds = 25, -- they stop this far away to shoot
			ShotSeconds = 2.5, -- between shots, plus up to a second
			HitChance = 0.3, -- not great aim
			Damage = 13, -- per hit, from 100 health
			KnockoutTakePercent = 0.15, -- of your carried cash, when they knock you down
			KnockoutGraceSeconds = 10, -- then they leave you alone this long
			MinSpawnStuds = 60,
		},
	},
	-- Everyone still in the run (2+ players) deposits within Seconds of each other: those
	-- deposits count Bonus extra toward the quota.
	TeamCombo = { Seconds = 30, Bonus = 0.1 },
	-- Your STREAK: every payout (jobs, crimes, events) within WindowSeconds of the last one adds
	-- one, and pays more. Depositing refills the timer; getting busted ends it. Characters on a
	-- streak of FlameCount+ burn (everyone sees it).
	Streak = {
		WindowSeconds = 45,
		Tiers = { -- payouts in a row -> pay multiplier (the highest tier reached counts)
			{ count = 2, multiplier = 1.1 },
			{ count = 3, multiplier = 1.25 },
			{ count = 5, multiplier = 1.5 },
			{ count = 8, multiplier = 2 },
		},
		FlameCount = 3, -- sparks at your feet from here...
		BlazeCount = 5, -- ...flames from here...
		InfernoCount = 8, -- ...and a full blaze from here
	},
	-- Run levels: every payout gives XpPerPayout + 1 XP per XpPerDollars earned. Level n to n+1
	-- takes FirstLevelXp * Growth^(n-1) XP. Each level above 1 pays PayPerLevel more for the
	-- rest of the run; every CredEvery levels also gives CredReward x (level / CredEvery) Cred.
	Levels = {
		XpPerPayout = 10,
		XpPerDollars = 100,
		FirstLevelXp = 40,
		Growth = 1.12,
		PayPerLevel = 0.02,
		MaxLevel = 25,
		CredEvery = 5,
		CredReward = 25,
	},
	-- How hard the screen celebrates money (client effects only).
	Fx = {
		BigPayout = 3_000, -- a gold flash, a camera shake and a bigger money line
		HugePayout = 10_000, -- and a shower of coins down the screen
		BillsMin = 4, -- bills flying into your bag for a small payout...
		BillsMax = 22, -- ...up to this many for a huge one
		ShakeStuds = 0.35, -- camera shake on a big payout (more on a huge one)
		PitchStep = 0.06, -- each payout within PitchSeconds of the last rings this much higher...
		PitchMax = 0.5, -- ...up to this much
		PitchSeconds = 3,
		Milestones = { 0.25, 0.5, 0.75 }, -- quota progress that gets a pop on screen
		WorldRange = 160, -- studs: you see other players' payout bursts and level-ups this close
	},
	-- The late game gets tougher from FromQuota: cops get faster and more of them come.
	Pressure = {
		FromQuota = 4,
		CopSpeedPerQuota = 0.06, -- x cop speed per quota from FromQuota...
		MaxCopSpeed = 1.3, -- ...up to this
		CopsPerStarPerQuota = 0.5, -- added to Police.CopsPerStar per quota from FromQuota
	},
	-- Repo men (from FromQuota) go after anyone carrying more than BagFraction of their bag. A
	-- tag takes TakePercent of the cash they carry. Bank it, outrun them (they're slower than a
	-- sprint) or zap them; they give up after ChaseSeconds.
	Repo = {
		FromQuota = 4,
		BagFraction = 0.5,
		TakePercent = 0.2,
		Speed = 30,
		MaxInTown = 2,
		ChaseSeconds = 75,
		CooldownSeconds = 90, -- per player, after a repo man tags them or gives up
		WarnSeconds = 4, -- the warning comes this long before he turns up
		TagRangeStuds = 4,
		MinSpawnStuds = 80,
	},
	Heat = {
		WantedSeconds = 32, -- your heat clears this long after your last crime, however many stars (the chase song's length)
		HidingDecayMultiplier = 4, -- hidden in a bush (and not spotted): that clock runs this much faster
		Steal = 0.5,
		Pickpocket = 0.5,
		PickpocketFail = 1, -- they spotted you: a whole star
		WalletSwipe = 0.5,
		ShadyPackage = 1,
		BreakIn = { 1, 1.5, 2, 2.5 }, -- by house tier (4 = mansion)
		StoreRobbery = 2,
		CarTheft = 1.5,
		BlastPlayer = 1, -- stunning a teammate with a blaster
		BlastCop = 0.5, -- stunning a cop
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
			Taxi = 1,
			BurgerBarn = 1,
			StoreRobbery = 2,
			BountyHunting = 2,
			CarTheft = 2,
			CarWash = 2,
			CarFlip = 2,
			FoodStand = 3,
		},
		-- The legal jobs in town. All pay into your bag; every price and cost below is at
		-- quota 1 and scales with the quota like other pay (TierPayoutMultiplier).
		Taxi = { -- City Cabs: a shift of back-to-back fares in a yellow cab (R ends it)
			DriveSpeed = 80,
			BaseFare = 600, -- plus PerStud for every stud from pickup to drop-off
			PerStud = 2.5,
			MinTripStuds = 200, -- drop-offs at least this far from the pickup
			PickupSeconds = 90, -- the passenger gives up waiting after this...
			FareSeconds = 90, -- ...and gets out without paying if the ride takes longer
			StopRadiusStuds = 14, -- how close to the stop counts as pulled up
			StopSpeed = 25, -- and slow enough to hop in or out
		},
		BurgerBarn = { -- cook and serve 3 orders
			Orders = 3,
			ShiftSeconds = 120,
			PayPerOrder = 500,
			NoBurnBonus = 300, -- for a full shift with nothing burnt
			GrillSeconds = 4, -- a patty cooks this long...
			BurnSeconds = 4, -- ...and burns if it's left on this much longer
			FryHoldSeconds = 1.5,
			ShakeHoldSeconds = 1.5,
			RangeStuds = 8,
		},
		CarWash = { -- Sudz: scrub the dirt off each car, then pull the rinse lever
			Cars = 3,
			ShiftSeconds = 180,
			PayPerCar = 1_000,
			QuickTip = 300, -- for a car done within QuickSeconds of rolling in
			QuickSeconds = 30,
			DirtSpots = 8,
			ScrubHoldSeconds = 1.2,
			RollSeconds = 2, -- cars roll in and out of the bay this quickly
			RangeStuds = 8,
		},
		CarFlip = { -- buy a wreck behind Speedy's, fix it, respray it at the chop shop, sell it
			Cost = 1_500, -- paid from your bag; lost if you fail
			SalePrice = 5_000,
			BuyerTierBonus = { 1, 1.1, 1.2, 1.4 }, -- richer streets pay a bit more (house tier)
			TimeLimitSeconds = 180,
			Dents = 3,
			DentHoldSeconds = 1.5,
			FlatTyres = 2,
			FitHoldSeconds = 1,
			DriveSpeed = 80,
			ChopShopRadiusStuds = 10, -- drive this close to the chop shop bay's middle for the respray
			SellRadiusStuds = 12, -- and this close to the buyer's driveway
			MinBuyerStuds = 250,
			RespawnSeconds = 30, -- a new wreck turns up this long after one goes
			RangeStuds = 8,
		},
		FoodStand = { -- rent the hot-dog cart at the market and sell to people in the street
			Rent = 500, -- 10 hot dogs
			Stock = 10,
			Price = 300,
			ShiftSeconds = 180,
			BuyCooldownSeconds = 60, -- each pedestrian buys at most this often
			SellHoldSeconds = 0.5,
			RangeStuds = 8,
		},
		Delivery = {
			BasePayout = 1_500, -- tier-1 pay per delivery
			TimeLimitSeconds = 90,
			MaxSpeedStudsPerSecond = 130, -- faster than this voids the job; keep above the fastest car
			DropoffRadiusStuds = 8,
			PromptRangeStuds = 10,
			MinDropoffDistance = 60, -- skip drop-offs closer than this to the depot
		},
		Doors = {
			HouseRestSeconds = 90, -- after a knock, that house won't answer for this long
			OfferSeconds = 15, -- time to pick an offer
			AnswerSeconds = 1.3, -- after the knock, the door opens and the resident speaks
			KnockRangeStuds = 8,
			JobTimeLimitSeconds = 90,
			TargetRadiusStuds = 7, -- how close counts as arriving
			BaseBreakInHoldSeconds = 6, -- lockpick upgrades shorten this
			MaxSpeedStudsPerSecond = 130, -- faster than this voids a travel job; keep above the fastest car
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
		-- Street races round the town loop, from Speedy's Garage in a loaner car.
		Racing = {
			EntryFee = 3_000, -- paid from your bag; the top 3 get it back (a solo racer needs a medal)
			CarSpeed = 120, -- everyone races the same loaner car (top speed)
			Laps = 2,
			GatherSeconds = 15, -- after the first racer joins, others have this long to join
			CountdownSeconds = 3,
			TimeLimitSeconds = 150,
			CooldownSeconds = 20, -- the garage rests after each race
			JoinRangeStuds = 12,
			LeaveRangeStuds = 60, -- walk this far from the start while gathering and you're out
			CheckpointRadiusStuds = 18,
			Pay = { 3_000, 1_800, 900 }, -- tier-1 prize for 1st / 2nd / 3rd (solo: gold / silver / bronze), on top of the fee back
			ParSeconds = { 62, 70, 82 }, -- gold / silver / bronze; slower than bronze pays nothing
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
			DriveSpeed = 80, -- the stolen car's top speed
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
	},
	-- Five-minute treats from the convenience stores. Different ones stack; buying one you
	-- already have starts its clock again. The energy drink goes in your backpack (one at a
	-- time) and starts when you drink it.
	Boosts = {
		Seconds = 300,
		Energy = { price = 800, speed = 2, drinkSeconds = 1.2 }, -- a drink you carry, then drink: on foot (not in cars) this much faster
		Disguise = { price = 1_200, heat = 0.5 }, -- heat builds this much as fast
		Candy = { price = 600, zone = 1.5 }, -- the pickpocket green zone is this much wider
		Gloves = { price = 1_000, breakIn = 0.5 }, -- break-ins take this much as long
		Scanner = { price = 1_500 }, -- police radio: see every cop through walls
	},
	-- Tony's cartoon stun blasters (no damage, nobody gets hurt: a zap, stars and a sit-down).
	Blasters = {
		UnlockQuota = 2, -- Tony opens up at this quota
		Zapper = { price = 6_000, range = 45, cooldown = 2.5, copStunSeconds = 3 },
		MegaZapper = { price = 20_000, range = 75, cooldown = 1.5, copStunSeconds = 5 },
		PlayerStunSeconds = 3, -- a blasted player sits down this long...
		DropPercent = 0.2, -- ...and drops this share of their bag as a cash bundle anyone can grab
		BundleSeconds = 30, -- an unclaimed bundle goes back to its owner after this long
		HoldUpSpeed = 2, -- robbing a store with a blaster out is this much faster...
		HoldUpPay = 1.5, -- ...and pays this much more
	},
	-- Physics cars (race cars, stolen cars, taxis, flip cars): real wheels on springs, driven by
	-- the driver's own computer (client/CarController). Top speeds are per car (Racing.CarSpeed,
	-- CarTheft.DriveSpeed and the other paths' DriveSpeed). Accelerations are in studs/s².
	Car = {
		Acceleration = 42, -- off the line; fades toward top speed (0-100 in ~4s at 120)
		TorqueFade = 2, -- how quickly power fades with speed: 1 - (speed / top) ^ this
		MinTorqueShare = 0.12, -- a little push stays near the top
		ReverseShare = 0.3, -- reverse top speed, as a share of top speed
		Braking = 40, -- a full stop from 120 in about 3s
		FrontBrakeShare = 0.6,
		EngineBraking = 6, -- slowing down when you let go of the throttle
		SteerAngleSlow = 35, -- degrees at a standstill...
		SteerAngleFast = 12, -- ...down to this at top speed, so it can't spin out
		SteerSeconds = 0.12, -- how quickly the wheels turn to where you're steering
		CornerGrip = 220, -- sideways studs/s² the steering will ask for at speed (more turns tighter; less pushes wide)
		YawAssist = 7, -- how firmly the car turns exactly as its wheels point (per second; 0 = raw physics, off while drifting)
		SuspensionHz = 2.6, -- bounces per second; lower is softer
		DampingRatio = 0.75, -- share of critical damping (1 = no bounce at all)
		SuspensionUp = 0.6, -- how far a wheel can push up into the body, as a share of its radius...
		SuspensionDown = 0.5, -- ...and drop below where it rests
		AntiRoll = 0.6, -- resists leaning in corners (share of the spring stiffness)
		FrontFriction = 2, -- the most grip Roblox allows
		RearFriction = 1.8, -- a little less at the back, so throttle in a hard turn kicks the tail out
		DriftFriction = 0.4, -- rear grip with the handbrake on
		DriftBrake = 0.25, -- share of Braking on the rear wheels with the handbrake on (and no throttle)
		DriftThrottle = 0.6, -- share of power you keep with the handbrake on, to hold a slide
		GripReturnSeconds = 0.3, -- rear grip comes back this smoothly after the handbrake
		DriftSteer = 20, -- degrees: in a slide, steering aims the front wheels this far either side of where you're sliding...
		CounterSteer = 0.7, -- ...and they follow the slide by themselves this much (1 = straight along it)
		DriftMaxAngle = 35, -- degrees: a slide is held to this much sideways (no spinning out)
		DriftSlowdown = 18, -- drifting on the throttle loses at most this much speed per second
		DriftCatch = 0.5, -- share of the extra slide angle taken off each step
		WheelDensity = 0.7,
		BallastDensity = 20, -- a heavy plate under the floor keeps it the right way up
		Downforce = 0.4, -- extra push down at top speed, as a share of the car's weight
		AirSpinDamping = 3, -- in the air, spinning dies down this quickly...
		AirLevelling = 1.5, -- ...and it tips back level this strongly
		MaxSpin = 5, -- radians/s: hard cap so crashes don't send it whirling
		FlipAfterSeconds = 2, -- on its side and stopped this long: press F (or tap FLIP)
	},
	-- Pedestrians dash out of the way of cars (cars pass through people; nobody gets hit).
	Dodge = {
		MinCarSpeed = 12, -- slower cars are ignored
		LookAheadSeconds = 1.1, -- how far ahead of a car people react...
		ExtraStuds = 8, -- ...plus this
		ClearStuds = 3, -- side clearance beyond the car's width
		DashStuds = 9, -- how far they leap aside
		DashSpeed = 34,
		HopHeight = 2.5,
		Seconds = 1.2, -- the whole dash, landing and wobble
		DashSeconds = 0.5, -- of which this is the fast part
	},
	Movement = {
		WalkSpeed = 25,
		SprintSpeed = 35, -- while holding Shift (or the Sprint touch button)
		MaxSpeedMultiplier = 2, -- the speed buff and an energy drink together never go past this
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
		-- Work clothes (catalog shirts and pants, checked in Studio).
		Uniforms = {
			Suit = { shirt = 7248050683, pants = 129459077 }, -- black suit and tie, Black Slacks (Mr. Penny, repo men)
			Police = { shirt = 6180109308, pants = 129459077 }, -- blue police shirt with tie and badge
			Gang = { shirt = 125157548394108, pants = 382537569 }, -- black graphic hoodie, Black Jeans (rival crew)
		},
	},
	-- Music, played quietly on each player's screen. Chase plays instead of Background while
	-- you're wanted (it's 32s long, the same as Heat.WantedSeconds).
	Music = {
		Background = { id = 1848354536, volume = 0.1 }, -- as loud as the chase track
		Chase = { id = 1842577591, volume = 0.1 },
		-- While the chase music plays, every other sound effect goes quiet on your screen except
		-- these: money (and the streak and level-ups it brings), sirens and the cell door when
		-- you're caught.
		ChaseKeeps = {
			"Paid",
			"Deposit",
			"Purchase",
			"Fanfare",
			"Siren",
			"JailDoor",
			"Coins",
			"CoinPour",
			"LevelUp",
			"StreakUp",
			"Milestone",
			"EventAlert",
			"Boom",
		},
		ChaseSiren = 0.35, -- a siren wails under the chase music (this much of Sounds.Siren's volume)
	},
	-- Sound effects from Roblox's audio library (ProSoundEffects and APM are Roblox-licensed).
	Sounds = {
		Click = { id = 122835655736085, volume = 0.5 },
		Open = { id = 9126047581, volume = 0.35 },
		Paid = { id = 135483737426662, volume = 0.6 },
		Deposit = { id = 120891770644830, volume = 0.6 },
		Purchase = { id = 133292918309565, volume = 0.6 },
		StoreBell = { id = 127488139302452, volume = 0.6 }, -- the user's pick, also the Burger Barn bell
		Alarm = { id = 138656991212198, volume = 0.7 },
		Siren = { id = 4832498807, volume = 0.45 },
		Knock = { id = 9114141551, volume = 0.8 },
		DoorOpen = { id = 120873363783894, volume = 0.7 },
		Whistle = { id = 9117260548, volume = 0.6 },
		JailDoor = { id = 73078778903922, volume = 0.7 }, -- the user's pick: a cell door closing when you're arrested
		Wanted = { id = 1846885714, volume = 0.4 },
		Fail = { id = 125909120236588, volume = 0.45 },
		Ding = { id = 135165335432475, volume = 0.5 }, -- the user's pick
		Beep = { id = 9117060347, volume = 0.5 },
		Horn = { id = 9114075424, volume = 0.35 },
		Fanfare = { id = 1840119665, volume = 0.45 },
		Badge = { id = 134821092416328, volume = 0.45 }, -- Rewards Level Up - Next Tier: a hustle, a badge or the daily challenge
		Rustle = { id = 9114519078, volume = 0.5 },
		Swipe = { id = 9126283592, volume = 0.6 },
		Zap = { id = 9114277757, volume = 0.5 }, -- Electric Zaps 12 (Pro Sound Effects)
		Stun = { id = 9116421639, volume = 0.6 }, -- Magic Transformation 8: cartoon boinks
		Sizzle = { id = 9114542867, volume = 0.35 }, -- Fry Or Sizzle 1 (Pro Sound Effects): the grill and fryer
		CustomerBell = { id = 127488139302452, volume = 0.6 }, -- the same bell as StoreBell (the user's pick)
		Milkshake = { id = 9113459621, volume = 0.4 }, -- Blender With Shake 7 (Pro Sound Effects): the shake machine
		Coins = { id = 607665037, volume = 0.35 }, -- coins_get: bills landing in your bag
		CoinPour = { id = 9121189379, volume = 0.5 }, -- BagOfCoins: a deposit pouring into the quota
		LevelUp = { id = 89481514209130, volume = 0.5 }, -- Level Up (EasyPlay Creations): a rising chime
		StreakUp = { id = 103911273184692, volume = 0.45 }, -- fire_ignite_1: your streak catches fire
		Milestone = { id = 139330213484352, volume = 0.45 }, -- a star chime: 25/50/75% of the quota
		Whoosh = { id = 9120711836, volume = 0.35 }, -- Whoosh Fast Swish By 4 (Pro Sound Effects): banners
		EventAlert = { id = 3165700530, volume = 0.8 }, -- the user's pick: a town event's ALERT lands
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
			{ stat = "RaceWin", goal = 1, text = "Win a street race (or set a gold time)" },
			{ stat = "Escape", goal = 2, text = "Lose the police in a bush twice" },
			{ stat = "ChopShop", goal = 1, text = "Sell a car to the chop shop" },
			{ stat = "QuotaCleared", goal = 3, best = true, text = "Clear quota 3 in a run" },
			{ stat = "StoreRobbery", goal = 2, text = "Rob 2 stores" },
			{ stat = "TaxiFare", goal = 4, text = "Drive 4 taxi fares" },
			{ stat = "BurgerOrder", goal = 6, text = "Serve 6 burger orders" },
			{ stat = "CarWash", goal = 3, text = "Wash 3 cars at Sudz" },
			{ stat = "CarFlip", goal = 1, text = "Flip a car for a profit" },
			{ stat = "HotDog", goal = 10, text = "Sell 10 hot dogs" },
		},
	},
	-- What Cred buys in the lobby (the UPGRADES and CUSTOMISATION windows): everything is at a
	-- fixed price (nothing random) and kept for good. Names and looks are in shared/Catalog and
	-- shared/Cosmetics.
	CredShop = {
		-- Levelled upgrades that help in every run. PerLevel is what each level adds; Prices[n]
		-- buys level n, and the list's length is the max level.
		Upgrades = {
			Speed = { PerLevel = 0.1, Prices = { 250, 600, 1_200, 2_400, 4_500 } }, -- x faster on foot
			Pockets = { PerLevel = 0.08, Prices = { 300, 700, 1_400, 2_800, 5_000 } }, -- bigger bag
			HeadStart = { PerLevel = 250, Prices = { 200, 500, 1_000, 2_000, 3_500 } }, -- $ at the start
			SilverTongue = { PerLevel = 0.04, Prices = { 350, 800, 1_600, 3_000, 5_500 } }, -- honest work pays more
			SmoothOperator = { PerLevel = 0.04, Prices = { 350, 800, 1_600, 3_000, 5_500 } }, -- crimes pay more
			LowProfile = { PerLevel = 0.06, Prices = { 400, 900, 1_800, 3_500 } }, -- crimes add less heat
			QuickHands = { PerLevel = 0.06, Prices = { 400, 900, 1_800, 3_500 } }, -- quicker break-ins and robberies
			Lawyer = { PerLevel = 4, Prices = { 300, 700, 1_400, 2_600, 4_500 } }, -- seconds off jail
			Insurance = { PerLevel = 0.04, Prices = { 300, 700, 1_400, 2_600, 4_500 } }, -- less lost when busted
			Bargain = { PerLevel = 0.04, Prices = { 250, 600, 1_200, 2_400, 4_000 } }, -- town shops cheaper
			Investor = { PerLevel = 0.05, Prices = { 800, 2_000, 4_500, 9_000 } }, -- more Cred per run
		},
		MinJailSeconds = 8, -- Lawyer can't take it below this
		-- One-time unlocks for your starting loadout.
		Unlocks = {
			Toolbelt = 1_500, -- every run starts with a level-1 lockpick
			Thermos = 1_200, -- every run starts with an energy drink in your backpack
			ZapperLicense = 3_500, -- a free Zapper the moment blasters go on sale
			WideOptions = 3_000, -- pick hustles from one more choice
		},
		-- Things no longer sold, refunded at what they cost the first time a profile loads.
		Retired = { PitPass = 2_500 } :: { [string]: number }, -- the kart unlock (karts were removed)
		-- Cosmetics (paint, underglow, trails, bags, zaps, bursts) cost this much by rarity.
		Tiers = { Common = 300, Rare = 900, Epic = 2_500, Legendary = 6_000 },
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
