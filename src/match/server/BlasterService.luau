--!strict
-- Tony's cartoon stun blasters. Buying one puts a Blaster tool in your backpack for the rest of
-- the run. The client only says where it aimed (FireBlaster); the server checks the cooldown,
-- range and line of sight, then:
--   a cop freezes for a few seconds (and you gain a little heat);
--   a teammate sits down seeing stars and drops part of their bag as a cash bundle that
--   anyone can grab (you gain heat, and grabbing someone else's cash counts as stealing).
-- Nobody gets hurt. No blasting in the bank (parts tagged SafeZone), and none to or from a car
-- (a police car's cop can still be frozen). A blaster in hand also
-- makes store hold-ups quicker and pay more (StoreRobbery asks BlasterService.drawn).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local PoliceService = require(script.Parent.PoliceService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local StealService = require(script.Parent.StealService)

local TOOL_NAME = "Blaster"
local SAFE_TAG = "SafeZone"
local STUN_ATTRIBUTE = "Stunned" -- on a stunned player's character; their client sits them down
local VEHICLE_ATTRIBUTE = "VehicleSpeed" -- VehicleService sets it on a character in any kart or car
local AIM_SLACK = 6 -- studs past the aim point the shot may still travel
local COOLDOWN_TOLERANCE = 0.9 -- a little network jitter on the cooldown
local BODY = Color3.fromRGB(60, 60, 75)
local GLOW: { [Types.BlasterId]: Color3 } = {
	Zapper = Color3.fromRGB(60, 220, 255),
	MegaZapper = Color3.fromRGB(255, 110, 220),
}
local NAMES: { [Types.BlasterId]: string } = { Zapper = "Zapper", MegaZapper = "Mega Zapper" }

local settings = Config.Blasters
local remotes = Remotes.match()
local fireLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local BlasterService = {}

local owned: { [Player]: Types.BlasterId } = {}
local lastShot: { [Player]: number } = {}

function BlasterService.owned(player: Player): Types.BlasterId?
	return owned[player]
end

-- True if they're holding their blaster right now.
function BlasterService.drawn(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	return owned[player] ~= nil and tool ~= nil and tool:IsA("Tool")
end

local function weldedPart(
	tool: Tool,
	handle: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	neon: boolean
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = tool
end

-- A chunky toy blaster: body, glowing barrel and grip. Parts only, no scripts.
local function makeTool(id: Types.BlasterId): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = NAMES[id]
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.3, 0.4)
	tool:SetAttribute("Cooldown", settings[id].cooldown) -- so the client doesn't fire faster than we'd accept
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.8, 2.2)
	handle.Color = BODY
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	weldedPart(tool, handle, "Barrel", Vector3.new(0.45, 0.45, 1), CFrame.new(0, 0.1, -1.5), GLOW[id], true)
	weldedPart(tool, handle, "Fin", Vector3.new(0.15, 0.5, 1.2), CFrame.new(0, 0.6, 0), GLOW[id], true)
	weldedPart(tool, handle, "Grip", Vector3.new(0.5, 1, 0.5), CFrame.new(0, -0.8, 0.5), BODY, false)
	return tool
end

-- Puts their blaster in their backpack (again after a respawn).
local function give(player: Player)
	local id: Types.BlasterId? = owned[player]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if id == nil or not backpack then
		return
	end
	local function removeOld(container: Instance?)
		local old = container and container:FindFirstChild(TOOL_NAME)
		if old then
			old:Destroy()
		end
	end
	removeOld(backpack)
	removeOld(player.Character)
	makeTool(id).Parent = backpack
end

-- ShopService takes the payment, then calls this.
function BlasterService.give(player: Player, id: Types.BlasterId)
	owned[player] = id
	give(player)
end

local function inSafeZone(position: Vector3): boolean
	for _, zone in CollectionService:GetTagged(SAFE_TAG) do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- The victim's dropped cash: first to touch it keeps it. Unclaimed, it goes back to them.
local function dropBundle(victim: Player, amount: number, ground: Vector3)
	local bundle = Instance.new("Part")
	bundle.Name = "CashBundle"
	bundle.Size = Vector3.new(2.4, 1, 1.6)
	bundle.Color = Color3.fromRGB(90, 210, 90)
	bundle.Material = Enum.Material.Neon
	bundle.Anchored = true
	bundle.CanCollide = false
	bundle.CanQuery = false
	bundle.CFrame = CFrame.new(ground + Vector3.new(0, 0.6, 0))
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(110, 30)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.MaxDistance = 80
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 255, 120)
	text.TextStrokeTransparency = 0.2
	text.Text = `💵 {Format.money(amount)}`
	text.Parent = label
	label.Parent = bundle
	bundle.Parent = workspace

	local droppedAt = os.clock()
	local claimed = false
	bundle.Touched:Connect(function(hit: BasePart)
		if claimed then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not RosterService.isActive(player) or JailService.isJailed(player) then
			return
		end
		if player == victim and os.clock() - droppedAt < settings.PlayerStunSeconds then
			return -- still seeing stars
		end
		if EconomyService.isFull(player) then
			return
		end
		claimed = true
		bundle:Destroy()
		local reason = if player == victim
			then "picked up their dropped cash"
			else `grabbed {victim.Name}'s dropped cash`
		local added = EconomyService.addCarried(player, amount, reason)
		if added < amount and victim.Parent then
			EconomyService.addCarried(victim, amount - added, "dropped cash that didn't fit", true)
		end
		if player == victim then
			Notifier.send(victim, "Phew, you got your cash back.", "Good")
		else
			StealService.record(player, added)
			Notifier.send(player, `You grabbed {Format.money(added)} of {victim.DisplayName}'s cash!`, "Good")
			Notifier.send(victim, `{player.DisplayName} grabbed your cash!`, "Bad")
		end
		Juice.paid(player, added)
	end)
	task.delay(settings.BundleSeconds, function()
		if not claimed then
			claimed = true
			bundle:Destroy()
			if victim.Parent then
				EconomyService.addCarried(victim, amount, "dropped cash came back", true)
				Notifier.send(victim, "Nobody grabbed your dropped cash, so it's back in your bag.", "Info")
			end
		end
	end)
end

-- The cop or player a hit part belongs to. Cars sit inside their driver's model, so look past them.
local function targetOf(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if PoliceService.isCop(model) or Players:GetPlayerFromCharacter(model) then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function stunPlayer(victim: Player, character: Model)
	character:SetAttribute(STUN_ATTRIBUTE, true)
	task.delay(settings.PlayerStunSeconds, function()
		if character.Parent then
			character:SetAttribute(STUN_ATTRIBUTE, nil)
		end
	end)
	Juice.sound(victim, "Stun")
end

-- Blasting a teammate: they sit down and drop part of their bag.
local function blastPlayer(shooter: Player, victim: Player, character: Model): boolean
	if victim == shooter or not RosterService.isActive(victim) or JailService.isJailed(victim) then
		return false
	end
	if character:GetAttribute(STUN_ATTRIBUTE) or character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil then
		return false -- already down, or safe in a car (knocking a driver over would wreck it)
	end
	if inSafeZone(character:GetPivot().Position) then
		return false
	end
	stunPlayer(victim, character)
	HeatService.add(shooter, Config.Heat.BlastPlayer)
	local amount = math.floor(EconomyService.account(victim).carried * settings.DropPercent)
	if amount > 0 then
		local taken = EconomyService.removeCarried(victim, amount, `blasted by {shooter.Name}`)
		dropBundle(victim, taken, character:GetPivot().Position - Vector3.new(0, 3, 0))
	end
	Notifier.send(victim, `{shooter.DisplayName} zapped you! Grab your cash back!`, "Bad")
	Notifier.send(shooter, `Zapped {victim.DisplayName}!`, "Good")
	return true
end

local function onFire(player: Player, payload: unknown)
	if not fireLimiter:allow(player) or typeof(payload) ~= "Vector3" then
		return
	end
	local id = owned[player]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not id or not character or not head or not head:IsA("BasePart") or not BlasterService.drawn(player) then
		return
	end
	if RunState.phase ~= "Quota" or not RosterService.isActive(player) or JailService.isJailed(player) then
		return
	end
	if character:GetAttribute(STUN_ATTRIBUTE) then
		return -- can't aim while seeing stars
	end
	if character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil then
		Notifier.send(player, "Hands on the wheel! Hop out to use your blaster.", "Info")
		return
	end
	local model = settings[id]
	local now = os.clock()
	local last = lastShot[player]
	if last and now - last < model.cooldown * COOLDOWN_TOLERANCE then
		return
	end
	local origin = head.Position
	if inSafeZone(origin) then
		Notifier.send(player, "No blasting in the bank!", "Info")
		return
	end
	local aim = payload - origin
	if aim.Magnitude < 1 then
		return
	end
	lastShot[player] = now

	local reach = math.min(aim.Magnitude + AIM_SLACK, model.range)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, aim.Unit * reach, params)
	local stopAt = if result then result.Position else origin + aim.Unit * reach

	local hit: Model? = nil
	local stunSeconds = 0
	local target = result and targetOf(result.Instance)
	if target and PoliceService.isCop(target) then
		PoliceService.stun(target, model.copStunSeconds)
		HeatService.add(player, Config.Heat.BlastCop)
		hit, stunSeconds = target, model.copStunSeconds
	elseif target then
		local victim = Players:GetPlayerFromCharacter(target)
		if victim and blastPlayer(player, victim, target) then
			hit, stunSeconds = target, settings.PlayerStunSeconds
		end
	end
	remotes.BlasterFx:fireAll({ from = origin, to = stopAt, hit = hit, stunSeconds = stunSeconds })
end

function BlasterService.start()
	remotes.FireBlaster:onServer(onFire)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(give, player) -- the backpack empties on respawn
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		owned[player] = nil
		lastShot[player] = nil
	end)
end

return BlasterService
