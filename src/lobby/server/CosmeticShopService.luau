--!strict
-- The cosmetics stand in the lobby: hold E to browse, then buy with Cred (fixed prices, nothing
-- random) and equip. Everything is checked here; the client only sends item ids.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Cosmetics = require(ServerScriptService.Common.Cosmetics)
local Profiles = require(ServerScriptService.Common.Profiles)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)

local SHOP_TAG = "CosmeticShop"
local RANGE_SLACK = 6

local remotes = Remotes.lobby()
local openLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local equipLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local CosmeticShopService = {}

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

local function nearShop(player: Player): boolean
	for _, stand in CollectionService:GetTagged(SHOP_TAG) do
		if
			stand:IsA("BasePart")
			and CharacterUtil.distanceTo(player, stand.Position) <= Config.Cosmetics.ShopRangeStuds + RANGE_SLACK
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
	local item, price = Catalog.cosmetic(payload), Catalog.price(payload)
	local data = Profiles.get(player)
	if not item or not price or not data or not nearShop(player) then
		return
	end
	if data.Owned[item.id] then
		notify(player, "You already own that.", "Info")
		return
	end
	if data.Cred < price then
		notify(player, `You need {Format.cred(price)} for that. Earn Cred by finishing runs!`, "Bad")
		return
	end
	Profiles.addCred(player, data, -price, `bought {item.id}`)
	data.Owned[item.id] = true
	data.Equipped[item.slot] = item.id
	Profiles.markChanged(player)
	Cosmetics.refresh(player)
	notify(player, `You bought {item.name}! It's on.`, "Good")
end

-- Equipping what you already wear takes it off.
local function onEquip(player: Player, payload: unknown)
	if not equipLimiter:allow(player) or typeof(payload) ~= "string" then
		return
	end
	local item = Catalog.cosmetic(payload)
	local data = Profiles.get(player)
	if not item or not data or not data.Owned[item.id] then
		return
	end
	data.Equipped[item.slot] = if data.Equipped[item.slot] == item.id then "" else item.id
	Profiles.markChanged(player)
	Cosmetics.refresh(player)
end

local function setupStand(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CosmeticsPrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = "Cosmetics"
	prompt.MaxActivationDistance = Config.Cosmetics.ShopRangeStuds
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if openLimiter:allow(player) and Profiles.get(player) then
			Profiles.markChanged(player) -- fresh numbers for the panel
			remotes.OpenCosmetics:fireClient(player, nil)
		end
	end)
	prompt.Parent = instance
end

function CosmeticShopService.start()
	for _, instance in CollectionService:GetTagged(SHOP_TAG) do
		setupStand(instance)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupStand)
	remotes.BuyCosmetic:onServer(onBuy)
	remotes.EquipCosmetic:onServer(onEquip)
end

return CosmeticShopService
