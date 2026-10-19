--!strict
-- The jail cell's lock: instead of just waiting, pick it. A ring spins clockwise with a green
-- arc on it; press when the green covers the arrow at the top to set a pin. Set every pin
-- (Config.Police.Lockpick) and the cell opens; a miss drops you back to the first pin. The
-- server makes the pins and checks every press (the client says how far into the spin it
-- pressed, and can't claim more time than has passed). Waiting it out still works: JailService
-- lets you go at your release time either way. The Bail Money pass leaves only the first
-- Store.BailPins pins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Passes = require(ServerScriptService.Common.Passes)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)

local settings = Config.Police.Lockpick
local remotes = Remotes.match()
local pressLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

type Lock = {
	pins: { Types.LockPin },
	pin: number,
	spinsFrom: number, -- os.clock() when this pin's spin starts
	onOpen: () -> (),
}

local JailLock = {}

local locks: { [Player]: Lock } = {}

-- Is the arrow (at 0 degrees, the top) inside the green arc t seconds into the spin?
local function covers(pin: Types.LockPin, t: number): boolean
	local arcStart = (pin.start + pin.speed * t) % 360
	local fromStart = (360 - arcStart) % 360 -- how far clockwise from the arc's start the arrow is
	local tolerance = settings.ToleranceDegrees
	return fromStart <= pin.width + tolerance or fromStart >= 360 - tolerance
end

local function send(player: Player, lock: Lock)
	remotes.LockpickGame:fireClient(player, {
		pins = lock.pins,
		pin = lock.pin,
		pauseSeconds = settings.PauseSeconds,
	})
end

-- A fresh lock on their cell; `onOpen` runs if they pick it.
function JailLock.give(player: Player, onOpen: () -> ())
	local pins: { Types.LockPin } = {}
	local count = if Passes.has(player, "BailMoney") then Config.Store.BailPins else #settings.Pins
	for index = 1, math.min(count, #settings.Pins) do
		local spec = settings.Pins[index]
		table.insert(pins, { start = rng:NextNumber(0, 360), width = spec.width, speed = spec.speed })
	end
	local lock: Lock = { pins = pins, pin = 1, spinsFrom = os.clock() + settings.PauseSeconds, onOpen = onOpen }
	locks[player] = lock
	send(player, lock)
end

-- They're out (or gone): put the lock away.
function JailLock.take(player: Player)
	if locks[player] then
		locks[player] = nil
		if player.Parent then
			remotes.LockpickGame:fireClient(player, nil)
		end
	end
end

local function onPress(player: Player, payload: unknown)
	local lock = locks[player]
	if not lock or not pressLimiter:allow(player) or typeof(payload) ~= "table" then
		return
	end
	local press = payload :: { [any]: unknown }
	local pinIndex, t = press.pin, press.t
	if typeof(pinIndex) ~= "number" or typeof(t) ~= "number" or t ~= t or pinIndex ~= lock.pin then
		return -- a press from before a reset: ignore it
	end
	local now = os.clock()
	local hit = t >= 0 and t <= now - lock.spinsFrom + settings.LatencySlack and covers(lock.pins[lock.pin], t)
	lock.spinsFrom = now + settings.PauseSeconds
	if not hit then
		lock.pin = 1
		send(player, lock)
		return
	end
	if lock.pin >= #lock.pins then
		locks[player] = nil
		remotes.LockpickGame:fireClient(player, nil)
		lock.onOpen()
		return
	end
	lock.pin += 1
	send(player, lock)
end

function JailLock.start()
	remotes.LockpickPress:onServer(onPress)
	Players.PlayerRemoving:Connect(function(player: Player)
		locks[player] = nil
	end)
end

return JailLock
