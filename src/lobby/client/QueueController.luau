--!strict
-- Shows the queue panel (count, countdown, Leave button) while you stand on a pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local QueueController = {}

function QueueController.start()
	local remotes = Remotes.lobby()
	local status: Types.QueueStatus? = nil

	local root = UI.root(UI.screen("Queue", 5))
	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(300, 110),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	UI.corner(panel, 14)
	UI.stroke(panel, 3, UI.Colors.Gold)

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
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 18,
	}, panel)

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

	remotes.QueueStatus:onClient(function(newStatus: Types.QueueStatus?)
		status = newStatus
		panel.Visible = newStatus ~= nil
	end)

	remotes.Notify:onClient(function(notice: Types.Notice)
		Toasts.show(notice.text, notice.kind)
	end)

	RunService.RenderStepped:Connect(function()
		local current = status
		if current then
			local left = current.departsAt - Timing.now()
			info.Text = `{current.count}/{current.max} players  ·  leaving in {Format.clock(left)}`
		end
	end)
end

return QueueController
