--!strict
-- Heading to town after PLAY: asks the server to go solo, host a lobby or join one, and keeps
-- the lobby you're in (QueueController.status, .changed) and the list of lobbies you could join
-- (QueueController.groups, .groupsChanged). While you're waiting in a lobby, a panel above the
-- menu bar shows who's in and the countdown; the host also gets the party size buttons (tap
-- 1-6) and START NOW. Beeps through the last few seconds before the lobby leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ShopFrame = require(script.Parent.ShopFrame)

local SIZE_BUTTON = 42
local SIZE_GAP = 8
local BEEP_SECONDS = 5

local QueueController = {
	status = nil :: Types.QueueStatus?,
	changed = Signal.new() :: Signal.Signal<Types.QueueStatus?>,
	groups = {} :: { Types.GroupListing },
	groupsChanged = Signal.new() :: Signal.Signal<{ Types.GroupListing }>,
}

local panel: GuiObject? = nil
local hidden = false

local function refresh()
	if panel then
		local status = QueueController.status
		panel.Visible = status ~= nil and not status.leaving and status.partySize > 1 and not hidden
	end
end

function QueueController.play(request: Types.PlayRequest)
	Remotes.lobby().Play:fire(request)
end

function QueueController.leave()
	Remotes.lobby().LeaveQueue:fire(nil)
end

-- The group panel stays out of the way while a shop window is open.
function QueueController.setHidden(hide: boolean)
	hidden = hide
	refresh()
end

-- Seconds until your group leaves (0 if you're not in one).
function QueueController.secondsLeft(): number
	local status = QueueController.status
	return if status then math.max(status.departsAt - Timing.now(), 0) else 0
end

function QueueController.start(root: Frame)
	local remotes = Remotes.lobby()

	local window = UI.window("HEADING TO TOWN", {
		Name = "Queue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(380, 0),
	}, root)
	panel = window.panel
	window.title.TextSize = 24
	Cursor.registerPanel(window.panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 6)

	local info = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = UI.Fonts.Number,
		TextSize = 19,
	}, window.body)
	local hint = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
	}, window.body)

	-- Party size buttons 1..MaxPlayers
	local maxPlayers = Config.Match.MaxPlayers
	local row = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(maxPlayers * SIZE_BUTTON + (maxPlayers - 1) * SIZE_GAP, SIZE_BUTTON),
		BackgroundTransparency = 1,
	}, window.body)
	UI.list(row, Enum.FillDirection.Horizontal, SIZE_GAP)

	local sizeButtons: { TextButton } = {}
	for size = 1, maxPlayers do
		local button = UI.button({
			LayoutOrder = size,
			Size = UDim2.fromOffset(SIZE_BUTTON, SIZE_BUTTON),
			Text = tostring(size),
			TextSize = 22,
		}, row)
		button.Activated:Connect(function()
			local current = QueueController.status
			if current and current.isHost and size >= current.count then
				remotes.SetPartySize:fire(size)
			end
		end)
		sizeButtons[size] = button
	end

	-- The host can leave with whoever's in.
	local startNow = UI.button({
		Name = "StartNow",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = UI.Colors.Money,
		Text = "START NOW",
	}, window.body)
	startNow.Activated:Connect(function()
		local current = QueueController.status
		if current and current.isHost then
			remotes.SetPartySize:fire(math.max(current.count, Config.Match.MinPlayers))
		end
	end)

	local function renderSizes(current: Types.QueueStatus)
		hint.Text = if current.isHost
			then "Your lobby: pick how many to wait for, or start now"
			else `{current.hostName}'s lobby: they pick the size and when to go`
		for size, button in sizeButtons do
			local selected = size == current.partySize
			local allowed = current.isHost and size >= current.count
			button.Active = allowed
			button.AutoButtonColor = allowed
			button.BackgroundColor3 = if selected
				then UI.Colors.Gold
				elseif allowed then UI.Colors.Panel
				else UI.Colors.Grey
			button.BackgroundTransparency = if selected or allowed then 0 else 0.4
		end
		startNow.Visible = current.isHost
	end

	remotes.QueueStatus:onClient(function(status: Types.QueueStatus?)
		QueueController.status = status
		if status then
			renderSizes(status)
		end
		refresh()
		QueueController.changed:Fire(status)
	end)

	remotes.GroupList:onClient(function(list: { Types.GroupListing })
		QueueController.groups = list
		QueueController.groupsChanged:Fire(list)
	end)

	remotes.Notify:onClient(function(notice: Types.Notice)
		Toasts.show(notice.text, notice.kind)
	end)

	local lastSecond = -1
	RunService.RenderStepped:Connect(function()
		local current = QueueController.status
		if not current or current.leaving then
			return
		end
		local left = current.departsAt - Timing.now()
		info.Text = `{current.count}/{current.partySize} players  ·  leaving in {Format.clock(left)}`
		local second = math.ceil(left)
		if second ~= lastSecond and second > 0 and second <= BEEP_SECONDS then
			Sounds.play("Beep", 1.2)
			UI.pop(info, 0.12)
		end
		lastSecond = second
	end)
end

return QueueController
