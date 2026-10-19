--!strict
-- Cash drop: a bag of money falls onto a random footpath spot (a pedestrian waypoint). The
-- first player to grab it keeps it (Events.CashDrop.Pay, scaled by quota; a legal job for hustles).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CashBag = require(script.Parent.CashBag)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local TownEvent = require(script.Parent.TownEvent)

local SPOT_TAG = "PedWaypoint"

local settings = Config.Events.CashDrop

local bag: CashBag.Bag? = nil

local CashDrop = {
	id = "CashDrop",
	title = "CASH DROP",
	seconds = settings.Seconds,
}

function CashDrop.canStart(): boolean
	return #CollectionService:GetTagged(SPOT_TAG) > 0
end

function CashDrop.start(ctx: TownEvent.Context)
	local spots = JobKit.tagged(SPOT_TAG)
	local spot = spots[Random.new():NextInteger(1, #spots)]
	local ground = JobKit.ground(spot).Position + Vector3.new(0, 1.5, 0)
	ctx.announce("Cash bag! First to grab it wins!", ground)
	bag = CashBag.drop(ground, settings.FallSeconds, settings.RangeStuds, function(player: Player)
		bag = nil
		local pay = math.floor(settings.Pay * ctx.tierMultiplier + 0.5)
		PayNotice.earn(player, pay, "Cash drop grabbed", "cash drop", true)
		Notifier.others(player, `{player.DisplayName} grabbed the cash drop!`, "Info")
		ctx.finish()
	end)
end

function CashDrop.tick() end

function CashDrop.stop()
	if bag then
		CashBag.remove(bag)
		bag = nil
	end
end

return CashDrop
