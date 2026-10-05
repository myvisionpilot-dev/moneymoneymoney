--!strict
-- Dresses up moments the server tells us about: a money line at the bottom of the screen for
-- every bit of cash in or out ("+$1,500 | Package dropped off", "-$800 | Energy Drink purchased")
-- with its sound and a bounce of the bag or quota bar, and any sound the server asks for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)
local MoneyFeed = require(script.Parent.MoneyFeed)

local JuiceController = {}

function JuiceController.start()
	Remotes.match().Juice:onClient(function(event: Types.JuiceEvent)
		local amount = event.amount or 0
		local label = event.label or ""
		if event.kind == "Paid" then
			Sounds.play("Paid", 1 + math.min(amount / 20_000, 0.3))
			MoneyFeed.show(`+{Format.money(amount)}`, UI.Colors.Money, label)
			HudController.popBag()
		elseif event.kind == "Spent" or event.kind == "Lost" then
			Sounds.play(if event.kind == "Spent" then "Purchase" else "Fail")
			MoneyFeed.show(`-{Format.money(amount)}`, UI.Colors.Danger, label)
			HudController.popBag()
		elseif event.kind == "Deposited" then
			Sounds.play("Deposit")
			MoneyFeed.show(`+{Format.money(amount)}`, UI.Colors.Gold, label)
			HudController.popQuota()
		elseif event.kind == "BagFull" then
			Sounds.play("Fail")
			MoneyFeed.show("BAG FULL", UI.Colors.Danger, `{Format.money(amount)} didn't fit`)
		elseif event.kind == "Sound" and event.sound then
			Sounds.play(event.sound)
		end
	end)
end

return JuiceController
