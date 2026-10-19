--!strict
-- A bag of money that falls out of the sky onto a spot, glowing, and waits to be grabbed (the
-- cash drop, the bank error). The first player in the run to hold E on it gets `onGrab`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local JailService = require(script.Parent.Parent.JailService)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local RosterService = require(script.Parent.Parent.RosterService)

local BAG_GREEN = Color3.fromRGB(70, 160, 80)
local BAND_GOLD = Color3.fromRGB(255, 205, 60)
local FALL_FROM = 80

export type Bag = { at: Vector3, gone: boolean, model: Model }

local CashBag = {}

local function build(ground: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CashBag"
	local sack = JobKit.prop(model, "Sack", Vector3.new(3, 3, 3), CFrame.new(ground), BAG_GREEN, Enum.Material.Fabric)
	sack.Shape = Enum.PartType.Ball
	JobKit.prop(model, "Band", Vector3.new(1.6, 0.5, 1.6), CFrame.new(ground + Vector3.new(0, 1.5, 0)), BAND_GOLD)
	local light = Instance.new("PointLight")
	light.Color = BAND_GOLD
	light.Range = 14
	light.Parent = sack
	model.PrimaryPart = sack
	model.Parent = workspace
	return model, sack
end

-- Drops a bag onto `ground` (where its middle ends up) over `fallSeconds`; `range` is how close
-- you must be to grab it.
function CashBag.drop(ground: Vector3, fallSeconds: number, range: number, onGrab: (player: Player) -> ()): Bag
	local model, sack = build(ground + Vector3.new(0, FALL_FROM, 0))
	local bag: Bag = { at = ground, gone = false, model = model }
	task.spawn(function()
		local value = Instance.new("CFrameValue")
		value.Value = model:GetPivot()
		value.Changed:Connect(function(cframe: CFrame)
			if model.Parent then
				model:PivotTo(cframe)
			end
		end)
		local fall = TweenService:Create(
			value,
			TweenInfo.new(fallSeconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ Value = CFrame.new(ground) }
		)
		fall:Play()
		fall.Completed:Wait()
		value:Destroy()
		if bag.gone then
			return
		end
		JobKit.prompt(
			sack,
			{ action = "Grab the cash", object = "Bag of cash", range = range },
			function(player: Player)
				if bag.gone or not RosterService.isActive(player) or JailService.isJailed(player) then
					return
				end
				Sounds.at("CoinPour", sack)
				CashBag.remove(bag)
				onGrab(player)
			end
		)
	end)
	return bag
end

function CashBag.remove(bag: Bag)
	if not bag.gone then
		bag.gone = true
		-- Let the grab sound finish first.
		task.delay(0.05, function()
			bag.model:Destroy()
		end)
	end
end

return CashBag
