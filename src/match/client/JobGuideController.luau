--!strict
-- Guides you through your current job (delivery, chores, errands...): a beam to the next
-- marker, a marker over every spot, and a HUD line with the job, time left and pay.

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

local JobGuideController = {}

local guide: Types.JobGuide? = nil
local points: { Attachment } = {}
local markers: { BillboardGui } = {}
local beam: Beam? = nil
local distanceLabel: TextLabel? = nil

local function clear()
	guide = nil
	if beam then
		beam:Destroy()
	end
	for _, marker in markers do
		marker:Destroy()
	end
	for _, point in points do
		point:Destroy()
	end
	beam, distanceLabel = nil, nil
	markers, points = {}, {}
	HudController.setJobText(nil)
end

local function linkBeam()
	local current = beam
	local character = player.Character
	if not current or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local attachment = root and root:FindFirstChild("RootAttachment")
	if attachment and attachment:IsA("Attachment") then
		current.Attachment0 = attachment
	end
end

local function makeMarker(point: Attachment, primary: boolean)
	local gui = Instance.new("BillboardGui")
	gui.Name = "JobMarker"
	gui.Adornee = point
	gui.AlwaysOnTop = true
	gui.Size = if primary then UDim2.fromOffset(120, 44) else UDim2.fromOffset(70, 26)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	local title = UI.label({
		Size = if primary then UDim2.fromScale(1, 0.6) else UDim2.fromScale(1, 1),
		Font = UI.Fonts.Heading,
		TextScaled = true,
		TextColor3 = UI.Colors.Gold,
		Text = "HERE",
	}, gui)
	UI.textStroke(title)
	if primary then
		local distance = UI.label({
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.4),
			TextScaled = true,
			Text = "",
		}, gui)
		UI.textStroke(distance)
		distanceLabel = distance
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(markers, gui)
end

local function onGuide(newGuide: Types.JobGuide?)
	clear()
	if not newGuide then
		return
	end
	guide = newGuide
	for index, position in newGuide.markers do
		local point = Instance.new("Attachment")
		point.Name = "JobTarget"
		point.WorldPosition = position + Vector3.new(0, 3, 0)
		point.Parent = workspace.Terrain
		table.insert(points, point)
		makeMarker(point, index == 1)
	end
	local first = points[1]
	if first then
		local newBeam = Instance.new("Beam")
		newBeam.Attachment1 = first
		newBeam.Color = ColorSequence.new(UI.Colors.Gold)
		newBeam.Width0 = 0.6
		newBeam.Width1 = 0.6
		newBeam.FaceCamera = true
		newBeam.LightEmission = 0.6
		newBeam.Transparency = NumberSequence.new(0.25)
		newBeam.Parent = workspace.Terrain
		beam = newBeam
		task.spawn(linkBeam)
	end
end

function JobGuideController.start()
	Remotes.match().JobGuide:onClient(onGuide)
	player.CharacterAdded:Connect(function()
		task.spawn(linkBeam)
	end)

	RunService.RenderStepped:Connect(function()
		local current = guide
		if not current then
			return
		end
		local secondsLeft = current.endsAt - Timing.now()
		HudController.setJobText(`{current.title} {Format.clock(secondsLeft)} · {Format.money(current.pay)}`)
		local label = distanceLabel
		local character = player.Character
		local first = current.markers[1]
		if label and character and first then
			label.Text = `{math.floor((character:GetPivot().Position - first).Magnitude)} studs`
		end
	end)
end

return JobGuideController
