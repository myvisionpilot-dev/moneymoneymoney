--!strict
-- The lobby's corners:
--   top left     your streak and today's challenge with a progress bar, and under them the
--                lime glitter Shop button (a cart and "Shop")
--   bottom left  your Cred: a big gold coin and the amount, with a + that opens the Shop too
-- MenuBar wires both buttons to the Shop window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)

local WIDTH = 250

local ProfileHud = {}

export type Buttons = { shop: TextButton, plus: TextButton }

function ProfileHud.start(): Buttons
	local root = UI.root(UI.screen("ProfileHud", 2))
	local column = UI.frame({
		Name = "Column",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, root)
	UI.list(column, Enum.FillDirection.Vertical, 10)
	local holder, panel = UI.panel(UI.Colors.Panel, {
		Name = "Panel",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, column)
	UI.padding(panel, 10)
	UI.list(panel, Enum.FillDirection.Vertical, 6)
	-- See-through like the windows: the bank shows behind it.
	holder.BackgroundColor3 = StoreKit.Colors.Body
	holder.BackgroundTransparency = StoreKit.BODY_TRANSPARENCY
	for _, name in { "Checker", "Rim" } do
		local child = holder:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end

	local shop = StoreKit.glitterIconButton("Shop", StoreKit.Images.Cart, StoreKit.Glitter.Lime, {
		Name = "Shop",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 80),
	}, column)
	Cursor.registerPanel(shop)

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

	-- Your Cred, bottom left: the coin with a little + on it, and the amount big in gold italics.
	local credRow = UI.frame({
		Name = "Cred",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -14),
		Size = UDim2.fromOffset(0, 66),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, root)
	local coin = StoreKit.image(StoreKit.Images.CredCoin, {
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.fromOffset(0, 2),
	}, credRow)
	local plus = StoreKit.button({
		Name = "Plus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(56, 52),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = StoreKit.Colors.Gold,
		TextSize = 26,
		Text = "+",
		ZIndex = 3,
	}, credRow)
	Cursor.registerPanel(plus)
	local cred = StoreKit.label({
		Position = UDim2.fromOffset(76, 4),
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = StoreKit.Fonts.BlackItalic,
		TextSize = 46,
		TextColor3 = StoreKit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, credRow)
	UI.textStroke(cred, 4)

	local lastCred: number? = nil
	local function render(view: Types.ProfileView)
		holder.Visible = true
		UI.roll(cred, view.cred, Format.number, 0.8) -- rolls up (or down, after you spend it)
		if lastCred and lastCred ~= view.cred then
			UI.pop(cred, 0.25)
			UI.pop(coin, 0.25)
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
	return { shop = shop, plus = plus }
end

return ProfileHud
