--!strict
-- Shoving an NPC off you (the rival crew, repo men): a Shove prompt on them. You push with both
-- hands (Gestures "Shove"), they fly back onto the ground seeing stars and get up a moment
-- later. Strength (bought in the Shop) makes it hit harder. Not from a car, not while you're
-- down yourself, not in the bank. Config.Shove.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Strength = require(ReplicatedStorage.Shared.Strength)
local Types = require(ReplicatedStorage.Shared.Types)
local Gestures = require(script.Parent.Gestures)
local JailService = require(script.Parent.JailService)
local RosterService = require(script.Parent.RosterService)
local SafeZone = require(script.Parent.SafeZone)
local Stun = require(script.Parent.Stun)

local VEHICLE_ATTRIBUTE = "VehicleSpeed" -- in a car
local RANGE_SLACK = 4

local settings = Config.Shove
local remotes = Remotes.match()

local Shove = {}

local lastShove: { [Player]: number } = {}
local downs = 0

-- Free to shove (or be swiped at): in the run, out of jail, on foot and on their feet.
function Shove.canFight(player: Player): boolean
	local character = player.Character
	return RosterService.isActive(player)
		and not JailService.isJailed(player)
		and character ~= nil
		and CharacterUtil.getRoot(player) ~= nil
		and character:GetAttribute(VEHICLE_ATTRIBUTE) == nil
		and not Stun.isStunned(character)
end

-- A Shove prompt on `root`: `onShove` runs for each shove that passes the checks.
function Shove.prompt(root: BasePart, onShove: (player: Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShovePrompt"
	prompt.ActionText = "Shove"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = settings.Studs
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		local from = CharacterUtil.getRoot(player)
		if now - (lastShove[player] or 0) < settings.CooldownSeconds or not Shove.canFight(player) or not from then
			return
		end
		if
			SafeZone.contains(from.Position)
			or (from.Position - root.Position).Magnitude > settings.Studs + RANGE_SLACK
		then
			return
		end
		lastShove[player] = now
		Gestures.playFor(player, "Shove")
		onShove(player)
	end)
	prompt.Parent = root
	return prompt
end

-- How hard this player shoves: their Strength's tier (1 = ordinary) and how far it sends people.
function Shove.power(player: Player): (number, number)
	local points = Strength.of(player)
	local tier = Strength.tier(points)
	return tier, Strength.push(points)
end

-- `by` shoved them: they fly back onto the ground (further, and for longer, the stronger the
-- shove) seeing stars, with `fx` where they were hit, then get up after `seconds` unless
-- `stayDown`.
function Shove.knockDown(model: Model, by: Player, seconds: number, fx: Types.JobFxKind, stayDown: boolean?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local shover = CharacterUtil.getRoot(by)
	if not humanoid or not root or not root:IsA("BasePart") or not shover then
		return
	end
	local tier, push = Shove.power(by)
	local down = seconds * (1 + (tier - 1) * 0.25)
	local away = root.Position - shover.Position
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away * settings.Push * push + Vector3.new(0, settings.Lift * math.sqrt(push), 0)
	root.AssemblyAngularVelocity = away:Cross(Vector3.yAxis) * -6 * push
	Sounds.at("Thud", root)
	local head = model:FindFirstChild("Head")
	remotes.JobFx:fireAll({
		kind = fx,
		at = if head and head:IsA("BasePart") then head.Position else root.Position,
		from = shover.Position,
		power = tier,
		by = by.UserId,
	})
	Stun.stars(model, down)
	downs += 1
	local mine = downs
	model:SetAttribute("Down", mine) -- only the latest knock-down gets them back up
	if stayDown then
		return
	end
	task.delay(down, function()
		if model.Parent and model:GetAttribute("Down") == mine then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function Shove.forget(player: Player)
	lastShove[player] = nil
end

return Shove
