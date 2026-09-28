--!strict
-- Dresses up moments the server tells us about: "+$1,500" pops up and floats away when you get
-- paid (coins sound, the bag bar bounces), a big gold "+$X DEPOSITED" at the bank (ka-ching),
-- and any sound the server asks for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local RISE = 70 -- pixels a pop-up floats up
local POP_SECONDS = 1.3

local JuiceController = {}

local rng = Random.new()

function JuiceController.start()
	local root = UI.root(UI.screen("Juice", 55))

	local function popUp(text: string, color: Color3, size: number, y: number)
		local label = UI.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, rng:NextInteger(-40, 40), y, 0),
			Size = UDim2.fromOffset(360, size + 10),
			Font = UI.Fonts.Heading,
			TextSize = size,
			TextColor3 = color,
			Text = text,
		}, root)
		UI.textStroke(label, 3)
		UI.pop(label, 0.4)
		UI.tween(label, POP_SECONDS, { Position = label.Position - UDim2.fromOffset(0, RISE), TextTransparency = 1 })
		local outline = label:FindFirstChild("TextOutline")
		if outline and outline:IsA("UIStroke") then
			UI.tween(outline, POP_SECONDS, { Transparency = 1 })
		end
		task.delay(POP_SECONDS, function()
			label:Destroy()
		end)
	end

	Remotes.match().Juice:onClient(function(event: Types.JuiceEvent)
		if event.kind == "Paid" then
			local amount = event.amount or 0
			Sounds.play("Paid", 1 + math.min(amount / 20_000, 0.3))
			popUp(`+{Format.money(amount)}`, UI.Colors.Money, 34, 0.55)
			HudController.popBag()
		elseif event.kind == "Deposited" then
			Sounds.play("Deposit")
			popUp(`+{Format.money(event.amount or 0)} DEPOSITED`, UI.Colors.Gold, 38, 0.45)
			HudController.popQuota()
		elseif event.kind == "Sound" and event.sound then
			Sounds.play(event.sound)
		end
	end)
end

return JuiceController
