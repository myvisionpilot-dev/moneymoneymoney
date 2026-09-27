--!strict
-- End-of-run screen: podium, everyone's contribution and prize, MVP, and the Cred you earned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local PLACES = { "1st", "2nd", "3rd" }

local ResultsController = {}

local function cell(parent: Instance, x: number, width: number, text: string, color: Color3, align: Enum.TextXAlignment)
	UI.label({
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(width, 1),
		TextXAlignment = align,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = color,
		TextSize = 16,
		Text = text,
	}, parent)
end

local function resultRow(parent: Instance, index: number, row: Types.ResultRow, mvpUserId: number?)
	local isMe = row.userId == Players.LocalPlayer.UserId
	local color = if isMe then UI.Colors.Gold else UI.Colors.Text
	local frame = UI.frame({
		LayoutOrder = index + 1,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	}, parent)
	local place = PLACES[index] or `{index}th`
	local name = `{place}  {row.name}`
	if row.userId == mvpUserId then
		name ..= "  [MVP]"
	end
	if row.status == "Left" then
		name ..= " (left)"
	end
	cell(frame, 0, 0.44, name, color, Enum.TextXAlignment.Left)
	cell(frame, 0.44, 0.22, Format.money(row.deposited), UI.Colors.Money, Enum.TextXAlignment.Right)
	cell(frame, 0.68, 0.14, Format.percent(row.share), color, Enum.TextXAlignment.Right)
	cell(frame, 0.84, 0.16, Format.number(row.prize), UI.Colors.Gold, Enum.TextXAlignment.Right)
end

function ResultsController.start()
	local root = UI.root(UI.screen("Results", 50))
	local overlay = UI.frame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
	}, root)
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.02,
	}, overlay)
	UI.corner(panel, 16)
	local stroke = UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 14)
	UI.list(panel, Enum.FillDirection.Vertical, 6)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = UI.Fonts.Heading,
		TextSize = 32,
	}, panel)
	UI.textStroke(title)
	local subtitle = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
	}, panel)
	local earned = UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		Font = UI.Fonts.Heading,
		TextSize = 36,
		TextColor3 = UI.Colors.Gold,
	}, panel)
	UI.textStroke(earned)

	local table_ = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, panel)
	UI.list(table_, Enum.FillDirection.Vertical, 2)

	local footer = UI.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, panel)

	local endsAt = 0

	Remotes.match().RunResults:onClient(function(results: Types.RunResults)
		endsAt = results.endsAt
		local failed = results.reason == "Failed"
		title.Text = if failed then "TONY WASN'T PAID" else "YOU CASHED OUT!"
		title.TextColor3 = if failed then UI.Colors.Danger else UI.Colors.Money
		stroke.Color = if failed then UI.Colors.Danger else UI.Colors.Gold
		subtitle.Text = if failed
			then `Quotas cleared: {results.highestQuota}. A failed run keeps only part of your prize.`
			else `Quotas cleared: {results.highestQuota}`
		earned.Text = `+{Format.cred(results.yourPrize)}`

		for _, child in table_:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local header = UI.frame({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, table_)
		cell(header, 0, 0.44, "PLAYER", UI.Colors.Muted, Enum.TextXAlignment.Left)
		cell(header, 0.44, 0.22, "DEPOSITED", UI.Colors.Muted, Enum.TextXAlignment.Right)
		cell(header, 0.68, 0.14, "SHARE", UI.Colors.Muted, Enum.TextXAlignment.Right)
		cell(header, 0.84, 0.16, "CRED", UI.Colors.Muted, Enum.TextXAlignment.Right)
		for _, label in header:GetChildren() do
			if label:IsA("TextLabel") then
				label.TextSize = 13
			end
		end
		for index, row in results.players do
			resultRow(table_, index, row, results.mvpUserId)
		end

		overlay.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		if overlay.Visible then
			footer.Text = `Back to the lobby in {Format.clock(endsAt - Timing.now())}`
		end
	end)
end

return ResultsController
