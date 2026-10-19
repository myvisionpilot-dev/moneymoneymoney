--!strict
-- The meters along the bottom left of the screen (top left on touch screens, clear of the
-- thumbstick). A tile for each treat that's running (energy drink, disguise, candy, gloves,
-- scanner): its little 3D picture, a dark wipe creeping down over it as it runs out and the
-- time left under it, throbbing red for the last 10 seconds. Then a tile for each hustle you've
-- picked this run, with what it's worth to you now (and how many you have). New tiles pop in
-- with stars; point at one (or tap it) to see what it is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Timing = require(Shared:WaitForChild("Timing"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local TILE = 56
local GAP = 10
local WARN_SECONDS = 10
local TOUCH_COLUMNS = 4
local HUSTLE_COLOR = UI.Colors.Purple

type Info = { id: string, name: string, detail: string, color: Color3 }

local boosts = Config.Boosts
local BOOSTS: { Info } = {
	{
		id = "Energy",
		name = "Energy Drink",
		detail = `{boosts.Energy.speed}x speed.`,
		color = Color3.fromRGB(80, 230, 90),
	},
	{
		id = "Disguise",
		name = "Disguise",
		detail = `{Format.percent(boosts.Disguise.heat)} heat from crimes.`,
		color = Color3.fromRGB(240, 185, 20),
	},
	{ id = "Candy", name = "Candy Bar", detail = "A wider green zone when you pickpocket.", color = UI.Colors.Pink },
	{
		id = "Gloves",
		name = "Gloves",
		detail = `Break-ins {Format.percent(boosts.Gloves.breakIn)} as long.`,
		color = UI.Colors.Purple,
	},
	{
		id = "Scanner",
		name = "Police Scanner",
		detail = "See every cop.",
		color = UI.Colors.Info,
	},
}

local function percent(value: number): string
	return `{math.floor(value * 100 + 0.5)}%`
end

-- What a hustle is worth with this many (HustleService does the same sums).
local HUSTLE_VALUES: { [string]: (value: number, stacks: number) -> string } = {
	SmoothTalker = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
	StickyFingers = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
	DeepPockets = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
	LuckyBreak = function(value, stacks)
		return `1 IN {math.floor(1 / (value * stacks) + 0.5)}`
	end,
	Ghost = function(value, stacks)
		return `x{1 + value * stacks}`
	end,
	CoolHead = function(value, stacks)
		return `-{percent(1 - (1 - value) ^ stacks)}`
	end,
	SecondChance = function()
		return "1 SAVE"
	end,
	EscapeArtist = function(value)
		return `-{percent(1 - value)}`
	end,
	Haggler = function(value, stacks)
		return `-{percent(1 - (1 - value) ^ stacks)}`
	end,
	Interest = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
	FleetFeet = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
	Safecracker = function(value)
		return `x{math.floor(1 / value + 0.5)}`
	end,
	RepoRepellent = function(value)
		return percent(value)
	end,
	Allowance = function(value, stacks)
		return `+{percent(value * stacks)}`
	end,
}

type Tile = {
	frame: Frame,
	scale: UIScale,
	rim: UIStroke?,
	wipe: UIGradient,
	label: TextLabel,
	count: TextLabel,
	color: Color3,
	leaving: boolean,
	warned: boolean, -- throbbing (nearly out)
}

local BoostMeters = {}

function BoostMeters.start()
	local root = UI.root(UI.screen("BoostMeters", 3))
	local touch = UserInputService.TouchEnabled
	local row = UI.frame({
		Name = "Meters",
		AnchorPoint = Vector2.new(0, if touch then 0 else 1),
		Position = if touch then UDim2.fromOffset(12, 52) else UDim2.new(0, 14, 1, -18),
		Size = UDim2.fromOffset(if touch then TOUCH_COLUMNS * (TILE + GAP) else 640, TILE),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, root)
	local layout = UI.grid(row, UDim2.fromOffset(TILE, TILE), GAP)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP + 12) -- room for the time under each
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	layout.StartCorner = if touch then Enum.StartCorner.TopLeft else Enum.StartCorner.BottomLeft

	-- What the tile you're pointing at is.
	local tip, tipContent = UI.panel(UI.Colors.Panel, {
		Name = "Tip",
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 10,
	}, root)
	UI.padding(tipContent, 8)
	UI.list(tipContent, Enum.FillDirection.Vertical, 2)
	local tipTitle = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = UI.Fonts.Heading,
		TextSize = 17,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, tipContent)
	local tipText = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, tipContent)
	local tipFor: Frame? = nil

	local function showTip(frame: Frame, title: string, text: string)
		tipFor = frame
		tipTitle.Text = title
		tipText.Text = text
		local rootScale = root:FindFirstChildOfClass("UIScale")
		local scale = if rootScale then rootScale.Scale else 1
		local at = (frame.AbsolutePosition - root.AbsolutePosition) / scale
		tip.AnchorPoint = Vector2.new(0, if touch then 0 else 1)
		tip.Position = if touch then UDim2.fromOffset(at.X, at.Y + TILE + 14) else UDim2.fromOffset(at.X, at.Y - 10)
		tip.Visible = true
	end

	local function hideTip(frame: Frame)
		if tipFor == frame then
			tipFor = nil
			tip.Visible = false
		end
	end

	local tiles: { [string]: Tile } = {}

	local function makeTile(
		key: string,
		order: number,
		picture: string,
		color: Color3,
		title: string,
		text: string
	): Tile
		local frame, content = UI.panel(UI.Colors.Panel, {
			Name = key,
			LayoutOrder = order,
		}, row)
		local rimFrame = frame:FindFirstChild("Rim")
		local rimStroke = rimFrame and rimFrame:FindFirstChildOfClass("UIStroke")
		if rimStroke then
			rimStroke.Color = color
			rimStroke.Thickness = 2.5
		end
		local glow = UI.glow(color, {
			Size = UDim2.fromOffset(TILE * 1.3, TILE * 1.3),
			Position = UDim2.fromScale(0.5, 0.42),
			ImageTransparency = 0.55,
			ZIndex = 1,
		}, content)
		glow.Name = "Glow"
		ItemModels.viewport(picture, {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 1, -12),
			ZIndex = 2,
		}, content, false)
		-- The dark wipe: everything above the gradient's edge is shaded (see setWipe).
		local shade = UI.frame({
			Name = "Wipe",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 3,
		}, content)
		UI.corner(shade, 12)
		local wipe = Instance.new("UIGradient")
		wipe.Rotation = 90
		wipe.Transparency = NumberSequence.new(1)
		wipe.Parent = shade
		local label = UI.label({
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, 16, 0, 20),
			FontFace = UI.Fonts.Number,
			TextSize = 17,
			TextWrapped = false,
			Text = "",
			ZIndex = 5,
		}, content)
		UI.textStroke(label, 2.6)
		local count = UI.label({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -6),
			Size = UDim2.fromOffset(30, 18),
			FontFace = UI.Fonts.Number,
			TextSize = 16,
			TextColor3 = UI.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "",
			ZIndex = 5,
		}, content)
		UI.textStroke(count, 2.4)
		local hit = Instance.new("TextButton")
		hit.Name = "Point"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 6
		hit.Parent = content
		hit.MouseEnter:Connect(function()
			showTip(frame, title, text)
		end)
		hit.MouseLeave:Connect(function()
			hideTip(frame)
		end)
		hit.Activated:Connect(function()
			showTip(frame, title, text)
			task.delay(2.5, hideTip, frame)
		end)
		-- It pops in with stars.
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = frame
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		task.delay(0.1, function()
			if frame.Parent then
				ScreenFx.stars(frame.AbsolutePosition + frame.AbsoluteSize / 2, 12, color)
			end
		end)
		local tile = {
			frame = frame,
			scale = scale,
			rim = rimStroke,
			wipe = wipe,
			label = label,
			count = count,
			color = color,
			leaving = false,
			warned = false,
		}
		tiles[key] = tile
		return tile
	end

	-- Shrinks a tile away.
	local function remove(key: string)
		local tile = tiles[key]
		if not tile or tile.leaving then
			return
		end
		tile.leaving = true
		tiles[key] = nil
		hideTip(tile.frame)
		UI.tween(tile.scale, 0.25, { Scale = 0 })
		task.delay(0.25, function()
			tile.frame:Destroy()
		end)
	end

	-- Shades the top `fraction` of a tile (0: none, 1: all of it).
	local function setWipe(tile: Tile, fraction: number)
		local edge = math.clamp(fraction, 0.001, 0.998)
		tile.wipe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(edge, 0.42),
			NumberSequenceKeypoint.new(edge + 0.001, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	-- Hustles: a tile each, worth what your stacks add up to.
	local function renderHustles()
		local me = ClientState.me()
		local have = if me then me.hustles else {}
		for order, hustle in Config.Hustles.List do
			local key = `Hustle{hustle.id}`
			local stacks = have[hustle.id] or 0
			local tile = tiles[key]
			if stacks <= 0 then
				remove(key)
				continue
			end
			if not tile then
				tile = makeTile(key, 100 + order, hustle.picture, HUSTLE_COLOR, hustle.title, hustle.detail)
			end
			local worth = HUSTLE_VALUES[hustle.id]
			tile.label.Text = if worth then worth(hustle.value, stacks) else ""
			tile.label.TextColor3 = UI.Colors.Gold
			local before = tile.count.Text
			tile.count.Text = if stacks > 1 then `x{stacks}` else ""
			if before ~= "" and before ~= tile.count.Text then
				UI.pop(tile.frame, 0.25) -- another of the same
			end
		end
	end

	ClientState.changed:Connect(renderHustles)

	RunService.RenderStepped:Connect(function()
		local me = ClientState.me()
		local now = Timing.now()
		for order, info in BOOSTS do
			local key = `Boost{info.id}`
			local endsAt = if me then me.boosts[info.id] else nil
			local left = if endsAt then endsAt - now else 0
			local tile = tiles[key]
			if left <= 0 then
				remove(key)
				continue
			end
			if not tile then
				tile = makeTile(key, order, info.id, info.color, info.name, info.detail)
			end
			tile.label.Text = Format.clock(left)
			setWipe(tile, 1 - left / boosts.Seconds)
			-- Nearly out: it throbs and its rim and time go red.
			local warning = left <= WARN_SECONDS
			local beat = if warning then (math.sin(os.clock() * 10) + 1) / 2 else 0
			tile.label.TextColor3 = if warning
				then UI.Colors.Danger:Lerp(Color3.new(1, 1, 1), beat * 0.5)
				else UI.Colors.Text
			if tile.rim then
				tile.rim.Color = if warning then UI.Colors.Danger else tile.color
			end
			if warning then
				tile.scale.Scale = 1 + beat * 0.08
			elseif tile.warned then
				tile.scale.Scale = 1 -- bought again just in time
			end
			tile.warned = warning
		end
	end)
end

return BoostMeters
