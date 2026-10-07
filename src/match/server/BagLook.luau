--!strict
-- The bag you wear in a run (a Cred shop cosmetic), built from the shop's picture of it: slung
-- across you like a gym bag, hanging in front on a strap over your right shoulder that runs
-- down your back and under your left arm (a backpack goes on your back, a strap over each
-- shoulder). It swells in steps as your bag fills (with a puff of bills each time), the rarer
-- bags sparkle, a full one leaks bills, and it's gone while it's empty. Scenery only: it weighs
-- nothing and nothing bumps into it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BagLooks = require(ReplicatedStorage.Shared.BagLooks)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Particles = require(ReplicatedStorage.Shared.Particles)
local Profiles = require(ServerScriptService.Common.Profiles)
local Style = require(ServerScriptService.Common.Style)
local EconomyService = require(script.Parent.EconomyService)

local STEPS = 4 -- sizes: a quarter full, half, three quarters, full
local SMALLEST, BIGGEST = 0.45, 0.85 -- scale of the shop picture
local TALLEST = 2.2 -- studs: a tall bag (a sack, a backpack) is shrunk to fit this when full
local HANG = 0.45 -- how far above the bottom of your chest a slung bag's middle hangs
local TILT = math.rad(5) -- a slung bag hangs with its strap end a little higher
local STRAP_WIDTH, STRAP_THICK = 0.24, 0.06
local LIFT = 0.05 -- how far a strap sits off the torso

local LEAK_RATE = 3 -- bills a second fluttering out of a full bag
local BILL_GREEN = Color3.fromRGB(110, 210, 100)

type Worn = { model: Model, step: number, id: string, leak: ParticleEmitter? }

local BagLook = {}

local worn: { [Player]: Worn } = {}

local function takeOff(player: Player)
	local current = worn[player]
	if current then
		current.model:Destroy()
		worn[player] = nil
	end
end

-- The top of a strap clip, where the strap hooks on.
local function clipTop(model: Model, name: string): Vector3?
	local clip = model:FindFirstChild(name)
	if clip and clip:IsA("BasePart") then
		return (clip.CFrame * CFrame.new(0, clip.Size.Y / 2, 0)).Position
	end
	return nil
end

-- A strap through `points`: a flat band for each stretch, its face turned out from `centre`.
local function strap(model: Model, points: { Vector3 }, centre: Vector3, color: Color3)
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local middle = (from + to) / 2
		local band = Instance.new("Part")
		band.Name = "Strap"
		band.Anchored = true
		band.Size = Vector3.new(STRAP_WIDTH, STRAP_THICK, (to - from).Magnitude + STRAP_THICK * 2)
		band.CFrame = CFrame.lookAt(middle, to, (middle - centre).Unit)
		band.Color = color
		band.Material = Enum.Material.Fabric
		band.TopSurface = Enum.SurfaceType.Smooth
		band.BottomSurface = Enum.SurfaceType.Smooth
		band.Parent = model
	end
end

-- Hangs the bag (scaled, still at the origin) on the torso and runs its straps.
local function hang(model: Model, design: string, torso: BasePart)
	local box, size = model:GetBoundingBox()
	local back = box.Position.Z + size.Z / 2 -- how far its back sticks out behind its middle
	local half = torso.Size / 2
	local at = torso.CFrame
	local function point(x: number, y: number, z: number): Vector3
		return at:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local color = BagLooks.strap(design)
	if BagLooks.carry(design) == "Back" then
		local top = box.Position.Y + size.Y / 2
		model:PivotTo(at * CFrame.new(0, half.Y - 0.1 - top, half.Z + back + 0.02) * CFrame.Angles(0, math.pi, 0))
		for _, name in { "ClipLeft", "ClipRight" } do
			local clip = clipTop(model, name)
			if clip then
				local side = if at:PointToObjectSpace(clip).X >= 0 then 1 else -1
				strap(model, {
					clip,
					point(side * 0.5, half.Y + LIFT, half.Z + LIFT),
					point(side * 0.5, half.Y + LIFT, -half.Z - LIFT),
					point(side * 0.55, -half.Y + 0.3, -half.Z - LIFT),
					point(side * (half.X + LIFT), -half.Y + 0.3, 0),
				}, torso.Position, color)
			end
		end
		return
	end
	model:PivotTo(at * CFrame.new(0, -half.Y + HANG, -(half.Z + back + 0.02)) * CFrame.Angles(0, 0, TILT))
	local right, left = clipTop(model, "ClipRight"), clipTop(model, "ClipLeft")
	if right and left then
		strap(model, {
			right,
			point(0.5, half.Y + LIFT, -half.Z - LIFT),
			point(0.5, half.Y + LIFT, half.Z + LIFT),
			point(-half.X - LIFT, -half.Y + 0.35, half.Z + LIFT),
			point(-half.X - LIFT, -half.Y + 0.35, -half.Z - LIFT),
			left,
		}, torso.Position, color)
	end
