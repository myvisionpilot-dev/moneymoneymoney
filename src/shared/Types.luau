--!strict
-- Shared types for run state and remote payloads.

export type Phase = "Waiting" | "Intro" | "Quota" | "Intermission" | "Decision" | "Results" | "Ended"
export type PlayerStatus = "Active" | "CashedOut" | "Finished" | "Left"
export type Decision = "CashOut" | "Continue"
export type NoticeKind = "Info" | "Good" | "Bad"
export type EndReason = "CashedOut" | "Failed"

export type PlayerRow = {
	userId: number,
	name: string,
	carried: number,
	deposited: number,
	bagCapacity: number,
	status: PlayerStatus,
	decided: boolean,
	heat: number, -- 0 to Police.MaxHeat; whole numbers are stars
	heatClearsAt: number, -- server time the heat clears at the current pace (0 with none)
	hiding: boolean, -- in a bush
	spotted: boolean, -- in a bush, but a cop is close enough to see you
	jailedUntil: number, -- 0 when free
	stolen: number, -- total stolen from teammates this run
	bounty: number, -- what a teammate earns for arresting you (0 = can't be arrested)
	streak: number, -- payouts in a row (Config.Streak); 0 = none
	streakEndsAt: number, -- server time the streak runs out without another payout
	level: number, -- run level (Config.Levels), from 1
	xp: number, -- XP into this level...
	xpNeeded: number, -- ...of this many for the next (0 at the top level)
	boosts: { [string]: number }, -- BoostId -> when it wears off (server time)
	hustles: { [string]: number }, -- hustle id -> how many you've picked this run
}

-- A run perk you pick after each quota (Config.Hustles).
export type HustleView = {
	id: string,
	title: string,
	detail: string,
	stacks: number, -- how many you already have
	max: number,
}

export type HustleOffer = {
	options: { HustleView },
	endsAt: number, -- a random one is picked for you then
}

-- The town event going on right now (Config.Events), as your screen shows it.
export type TownEventView = {
	id: string,
	title: string,
	detail: string,
	marker: Vector3?, -- where to go, if anywhere
	endsAt: number,
}

-- A quota twist (Config.Twists), as the HUD shows it.
export type TwistView = {
	id: string,
	title: string,
	detail: string,
}

export type RunSnapshot = {
	phase: Phase,
	quotaIndex: number,
	target: number,
	progress: number,
	phaseEndsAt: number, -- workspace:GetServerTimeNow() time
	isEndless: boolean,
	teamDeposited: number,
	twists: { TwistView }, -- this quota's twists (none in quota 1)
	players: { PlayerRow },
}

export type Notice = {
	text: string,
	kind: NoticeKind,
}

-- An announcement everyone sees under the quota panel: Mr. Penny, or town news.
export type Announcement = {
	speaker: string,
	text: string,
}

-- Where to go for your current job. Every job (delivery, chores, errands...) uses this.
export type JobGuide = {
	title: string,
	markers: { Vector3 }, -- the first one gets the guide beam
	endsAt: number,
	pay: number,
}

export type DoorOfferOption = {
	slot: number, -- 1 or 2
	title: string,
	detail: string,
	legal: boolean,
	pay: number,
	heat: number,
}

export type DoorOffer = {
	residentName: string,
	greeting: string,
	options: { DoorOfferOption },
	expiresAt: number,
	speakerAt: Vector3, -- just above the resident's head (what they say floats there)
}

-- Talking to a shopkeeper (or anyone else with something to say).
export type TalkOption = {
	text: string,
	detail: string?, -- small text on the right: pay, heat, why it's locked
	heat: boolean?, -- it's a crime (an orange card)
	locked: boolean?, -- shown but can't be picked
}

export type Talk = {
	id: number, -- answer with this id
	name: string,
	line: string,
	speakerAt: Vector3,
	options: { TalkOption }, -- none: just a line
	progress: { label: string, endsAt: number }?, -- e.g. emptying the register
}

export type TalkAnswer = { id: number, choice: number }

export type UpgradeId = "Bag" | "Lockpick"
export type BoostId = "Energy" | "Disguise" | "Candy" | "Gloves" | "Scanner"
export type BlasterId = "Zapper" | "MegaZapper"
export type ShopId = "Convenience" | "Clothes" | "Hardware" | "Guns"
export type ShopItemKind = "Upgrade" | "Boost" | "Blaster"

export type ShopItem = {
	id: string, -- an UpgradeId, BoostId or BlasterId
	kind: ShopItemKind,
	title: string,
	detail: string, -- what it does (upgrades: what you have -> what's next)
	status: string?, -- a short line such as "Level 1/3", "Active 3:12" or "Yours"
	price: number?, -- nil when there's nothing left to buy
}

export type ShopState = {
	shop: ShopId,
	title: string,
	note: string,
	items: { ShopItem },
	locked: string?, -- set while the shop isn't open yet (the items still show)
}

-- A blaster shot, for everyone's screen: the beam, and who (if anyone) got stunned.
export type BlasterFx = {
	from: Vector3,
	to: Vector3,
	hit: Model?,
	stunSeconds: number,
	color: Color3?, -- the shooter's zap colour (Cred shop); default cyan
	design: string?, -- the blaster's look (shared/BlasterLooks): each has its own effects
	muzzle: Vector3?, -- where the beam leaves the blaster (from is the head)
}

export type RaceState = "Gathering" | "Countdown" | "Racing"

-- Sent to each racer; nil means you're not in a race.
export type RaceUpdate = {
	state: RaceState,
	racers: number,
	solo: boolean, -- a solo race is a time trial against the par times
	startsAt: number, -- Gathering: when the countdown begins; otherwise when the race starts (GO)
	endsAt: number, -- Racing: the time limit
	checkpoint: number, -- checkpoints passed so far
	total: number, -- checkpoints in the whole race (every lap)
	laps: number,
	place: number, -- 1 = leading
	parSeconds: { number }, -- gold, silver, bronze
}

export type Contribution = {
	userId: number,
	name: string,
	deposited: number,
	share: number,
}

export type QuotaResult = {
	quotaIndex: number,
	passed: boolean,
	target: number,
	total: number,
	contributions: { Contribution },
	nextQuotaIndex: number,
	nextTarget: number,
	endsAt: number,
	rolledOver: boolean, -- the next quota already started (no break)
}

export type DecisionPrompt = {
	quotaIndex: number,
	prizeNow: number,
	prizeIfFail: number,
	nextQuotaIndex: number,
	nextTarget: number,
	endsAt: number,
	speakerAt: Vector3?, -- over Mr. Penny's head (his conversation box floats there)
}

export type ResultRow = {
	userId: number,
	name: string,
	deposited: number,
	share: number,
	prize: number,
	status: PlayerStatus,
}

-- A fun title on the results screen ("BIGGEST PAYDAY · Sam · $12,000 in one go").
export type Award = {
	title: string,
	name: string,
	detail: string,
}

export type RunResults = {
	reason: EndReason,
	highestQuota: number,
	yourPrize: number,
	mvpUserId: number?,
	snakeUserId: number?,
	players: { ResultRow },
	awards: { Award },
	endsAt: number,
}

-- Moments the client dresses up with sounds and effects. Money kinds show as a line at the
-- bottom of the screen: "+$10,000 | Customer served".
export type JuiceKind = "Paid" | "Spent" | "Lost" | "Deposited" | "BagFull" | "Sound" | "LevelUp"

export type JuiceEvent = {
	kind: JuiceKind,
	amount: number?, -- money kinds (BagFull: what didn't fit); LevelUp: Cred it gave (0 most levels)
	label: string?, -- money kinds: a few words on what happened
	sound: string?, -- Sound: a Config.Sounds name
	streak: number?, -- Paid: the streak multiplier it was paid at (1 or more)
	level: number?, -- LevelUp: the level you just reached
}

-- Something everyone nearby sees happen to a player in the world: cash bursting out of them
-- when they get paid, a fountain at the bank when they deposit (in their bank burst), a pillar
-- of light when they level up, a flash when they're busted.
export type FxKind = "Payout" | "Deposit" | "LevelUp" | "Busted"

export type FxEvent = {
	kind: FxKind,
	player: Player,
	at: Vector3,
	amount: number?, -- Payout, Deposit
	level: number?, -- LevelUp
	burst: string?, -- Deposit: their bank burst cosmetic id, if they wear one
}

-- The pickpocket minigame: one round per zone. The needle bounces along the bar at the round's
-- speed (bar lengths per second); press while it's inside the zone.
export type PickpocketZone = {
	start: number, -- 0 to 1 along the bar
	width: number,
	speed: number,
}

export type PickpocketGame = {
	target: string, -- the pedestrian's name
	zones: { PickpocketZone },
	roundSeconds: number,
	pauseSeconds: number,
}

-- Your saved profile, as the lobby shows it.
export type DailyView = {
	text: string,
	progress: number,
	goal: number,
	reward: number, -- Cred for finishing it today (streak bonus included)
	done: boolean,
}

export type ProfileView = {
	cred: number,
	lifetimeCred: number,
	highestQuota: number,
	runs: number,
	perks: { [string]: number }, -- upgrade id -> level bought (unlocks: 1 when owned)
	owned: { string }, -- cosmetic ids bought
	equipped: { [string]: string }, -- cosmetic slot -> id worn
	badges: { string }, -- earned badge ids
	daily: DailyView,
	streak: number, -- days in a row (0 if it lapsed)
}

-- What you picked after PLAY in the lobby: go on your own, host a lobby for others to join,
-- or join one (group is its id from the list).
export type PlayRequest = {
	mode: "Solo" | "Host" | "Join",
	group: string?,
}

-- A lobby waiting for players, as the FIND A LOBBY list shows it.
export type GroupListing = {
	id: string,
	hostName: string,
	count: number,
	partySize: number,
	departsAt: number,
}

-- The group you're in after pressing PLAY.
export type QueueStatus = {
	count: number,
	partySize: number, -- the group leaves once this many have joined
	departsAt: number,
	isHost: boolean, -- whoever hosts the lobby picks the party size and can start it early
	hostName: string,
	leaving: boolean, -- on its way to town right now
}

return {}
