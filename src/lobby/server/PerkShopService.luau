--!strict
-- The speed shop stand in the lobby: hold E to browse, then buy perk levels with Cred (fixed
-- prices, nothing random). They're kept for good (Perks puts them on your character).
-- Everything is checked here; the client only sends the perk id.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Perks = require(ServerScriptService.Common.Perks)
local Profiles = require(ServerScriptService.Common.Profiles)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)

local SHOP_TAG = "PerkShop"
local RANGE_SLACK = 6

local remotes = Remotes.lobby()
local openLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local PerkShopService = {}

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

local function nearShop(player: Player): boolean
	for _, stand in CollectionService:GetTagged(SHOP_TAG) do
		if
			stand:IsA("BasePart")
			and CharacterUtil.distanceTo(player, stand.Position) <= Config.Perks.ShopRangeStuds + RANGE_SLACK
		then
			return true
		end
	end
	return false
end

local function onBuy(player: Player, payload: unknown)
	if not buyLimiter:allow(player) or typeof(payload) ~= "string" then
		return
	end
	local perk = Catalog.perk(payload)
	local data = Profiles.get(player)
	if not perk or not data or not nearShop(player) then
		return
	end
	local level = Perks.level(player, perk.id)
	local price = Catalog.perkPrice(perk.id, level)
	if not price then
		notify(player, `{perk.name} is maxed out.`, "Info")
		return
	end
	if data.Cred < price then
		notify(player, `You need {Format.cred(price)} for that. Earn Cred by finishing runs!`, "Bad")
		return
	end
	Profiles.addCred(player, data, -price, `bought {perk.id} level {level + 1}`)
	data.Perks[perk.id] = level + 1
	Profiles.markChanged(player)
	Perks.refresh(player)
	notify(player, `{perk.name} level {level + 1}! It's yours for good.`, "Good")
end

local function setupStand(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PerkShopPrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = "Speed Shop"
	prompt.MaxActivationDistance = Config.Perks.ShopRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if openLimiter:allow(player) and Profiles.get(player) then
			Profiles.markChanged(player) -- fresh numbers for the panel
			remotes.OpenPerkShop:fireClient(player, nil)
		end
	end)
	prompt.Parent = instance
end

function PerkShopService.start()
	for _, instance in CollectionService:GetTagged(SHOP_TAG) do
		setupStand(instance)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupStand)
	remotes.BuyPerk:onServer(onBuy)
end

return PerkShopService
