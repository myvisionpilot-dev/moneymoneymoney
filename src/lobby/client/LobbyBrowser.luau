--!strict
-- FIND A LOBBY (PLAY, then WITH OTHERS): every lobby waiting for players, with who's hosting,
-- how full it is and when it leaves, and a JOIN button each; or HOST A LOBBY to open your own
-- for others to find. The list updates as lobbies open, fill and leave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local QueueController = require(script.Parent.QueueController)
local ShopFrame = require(script.Parent.ShopFrame)

local WIDTH = 520
local ROW_WIDTH = 462 -- the list's inside, less its scroll bar
local ROW_HEIGHT = 60
local LIST_HEIGHT = 250

type Row = { listing: Types.GroupListing, detail: TextLabel }

local LobbyBrowser = {}

function LobbyBrowser.start(root: Frame): UI.Window
	local window = UI.window("FIND A LOBBY", {
		Name = "LobbyBrowser",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(WIDTH, 0),
	}, root, true)
	window.title.TextSize = 24
	Cursor.registerPanel(window.panel)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		Text = "Join a lobby that's waiting for players, or host your own.",
	}, window.body)
	local list = ShopFrame.scroller({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, LIST_HEIGHT) }, window.body)
	UI.padding(list, 4)
	UI.list(list, Enum.FillDirection.Vertical, 6)
	local empty = UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Text = "No lobbies open right now. Host one and others can join you!",
	}, window.body)
	local host = UI.button({
		Name = "Host",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = UI.Colors.Gold,
		TextSize = 24,
		Text = "HOST A LOBBY",
	}, window.body)
	host.Activated:Connect(function()
		window.panel.Visible = false
		QueueController.play({ mode = "Host" })
	end)

	local rows: { Row } = {}

	local function row(order: number, listing: Types.GroupListing)
		local _, content = UI.panel(UI.Colors.Panel, {
			Name = `Lobby{listing.id}`,
			LayoutOrder = order,
			Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
		}, list, ROW_HEIGHT)
		UI.label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -140, 0, 24),
			FontFace = UI.Fonts.Heading,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			Text = `{listing.hostName}'s lobby`,
		}, content)
		local detail = UI.label({
			Position = UDim2.fromOffset(12, 31),
			Size = UDim2.new(1, -140, 0, 20),
			FontFace = UI.Fonts.Number,
			TextSize = 15,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		}, content)
		local join = UI.button({
			Name = "Join",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 22,
			Text = "JOIN",
		}, content)
		join.Activated:Connect(function()
			window.panel.Visible = false
			QueueController.play({ mode = "Join", group = listing.id })
		end)
		table.insert(rows, { listing = listing, detail = detail })
	end

	local function render(listings: { Types.GroupListing })
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(rows)
		for order, listing in listings do
			row(order, listing)
		end
		empty.Visible = #listings == 0
		list.Visible = #listings > 0
	end

	QueueController.groupsChanged:Connect(render)
	render(QueueController.groups)

	RunService.RenderStepped:Connect(function()
		if not window.panel.Visible then
			return
		end
		for _, entry in rows do
			local listing = entry.listing
			local left = math.max(listing.departsAt - Timing.now(), 0)
			entry.detail.Text = `{listing.count}/{listing.partySize} players  ·  leaves in {Format.clock(left)}`
		end
	end)
	return window
end

return LobbyBrowser
