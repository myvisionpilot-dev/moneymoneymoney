--!strict
-- BANK ERROR: Mr. Penny's van spilled its bags. Events.BankError.Bags bags of cash fall all
-- over town at once; each goes to the first to grab it. Everyone's marker points at the bag
-- nearest them, and it's over when they're all gone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local CashBag = require(script.Parent.CashBag)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local Spots = require(script.Parent.Spots)
local TownEvent = require(script.Parent.TownEvent)

local FALL_SECONDS = 3
local GRAB_RANGE = 10
local MARK_SECONDS = 1
local SPREAD_STUDS = 70 -- bags this far apart where the town allows

local settings = Config.Events.BankError
local rng = Random.new()

local bags: { CashBag.Bag } = {}
local context: TownEvent.Context? = nil
local lastMark = 0

local BankError = {
	id = "BankError",
	title = "BANK ERROR",
	seconds = settings.Seconds,
}

function BankError.canStart(): boolean
	return #Spots.all() >= settings.Bags
end

-- Spots for the bags, spread apart where possible.
local function pickSpots(): { Vector3 }
	local pool = Spots.all()
	local chosen: { Vector3 } = {}
	for _ = 1, 40 do
		if #chosen >= settings.Bags or #pool == 0 then
			break
		end
		local spot = table.remove(pool, rng:NextInteger(1, #pool)) :: Vector3
		local apart = true
		for _, other in chosen do
			if (other - spot).Magnitude < SPREAD_STUDS then
				apart = false
			end
		end
		if apart or #pool < settings.Bags then
			table.insert(chosen, spot)
		end
	end
	return chosen
end

local function remaining(): number
	local count = 0
	for _, bag in bags do
		if not bag.gone then
			count += 1
		end
	end
	return count
end

function BankError.start(ctx: TownEvent.Context)
	context = ctx
	table.clear(bags)
	lastMark = 0
	local pay = math.floor(settings.Pay * ctx.tierMultiplier + 0.5)
	ctx.announce("Bank error! Grab the cash bags!", nil)
	for index, spot in pickSpots() do
		task.delay((index - 1) * 0.3, function()
			if context ~= ctx then
				return
			end
			local bag = CashBag.drop(spot + Vector3.new(0, 1.5, 0), FALL_SECONDS, GRAB_RANGE, function(player: Player)
				PayNotice.earn(player, pay, "Bank bag grabbed", "bank error", true)
				Notifier.others(player, `{player.DisplayName} grabbed a bank bag!`, "Info")
				if remaining() == 0 then
					ctx.finish()
				end
			end)
			table.insert(bags, bag)
		end)
	end
end

-- Everyone's marker on the bag nearest them.
function BankError.tick()
	local ctx = context
	if not ctx or os.clock() - lastMark < MARK_SECONDS then
		return
	end
	lastMark = os.clock()
	local left = remaining()
	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.getRoot(player)
		local nearest: Vector3? = nil
		local best = math.huge
		for _, bag in bags do
			local distance = if root then (bag.at - root.Position).Magnitude else 0
			if not bag.gone and distance < best then
				nearest, best = bag.at, distance
			end
		end
		if nearest then
			ctx.announceTo(player, `{left} bag{if left == 1 then "" else "s"} left!`, nearest)
		end
	end
end

function BankError.stop()
	context = nil
	for _, bag in bags do
		CashBag.remove(bag)
	end
	table.clear(bags)
end

return BankError
