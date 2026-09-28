--!strict
-- The pickpocket minigame: a needle bounces along a bar; press (E, click, a controller's A, or
-- the GRAB button on touch screens) while it's in the green. Three rounds, each faster with a
-- smaller zone. We show hits and misses straight away and send our press times to the server,
-- which checks them and decides. Other prompts are hidden meanwhile so E only grabs.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local BAR_WIDTH = 340
local RESULT_SECONDS = 0.9 -- how long the last hit or miss shows before the panel closes

local PickpocketController = {}

local function needleAt(zone: Types.PickpocketZone, t: number): number
	local travel = (t * zone.speed) % 2
	return if travel <= 1 then travel else 2 - travel
end

function PickpocketController.start()
	local remotes = Remotes.match()
	local tolerance = Config.Paths.Pickpocket.Minigame.Tolerance
	local root = UI.root(UI.screen("Pickpocket", 45))

	local panel = UI.card(UI.Colors.Purple, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(BAR_WIDTH + 40, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, root)
	UI.padding(panel, 12)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = UI.Fonts.Heading,
		TextSize = 26,
	}, panel)
	UI.textStroke(title, 3)
	local hint = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Text = "Press E (or click) when the needle is in the green!",
	}, panel)

	local bar = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(BAR_WIDTH, 38),
		BackgroundColor3 = UI.Colors.PanelDark,
		ClipsDescendants = true,
	}, panel)
	UI.corner(bar, 10)
	UI.stroke(bar, 3)
	local zoneFrame = UI.frame({ Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = UI.Colors.Money }, bar)
	UI.gradient(zoneFrame, 0.2)
	local needle = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 8, 1, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, bar)
	UI.corner(needle, 4)
	UI.stroke(needle, 2)

	local footer = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, panel)
	local rounds = UI.label({
		Size = UDim2.fromScale(0.5, 1),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, footer)
	local grab = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 20,
		Text = "👛 GRAB!",
	}, footer)

	local current: Types.PickpocketGame? = nil
	local round = 1
	local roundStartedAt = 0
	local presses: { number } = {}
	local finished = false

	local function showRound()
		local game = current
		if not game then
			return
		end
		local zone = game.zones[round]
		zoneFrame.Position = UDim2.fromScale(zone.start, 0)
		zoneFrame.Size = UDim2.fromScale(zone.width, 1)
		zoneFrame.BackgroundColor3 = UI.Colors.Money
		local dots = {}
		for index = 1, #game.zones do
			table.insert(dots, if index < round then "✅" elseif index == round then "🟡" else "⚪")
		end
		rounds.Text = table.concat(dots, " ")
	end

	local function submit()
		finished = true
		remotes.PickpocketPresses:fire(presses)
	end

	local function press()
		local game = current
		if not game or finished or os.clock() < roundStartedAt then
			return
		end
		local t = os.clock() - roundStartedAt
		local zone = game.zones[round]
		local position = needleAt(zone, t)
		table.insert(presses, t)
		local hit = position >= zone.start - tolerance and position <= zone.start + zone.width + tolerance
		if not hit then
			zoneFrame.BackgroundColor3 = UI.Colors.Danger
			hint.Text = "Missed! They noticed..."
			Sounds.play("Whistle")
			UI.pop(bar, 0.08)
			submit()
			return
		end
		Sounds.play("Ding", 1 + round * 0.12)
		UI.pop(needle, 0.5)
		if round >= #game.zones then
			hint.Text = "Got it!"
			submit()
			return
		end
		round += 1
		roundStartedAt = os.clock() + game.pauseSeconds
		showRound()
	end

	grab.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not current or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		local isKey = key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1 and not processed
		if isKey or isClick then
			press()
		end
	end)

	remotes.PickpocketGame:onClient(function(game: Types.PickpocketGame?)
		if not game then
			-- The server decided; leave the last hit or miss up for a moment.
			local closing = current
			task.delay(RESULT_SECONDS, function()
				if current == closing then
					current = nil
					panel.Visible = false
					ProximityPromptService.Enabled = true
				end
			end)
			return
		end
		current = game
		round = 1
		presses = {}
		finished = false
		roundStartedAt = os.clock() + game.pauseSeconds
		title.Text = `👛 Pickpocket {game.target}`
		hint.Text = "Press E (or click) when the needle is in the green!"
		showRound()
		panel.Visible = true
		ProximityPromptService.Enabled = false
		UI.pop(panel, 0.08)
		Sounds.play("Swipe", 1.3)
	end)

	RunService.RenderStepped:Connect(function()
		local game = current
		if not game or finished then
			return
		end
		local t = math.max(os.clock() - roundStartedAt, 0)
		needle.Position = UDim2.fromScale(needleAt(game.zones[round], t), 0.5)
		if t > game.roundSeconds then
			table.insert(presses, t) -- too slow counts as a miss
			hint.Text = "Too slow! They noticed..."
			Sounds.play("Whistle")
			submit()
		end
	end)
end

return PickpocketController
