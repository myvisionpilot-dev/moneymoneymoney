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
	LeaveQueue: ToServer<nil>,
}

export type MatchRemotes = {
	RunSnapshot: ToClient<Types.RunSnapshot>,
	TonySays: ToClient<Types.TonyLine>,
	Notify: ToClient<Types.Notice>,
	DeliveryJob: ToClient<Types.DeliveryJob?>,
	QuotaResult: ToClient<Types.QuotaResult>,
	DecisionPrompt: ToClient<Types.DecisionPrompt>,
	RunResults: ToClient<Types.RunResults>,
	ClientReady: ToServer<nil>,
	SubmitDecision: ToServer<Types.Decision>,
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
		LeaveQueue = toServer("LeaveQueue"),
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
		TonySays = toClient("TonySays"),
		Notify = toClient("Notify"),
		DeliveryJob = toClient("DeliveryJob"),
		QuotaResult = toClient("QuotaResult"),
		DecisionPrompt = toClient("DecisionPrompt"),
		RunResults = toClient("RunResults"),
		ClientReady = toServer("ClientReady"),
		SubmitDecision = toServer("SubmitDecision"),
	}
	matchRemotes = remotes
	return remotes
end

return Remotes
