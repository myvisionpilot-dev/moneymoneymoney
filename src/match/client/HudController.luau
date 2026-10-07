--!strict
-- Always-on HUD in the shop style (blue checkered panels): the quota (name, timer, progress bar
-- and the next-step hint) top centre; heat, health, the cash you're holding and your run level
-- (with its XP bar) top right, with small lines under them for what you've banked, your job,
-- boosts, bounty and hustles; a banner while you're in jail. Money rolls up instead of jumping,
-- and a full bag throbs red. It also plays the sting when you gain a star, the clang and red flash when you're
-- busted, beeps for the last 10 seconds, and swaps in the chase music while you're wanted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Music = require(Shared:WaitForChild("Music"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COUNTDOWN_BEEPS = 10 -- seconds left in a quota when the beeps start
local PANEL_WIDTH = 236
local BOOSTS: { { id: string, name: string } } = {
	{ id = "Energy", name = "Energy" },
	{ id = "Disguise", name = "Disguise" },
	{ id = "Candy", name = "Candy" },
	{ id = "Gloves", name = "Gloves" },
	{ id = "Scanner", name = "Scanner" },
}
local RED = UI.Colors.Danger
local GREEN = UI.Colors.Money
local GOLD = UI.Colors.Gold
local PURPLE = UI.Colors.Purple
local DARK_RED = Color3.fromRGB(150, 25, 40)

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
local levelBar: Frame? = nil
local quotaBarFrame: Frame? = nil
local hudRoot: Frame? = nil
local quotaFrame: Frame? = nil
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
			UI.pop(label, 0.15)
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
		label.Text = text or ""
	end
end

-- A bounce on the holding bar (money came in) or the quota bar (a deposit).
function HudController.popBag()
	if bagBar then
		UI.pop(bagBar, 0.08)
	end
end

-- The HUD's screen and its quota panel (announcements slide out from under it).
function HudController.quotaPanel(): (Frame?, Frame?)
	return hudRoot, quotaFrame
end

function HudController.popQuota()
	if quotaBarFrame then
		UI.pop(quotaBarFrame, 0.06)
	end
end

function HudController.popLevel()
	if levelBar then
		UI.pop(levelBar, 0.25)
	end
end

-- The middle of a HUD bar on screen (where flying cash heads); the screen's middle before the
-- HUD is built.
local function centre(frame: GuiObject?): Vector2
	if not frame then
		local camera = workspace.CurrentCamera
		return if camera then camera.ViewportSize / 2 else Vector2.new(400, 300)
	end
	return frame.AbsolutePosition + frame.AbsoluteSize / 2
end

function HudController.bagTarget(): Vector2
	return centre(bagBar)
end

function HudController.quotaTarget(): Vector2
	return centre(quotaBarFrame)
end

function HudController.levelTarget(): Vector2
	return centre(levelBar)
end

type Stat = { title: TextLabel, right: TextLabel, track: Frame, fill: Frame, text: TextLabel }

-- A row in the status panel: a round icon, a name, something on the right, and a bar.
local function statRow(parent: Instance, order: number, glyph: string, color: Color3, name: string): Stat
	local row = UI.frame({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, parent)
	UI.iconCircle(glyph, color, 30, { Position = UDim2.fromOffset(0, 6) }, row)
	local title = UI.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(0.5, -38, 0, 20),
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Text = name,
	}, row)
	local right = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 0, 20),
		FontFace = UI.Fonts.Number,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Text = "",
	}, row)
	local track, fill, text =
		UI.bar(color, { Position = UDim2.fromOffset(38, 23), Size = UDim2.new(1, -38, 0, 17) }, row)
	return { title = title, right = right, track = track, fill = fill, text = text }
end

