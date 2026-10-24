--!strict
-- Break-ins on your screen (Paths/BreakIn on the server). Back doors are hidden except the one
-- whose break-in job you took (BreakInHouse), and take as long to pick as the server says you
-- take (BreakInHold). Inside a house (the Inside attribute on your
-- character): the sweeping lasers slide back and forth, and if any part of your body touches a
-- beam we tell the server (poses are only exact here, so it's checked here). A panel at the top
-- shows the cash left and how to get past the lasers; when the alarm goes it flashes red with a
-- countdown.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local UI = require(Shared:WaitForChild("UI"))

local DOOR_PROMPT = "BreakInPrompt"
local INSIDE_ATTRIBUTE = "Inside"
local HOLD_ATTRIBUTE = "BreakInHold"
local TIP_ATTRIBUTE = "BreakInHouse" -- the house whose back door you can see (its break-in job)
local ALARM_ATTRIBUTE = "AlarmEndsAt"
local LASER_TAG = "Laser"
local CHECK_SECONDS = 1 / 30
local TRIP_RETRY_SECONDS = 2 -- if the server didn't hear us, say it again
local ALARM_EDGE = 16 -- how thick the red edge round the screen is

local player = Players.LocalPlayer

local BreakInController = {}

type Sweeper = { part: BasePart, base: CFrame, dir: Vector3, amp: number, period: number, phase: number }

local room: Model? = nil
local sweepers: { Sweeper } = {}
local lasers: { BasePart } = {}
local trippedAt = -math.huge
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local panel: Frame
local cashLabel: TextLabel
local hintLabel: TextLabel
local alarmFrame: Frame
local alarmEdge: UIStroke
local alarmLabel: TextLabel

-- Back doors -------------------------------------------------------------------------------

local doorPrompts: { [ProximityPrompt]: boolean } = {}

local function holdSeconds(): number?
	local seconds = player:GetAttribute(HOLD_ATTRIBUTE)
	return if typeof(seconds) == "number" then seconds else nil
end

local function applyHold(prompt: ProximityPrompt)
	local seconds = holdSeconds()
	if seconds then
		prompt.HoldDuration = seconds
	end
end

-- Back doors are hidden till you take a house's break-in job: then that one shows (its door,
-- lamp and prompt), on your screen only.
local function showDoor(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local mine = model:GetAttribute("HouseId") == player:GetAttribute(TIP_ATTRIBUTE)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if mine then 0 else 1
			part.CanCollide = mine and part:GetAttribute("Collide") == true
			part.CanQuery = mine
		elseif part:IsA("PointLight") or part:IsA("ProximityPrompt") then
			(part :: any).Enabled = mine
		end
	end
end

local function showDoors()
	local folder = workspace:FindFirstChild("BreakInDoors")
	if folder then
		for _, model in folder:GetChildren() do
			showDoor(model)
		end
	end
end

local function watchPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == DOOR_PROMPT then
		doorPrompts[instance] = true
		instance.Destroying:Connect(function()
			doorPrompts[instance] = nil
		end)
		applyHold(instance)
		local model = instance:FindFirstAncestorOfClass("Model")
		if model then
			showDoor(model) -- it may stream in after the tip-off
		end
	end
end

-- The HUD ----------------------------------------------------------------------------------

local function buildHud()
	local gui = UI.screen("BreakIn", 6)
	local root = UI.root(gui)
	local frame, content = UI.panel(UI.Colors.Panel, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96), -- under the quota panel
		Size = UDim2.fromOffset(300, 74),
		Visible = false,
	}, root)
	panel = frame
	cashLabel = UI.label({
		Name = "Cash",
		FontFace = UI.Fonts.Title,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 32),
		TextSize = 28,
		TextColor3 = UI.Colors.Money,
		Text = "",
	}, content)
	UI.textStroke(cashLabel, 2.6)
	hintLabel = UI.label({
		Name = "Hint",
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 26),
		TextSize = 18,
		TextColor3 = UI.Colors.Muted,
		Text = "",
	}, content)
	-- The alarm: a flashing red edge right round the screen (its own gui, over the top bar too;
	-- the frame is inset so the stroke round it ends at the screen's edge) and a countdown.
	local alarmGui = UI.screen("BreakInAlarm", 5)
	alarmGui.IgnoreGuiInset = true
	alarmFrame = UI.frame({
		Name = "Alarm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * ALARM_EDGE, 1, -2 * ALARM_EDGE),
		BackgroundColor3 = UI.Colors.Danger,
		BackgroundTransparency = 1,
		Visible = false,
	}, alarmGui)
	alarmEdge = Instance.new("UIStroke")
	alarmEdge.Color = UI.Colors.Danger
	alarmEdge.Thickness = ALARM_EDGE
	alarmEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	alarmEdge.Parent = alarmFrame
	alarmLabel = UI.label({
		Name = "Countdown",
		FontFace = UI.Fonts.Title,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(420, 40),
		TextSize = 34,
		TextColor3 = UI.Colors.Danger,
		Text = "",
	}, root)
	UI.textStroke(alarmLabel, 3)
	alarmLabel.Visible = false
end

local function hint(): string
	local crawl = if TouchButtons.enabled() then "CRAWL" else "C"
	return `Jump low lasers. {crawl} to crawl.`
end

local function refreshCash()
	local current = room
	if not current then
		return
	end
	local total = current:GetAttribute("Piles")
	local left = current:GetAttribute("PilesLeft")
	if typeof(total) ~= "number" or typeof(left) ~= "number" then
		cashLabel.Text = "FIND THE CASH"
		return
	end
	local found = total - left
	cashLabel.Text = `CASH FOUND {found}/{total}`
	if current:GetAttribute(ALARM_ATTRIBUTE) then
		hintLabel.Text = "Cash locked away! Get out!"
	elseif left == 0 then
		hintLabel.Text = "All found! Head out the door."
	else
		hintLabel.Text = hint()
	end
	UI.pop(cashLabel, 0.15)
end

-- Inside -----------------------------------------------------------------------------------

local function characterParts(character: Model): { Instance }
	local parts: { Instance } = {}
	-- Your head, body and legs: not the root, nor the invisible collision box that stays upright
	-- when you lie down, nor your arms (they swing out as you turn; we're kind about those).
	for _, child in character:GetChildren() do
		if
			child:IsA("BasePart")
			and child.Name ~= "HumanoidRootPart"
			and child.Transparency < 1
			and not child.Name:find("Arm")
			and not child.Name:find("Hand")
		then
			table.insert(parts, child)
		end
	end
	return parts
end

local known: { [Instance]: boolean } = {}

-- A part of the room: a laser to watch, or one to sweep (where it sits now is the middle of its
-- sweep, so each is only picked up once).
local function collect(descendant: Instance)
	if known[descendant] or not descendant:IsA("BasePart") then
		return
	end
	known[descendant] = true
	if CollectionService:HasTag(descendant, LASER_TAG) then
		table.insert(lasers, descendant)
	end
	local dir = descendant:GetAttribute("SweepDir")
	local amp = descendant:GetAttribute("SweepAmp")
	local period = descendant:GetAttribute("SweepPeriod")
	local phase = descendant:GetAttribute("SweepPhase")
	if
		typeof(dir) == "Vector3"
		and typeof(amp) == "number"
		and typeof(period) == "number"
		and typeof(phase) == "number"
	then
		table.insert(sweepers, {
			part = descendant,
			base = descendant.CFrame,
			dir = dir,
			amp = amp,
			period = math.max(period, 0.5),
			phase = phase,
		})
	end
end

local function leaveRoom()
	room = nil
	sweepers, lasers, known = {}, {}, {}
	panel.Visible = false
	alarmFrame.Visible = false
	alarmLabel.Visible = false
end

local function enterRoom(houseId: number)
	local folder = workspace:WaitForChild("BreakInRooms", 10)
	local model = folder and folder:WaitForChild(`House{houseId}`, 10)
	local character = player.Character
	if not model or not model:IsA("Model") or not character or character:GetAttribute(INSIDE_ATTRIBUTE) ~= houseId then
		return
	end
	room = model
	trippedAt = -math.huge
	sweepers, lasers, known = {}, {}, {}
	for _, descendant in model:GetDescendants() do
		collect(descendant)
	end
	-- Streaming can bring the room in a bit at a time: pick up anything that arrives late.
	model.DescendantAdded:Connect(function(descendant: Instance)
		if room == model then
			collect(descendant)
		end
	end)
	model:GetAttributeChangedSignal("PilesLeft"):Connect(refreshCash)
	model:GetAttributeChangedSignal(ALARM_ATTRIBUTE):Connect(function()
		refreshCash()
		if room == model and model:GetAttribute(ALARM_ATTRIBUTE) then
			Sounds.play("Fail")
		end
	end)
	panel.Visible = true
	refreshCash()
	UI.pop(panel, 0.1)
end

local function watchCharacter(character: Model)
	local function update()
		local houseId = character:GetAttribute(INSIDE_ATTRIBUTE)
		if typeof(houseId) == "number" then
			task.spawn(enterRoom, houseId)
		else
			leaveRoom()
		end
	end
	character:GetAttributeChangedSignal(INSIDE_ATTRIBUTE):Connect(update)
	update()
end

local function touchingLaser(character: Model): boolean
	overlap.FilterDescendantsInstances = characterParts(character)
	for _, laser in lasers do
		if laser.Parent and laser.Transparency < 1 and #workspace:GetPartsInPart(laser, overlap) > 0 then
			return true
		end
	end
	return false
end

local sinceCheck = 0

local function step(dt: number)
	local current = room
	if not current then
		return
	end
	if not current.Parent then
		leaveRoom()
		return
	end
	local now = Timing.now()
	for _, sweeper in sweepers do
		local offset = math.sin((now / sweeper.period + sweeper.phase) * math.pi * 2) * sweeper.amp
		sweeper.part.CFrame = sweeper.base + sweeper.dir * offset
	end
	local alarm = current:GetAttribute(ALARM_ATTRIBUTE)
	if typeof(alarm) == "number" then
		local left = math.max(math.ceil(alarm - now), 0)
		alarmFrame.Visible = true
		alarmLabel.Visible = true
		alarmLabel.Text = `ALARM! OUT IN {left}`
		local flash = math.abs(math.sin(now * 5)) -- a red flash
		alarmFrame.BackgroundTransparency = 0.8 + 0.15 * flash
		alarmEdge.Transparency = 0.6 * flash
		return
	end
	sinceCheck += dt
	if sinceCheck < CHECK_SECONDS then
		return
	end
	sinceCheck = 0
	local character = player.Character
	if character and os.clock() - trippedAt > TRIP_RETRY_SECONDS and touchingLaser(character) then
		trippedAt = os.clock()
		Remotes.match().TripLaser:fire(nil)
	end
end

function BreakInController.start()
	buildHud()
	for _, descendant in workspace:GetDescendants() do
		watchPrompt(descendant)
	end
	workspace.DescendantAdded:Connect(watchPrompt)
	showDoors()
	player:GetAttributeChangedSignal(TIP_ATTRIBUTE):Connect(showDoors)
	player:GetAttributeChangedSignal(HOLD_ATTRIBUTE):Connect(function()
		for prompt in doorPrompts do
			applyHold(prompt)
		end
	end)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	RunService.Heartbeat:Connect(step)
end

return BreakInController
