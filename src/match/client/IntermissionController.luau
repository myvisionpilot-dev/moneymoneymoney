--!strict
-- A paid quota: the result, everyone's contribution, and what's next. Shown through the break,
-- or for a few seconds while you play when the next quota started straight away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local CONFETTI_PIECES = 40
local CONFETTI_SECONDS = 2.2
local CONFETTI_COLORS = { UI.Colors.Gold, UI.Colors.Money, UI.Colors.Pink, UI.Colors.Panel, UI.Colors.Purple }

local IntermissionController = {}

local rng = Random.new()

-- Paper confetti raining down the screen.
local function confetti(parent: Instance)
	for _ = 1, CONFETTI_PIECES do
		local piece = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(rng:NextNumber(), 0, 0, rng:NextInteger(-60, -10)),
			Size = UDim2.fromOffset(rng:NextInteger(6, 11), rng:NextInteger(10, 16)),
			BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)],
			Rotation = rng:NextInteger(0, 360),
			ZIndex = 5,
		}, parent)
		local seconds = CONFETTI_SECONDS * rng:NextNumber(0.7, 1.1)
		UI.tween(piece, seconds, {
			Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.08, 0.08), 0, 1, 40),
			Rotation = piece.Rotation + rng:NextInteger(-360, 360),
		})
		task.delay(seconds, function()
			piece:Destroy()
		end)
	end
end

local function contributionRow(parent: Instance, order: number, contribution: Types.Contribution)
	local isMe = contribution.userId == Players.LocalPlayer.UserId
	local color = if isMe then UI.Colors.Gold else UI.Colors.Text
	local row = UI.frame({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	}, parent)
	UI.label({
		Size = UDim2.fromScale(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = color,
		Text = contribution.name,
	}, row)
	UI.label({
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		Text = Format.money(contribution.deposited),
	}, row)
	UI.label({
		Position = UDim2.fromScale(0.8, 0),
		Size = UDim2.fromScale(0.2, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		Text = Format.percent(contribution.share),
	}, row)
end

function IntermissionController.start()
	local root = UI.root(UI.screen("Intermission", 30))
	local panel = UI.card(UI.Colors.Money, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196), -- below Mr. Penny's banner
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, root)
	UI.padding(panel, 14)
	UI.list(panel, Enum.FillDirection.Vertical, 6)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = UI.Fonts.Heading,
		TextSize = 32,
	}, panel)
	UI.textStroke(title, 3)
	local subtitle = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, panel)
	local rows = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, panel)
	UI.list(rows, Enum.FillDirection.Vertical, 2)
	local nextLabel = UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		Font = UI.Fonts.Heading,
		TextSize = 20,
		TextColor3 = UI.Colors.Gold,
	}, panel)
	local countdown = UI.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, panel)

	local current: Types.QuotaResult? = nil

	Remotes.match().QuotaResult:onClient(function(result: Types.QuotaResult)
		current = result
		title.Text = if result.passed
			then `🎉 QUOTA {result.quotaIndex} PAID!`
			else `QUOTA {result.quotaIndex} MISSED`
		panel.BackgroundColor3 = if result.passed then UI.Colors.Money else UI.Colors.Danger
		subtitle.Text = `Team deposited {Format.money(result.total)} of {Format.money(result.target)}`

		for _, child in rows:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, contribution in result.contributions do
			contributionRow(rows, index, contribution)
		end

		if result.rolledOver then
			nextLabel.Text = `Now: Quota {result.nextQuotaIndex} · {Format.money(result.nextTarget)}`
		elseif result.quotaIndex >= Config.Match.CashOutAfterQuota then
			nextLabel.Text =
				`Up next: cash out, or face Quota {result.nextQuotaIndex} ({Format.money(result.nextTarget)})`
		else
			nextLabel.Text = `Next: Quota {result.nextQuotaIndex} · {Format.money(result.nextTarget)}`
		end
		panel.Visible = true
		UI.pop(panel, 0.1)
		if result.passed then
			Sounds.play("Fanfare")
			confetti(root)
		end
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase ~= "Intermission" and snapshot.phase ~= "Quota" then
			panel.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local result = current
		if not panel.Visible or not result then
			return
		end
		local secondsLeft = result.endsAt - Timing.now()
		if secondsLeft <= 0 then
			panel.Visible = false
		elseif result.rolledOver then
			countdown.Text = "It's already started. Keep going!"
		else
			countdown.Text = `Continuing in {Format.clock(secondsLeft)}`
		end
	end)
end

return IntermissionController
