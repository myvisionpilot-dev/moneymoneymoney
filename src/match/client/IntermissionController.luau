--!strict
-- A paid quota. First the big moment on its own: fanfare, QUOTA 1 PAID!, confetti and money
-- raining down. Then (once that banner's had its moment) who paid: a panel springs in over
-- spinning gold rays, the rows dealt in one at a time with their amounts rolling up and the top
-- earner shining. It shows through the break, or until the hustle pick when the next quota
-- started straight away; the next quota itself is announced after the pick
-- (NextQuotaController), except before a cash-out choice, which the panel warns about.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local CONFETTI_PIECES = 70
local CONFETTI_SECONDS = 2.2
local CONFETTI_COLORS = { UI.Colors.Gold, UI.Colors.Money, UI.Colors.Pink, UI.Colors.Panel, UI.Colors.Purple }
local PAID_BANNER_SECONDS = 2.2
local WHO_PAID_DELAY = PAID_BANNER_SECONDS + 0.9 -- who paid comes in once the QUOTA PAID banner has gone
local ROW_GAP = 0.18 -- between rows being dealt in
local WIDTH = 440

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

-- One player's row: name, what they deposited (rolling up) and their share. The top earner's
-- row is gold and catches the light.
local function contributionRow(parent: Instance, order: number, contribution: Types.Contribution, top: boolean)
	local isMe = contribution.userId == Players.LocalPlayer.UserId
	local color = if isMe then UI.Colors.Gold else UI.Colors.Text
	local row, content = UI.panel(if top then UI.Colors.Gold else UI.Colors.PanelDark, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 32),
	}, parent)
	if top then
		UI.shine(row, 2, 12)
	end
	UI.padding(content, 5)
	UI.label({
		Size = UDim2.fromScale(0.5, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = if top then Color3.new(1, 1, 1) else color,
		Text = if top then `TOP  {contribution.name}` else contribution.name,
	}, content)
	local amount = UI.label({
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		FontFace = UI.Fonts.Number,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Money,
		Text = "",
	}, content)
	UI.label({
		Position = UDim2.fromScale(0.8, 0),
		Size = UDim2.fromScale(0.2, 1),
		FontFace = UI.Fonts.Number,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if top then Color3.new(1, 1, 1) else color,
		Text = Format.percent(contribution.share),
	}, content)
	UI.roll(amount, 0, Format.money)
	UI.roll(amount, contribution.deposited, Format.money, 0.7)
	-- Dealt in: it flips up from nothing.
	local deal = Instance.new("UIScale")
	deal.Scale = 0
	deal.Parent = row
	TweenService:Create(deal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sounds.play("Coins", 0.9 + order * 0.08, 0.6)
end

function IntermissionController.start()
	local root = UI.root(UI.screen("Intermission", 30))
	local holder = UI.frame({
		Name = "WhoPaid",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200), -- below Mr. Penny's drawer
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	-- Gold rays turning behind it.
	local rays = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(640, 640),
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, holder)
	UI.rays(rays, 640, UI.Colors.Gold, 320)
	local panel = UI.card(UI.Colors.Money, {
		Name = "Panel",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
	}, holder)
	UI.padding(panel, 14)
	UI.list(panel, Enum.FillDirection.Vertical, 6)
	local spring = Instance.new("UIScale")
	spring.Parent = holder

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = UI.Fonts.Title,
		TextSize = 32,
		Text = "WHO PAID",
	}, panel)
	UI.textStroke(title, 3)
	local subtitle = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
	}, panel)
	local rows = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, panel)
	UI.list(rows, Enum.FillDirection.Vertical, 4)
	local nextLabel = UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = UI.Fonts.Heading,
		TextSize = 18,
		TextColor3 = UI.Colors.Gold,
	}, panel)
	local countdown = UI.label({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
	}, panel)

	local current: Types.QuotaResult? = nil
	local shownFor = 0 -- bumps every result, so a late reveal doesn't show an old one

	local function reveal(result: Types.QuotaResult, mine: number)
		if shownFor ~= mine then
			return
		end
		title.Text = if result.passed then "WHO PAID" else `QUOTA {result.quotaIndex} MISSED`
		panel.BackgroundColor3 = if result.passed then UI.Colors.Money else UI.Colors.Danger
		subtitle.Text = `Quota {result.quotaIndex}: {Format.money(result.total)} of {Format.money(result.target)}`
		for _, child in rows:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		-- The next quota is announced after the hustle pick; a cash-out choice gets a warning.
		nextLabel.Visible = not result.rolledOver and result.quotaIndex >= Config.Match.CashOutAfterQuota
		nextLabel.Text = `Up next: cash out, or face Quota {result.nextQuotaIndex} ({Format.money(result.nextTarget)})`
		holder.Visible = true
		rays.Visible = result.passed
		spring.Scale = 0.4
		TweenService:Create(spring, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		Sounds.play("Whoosh", 1, 0.8)
		for index, contribution in result.contributions do
			task.delay(0.25 + (index - 1) * ROW_GAP, function()
				if shownFor == mine then
					contributionRow(rows, index, contribution, index == 1 and #result.contributions > 1)
				end
			end)
		end
	end

	Remotes.match().QuotaResult:onClient(function(result: Types.QuotaResult)
		current = result
		shownFor += 1
		local mine = shownFor
		holder.Visible = false
		if result.passed then
			-- The big one, on its own: fanfare, the banner, confetti and money raining down.
			Sounds.play("Fanfare")
			Sounds.play("CoinPour", 0.9)
			confetti(root)
			ScreenFx.rain(60)
			ScreenFx.flash(UI.Colors.Gold, 0.3)
			ScreenFx.shake(0.4, 0.5)
			ScreenFx.banner(
				`QUOTA {result.quotaIndex} PAID!`,
				UI.Colors.Gold,
				`{Format.money(result.total)} banked`,
				PAID_BANNER_SECONDS
			)
			task.delay(WHO_PAID_DELAY, reveal, result, mine)
		else
			reveal(result, mine)
		end
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase ~= "Intermission" and snapshot.phase ~= "Quota" then
			holder.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local result = current
		if not holder.Visible or not result then
			return
		end
		local secondsLeft = result.endsAt - Timing.now()
		if secondsLeft <= 0 then
			holder.Visible = false
		elseif result.rolledOver then
			countdown.Text = "Next up: pick a hustle!"
		else
			countdown.Text = `Continuing in {Format.clock(secondsLeft)}`
		end
	end)
end

return IntermissionController
