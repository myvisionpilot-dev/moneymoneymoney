--!strict
-- End-of-run screen: podium, everyone's contribution and prize, MVP and Snake, fun awards
-- (Biggest Payday...) and the Cred you earned. A fanfare for cashing out, a sad sting when the
-- bank wasn't paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local UI = require(Shared:WaitForChild("UI"))

local MEDALS = { "1st", "2nd", "3rd" }

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

local function resultRow(parent: Instance, index: number, row: Types.ResultRow, results: Types.RunResults)
	local isMe = row.userId == Players.LocalPlayer.UserId
	local color = if isMe then UI.Colors.Gold else UI.Colors.Text
	local _, frame = UI.panel(if isMe then UI.Colors.PanelDark else UI.Colors.Panel, {
		LayoutOrder = index + 1,
		Size = UDim2.new(1, 0, 0, 30),
	}, parent)
	UI.padding(frame, 4)
	local name = `{MEDALS[index] or Format.ordinal(index)} {row.name}`
	if row.userId == results.mvpUserId then
		name ..= " (MVP)"
	end
	if row.userId == results.snakeUserId then
		name ..= " (Snake)"
	end
	if row.status == "Left" then
		name ..= " (left)"
	end
	cell(frame, 0, 0.44, name, color, Enum.TextXAlignment.Left)
	cell(frame, 0.44, 0.22, Format.money(row.deposited), UI.Colors.Money, Enum.TextXAlignment.Right)
	cell(frame, 0.68, 0.14, Format.percent(row.share), color, Enum.TextXAlignment.Right)
	cell(frame, 0.84, 0.16, Format.number(row.prize), UI.Colors.Gold, Enum.TextXAlignment.Right)
end

-- A fun title: "BIGGEST PAYDAY", then "Sam · $12,000 in one go".
local function awardCard(parent: Instance, index: number, award: Types.Award)
	local _, card = UI.panel(UI.Colors.Purple, { LayoutOrder = index }, parent)
	UI.padding(card, 4)
	local title = UI.label({
		Size = UDim2.fromScale(1, 0.5),
		FontFace = UI.Fonts.Heading,
		TextSize = 15,
		TextColor3 = UI.Colors.Gold,
		Text = award.title,
	}, card)
	UI.textStroke(title, 2)
	UI.label({
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.5),
		TextSize = 13,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = `{award.name} · {award.detail}`,
	}, card)
end

function ResultsController.start()
	local root = UI.root(UI.screen("Results", 50))
	local overlay = UI.frame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
	}, root)
	-- Light rays turning behind the panel when you cash out.
	local rays = UI.frame({
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 900),
		BackgroundTransparency = 1,
	}, overlay)
	UI.rays(rays, 900, UI.Colors.Gold, 450)
	local window = UI.window("", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 0),
		Visible = true,
	}, overlay)
	local panel = window.panel
	window.title.TextXAlignment = Enum.TextXAlignment.Center
	window.title.Size = UDim2.fromScale(1, 1)
	window.title.TextSize = 32
	UI.list(window.body, Enum.FillDirection.Vertical, 6)

	local subtitle = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, window.body)
	local earned = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = UI.Fonts.Number,
		TextSize = 38,
		TextColor3 = UI.Colors.Gold,
	}, window.body)
	UI.textStroke(earned, 3)

	local table_ = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, window.body)
	UI.list(table_, Enum.FillDirection.Vertical, 4)

	local awards = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, window.body)
	UI.grid(awards, UDim2.new(0.5, -3, 0, 46), 6)

	local footer = UI.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
	}, window.body)

	local endsAt = 0

	Remotes.match().RunResults:onClient(function(results: Types.RunResults)
		endsAt = results.endsAt
		local failed = results.reason == "Failed"
		window.title.Text = if failed then "THE BANK WASN'T PAID" else "YOU CASHED OUT!"
		panel.BackgroundColor3 = if failed then UI.Colors.Danger else UI.Colors.Money
		subtitle.Text = if failed
			then `Quotas cleared: {results.highestQuota}. A failed run keeps only part of your prize.`
			else `Quotas cleared: {results.highestQuota}`
		-- Your Cred counts up from nothing, clinking as it goes.
		local function credText(value: number): string
			return `+{Format.cred(value)}`
		end
		UI.roll(earned, 0, credText)
		task.delay(0.5, function()
			UI.roll(earned, results.yourPrize, credText, 1.6)
			for index = 1, 8 do
				task.delay(index * 0.18, function()
					Sounds.play("Coins", 0.9 + index * 0.06, 0.6)
				end)
			end
			task.delay(1.7, function()
				UI.pop(earned, 0.35)
				if not failed then
					ScreenFx.stars(earned.AbsolutePosition + earned.AbsoluteSize / 2, 20, UI.Colors.Gold)
				end
			end)
		end)
		rays.Visible = not failed

		for _, child in table_:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local header = UI.frame({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, table_)
		cell(header, 0, 0.44, "PLAYER", UI.Colors.Text, Enum.TextXAlignment.Left)
		cell(header, 0.44, 0.22, "DEPOSITED", UI.Colors.Text, Enum.TextXAlignment.Right)
		cell(header, 0.68, 0.14, "SHARE", UI.Colors.Text, Enum.TextXAlignment.Right)
		cell(header, 0.84, 0.16, "CRED", UI.Colors.Text, Enum.TextXAlignment.Right)
		for _, label in header:GetChildren() do
			if label:IsA("TextLabel") then
				label.TextSize = 13
			end
		end
		for index, row in results.players do
			resultRow(table_, index, row, results)
		end
		for _, child in awards:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, award in results.awards do
			awardCard(awards, index, award)
		end

		overlay.Visible = true
		UI.pop(panel, 0.08)
		Sounds.play(if failed then "Fail" else "Fanfare")
		if not failed then
			ScreenFx.rain(50)
			ScreenFx.flash(UI.Colors.Gold, 0.25)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if overlay.Visible then
			footer.Text = `Back to the lobby in {Format.clock(endsAt - Timing.now())}`
		end
	end)
end

return ResultsController
