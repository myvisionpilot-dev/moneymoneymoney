--!strict
-- The BOOSTS window (the gold Boosts button under the Shop), in the store look: two big cards for
-- the rewards that last for good (serverCommon/Social, Config.Social):
--   INVITE A FRIEND   Roblox's invite screen; once a friend you invited joins, +10% Cred
--   JOIN THE GROUP    Roblox's join-group prompt; once you're in, +30% Cred and +30% Luck
-- Each card's glitter button says ACTIVE (gold, shining) once its reward is yours.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local StoreFx = require(Shared:WaitForChild("StoreFx"))
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local UI = require(Shared:WaitForChild("UI"))
local ShopFrame = require(script.Parent.ShopFrame)

local WIDTH = 720
local CARD_HEIGHT = 330
local GAP = 14

local settings = Config.Social

local BoostsWindow = {}

local player = Players.LocalPlayer

local function groupId(): number
	if settings.GroupId > 0 then
		return settings.GroupId
	end
	return if game.CreatorType == Enum.CreatorType.Group then game.CreatorId else 0
end

local function invite()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not ok or not can then
		Sounds.play("Fail", 1, 0.6)
		Toasts.show("Invites aren't available right now", "Info")
		return
	end
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "Come make MONEY MONEY MONEY with me!"
	options.LaunchData = `invite:{player.UserId}`
	pcall(function()
		SocialService:PromptGameInvite(player, options)
	end)
end

local function joinGroup()
	local id = groupId()
	if id <= 0 then
		Toasts.show("No group yet!", "Info")
		return
	end
	task.spawn(function()
		pcall(function()
			GroupService:PromptJoinAsync(id)
		end)
		Remotes.lobby().CheckGroup:fire(nil) -- did they join? the server looks again
	end)
end

type Card = { button: TextButton, label: TextLabel, status: TextLabel }

function BoostsWindow.start(root: Frame): UI.Window
	local window = StoreKit.window("Boosts", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShopFrame.BAR_SPACE),
		Size = UDim2.fromOffset(WIDTH, 0),
	}, root)
	Cursor.registerPanel(window.panel)
	StoreKit.image(StoreKit.Images.InviteFriend, { Size = UDim2.fromScale(1, 1) }, window.icon)
	local fx = StoreFx.new(window.panel, window.body)
	fx.shimmer(window.title)

	local list = UI.frame(
		{ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 },
		window.body
	)
	UI.list(list, Enum.FillDirection.Vertical, GAP)
	local note = StoreKit.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 22,
		TextColor3 = StoreKit.Colors.Gold,
		Text = "Boosts that last forever!",
	}, list)
	UI.textStroke(note, 3)
	fx.shimmer(note)
	local row = StoreKit.row(2, CARD_HEIGHT, GAP, list)

	local function card(
		color: Color3,
		picture: string,
		title: string,
		reward: string,
		how: string,
		action: string,
		onPress: () -> ()
	): Card
		local frame, content = StoreKit.card(color, {
			Size = UDim2.new(0.5, -GAP / 2, 1, 0),
		}, row, Vector2.new(0.5, 0.32), CARD_HEIGHT * 1.6)
		fx.lift(frame)
		fx.twinkle(frame, 6, "white")
		fx.burst(frame, Vector2.new(0.5, 0.32), "gold")
		UI.shine(frame, 3.6 + math.random(), 8)
		local art = StoreKit.image(StoreKit.art(picture), {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(152, 152),
			ZIndex = 3,
		}, content)
		fx.float(art)
		local heading = StoreKit.label({
			Position = UDim2.fromOffset(8, 156),
			Size = UDim2.new(1, -16, 0, 40),
			TextSize = 32,
			Text = title,
			ZIndex = 4,
		}, content)
		UI.textStroke(heading, 3.5)
		local line = StoreKit.label({
			Position = UDim2.fromOffset(8, 196),
			Size = UDim2.new(1, -16, 0, 30),
			FontFace = StoreKit.Fonts.ExtraBold,
			TextSize = 24,
			RichText = true,
			Text = StoreKit.highlight(reward),
			ZIndex = 4,
		}, content)
		UI.textStroke(line, 2.5)
		local status = StoreKit.label({
			Position = UDim2.fromOffset(8, 226),
			Size = UDim2.new(1, -16, 0, 22),
			TextSize = 16,
			TextColor3 = Color3.fromRGB(235, 240, 255),
			Text = how,
			ZIndex = 4,
		}, content)
		local button = StoreKit.glitterButton(StoreKit.Glitter.Lime, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -28, 0, 60),
			ZIndex = 5,
		}, content)
		local label = StoreKit.glitterText(button, {
			Size = UDim2.new(1, 0, 1, -3),
			TextSize = 32,
			Text = action,
		})
		UI.shine(button, 2.6 + math.random(), 12)
		fx.wiggle(button)
		button.Activated:Connect(onPress)
		return { button = button, label = label, status = status }
	end

	local inviteCard = card(
		Color3.fromRGB(30, 140, 255),
		"InviteFriend",
		"INVITE A FRIEND",
		`[+{Format.percent(settings.InviteCred)}] Cred forever!`,
		"When a friend you invite joins",
		"INVITE",
		invite
	)
	local groupCard = card(
		Color3.fromRGB(150, 60, 240),
		"GroupJoin",
		"JOIN THE GROUP",
		`[+{Format.percent(settings.GroupCred)}] Cred + [+{Format.percent(settings.GroupLuck)}] Luck!`,
		"Join, then this turns on",
		"JOIN GROUP",
		joinGroup
	)

	local function render()
		local referred = player:GetAttribute("Referred") == true
		local member = player:GetAttribute("InGroup") == true
		local function show(which: Card, on: boolean, off: string, active: string)
			StoreKit.glitterPaint(which.button, if on then StoreKit.Glitter.Gold else StoreKit.Glitter.Lime)
			which.label.Text = if on then active else off
		end
		show(inviteCard, referred, "INVITE", "ACTIVE! Invite more")
		show(groupCard, member, "JOIN GROUP", "ACTIVE!")
		inviteCard.status.Text = if referred
			then "Your friend joined: it's yours for good"
			else "When a friend you invite joins"
		groupCard.status.Text = if member then "Thanks for joining!" else "Join, then this turns on"
	end
	render()
	player.AttributeChanged:Connect(function(name: string)
		if name == "Referred" or name == "InGroup" then
			local was = inviteCard.label.Text
			render()
			if window.panel.Visible and was ~= inviteCard.label.Text then
				Sounds.play("Fanfare")
			end
		end
	end)
	-- Opening it looks again, in case they joined the group on the website.
	window.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.panel.Visible then
			Remotes.lobby().CheckGroup:fire(nil)
		end
	end)
	return window
end

return BoostsWindow
