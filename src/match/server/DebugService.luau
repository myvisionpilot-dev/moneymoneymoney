--!strict
-- Debug chat commands for the owner (and anyone in a Studio test):
--   /cash <amount> [player]   give carried cash (ignores bag size)
--   /pay <amount>             get paid as if for a job (streak, XP, effects)
--   /zapfx [design]           a blaster shot's effects straight ahead of you (BlasterLooks ids)
--   /cred <amount>            add saved Cred to yourself (to test the lobby shop)
--   /skip                     pass the current quota now
--   /timer <seconds>          set time left in the current phase
--   /start                    start the run without waiting for arrivals
--   /heat <stars>             add heat to yourself (to test police)
--   /tp <x> <y> <z>           teleport yourself (goes through MovementGuard)
--   /drive [top speed]        a car right where you stand (default: race car speed)
--   /twist <id|none>          swap this quota's twist (ids in Config.Twists)
--   /hustle <id>              give yourself a hustle (ids in Config.Hustles)
--   /event <id>               start a town event now (CashDrop, HappyHour, FireSale, VipFare...)
-- In Studio, ServerStorage.DebugHook:Invoke("cash", "5000") runs the same commands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Admin = require(ServerScriptService.Common.Admin)
local Profiles = require(ServerScriptService.Common.Profiles)
local BlasterService = require(script.Parent.BlasterService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local HeatService = require(script.Parent.HeatService)
local HustleService = require(script.Parent.HustleService)
local MovementGuard = require(script.Parent.MovementGuard)
local Notifier = require(script.Parent.Notifier)
local PayNotice = require(script.Parent.PayNotice)
local QuotaRunService = require(script.Parent.QuotaRunService)
local RosterService = require(script.Parent.RosterService)
local TwistService = require(script.Parent.TwistService)
local VehicleService = require(script.Parent.VehicleService)

type Handler = (player: Player, args: { string }) -> string

local DebugService = {}

local function findPlayer(name: string): Player?
	local lowered = name:lower()
	for _, player in Players:GetPlayers() do
		if
			player.Name:lower():sub(1, #lowered) == lowered
			or player.DisplayName:lower():sub(1, #lowered) == lowered
		then
			return player
		end
	end
	return nil
end

local handlers: { [string]: Handler } = {
	cash = function(player: Player, args: { string }): string
		local amount = tonumber(args[1])
		if not amount or amount <= 0 then
			return "Usage: /cash <amount> [player]"
		end
		local target = player
		if args[2] then
			local found = findPlayer(args[2])
			if not found then
				return `No player named {args[2]}`
			end
			target = found
		end
		if not RosterService.isActive(target) then
			return `{target.DisplayName} isn't active in the run`
		end
		local added = EconomyService.addCarried(target, amount, `debug /cash by {player.Name}`, true)
		return `Gave {Format.money(added)} to {target.DisplayName}`
	end,

	pay = function(player: Player, args: { string }): string
		local amount = tonumber(args[1])
		if not amount or amount <= 0 then
			return "Usage: /pay <amount>"
		end
		if not RosterService.isActive(player) then
			return "You aren't active in the run"
		end
		local added = PayNotice.earn(player, amount, "Debug payout", `debug /pay by {player.Name}`, true)
		return `Paid {Format.money(added)} like a job`
	end,

	cred = function(player: Player, args: { string }): string
		local amount = tonumber(args[1])
		local data = Profiles.get(player)
		if not amount or amount <= 0 then
			return "Usage: /cred <amount>"
		elseif not data then
			return "Your save hasn't loaded yet"
		end
		Profiles.addCred(player, data, amount, `debug /cred by {player.Name}`)
		Profiles.markChanged(player)
		return `You now have {Format.cred(data.Cred)}`
	end,

	skip = function(_player: Player, _args: { string }): string
		return if QuotaRunService.skipQuota()
			then "Quota skipped (counts as passed)"
			else "/skip only works during a quota"
	end,

	timer = function(_player: Player, args: { string }): string
		local seconds = tonumber(args[1])
		if not seconds then
			return "Usage: /timer <seconds>"
		end
		return if QuotaRunService.setTimer(seconds)
			then `Timer set to {Format.clock(seconds)}`
			else "No timer is running right now"
	end,

	heat = function(player: Player, args: { string }): string
		local stars = tonumber(args[1])
		if not stars then
			return "Usage: /heat <stars>"
		end
		HeatService.add(player, stars)
		return `Heat is now {string.format("%.1f", HeatService.get(player))}`
	end,

	tp = function(player: Player, args: { string }): string
		local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		if not x or not y or not z then
			return "Usage: /tp <x> <y> <z>"
		end
		MovementGuard.teleport(player, CFrame.new(x, y, z))
		return `Teleported to {x}, {y}, {z}`
	end,

	drive = function(player: Player, args: { string }): string
		local speed = tonumber(args[1]) or Config.Paths.Racing.CarSpeed
		local color = Color3.fromRGB(225, 75, 65)
		return if VehicleService.mount(player, "Debug", speed, color)
			then `In a car (top speed {speed}). R gets out.`
			else "No room for a car here"
	end,

	start = function(_player: Player, _args: { string }): string
		return if QuotaRunService.forceStart() then "Starting the run" else "The run has already started"
	end,

	zapfx = function(player: Player, args: { string }): string
		local root = CharacterUtil.getRoot(player)
		if not root then
			return "No character"
		end
		local design = args[1] or "Zapper"
		local from = (root.CFrame * CFrame.new(1.2, 1, -2)).Position
		local to = (root.CFrame * CFrame.new(0, 0, -28)).Position
		BlasterService.effect(from, to, design, Color3.fromRGB(90, 230, 255))
		return `Fired a {design} shot ahead of you`
	end,

	event = function(_player: Player, args: { string }): string
		local id = args[1]
		if not id then
			return "Usage: /event <id> (CashDrop, HappyHour, FireSale, VipFare, ArmouredTruck, RivalCrew)"
		end
		return if EventService.force(id) then `Event: {id}` else "Unknown event, or no quota running"
	end,

	hustle = function(player: Player, args: { string }): string
		local id = args[1]
		if not id then
			return "Usage: /hustle <id> (ids in Config.Hustles)"
		end
		return if HustleService.grant(player, id) then `Hustle: {id}` else "Unknown or maxed hustle"
	end,

	twist = function(_player: Player, args: { string }): string
		local id = args[1]
		if id == nil or id == "none" then
			TwistService.force(nil)
			return "No twist this quota"
		end
		return if TwistService.force(id) then `Twist: {id}` else "Unknown twist (see Config.Twists)"
	end,
}

local function run(player: Player, name: string, args: { string }): string
	if not Admin.isAdmin(player) then
		return "You can't use debug commands."
	end
	local handler = handlers[name]
	if not handler then
		return `Unknown command /{name}`
	end
	local message = handler(player, args)
	print(`[Debug] {player.Name}: /{name} {table.concat(args, " ")} -> {message}`)
	return message
end

local function splitArgs(text: string): { string }
	local args = {}
	for word in text:gmatch("%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- the command itself
	return args
end

function DebugService.start()
	local folder = Instance.new("Folder")
	folder.Name = "DebugCommands"
	folder.Parent = TextChatService

	for name in handlers do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = `/{name}`
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				Notifier.send(player, run(player, name, splitArgs(text)), "Info")
			end
		end)
	end

	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "DebugHook"
		hook.OnInvoke = function(name: string, ...: string): string
			local player = Players:GetPlayers()[1]
			if not player then
				return "No players in the test"
			end
			return run(player, name, { ... })
		end
		hook.Parent = ServerStorage
	end
end

return DebugService
