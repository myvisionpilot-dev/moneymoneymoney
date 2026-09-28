--!strict
-- Tony's upgrade shop: opens from the counter in his office. Paid from the cash in your bag.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COUNTER_TAG = "ShopCounter"
local CLOSE_SLACK = 6

local ShopController = {}

function ShopController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Shop", 45))

	local panel = UI.frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, root)
	UI.corner(panel, 16)
	UI.stroke(panel, 3, UI.Colors.Gold)
	UI.padding(panel, 14)
	FirstPerson.registerPanel(panel)
	UI.list(panel, Enum.FillDirection.Vertical, 8)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = UI.Fonts.Heading,
		TextSize = 28,
		TextColor3 = UI.Colors.Gold,
		Text = "TONY'S UPGRADES",
	}, panel)
	UI.textStroke(title)
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		Text = "Paid from your bag, never your deposits. Upgrades last this run.",
	}, panel)

	local list = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, panel)
	UI.list(list, Enum.FillDirection.Vertical, 8)

	local close = UI.button({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(140, 40),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "Close",
	}, panel)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local function itemRow(item: Types.ShopItem, carried: number)
		local rowFrame = UI.frame({
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = UI.Colors.PanelLight,
		}, list)
		UI.corner(rowFrame, 10)
		UI.label({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -170, 0, 22),
			Font = UI.Fonts.Heading,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{item.title}  (level {item.level}/{item.maxLevel})`,
		}, rowFrame)
		UI.label({
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -170, 0, 20),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = if item.nextEffect then `{item.current}  →  {item.nextEffect}` else `{item.current} (max)`,
		}, rowFrame)

		local price = item.nextPrice
		local affordable = price ~= nil and carried >= price
		local buy = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = if affordable then UI.Colors.Money else UI.Colors.PanelLight,
			TextSize = 18,
			Text = if price then `BUY {Format.money(price)}` else "MAXED",
		}, rowFrame)
		buy.AutoButtonColor = affordable
		buy.Activated:Connect(function()
			if price then
				remotes.BuyUpgrade:fire(item.id)
			end
		end)
	end

	remotes.ShopOpen:onClient(function(state: Types.ShopState)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local me = ClientState.me()
		local carried = if me then me.carried else 0
		for _, item in state.items do
			itemRow(item, carried)
		end
		panel.Visible = true
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase == "Results" or snapshot.phase == "Ended" then
			panel.Visible = false
		end
	end)

	-- Walking away from the counter closes the shop.
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if not panel.Visible or not character then
			return
		end
		local position = character:GetPivot().Position
		for _, counter in CollectionService:GetTagged(COUNTER_TAG) do
			if
				counter:IsA("BasePart")
				and (counter.Position - position).Magnitude <= Config.Shop.RangeStuds + CLOSE_SLACK
			then
				return
			end
		end
		panel.Visible = false
	end)
end

return ShopController
