--!strict
-- Talking to someone. What they say types out over their head in white (a speech line, not a
-- box), and your answers come up as numbered cards low in the middle of the screen: orange
-- when it adds heat, blue when it doesn't, grey when you can't pick it yet. Click a card or
-- press its number (the backpack's number keys are switched off meanwhile). A line with no
-- answers just shows for a moment, or until its progress bar fills. From far away (or with no
-- speaker to stand over) the line shows above the cards instead. One at a time; opening
-- another replaces it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local UI = require(Shared:WaitForChild("UI"))

local CARD_WIDTH = 460
local CARD_HEIGHT = 44
local FAR_STUDS = 60 -- past this the line moves from over their head to above the cards
local TYPE_SECONDS = 0.022 -- per letter
local BLIP_EVERY = 3 -- letters between blips
local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

export type Option = {
	text: string,
	detail: string?, -- small text on the right (pay, heat)
	heat: boolean?, -- orange: it adds heat
	locked: boolean?, -- grey, and can't be picked
}

export type Spec = {
	at: Vector3?, -- just above the speaker's head
	name: string,
	line: string,
	options: { Option },
	onChoose: ((choice: number) -> ())?,
	progress: { label: string, endsAt: number }?, -- a bar that fills by endsAt (server time)
	closeBeyond: number?, -- closes when you walk this far from the speaker
}

export type Handle = {
	setFooter: (text: string) -> (),
	close: () -> (),
}

local Dialogue = {}

local current: Handle? = nil
local container: Frame? = nil
local blocked = false -- another window (the hustle picker) is in the way
local wanted = false -- the open conversation wants its answers on screen

-- The holder for the cards, made on first use.
local function getContainer(): Frame
	local existing = container
	if existing then
		return existing
	end
	local root = UI.root(UI.screen("Dialogue", 40))
	local frame = UI.frame({
		Name = "Answers",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	UI.list(frame, Enum.FillDirection.Vertical, 6)
	Cursor.registerPanel(frame)
	container = frame
	return frame
end

-- Types the line out with soft blips; stops if the label gets a newer line.
local function typeOut(label: TextLabel, line: string)
	label.Text = line
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local length = utf8.len(line) or #line
		for shown = 1, length do
			if label.Text ~= line or not label.Parent then
				return
			end
			label.MaxVisibleGraphemes = shown
			if shown % BLIP_EVERY == 0 then
				Sounds.play("Click", 1.4 + math.random() * 0.3, 0.3)
			end
			task.wait(TYPE_SECONDS)
		end
		label.MaxVisibleGraphemes = -1
	end)
end

local function answerCard(parent: Instance, index: number, option: Option, onPick: () -> ())
	local color = if option.locked then UI.Colors.Grey elseif option.heat then UI.Colors.Risk else UI.Colors.Panel
	local card, content = UI.panel(color, {
		Name = `Answer{index}`,
		LayoutOrder = index,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
	}, parent)
	UI.iconCircle(tostring(index), UI.Colors.Ink, 28, { Position = UDim2.fromOffset(8, 8) }, content)
	local hasDetail = option.detail ~= nil and option.detail ~= ""
	local title = UI.label({
		Position = UDim2.fromOffset(44, 4),
		Size = UDim2.new(1, if hasDetail then -186 else -54, 1, -8),
		FontFace = UI.Fonts.Speech,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = option.text,
	}, content)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 19
	limit.MinTextSize = 11
	limit.Parent = title
	if hasDetail then
		UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0, 132, 1, 0),
			TextSize = 14,
			TextColor3 = if option.locked then UI.Colors.Text else UI.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = option.detail,
		}, content)
	end

	-- The whole card is the button.
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 5
	button.AutoButtonColor = false
	button.Parent = card
	local hover = Instance.new("UIScale")
	hover.Parent = card
	button.MouseEnter:Connect(function()
		if not option.locked then
			UI.tween(hover, 0.08, { Scale = 1.03 })
		end
	end)
	button.MouseLeave:Connect(function()
		UI.tween(hover, 0.08, { Scale = 1 })
	end)
	button.Activated:Connect(onPick)
end

-- Hides the answers while another window is open (and stops number keys picking them).
function Dialogue.setBlocked(isBlocked: boolean)
	blocked = isBlocked
	local holder = container
	if holder then
		holder.Visible = wanted and not blocked
	end
end

function Dialogue.close()
	local open = current
	if open then
		open.close()
	end
end

