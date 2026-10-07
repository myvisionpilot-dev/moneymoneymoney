--!strict
-- Announcements (Mr. Penny, town news): a drawer slides down from under the quota panel with
-- who's talking and what they say, the words typing out with soft blips, then slides back up
-- into it. They queue up and show one at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local EventAlertController = require(script.Parent.EventAlertController)
local HudController = require(script.Parent.HudController)
local NextQuotaController = require(script.Parent.NextQuotaController)

local TYPE_SECONDS = 0.025 -- per letter
local BLIP_EVERY = 3 -- letters between blips
local TUCK = 14 -- how far the drawer's top stays tucked up under the quota panel
local OUTLINE_ROOM = 4 -- room in the opening for the drawer's outline, so it isn't cut off
local PADDING = 10
local SPEAKER_HEIGHT = 16
local TEXT_SIZE = 16
local MAX_HEIGHT = 240
local MAX_QUEUE = 3 -- keep up with the game: drop the oldest beyond this
local OPEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local AnnouncementController = {}

function AnnouncementController.start()
	local root, quota = HudController.quotaPanel()
	if not root or not quota then
		return
	end
	-- The opening it slides through starts under the quota panel, which is drawn on top, and
	-- anything above the opening is cut off: so the drawer seems to come out from behind it.
	-- The drawer is as wide as the quota panel, so their outlines line up.
	local width = quota.Size.X.Offset
	local slot = UI.frame({
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, quota.Position.Y.Offset + quota.Size.Y.Offset - TUCK),
		Size = UDim2.fromOffset(width + OUTLINE_ROOM * 2, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = quota.ZIndex - 1,
	}, root)
	local drawer, content = UI.panel(UI.Colors.Panel, { Size = UDim2.fromOffset(width, MAX_HEIGHT) }, slot, MAX_HEIGHT)

	local speaker = UI.label({
		Position = UDim2.fromOffset(PADDING, TUCK + PADDING),
		Size = UDim2.new(1, -PADDING * 2, 0, SPEAKER_HEIGHT),
		FontFace = UI.Fonts.Heading,
		TextSize = 13,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Text = "",
	}, content)
	local textTop = TUCK + PADDING + SPEAKER_HEIGHT + 2
	local text = UI.label({
		Position = UDim2.fromOffset(PADDING, textTop),
		Size = UDim2.new(1, -PADDING * 2, 0, 20),
		FontFace = UI.Fonts.Serif,
		TextSize = TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	}, content)

	-- How tall the words wrap to at this width.
	local function textHeight(line: string): number
		local params = Instance.new("GetTextBoundsParams")
		params.Text = line
		params.Font = UI.Fonts.Serif
		params.Size = TEXT_SIZE
		params.Width = width - PADDING * 2
		local ok, bounds = pcall(function()
			return TextService:GetTextBoundsAsync(params)
		end)
		return if ok then math.ceil(bounds.Y) else TEXT_SIZE * 3
	end

	local function slide(y: number, info: TweenInfo)
		local tween = TweenService:Create(drawer, info, { Position = UDim2.fromOffset(OUTLINE_ROOM, y) })
		tween:Play()
		tween.Completed:Wait()
	end

	local queue: { Types.Announcement } = {}
	local showing = false

	local function show(announcement: Types.Announcement)
		-- An event ALERT has the spot under the quota panel; and after a quota's paid, Mr. Penny
		-- waits until you've picked your hustle and seen the next quota. (A moment first, so the
		-- news that a quota started has caught up with the line about it.)
		task.wait(0.3)
		while EventAlertController.showing() or NextQuotaController.holding() do
			task.wait(0.2)
		end
		local line = announcement.text
		local wordsHeight = textHeight(line)
		local height = math.min(textTop + wordsHeight + PADDING + 2, MAX_HEIGHT)
		speaker.Text = announcement.speaker
		text.Size = UDim2.new(1, -PADDING * 2, 0, wordsHeight + 2)
		text.Text = line
		text.MaxVisibleGraphemes = 0
		slot.Size = UDim2.fromOffset(width + OUTLINE_ROOM * 2, height + OUTLINE_ROOM)
		drawer.Size = UDim2.fromOffset(width, height)
		drawer.Position = UDim2.fromOffset(OUTLINE_ROOM, -height)
		slide(0, OPEN)
		local length = utf8.len(line) or #line
		for shown = 1, length do
			text.MaxVisibleGraphemes = shown
			if shown % BLIP_EVERY == 0 then
				Sounds.play("Click", 1.5 + math.random() * 0.3, 0.35)
			end
			task.wait(TYPE_SECONDS)
		end
		text.MaxVisibleGraphemes = -1
		task.wait(math.clamp(#line / 15, 3.5, 7))
		slide(-height, CLOSE)
	end

	local function run()
		showing = true
		while #queue > 0 do
			show(table.remove(queue, 1) :: Types.Announcement)
			task.wait(0.15)
		end
		showing = false
	end

	Remotes.match().Announce:onClient(function(announcement: Types.Announcement)
		table.insert(queue, announcement)
		if #queue > MAX_QUEUE then
			table.remove(queue, 1)
		end
		if not showing then
			task.spawn(run)
		end
	end)
end

return AnnouncementController
