--!strict
-- Tony's cartoon stun blasters. Buying one puts a Blaster tool in your backpack for the rest of
-- the run. The client only says where it aimed (FireBlaster); the server checks the cooldown,
-- range and line of sight, then:
--   a cop freezes for a few seconds (and you gain a little heat); so does a repo man (no heat),
--   and event NPCs registered with BlasterService.addTarget (the rival crew) decide for themselves;
--   a teammate sits down seeing stars and drops part of their bag as a cash bundle that
--   anyone can grab (you gain heat, and grabbing someone else's cash counts as stealing).
-- Nobody gets hurt. No blasting in the bank (parts tagged SafeZone), and none to or from a car
-- (a police car's cop can still be frozen). A blaster in hand also
-- makes store hold-ups quicker and pay more (StoreRobbery asks BlasterService.drawn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BlasterLooks = require(ReplicatedStorage.Shared.BlasterLooks)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Particles = require(ReplicatedStorage.Shared.Particles)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local Style = require(ServerScriptService.Common.Style)
local EconomyService = require(script.Parent.EconomyService)
local HeatService = require(script.Parent.HeatService)
local JailService = require(script.Parent.JailService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)
local PoliceService = require(script.Parent.PoliceService)
local RepoService = require(script.Parent.RepoService)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local SafeZone = require(script.Parent.SafeZone)
local StealService = require(script.Parent.StealService)

local TOOL_NAME = "Blaster"
local STUN_ATTRIBUTE = "Stunned" -- on a stunned player's character; their client sits them down
local VEHICLE_ATTRIBUTE = "VehicleSpeed" -- VehicleService sets it on a character in any car
local AIM_SLACK = 6 -- studs past the aim point the shot may still travel
local COOLDOWN_TOLERANCE = 0.9 -- a little network jitter on the cooldown
local MEGA_SCALE = 1.15 -- a Mega Zapper in a custom blaster's look is a size up
local NAMES: { [Types.BlasterId]: string } = { Zapper = "Zapper", MegaZapper = "Mega Zapper" }

local settings = Config.Blasters
local remotes = Remotes.match()
local fireLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local BlasterService = {}

-- Something else blasters can hit (an event's NPCs), besides cops, repo men and players.
export type Target = {
	isTarget: (model: Model) -> boolean,
	hit: (model: Model, shooter: Player, stunSeconds: number) -> (),
}

local owned: { [Player]: Types.BlasterId } = {} -- bought from Tony
local loaned: { [Player]: boolean } = {} -- a Zapper lent for an event
local lastShot: { [Player]: number } = {}
local targets: { Target } = {}

-- The blaster they bought (not a loaner).
function BlasterService.owned(player: Player): Types.BlasterId?
	return owned[player]
end

local function heldId(player: Player): Types.BlasterId?
	local loaner: Types.BlasterId = "Zapper"
	return owned[player] or (if loaned[player] then loaner else nil)
end

-- True if they're holding their blaster right now.
function BlasterService.drawn(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	return heldId(player) ~= nil and tool ~= nil and tool:IsA("Tool")
end

function BlasterService.addTarget(target: Target)
	table.insert(targets, target)
end

-- The blaster in your hand, in its look (shared/BlasterLooks): Tony's own design, or the custom
-- blaster you wear from the lobby, its glow in your zap colour. An invisible handle in the
-- middle of the body, every piece welded to it. Parts only, no scripts.
local function makeTool(id: Types.BlasterId, player: Player?): Tool
	local custom = if player then Style.worn(player, "Blaster") else nil
	local zap = if player then Style.worn(player, "Zap") else nil
	local design = if custom and custom.model then custom.model else id
	local scale = if custom and id == "MegaZapper" then MEGA_SCALE else 1
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = NAMES[id]
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.3 * scale, 0.4 * scale)
	tool:SetAttribute("Cooldown", settings[id].cooldown) -- so the client doesn't fire faster than we'd accept
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.one * 0.4
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	local pieces: { BlasterLooks.Piece } = BlasterLooks.pieces(design) or BlasterLooks.pieces(id) or {}
	for _, piece in pieces do
		local part = Instance.new("Part")
		part.Name = if piece.role == "glow" then "Glow" else "Piece"
		part.Shape = piece.shape or Enum.PartType.Block
		part.Size = piece.size * scale
		part.Color = if piece.role == "glow" and zap then zap.color else piece.color
		part.Material = piece.material or Enum.Material.SmoothPlastic
		part.Reflectance = piece.reflectance or 0
		part.Transparency = piece.transparency or 0
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.CFrame = handle.CFrame * CFrame.new(piece.at.Position * scale) * piece.at.Rotation
		if piece.role == "glow" and zap and zap.rainbow then
			part:AddTag("RainbowGlow")
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
	end
	-- The rarest custom blasters crackle in your hand.
	local glow = tool:FindFirstChild("Glow")
	if custom and glow and (custom.tier == "Epic" or custom.tier == "Legendary") then
		local zapColor = if zap then zap.color else custom.color
		Particles.keep(glow, if custom.tier == "Legendary" then "Sparkles" else "Sparks", 6, zapColor, 0.25)
	end
	return tool
end

-- Which look a player's shots come out in (their custom blaster, or Tony's design).
local function designOf(player: Player, id: string): string
	local custom = Style.worn(player, "Blaster")
	return if custom and custom.model then custom.model else id
end

-- Where the beam leaves their blaster: just in front of the one in their hand.
local function muzzleOf(character: Model): Vector3?
	local tool = character:FindFirstChild(TOOL_NAME)
	local handle = tool and tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return (handle.CFrame * CFrame.new(0, 0.1, -1.5)).Position
	end
	return nil
end

-- A blaster for an NPC to hold (no scripts; it does nothing on its own).
function BlasterService.prop(id: Types.BlasterId): Tool
	return makeTool(id)
end

local function removeTool(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		local old = container and container:FindFirstChild(TOOL_NAME)
		if old then
			old:Destroy()
		end
	end
end

-- Puts their blaster in their backpack (again after a respawn).
local function give(player: Player)
	local id: Types.BlasterId? = heldId(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not id or not backpack then
		return
	end
	removeTool(player)
	makeTool(id, player).Parent = backpack
end

-- ShopService takes the payment, then calls this.
function BlasterService.give(player: Player, id: Types.BlasterId)
	owned[player] = id
	loaned[player] = nil
	give(player)
end

-- Lends a Zapper for an event (if they haven't bought a blaster). True if they got one.
function BlasterService.lend(player: Player): boolean
	if owned[player] or loaned[player] then
		return false
	end
	loaned[player] = true
	give(player)
	return true
end

function BlasterService.takeBack(player: Player)
	if loaned[player] then
		loaned[player] = nil
		removeTool(player)
	end
end

-- A blaster shot someone else fired (an NPC), on everyone's screen, in a design's style.
function BlasterService.effect(from: Vector3, to: Vector3, design: string?, color: Color3?)
	remotes.BlasterFx:fireAll({ from = from, to = to, hit = nil, stunSeconds = 0, design = design, color = color })
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
	text.Text = Format.money(amount)
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
			Juice.paid(player, added, "Got your cash back")
		else
			StealService.record(player, added)
			Juice.paid(player, added, `Grabbed {victim.DisplayName}'s cash`)
			Notifier.send(victim, `{player.DisplayName} grabbed your cash!`, "Bad")
		end
	end)
	task.delay(settings.BundleSeconds, function()
		if not claimed then
			claimed = true
			bundle:Destroy()
			if victim.Parent then
				EconomyService.addCarried(victim, amount, "dropped cash came back", true)
				Juice.paid(victim, amount, "Dropped cash came back")
			end
		end
	end)
end

local function extraTarget(model: Model): Target?
	for _, target in targets do
		if target.isTarget(model) then
			return target
		end
	end
	return nil
end

-- The cop, repo man, event NPC or player a hit part belongs to. Cars sit inside their driver's
-- model, so look past them.
local function targetOf(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if
			PoliceService.isCop(model)
			or RepoService.isRepo(model)
			or extraTarget(model)
			or Players:GetPlayerFromCharacter(model)
		then
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

-- Sits them down seeing stars (a zap from a teammate, or knocked out by the rival crew).
function BlasterService.stunPlayer(victim: Player)
	local character = victim.Character
	if character then
		stunPlayer(victim, character)
	end
end

-- Blasting a teammate: they sit down and drop part of their bag.
local function blastPlayer(shooter: Player, victim: Player, character: Model): boolean
	if victim == shooter or not RosterService.isActive(victim) or JailService.isJailed(victim) then
		return false
	end
	if character:GetAttribute(STUN_ATTRIBUTE) or character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil then
		return false -- already down, or safe in a car (knocking a driver over would wreck it)
	end
	if SafeZone.contains(character:GetPivot().Position) then
		return false
	end
	stunPlayer(victim, character)
	HeatService.add(shooter, Config.Heat.BlastPlayer)
	local amount = math.floor(EconomyService.account(victim).carried * settings.DropPercent)
	if amount > 0 then
		local taken = EconomyService.removeCarried(victim, amount, `blasted by {shooter.Name}`)
		dropBundle(victim, taken, character:GetPivot().Position - Vector3.new(0, 3, 0))
		Juice.lost(victim, taken, "Dropped when zapped")
	end
	Notifier.send(victim, `{shooter.DisplayName} zapped you! Grab your cash back!`, "Bad")
	Notifier.send(shooter, `Zapped {victim.DisplayName}!`, "Good")
	return true
end

-- Their Cred shop zap colour (a rainbow zap picks a fresh colour every shot); nil is the
-- normal cyan.
local function zapColor(player: Player): Color3?
	local zap = Style.worn(player, "Zap")
	if not zap then
		return nil
	end
	return if zap.rainbow then Color3.fromHSV(math.random(), 0.8, 1) else zap.color
end

local function onFire(player: Player, payload: unknown)
	if not fireLimiter:allow(player) or typeof(payload) ~= "Vector3" then
		return
	end
	local id = heldId(player)
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
	if SafeZone.contains(origin) then
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
	elseif target and RepoService.isRepo(target) then
		RepoService.stun(target, model.copStunSeconds)
		hit, stunSeconds = target, model.copStunSeconds
	elseif target and extraTarget(target) then
		local extra = extraTarget(target) :: Target
		extra.hit(target, player, model.copStunSeconds)
		hit, stunSeconds = target, model.copStunSeconds
	elseif target then
		local victim = Players:GetPlayerFromCharacter(target)
		if victim and blastPlayer(player, victim, target) then
			hit, stunSeconds = target, settings.PlayerStunSeconds
		end
	end
	remotes.BlasterFx:fireAll({
		from = origin,
		to = stopAt,
		hit = hit,
		stunSeconds = stunSeconds,
		color = zapColor(player),
		design = designOf(player, id),
		muzzle = muzzleOf(character),
	})
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
		owned[player], loaned[player], lastShot[player] = nil, nil, nil
	end)
end

return BlasterService
