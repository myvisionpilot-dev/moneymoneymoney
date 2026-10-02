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
	OpenCosmetics: ToClient<nil>, -- you used the cosmetics stand
	LeaveQueue: ToServer<nil>,
	SetPartySize: ToServer<number>,
	BuyCosmetic: ToServer<string>, -- cosmetic id
	EquipCosmetic: ToServer<string>, -- cosmetic id; equipping what you're wearing takes it off
}

export type MatchRemotes = {
	RunSnapshot: ToClient<Types.RunSnapshot>,
	PennySays: ToClient<Types.PennyLine>,
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
	BlasterFx: ToClient<Types.BlasterFx>, -- someone fired a blaster
	ClientReady: ToServer<nil>,
	PickpocketPresses: ToServer<{ number }>, -- seconds into each round when you pressed
	SubmitDecision: ToServer<Types.Decision>,
	ChooseDoorOffer: ToServer<number>, -- 1 or 2, or 0 to walk away
	BuyItem: ToServer<string>, -- an item id from the shop you're at
	FireBlaster: ToServer<Vector3>, -- where you aimed
	SetRiding: ToServer<boolean>, -- get on or off your ride
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
		OpenCosmetics = toClient("OpenCosmetics"),
		LeaveQueue = toServer("LeaveQueue"),
		SetPartySize = toServer("SetPartySize"),
		BuyCosmetic = toServer("BuyCosmetic"),
		EquipCosmetic = toServer("EquipCosmetic"),
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
		PennySays = toClient("PennySays"),
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
		BlasterFx = toClient("BlasterFx"),
		ClientReady = toServer("ClientReady"),
		PickpocketPresses = toServer("PickpocketPresses"),
		SubmitDecision = toServer("SubmitDecision"),
		ChooseDoorOffer = toServer("ChooseDoorOffer"),
		BuyItem = toServer("BuyItem"),
		FireBlaster = toServer("FireBlaster"),
		SetRiding = toServer("SetRiding"),
	}
	matchRemotes = remotes
	return remotes
end

return Remotes
