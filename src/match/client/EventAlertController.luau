--!strict
-- The town event ALERT (client): when an event starts, a big panel in the event's colour
-- (Config.Events.Alert) drops out from under the quota panel and bounces to a stop, with light
-- rays spinning behind the words: ALERT, the event's name, what to do. As it lands the screen
-- flashes its colour, the camera jolts, stars fly off it and the alarm goes; while it's down its
-- outline strobes, ALERT blinks and the panel throbs. Then it goes back up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local settings = Config.Events.Alert
local TUCK = 14 -- how far its top stays tucked up under the quota panel
local OUTLINE_ROOM = 6 -- room in the opening for the outline, so it isn't cut off
local PADDING = 12
local ALERT_HEIGHT = 22
local TITLE_HEIGHT = 42
local DETAIL_SIZE = 17
local DROP = TweenInfo.new(0.55, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local LIFT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local DEFAULT_COLOR = Color3.fromRGB(215, 30, 50)

local EventAlertController = {}

local showing = false

-- True while an alert is down (announcements wait for it).
function EventAlertController.showing(): boolean
	return showing
end

local show: (view: Types.TownEventView) -> () = function() end

function EventAlertController.show(view: Types.TownEventView)
	show(view)
end

function EventAlertController.start()
	local root, quota = HudController.quotaPanel()
	if not root or not quota then
		return
	end
	-- Like the announcement drawer: the opening starts under the quota panel (drawn on top) and
	-- cuts off anything above it, so the alert seems to drop out from behind it.
	local width = quota.Size.X.Offset
	local slot = UI.frame({
		Name = "EventAlert",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, quota.Position.Y.Offset + quota.Size.Y.Offset - TUCK),
		Size = UDim2.fromOffset(width + OUTLINE_ROOM * 2, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = quota.ZIndex - 1,
	}, root)
	local panel, content = UI.panel(DEFAULT_COLOR, { Size = UDim2.fromOffset(width, 160) }, slot, 260)
	local border = panel:FindFirstChild("Border") :: UIStroke?
	local rays: Instance = UI.rays(panel, 520, nil, 12)
	local throb = Instance.new("UIScale")
	throb.Parent = content

	local alert = UI.label({
		Position = UDim2.fromOffset(PADDING, TUCK + 6),
		Size = UDim2.new(1, -PADDING * 2, 0, ALERT_HEIGHT),
		FontFace = UI.Fonts.Title,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "ALERT",
	}, content)
	UI.textStroke(alert, 2)
	local title = UI.label({
		Position = UDim2.fromOffset(PADDING, TUCK + 6 + ALERT_HEIGHT),
		Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, content)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 38
	fit.Parent = title
	UI.textStroke(title, 3)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 235, 150))
	shine.Parent = title
	local detailTop = TUCK + 6 + ALERT_HEIGHT + TITLE_HEIGHT + 2
	local detail = UI.label({
		Position = UDim2.fromOffset(PADDING, detailTop),
		Size = UDim2.new(1, -PADDING * 2, 0, 40),
		FontFace = UI.Fonts.Heading,
		TextSize = DETAIL_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	}, content)

	local function detailHeight(line: string): number
		local params = Instance.new("GetTextBoundsParams")
		params.Text = line
		params.Font = UI.Fonts.Heading
		params.Size = DETAIL_SIZE
		params.Width = width - PADDING * 2
		local ok, bounds = pcall(function()
			return TextService:GetTextBoundsAsync(params)
		end)
		return if ok then math.ceil(bounds.Y) else DETAIL_SIZE * 3
	end

	local shown = 0 -- bumps every alert, so an old one doesn't lift a newer one
	local height = 160
	local landedAt = 0

	show = function(view: Types.TownEventView)
		shown += 1
		local mine = shown
		local color = settings.Colors[view.id] or DEFAULT_COLOR
		local words = if view.detail ~= "" then view.detail else "Something's happening in town!"
		local wordsHeight = detailHeight(words)
		height = detailTop + wordsHeight + PADDING
		title.Text = `{view.title}!`
		detail.Text = words
		detail.Size = UDim2.new(1, -PADDING * 2, 0, wordsHeight + 2)
		panel.BackgroundColor3 = color
		rays:Destroy()
		-- Rays in a lighter shade of its own colour (white ones wash it out).
		rays = UI.rays(panel, 520, color:Lerp(Color3.new(1, 1, 1), 0.3), 12)
		slot.Size = UDim2.fromOffset(width + OUTLINE_ROOM * 2, height + OUTLINE_ROOM * 2)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset(OUTLINE_ROOM, -height)
		showing = true
		TweenService:Create(panel, DROP, { Position = UDim2.fromOffset(OUTLINE_ROOM, 0) }):Play()
		Sounds.play("Whoosh", 0.9, 0.8)
		-- It lands: flash, jolt, stars, alarm.
		task.delay(0.22, function()
			if shown ~= mine then
				return
			end
			landedAt = os.clock()
			Sounds.play("EventAlert")
			ScreenFx.flash(color, 0.32)
			ScreenFx.shake(0.6, 0.45)
			local middle = panel.AbsolutePosition + panel.AbsoluteSize / 2
			ScreenFx.stars(middle, 26, color)
			ScreenFx.stars(middle, 12, Color3.new(1, 1, 1))
			UI.pop(title, 0.35)
		end)
		task.delay(settings.Seconds, function()
			if shown ~= mine then
				return
			end
			local tween = TweenService:Create(panel, LIFT, { Position = UDim2.fromOffset(OUTLINE_ROOM, -height) })
			tween:Play()
			tween.Completed:Wait()
			if shown == mine then
				showing = false
			end
		end)
	end

	-- While it's down: the outline strobes white, ALERT blinks, the words throb and wobble.
	RunService.RenderStepped:Connect(function()
		if not showing then
			return
		end
		local now = os.clock()
		local strobe = math.floor(now * 8) % 2 == 0
		if border then
			border.Color = if strobe then Color3.new(1, 1, 1) else UI.Colors.Ink
			border.Thickness = if strobe then 4 else 3
		end
		alert.TextColor3 = if strobe then UI.Colors.Gold else Color3.new(1, 1, 1)
		local since = now - landedAt
		local kick = if since < 0.4 then (0.4 - since) * 0.25 else 0
		throb.Scale = 1 + math.sin(now * 9) * 0.015 + kick
		title.Rotation = math.sin(now * 7) * 1.5
	end)
end

return EventAlertController
