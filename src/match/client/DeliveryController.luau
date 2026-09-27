--!strict
-- Guides you to your drop-off: a beam from your character, a marker over the house, and a HUD line.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer

local DeliveryController = {}

local job: Types.DeliveryJob? = nil
local target: Attachment? = nil
local beam: Beam? = nil
local marker: BillboardGui? = nil
local distanceLabel: TextLabel? = nil

local function clear()
	job = nil
	if beam then
		beam:Destroy()
	end
	if marker then
		marker:Destroy()
	end
	if target then
		target:Destroy()
	end
	beam, marker, target, distanceLabel = nil, nil, nil, nil
	HudController.setJobText(nil)
end

local function linkBeam()
	local currentBeam = beam
	local character = player.Character
	if not currentBeam or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local attachment = root and root:FindFirstChild("RootAttachment")
	if attachment and attachment:IsA("Attachment") then
		currentBeam.Attachment0 = attachment
	end
end

local function onJob(newJob: Types.DeliveryJob?)
	clear()
	if not newJob then
		return
	end
	job = newJob

	local point = Instance.new("Attachment")
	point.Name = "DeliveryTarget"
	point.WorldPosition = newJob.dropoffPosition + Vector3.new(0, 3, 0)
	point.Parent = workspace.Terrain
	target = point

	local newBeam = Instance.new("Beam")
	newBeam.Attachment1 = point
	newBeam.Color = ColorSequence.new(UI.Colors.Gold)
	newBeam.Width0 = 0.6
	newBeam.Width1 = 0.6
	newBeam.FaceCamera = true
	newBeam.LightEmission = 0.6
	newBeam.Transparency = NumberSequence.new(0.25)
	newBeam.Parent = workspace.Terrain
	beam = newBeam
	task.spawn(linkBeam)

	local gui = Instance.new("BillboardGui")
	gui.Name = "DeliveryMarker"
	gui.Adornee = point
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(140, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	local title = UI.label({
		Size = UDim2.fromScale(1, 0.6),
		Font = UI.Fonts.Heading,
		TextScaled = true,
		TextColor3 = UI.Colors.Gold,
		Text = "DROP OFF",
	}, gui)
	UI.textStroke(title)
	local distance = UI.label({
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		TextScaled = true,
		Text = "",
	}, gui)
	UI.textStroke(distance)
	gui.Parent = player:WaitForChild("PlayerGui")
	marker = gui
	distanceLabel = distance
end

function DeliveryController.start()
	Remotes.match().DeliveryJob:onClient(onJob)
	player.CharacterAdded:Connect(function()
		task.spawn(linkBeam)
	end)

	RunService.RenderStepped:Connect(function()
		local current = job
		if not current then
			return
		end
		local secondsLeft = current.endsAt - Timing.now()
		HudController.setJobText(`DELIVERY {Format.clock(secondsLeft)} · {Format.money(current.payout)}`)
		local label = distanceLabel
		local character = player.Character
		if label and character then
			local studs = (character:GetPivot().Position - current.dropoffPosition).Magnitude
			label.Text = `{math.floor(studs)} studs`
		end
	end)
end

return DeliveryController
