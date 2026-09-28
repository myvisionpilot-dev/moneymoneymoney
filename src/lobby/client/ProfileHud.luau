--!strict
-- Lobby panel (top left): your Cred, streak and today's challenge.

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
		BackgroundTransparency = 0.15,
		Visible = false,
	}, root)
	UI.corner(panel, 14)
	UI.stroke(panel, 3)
	UI.padding(panel, 10)
	UI.list(panel, Enum.FillDirection.Vertical, 4)

	local function line(order: number, size: number, color: Color3?, font: Enum.Font?): TextLabel
		return UI.label({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = size,
			Font = font or UI.Fonts.Body,
			TextColor3 = color or UI.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, panel)
	end
	local cred = line(1, 26, UI.Colors.Gold, UI.Fonts.Heading)
	UI.textStroke(cred)
	local streak = line(2, 15, UI.Colors.Muted)
	local challengeTitle = line(3, 14, UI.Colors.Muted)
	challengeTitle.Text = "TODAY'S CHALLENGE"
	local challenge = line(4, 17)
	local progress = line(5, 15, UI.Colors.Money)

	local function render(view: Types.ProfileView)
		panel.Visible = true
		cred.Text = Format.cred(view.cred)
		streak.Text = if view.streak > 0
			then `Streak: {view.streak} day{if view.streak == 1 then "" else "s"} in a row`
			else "Finish a daily challenge to start a streak"
		challenge.Text = view.daily.text
		if view.daily.done then
			progress.Text = "Done! A new one tomorrow."
		else
			progress.Text = `{view.daily.progress}/{view.daily.goal} · +{Format.cred(view.daily.reward)}`
		end
	end

	ProfileState.changed:Connect(render)
	if ProfileState.view then
		render(ProfileState.view)
	end
end

return ProfileHud
