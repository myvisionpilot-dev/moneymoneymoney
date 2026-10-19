--!strict
-- Cred packs bought with Robux (Config.Store.CredPacks, developer products), in both places:
-- Roblox calls ProcessReceipt for each purchase until we say it's granted, maybe more than once
-- and maybe on a later server (even in the Match), so every receipt id is remembered in the
-- save and only ever paid once. Bought Cred doesn't count as earned (lifetime Cred and the Top
-- Earners board).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)

local LOAD_WAIT_SECONDS = 10

local Purchases = {}

local function packFor(productId: number): Config.CredPack?
	for _, pack in Config.Store.CredPacks do
		if pack.id > 0 and pack.id == productId then
			return pack
		end
	end
	return nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local pack = packFor(receipt.ProductId)
	if not pack then
		warn(`[Purchases] no Cred pack has product id {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Profiles.waitFor(player, LOAD_WAIT_SECONDS)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again later
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already paid
	end
	Profiles.addCred(player, data, pack.cred, `bought a {pack.cred} Cred pack ({purchaseId})`, true)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > Config.Store.ReceiptsKept do
		table.remove(data.Receipts, 1)
	end
	Profiles.markChanged(player)
	Profiles.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Purchases.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return Purchases
