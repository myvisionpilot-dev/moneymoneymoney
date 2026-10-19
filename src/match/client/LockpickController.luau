--!strict
-- The jail cell's lock (client): a ring of red notches with a green arc spins clockwise under
-- an arrow; press (click, E, a controller's A, or the PICK button) when the green is under the
-- arrow to set a pin. Every pin set and the cell opens; a miss rattles the bars and drops you
-- back to the first pin. We show hits and misses straight away and send each press to the
-- server (JailLock), which checks it and has the last word. Shows while you're in jail, with
-- how long you'd wait otherwise; the HUD's BUSTED banner hides meanwhile.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cursor = require(Shared:WaitForChild("Cursor"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local RING = 160 -- the ring's diameter
local NOTCHES = 72 -- 5 degrees each
local NOTCH_SIZE = Vector2.new(8, 14)
local RED = Color3.fromRGB(235, 55, 65)
local GREEN = Color3.fromRGB(110, 230, 60)
local TOUCH = UserInputService.TouchEnabled
local HOW_TO = if TOUCH then "Tap PICK on the green!" else "Click on the green!"
-- The panel's bottom sits above the money lines, and phones (shorter screens) get it smaller.
local SPOT = UDim2.new(0.5, 0, 1, -130)
local FIT = if TOUCH then 0.8 else 1

local LockpickController = {}
local current: Types.LockpickGame? = nil

-- True while the lock is on screen (announcements wait so they don't slide out behind it).
function LockpickController.showing(): boolean
	return current ~= nil
end

-- The arc's start t seconds into a pin's spin (degrees clockwise from the top).
local function arcAt(pin: Types.LockPin, t: number): number
	return (pin.start + pin.speed * math.max(t, 0)) % 360
end

local function covers(pin: Types.LockPin, t: number, tolerance: number): boolean
	local fromStart = (360 - arcAt(pin, t)) % 360
	return fromStart <= pin.width + tolerance or fromStart >= 360 - tolerance
end

function LockpickController.start()
	local remotes = Remotes.match()
	local tolerance = Config.Police.Lockpick.ToleranceDegrees
	local root = UI.root(UI.screen("Lockpick", 44))

	local panel, content = UI.panel(UI.Colors.Panel, {
		Name = "Lockpick",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = SPOT,
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, root)
	panel.BackgroundTransparency = 0 -- solid, so Mr. Penny's drawer can't show through
	Cursor.registerPanel(panel)
	UI.padding(content, 12)
	UI.list(content, Enum.FillDirection.Vertical, 6)

	local title = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		FontFace = UI.Fonts.Title,
		TextSize = 32,
		TextColor3 = UI.Colors.Danger,
		Text = "BUSTED!",
	}, content)
	UI.textStroke(title, 3.5)
	local hint = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 15,
		TextWrapped = true,
		Text = HOW_TO,
	}, content)

	-- The dial: the ring (it spins), the padlock in the middle, the arrow on top.
	local dial = UI.frame({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(RING + 30, RING + 30),
		BackgroundTransparency = 1,
	}, content)
	local glow = UI.glow(GREEN, {
		Size = UDim2.fromOffset(RING * 1.5, RING * 1.5),
		ImageTransparency = 1,
	}, dial)
	local ring = UI.frame({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING, RING),
		BackgroundTransparency = 1,
	}, dial)
	local notches: { Frame } = {}
	local radius = RING / 2 - NOTCH_SIZE.Y / 2
	for index = 0, NOTCHES - 1 do
		local angle = (index + 0.5) * 360 / NOTCHES
		local notch = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(math.rad(angle)) * radius, 0.5, -math.cos(math.rad(angle)) * radius),
			Size = UDim2.fromOffset(NOTCH_SIZE.X, NOTCH_SIZE.Y),
			Rotation = angle,
			BackgroundColor3 = RED,
		}, ring)
		UI.corner(notch, 3)
		UI.stroke(notch, 1.5)
		table.insert(notches, notch)
	end
	local hub = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING - 52, RING - 52),
		BackgroundColor3 = UI.Colors.PanelDark,
	}, dial)
	UI.corner(hub, RING)
	UI.stroke(hub, 3)
	UI.checker(hub, 10, RING)
	ItemModels.viewport("Lockpick", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = 2,
	}, hub, true)
	-- The arrow: a gold point aimed down at the ring.
	local arrow = UI.frame({
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -RING / 2 + 4),
		Size = UDim2.fromOffset(28, 30),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, dial)
	local tip = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(20, 20),
		Rotation = 45,
		BackgroundColor3 = UI.Colors.Gold,
		ZIndex = 5,
	}, arrow)
	UI.stroke(tip, 2.5)
	local stem = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(12, 18),
		BackgroundColor3 = UI.Colors.Gold,
		ZIndex = 6,
	}, arrow)
	UI.stroke(stem, 2.5)

	-- Pins set so far, and the time you'd wait instead.
	local pinsRow = UI.frame({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
	}, content)
	local pinsLayout = UI.list(pinsRow, Enum.FillDirection.Horizontal, 10)
	pinsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local footer = UI.frame({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, content)
	local waitLabel = UI.label({
		Size = UDim2.new(1, -130, 1, 0),
		FontFace = UI.Fonts.Number,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, footer)
	local pick = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = UI.Colors.Gold,
		TextSize = 22,
		Text = "PICK!",
	}, footer)

	local pinIndex = 1
	local spinsFrom = 0 -- os.clock() when the current pin starts spinning
	local pinDots: { Frame } = {}

	-- Colours the notches for this pin's arc (the ring's own angle 0 is where the arc starts).
	local function paintRing(pin: Types.LockPin)
		for index, notch in notches do
			local middle = (index - 0.5) * 360 / NOTCHES
			notch.BackgroundColor3 = if middle <= pin.width then GREEN else RED
		end
	end

	local function showPins()
		local game = current
		if not game then
			return
		end
		for index, dot in pinDots do
			dot.BackgroundColor3 = if index < pinIndex then UI.Colors.Gold else UI.Colors.PanelDark
		end
		local pin = game.pins[pinIndex]
		if pin then
			paintRing(pin)
		end
	end

	local function startPin(index: number, pause: number)
		pinIndex = index
		spinsFrom = os.clock() + pause
		showPins()
	end

	local function press()
		local game = current
		if not game or os.clock() < spinsFrom then
			return
		end
		local t = os.clock() - spinsFrom
		local pin = game.pins[pinIndex]
		remotes.LockpickPress:fire({ pin = pinIndex, t = t })
		if not covers(pin, t, tolerance) then
			-- Slipped: the bars rattle and it's back to the first pin.
			Sounds.play("LockRattle", 1.15)
			hint.Text = "Slipped! Start again."
			for _, notch in notches do
				notch.BackgroundColor3 = RED
			end
			glow.ImageColor3 = RED
			glow.ImageTransparency = 0.2
			UI.tween(glow, 0.5, { ImageTransparency = 1 })
			task.spawn(function()
				for step = 1, 6 do
					panel.Position = SPOT + UDim2.fromOffset(if step % 2 == 0 then 7 else -7, 0)
					task.wait(0.03)
				end
				panel.Position = SPOT
			end)
			-- The all-red ring stays a moment before the first pin comes back.
			pinIndex = 1
			spinsFrom = os.clock() + game.pauseSeconds + 0.35
			task.delay(0.35, function()
				if pinIndex == 1 then
					showPins()
				end
			end)
			return
		end
		-- Set: a click, the pin lights gold, a burst of green.
		hint.Text = HOW_TO
		local dot = pinDots[pinIndex]
		if dot then
			UI.pop(dot, 0.6)
			ScreenFx.stars(dot.AbsolutePosition + dot.AbsoluteSize / 2, 8, UI.Colors.Gold)
		end
		glow.ImageColor3 = GREEN
		glow.ImageTransparency = 0.2
		UI.tween(glow, 0.4, { ImageTransparency = 1 })
		UI.pop(ring, 0.06)
		if pinIndex >= #game.pins then
			Sounds.play("LockOpen")
			hint.Text = "Click! You're out!"
			pinIndex += 1
			showPins()
			spinsFrom = math.huge -- the server opens the cell
			return
		end
		Sounds.play("LockClick", 1 + pinIndex * 0.1)
		startPin(pinIndex + 1, game.pauseSeconds)
	end

	local function close()
		current = nil
		panel.Visible = false
		HudController.hideJailBanner(false)
		ProximityPromptService.Enabled = true
	end

	pick.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not current or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		local isKey = key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1 and not processed
		if isKey or isClick then
			press()
		end
	end)

	remotes.LockpickGame:onClient(function(game: Types.LockpickGame?)
		if not game then
			local closing = current
			if closing and pinIndex > #closing.pins then
				-- Picked it: the lock pops, then it all goes.
				ScreenFx.flash(GREEN, 0.25)
				ScreenFx.stars(ring.AbsolutePosition + ring.AbsoluteSize / 2, 30, UI.Colors.Gold)
				task.delay(0.6, function()
					if current == closing then
						close()
					end
				end)
			elseif closing then
				close() -- let out (time served, or the quota ended)
			end
			return
		end
		local fresh = current == nil or current.pins[1].start ~= game.pins[1].start
		current = game
		if fresh then
			for _, dot in pinDots do
				dot:Destroy()
			end
			table.clear(pinDots)
			for index = 1, #game.pins do
				local dot = UI.frame({
					LayoutOrder = index,
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = UI.Colors.PanelDark,
				}, pinsRow)
				UI.corner(dot, 11)
				UI.stroke(dot, 2.5)
				table.insert(pinDots, dot)
			end
			hint.Text = HOW_TO
			startPin(game.pin, game.pauseSeconds)
			panel.Visible = true
			HudController.hideJailBanner(true)
			ProximityPromptService.Enabled = false
			local spring = panel:FindFirstChild("Spring") :: UIScale?
			if not spring then
				local created = Instance.new("UIScale")
				created.Name = "Spring"
				created.Parent = panel
				spring = created
			end
			if spring then
				spring.Scale = FIT * 0.5
				TweenService:Create(spring, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = FIT,
				}):Play()
			end
		elseif game.pin ~= pinIndex then
			startPin(game.pin, game.pauseSeconds) -- the server saw it differently: go with it
		end
	end)

	RunService.RenderStepped:Connect(function()
		local game = current
		if not game then
			return
		end
		local pin = game.pins[math.min(pinIndex, #game.pins)]
		if spinsFrom ~= math.huge then
			ring.Rotation = arcAt(pin, os.clock() - spinsFrom)
		end
		local me = ClientState.me()
		local left = if me then me.jailedUntil - Timing.now() else 0
		waitLabel.Text = if left > 0 then `or wait {Format.clock(left)}` else ""
	end)
end

return LockpickController
