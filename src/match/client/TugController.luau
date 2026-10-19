--!strict
-- The dog's spotted a squirrel (TugGame, from Paths/DogWalk): a panel pops up with what they've
-- seen, a meter of how hard they're pulling and a big PULL! button. Tap it, or E / Space / A,
-- as fast as you can to bring the meter back to HEEL before it reaches GONE (they slip the
-- leash) or the clock runs out. Prompts are off while it's up, so E only pulls. The server
-- counts the taps; between its updates the meter guesses ahead so it feels instant.

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local ACTION = "DogTug"
local TOUCH = UserInputService.TouchEnabled
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local TugController = {}

function TugController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("DogTug", 46))
	local panel = UI.frame({
		Name = "Tug",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(380, 150),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	UI.corner(panel, 18)
	UI.stroke(panel, 3)
	local grow = Instance.new("UIScale")
	grow.Parent = panel
	Cursor.registerPanel(panel)

	local title = UI.label({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 34),
		FontFace = UI.Fonts.Title,
		TextSize = 30,
		TextColor3 = UI.Colors.Risk,
		Text = "SQUIRREL!",
	}, panel)
	UI.textStroke(title, 3)
	local track = UI.frame({
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundColor3 = UI.Colors.Track,
	}, panel)
	UI.corner(track, 11)
	UI.stroke(track, 2.5)
	local fill = UI.frame({
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = UI.Colors.Money,
	}, track)
	UI.corner(fill, 11)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Colors.Money),
		ColorSequenceKeypoint.new(0.6, UI.Colors.Gold),
		ColorSequenceKeypoint.new(1, UI.Colors.Danger),
	})
	shade.Parent = fill
	for index, word in { "HEEL", "GONE" } do
		local end_ = UI.label({
			AnchorPoint = Vector2.new(if index == 1 then 0 else 1, 0),
			Position = UDim2.new(if index == 1 then 0 else 1, if index == 1 then 16 else -16, 0, 70),
			Size = UDim2.fromOffset(80, 18),
			TextSize = 14,
			TextXAlignment = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			TextColor3 = if index == 1 then UI.Colors.Money else UI.Colors.Danger,
			Text = word,
		}, panel)
		UI.textStroke(end_, 1.8)
	end
	local clock = UI.frame({
		Position = UDim2.fromOffset(110, 74),
		Size = UDim2.new(1, -220, 0, 8),
		BackgroundColor3 = UI.Colors.Track,
	}, panel)
	UI.corner(clock, 4)
	local clockFill = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Colors.Gold }, clock)
	UI.corner(clockFill, 4)
	local pull = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(200, 48),
		BackgroundColor3 = UI.Colors.Risk,
		TextSize = 26,
		Text = if TOUCH then "PULL!" else "PULL! (E)",
	}, panel)

	local current: Types.TugGame? = nil
	local meter = 0
	local guess = 0

	local function tap()
		local tug = current
		if not tug then
			return
		end
		remotes.TugTap:fire(nil)
		guess = math.max(0, guess - tug.tap)
		UI.pop(pull, 0.12)
		ScreenFx.shake(0.06, 0.08)
	end
	pull.Activated:Connect(tap)

	local function bind(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority(
				ACTION,
				function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
					if state == Enum.UserInputState.Begin then
						tap()
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.ContextActionPriority.High.Value + 50,
				Enum.KeyCode.E,
				Enum.KeyCode.Space,
				Enum.KeyCode.ButtonA,
				Enum.KeyCode.ButtonX
			)
		else
			ContextActionService:UnbindAction(ACTION)
		end
		ProximityPromptService.Enabled = not on
	end

	remotes.TugGame:onClient(function(update: Types.TugGame?)
		local was = current
		current = update
		if update then
			meter = update.meter
			if not was then
				guess = update.meter
				title.Text = update.critter
				panel.Visible = true
				grow.Scale = 0.6
				TweenService:Create(grow, POP, { Scale = 1 }):Play()
				Sounds.play("Whoosh", 1.2)
				bind(true)
			elseif math.abs(guess - meter) > 0.12 then
				guess = meter
			end
		elseif was then
			panel.Visible = false
			bind(false)
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local tug = current
		if not tug then
			return
		end
		guess = math.clamp(guess + tug.pull * dt, 0, 1)
		guess += (meter - guess) * math.min(1, dt * 3)
		fill.Size = UDim2.fromScale(math.clamp(guess, 0.04, 1), 1)
		local left = tug.endsAt - Timing.now()
		clockFill.Size = UDim2.fromScale(math.clamp(left / Config.Paths.Doors.DogWalk.Tug.Seconds, 0, 1), 1)
		panel.Rotation = math.sin(os.clock() * 40) * guess * 2.5
		title.Rotation = math.sin(os.clock() * 25) * 4
	end)
end

return TugController
