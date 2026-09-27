--!strict
-- Always-on HUD: quota + progress + timer (top centre); bag, deposited, share, heat and the
-- current job (top right); a jail banner while you're locked up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local PHASE_TITLES: { [Types.Phase]: string } = {
	Waiting = "WAITING FOR CREW",
	Intro = "GET READY",
	Quota = "QUOTA",
	Intermission = "BREAK",
	Decision = "DECIDE",
	Results = "RUN OVER",
	Ended = "RUN OVER",
}

local HudController = {}

local jobLabel: TextLabel? = nil

-- DeliveryController shows the active job here; nil hides the row.
function HudController.setJobText(text: string?)
	local label = jobLabel
	if label then
		label.Visible = text ~= nil
		label.Text = text or ""
	end
end

local function makeBar(parent: Instance, props: UI.Props, color: Color3): (Frame, Frame, TextLabel)
	local bar = UI.frame(props, parent)
	bar.BackgroundColor3 = UI.Colors.PanelLight
	UI.corner(bar, 8)
	local fill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, bar)
	UI.corner(fill, 8)
	local text = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 2 }, bar)
	UI.textStroke(text)
	return bar, fill, text
end

function HudController.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	local root = UI.root(UI.screen("Hud", 1))

	-- Quota panel
	local quotaPanel = UI.frame({
		Name = "Quota",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(340, 88),
		BackgroundTransparency = 0.15,
	}, root)
	UI.corner(quotaPanel, 14)
	UI.stroke(quotaPanel, 3)

	local title = UI.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -120, 0, 28),
		Font = UI.Fonts.Heading,
		TextSize = 24,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "WAITING FOR CREW",
	}, quotaPanel)
	UI.textStroke(title)

	local timer = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(100, 28),
		Font = UI.Fonts.Heading,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, quotaPanel)
	UI.textStroke(timer)

	local quotaBar, quotaFill, quotaText = makeBar(quotaPanel, {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 26),
	}, UI.Colors.Money)

	local status = UI.label({
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		Text = "",
	}, quotaPanel)

	-- Cash panel
	local cashPanel = UI.frame({
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
	}, root)
	UI.corner(cashPanel, 14)
	UI.stroke(cashPanel, 3)
	UI.padding(cashPanel, 8)
	UI.list(cashPanel, Enum.FillDirection.Vertical, 4)

	local function row(order: number, text: string, color: Color3?): TextLabel
		return UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color or UI.Colors.Text,
			Text = text,
		}, cashPanel)
	end

	row(1, "BAG", UI.Colors.Muted)
	local _, bagFill, bagText = makeBar(cashPanel, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
	}, UI.Colors.Gold)
	local depositedLabel = row(3, "DEPOSITED $0", UI.Colors.Money)
	local shareLabel = row(4, "YOUR SHARE 0%")
	local heatLabel = row(5, "HEAT", UI.Colors.Muted)
	local job = row(6, "", UI.Colors.Gold)
	job.Visible = false
	jobLabel = job

	-- Jail banner (centre of the screen while you're locked up)
	local jailBanner = UI.label({
		Name = "Jail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(360, 60),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = UI.Colors.Panel,
		Font = UI.Fonts.Heading,
		TextSize = 30,
		TextColor3 = UI.Colors.Danger,
		Visible = false,
	}, root)
	UI.corner(jailBanner, 14)
	UI.stroke(jailBanner, 3, UI.Colors.Danger)

	local function render(snapshot: Types.RunSnapshot)
		local phaseTitle = PHASE_TITLES[snapshot.phase]
		if snapshot.phase == "Quota" then
			phaseTitle = if snapshot.isEndless then `ENDLESS {snapshot.quotaIndex}` else `QUOTA {snapshot.quotaIndex}`
		end
		title.Text = phaseTitle

		local showBar = snapshot.target > 0
		quotaBar.Visible = showBar
		if showBar then
			local fraction = math.clamp(snapshot.progress / snapshot.target, 0, 1)
			quotaFill.Size = UDim2.fromScale(fraction, 1)
			quotaText.Text = `{Format.money(snapshot.progress)} / {Format.money(snapshot.target)}`
		end

		if snapshot.phase == "Quota" then
			status.Text = if snapshot.progress >= snapshot.target
				then "Quota met! Extra rolls over."
				else "Deposit cash at Tony's desk"
		elseif snapshot.phase == "Waiting" then
			status.Text = "The run starts soon"
		elseif snapshot.phase == "Intro" then
			status.Text = "Tony's about to name his price"
		elseif snapshot.phase == "Intermission" then
			status.Text = "Next quota starts soon"
		elseif snapshot.phase == "Decision" then
			status.Text = "Cash out or keep going?"
		else
			status.Text = ""
		end

		local me = ClientState.me()
		if me then
			bagFill.Size = UDim2.fromScale(math.clamp(me.carried / math.max(me.bagCapacity, 1), 0, 1), 1)
			bagFill.BackgroundColor3 = if me.carried >= me.bagCapacity then UI.Colors.Danger else UI.Colors.Gold
			bagText.Text = `{Format.money(me.carried)} / {Format.money(me.bagCapacity)}`
			depositedLabel.Text = `DEPOSITED {Format.money(me.deposited)}`
			local share = if snapshot.teamDeposited > 0 then me.deposited / snapshot.teamDeposited else 0
			shareLabel.Text = `YOUR SHARE {Format.percent(share)}`

			local stars = math.floor(me.heat)
			local shown = string.rep("★", stars) .. string.rep("☆", Config.Police.MaxHeat - stars)
			heatLabel.Text = `HEAT {shown}` .. (if me.hiding and me.heat > 0 then "  hiding" else "")
			heatLabel.TextColor3 = if stars >= 1 then UI.Colors.Danger else UI.Colors.Muted
		end
	end

	ClientState.changed:Connect(render)
	if ClientState.snapshot then
		render(ClientState.snapshot)
	end

	RunService.RenderStepped:Connect(function()
		local me = ClientState.me()
		local jailLeft = if me then me.jailedUntil - Timing.now() else 0
		jailBanner.Visible = jailLeft > 0
		if jailLeft > 0 then
			jailBanner.Text = `BUSTED! Out in {Format.clock(jailLeft)}`
		end

		local snapshot = ClientState.snapshot
		if not snapshot or snapshot.phaseEndsAt <= 0 or snapshot.phase == "Ended" then
			timer.Text = ""
			return
		end
		local secondsLeft = snapshot.phaseEndsAt - Timing.now()
		timer.Text = Format.clock(secondsLeft)
		timer.TextColor3 = if snapshot.phase == "Quota" and secondsLeft <= 60 then UI.Colors.Danger else UI.Colors.Text
	end)
end

return HudController