end

-- The bag's biggest piece (where its sparkle and leaking bills come from).
local function bodyOf(model: Model): BasePart?
	local best: BasePart? = nil
	local volume = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Strap" then
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > volume then
				best, volume = part, size
			end
		end
	end
	return best
end

-- Sparkle for the rarer bags (and a glow for the legendary one), and the bills that leak out
-- of a full bag (switched on and off by setFull).
local function dress(model: Model, item: Cosmetics.Item, grew: boolean): ParticleEmitter?
	local body = bodyOf(model)
	if not body then
		return nil
	end
	if item.tier == "Legendary" then
		Particles.keep(body, "Sparkles", 6, item.color, 0.4)
		local light = Instance.new("PointLight")
		light.Color = item.color
		light.Range = 8
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = body
	elseif item.tier == "Epic" then
		Particles.keep(body, "Sparkles", 3, item.color, 0.35)
	end
	if grew then
		-- It swelled: a puff of bills and sparkle.
		Particles.emit(body, {
			{ preset = "Bills", count = 8, color = BILL_GREEN, scale = 0.5 },
			{ preset = "Sparkles", count = 8, color = Color3.fromRGB(255, 230, 120), scale = 0.5 },
		})
	end
	local leak = Particles.keep(body, "Bills", LEAK_RATE, BILL_GREEN, 0.4)
	leak.Speed = NumberRange.new(1, 3)
	leak.Enabled = false
	return leak
end

local function update(player: Player)
	local item = Style.worn(player, "Bag")
	local account = EconomyService.get(player.UserId)
	local fill = if account and account.bagCapacity > 0 then account.carried / account.bagCapacity else 0
	local step = if fill <= 0 then 0 else math.clamp(math.ceil(fill * STEPS), 1, STEPS)
	local full = fill >= 1
	local current = worn[player]
	if not item or step == 0 then
		takeOff(player)
		return
	end
	if current and current.step == step and current.id == item.id and current.model.Parent then
		if current.leak then
			current.leak.Enabled = full
		end
		return
	end
	local grew = current ~= nil and current.id == item.id and step > current.step
	takeOff(player)
	local character = player.Character
	local torso = character and character:FindFirstChild("UpperTorso")
	if not character or not torso or not torso:IsA("BasePart") then
		return
	end
	local design = item.model or "Sack"
	local model = ItemModels.model(design)
	if not model then
		return
	end
	model.Name = "BackBag"
	local _, natural = model:GetBoundingBox()
	local fit = math.min(1, TALLEST / (natural.Y * BIGGEST))
	model:ScaleTo((SMALLEST + (BIGGEST - SMALLEST) * step / STEPS) * fit)
	hang(model, design, torso)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
	local leak = dress(model, item, grew)
	if leak then
		leak.Enabled = full
	end
	worn[player] = { model = model, step = step, id = item.id, leak = leak }
end

function BagLook.start()
	EconomyService.changed:Connect(function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			update(player)
		end
	end)
	Profiles.loaded:Connect(update)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			worn[player] = nil -- went with the old character
			character:WaitForChild("UpperTorso", 10)
			update(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		worn[player] = nil
	end)
end

return BagLook
