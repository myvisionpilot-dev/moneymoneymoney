--!strict
-- Hustles: run perks (Config.Hustles). Every time a quota is paid, everyone still in the run is
-- offered Hustles.Offered random ones they haven't maxed. They pick one within
-- Hustles.PickSeconds, or get a random one. Hustles last the whole run. Other services ask
-- here how a player's hustles change things: pay, bag size, heat, jail, shop prices,
-- deposits, speed, break-ins, repo men and a bonus each quota.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local RunState = require(script.Parent.RunState)

type Hustle = Config.Hustle
type Offer = { options: { Hustle }, endsAt: number }

local settings = Config.Hustles
local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

local byId: { [string]: Hustle } = {}
for _, hustle in settings.List do
	byId[hustle.id] = hustle
end

local HustleService = {
	changed = Signal.new() :: Signal.Signal<Player>,
}

local owned: { [Player]: { [string]: number } } = {}
local offers: { [Player]: Offer } = {}
local freeBustQuota: { [Player]: number } = {} -- the quota their Second Chance was used in

function HustleService.stacks(player: Player, id: string): number
	local list = owned[player]
	return if list then list[id] or 0 else 0
end

-- For the snapshot: id -> stacks.
function HustleService.list(player: Player): { [string]: number }
	return table.clone(owned[player] or {})
end

-- Stacks times the hustle's value.
local function total(player: Player, id: string): number
	return HustleService.stacks(player, id) * byId[id].value
end

local function has(player: Player, id: string): boolean
	return HustleService.stacks(player, id) > 0
end

local function view(player: Player, hustle: Hustle): Types.HustleView
	return {
		id = hustle.id,
		title = hustle.title,
		detail = hustle.detail,
		stacks = HustleService.stacks(player, hustle.id),
		max = hustle.max,
	}
end

function HustleService.bagMultiplier(player: Player): number
	return 1 + total(player, "DeepPockets")
end

local function add(player: Player, hustle: Hustle)
	local list = owned[player]
	if not list then
		list = {}
		owned[player] = list
	end
	list[hustle.id] = (list[hustle.id] or 0) + 1
	if hustle.id == "DeepPockets" then
		EconomyService.setBagMultiplier(player, HustleService.bagMultiplier(player))
	end
	Notifier.send(player, `New hustle: {hustle.title}! {hustle.detail}`, "Good")
	Juice.sound(player, "Badge")
	HustleService.changed:Fire(player)
end

local function settle(player: Player, picked: Hustle)
	offers[player] = nil
	if player.Parent then
		remotes.HustleOffer:fireClient(player, nil)
		add(player, picked)
	end
end

local function settleRandomly(player: Player, offer: Offer)
	settle(player, offer.options[rng:NextInteger(1, #offer.options)])
end

-- Offers each player a pick. An earlier offer they never answered is settled at random first.
function HustleService.offer(players: { Player })
	for _, player in players do
		local pending = offers[player]
		if pending then
			settleRandomly(player, pending)
		end
		local pool: { Hustle } = {}
		for _, hustle in settings.List do
			if HustleService.stacks(player, hustle.id) < hustle.max then
				table.insert(pool, hustle)
			end
		end
		if #pool == 0 then
			continue
		end
		local options: { Hustle } = {}
		for _ = 1, math.min(settings.Offered, #pool) do
			table.insert(options, table.remove(pool, rng:NextInteger(1, #pool)) :: Hustle)
		end
		local offer = { options = options, endsAt = Timing.now() + settings.PickSeconds }
		offers[player] = offer
		local views = {}
		for _, hustle in options do
			table.insert(views, view(player, hustle))
		end
		remotes.HustleOffer:fireClient(player, { options = views, endsAt = offer.endsAt })
	end
end

-- Debug: hand them a hustle by id (any case). False if it's unknown or maxed.
function HustleService.grant(player: Player, id: string): boolean
	for _, hustle in settings.List do
		if hustle.id:lower() == id:lower() and HustleService.stacks(player, hustle.id) < hustle.max then
			add(player, hustle)
			return true
		end
	end
	return false
end

-- They cashed out: put their open offer away.
function HustleService.closeOffer(player: Player)
	if offers[player] then
		offers[player] = nil
		remotes.HustleOffer:fireClient(player, nil)
	end
end

-- The run is over: put away every open offer.
function HustleService.closeOffers()
	for player in offers do
		remotes.HustleOffer:fireClient(player, nil)
	end
	table.clear(offers)
end

local function onPick(player: Player, payload: unknown)
	local offer = offers[player]
	if not limiter:allow(player) or typeof(payload) ~= "string" or not offer then
		return
	end
	for _, hustle in offer.options do
		if hustle.id == payload then
			settle(player, hustle)
			return
		end
	end
end

-- Smooth Talker (legal) or Sticky Fingers (crimes).
function HustleService.payMultiplier(player: Player, legal: boolean): number
	return 1 + total(player, if legal then "SmoothTalker" else "StickyFingers")
end

-- Lucky Break: true if this payout is doubled.
function HustleService.lucky(player: Player): boolean
	local chance = total(player, "LuckyBreak")
	return chance > 0 and rng:NextNumber() < chance
end

function HustleService.heatDecayMultiplier(player: Player): number
	return 1 + total(player, "Ghost")
end

function HustleService.heatGainMultiplier(player: Player): number
	return (1 - byId.CoolHead.value) ^ HustleService.stacks(player, "CoolHead")
end

-- Second Chance: true (and used up for this quota) if this bust costs them nothing.
function HustleService.useFreeBust(player: Player): boolean
	if not has(player, "SecondChance") or freeBustQuota[player] == RunState.quotaIndex then
		return false
	end
	freeBustQuota[player] = RunState.quotaIndex
	return true
end

function HustleService.jailMultiplier(player: Player): number
	return if has(player, "EscapeArtist") then byId.EscapeArtist.value else 1
end

function HustleService.shopMultiplier(player: Player): number
	return (1 - byId.Haggler.value) ^ HustleService.stacks(player, "Haggler")
end

-- Interest: the extra share of each deposit that counts toward the quota.
function HustleService.depositBonus(player: Player): number
	return total(player, "Interest")
end

function HustleService.speedMultiplier(player: Player): number
	return 1 + total(player, "FleetFeet")
end

function HustleService.breakInMultiplier(player: Player): number
	return if has(player, "Safecracker") then byId.Safecracker.value else 1
end

-- How full their bag can get before a repo man comes.
function HustleService.repoFraction(player: Player): number
	return if has(player, "RepoRepellent") then byId.RepoRepellent.value else Config.Repo.BagFraction
end

-- Allowance: the share of the quota target they get at the start of each quota.
function HustleService.allowance(player: Player): number
	return total(player, "Allowance")
end

function HustleService.start()
	remotes.PickHustle:onServer(onPick)
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player], offers[player], freeBustQuota[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = Timing.now()
			for player, offer in offers do
				if now >= offer.endsAt then
					settleRandomly(player, offer)
				end
			end
		end
	end)
end

return HustleService
