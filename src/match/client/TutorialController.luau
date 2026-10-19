--!strict
-- The first-join tutorial on your screen (server/Tutorial). Each step is a few big words under
-- the quota panel with a row of dots for how far you've got, a trail of gold arrows along the
-- ground from you to where to go (scrolling toward it), and a bouncing arrow over the spot. When
-- you finish a step its cheer pops up in the middle ("Nice!") with stars; at the end a banner
-- says it's done before you're sent to the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local GOLD = Color3.fromRGB(255, 214, 60)
local SCROLL_SPEED = 7 -- studs a second the arrows slide toward the target
local NEAR_STUDS = 5 -- this close, the trail goes
local MARKER_HEIGHT = 7
local CHEER_SECONDS = 1.3
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local settings = Config.Tutorial
local player = Players.LocalPlayer

local TutorialController = {}

-- Arrows on the ground --------------------------------------------------------------------

type Arrow = { left: Part, right: Part }

local function bar(parent: Instance): Part
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.45, 0.1, 1.95)
	part.Color = GOLD
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- A chevron lying on the ground at `at`, pointing along `ahead` (flat, unit).
local function place(arrow: Arrow, at: Vector3, ahead: Vector3, transparency: number)
	local side = Vector3.new(-ahead.Z, 0, ahead.X)
	local tip = at + ahead * 0.8
	for index, part in { arrow.left, arrow.right } do
		local back = at - ahead * 0.8 + side * (if index == 1 then 1.1 else -1.1)
		part.CFrame = CFrame.lookAt((tip + back) / 2, tip)
		part.Transparency = transparency
	end
end

-- The marker over the spot ---------------------------------------------------------------

local function downArrow(parent: Instance): Frame
	local holder = UI.frame({ Size = UDim2.fromOffset(60, 70), BackgroundTransparency = 1 }, parent)
	local stem = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(18, 36),
		BackgroundColor3 = GOLD,
	}, holder)
	UI.corner(stem, 5)
	UI.stroke(stem, 3)
	for _, side in { -1, 1 } do
		local wing = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 11, 0, 46),
			Size = UDim2.fromOffset(38, 16),
			Rotation = side * -42,
			BackgroundColor3 = GOLD,
		}, holder)
		UI.corner(wing, 6)
		UI.stroke(wing, 3)
	end
	return holder
end

