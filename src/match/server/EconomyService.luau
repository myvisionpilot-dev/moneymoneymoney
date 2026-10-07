--!strict
-- Carried and deposited cash for every player.
-- The only place money changes, and every change is logged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Timing = require(ReplicatedStorage.Shared.Timing)

local MAX_LOG = 5000

export type Account = {
	userId: number,
	carried: number,
	deposited: number, -- whole-run total; this is the player's contribution
	bagCapacity: number, -- bagBase x bagMultiplier x perkMultiplier
	bagBase: number, -- from the bag upgrades
	bagMultiplier: number, -- from hustles
	perkMultiplier: number, -- from the Big Pockets upgrade (Cred shop)
}

export type Entry = {
	time: number,
	userId: number,
	kind: "carried" | "deposit",
	delta: number,
	reason: string,
	carried: number,
	deposited: number,
}

local accounts: { [number]: Account } = {}
local log: { Entry } = {}
local teamDeposited = 0

local EconomyService = {
	changed = Signal.new() :: Signal.Signal<number>, -- fires with the userId that changed
}

local function record(account: Account, kind: "carried" | "deposit", delta: number, reason: string)
	table.insert(log, {
		time = Timing.now(),
		userId = account.userId,
		kind = kind,
		delta = delta,
		reason = reason,
		carried = account.carried,
		deposited = account.deposited,
	})
	if #log > MAX_LOG then
		table.remove(log, 1)
	end
	EconomyService.changed:Fire(account.userId)
end

function EconomyService.account(player: Player): Account
	local account = accounts[player.UserId]
	if not account then
		account = {
			userId = player.UserId,
			carried = 0,
			deposited = 0,
			bagCapacity = Config.Economy.BaseBagCapacity,
			bagBase = Config.Economy.BaseBagCapacity,
			bagMultiplier = 1,
			perkMultiplier = 1,
		}
		accounts[player.UserId] = account
	end
	return account
end

function EconomyService.get(userId: number): Account?
	return accounts[userId]
end

function EconomyService.teamDeposited(): number
	return teamDeposited
end

function EconomyService.isFull(player: Player): boolean
	local account = EconomyService.account(player)
	return account.carried >= account.bagCapacity
end

-- Adds carried cash up to bag capacity. Returns how much actually fit.
function EconomyService.addCarried(player: Player, amount: number, reason: string, ignoreCapacity: boolean?): number
	local whole = math.floor(amount)
	if whole <= 0 then
		return 0
	end
	local account = EconomyService.account(player)
	local room = if ignoreCapacity then whole else math.max(0, account.bagCapacity - account.carried)
	local added = math.min(whole, room)
	if added > 0 then
		account.carried += added
		record(account, "carried", added, reason)
	end
	return added
end

-- Removes carried cash (never below zero). Returns how much was removed.
function EconomyService.removeCarried(player: Player, amount: number, reason: string): number
	local account = EconomyService.account(player)
	local removed = math.min(math.floor(amount), account.carried)
	if removed > 0 then
		account.carried -= removed
		record(account, "carried", -removed, reason)
	end
	return removed
end

-- Moves carried cash from one player to another, limited by the receiver's bag space.
-- Returns the amount moved.
function EconomyService.transferCarried(from: Player, to: Player, amount: number, reason: string): number
	local source = EconomyService.account(from)
	local target = EconomyService.account(to)
	local room = math.max(0, target.bagCapacity - target.carried)
	local moved = math.min(math.floor(amount), source.carried, room)
	if moved <= 0 then
		return 0
	end
	source.carried -= moved
	record(source, "carried", -moved, `{reason} (to {to.UserId})`)
	target.carried += moved
	record(target, "carried", moved, `{reason} (from {from.UserId})`)
	return moved
end

local function resize(account: Account)
	account.bagCapacity = math.floor(account.bagBase * account.bagMultiplier * account.perkMultiplier + 0.5)
	EconomyService.changed:Fire(account.userId)
end

-- Bag upgrades change how much carried cash fits...
function EconomyService.setBagCapacity(player: Player, capacity: number)
	local account = EconomyService.account(player)
	account.bagBase = capacity
	resize(account)
end

-- ...and so does the Big Pockets upgrade...
function EconomyService.setPerkMultiplier(player: Player, multiplier: number)
	local account = EconomyService.account(player)
	account.perkMultiplier = multiplier
	resize(account)
end

-- ...and the Deep Pockets hustle.
function EconomyService.setBagMultiplier(player: Player, multiplier: number)
	local account = EconomyService.account(player)
	account.bagMultiplier = multiplier
	resize(account)
end

function EconomyService.setCarried(player: Player, amount: number, reason: string)
	local account = EconomyService.account(player)
	local delta = math.floor(amount) - account.carried
	account.carried += delta
	record(account, "carried", delta, reason)
end

-- Moves all carried cash into deposits. Returns the amount deposited.
function EconomyService.depositAll(player: Player, reason: string): number
	local account = EconomyService.account(player)
	local amount = account.carried
	if amount <= 0 then
		return 0
	end
	account.carried = 0
	account.deposited += amount
	teamDeposited += amount
	record(account, "deposit", amount, reason)
	return amount
end

function EconomyService.getLog(): { Entry }
	return table.clone(log)
end

return EconomyService
