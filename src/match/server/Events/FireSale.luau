--!strict
-- Fire sale: one shop (a counter's Shop attribute) is Events.FireSale.Discount off for a while.
-- ShopService asks FireSale.multiplier(shop) for every price.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local RunState = require(script.Parent.Parent.RunState)
local TownEvent = require(script.Parent.TownEvent)

local COUNTER_TAG = "ShopCounter"
-- What the banner calls each shop (the shop windows' titles live in ShopService).
local NAMES: { [string]: string } = {
	Clothes = "BAGS",
	Hardware = "Handy Hank's",
	Convenience = "The convenience stores",
	Guns = "Tony's Blasters",
}

local settings = Config.Events.FireSale

local onSale: string? = nil

local FireSale = {
	id = "FireSale",
	title = "FIRE SALE",
	seconds = settings.Seconds,
}

function FireSale.multiplier(shop: Types.ShopId): number
	return if onSale == shop then 1 - settings.Discount else 1
end

function FireSale.canStart(): boolean
	return #CollectionService:GetTagged(COUNTER_TAG) > 0
end

function FireSale.start(ctx: TownEvent.Context)
	local counters: { [string]: BasePart } = {}
	local shops: { string } = {}
	for _, counter in CollectionService:GetTagged(COUNTER_TAG) do
		local shop = counter:GetAttribute("Shop")
		local open = shop ~= "Guns" or RunState.quotaIndex >= Config.Blasters.UnlockQuota
		if typeof(shop) == "string" and NAMES[shop] and open and counter:IsA("BasePart") and not counters[shop] then
			counters[shop] = counter
			table.insert(shops, shop)
		end
	end
	if #shops == 0 then
		ctx.finish()
		return
	end
	local shop = shops[Random.new():NextInteger(1, #shops)]
	onSale = shop
	local off = math.floor(settings.Discount * 100 + 0.5)
	ctx.announce(`{NAMES[shop]}: everything {off}% off. Go shopping!`, counters[shop].Position)
end

function FireSale.tick() end

function FireSale.stop()
	onSale = nil
end

return FireSale