function HudController.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- ours is in the status panel
	end)
	Music.start()

	local root = UI.root(UI.screen("Hud", 1))
	hudRoot = root

	-- Quota (top centre), drawn over the announcement drawer under it.
	local quotaOuter, quotaPanel = UI.panel(UI.Colors.Panel, {
		Name = "Quota",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(320, 80),
		ZIndex = 3,
	}, root)
	quotaFrame = quotaOuter
	UI.shine(quotaOuter, 6, 12) -- catches the light now and then
	local title = UI.label({
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -110, 0, 24),
		FontFace = UI.Fonts.Title,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Text = "WAITING FOR CREW",
	}, quotaPanel)
	local timer = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 3),
		Size = UDim2.fromOffset(100, 26),
		FontFace = UI.Fonts.Number,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Text = "",
	}, quotaPanel)
	UI.textStroke(timer, 2.5)
	local quotaBar, quotaFill, quotaText =
		UI.bar(GREEN, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 20) }, quotaPanel)
	quotaText.TextSize = 14
	quotaBarFrame = quotaBar
	local status = UI.label({
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
		Text = "",
	}, quotaPanel)
	statusLabel = status

	-- Status panel (top right): heat, health, holding, then small lines.
	local _, statusPanel = UI.panel(UI.Colors.Panel, {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, root, 320)
	UI.padding(statusPanel, 8)
	local layout = UI.list(statusPanel, Enum.FillDirection.Vertical, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local heat = statRow(statusPanel, 1, "!", RED, "HEAT")
	heat.right.TextSize = 19
	heat.right.TextColor3 = GOLD
	local health = statRow(statusPanel, 2, "+", GREEN, "HEALTH")
	local holding = statRow(statusPanel, 3, "$", GOLD, "HOLDING")
	bagBar = holding.track
	local level = statRow(statusPanel, 4, "LV", PURPLE, "LEVEL 1")
	level.right.TextColor3 = GOLD
	levelBar = level.track

	local function line(order: number, color: Color3?): TextLabel
		return UI.label({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 13,
			TextColor3 = color or UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		}, statusPanel)
	end
	local bankedLabel = line(5)
	local bountyLabel = line(6, Color3.fromRGB(255, 150, 150))
	bountyLabel.Visible = false
	local job = line(7, UI.Colors.Text)
	job.Visible = false
	jobLabel = job
	local boostsLabel = line(8)
	boostsLabel.Visible = false
	local hustlesLabel = line(9, Color3.fromRGB(225, 200, 255))
	hustlesLabel.Visible = false

	-- Jail banner while you're locked up: low on the screen, so the cell window stays clear
	-- (above the money lines).
	local jailBanner, jailContent = UI.panel(UI.Colors.Danger, {
		Name = "Jail",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(300, 46),
		Visible = false,
	}, root)
	local jailText = UI.label({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Title,
		TextSize = 22,
	}, jailContent)

	-- A red flash over the whole screen when you're busted.
	local flashScreen = UI.screen("Flash", 0)
	flashScreen.IgnoreGuiInset = true
	local flash = UI.frame({
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Danger,
		BackgroundTransparency = 1,
	}, flashScreen)

	-- Health comes straight from your own character.
	local function watchHealth(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local function show()
			local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			health.fill.Size = UDim2.fromScale(fraction, 1)
			health.fill.BackgroundColor3 = if fraction < 0.35 then RED else GREEN
			health.right.Text = `{math.floor(fraction * 100 + 0.5)}%`
		end
		humanoid.HealthChanged:Connect(show)
		show()
	end
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	player.CharacterAdded:Connect(watchHealth)

	local lastStars = 0
	local wasJailed = false
	local full = false
	local lastXp: number? = nil
	local lastLevel = 1

	-- "+12 XP" floating up off the level bar.
	local function xpFloat(gained: number)
		local floater = UI.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0, 30),
			Size = UDim2.fromOffset(90, 18),
			FontFace = UI.Fonts.Number,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(225, 190, 255),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = `+{gained} XP`,
			ZIndex = 5,
		}, level.track.Parent)
		UI.tween(floater, 0.9, { Position = UDim2.new(1, -4, 0, 6), TextTransparency = 1 })
		local outline = floater:FindFirstChild("TextOutline")
		if outline and outline:IsA("UIStroke") then
			UI.tween(outline, 0.9, { Transparency = 1 })
		end
		task.delay(1, function()
			floater:Destroy()
		end)
	end

	local function render(snapshot: Types.RunSnapshot)
		local phaseTitle = PHASE_TITLES[snapshot.phase]
		if snapshot.phase == "Quota" then
			phaseTitle = if snapshot.isEndless
				then `ENDLESS QUOTA {snapshot.quotaIndex}`
				else `QUOTA {snapshot.quotaIndex}`
		end
		title.Text = phaseTitle

		local showBar = snapshot.target > 0
		quotaBar.Visible = showBar
		if showBar then
			local fraction = math.clamp(snapshot.progress / snapshot.target, 0, 1)
			UI.tween(quotaFill, 0.35, { Size = UDim2.fromScale(fraction, 1) })
			local target = snapshot.target
			UI.roll(quotaText, snapshot.progress, function(value: number): string
				return `{Format.money(value)} / {Format.money(target)}`
			end, 0.9)
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
		full = me.carried >= me.bagCapacity
		UI.tween(
			holding.fill,
			0.3,
			{ Size = UDim2.fromScale(math.clamp(me.carried / math.max(me.bagCapacity, 1), 0, 1), 1) }
		)
		if not full then
			holding.fill.BackgroundColor3 = GOLD
		end
		local capacity = me.bagCapacity
		UI.roll(holding.text, me.carried, function(value: number): string
			return `{Format.money(value)} / {Format.money(capacity)}`
		end)
		holding.right.Text = if full then "FULL" else ""

		-- Run level and XP.
		level.title.Text = `LEVEL {me.level}`
		local bonus = math.floor(Config.Levels.PayPerLevel * (me.level - 1) * 100 + 0.5)
		level.right.Text = if bonus > 0 then `+{bonus}% PAY` else ""
		if me.xpNeeded > 0 then
			UI.tween(level.fill, 0.3, { Size = UDim2.fromScale(math.clamp(me.xp / me.xpNeeded, 0, 1), 1) })
			level.text.Text = `{me.xp} / {me.xpNeeded} XP`
		else
			level.fill.Size = UDim2.fromScale(1, 1)
			level.text.Text = "MAX LEVEL"
		end
		if lastXp ~= nil and me.level == lastLevel and me.xp > lastXp then
			xpFloat(me.xp - lastXp)
		end
		lastXp = me.xp
		lastLevel = me.level
		holding.right.TextColor3 = Color3.fromRGB(255, 150, 150)
		local share = if snapshot.teamDeposited > 0 then me.deposited / snapshot.teamDeposited else 0
		bankedLabel.Text = `Banked {Format.money(me.deposited)}  ·  {Format.percent(share)} share`

		local stars = math.floor(me.heat)
		heat.right.Text = string.rep("★", stars) .. string.rep("☆", Config.Police.MaxHeat - stars)
		heat.title.Text = if not me.hiding
			then "HEAT"
			elseif me.spotted then "HEAT  SPOTTED"
			elseif me.heat > 0 then "HEAT  HIDDEN"
			else "HEAT"
		if stars > lastStars then
			Sounds.play("Wanted")
			UI.pop(heat.right, 0.3)
		elseif stars == 0 and lastStars >= 1 and me.hiding then
			Sounds.play("Ding") -- lost the police in a bush
		end
		lastStars = stars
		Music.setChase(stars >= 1 and snapshot.phase == "Quota")

		local jailed = me.jailedUntil > Timing.now()
		if jailed and not wasJailed then
			Sounds.play("JailDoor")
			flash.BackgroundTransparency = 0.45
			UI.tween(flash, 0.8, { BackgroundTransparency = 1 })
		end
		wasJailed = jailed

		local hustles: { string } = {}
		for _, hustle in Config.Hustles.List do
			local stacks = me.hustles[hustle.id]
			if stacks then
				table.insert(hustles, if stacks > 1 then `{hustle.title} x{stacks}` else hustle.title)
			end
		end
		hustlesLabel.Visible = #hustles > 0
		hustlesLabel.Text = `Hustles: {table.concat(hustles, ", ")}`

		bountyLabel.Visible = me.bounty > 0
		bountyLabel.Text = `Bounty on you: {Format.money(me.bounty)}`
	end

	ClientState.changed:Connect(render)
	if ClientState.snapshot then
		render(ClientState.snapshot)
	end

	local lastBeep = -1
	RunService.RenderStepped:Connect(function()
		local me = ClientState.me()
		local shown: { string } = {}
		for _, boost in BOOSTS do
			local endsAt = me and me.boosts[boost.id]
			if endsAt and endsAt > Timing.now() then
				table.insert(shown, `{boost.name} {Format.clock(endsAt - Timing.now())}`)
			end
		end
		boostsLabel.Visible = #shown > 0
		boostsLabel.Text = table.concat(shown, "  ·  ")
		-- A full bag throbs red (and so does its FULL), so you head for the bank.
		if full then
			local beat = (math.sin(os.clock() * 8) + 1) / 2
			holding.fill.BackgroundColor3 = RED:Lerp(DARK_RED, beat)
			holding.right.TextTransparency = beat * 0.6
		else
			holding.right.TextTransparency = 0
		end
		-- The heat bar counts down to when your heat clears.
		local clearsIn = if me and me.heat > 0 then math.max(me.heatClearsAt - Timing.now(), 0) else 0
		heat.fill.Size = UDim2.fromScale(math.clamp(clearsIn / Config.Heat.WantedSeconds, 0, 1), 1)
		heat.text.Text = if not me or me.heat <= 0
			then "Clean"
			elseif me.heat >= 1 then `WANTED  {Format.clock(clearsIn)}`
			else `Cools off in {Format.clock(clearsIn)}`
		local jailLeft = if me then me.jailedUntil - Timing.now() else 0
		jailBanner.Visible = jailLeft > 0
		if jailLeft > 0 then
			jailText.Text = `BUSTED  ·  out in {Format.clock(jailLeft)}`
		end

		local snapshot = ClientState.snapshot
		if not snapshot or snapshot.phaseEndsAt <= 0 or snapshot.phase == "Ended" then
			timer.Text = ""
			return
		end
		local secondsLeft = snapshot.phaseEndsAt - Timing.now()
		timer.Text = Format.clock(secondsLeft)
		local urgent = snapshot.phase == "Quota" and secondsLeft <= Config.Guide.HurrySeconds
		timer.TextColor3 = if urgent then Color3.fromRGB(255, 120, 120) else UI.Colors.Text
		local whole = math.ceil(secondsLeft)
		if snapshot.phase == "Quota" and whole <= COUNTDOWN_BEEPS and whole > 0 and whole ~= lastBeep then
			lastBeep = whole
			Sounds.play("Beep", 1.3)
			UI.pop(timer, 0.2)
		end
	end)
end

return HudController
