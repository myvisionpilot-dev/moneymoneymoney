--!strict
-- Loose cash on the ground (client): every LooseCash marker the server puts down (money rain,
-- the parade) becomes a bill you can see, fluttering down out of the sky until it lands, then
-- spinning and bobbing on the spot. When someone pockets one it pops: yours flies off to your
-- HOLDING bar with a clink, other people's just burst into sparkles.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Particles = require(Shared:WaitForChild("Particles"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local HudController = require(script.Parent.HudController)

local TAG = "LooseCash"
local FALL_FROM = 45
local BILL_GREEN = Color3.fromRGB(96, 200, 96)
local BILL_LIGHT = Color3.fromRGB(175, 240, 160)
local CLINK_GAP = 0.06

type Shown = { note: Part, band: Part, landsAt: number, fallsFrom: number, seed: number }

local LooseCashController = {}

local shown: { [BasePart]: Shown } = {}
local folder: Folder? = nil
local lastClink = 0
local rng = Random.new()

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = "LooseCashFx"
	created.Parent = workspace
	folder = created
	return created
end

local function piece(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = getFolder()
	return part
end

local function add(marker: Instance)
	if not marker:IsA("BasePart") or shown[marker] then
		return
	end
	local landsAt = marker:GetAttribute("LandsAt")
	local note = piece("Bill", Vector3.new(1.7, 0.06, 0.85), BILL_GREEN)
	local band = piece("Band", Vector3.new(0.4, 0.09, 0.87), BILL_LIGHT)
	shown[marker] = {
		note = note,
		band = band,
		landsAt = if typeof(landsAt) == "number" then landsAt else Timing.now(),
		fallsFrom = Timing.now(),
		seed = rng:NextNumber(0, 100),
	}
end

-- Gone: pocketed (it pops) or just gone (it vanishes).
local function remove(marker: Instance)
	if not marker:IsA("BasePart") then
		return
	end
	local entry = shown[marker]
	if not entry then
		return
	end
	shown[marker] = nil
	local at = entry.note.Position
	entry.note:Destroy()
	entry.band:Destroy()
	local collector = marker:GetAttribute("Collector")
	if collector == nil then
		return
	end
	Particles.burst(at, { { preset = "Sparkles", count = 6, color = BILL_LIGHT, scale = 0.6 } })
	if collector ~= Players.LocalPlayer.UserId then
		return
	end
	-- Yours: a clink, and the bill flies up to your HOLDING bar.
	local now = os.clock()
	if now - lastClink >= CLINK_GAP then
		lastClink = now
		Sounds.play("Coins", rng:NextNumber(1.05, 1.3), 0.6)
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local point, onScreen = camera:WorldToScreenPoint(at)
	if not onScreen then
		return
	end
	local flyer = ScreenFx.bill()
	flyer.Position = UDim2.fromOffset(point.X, point.Y)
	flyer.Parent = ScreenFx.layer()
	local to = HudController.bagTarget()
	local flight = TweenService:Create(
		flyer,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromOffset(to.X, to.Y), Rotation = rng:NextNumber(-300, 300) }
	)
	flight.Completed:Once(function()
		flyer:Destroy()
		HudController.popBag()
	end)
	flight:Play()
end

function LooseCashController.start()
	for _, marker in CollectionService:GetTagged(TAG) do
		add(marker)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

	RunService.RenderStepped:Connect(function()
		local now = Timing.now()
		local clock = os.clock()
		for marker, entry in shown do
			local spot = marker.Position - Vector3.new(0, 0.5, 0)
			local cframe: CFrame
			if now < entry.landsAt then
				-- Fluttering down: drifting side to side and tumbling.
				local t = math.clamp((now - entry.fallsFrom) / math.max(entry.landsAt - entry.fallsFrom, 0.01), 0, 1)
				local sway = math.sin(clock * 5 + entry.seed) * 1.5 * (1 - t)
				local height = FALL_FROM * (1 - t) + 0.4
				cframe = CFrame.new(spot + Vector3.new(sway, height, math.cos(clock * 4 + entry.seed) * (1 - t)))
					* CFrame.Angles(
						math.sin(clock * 7 + entry.seed) * 0.9,
						clock * 3 + entry.seed,
						math.cos(clock * 6) * 0.6
					)
			else
				-- Landed: hovering, spinning, catching the eye.
				local bob = 0.55 + math.sin(clock * 3 + entry.seed) * 0.15
				cframe = CFrame.new(spot + Vector3.new(0, bob, 0))
					* CFrame.Angles(0, clock * 2.2 + entry.seed, math.rad(25))
			end
			entry.note.CFrame = cframe
			entry.band.CFrame = cframe
		end
	end)
end

return LooseCashController
