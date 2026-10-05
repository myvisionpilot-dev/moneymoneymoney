--!strict
-- Always-on HUD: quota + progress + timer + next-step hint (top centre); bag, deposited, share, heat and the
-- current job (top right); a jail banner while you're locked up. It also plays the sting when
-- you gain a star, the clang and red flash when you're busted, and beeps for the last 10 seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COUNTDOWN_BEEPS = 10 -- seconds left in a quota when the beeps start
local BOOST_ORDER = { "Energy", "Disguise", "Candy", "Gloves", "Scanner" }
local BOOST_ICONS: { [string]: string } =
	{ Energy = "⚡", Disguise = "🧢", Candy = "🍫", Gloves = "🧤", Scanner = "📻" }

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
local bagBar: Frame? = nil
local quotaBarFrame: Frame? = nil
local statusLabel: TextLabel? = nil
local phaseStatus = "" -- the quota panel's line for the current phase
local hint: string? = nil -- GuideController's next step, shown instead during a quota

local function showStatus()
	local label = statusLabel
	if not label then
		return
	end
	local current = if ClientState.phase() == "Quota" then hint else nil
	local text = current or phaseStatus
	if label.Text ~= text then
		label.Text = text
		if current then
			UI.pop(label, 0.25)
		end
	end
	label.TextColor3 = if current then UI.Colors.Gold else UI.Colors.Muted
end

-- GuideController's "what to do next" line under the quota bar; nil goes back to normal.
function HudController.setHint(text: string?)
	hint = text
	showStatus()
end

-- JobGuideController shows the active job here; nil hides the row.
function HudController.setJobText(text: string?)
	local label = jobLabel
	if label then
		label.Visible = text ~= nil
		label.Text = if text then `📦 {text}` else ""
	end
end

-- A bounce on the bag bar (money came in) or the quota bar (a deposit).
function HudController.popBag()
	if bagBar then
		UI.pop(bagBar, 0.12)
	end
end

function HudController.popQuota()
	if quotaBarFrame then
		UI.pop(quotaBarFrame, 0.1)
	end
end

local function makeBar(parent: Instance, props: UI.Props, color: Color3): (Frame, Frame, TextLabel)
	local bar = UI.frame(props, parent)
	bar.BackgroundColor3 = UI.Colors.PanelDark
	bar.ClipsDescendants = false
	UI.corner(bar, 10)
	UI.stroke(bar, 3)
	local fill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, bar)
	UI.corner(fill, 10)
	UI.gradient(fill, 0.25)
	local text = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 2 }, bar)
	return bar, fill, text
end

local function panel(props: UI.Props, parent: Instance): Frame
	local frame = UI.frame(props, parent)
	frame.BackgroundColor3 = UI.Colors.Panel
	UI.corner(frame, 16)
	UI.stroke(frame, 4)
	UI.gradient(frame, 0.15)
	return frame
end