function TutorialController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Tutorial", 45))

	-- The step card: a dark checkered panel like the rest of the HUD, just under the quota panel.
	local card, content = UI.panel(UI.Colors.Panel, {
		Name = "Step",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(320, 68),
		Visible = false,
	}, root)
	UI.shine(card, 5, 12)
	local grow = Instance.new("UIScale")
	grow.Parent = card
	local line = UI.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 38),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Text = "",
	}, content)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 30
	fit.Parent = line
	UI.textStroke(line, 3)
	local dots = UI.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, content)
	UI.list(dots, Enum.FillDirection.Horizontal, 8)
	local dotFrames: { Frame } = {}
	for index = 1, #settings.Steps do
		local dot =
			UI.frame({ LayoutOrder = index, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = UI.Colors.Track }, dots)
		UI.corner(dot, 6)
		UI.stroke(dot, 2)
		dotFrames[index] = dot
	end

	-- The cheer in the middle.
	local cheer = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 90),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = GOLD,
		Text = "",
		Visible = false,
	}, root)
	UI.textStroke(cheer, 4)
	local cheerScale = Instance.new("UIScale")
	cheerScale.Parent = cheer

	-- The marker over the target.
	local point = Instance.new("Attachment")
	point.Name = "TutorialTarget"
	point.Parent = workspace.Terrain
	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialMarker"
	marker.Adornee = point
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Size = UDim2.fromOffset(60, 70)
	marker.Enabled = false
	downArrow(marker)
	marker.Parent = player:WaitForChild("PlayerGui")

	-- The trail.
	local folder = Instance.new("Folder")
	folder.Name = "TutorialArrows"
	folder.Parent = workspace
	local arrows: { Arrow } = {}
	for index = 1, settings.ArrowCount do
		arrows[index] = { left = bar(folder), right = bar(folder) }
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local current: Types.TutorialStep? = nil
	local shownIndex = 0
	local cheerUntil = 0

	local function showCard(step: Types.TutorialStep)
		line.Text = step.text
		for index, dot in dotFrames do
			dot.BackgroundColor3 = if index < step.index
				then UI.Colors.Money
				elseif index == step.index then GOLD
				else UI.Colors.Track
		end
		card.Visible = true
		grow.Scale = 0.7
		TweenService:Create(grow, POP, { Scale = 1 }):Play()
	end

	local function showCheer(text: string, big: boolean)
		cheer.Text = text
		cheer.Visible = true
		cheerScale.Scale = 0.4
		TweenService:Create(cheerScale, POP, { Scale = 1 }):Play()
		local middle = cheer.AbsolutePosition + cheer.AbsoluteSize / 2
		ScreenFx.stars(middle, if big then 30 else 16, GOLD)
		Sounds.play(if big then "Fanfare" else "Milestone", 1.1)
		cheerUntil = os.clock() + CHEER_SECONDS
	end

	remotes.Tutorial:onClient(function(step: Types.TutorialStep?)
		current = step
		if not step then
			card.Visible = false
			marker.Enabled = false
			shownIndex = 0
			return
		end
		if step.done then
			card.Visible = false
			marker.Enabled = false
			ScreenFx.banner(step.cheer or settings.DoneText, GOLD, step.text, settings.DoneSeconds)
			ScreenFx.rain(40)
			Sounds.play("Fanfare")
			return
		end
		if step.index ~= shownIndex then
			shownIndex = step.index
			if step.cheer then
				card.Visible = false -- the cheer has the screen, then the next step comes in
				showCheer(step.cheer, false)
				task.delay(CHEER_SECONDS - 0.3, function()
					if current == step or (current and current.index == step.index) then
						showCard(step)
					end
				end)
			else
				showCard(step)
			end
		end
	end)

	local function targetOf(step: Types.TutorialStep): Vector3?
		local follow = step.follow
		if follow and follow.Parent then
			local followRoot = follow:FindFirstChild("HumanoidRootPart")
			if followRoot and followRoot:IsA("BasePart") then
				return followRoot.Position
			end
		end
		return step.target
	end

	local function hideTrail()
		for _, arrow in arrows do
			arrow.left.Transparency = 1
			arrow.right.Transparency = 1
		end
	end

	RunService.RenderStepped:Connect(function()
		if os.clock() > cheerUntil then
			cheer.Visible = false
		end
		local step = current
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local target = if step and not step.done then targetOf(step) else nil
		if not target or not body or not body:IsA("BasePart") then
			marker.Enabled = false
			hideTrail()
			return
		end
		marker.Enabled = true
		point.WorldPosition = target + Vector3.new(0, MARKER_HEIGHT + math.sin(os.clock() * 4) * 0.6, 0)

		local from = body.Position
		if Vector3.new(target.X - from.X, 0, target.Z - from.Z).Magnitude < NEAR_STUDS then
			hideTrail()
			return
		end
		-- The way there: from you along the route (from its point nearest you), then the target.
		local points: { Vector3 } = { from }
		local route = step and step.route
		if route and #route >= 2 then
			local nearest, nearestDistance = 1, math.huge
			for index, spot in route do
				local gap = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z).Magnitude
				if gap < nearestDistance then
					nearest, nearestDistance = index, gap
				end
			end
			for index = nearest + 1, #route do
				table.insert(points, route[index])
			end
		end
		table.insert(points, target)
		local lengths: { number } = {}
		local total = 0
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			local length = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
			lengths[index] = length
			total += length
		end
		params.FilterDescendantsInstances = { character :: Instance, folder }
		local spacing = settings.ArrowSpacing
		local scroll = (os.clock() * SCROLL_SPEED) % spacing
		local segment, walked = 1, 0
		for index, arrow in arrows do
			local along = 2.5 + (index - 1) * spacing + scroll
			if along > total - 2 then
				arrow.left.Transparency = 1
				arrow.right.Transparency = 1
			else
				while segment < #lengths and walked + lengths[segment] < along do
					walked += lengths[segment]
					segment += 1
				end
				local a, b = points[segment], points[segment + 1]
				local direction = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				local share = if lengths[segment] > 0 then (along - walked) / lengths[segment] else 0
				local spot = a:Lerp(b, share)
				local ahead = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
				local hit = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
				local ground = if hit then hit.Position else Vector3.new(spot.X, from.Y - 3, spot.Z)
				-- Fade in near you, out toward the end of the trail and near the target.
				local fadeIn = math.clamp((along - 2.5) / spacing, 0, 1)
				local fadeOut = math.clamp((total - 2 - along) / spacing, 0, 1)
				local tail = math.clamp(1 - (index - settings.ArrowCount + 6) / 6, 0, 1)
				local alpha = fadeIn * fadeOut * tail
				place(arrow, ground + Vector3.new(0, 0.12, 0), ahead, 1 - alpha * 0.9)
			end
		end
	end)
end

return TutorialController
