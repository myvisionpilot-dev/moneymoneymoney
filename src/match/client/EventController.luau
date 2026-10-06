--!strict
-- The town event going on right now: an orange checkered card under the twist cards (what's happening
-- and the time left), plus a light pillar and a marker with the distance over the spot to go to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local TwistController = require(script.Parent.TwistController)

local PILLAR_HEIGHT = 150

local player = Players.LocalPlayer

local EventController = {}

local pillar: Part? = nil
local point: Attachment? = nil
local marker: BillboardGui? = nil
local distanceLabel: TextLabel? = nil

local function clearMarker()
	for _, thing in { pillar, point, marker } :: { Instance? } do
		if thing then
			thing:Destroy()
		end
	end
	pillar, point, marker, distanceLabel = nil, nil, nil, nil
end

-- The pillar, the spot and its marker, made the first time an event has a spot.
local function makeMarker(): Part
	local part = Instance.new("Part")
	part.Name = "EventPillar"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(PILLAR_HEIGHT, 2.5, 2.5)
	part.Material = Enum.Material.Neon
	part.Color = UI.Colors.Risk
	part.Transparency = 0.55
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	pillar = part

	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	point = attachment
	local gui = Instance.new("BillboardGui")
	gui.Name = "EventMarker"
	gui.Adornee = attachment
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(120, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	local title = UI.label({
		Size = UDim2.fromScale(1, 0.6),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = UI.Colors.Risk,
		Text = "EVENT",
	}, gui)
	UI.textStroke(title)
	local distance =
		UI.label({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), TextScaled = true }, gui)
	UI.textStroke(distance)
	distanceLabel = distance
	gui.Parent = player:WaitForChild("PlayerGui")
	marker = gui
	return part
end

local function showMarker(position: Vector3)
	local column = pillar or makeMarker()
	-- Cylinders lie along X, so stand it up.
	column.CFrame = CFrame.new(position + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if point then
		point.WorldPosition = position + Vector3.new(0, 3, 0)
	end
end

function EventController.start()
	local card, heading, detail, content = TwistController.card(TwistController.column(), "Event", 100, UI.Colors.Risk) -- under the twists
	card.Visible = false
	local timer = UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = UI.Fonts.Number,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)

	local current: Types.TownEventView? = nil

	Remotes.match().TownEvent:onClient(function(view: Types.TownEventView?)
		local isNew = view ~= nil and (current == nil or current.id ~= view.id)
		current = view
		if not view then
			card.Visible = false
			clearMarker()
			return
		end
		heading.Text = `EVENT: {view.title}`
		detail.Text = view.detail
		card.Visible = true
		if isNew then
			UI.pop(card, 0.2)
			Sounds.play("Ding", 0.8)
		end
		if view.marker then
			showMarker(view.marker)
		else
			clearMarker()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local view = current
		if not view then
			return
		end
		timer.Text = `{Format.clock(view.endsAt - Timing.now())} left`
		local label = distanceLabel
		local character = player.Character
		local target = view.marker
		if label and character and target then
			label.Text = `{math.floor((character:GetPivot().Position - target).Magnitude)} studs`
		end
	end)
end

return EventController
