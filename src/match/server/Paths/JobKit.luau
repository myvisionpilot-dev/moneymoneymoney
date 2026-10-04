--!strict
-- Small pieces the town's legal jobs share (Taxi, BurgerBarn, CarWash, CarFlip, FoodStand):
-- server-checked prompts, props, customers, the job guide, paying out and a steady tick.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.Parent.EconomyService)
local NpcService = require(script.Parent.Parent.NpcService)
local PayNotice = require(script.Parent.Parent.PayNotice)
local PromptGuard = require(script.Parent.Parent.PromptGuard)
local Stats = require(script.Parent.Parent.Stats)

local RANGE_SLACK = 3
local CUSTOMER_NAMES = {
	"Hungry Hank",
	"Picky Pat",
	"Late-Night Lou",
	"Teen Tess",
	"Trucker Ted",
	"Granny Gail",
	"Commuter Carl",
	"Birthday Bea",
	"Gym Bro Gus",
	"Tourist Tom",
	"Nurse Nina",
	"Uncle Ugo",
}

local remotes = Remotes.match()
local limiter = RateLimiter.new(Config.Security.PromptsPerSecond, 1)
local rng = Random.new()

local JobKit = {}

export type PromptOptions = {
	action: string,
	object: string,
	hold: number?,
	range: number?,
	owner: Player?, -- only this player sees it (PromptController) and can use it
}

-- Someone standing still for a job (a customer, a passenger), anchored. They turn up as soon as
-- Roblox has dressed them; dismissing them before that is fine.
export type Customer = {
	model: Model?,
	dismissed: boolean,
}

function JobKit.positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- A prompt the server checks: rate, hold time, range and (with an owner) who's using it.
function JobKit.prompt(
	parent: Instance,
	options: PromptOptions,
	onTriggered: (player: Player, prompt: ProximityPrompt) -> ()
): ProximityPrompt
	local range = options.range or 8
	local owner = options.owner
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JobPrompt"
	prompt.ActionText = options.action
	prompt.ObjectText = options.object
	prompt.HoldDuration = options.hold or 0
	prompt.MaxActivationDistance = range
	prompt.RequiresLineOfSight = false
	if owner then
		prompt:SetAttribute("OnlyFor", owner.UserId)
	end
	PromptGuard.watch(prompt)
	prompt.Triggered:Connect(function(player: Player)
		if (owner and player ~= owner) or not limiter:allow(player) or not PromptGuard.held(prompt, player) then
			return
		end
		local position = JobKit.positionOf(parent)
		if position and CharacterUtil.distanceTo(player, position) > range + RANGE_SLACK then
			return
		end
		onTriggered(player, prompt)
	end)
	prompt.Parent = parent
	return prompt
end

-- An anchored prop nobody bumps into (patties, trays, dirt, dents...).
function JobKit.prop(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function JobKit.tagged(tag: string): { BasePart }
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	return list
end

function JobKit.first(tag: string): BasePart?
	return JobKit.tagged(tag)[1]
end

-- Where a marker part stands on the ground, facing the way the part faces.
function JobKit.ground(marker: BasePart): CFrame
	return marker.CFrame * CFrame.new(0, -marker.Size.Y / 2, 0)
end

function JobKit.customer(ground: CFrame, name: string?): Customer
	local customer: Customer = { model = nil, dismissed = false }
	task.spawn(function()
		local model =
			NpcService.makeRig(name or CUSTOMER_NAMES[rng:NextInteger(1, #CUSTOMER_NAMES)], NpcService.randomLook())
		if customer.dismissed then
			model:Destroy()
			return
		end
		NpcService.place(model, ground * CFrame.new(0, 3, 0))
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		customer.model = model
	end)
	return customer
end

function JobKit.dismiss(customer: Customer?, afterSeconds: number?)
	if not customer then
		return
	end
	local function go()
		customer.dismissed = true
		if customer.model then
			customer.model:Destroy()
			customer.model = nil
		end
	end
	if afterSeconds then
		task.delay(afterSeconds, go)
	else
		go()
	end
end

function JobKit.guide(player: Player, title: string, markers: { Vector3 }, endsAt: number, pay: number)
	if player.Parent then
		remotes.JobGuide:fireClient(player, { title = title, markers = markers, endsAt = endsAt, pay = pay })
	end
end

function JobKit.clearGuide(player: Player)
	if player.Parent then
		remotes.JobGuide:fireClient(player, nil)
	end
end

-- Pays into the bag with the usual pop-up, and counts toward daily challenges.
function JobKit.pay(player: Player, amount: number, headline: string, reason: string, stat: string?): number
	local added = EconomyService.addCarried(player, amount, reason)
	PayNotice.send(player, headline, added, amount)
	if stat then
		Stats.record(player, stat)
	end
	return added
end

-- A base price at this quota (prices and pay scale together).
function JobKit.scaled(base: number, multiplier: number): number
	return math.floor(base * multiplier + 0.5)
end

-- How fast they're going (studs/s along the ground), in a car or on foot.
function JobKit.speed(player: Player): number
	local root = CharacterUtil.getRoot(player)
	if not root then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- Runs `step` every `seconds` (from Heartbeat).
function JobKit.every(seconds: number, step: () -> ())
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since >= seconds then
			since = 0
			step()
		end
	end)
end

return JobKit
