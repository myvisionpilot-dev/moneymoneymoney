--!strict
-- Robbing a store (client): the till opens on screen, seen from above. A REGISTER display along
-- the top counts what you've grabbed, and the drawer below is split into slots, each with a
-- stack of bills (coins in the little one). Click a stack to grab its top bill: it flies to
-- your bag with a rustle of cash. E (or a controller's A) grabs from the biggest slot left.
-- The bar drains to time's up; the server (StoreRobbery) counts every grab and pays at the end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local DRAWER = Vector2.new(560, 400)
local HEADER = 66
local BILL_GREEN = Color3.fromRGB(95, 190, 90)
local BILL_LIGHT = Color3.fromRGB(150, 225, 135)
local BILL_DARK = Color3.fromRGB(30, 95, 40)
local COIN_GOLD = Color3.fromRGB(250, 200, 50)
local METAL = Color3.fromRGB(225, 229, 236)
local SLOT = Color3.fromRGB(196, 202, 214)
local HURRY_SECONDS = 2

-- Where each slot sits in the drawer (fractions: x, y, width, height), in the server's order:
-- the left column, the two big middle slots, then the right column (coins on top).
local LAYOUT: { { number } } = {
	{ 0, 0, 0.31, 0.33 },
	{ 0, 0.33, 0.31, 0.33 },
	{ 0, 0.66, 0.31, 0.34 },
	{ 0.31, 0, 0.35, 0.5 },
	{ 0.31, 0.5, 0.35, 0.5 },
	{ 0.66, 0, 0.34, 0.2 },
	{ 0.66, 0.2, 0.34, 0.46 },
	{ 0.66, 0.66, 0.34, 0.34 },
}
local COIN_SLOT = 6

type Slot = { frame: Frame, pieces: { GuiObject }, value: number, label: TextLabel }

local RegisterController = {}

local rng = Random.new()

-- A bank note, `size` across (portrait when `upright`).
local function bill(parent: Instance, size: Vector2, upright: boolean, offset: Vector2): Frame
	local note = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = (if upright then 90 else 0) + rng:NextNumber(-3, 3),
		BackgroundColor3 = BILL_GREEN,
	}, parent)
	UI.corner(note, 4)
	UI.stroke(note, 2, BILL_DARK)
	local inner = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
	}, note)
	UI.corner(inner, 3)
	UI.stroke(inner, 1.5, BILL_LIGHT)
	local seal = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.Y * 0.62, size.Y * 0.62),
		BackgroundColor3 = BILL_LIGHT,
	}, note)
	UI.corner(seal, size.Y)
	UI.stroke(seal, 1.5, BILL_DARK)
	UI.plain({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.Fonts.Heading,
		TextSize = math.floor(size.Y * 0.48),
		TextColor3 = BILL_DARK,
		Text = "$",
		Rotation = if upright then -90 else 0,
	}, seal)
	return note
end

local function coin(parent: Instance, diameter: number, offset: Vector2): Frame
	local disc = UI.iconCircle("$", COIN_GOLD, diameter, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
	}, parent)
	return disc
end

