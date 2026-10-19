--!strict
-- Pick a hustle: store cards in the middle of the screen a few seconds into each new quota (its
-- name, a little 3D picture in sunburst rays, what it does), springing in one after another
-- with a shine sweeping across, over a timer bar that drains (and throbs red at the end). Click one and it lasts the
-- rest of the run: it lights up and grows, the others drop away, stars fly and HUSTLE PICKED!
-- crashes in; when the timer runs out the server picks one for you. The game keeps going while
-- it's open. HustleController.closed fires when it goes, however it goes (the next quota is
-- announced then: NextQuotaController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Signal = require(Shared:WaitForChild("Signal"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local Dialogue = require(script.Parent.Dialogue)

local CARD_HEIGHT = 190
local CARD_COLORS = {
	Color3.fromRGB(150, 80, 240),
	Color3.fromRGB(230, 70, 150),
	Color3.fromRGB(40, 150, 230),
	Color3.fromRGB(240, 140, 30),
}
local SPRING = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local HustleController = {
	closed = Signal.new() :: Signal.Signal<()>,
}

local isOpen = false

function HustleController.isOpen(): boolean
	return isOpen
end

-- The hustle's little 3D picture (Config.Hustles).
local function pictureOf(id: string): string?
	for _, hustle in Config.Hustles.List do
		if hustle.id == id then
			return hustle.picture
		end
	end
	return nil
end

local function stackText(option: Types.HustleView): string
	if option.stacks > 0 then
		return `You have {option.stacks}/{option.max}`
	end
	return if option.max > 1 then `New! Stacks to {option.max}` else "New!"
end

function HustleController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Hustles", 40))

	local window = UI.window("PICK A HUSTLE", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(600, 0),
	}, root)
	local panel = window.panel
	UI.centreTitle(window)
	Cursor.registerPanel(panel)
	-- A conversation's answers would sit on top of the picker, so they wait until it's gone.
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		Dialogue.setBlocked(panel.Visible)
	end)
	UI.list(window.body, Enum.FillDirection.Vertical, 8)

	local row = UI.frame({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,
	}, window.body)
	UI.list(row, Enum.FillDirection.Horizontal, 10)

	local timeTrack, timeFill = UI.bar(UI.Colors.Gold, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 14),
	}, window.body)
	local countdown = UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = UI.Fonts.Heading,
		TextSize = 15,
	}, window.body)

	local offer: Types.HustleOffer? = nil
	local offeredAt = 0
	local cards: { [string]: Frame } = {}

	local function close()
		offer = nil
		panel.Visible = false
		if isOpen then
			isOpen = false
			HustleController.closed:Fire()
		end
	end

	-- The one they picked lights up and grows; the rest drop away; then it all goes.
	local function picked(option: Types.HustleView)
		offer = nil
		local chosen = cards[option.id]
		for id, button in cards do
			local scale = button:FindFirstChild("Spring") :: UIScale?
			if not scale then
				continue
			end
			if id == option.id then
				TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1.18,
				}):Play()
			else
				UI.tween(scale, 0.3, { Scale = 0 })
			end
		end
		if chosen then
			ScreenFx.stars(chosen.AbsolutePosition + chosen.AbsoluteSize / 2, 30, UI.Colors.Gold)
			ScreenFx.debris(
				chosen.AbsolutePosition + chosen.AbsoluteSize / 2,
				16,
				{ chosen.BackgroundColor3, UI.Colors.Gold }
			)
		end
		Sounds.play("LevelUp", 1.1)
		ScreenFx.banner("HUSTLE PICKED!", UI.Colors.Purple, option.title, 1.4)
		task.delay(0.6, close)
	end

	local function card(option: Types.HustleView, index: number, count: number)
		local color = CARD_COLORS[(index - 1) % #CARD_COLORS + 1]
		local holder, content = UI.itemCard(color, {
			Name = `Hustle{index}`,
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -10 * (count - 1) / count, 1, 0),
		}, row, 0.36)
		local spring = Instance.new("UIScale")
		spring.Name = "Spring"
		spring.Scale = 0
		spring.Parent = holder
		UI.shine(holder, 2.2 + index * 0.35, 14)
		local title = UI.label({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 28),
			FontFace = UI.Fonts.Title,
			TextScaled = true,
			Text = option.title,
		}, content)
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 24
		fit.Parent = title
		UI.textStroke(title, 3)
		local picture = pictureOf(option.id)
		if picture then
			ItemModels.viewport(picture, {
				Position = UDim2.fromOffset(10, 32),
				Size = UDim2.new(1, -20, 0, 74),
			}, content, true)
		end
		UI.label({
			Position = UDim2.fromOffset(8, 108),
			Size = UDim2.new(1, -16, 0, 50),
			FontFace = UI.Fonts.Heading,
			TextSize = 15,
			Text = option.detail,
		}, content)
		local stacks = UI.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 20),
			FontFace = UI.Fonts.Heading,
			TextSize = 15,
			TextColor3 = if option.stacks > 0 then UI.Colors.Money else Color3.fromRGB(255, 240, 160),
			Text = stackText(option),
		}, content)
		UI.textStroke(stacks, 2)
		-- The whole card is the button.
		local hit = Instance.new("TextButton")
		hit.Name = "Pick"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 6
		hit.Parent = content
		-- Each springs in a beat after the last, with a whoosh.
		task.delay(0.12 * index, function()
			TweenService:Create(spring, SPRING, { Scale = 1 }):Play()
			Sounds.play("Whoosh", 1 + index * 0.1, 0.5)
		end)
		hit.MouseEnter:Connect(function()
			if offer then
				UI.tween(spring, 0.12, { Scale = 1.06 })
			end
		end)
		hit.MouseLeave:Connect(function()
			if offer then
				UI.tween(spring, 0.12, { Scale = 1 })
			end
		end)
		hit.Activated:Connect(function()
			if offer then
				Sounds.play("Click")
				remotes.PickHustle:fire(option.id)
				picked(option)
			end
		end)
		cards[option.id] = holder
	end

	remotes.HustleOffer:onClient(function(newOffer: Types.HustleOffer?)
		for _, child in row:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		table.clear(cards)
		if not newOffer then
			close()
			return
		end
		offer = newOffer
		offeredAt = Timing.now()
		for index, option in newOffer.options do
			card(option, index, #newOffer.options)
		end
		-- Wide Options (Cred shop) offers a fourth: the window widens to fit.
		panel.Size = UDim2.fromOffset(if #newOffer.options > 3 then 760 else 600, 0)
		panel.Visible = true
		isOpen = true
		Sounds.play("Milestone", 0.9)
	end)

	RunService.RenderStepped:Connect(function()
		local current = offer
		if not current or not panel.Visible then
			return
		end
		local left = math.max(current.endsAt - Timing.now(), 0)
		local whole = math.max(current.endsAt - offeredAt, Config.Hustles.PickSeconds)
		timeFill.Size = UDim2.fromScale(math.clamp(left / whole, 0, 1), 1)
		if left < 5 then
			local beat = (math.sin(os.clock() * 12) + 1) / 2
			timeFill.BackgroundColor3 = UI.Colors.Danger:Lerp(Color3.new(1, 1, 1), beat * 0.4)
			timeTrack.Rotation = math.sin(os.clock() * 30) * 0.6
		else
			timeFill.BackgroundColor3 = UI.Colors.Gold
			timeTrack.Rotation = 0
		end
		countdown.Text = `Pick one: {Format.clock(left)}`
	end)
end

return HustleController
