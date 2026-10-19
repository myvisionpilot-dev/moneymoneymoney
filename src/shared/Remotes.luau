--!strict
-- Every remote in the game, with typed payloads.
-- Client-to-server payloads arrive as `unknown`: validate them before use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

export type ToClient<T> = {
	fireClient: (self: ToClient<T>, player: Player, payload: T) -> (),
	fireAll: (self: ToClient<T>, payload: T) -> (),
	onClient: (self: ToClient<T>, handler: (payload: T) -> ()) -> RBXScriptConnection,
}

export type ToServer<T> = {
	fire: (self: ToServer<T>, payload: T) -> (),
	onServer: (self: ToServer<T>, handler: (player: Player, payload: unknown) -> ()) -> RBXScriptConnection,
}

export type LobbyRemotes = {
	QueueStatus: ToClient<Types.QueueStatus?>,
	Notify: ToClient<Types.Notice>,
	ProfileSync: ToClient<Types.ProfileView>,
	GroupList: ToClient<{ Types.GroupListing }>, -- the lobbies waiting for players
	Play: ToServer<Types.PlayRequest>, -- go alone, host a lobby or join one
	LeaveQueue: ToServer<nil>,
	SetPartySize: ToServer<number>,
	BuyCredItem: ToServer<string>, -- an upgrade (its next level), unlock or cosmetic id
	EquipCosmetic: ToServer<string>, -- a cosmetic id you own: wear it, or take it off if worn
	WheelResult: ToClient<Types.WheelResult>, -- your Lucky Wheel spin stopped: what you won
	BuyStrength: ToServer<number>, -- a Config.Store.StrengthPacks index, paid in Cred
	CheckGroup: ToServer<nil>, -- look again: did I just join the group?
}

export type MatchRemotes = {
	RunSnapshot: ToClient<Types.RunSnapshot>,
	Announce: ToClient<Types.Announcement>, -- Mr. Penny or town news, under the quota panel
	Notify: ToClient<Types.Notice>,
	JobGuide: ToClient<Types.JobGuide?>,
	QuotaResult: ToClient<Types.QuotaResult>,
	DecisionPrompt: ToClient<Types.DecisionPrompt>,
	RunResults: ToClient<Types.RunResults>,
	DoorOffer: ToClient<Types.DoorOffer?>,
	ShopOpen: ToClient<Types.ShopState>,
	RaceUpdate: ToClient<Types.RaceUpdate?>,
	Juice: ToClient<Types.JuiceEvent>,
	PickpocketGame: ToClient<Types.PickpocketGame?>, -- nil ends it
	CrateOpened: ToClient<Types.CrateReveal>, -- the crate you just bought at Tony's, and what was in it
	Fx: ToClient<Types.FxEvent>, -- a payout, deposit, level-up or bust everyone nearby sees
	HustleOffer: ToClient<Types.HustleOffer?>, -- pick one of these; nil closes the offer
	TownEvent: ToClient<Types.TownEventView?>, -- nil: no event right now
	Talk: ToClient<Types.Talk?>, -- someone talks to you; nil ends the conversation
	LockpickGame: ToClient<Types.LockpickGame?>, -- your jail cell's lock; nil: you're out
	RegisterGame: ToClient<Types.RegisterGame?>, -- the till you're robbing; nil: it's over
	Gig: ToClient<Types.GigView?>, -- your phone: a gig offer, the one you're on, or how it went
	Toss: ToClient<Types.Toss>, -- something flying through the air (everyone draws it)
	JobFx: ToClient<Types.JobFx>, -- a crack, a smash, a chomp... (everyone nearby sees it)
	TugGame: ToClient<Types.TugGame?>, -- the dog's pulling: tap to hold them back; nil ends it
	Tutorial: ToClient<Types.TutorialStep?>, -- the first-join tutorial's step; nil: no tutorial
	ClientReady: ToServer<nil>,
	PickpocketPresses: ToServer<{ number }>, -- seconds into each round when you pressed
	SubmitDecision: ToServer<Types.Decision>,
	ChooseDoorOffer: ToServer<number>, -- 1 or 2, or 0 to walk away
	BuyItem: ToServer<string>, -- an item id from the shop you're at
	LeaveCar: ToServer<nil>, -- get out of the car you're driving (not a race car)
	PickHustle: ToServer<string>, -- a hustle id from your current offer
	TalkAnswer: ToServer<Types.TalkAnswer>, -- the answer you picked in a conversation
	LockpickPress: ToServer<Types.LockpickPress>, -- you pressed on a pin of the jail lock
	RegisterGrab: ToServer<number>, -- you grabbed a bill from this slot of the till
	GigAnswer: ToServer<Types.GigAnswer>, -- you accepted (or ignored) the gig on your phone
	Throw: ToServer<Vector3>, -- you threw what you're holding (a parcel, a letter, the ball) at this spot
	TugTap: ToServer<nil>, -- one tap on the leash
	BuyStrength: ToServer<number>, -- a Config.Store.StrengthPacks index, paid in Cred
	CheckGroup: ToServer<nil>, -- look again: did I just join the group?
	SetProne: ToServer<boolean>, -- lie down (C) or get back up
	TripLaser: ToServer<nil>, -- you touched a laser in the house you broke into
}

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local function getFolder(): Instance
	if not IS_SERVER then
		return ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getRemote(name: string): RemoteEvent
	local folder = getFolder()
	if not IS_SERVER then
		return folder:WaitForChild(name) :: RemoteEvent
	end
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function toClient<T>(name: string): ToClient<T>
	local remote = getRemote(name)
	return {
		fireClient = function(_self: ToClient<T>, player: Player, payload: T)
			remote:FireClient(player, payload)
		end,
		fireAll = function(_self: ToClient<T>, payload: T)
			remote:FireAllClients(payload)
		end,
		onClient = function(_self: ToClient<T>, handler: (payload: T) -> ()): RBXScriptConnection
			return remote.OnClientEvent:Connect(handler)
		end,
	}
