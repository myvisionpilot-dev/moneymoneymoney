--!strict
-- After quota 5: cash out now, or keep going for a bigger quota and prize. Shows the risk plainly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local DecisionController = {}

function DecisionController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Decision", 40))
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196), -- below Tony's banner
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 14)
	FirstPerson.registerPanel(panel)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = UI.Fonts.Heading,
		TextSize = 28,
		TextColor3 = UI.Colors.Gold,
		Text = "CASH OUT OR KEEP GOING?",
	}, panel)
	UI.textStroke(title)
	local prizeLabel = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 20,
	}, panel)

	local buttons = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
	}, panel)
	UI.list(buttons, Enum.FillDirection.Horizontal, 12)
	local cashOut = UI.button({
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = UI.Colors.Money,
		TextSize = 20,
	}, buttons)
	local keepGoing = UI.button({
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = UI.Colors.Risk,
		TextSize = 18,
	}, buttons)

	local riskLabel = UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
	}, panel)
	local countdown = UI.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, panel)

	local prompt: Types.DecisionPrompt? = nil
	local chosen: Types.Decision? = nil

	local function setButtons(enabled: boolean)
		for _, button in { cashOut, keepGoing } do
			button.Active = enabled
			button.AutoButtonColor = enabled
		end
	end

	local function choose(choice: Types.Decision)
		if chosen or not prompt then
			return
		end
		chosen = choice
		setButtons(false)
		cashOut.BackgroundTransparency = if choice == "CashOut" then 0 else 0.6
		keepGoing.BackgroundTransparency = if choice == "Continue" then 0 else 0.6
		remotes.SubmitDecision:fire(choice)
	end
	cashOut.Activated:Connect(function()
		choose("CashOut")
	end)
	keepGoing.Activated:Connect(function()
		choose("Continue")
	end)

	remotes.DecisionPrompt:onClient(function(newPrompt: Types.DecisionPrompt)
		prompt = newPrompt
		chosen = nil
		setButtons(true)
		cashOut.BackgroundTransparency = 0
		keepGoing.BackgroundTransparency = 0
		prizeLabel.Text = `Your prize right now: {Format.cred(newPrompt.prizeNow)}`
		cashOut.Text = `CASH OUT\nTake {Format.cred(newPrompt.prizeNow)}`
		keepGoing.Text = `KEEP GOING\nQuota {newPrompt.nextQuotaIndex}: {Format.money(newPrompt.nextTarget)}`
		local keepPercent = Format.percent(Config.Match.FailKeepPercent)
		riskLabel.Text =
			`Keep going and fail: you keep only {keepPercent} ({Format.cred(newPrompt.prizeIfFail)}). No answer = cash out.`
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase ~= "Decision" then
			panel.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = prompt
		local snapshot = ClientState.snapshot
		if not panel.Visible or not current or not snapshot then
			return
		end
		local active, decided = 0, 0
		for _, row in snapshot.players do
			if row.status == "Active" then
				active += 1
				if row.decided then
					decided += 1
				end
			end
		end
		local choiceText = if chosen == "CashOut"
			then "You're cashing out. "
			elseif chosen == "Continue" then "You're staying in. "
			else ""
		countdown.Text = `{choiceText}{Format.clock(current.endsAt - Timing.now())} · {decided}/{active} decided`
	end)
end

return DecisionController
