--!strict
-- All-time leaderboards in OrderedDataStores: Cred earned and highest quota cleared. The Match
-- submits after each run (only ever raising a score); the lobby reads the top entries.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)

export type Board = "Cred" | "Quota"

export type Entry = {
	userId: number,
	name: string,
	value: number,
}

local STORES: { [Board]: string } = {
	Cred = "LifetimeCred_v1",
	Quota = "HighestQuota_v1",
}

local Leaderboards = {}

local names: { [number]: string } = {}

local function storeFor(board: Board): OrderedDataStore
	return DataStoreService:GetOrderedDataStore(Profiles.storeName(STORES[board]))
end

-- Raises this player's score if `value` beats it. Runs in the background.
function Leaderboards.submit(player: Player, board: Board, value: number)
	local key = tostring(player.UserId)
	local score = math.floor(value)
	names[player.UserId] = player.DisplayName
	task.spawn(function()
		-- Returning nil cancels the write, so a worse score never replaces a better one.
		local function raise(old: any): number?
			local current = if typeof(old) == "number" then old else 0
			return if score > current then score else nil
		end
		local ok, message = pcall(function()
			storeFor(board):UpdateAsync(key, raise :: any)
		end)
		if not ok then
			warn(`[Leaderboards] Couldn't save {board} score: {message}`)
		end
	end)
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local found = if ok then name else `Player {userId}`
	names[userId] = found
	return found
end

-- The top Leaderboards.Size entries, best first (nil if the DataStore can't be reached).
function Leaderboards.top(board: Board): { Entry }?
	local ok, pages = pcall(function(): DataStorePages
		return storeFor(board):GetSortedAsync(false, Config.Leaderboards.Size)
	end)
	if not ok then
		return nil
	end
	local entries: { Entry } = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId and typeof(item.value) == "number" then
			table.insert(entries, { userId = userId, name = nameOf(userId), value = item.value })
		end
	end
	return entries
end

return Leaderboards
