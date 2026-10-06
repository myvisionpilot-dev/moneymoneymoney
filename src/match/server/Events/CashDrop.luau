--!strict
-- Cash drop: a bag of money falls onto a random footpath spot (a pedestrian waypoint). The
-- first player to grab it keeps it (Events.CashDrop.Pay, scaled by quota; a legal job for hustles).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local JailService = require(script.Parent.Parent.JailService)
local JobKit = require(script.Parent.Parent.Paths.JobKit)
local Notifier = require(script.Parent.Parent.Notifier)
local PayNotice = require(script.Parent.Parent.PayNotice)
local RosterService = require(script.Parent.Parent.RosterService)
local TownEvent = require(script.Parent.TownEvent)

local SPOT_TAG = "PedWaypoint"
local BAG_GREEN = Color3.fromRGB(70, 160, 80)
local BAND_GOLD = Color3.fromRGB(255, 205, 60)

local settings = Config.Events.CashDrop

local bag: Model? = nil

local CashDrop = {
	id = "CashDrop",
	title = "CASH DROP",
	seconds = settings.Seconds,
}

function CashDrop.canStart(): boolean
	return #CollectionService:GetTagged(SPOT_TAG) > 0
end

local function buildBag(ground: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CashDrop"
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

function CashDrop.start(ctx: TownEvent.Context)
	local spots = JobKit.tagged(SPOT_TAG)
	local spot = spots[Random.new():NextInteger(1, #spots)]
	local ground = JobKit.ground(spot).Position + Vector3.new(0, 1.5, 0)
	local model, sack = buildBag(ground + Vector3.new(0, 80, 0))
	bag = model
	ctx.announce("A bag of cash just fell on the town. First to grab it keeps it!", ground)

	-- It falls from the sky, then anyone can grab it.
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe: CFrame)
		if model.Parent then
			model:PivotTo(cframe)
		end
	end)
	local fall = TweenService:Create(
		value,
		TweenInfo.new(settings.FallSeconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = CFrame.new(ground) }
	)
	fall:Play()
	fall.Completed:Wait()
	value:Destroy()
	if bag ~= model then
		return -- the event already ended
	end
	JobKit.prompt(sack, {
		action = "Grab the cash",
		object = "Cash drop",
		range = settings.RangeStuds,
	}, function(player: Player)
		if bag ~= model or not RosterService.isActive(player) or JailService.isJailed(player) then
			return
		end
		bag = nil
		model:Destroy()
		local pay = math.floor(settings.Pay * ctx.tierMultiplier + 0.5)
		PayNotice.earn(player, pay, "Cash drop grabbed", "cash drop", true)
		Notifier.others(player, `{player.DisplayName} grabbed the cash drop!`, "Info")
		ctx.finish()
	end)
end

function CashDrop.tick() end

function CashDrop.stop()
	if bag then
		bag:Destroy()
		bag = nil
	end
end

return CashDrop
