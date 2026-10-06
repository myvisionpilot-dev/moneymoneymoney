--!strict
-- The queue panel while you stand on a pad: count, countdown, party size picker and Leave.
-- The host (first on the pad) taps 1-6 to set the party size; everyone else sees their choice.
-- Beeps through the last few seconds before the van leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local SIZE_BUTTON = 42
local SIZE_GAP = 8
local BEEP_SECONDS = 5

local QueueController = {}

function QueueController.start()
	local remotes = Remotes.lobby()
	local status: Types.QueueStatus? = nil

	local root = UI.root(UI.screen("Queue", 5))
	local window = UI.window("HEADING TO TOWN", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(360, 0),
	}, root)
	local panel = window.panel
	window.title.TextSize = 24
	Cursor.registerPanel(panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 6)

	local info = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 18,
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
			local current = status
			if current and current.isHost and size >= current.count then
				remotes.SetPartySize:fire(size)
			end
		end)
		sizeButtons[size] = button
	end

	local leave = UI.button({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(170, 40),
		BackgroundColor3 = UI.Colors.Danger,
		Text = "LEAVE",
	}, window.body)
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
			button.BackgroundColor3 = if selected
				then UI.Colors.Gold
				elseif allowed then UI.Colors.Panel
				else UI.Colors.Grey
			button.BackgroundTransparency = if selected or allowed then 0 else 0.4
		end
	end

	local lastCount = -1
	remotes.QueueStatus:onClient(function(newStatus: Types.QueueStatus?)
		status = newStatus
		panel.Visible = newStatus ~= nil
		if newStatus then
			if lastCount >= 0 and newStatus.count > lastCount then
				Sounds.play("Ding")
			end
			lastCount = newStatus.count
			renderSizes(newStatus)
		else
			lastCount = -1
		end
	end)

	remotes.Notify:onClient(function(notice: Types.Notice)
		Toasts.show(notice.text, notice.kind)
	end)

	local lastSecond = -1
	RunService.RenderStepped:Connect(function()
		local current = status
		if not current then
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
