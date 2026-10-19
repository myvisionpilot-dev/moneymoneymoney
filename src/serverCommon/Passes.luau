--!strict
-- Game passes (Config.Store.Passes), in both places: who owns which, asked of Roblox when they
-- join and again the moment they buy one. Passes.has also counts a pack (the Big Baller Pack) as
-- every pass it includes. What you own shows on you as attributes (Pass_DoubleCash = true) for
-- the store's cards and the chat tag. In a Studio test, a TestPass_<key> attribute (or the
-- match's /pass command) counts as owning it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local IS_STUDIO = RunService:IsStudio()

local Passes = {
	changed = Signal.new() :: Signal.Signal<Player>, -- they bought one (or a test one was given)
}

local owned: { [Player]: { [string]: boolean } } = {}

local function ownsItself(player: Player, key: string): boolean
	local mine = owned[player]
	if mine and mine[key] then
		return true
	end
	return IS_STUDIO and player:GetAttribute(`TestPass_{key}`) == true
end

function Passes.has(player: Player, key: string): boolean
	if ownsItself(player, key) then
		return true
	end
	for _, pass in Config.Store.Passes do
		if pass.includes and table.find(pass.includes, key) and ownsItself(player, pass.key) then
			return true
		end
	end
	return false
end

local function publish(player: Player)
	for _, pass in Config.Store.Passes do
		player:SetAttribute(`Pass_{pass.key}`, if Passes.has(player, pass.key) then true else nil)
	end
	Passes.changed:Fire(player)
end

local function check(player: Player)
	local mine: { [string]: boolean } = {}
	for _, pass in Config.Store.Passes do
		if pass.id > 0 then
			local ok, has = pcall(function(): boolean
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and has then
				mine[pass.key] = true
			elseif not ok then
				warn(`[Passes] couldn't check {pass.key} for {player.Name}: {has}`)
			end
		end
	end
	if player.Parent == Players then
		owned[player] = mine
		publish(player)
	end
end

local function watch(player: Player)
	task.spawn(check, player)
	if IS_STUDIO then
		player.AttributeChanged:Connect(function(name: string)
			if name:sub(1, 9) == "TestPass_" then
				publish(player)
			end
		end)
	end
end

function Passes.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for _, pass in Config.Store.Passes do
				if pass.id == passId then
					local mine = owned[player] or {}
					mine[pass.key] = true
					owned[player] = mine
					print(`[Passes] {player.Name} bought {pass.key}`)
					publish(player)
				end
			end
		end
	)
end

return Passes
