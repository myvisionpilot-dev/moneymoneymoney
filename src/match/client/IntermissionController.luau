--!strict
-- Between quotas: the result, everyone's contribution, and what's next.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local IntermissionController = {}

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
		TextColor3 = UI.Colors.Money,
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
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196), -- below Tony's banner
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 3, UI.Colors.Money)
	UI.padding(panel, 14)
	UI.list(panel, Enum.FillDirection.Vertical, 6)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Font = UI.Fonts.Heading,
		TextSize = 30,
		TextColor3 = UI.Colors.Money,
	}, panel)
	UI.textStroke(title)
	local subtitle = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
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
		title.Text = if result.passed then `QUOTA {result.quotaIndex} PAID!` else `QUOTA {result.quotaIndex} MISSED`
		title.TextColor3 = if result.passed then UI.Colors.Money else UI.Colors.Danger
		subtitle.Text = `Team deposited {Format.money(result.total)} of {Format.money(result.target)}`

		for _, child in rows:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, contribution in result.contributions do
			contributionRow(rows, index, contribution)
		end

		if result.quotaIndex >= Config.Match.CashOutAfterQuota then
			nextLabel.Text =
				`Up next: cash out, or face Quota {result.nextQuotaIndex} ({Format.money(result.nextTarget)})`
		else
			nextLabel.Text = `Next: Quota {result.nextQuotaIndex} · {Format.money(result.nextTarget)}`
		end
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase ~= "Intermission" then
			panel.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local result = current
		if panel.Visible and result then
			countdown.Text = `Continuing in {Format.clock(result.endsAt - Timing.now())}`
		end
	end)
end

return IntermissionController