function HudController.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	local root = UI.root(UI.screen("Hud", 1))

	-- Quota panel
	local quotaPanel = panel({
		Name = "Quota",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(340, 90),
	}, root)

	local title = UI.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -120, 0, 28),
		Font = UI.Fonts.Heading,
		TextSize = 26,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "WAITING FOR CREW",
	}, quotaPanel)
	UI.textStroke(title, 3)

	local timer = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(110, 28),
		Font = UI.Fonts.Heading,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, quotaPanel)
	UI.textStroke(timer, 3)

	local quotaBar, quotaFill, quotaText = makeBar(quotaPanel, {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 26),
	}, UI.Colors.Money)
	quotaBarFrame = quotaBar

	local status = UI.label({
		Position = UDim2.fromOffset(12, 67),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		Text = "",
	}, quotaPanel)
	statusLabel = status

	-- Cash panel
	local cashPanel = panel({
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, root)
	UI.padding(cashPanel, 9)
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

	row(1, "🎒 BAG", UI.Colors.Muted)
	local bag, bagFill, bagText = makeBar(cashPanel, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
	}, UI.Colors.Gold)
	bagBar = bag
	local depositedLabel = row(3, "🏦 DEPOSITED $0", UI.Colors.Money)
	local shareLabel = row(4, "📊 YOUR SHARE 0%")
	local heatLabel = row(5, "🚨 HEAT", UI.Colors.Muted)
	-- Fills toward the next star, so small crimes (half a star) still show.
	local heatMeter = UI.frame({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = UI.Colors.PanelDark,
		Visible = false,
	}, cashPanel)
	UI.corner(heatMeter, 4)
	UI.stroke(heatMeter, 2)
	local heatMeterFill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Risk }, heatMeter)
	UI.corner(heatMeterFill, 4)
	local bountyLabel = row(7, "", UI.Colors.Danger)
	bountyLabel.Visible = false
	local rideLabel = row(8, "", UI.Colors.Gold)
	rideLabel.Visible = false
	local job = row(9, "", UI.Colors.Gold)
	job.Size = UDim2.fromScale(1, 0) -- long job titles wrap onto a second line
	job.AutomaticSize = Enum.AutomaticSize.Y
	job.Visible = false
	jobLabel = job
	local boostsLabel = row(10, "", UI.Colors.Gold) -- convenience-store boosts and their time left
	boostsLabel.Visible = false

	-- Jail banner while you're locked up: low on the screen, so the cell window stays clear
	-- (above the money lines).
	local jailBanner = UI.card(UI.Colors.Danger, {
		Name = "Jail",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(320, 52),
		Visible = false,
	}, root)
	local jailText = UI.label({
		Size = UDim2.fromScale(1, 1),
		Font = UI.Fonts.Heading,
		TextSize = 26,
	}, jailBanner)
	UI.textStroke(jailText, 3)

	-- A red flash over the whole screen when you're busted.
	local flashScreen = UI.screen("Flash", 0)
	flashScreen.IgnoreGuiInset = true
	local flash = UI.frame({
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Danger,
		BackgroundTransparency = 1,
	}, flashScreen)

	local lastStars = 0
	local wasJailed = false

	local function render(snapshot: Types.RunSnapshot)
		local phaseTitle = PHASE_TITLES[snapshot.phase]
		if snapshot.phase == "Quota" then
			phaseTitle = if snapshot.isEndless
				then `🔥 ENDLESS {snapshot.quotaIndex}`
				else `💰 QUOTA {snapshot.quotaIndex}`
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
			phaseStatus = "Deposit cash at the bank"
		elseif snapshot.phase == "Waiting" then
			phaseStatus = "The run starts soon"
		elseif snapshot.phase == "Intro" then
			phaseStatus = "Mr. Penny is about to name the price"
		elseif snapshot.phase == "Intermission" then
			phaseStatus = "Next quota starts soon"
		elseif snapshot.phase == "Decision" then
			phaseStatus = "Cash out or keep going?"
		else
			phaseStatus = ""
		end
		showStatus()

		local me = ClientState.me()
		if not me then
			return
		end
		bagFill.Size = UDim2.fromScale(math.clamp(me.carried / math.max(me.bagCapacity, 1), 0, 1), 1)
		bagFill.BackgroundColor3 = if me.carried >= me.bagCapacity then UI.Colors.Danger else UI.Colors.Gold
		bagText.Text = `{Format.money(me.carried)} / {Format.money(me.bagCapacity)}`
		depositedLabel.Text = `🏦 DEPOSITED {Format.money(me.deposited)}`
		local share = if snapshot.teamDeposited > 0 then me.deposited / snapshot.teamDeposited else 0
		shareLabel.Text = `📊 YOUR SHARE {Format.percent(share)}`

		local stars = math.floor(me.heat)
		local shown = string.rep("★", stars) .. string.rep("☆", Config.Police.MaxHeat - stars)
		local hideText = if not me.hiding
			then ""
			elseif me.spotted then "  SPOTTED!"
			elseif me.heat > 0 then "  hidden"
			else ""
		heatLabel.Text = `🚨 HEAT {shown}{hideText}`
		heatLabel.TextColor3 = if stars >= 1
			then UI.Colors.Danger
			elseif me.heat > 0 then UI.Colors.Risk
			else UI.Colors.Muted
		heatMeter.Visible = me.heat > 0 and stars < Config.Police.MaxHeat
		heatMeterFill.Size = UDim2.fromScale(me.heat - stars, 1)
		if stars > lastStars then
			Sounds.play("Wanted")
			UI.pop(heatLabel, 0.3)
		elseif stars == 0 and lastStars >= 1 and me.hiding then
			Sounds.play("Ding") -- lost the police in a bush
		end
		lastStars = stars

		local jailed = me.jailedUntil > Timing.now()
		if jailed and not wasJailed then
			Sounds.play("JailDoor")
			flash.BackgroundTransparency = 0.45
			UI.tween(flash, 0.8, { BackgroundTransparency = 1 })
		end
		wasJailed = jailed

		bountyLabel.Visible = me.bounty > 0
		bountyLabel.Text = `🎯 BOUNTY ON YOU {Format.money(me.bounty)}`
		rideLabel.Visible = me.rideLevel > 0
		local key = if UserInputService.TouchEnabled then "tap 🏎️" else "R"
		rideLabel.Text = if me.riding then `🏎️ RIDING · {key} to walk` else `🏎️ KART · {key} to ride`
	end

	ClientState.changed:Connect(render)
	if ClientState.snapshot then
		render(ClientState.snapshot)
	end

	local lastBeep = -1
	RunService.RenderStepped:Connect(function()
		local me = ClientState.me()
		local shown: { string } = {}
		for _, id in BOOST_ORDER do
			local endsAt = me and me.boosts[id]
			if endsAt and endsAt > Timing.now() then
				table.insert(shown, `{BOOST_ICONS[id]} {Format.clock(endsAt - Timing.now())}`)
			end
		end
		boostsLabel.Visible = #shown > 0
		boostsLabel.Text = table.concat(shown, "  ")
		local jailLeft = if me then me.jailedUntil - Timing.now() else 0
		jailBanner.Visible = jailLeft > 0
		if jailLeft > 0 then
			jailText.Text = `🚔 BUSTED! Out in {Format.clock(jailLeft)}`
		end

		local snapshot = ClientState.snapshot
		if not snapshot or snapshot.phaseEndsAt <= 0 or snapshot.phase == "Ended" then
			timer.Text = ""
			return
		end
		local secondsLeft = snapshot.phaseEndsAt - Timing.now()
		timer.Text = `⏱️ {Format.clock(secondsLeft)}`
		local urgent = snapshot.phase == "Quota" and secondsLeft <= Config.Guide.HurrySeconds
		timer.TextColor3 = if urgent then UI.Colors.Danger else UI.Colors.Text
		local whole = math.ceil(secondsLeft)
		if snapshot.phase == "Quota" and whole <= COUNTDOWN_BEEPS and whole > 0 and whole ~= lastBeep then
			lastBeep = whole
			Sounds.play("Beep", 1.3)
			UI.pop(timer, 0.2)
		end
	end)
end

return HudController
