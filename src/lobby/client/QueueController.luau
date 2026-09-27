--!strict
-- The queue panel while you stand on a pad: count, countdown, party size picker and Leave.
-- The host (first on the pad) taps 1-6 to set the party size; everyone else sees their choice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local SIZE_BUTTON = 42
local SIZE_GAP = 8

local QueueController = {}

function QueueController.start()
	local remotes = Remotes.lobby()
	local status: Types.QueueStatus? = nil

	local root = UI.root(UI.screen("Queue", 5))
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(330, 180),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	UI.corner(panel, 14)
	UI.stroke(panel, 3, UI.Colors.Gold)
	FirstPerson.registerPanel(panel)

	local title = UI.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 28),
		Font = UI.Fonts.Heading,
		TextSize = 24,
		TextColor3 = UI.Colors.Gold,
		Text = "HEADING TO TONY'S",
	}, panel)
	UI.textStroke(title)

	local info = UI.label({
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 20),
		TextSize = 17,
	}, panel)

	local hint = UI.label({
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
	}, panel)

	-- Party size buttons 1..MaxPlayers
	local maxPlayers = Config.Match.MaxPlayers
	local rowWidth = maxPlayers * SIZE_BUTTON + (maxPlayers - 1) * SIZE_GAP
	local row = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(rowWidth, SIZE_BUTTON),
		BackgroundTransparency = 1,
	}, panel)
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
			local current = status
			if current and current.isHost and size >= current.count then
				remotes.SetPartySize:fire(size)
			end
		end)
		sizeButtons[size] = button
	end

	local leave = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(160, 40),
		BackgroundColor3 = UI.Colors.Danger,
		Text = "LEAVE",
	}, panel)
	leave.Activated:Connect(function()
		remotes.LeaveQueue:fire(nil)
	end)

	local function renderSizes(current: Types.QueueStatus)
		hint.Text = if current.isHost
			then "You're the host: pick the party size"
			else `{current.hostName} picks the party size`
		for size, button in sizeButtons do
			local selected = size == current.partySize
			local allowed = current.isHost and size >= current.count
			button.Active = allowed
			button.AutoButtonColor = allowed
			button.BackgroundColor3 = if selected then UI.Colors.Gold else UI.Colors.PanelLight
			button.TextColor3 = if selected then UI.Colors.Panel else UI.Colors.Text
			button.BackgroundTransparency = if selected or allowed then 0 else 0.6
			button.TextTransparency = if selected or allowed then 0 else 0.5
		end
	end

	remotes.QueueStatus:onClient(function(newStatus: Types.QueueStatus?)
		status = newStatus
		panel.Visible = newStatus ~= nil
		if newStatus then
			renderSizes(newStatus)
		end
	end)

	remotes.Notify:onClient(function(notice: Types.Notice)
		Toasts.show(notice.text, notice.kind)
	end)

	RunService.RenderStepped:Connect(function()
		local current = status
		if current then
			local left = current.departsAt - Timing.now()
			info.Text = `{current.count}/{current.partySize} players  ·  leaving in {Format.clock(left)}`
		end
	end)
end

return QueueController
