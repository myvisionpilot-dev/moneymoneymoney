--!strict
-- Dresses up moments the server tells us about: a money line at the bottom of the screen for
-- every bit of cash in or out ("+$1,500 | Package dropped off", "-$800 | Energy Drink purchased")
-- with its sound, bills flying into your bag (CashFx) and a ka-ching that rings higher when
-- payouts come close together; deposits pouring into the quota; level-ups (LevelController);
-- and any sound the server asks for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local CashFx = require(script.Parent.CashFx)
local HudController = require(script.Parent.HudController)
local LevelController = require(script.Parent.LevelController)
local MoneyFeed = require(script.Parent.MoneyFeed)

local settings = Config.Fx

local JuiceController = {}

local lastPaid = 0
local climb = 0 -- how much higher the next ka-ching rings

function JuiceController.start()
	Remotes.match().Juice:onClient(function(event: Types.JuiceEvent)
		local amount = event.amount or 0
		local label = event.label or ""
		if event.kind == "Paid" then
			local now = os.clock()
			climb = if now - lastPaid <= settings.PitchSeconds
				then math.min(climb + settings.PitchStep, settings.PitchMax)
				else 0
			lastPaid = now
			Sounds.play("Paid", 1 + climb + math.min(amount / 40_000, 0.15))
			MoneyFeed.show(`+{Format.money(amount)}`, UI.Colors.Money, label, {
				big = amount >= settings.BigPayout,
				streak = event.streak,
			})
			CashFx.payout(amount, 1 + climb)
		elseif event.kind == "Spent" or event.kind == "Lost" then
			Sounds.play(if event.kind == "Spent" then "Purchase" else "Fail")
			MoneyFeed.show(`-{Format.money(amount)}`, UI.Colors.Danger, label)
			HudController.popBag()
		elseif event.kind == "Deposited" then
			Sounds.play("Deposit")
			MoneyFeed.show(`+{Format.money(amount)}`, UI.Colors.Gold, label, { big = amount >= settings.BigPayout })
			CashFx.deposit(amount)
		elseif event.kind == "BagFull" then
			Sounds.play("Fail")
			MoneyFeed.show("BAG FULL", UI.Colors.Danger, `{Format.money(amount)} didn't fit`)
			HudController.popBag()
		elseif event.kind == "LevelUp" and event.level then
			LevelController.levelUp(event.level, amount)
		elseif event.kind == "Sound" and event.sound then
			Sounds.play(event.sound)
		end
	end)
end

return JuiceController
