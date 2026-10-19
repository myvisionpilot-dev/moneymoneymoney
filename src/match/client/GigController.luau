--!strict
-- Your phone (client): when a gig comes in (Paths/PhoneGigs) it slides up from the bottom right
-- (the right side on touch screens, above the jump button), ringing and wobbling: INCOMING GIG,
-- a little 3D picture of the job in light rays, what to do, the pay and a bar running out until
-- it stops ringing. ACCEPT (or G) takes it; IGNORE lets it go. While you're on it the job guide
-- shows the way and the phone tucks away. At the end it pops back up: GIG DONE! with the pay and
-- the speed bonus (stars and confetti), or GIG LOST and why.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local PHONE = Vector2.new(196, 318)
local RING_EVERY = 1.4
local DONE_SECONDS = 3.2
local LOST_SECONDS = 2.6
local PICTURES: { [Types.GigKind]: string } = { Parcel = "Parcel", Cat = "Cat", Photo = "Camera", Litter = "Trash" }
local TOUCH = UserInputService.TouchEnabled
local SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TUCK = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local GigController = {}

function GigController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Phone", 47))

	-- Where it sits when it's up, and tucked away off screen.
	local shownAt = if TOUCH then UDim2.new(1, -12, 0.5, -10) else UDim2.new(1, -14, 1, -14)
	local hiddenAt = if TOUCH then UDim2.new(1, PHONE.X + 30, 0.5, -10) else UDim2.new(1, -14, 1, PHONE.Y + 40)
	local phone = UI.frame({
		Name = "Phone",
		AnchorPoint = if TOUCH then Vector2.new(1, 0.5) else Vector2.new(1, 1),
		Position = hiddenAt,
		Size = UDim2.fromOffset(PHONE.X, PHONE.Y),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	}, root)
	UI.corner(phone, 28)
	UI.stroke(phone, 4)
	UI.gradient(phone, 0.3)
	Cursor.registerPanel(phone)
	if TOUCH then
		local small = Instance.new("UIScale")
		small.Scale = 0.85
		small.Parent = phone
	end

	local screen = UI.frame({
		Name = "Screen",
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 1, -42),
		BackgroundColor3 = UI.Colors.Info,
		ClipsDescendants = false,
	}, phone)
	UI.corner(screen, 18)
	UI.stroke(screen, 2.5)
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 110, 230))
	tint.Parent = screen
	UI.checker(screen, 10, 18)
	-- The notch and the home bar.
	local notch = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(60, 10),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		ZIndex = 3,
	}, phone)
	UI.corner(notch, 5)
	local homeBar = UI.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.fromOffset(64, 5),
		BackgroundColor3 = Color3.fromRGB(200, 200, 210),
	}, phone)
	UI.corner(homeBar, 3)

	local header = UI.label({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 24),
		FontFace = UI.Fonts.Title,
		TextSize = 20,
		Text = "INCOMING GIG",
		ZIndex = 4,
	}, screen)
	UI.textStroke(header, 2.5)
	local art = UI.frame({
		Position = UDim2.fromOffset(6, 32),
		Size = UDim2.new(1, -12, 0, 92),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, screen)
	UI.rays(art, 300, Color3.fromRGB(255, 240, 200), 14)
	local title = UI.label({
		Position = UDim2.fromOffset(6, 126),
		Size = UDim2.new(1, -12, 0, 26),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
		TextColor3 = UI.Colors.Gold,
		ZIndex = 4,
	}, screen)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 24
	fit.Parent = title
	UI.textStroke(title, 2.6)
	local detail = UI.label({
		Position = UDim2.fromOffset(8, 154),
		Size = UDim2.new(1, -16, 0, 52),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 4,
	}, screen)
	local payLine = UI.label({
		Position = UDim2.fromOffset(6, 206),
		Size = UDim2.new(1, -12, 0, 24),
		FontFace = UI.Fonts.Number,
		TextSize = 20,
		TextColor3 = UI.Colors.Money,
		ZIndex = 4,
	}, screen)
	UI.textStroke(payLine, 2.4)
	local answerTrack, answerFill = UI.bar(UI.Colors.Gold, {
		Position = UDim2.fromOffset(10, 232),
		Size = UDim2.new(1, -20, 0, 8),
		ZIndex = 4,
	}, screen)
	local ignore = UI.button({
		Position = UDim2.new(0, 6, 1, -40),
		Size = UDim2.new(0.42, -6, 0, 34),
		BackgroundColor3 = UI.Colors.Danger,
		TextSize = 15,
		Text = "IGNORE",
		ZIndex = 5,
	}, screen)
	local accept = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 1, -40),
		Size = UDim2.new(0.58, -6, 0, 34),
		BackgroundColor3 = UI.Colors.Money,
		TextSize = 17,
		Text = if TOUCH then "ACCEPT" else "ACCEPT (G)",
		ZIndex = 5,
	}, screen)
	UI.shine(accept, 1.6, 12)

	local current: Types.GigView? = nil
	local ringingSince = 0
	local lastRing = 0
	local hideAt = 0
	local up = false

	local function slide(show: boolean)
		if show == up then
			return
		end
		up = show
		if show then
			phone.Visible = true
			phone.Position = hiddenAt
			TweenService:Create(phone, SLIDE, { Position = shownAt }):Play()
		else
			local tween = TweenService:Create(phone, TUCK, { Position = hiddenAt })
			tween.Completed:Once(function()
				if not up then
					phone.Visible = false
				end
			end)
			tween:Play()
		end
	end

	local function picture(kind: Types.GigKind)
		for _, child in art:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		ItemModels.viewport(PICTURES[kind], { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, art, true)
	end

	local function answer(yes: boolean)
		local gig = current
		if gig and gig.state == "Offer" then
			remotes.GigAnswer:fire({ id = gig.id, accept = yes })
			if yes then
				Sounds.play("Purchase", 1.2, 0.7)
				UI.pop(accept, 0.2)
			end
		end
	end
	accept.Activated:Connect(function()
		answer(true)
	end)
	ignore.Activated:Connect(function()
		answer(false)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.G and not UserInputService:GetFocusedTextBox() then
			answer(true)
		end
	end)

	local function showOffer(gig: Types.GigView)
		header.Text = "INCOMING GIG"
		header.TextColor3 = UI.Colors.Text
		title.Text = gig.title
		detail.Text = gig.detail
		payLine.Text = `{Format.money(gig.pay)} + speed bonus`
		payLine.TextColor3 = UI.Colors.Money
		answerTrack.Visible = true
		accept.Visible = true
		ignore.Visible = true
		picture(gig.kind)
		ringingSince = Timing.now()
		lastRing = 0
		slide(true)
	end

	local function showEnd(gig: Types.GigView)
		answerTrack.Visible = false
		accept.Visible = false
		ignore.Visible = false
		phone.Rotation = 0
		picture(gig.kind)
		title.Text = gig.title
		if gig.state == "Done" then
			local bonus = gig.bonus or 0
			header.Text = "GIG DONE!"
			header.TextColor3 = UI.Colors.Gold
			payLine.Text = `+{Format.money(gig.pay + bonus)}`
			payLine.TextColor3 = UI.Colors.Money
			detail.Text = if bonus > 0 then `Speed bonus: +{Format.money(bonus)}!` else "Done! Just in time."
			hideAt = os.clock() + DONE_SECONDS
			slide(true)
			task.delay(0.35, function()
				local middle = phone.AbsolutePosition + phone.AbsoluteSize / 2
				ScreenFx.stars(middle, 22, UI.Colors.Gold)
				ScreenFx.debris(middle, 14, { UI.Colors.Money, UI.Colors.Gold, Color3.new(1, 1, 1) })
				UI.pop(screen, 0.12)
			end)
			Sounds.play("Milestone", 1.1)
		else
			header.Text = "GIG LOST"
			header.TextColor3 = UI.Colors.Danger
			payLine.Text = ""
			detail.Text = gig.detail
			hideAt = os.clock() + LOST_SECONDS
			slide(true)
			Sounds.play("Fail", 1.2, 0.6)
		end
	end

	remotes.Gig:onClient(function(gig: Types.GigView?)
		current = gig
		hideAt = 0
		if gig and gig.state == "Offer" then
			showOffer(gig)
		elseif gig and (gig.state == "Done" or gig.state == "Failed") then
			showEnd(gig)
		else
			slide(false) -- rang out, or on the job (the job guide takes it from here)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local gig = current
		local clock = os.clock()
		if hideAt > 0 and clock >= hideAt then
			hideAt = 0
			current = nil
			slide(false)
		end
		if not gig or gig.state ~= "Offer" or not up then
			phone.Rotation = 0
			return
		end
		-- Ringing: it buzzes and wobbles, and the bar runs down to when it stops.
		local now = Timing.now()
		phone.Rotation = math.sin(clock * 30) * 2.5 * (if (clock % RING_EVERY) < 0.6 then 1 else 0)
		if clock - lastRing >= RING_EVERY then
			lastRing = clock
			Sounds.play("PhoneRing")
		end
		local whole = math.max(gig.endsAt - ringingSince, 0.1)
		answerFill.Size = UDim2.fromScale(math.clamp((gig.endsAt - now) / whole, 0, 1), 1)
	end)
end

return GigController
