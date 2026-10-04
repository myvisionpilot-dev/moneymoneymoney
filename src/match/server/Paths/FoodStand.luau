--!strict
-- The hot-dog cart: from quota Unlocks.FoodStand, rent it at the Street Market for
-- FoodStand.Rent (from your bag) and push it around town, selling hot dogs to pedestrians for
-- Price each (hold E next to them). Each pedestrian buys at most once every BuyCooldownSeconds.
-- The shift ends when you sell out or after ShiftSeconds; unsold hot dogs aren't refunded.
-- While you push the cart (the PushingCart character attribute) you can't pickpocket or ride.
-- Map tag: FoodCartCounter (where you rent it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Carry = require(script.Parent.Parent.Carry)
local EconomyService = require(script.Parent.Parent.EconomyService)
local Juice = require(script.Parent.Parent.Juice)
local MoneyPath = require(script.Parent.MoneyPath)
local Notifier = require(script.Parent.Parent.Notifier)
local NpcService = require(script.Parent.Parent.NpcService)
local VehicleService = require(script.Parent.Parent.VehicleService)
local JobKit = require(script.Parent.JobKit)

local COUNTER_TAG = "FoodCartCounter"
local CART_ATTRIBUTE = "PushingCart"
local CHECK_SECONDS = 0.5
local PAUSE_SECONDS = 1.2 -- a customer stops this long to take their hot dog
local CART_OFFSET = CFrame.new(0, -1.4, -3.4) -- pushed low in front, like the mower

type Shift = {
	endsAt: number,
	stock: number,
	sold: number,
	cart: BasePart?,
	prompts: { [Model]: ProximityPrompt },
}

local settings = Config.Paths.FoodStand
local unlockQuota = Config.Paths.Unlocks.FoodStand

local shifts: { [Player]: Shift } = {}
local lastBought: { [Model]: number } = {} -- any seller: when each pedestrian last bought one
local context: MoneyPath.Context? = nil

local function getContext(): MoneyPath.Context
	local current = context
	if not current then
		error("FoodStand used before init")
	end
	return current
end

local function rent(): number
	return JobKit.scaled(settings.Rent, getContext().payMultiplier())
end

local function price(): number
	return JobKit.scaled(settings.Price, getContext().payMultiplier())
end

local function guide(player: Player, shift: Shift)
	JobKit.guide(player, `Hot dogs: {shift.stock} left`, {}, shift.endsAt, price())
end

local function endShift(player: Player, reason: string?, kind: ("Info" | "Good" | "Bad")?)
	local shift = shifts[player]
	if not shift then
		return
	end
	shifts[player] = nil
	for _, prompt in shift.prompts do
		prompt:Destroy()
	end
	if shift.cart then
		shift.cart:Destroy()
	end
	local character = player.Character
	if character then
		character:SetAttribute(CART_ATTRIBUTE, nil)
	end
	JobKit.clearGuide(player)
	if reason then
		Notifier.send(player, reason, kind or "Info")
	end
end

-- The customer stops for a moment to take it (unless they're busy dodging or being robbed).
local function pause(pedestrian: Model)
	local humanoid = pedestrian:FindFirstChildOfClass("Humanoid")
	local walk = Config.Paths.Pickpocket.WalkSpeed
	if not humanoid or humanoid.WalkSpeed ~= walk then
		return
	end
	humanoid.WalkSpeed = 0
	task.delay(PAUSE_SECONDS, function()
		if humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = walk
		end
	end)
end

local function sellTo(player: Player, pedestrian: Model)
	local shift = shifts[player]
	if not shift or shift.stock <= 0 then
		return
	end
	local last = lastBought[pedestrian]
	if last and os.clock() - last < settings.BuyCooldownSeconds then
		Notifier.send(player, `{pedestrian.Name} just had one. Try someone else!`, "Info")
		return
	end
	lastBought[pedestrian] = os.clock()
	shift.stock -= 1
	shift.sold += 1
	pause(pedestrian)
	JobKit.pay(player, price(), `{pedestrian.Name} bought a hot dog!`, "hot dog", "HotDog")
	if shift.stock <= 0 then
		endShift(player, `Sold out! {shift.sold} hot dogs sold.`, "Good")
	else
		guide(player, shift)
	end
end

local function addSellPrompt(player: Player, shift: Shift, pedestrian: Model)
	local root = pedestrian:FindFirstChild("HumanoidRootPart")
	if not root or shift.prompts[pedestrian] then
		return
	end
	shift.prompts[pedestrian] = JobKit.prompt(root, {
		action = "Sell hot dog",
		object = pedestrian.Name,
		hold = settings.SellHoldSeconds,
		range = settings.RangeStuds,
		owner = player,
	}, function()
		sellTo(player, pedestrian)
	end)
end

-- The cart: a stand on wheels with a striped umbrella, pushed in front of you.
local function attachCart(player: Player): BasePart?
	local cart = Carry.attach(
		player,
		"HotDogCart",
		Vector3.new(3, 2.2, 2.2),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic,
		CART_OFFSET
	)
	if not cart then
		return nil
	end
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape or Enum.PartType.Block
		part.Size = size
		part.Color = color
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = cart.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = cart
		weld.Part1 = part
		weld.Parent = part
		part.Parent = cart
	end
	piece("Stripe", Vector3.new(3.05, 0.5, 2.25), CFrame.new(0, 0.5, 0), Color3.fromRGB(220, 50, 50))
	piece("Pole", Vector3.new(0.2, 3.4, 0.2), CFrame.new(0, 2.8, 0), Color3.fromRGB(200, 200, 200))
	piece("Umbrella", Vector3.new(4.6, 0.3, 4.6), CFrame.new(0, 4.5, 0), Color3.fromRGB(255, 200, 40))
	for _, x in { -1.2, 1.2 } do
		piece(
			"CartWheel",
			Vector3.new(0.3, 1, 1),
			CFrame.new(x, -1.2, 0),
			Color3.fromRGB(30, 30, 32),
			Enum.PartType.Cylinder
		)
	end
	return cart
end

local function start(player: Player, _source: Instance?): (boolean, string?)
	local ctx = getContext()
	if not ctx.isOpen() then
		return false, `The hot-dog cart opens at quota {unlockQuota}.`
	end
	if not ctx.canWork(player) then
		return false, nil
	end
	if ctx.isBusy(player) then
		return false, "Finish your current job first."
	end
	if VehicleService.kind(player) then
		return false, "Get out of your vehicle first."
	end
	local cost = rent()
	if EconomyService.account(player).carried < cost then
		return false, `You need {Format.money(cost)} in your bag to rent the cart.`
	end
	local cart = attachCart(player)
	if not cart then
		return false, nil
	end
	EconomyService.removeCarried(player, cost, "rented the hot-dog cart")
	local shift: Shift = {
		endsAt = Timing.now() + settings.ShiftSeconds,
		stock = settings.Stock,
		sold = 0,
		cart = cart,
		prompts = {},
	}
	shifts[player] = shift
	local character = player.Character
	if character then
		character:SetAttribute(CART_ATTRIBUTE, true)
	end
	for _, pedestrian in NpcService.pedestrians() do
		addSellPrompt(player, shift, pedestrian)
	end
	Juice.sound(player, "Purchase")
	Notifier.send(
		player,
		`Cart rented for {Format.money(cost)}! Push it around and hold E next to people to sell hot dogs.`,
		"Info"
	)
	guide(player, shift)
	return true, nil
end

local function checkShifts()
	local now = Timing.now()
	for player, shift in shifts do
		local cart = shift.cart
		if not player.Parent then
			endShift(player)
		elseif not cart or not cart.Parent then
			endShift(player, "You lost the cart.", "Bad")
		elseif now > shift.endsAt then
			endShift(player, `Shift's over: {shift.sold} hot dogs sold.`, "Info")
		end
	end
end

local function init(newContext: MoneyPath.Context)
	context = newContext
	for _, counter in JobKit.tagged(COUNTER_TAG) do
		JobKit.prompt(counter, { action = "Rent hot-dog cart", object = "Street Market", hold = 0.3 }, function(player)
			local ok, message = start(player)
			if not ok and message then
				Notifier.send(player, message, "Info")
			end
		end)
	end
	NpcService.pedestrianAdded:Connect(function(pedestrian: Model)
		for player, shift in shifts do
			addSellPrompt(player, shift, pedestrian)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		endShift(player)
	end)
	JobKit.every(CHECK_SECONDS, checkShifts)
end

local FoodStand: MoneyPath.MoneyPath = {
	id = "FoodStand",
	displayName = "Hot-dog cart",
	unlockQuota = unlockQuota,
	legal = true,
	init = init,
	start = start,
	complete = function(_player: Player): (boolean, string?)
		return false, nil
	end,
	fail = function(player: Player, reason: string)
		endShift(player, reason, "Bad")
	end,
	payout = function(_player: Player, _tier: number): number
		return price()
	end,
	hasJob = function(player: Player): boolean
		return shifts[player] ~= nil
	end,
	cancelAll = function(reason: string)
		for player in shifts do
			endShift(player, reason, "Bad")
		end
	end,
}

return FoodStand
