--!strict
-- Lobby panel (top left): your Cred, streak and today's challenge with a progress bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)

local ProfileHud = {}

function ProfileHud.start()
	local root = UI.root(UI.screen("ProfileHud", 2))
	local panel = UI.frame({
		Name = "Panel",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 4)
	UI.gradient(panel, 0.15)
	UI.padding(panel, 10)
	UI.list(panel, Enum.FillDirection.Vertical, 6)

	local cred = UI.pill("C", UI.Colors.Gold, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34) }, panel)
	local streak = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	local daily = UI.card(UI.Colors.Purple, {
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, panel)
	UI.padding(daily, 8)
	UI.list(daily, Enum.FillDirection.Vertical, 4)
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "TODAY'S CHALLENGE",
	}, daily)
	local challenge = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, daily)
	local bar = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = UI.Colors.PanelDark,
	}, daily)
	UI.corner(bar, 10)
	UI.stroke(bar, 2)
	local fill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Money }, bar)
	UI.corner(fill, 10)
	UI.gradient(fill, 0.25)
	local progress = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 14, ZIndex = 2 }, bar)
	local reward = UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, daily)

	local lastCred: number? = nil
	local function render(view: Types.ProfileView)
		panel.Visible = true
		cred.Text = Format.cred(view.cred)
		if lastCred and lastCred ~= view.cred then
			UI.pop(cred, 0.3)
		end
		lastCred = view.cred
		streak.Text = if view.streak > 0
			then `{view.streak}-day streak`
			else "Finish a daily challenge to start a streak"

		local today = view.daily
		challenge.Text = today.text
		local done = today.done or today.progress >= today.goal
		fill.Size = UDim2.fromScale(if done then 1 else math.clamp(today.progress / math.max(today.goal, 1), 0, 1), 1)
		progress.Text = if done then "DONE!" else `{today.progress}/{today.goal}`
		reward.Text = if today.done then "A new one tomorrow" else `Reward: {Format.cred(today.reward)}`
	end

	ProfileState.changed:Connect(render)
	if ProfileState.view then
		render(ProfileState.view)
	end
end

return ProfileHud