function Dialogue.open(spec: Spec): Handle
	Dialogue.close()
	local player = Players.LocalPlayer
	local holder = getContainer()
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Over their head: just the words, white with a dark edge.
	local point: Attachment? = nil
	local speech: BillboardGui? = nil
	local at = spec.at
	if at then
		local attachment = Instance.new("Attachment")
		attachment.Name = "DialogueSpot"
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		point = attachment
		local gui = Instance.new("BillboardGui")
		gui.Name = "Speech"
		gui.Adornee = attachment
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.MaxDistance = FAR_STUDS
		gui.Size = UDim2.fromOffset(360, 150)
		gui.SizeOffset = Vector2.new(0, 0.5) -- grows up from just over their head
		gui.Parent = player:WaitForChild("PlayerGui")
		speech = gui
		local label = UI.plain({
			Size = UDim2.fromScale(1, 1),
			FontFace = UI.Fonts.Speech,
			TextSize = 21,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}, gui)
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.new(0, 0, 0)
		edge.Thickness = 1.6
		edge.Transparency = 0.15
		edge.Parent = label
		typeOut(label, spec.line)
	end

	-- Far away (or nobody to stand over): the line goes above the cards.
	local farLine = UI.label({
		Name = "Line",
		LayoutOrder = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = UI.Fonts.Speech,
		TextSize = 18,
		Text = `{spec.name}: "{spec.line}"`,
		Visible = at == nil,
	}, holder)

	local closed = false
	local connections: { RBXScriptConnection } = {}
	local handle: Handle
	local hasOptions = #spec.options > 0

	local function choose(choice: number)
		local option = spec.options[choice]
		if closed or blocked or not option then
			return
		end
		if option.locked then
			Sounds.play("Fail", 1, 0.5)
			return
		end
		Sounds.play("Click")
		handle.close()
		local onChoose = spec.onChoose
		if onChoose then
			onChoose(choice)
		end
	end

	for index, option in spec.options do
		answerCard(holder, index, option, function()
			choose(index)
		end)
	end

	local progress = spec.progress
	local fill: Frame? = nil
	local startedAt = Timing.now()
	if progress then
		local _, barFill, barText = UI.bar(UI.Colors.Money, {
			LayoutOrder = 50,
			Size = UDim2.fromOffset(300, 24),
		}, holder)
		barText.Text = progress.label
		barText.TextSize = 15
		fill = barFill
	end

	local footer = UI.label({
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
		Text = "",
		Visible = false,
	}, holder)
	wanted = hasOptions or progress ~= nil or at == nil
	holder.Visible = wanted and not blocked
	UI.pop(holder, 0.05)

	-- Number keys answer while there are answers, so the backpack doesn't grab them too.
	if hasOptions then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
				local choice = KEYS[input.KeyCode]
				if choice and not processed then
					choose(choice)
				end
			end)
		)
	end

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if at and camera then
				local far = (camera.CFrame.Position - at).Magnitude > FAR_STUDS
				farLine.Visible = far
				if far and not hasOptions and not progress then
					wanted = true
					holder.Visible = not blocked
				end
			end
			local barFill = fill
			if progress and barFill then
				local span = math.max(progress.endsAt - startedAt, 0.01)
				barFill.Size = UDim2.fromScale(math.clamp((Timing.now() - startedAt) / span, 0, 1), 1)
			end
			local beyond = spec.closeBeyond
			local character = player.Character
			if at and beyond and character then
				local offset = character:GetPivot().Position - at
				if Vector3.new(offset.X, 0, offset.Z).Magnitude > beyond then
					handle.close()
				end
			end
		end)
	)

	handle = {
		setFooter = function(text: string)
			footer.Text = text
			footer.Visible = text ~= ""
		end,
		close = function()
			if closed then
				return
			end
			closed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			if speech then
				speech:Destroy()
			end
			if point then
				point:Destroy()
			end
			wanted = false
			holder.Visible = false
			for _, child in holder:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			if hasOptions then
				pcall(function()
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
				end)
			end
			if current == handle then
				current = nil
			end
		end,
	}
	current = handle

	-- Just a line: it closes by itself once it's been read (or once the bar is full).
	if not hasOptions then
		local seconds = if progress
			then math.max(progress.endsAt - Timing.now(), 0) + 1.5
			else 1.8 + #spec.line * (TYPE_SECONDS + 0.035)
		task.delay(seconds, handle.close)
	else
		Sounds.play("Open")
	end
	return handle
end

return Dialogue