function RegisterController.start()
	local remotes = Remotes.match()
	local root = UI.root(UI.screen("Register", 46))

	local backdrop = UI.frame({
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
	}, root)
	local drawer = UI.frame({
		Name = "Till",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(DRAWER.X, DRAWER.Y),
		BackgroundColor3 = Color3.fromRGB(70, 74, 86),
		Visible = false,
	}, root)
	UI.corner(drawer, 18)
	UI.stroke(drawer, 4)
	UI.gradient(drawer, 0.25)
	UI.checker(drawer, 12, 18, Color3.new(0, 0, 0), 0.9)
	Cursor.registerPanel(drawer)
	local spring = Instance.new("UIScale")
	spring.Parent = drawer

	-- The REGISTER display: a green screen with what you've grabbed, and the time bar under it.
	local header = UI.frame({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, HEADER - 16),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, drawer)
	local brand = UI.label({
		Size = UDim2.new(0.5, 0, 1, -12),
		FontFace = UI.Fonts.Title,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "REGISTER",
		ZIndex = 2,
	}, header)
	UI.textStroke(brand, 3.5)
	local screen = UI.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.46, 0, 1, -12),
		BackgroundColor3 = Color3.fromRGB(20, 45, 25),
		ZIndex = 2,
	}, header)
	UI.corner(screen, 8)
	UI.stroke(screen, 3)
	UI.checker(screen, 4, 8, Color3.fromRGB(120, 255, 120), 0.94)
	local total = UI.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		FontFace = UI.Fonts.Number,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(130, 255, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "$0",
		ZIndex = 3,
	}, screen)
	local timeTrack, timeFill = UI.bar(UI.Colors.Gold, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 9),
		ZIndex = 2,
	}, header)

	-- The drawer itself: metal, with dark dividers between the slots.
	local tray = UI.frame({
		Position = UDim2.fromOffset(12, HEADER),
		Size = UDim2.new(1, -24, 1, -HEADER - 12),
		BackgroundColor3 = METAL,
		ZIndex = 2,
	}, drawer)
	UI.corner(tray, 10)
	UI.stroke(tray, 4)
	UI.gradient(tray, 0.12)

	local current: Types.RegisterGame? = nil
	local slots: { Slot } = {}
	local grabbed = 0

	local function clearSlots()
		for _, slot in slots do
			slot.frame:Destroy()
		end
		table.clear(slots)
	end

	-- A grab: the top bill flies to your bag, "+$400" floats up, and the cash rustles.
	local function grab(index: number)
		local slot = slots[index]
		local game = current
		if not game or not slot or #slot.pieces == 0 then
			return
		end
		local piece = table.remove(slot.pieces) :: GuiObject
		local from = piece.AbsolutePosition + piece.AbsoluteSize / 2
		piece:Destroy()
		remotes.RegisterGrab:fire(index)
		grabbed += slot.value
		UI.roll(total, grabbed, Format.money, 0.25)
		UI.pop(screen, 0.08)
		Sounds.play("CashGrab", rng:NextNumber(0.95, 1.2), 0.8)
		local flyer = if index == COIN_SLOT then ScreenFx.coin() else ScreenFx.bill()
		flyer.Position = UDim2.fromOffset(from.X, from.Y)
		flyer.Parent = ScreenFx.layer()
		local to = HudController.bagTarget()
		local flight = TweenService:Create(
			flyer,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(to.X, to.Y), Rotation = rng:NextNumber(-360, 360) }
		)
		flight.Completed:Once(function()
			flyer:Destroy()
			HudController.popBag()
		end)
		flight:Play()
		local float = UI.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.35),
			Size = UDim2.fromOffset(120, 26),
			FontFace = UI.Fonts.Number,
			TextSize = 24,
			TextColor3 = BILL_LIGHT,
			Text = `+{Format.money(slot.value)}`,
			ZIndex = 8,
		}, slot.frame)
		UI.textStroke(float, 2.5)
		UI.tween(float, 0.6, { Position = UDim2.fromScale(0.5, -0.1), TextTransparency = 1 })
		local outline = float:FindFirstChild("TextOutline")
		if outline and outline:IsA("UIStroke") then
			UI.tween(outline, 0.6, { Transparency = 1 })
		end
		task.delay(0.6, function()
			float:Destroy()
		end)
		UI.pop(slot.frame, 0.06)
		if #slot.pieces == 0 then
			slot.label.Text = "EMPTY"
			slot.label.TextColor3 = UI.Colors.Grey
		end
	end

	-- One slot: its stack of bills (or coins) and what each is worth.
	local function makeSlot(index: number, info: Types.RegisterSlot): Slot
		local place = LAYOUT[index] or { 0, 0, 0.3, 0.3 }
		local frame = UI.frame({
			Name = `Slot{index}`,
			Position = UDim2.new(place[1], 5, place[2], 5),
			Size = UDim2.new(place[3], -10, place[4], -10),
			BackgroundColor3 = SLOT,
			ZIndex = 3,
		}, tray)
		UI.corner(frame, 8)
		UI.stroke(frame, 3)
		UI.gradient(frame, 0.15)
		-- The slot's size in the drawer's own pixels, to size the bills.
		local across = (DRAWER.X - 24) * place[3] - 10
		local tall = (DRAWER.Y - HEADER - 12) * place[4] - 10
		local upright = tall > across * 1.2
		local pieces: { GuiObject } = {}
		for count = 1, info.bills do
			local nudge = Vector2.new(-(count - 1) * 2.5, -(count - 1) * 3)
			local piece: GuiObject
			if index == COIN_SLOT then
				local size = math.min(tall * 0.7, 34)
				piece = coin(frame, size, Vector2.new((count - (info.bills + 1) / 2) * size * 0.8, 0))
			else
				local long = if upright
					then math.min(tall * 0.78, across * 1.9)
					else math.min(across * 0.78, tall * 1.9)
				piece = bill(frame, Vector2.new(long, long / 2.1), upright, nudge)
			end
			piece.ZIndex = 3 + count -- the last one is on top
			table.insert(pieces, piece)
		end
		local label = UI.label({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -2),
			Size = UDim2.fromOffset(80, 18),
			FontFace = UI.Fonts.Number,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UI.Colors.Gold,
			Text = Format.money(info.value),
			ZIndex = 9,
		}, frame)
		local hit = Instance.new("TextButton")
		hit.Name = "Grab"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 10
		hit.Parent = frame
		hit.Activated:Connect(function()
			grab(index)
		end)
		return { frame = frame, pieces = pieces, value = info.value, label = label }
	end

	-- E or A: grab from the slot holding the most money.
	local function grabBest()
		local best, bestValue = 0, 0
		for index, slot in slots do
			if #slot.pieces > 0 and slot.value > bestValue then
				best, bestValue = index, slot.value
			end
		end
		if best > 0 then
			grab(best)
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
		if not current or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonA then
			grabBest()
		end
	end)

	local function close()
		local cleaned = true
		for _, slot in slots do
			if #slot.pieces > 0 then
				cleaned = false
			end
		end
		current = nil
		if cleaned and grabbed > 0 then
			ScreenFx.banner("CLEANED OUT!", UI.Colors.Money, `{Format.money(grabbed)} grabbed`, 1.4)
		end
		UI.tween(spring, 0.2, { Scale = 0.6 })
		task.delay(0.2, function()
			if not current then
				drawer.Visible = false
				backdrop.Visible = false
				clearSlots()
			end
		end)
	end

	remotes.RegisterGame:onClient(function(game: Types.RegisterGame?)
		if not game then
			if current then
				close()
			end
			return
		end
		clearSlots()
		current = game
		grabbed = 0
		UI.roll(total, 0, Format.money)
		for index, info in game.slots do
			table.insert(slots, makeSlot(index, info))
		end
		backdrop.Visible = true
		drawer.Visible = true
		spring.Scale = 0.4
		TweenService:Create(spring, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		Sounds.play("Open", 0.8)
		ScreenFx.flash(UI.Colors.Money, 0.12)
	end)

	local startedAt = 0
	local length = 1
	RunService.RenderStepped:Connect(function()
		local game = current
		if not game then
			startedAt = 0
			return
		end
		local now = Timing.now()
		if startedAt == 0 then
			startedAt = now
			length = math.max(game.endsAt - now, 0.1)
		end
		local left = math.max(game.endsAt - now, 0)
		timeFill.Size = UDim2.fromScale(math.clamp(left / length, 0, 1), 1)
		if left < HURRY_SECONDS then
			local beat = (math.sin(os.clock() * 14) + 1) / 2
			timeFill.BackgroundColor3 = UI.Colors.Danger:Lerp(Color3.new(1, 1, 1), beat * 0.4)
			timeTrack.Rotation = math.sin(os.clock() * 30) * 0.5
		else
			timeFill.BackgroundColor3 = UI.Colors.Gold
			timeTrack.Rotation = 0
		end
	end)
end

return RegisterController
