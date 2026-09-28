--!strict
-- The race panel (top left): who's in, your place, checkpoints, laps and time, plus the par
-- times for a solo race; and a big 3-2-1-GO in the middle of the screen. The next checkpoint's
-- marker comes from JobGuideController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local GO_SHOWN_SECONDS = 1

local RaceController = {}

function RaceController.start()
	local root = UI.root(UI.screen("Race", 30))

	local panel = UI.frame({
		Name = "Panel",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	UI.corner(panel, 14)
	UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 8)
	UI.list(panel, Enum.FillDirection.Vertical, 2)

	local function line(order: number, size: number, color: Color3?, font: Enum.Font?): TextLabel
		return UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, size + 4),
			TextSize = size,
			Font = font or UI.Fonts.Body,
			TextColor3 = color or UI.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, panel)
	end
	local title = line(1, 22, UI.Colors.Gold, UI.Fonts.Heading)
	UI.textStroke(title)
	local progress = line(2, 16)
	local clock = line(3, 16)
	local hint = line(4, 13, UI.Colors.Muted)

	local countdown = UI.label({
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(300, 110),
		Font = UI.Fonts.Heading,
		TextSize = 96,
		TextColor3 = UI.Colors.Gold,
		Visible = false,
	}, root)
	UI.textStroke(countdown)

	local update: Types.RaceUpdate? = nil
	Remotes.match().RaceUpdate:onClient(function(newUpdate: Types.RaceUpdate?)
		update = newUpdate
		panel.Visible = newUpdate ~= nil
		if not newUpdate then
			countdown.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = update
		if not current then
			return
		end
		local now = Timing.now()
		local pars = current.parSeconds
		local parText =
			`Gold {Format.raceTime(pars[1])} · Silver {Format.raceTime(pars[2])} · Bronze {Format.raceTime(pars[3])}`

		if current.state == "Gathering" then
			title.Text = if current.solo then "TIME TRIAL" else "RACE"
			progress.Text = `{current.racers} racer{if current.racers == 1 then "" else "s"} · starts in {Format.clock(
				current.startsAt - now
			)}`
			clock.Text = "Stay by the start line"
			hint.Text = if current.solo then parText else "Top 3 get paid"
			countdown.Visible = false
			return
		end

		local lapSize = math.max(current.total // math.max(current.laps, 1), 1)
		local lap = math.min(current.checkpoint // lapSize + 1, current.laps)
		title.Text = if current.solo then "TIME TRIAL" else `{Format.ordinal(current.place)} OF {current.racers}`
		progress.Text = `Lap {lap}/{current.laps} · Checkpoint {current.checkpoint}/{current.total}`
		clock.Text = if now < current.startsAt then "0:00.0" else Format.raceTime(now - current.startsAt)
		hint.Text = if current.solo then parText else `Bronze par {Format.raceTime(pars[#pars])} to get paid`

		local untilGo = current.startsAt - now
		if untilGo > 0 then
			countdown.Visible = true
			countdown.Text = tostring(math.ceil(untilGo))
		elseif untilGo > -GO_SHOWN_SECONDS then
			countdown.Visible = true
			countdown.Text = "GO!"
		else
			countdown.Visible = false
		end
	end)
end

return RaceController
