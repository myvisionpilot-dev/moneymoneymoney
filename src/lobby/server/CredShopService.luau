--!strict
-- Spending Cred (the lobby's UPGRADES and CUSTOMISATION windows): upgrades (levelled), loadout
-- unlocks and cosmetics, all at fixed prices (nothing random) and kept for good. Cosmetics are
-- worn one per slot. Everything is checked here; the client only sends an id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Perks = require(ServerScriptService.Common.Perks)
local Profiles = require(ServerScriptService.Common.Profiles)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Style = require(ServerScriptService.Common.Style)

local remotes = Remotes.lobby()
local buyLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local CredShopService = {}

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

-- Takes the Cred, or says how much more they need.
local function pay(player: Player, data: Profiles.Data, price: number, reason: string): boolean
	if data.Cred < price then
		notify(player, `You need {Format.cred(price - data.Cred)} more. Earn Cred by finishing runs!`, "Bad")
		return false
	end
	Profiles.addCred(player, data, -price, reason)
	return true
end

local function buy(player: Player, data: Profiles.Data, id: string)
	local upgrade = Catalog.upgrade(id)
	if upgrade then
		local level = Perks.level(player, id)
		local price = Catalog.upgradePrice(id, level)
		if not price then
			notify(player, `{upgrade.name} is maxed out.`, "Info")
		elseif pay(player, data, price, `bought {id} level {level + 1}`) then
			data.Perks[id] = level + 1
			notify(
				player,
				`{upgrade.name} level {level + 1}: {upgrade.effect(Catalog.upgradeAmount(id, level + 1))}.`,
				"Good"
			)
		end
		return
	end
	local unlock = Catalog.unlock(id)
	if unlock then
		local price = Catalog.unlockPrice(id)
		if Perks.has(player, id) or not price then
			return
		end
		if pay(player, data, price, `unlocked {id}`) then
			data.Perks[id] = 1
			notify(player, `Unlocked {unlock.name}! {unlock.text}`, "Good")
		end
		return
	end
	local item = Cosmetics.get(id)
	if item and not data.Owned[id] and pay(player, data, Cosmetics.price(item), `bought cosmetic {id}`) then
		data.Owned[id] = true
		data.Equipped[item.slot] = id -- wear it straight away
		notify(player, `{item.name} is yours, and you're wearing it.`, "Good")
	end
end

local function onBuy(player: Player, payload: unknown)
	if not buyLimiter:allow(player) or typeof(payload) ~= "string" then
		return
	end
	local data = Profiles.get(player)
	if not data then
		return
	end
	buy(player, data, payload)
	Profiles.markChanged(player)
	Perks.refresh(player)
	Style.refresh(player)
end

-- Wear a cosmetic they own, or take it off if they're already wearing it.
local function onEquip(player: Player, payload: unknown)
	if not buyLimiter:allow(player) or typeof(payload) ~= "string" then
		return
	end
	local data = Profiles.get(player)
	local item = Cosmetics.get(payload)
	if not data or not item or not data.Owned[item.id] then
		return
	end
	if data.Equipped[item.slot] == item.id then
		data.Equipped[item.slot] = nil
	else
		data.Equipped[item.slot] = item.id
	end
	Profiles.markChanged(player)
	Style.refresh(player)
end

function CredShopService.start()
	remotes.BuyCredItem:onServer(onBuy)
	remotes.EquipCosmetic:onServer(onEquip)
end

return CredShopService
