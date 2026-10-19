--!strict
-- Throwing what you hold: a parcel or a letter onto a porch, the ball for the dog. A job says
-- what you can throw right now (Throwing.set) and what happens where it lands. Your
-- character's ThrowKind, ThrowRange and ThrowTarget attributes tell client/ThrowController to
-- show the aim; it sends the Throw remote with the spot you picked. The server keeps the spot in
-- reach, finds the ground there, plays the throw and hands the landing spot to the job, which
-- flies the prop there with Throwing.fly (every client draws the flight).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Dogs = require(script.Parent.Dogs)
local Gestures = require(script.Parent.Gestures)

local COOLDOWN_SECONDS = 0.8
local RELEASE_SECONDS = 0.22 -- into the throw, the hand lets go
local TOO_HIGH = 4 -- a landing this far above the thrower's middle is a roof: it rolls off

export type Spec = {
	kind: string, -- "Package", "Letter", "Ball"
	range: number,
	target: Vector3?, -- what to aim at (a doormat), if anything
	onThrow: (landing: Vector3, from: CFrame) -> (),
}

export type Flight = {
	height: number?,
	spin: number?,
	flat: boolean?,
	hops: number?,
	hopping: boolean?,
	seconds: number?,
}

local Throwing = {}

local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local specs: { [Player]: Spec } = {}
local lastThrow: { [Player]: number } = {}
local lastToss = 0

local function show(player: Player, spec: Spec?)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("ThrowKind", if spec then spec.kind else nil)
	character:SetAttribute("ThrowRange", if spec then spec.range else nil)
	character:SetAttribute("ThrowTarget", if spec then spec.target else nil)
end

function Throwing.set(player: Player, spec: Spec)
	specs[player] = spec
	show(player, spec)
end

-- Stops them throwing (only `spec`, if given: a newer one stays).
function Throwing.clear(player: Player, spec: Spec?)
	if spec and specs[player] ~= spec then
		return
	end
	specs[player] = nil
	show(player, nil)
end

function Throwing.current(player: Player): Spec?
	return specs[player]
end

-- How long a throw this far stays in the air.
function Throwing.airTime(distance: number): number
	return math.clamp(0.35 + distance / 45, 0.45, 1.35)
end

-- Flies an anchored part (PropModels.loose) from `from` to `to`: every client draws it, and
-- the server puts it at `to` when it lands. Returns how long until it's there.
function Throwing.fly(part: BasePart, from: CFrame, to: CFrame, flight: Flight?): number
	local options: Flight = flight or {}
	local distance = (to.Position - from.Position).Magnitude
	local seconds = options.seconds or Throwing.airTime(distance)
	local hops = options.hops or 0
	local total = seconds + hops * 0.22
	part.Anchored = true
	part.CFrame = from
	lastToss += 1
	part:SetAttribute("TossId", lastToss)
	remotes.Toss:fireAll({
		id = lastToss,
		part = part,
		startedAt = Timing.now(),
		from = from,
		to = to,
		seconds = seconds,
		height = options.height or (2 + distance * 0.22),
		spin = options.spin,
		flat = options.flat,
		hops = hops,
		hopping = options.hopping,
	})
	task.delay(total, function()
		-- (Not if something's picked it up on the way: the dog caught the ball.)
		if part.Parent and part.Anchored then
			part.CFrame = to
		end
	end)
	return total
end

-- The ground where they aimed, kept within reach and off the rooftops.
local function landingFor(root: BasePart, aim: Vector3, range: number): Vector3
	local offset = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end
	local probeY = math.clamp(aim.Y, root.Position.Y - 15, root.Position.Y + 10) + 1
	for _, share in { 1, 0.75, 0.5 } do
		local spot = Vector3.new(root.Position.X + offset.X * share, probeY, root.Position.Z + offset.Z * share)
		local ground = Dogs.groundAt(spot, 1)
		if ground and ground.Y <= root.Position.Y + TOO_HIGH then
			return ground
		end
		probeY = root.Position.Y + 1
	end
	return root.Position - Vector3.new(0, 3, 0)
end

local function onThrow(player: Player, payload: unknown)
	if not limiter:allow(player) or typeof(payload) ~= "Vector3" then
		return
	end
	local aim = payload :: Vector3
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z or aim.Magnitude > 1e5 then
		return
	end
	local spec = specs[player]
	local root = CharacterUtil.getRoot(player)
	local character = player.Character
	local now = os.clock()
	if not spec or not root or not character or now - (lastThrow[player] or 0) < COOLDOWN_SECONDS then
		return
	end
	if character:GetAttribute("VehicleSpeed") or character:GetAttribute("Stunned") then
		return
	end
	lastThrow[player] = now
	local landing = landingFor(root, aim, spec.range)
	-- Face the throw, wind up, let go.
	Gestures.playFor(player, "Throw")
	task.delay(RELEASE_SECONDS, function()
		local still = CharacterUtil.getRoot(player)
		if specs[player] ~= spec or not still then
			return
		end
		local flat = Vector3.new(landing.X - still.Position.X, 0, landing.Z - still.Position.Z)
		local facing = if flat.Magnitude > 0.1 then flat.Unit else still.CFrame.LookVector
		local from = CFrame.lookAt(still.Position, still.Position + facing) * CFrame.new(0.9, 1.3, -1)
		spec.onThrow(landing, from)
	end)
end

function Throwing.start()
	remotes.Throw:onServer(onThrow)
	Players.PlayerRemoving:Connect(function(player: Player)
		specs[player] = nil
		lastThrow[player] = nil
	end)
end

return Throwing
