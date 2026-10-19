--!strict
-- The Lucky Wheel (built by WheelBuilder). Spins are free: one a day (UTC), plus the ones you
-- earned in runs (Profiles Spins.Free, added by the match's RewardService). Press Spin and the
-- server takes a spin, picks the slice by its odds (Config.Wheel) and writes the spin onto the
-- wheel's attributes (SpinFrom, SpinTo, SpinStart, SpinSeconds, SpinBy), so every client turns
-- it the same way. One spin at a time. The prize is saved straight away but only shown (Cred
-- counter, WheelResult) once the wheel stops. Your spins and when the next daily one comes are
-- on you as attributes (WheelSpins, WheelDailyAt) for the sign on the wheel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Wheel = require(ReplicatedStorage.Shared.Wheel)
local Daily = require(ServerScriptService.Common.Daily)
local Profiles = require(ServerScriptService.Common.Profiles)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local WheelBuilder = require(script.Parent.WheelBuilder)

local SECONDS_PER_DAY = 86_400

local settings = Config.Wheel
local remotes = Remotes.lobby()
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local rng = Random.new()

local WheelService = {}

local model: Model? = nil
local prompt: ProximityPrompt? = nil
local busy = false

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	remotes.Notify:fireClient(player, { text = text, kind = kind })
end

-- Spins they can use now, and whether one of them is today's free one.
local function available(data: Profiles.Data): (number, boolean)
	local daily = data.Spins.LastDaily < Daily.today()
	return data.Spins.Free + (if daily then 1 else 0), daily
end

local function publish(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local count = available(data)
	player:SetAttribute("WheelSpins", count)
	player:SetAttribute("WheelDailyAt", (Daily.today() + 1) * SECONDS_PER_DAY)
end

local function pick(): number
	local total = 0
	for _, slice in settings.Slices do
		total += slice.weight
	end
	local roll = rng:NextNumber() * total
	for index, slice in settings.Slices do
		roll -= slice.weight
		if roll < 0 then
			return index
		end
	end
	return 1
end

-- A cosmetic of this rarity they don't own yet (nil if they own them all).
local function unowned(data: Profiles.Data, tier: string): Cosmetics.Item?
	local choices: { Cosmetics.Item } = {}
	for _, item in Cosmetics.Items do
		if item.tier == tier and not data.Owned[item.id] then
			table.insert(choices, item)
		end
	end
	return if #choices > 0 then choices[rng:NextInteger(1, #choices)] else nil
end

-- Saves the prize now (so leaving mid-spin keeps it); returns what to show.
local function award(player: Player, data: Profiles.Data, index: number): Types.WheelResult
	local slice = settings.Slices[index]
	local result: Types.WheelResult = { slice = index, cred = 0, cosmetic = nil }
	if slice.cosmetic then
		local item = unowned(data, slice.cosmetic)
		if item then
			data.Owned[item.id] = true
			result.cosmetic = item.id
			print(`[Wheel] {player.Name} won {item.id}`)
			return result
		end
		result.cred = (Config.CredShop.Tiers :: { [string]: number })[slice.cosmetic] or 0
	else
		result.cred = slice.cred or 0
	end
	Profiles.addCred(player, data, result.cred, `lucky wheel slice {index}`)
	return result
end

local function spin(player: Player)
	local root, button = model, prompt
	local data = Profiles.get(player)
	if not root or not button or not data or not limiter:allow(player) then
		return
	end
	if busy then
		notify(player, "Wait for this spin!", "Info")
		return
	end
	local count, daily = available(data)
	if count <= 0 then
		notify(player, "No spins left. Clear quotas for more!", "Info")
		return
	end
	if daily then
		data.Spins.LastDaily = Daily.today()
	else
		data.Spins.Free -= 1
	end
	local index = pick()
	local result = award(player, data, index)
	Profiles.save(player)
	publish(player)

	busy = true
	button.Enabled = false
	local from = (root:GetAttribute("Angle") :: number?) or 0
	local turns = rng:NextInteger(settings.Turns[1], settings.Turns[2])
	local to = Wheel.stopAt(from, index, turns, rng:NextNumber(-1, 1))
	root:SetAttribute("SpinFrom", from)
	root:SetAttribute("SpinTo", to)
	root:SetAttribute("SpinSeconds", settings.SpinSeconds)
	root:SetAttribute("SpinBy", player.UserId)
	root:SetAttribute("SpinStart", workspace:GetServerTimeNow())
	print(`[Wheel] {player.Name} spun slice {index} ({Wheel.label(settings.Slices[index])})`)

	task.delay(settings.SpinSeconds, function()
		root:SetAttribute("Angle", to % 360)
		busy = false
		button.Enabled = true
		if player.Parent then
			Profiles.markChanged(player) -- the Cred counter catches up now
			remotes.WheelResult:fireClient(player, result)
		end
	end)
end

function WheelService.start()
	-- The wheel saved in the place (built in Studio with tools/build_wheel, and moved wherever you
	-- like); a place without one gets one built at Config.Wheel.Position.
	local placed = workspace:FindFirstChild("LuckyWheel")
	local root = if placed
			and placed:IsA("Model")
			and placed:FindFirstChild("Spinner")
			and placed:FindFirstChild("SpinSpot")
		then placed
		else WheelBuilder.build()
	root:SetAttribute("Angle", 0)
	model = root
	local spot = root:FindFirstChild("SpinSpot")
	local found = spot and spot:FindFirstChildOfClass("ProximityPrompt")
	if not found then
		warn("[Wheel] no Spin prompt")
		return
	end
	prompt = found
	found.Triggered:Connect(spin)
	Profiles.loaded:Connect(function(player: Player)
		publish(player)
		local data = Profiles.get(player)
		local count = if data then available(data) else 0
		if count > 0 then
			notify(player, `{count} free spin{if count == 1 then "" else "s"} on the Lucky Wheel!`, "Good")
		end
	end)
	-- The daily spin comes back at midnight UTC for anyone still here.
	task.spawn(function()
		local day = Daily.today()
		while true do
			task.wait(30)
			if Daily.today() ~= day then
				day = Daily.today()
				for _, player in Players:GetPlayers() do
					publish(player)
				end
			end
		end
	end)
end

return WheelService