end

local function toServer<T>(name: string): ToServer<T>
	local remote = getRemote(name)
	return {
		fire = function(_self: ToServer<T>, payload: T)
			remote:FireServer(payload)
		end,
		onServer = function(_self: ToServer<T>, handler: (player: Player, payload: unknown) -> ()): RBXScriptConnection
			return remote.OnServerEvent:Connect(handler)
		end,
	}
end

local Remotes = {}

local lobbyRemotes: LobbyRemotes? = nil
local matchRemotes: MatchRemotes? = nil

function Remotes.lobby(): LobbyRemotes
	if lobbyRemotes then
		return lobbyRemotes
	end
	local remotes: LobbyRemotes = {
		QueueStatus = toClient("QueueStatus"),
		Notify = toClient("Notify"),
		ProfileSync = toClient("ProfileSync"),
		GroupList = toClient("GroupList"),
		Play = toServer("Play"),
		LeaveQueue = toServer("LeaveQueue"),
		SetPartySize = toServer("SetPartySize"),
		BuyCredItem = toServer("BuyCredItem"),
		EquipCosmetic = toServer("EquipCosmetic"),
		WheelResult = toClient("WheelResult"),
		BuyStrength = toServer("BuyStrength"),
		CheckGroup = toServer("CheckGroup"),
	}
	lobbyRemotes = remotes
	return remotes
end

function Remotes.match(): MatchRemotes
	if matchRemotes then
		return matchRemotes
	end
	local remotes: MatchRemotes = {
		RunSnapshot = toClient("RunSnapshot"),
		Announce = toClient("Announce"),
		Notify = toClient("Notify"),
		JobGuide = toClient("JobGuide"),
		QuotaResult = toClient("QuotaResult"),
		DecisionPrompt = toClient("DecisionPrompt"),
		RunResults = toClient("RunResults"),
		DoorOffer = toClient("DoorOffer"),
		ShopOpen = toClient("ShopOpen"),
		RaceUpdate = toClient("RaceUpdate"),
		Juice = toClient("Juice"),
		PickpocketGame = toClient("PickpocketGame"),
		CrateOpened = toClient("CrateOpened"),
		Fx = toClient("Fx"),
		HustleOffer = toClient("HustleOffer"),
		TownEvent = toClient("TownEvent"),
		Talk = toClient("Talk"),
		LockpickGame = toClient("LockpickGame"),
		RegisterGame = toClient("RegisterGame"),
		Gig = toClient("Gig"),
		Toss = toClient("Toss"),
		JobFx = toClient("JobFx"),
		TugGame = toClient("TugGame"),
		Tutorial = toClient("Tutorial"),
		ClientReady = toServer("ClientReady"),
		PickpocketPresses = toServer("PickpocketPresses"),
		SubmitDecision = toServer("SubmitDecision"),
		ChooseDoorOffer = toServer("ChooseDoorOffer"),
		BuyItem = toServer("BuyItem"),
		LeaveCar = toServer("LeaveCar"),
		PickHustle = toServer("PickHustle"),
		TalkAnswer = toServer("TalkAnswer"),
		LockpickPress = toServer("LockpickPress"),
		RegisterGrab = toServer("RegisterGrab"),
		GigAnswer = toServer("GigAnswer"),
		Throw = toServer("Throw"),
		TugTap = toServer("TugTap"),
		BuyStrength = toServer("BuyStrength"),
		CheckGroup = toServer("CheckGroup"),
		SetProne = toServer("SetProne"),
		TripLaser = toServer("TripLaser"),
	}
	matchRemotes = remotes
	return remotes
end

return Remotes
