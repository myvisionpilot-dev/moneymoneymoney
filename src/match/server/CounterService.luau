--!strict
-- Shop counters. Walk up and press E: the shopkeeper behind it (StaffService) says hello, and
-- you answer: buy something (opens the shop), rob the register (a crime from quota
-- Unlocks.StoreRobbery: stay put while it empties, StoreRobbery) or never mind. Counters are
-- map parts tagged ShopCounter, with Shop and Staff attributes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Notifier = require(script.Parent.Notifier)
local ShopService = require(script.Parent.ShopService)
local StaffService = require(script.Parent.StaffService)
local StoreRobbery = require(script.Parent.Paths.StoreRobbery)

local COUNTER_TAG = "ShopCounter"
local PROMPT_RANGE = 8
local RANGE_SLACK = 4

local BUY, ROB = 1, 2
local ROBBED_LINES = { "Whoa, okay! Take it, take it!", "Don't zap me! It's all yours!", "Okay, okay! Just stay calm!" }
local AFTER_LINES = { "I'm calling the cops!", "Somebody call the police!" }
local BYE_LINES = { "See you around!", "Come back any time!", "Have a good one!" }

type Chat = { id: number, counter: BasePart, shop: Types.ShopId, staff: string }

local remotes = Remotes.match()
local talkLimiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local answerLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)
local rng = Random.new()

local chats: { [Player]: Chat } = {}
local lastId = 0

local function pick(lines: { string }): string
	return lines[rng:NextInteger(1, #lines)]
end

-- Says a line to the player (with answers, or a progress bar, or neither).
local function say(
	player: Player,
	counter: BasePart,
	staff: string,
	line: string,
	options: { Types.TalkOption },
	progress: { label: string, endsAt: number }?
): number
	lastId += 1
	local name = StaffService.info(staff)
	remotes.Talk:fireClient(player, {
		id = lastId,
		name = name or "Shopkeeper",
		line = line,
		speakerAt = StaffService.headAt(staff) or (counter.Position + Vector3.new(0, 5, 0)),
		options = options,
		progress = progress,
	})
	return lastId
end

local function greet(player: Player, counter: BasePart)
	local shop = ShopService.shopOf(counter)
	local staff = counter:GetAttribute("Staff")
	if shop == nil or typeof(staff) ~= "string" or not ShopService.canShop(player) then
		return
	end
	if StoreRobbery.isRobbing(player) then
		return
	end
	local _, greetings = StaffService.info(staff)
	local locked = StoreRobbery.status(counter)
	local heat = Config.Heat.StoreRobbery
	local options: { Types.TalkOption } = {
		{ text = "Buy something" },
		{
			text = "Rob the register",
			detail = locked or `{Format.money(StoreRobbery.payFor(player))} · +{heat} heat`,
			heat = true,
			locked = locked ~= nil,
		},
		{ text = "Never mind" },
	}
	local line = if greetings then pick(greetings) else "Hi there!"
	local id = say(player, counter, staff, line, options)
	chats[player] = { id = id, counter = counter, shop = shop :: any, staff = staff }
end

local function rob(player: Player, chat: Chat)
	local endsAt, message = StoreRobbery.begin(player, chat.counter, function(ok: boolean, why: string?)
		StaffService.handsUp(chat.staff, false)
		if ok then
			say(player, chat.counter, chat.staff, pick(AFTER_LINES), {})
		else
			remotes.Talk:fireClient(player, nil)
			if why then
				Notifier.send(player, why, "Bad")
			end
		end
	end)
	if not endsAt then
		if message then
			Notifier.send(player, message, "Info")
		end
		return
	end
	StaffService.handsUp(chat.staff, true)
	say(player, chat.counter, chat.staff, pick(ROBBED_LINES), {}, { label = "Emptying the register", endsAt = endsAt })
end

local function onAnswer(player: Player, payload: unknown)
	if not answerLimiter:allow(player) or typeof(payload) ~= "table" then
		return
	end
	local answer = payload :: { [any]: unknown }
	local id, choice = answer.id, answer.choice
	local chat = chats[player]
	if not chat or typeof(id) ~= "number" or typeof(choice) ~= "number" or id ~= chat.id then
		return
	end
	chats[player] = nil
	if CharacterUtil.distanceTo(player, chat.counter.Position) > PROMPT_RANGE + RANGE_SLACK then
		return
	end
	if choice == BUY then
		ShopService.open(player, chat.shop)
	elseif choice == ROB then
		rob(player, chat)
	else
		say(player, chat.counter, chat.staff, pick(BYE_LINES), {})
	end
end

local function setupCounter(instance: Instance)
	local shop = ShopService.shopOf(instance)
	if shop == nil or not instance:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = ShopService.title(shop :: any)
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if talkLimiter:allow(player) then
			greet(player, instance)
		end
	end)
	prompt.Parent = instance
end

local CounterService = {}

function CounterService.start()
	for _, instance in CollectionService:GetTagged(COUNTER_TAG) do
		setupCounter(instance)
	end
	CollectionService:GetInstanceAddedSignal(COUNTER_TAG):Connect(setupCounter)
	remotes.TalkAnswer:onServer(onAnswer)
	Players.PlayerRemoving:Connect(function(player: Player)
		chats[player] = nil
	end)
end

return CounterService
