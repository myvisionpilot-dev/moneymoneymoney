--!strict
-- The store look (client, both places: the lobby's windows and the Shop in a run), after the
-- user's references: Montserrat Black in white with a thick dark outline, a faint brick pattern
-- on cards and buttons, windows with a glossy green title bar (diagonal glints and a shine
-- sweeping across) over a see-through dark body, cards with a white glow behind their picture,
-- chunky green price buttons with a Robux or Cred icon, pink gift buttons, and "glitter" buttons
-- (a gradient with a light rim and soft white dots). The pictures are 2D cartoons drawn by
-- art/store/draw_store_art.py and uploaded as images.

local TweenService = game:GetService("TweenService")

local ItemModels = require(script.Parent.ItemModels)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local WHITE = Color3.new(1, 1, 1)

local StoreKit = {}

local function apply(target: any, props: UI.Props?)
	if props then
		for key, value in props do
			target[key] = value
		end
	end
end

StoreKit.Fonts = {
	Black = Font.new(MONTSERRAT, Enum.FontWeight.Heavy),
	ExtraBold = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
	BlackItalic = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
}

StoreKit.Colors = {
	Green = Color3.fromRGB(70, 230, 60), -- cards and the title bar
	GreenLight = Color3.fromRGB(135, 255, 112),
	GreenDark = Color3.fromRGB(58, 214, 48),
	Lime = Color3.fromRGB(112, 245, 8), -- buy buttons and the Shop button: bright yellowy green
	LimeEdge = Color3.fromRGB(14, 76, 2), -- the Shop button's dark green outline...
	LimeRim = Color3.fromRGB(190, 255, 175), -- ...and the pale line just inside it
	Body = Color3.fromRGB(16, 18, 26), -- a window's inside, behind the cards: dark and see-through
	Gold = Color3.fromRGB(255, 214, 54), -- section titles and Cred
	Highlight = Color3.fromRGB(70, 255, 70), -- the "x2" in a pass's text
	Gift = Color3.fromRGB(200, 60, 255),
	Close = Color3.fromRGB(226, 32, 40),
}

-- The pictures (white-on-clear icons are tinted; the rest are full colour).
StoreKit.BODY_TRANSPARENCY = 0.38 -- how much of the world shows through a window's body
StoreKit.BUNDLE_RATIO = 1.4 -- the bundle pictures' width for their height

StoreKit.Images = {
	Bricks = "rbxassetid://124113967763344",
	Dots = "rbxassetid://75288816576998", -- soft white glitter dots, tiled on glitter buttons
	Bill = "rbxassetid://111351454249622", -- one loose bill (falling money)
	Bundle = "rbxassetid://73613831101430", -- one bundle, turned to the right (money piles are built from these)
	BundleBack = "rbxassetid://76657316155831", -- one bundle, turned to the left
	BundleUp = "rbxassetid://99921925781627", -- one bundle, tipped to show its top
	Sparkle = "rbxassetid://70581829569598", -- a white four-pointed star (tinted)
	Robux = "rbxassetid://92675252689589",
	Gift = "rbxassetid://84859726225454",
	Cart = "rbxassetid://114111098417711",
	Arrow = "rbxassetid://87568983122527",
	Brush = "rbxassetid://121252276641840",
	CredCoin = "rbxassetid://126343165892731",
	Cred100 = "rbxassetid://78197346119276",
	Cred500 = "rbxassetid://114194321170659",
	Cred1000 = "rbxassetid://95497118707778",
	Cred5000 = "rbxassetid://109581877982844",
	Cred25000 = "rbxassetid://132618530239195",
	Cred100000 = "rbxassetid://125101085177492",
	PassBigBaller = "rbxassetid://82741689542475",
	PassRainbow = "rbxassetid://83503237491050",
	PassDoubleCash = "rbxassetid://75896676773796",
	PassDoubleLuck = "rbxassetid://93138405510232",
	PassDoubleCred = "rbxassetid://90298162431970",
	PassMegaBag = "rbxassetid://105850011313104",
	PassFatStack = "rbxassetid://96794086103896",
	PassTipJar = "rbxassetid://97841333101496",
	PassBail = "rbxassetid://132319325839939",
	PassClean = "rbxassetid://91065277998197",
	PassVip = "rbxassetid://128470465461987",
}

-- The faint brick pattern over a frame: dark on colours, light on the dark body.
function StoreKit.bricks(parent: GuiObject, dark: boolean?, radius: number?, cell: number?): ImageLabel
	local tiles = Instance.new("ImageLabel")
	tiles.Name = "Bricks"
	tiles.Size = UDim2.fromScale(1, 1)
	tiles.BackgroundTransparency = 1
	tiles.Image = StoreKit.Images.Bricks
	tiles.ImageColor3 = if dark == false then WHITE else Color3.new(0, 0, 0)
	tiles.ImageTransparency = if dark == false then 0.93 else 0.9
	tiles.ScaleType = Enum.ScaleType.Tile
	tiles.TileSize = UDim2.fromOffset(cell or 22, cell or 22)
	tiles.ZIndex = 1
	tiles.Active = false
	tiles.Parent = parent
	UI.corner(tiles, radius or 8)
	return tiles
end

-- An outlined Montserrat label.
function StoreKit.label(props: UI.Props?, parent: Instance?): TextLabel
	local label = UI.label({ FontFace = StoreKit.Fonts.Black, TextWrapped = false })
	apply(label, props)
	label.Parent = parent
	UI.textStroke(label)
	return label
end

-- "Get [x2] Money!" with the bracketed bits in bright green (rich text).
function StoreKit.highlight(text: string): string
	return (text:gsub("%[(.-)%]", '<font color="#46FF46">%1</font>'))
end

-- A chunky button in the store look: the brick pattern instead of the checkerboard,
-- Montserrat, smaller corners.
function StoreKit.button(props: UI.Props?, parent: Instance?): TextButton
	local button = UI.button({ FontFace = StoreKit.Fonts.Black })
	apply(button, props)
	local checker = button:FindFirstChild("Checker")
	if checker then
		checker:Destroy()
	end
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 8)
	end
	local highlight = button:FindFirstChild("Highlight")
	if highlight and highlight:IsA("Frame") then
		local round = highlight:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(0, 5)
		end
	end
	StoreKit.bricks(button, true, 8, 18)
	UI.textStroke(button, 3)
	button.Parent = parent
	return button
end

-- A small picture (an image id from StoreKit.Images).
function StoreKit.image(id: string, props: UI.Props?, parent: Instance?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = id
	image.ScaleType = Enum.ScaleType.Fit
	apply(image, props)
	image.Parent = parent
	return image
end

-- An icon and words side by side in the middle of a button (a price, or SOON/OWNED).
-- Returns the words' label so the caller can change them.
function StoreKit.iconText(button: TextButton, icon: string?, text: string, size: number?): TextLabel
	local old = button:FindFirstChild("IconText")
	if old then
		old:Destroy()
	end
	button.Text = ""
	local textSize = size or math.clamp(math.floor(button.Size.Y.Offset * 0.52), 16, 30)
	local row = UI.frame({
		Name = "IconText",
		Size = UDim2.fromScale(1, 0.92),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, button)
	local layout = UI.list(row, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	if icon then
		StoreKit.image(icon, {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(textSize + 6, textSize + 6),
			ZIndex = 4,
		}, row)
	end
	return StoreKit.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, textSize + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = textSize,
		Text = text,
		ZIndex = 4,
	}, row)
end

-- A menu button in the store look: a picture on the left (an image id, or an ItemModels id for
-- a little turning 3D model), the name beside it.
function StoreKit.iconButton(text: string, icon: string, color: Color3, props: UI.Props, parent: Instance): TextButton
	local button = StoreKit.button({ BackgroundColor3 = color, Text = "" })
	for key, value in props do
		(button :: any)[key] = value
	end
	local height = button.Size.Y.Offset
	local picture = {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.47, 0),
		Size = UDim2.fromOffset(height * 0.68, height * 0.68),
		ZIndex = 4,
	}
	if icon:sub(1, 13) == "rbxassetid://" then
		StoreKit.image(icon, picture, button)
	else
		picture.Position = UDim2.new(0, 4, 0.5, 0)
		picture.Size = UDim2.fromOffset(height * 0.9, height * 0.9)
		ItemModels.viewport(icon, picture, button, true)
	end
	local label = StoreKit.label({
		Position = UDim2.fromOffset(height * 0.68 + 18, 0),
		Size = UDim2.new(1, -height * 0.68 - 26, 0.94, 0),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		ZIndex = 4,
	}, button)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = math.floor(height * 0.5)
	limit.Parent = label
	UI.textStroke(label, 3)
	button.Parent = parent
	return button
end

-- Makes a button the bright lime of the reference's Shop button: a dark green outline with a pale
-- line just inside it.
function StoreKit.lime(button: TextButton)
	button.BackgroundColor3 = StoreKit.Colors.Lime
	local border = button:FindFirstChild("Border")
	if border and border:IsA("UIStroke") then
		border.Color = StoreKit.Colors.LimeEdge
		border.Thickness = 4
	end
	if not button:FindFirstChild("Rim") then
		local rim = UI.frame({
			Name = "Rim",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Active = false,
		}, button)
		UI.corner(rim, 6)
		UI.stroke(rim, 2, StoreKit.Colors.LimeRim)
	end
end

-- The pink gift button beside a price.
function StoreKit.giftButton(props: UI.Props?, parent: Instance?): TextButton
	local button = StoreKit.button({ BackgroundColor3 = WHITE, Text = "" })
	apply(button, props)
	-- One gradient per frame: the gift's pink-to-purple replaces the button's lip.
	local lip = button:FindFirstChildOfClass("UIGradient")
	if lip then
		lip:Destroy()
	end
	local tint = Instance.new("UIGradient")
	tint.Color = ColorSequence.new(Color3.fromRGB(255, 120, 230), Color3.fromRGB(150, 70, 255))
	tint.Rotation = 90
	tint.Parent = button
	StoreKit.image(StoreKit.Images.Gift, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 4,
	}, button)
	button.Parent = parent
	return button
end

-- A store card: a colour (or a gradient: rainbow, gold) going from a deeper shade at the top to
-- a lighter one at the bottom, outlined,
-- bricks, faint light rays and a soft white glow where its picture goes (`glowAt`, scale).
function StoreKit.card(
	color: Color3,
	props: UI.Props?,
	parent: Instance?,
	glowAt: Vector2?,
	glowSize: number?
): (Frame, Frame)
	local card = UI.frame({ BackgroundColor3 = WHITE })
	apply(card, props)
	UI.corner(card, 8)
	UI.stroke(card, 3.5)
	local shade = Instance.new("UIGradient")
	shade.Name = "Shade"
	shade.Rotation = 90
	shade.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.24), color:Lerp(WHITE, 0.1))
	shade.Parent = card
	StoreKit.bricks(card, true, 8)
	local at = glowAt or Vector2.new(0.5, 0.4)
	UI.rays(card, glowSize or 420, WHITE, 8, at)
	local rays = card:FindFirstChild("Rays")
	local spinner = rays and rays:FindFirstChild("Spinner")
	if spinner and spinner:IsA("ImageLabel") then
		spinner.ImageTransparency = 0.82
	end
	UI.glow(WHITE, {
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset((glowSize or 420) * 0.5, (glowSize or 420) * 0.5),
		ImageTransparency = 0.05,
		ZIndex = 1,
	}, card)
	local content = UI.frame({
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, card)
	card.Parent = parent
	return card, content
end

-- Recolours a card with a gradient instead (left to right): the rainbow pack, the gold one.
function StoreKit.paint(card: Frame, colors: { Color3 })
	card.BackgroundColor3 = WHITE
	local shade = card:FindFirstChild("Shade")
	if shade then
		shade:Destroy()
	end
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / math.max(#colors - 1, 1), color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Shade"
	gradient.Rotation = 20
	gradient.Color = ColorSequence.new(keys)
	gradient.Parent = card
	-- A painted card is all about its colours: a softer glow and fainter rays keep them vivid.
	local glow = card:FindFirstChild("Glow")
	if glow and glow:IsA("ImageLabel") then
		glow.ImageTransparency = 0.45
	end
	local rays = card:FindFirstChild("Rays")
	if rays then
		for _, child in rays:GetChildren() do
			if child:IsA("ImageLabel") then
				child.ImageTransparency = if child.Name == "Spinner" then 0.9 else 0.65
			end
		end
	end
end

StoreKit.Rainbow = { -- full-strength colours: red, orange, yellow, green, blue, purple, pink
	Color3.fromRGB(255, 40, 60),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 225, 0),
	Color3.fromRGB(30, 215, 50),
	Color3.fromRGB(0, 160, 255),
	Color3.fromRGB(135, 60, 255),
	Color3.fromRGB(255, 40, 190),
}
StoreKit.GoldColors = {
	Color3.fromRGB(255, 224, 40),
	Color3.fromRGB(255, 170, 0),
	Color3.fromRGB(255, 214, 20),
}

-- A section title: "-- PASSES --", gold unless `color` says otherwise.
function StoreKit.section(text: string, order: number, parent: Instance, color: Color3?): TextLabel
	local label = StoreKit.label({
		Name = "Section",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		TextSize = 34,
		TextColor3 = color or StoreKit.Colors.Gold,
		Text = `-- {text} --`,
	}, parent)
	UI.textStroke(label, 3.5)
	return label
end

-- A row that holds cards side by side, each sharing the width (cards set their own Size.X
-- scale; use `gap` between them).
function StoreKit.row(order: number, height: number, gap: number, parent: Instance): (Frame, UIListLayout)
	local row = UI.frame({
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, parent)
	local layout = UI.list(row, Enum.FillDirection.Horizontal, gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return row, layout
end

-- A picture by its StoreKit.Images key ("" for an unknown one).
function StoreKit.art(key: string): string
	return (StoreKit.Images :: any)[key] or ""
end

export type Window = UI.Window

local HEADER_HEIGHT = 62

-- A store window: a glossy green title bar (title on the left, tabs beside it, a red X on the
-- right unless `closable` is false) over a see-through dark body. Same fields as UI.window.
function StoreKit.window(title: string, props: UI.Props?, parent: Instance?, closable: boolean?): Window
	local panel = UI.frame({
		BackgroundColor3 = StoreKit.Colors.Body,
		BackgroundTransparency = StoreKit.BODY_TRANSPARENCY,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, parent)
	apply(panel, props)
	UI.corner(panel, 10)
	UI.stroke(panel, 4)

	local header = UI.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = StoreKit.Colors.Green,
		ZIndex = 5,
	}, panel)
	UI.corner(header, 8)
	UI.stroke(header, 3)
	local headerShade = Instance.new("UIGradient")
	headerShade.Rotation = 90
	headerShade.Color = ColorSequence.new(StoreKit.Colors.GreenLight, StoreKit.Colors.GreenDark)
	headerShade.Parent = header
	StoreKit.bricks(header, true, 8, 20)
	-- Two diagonal glints across it, like light on glass...
	local glints = UI.frame({
		Name = "Glints",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
		Active = false,
	}, header)
	UI.corner(glints, 8)
	local band = Instance.new("UIGradient")
	band.Rotation = 35
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.21, 0.72),
		NumberSequenceKeypoint.new(0.34, 0.72),
		NumberSequenceKeypoint.new(0.35, 1),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(0.63, 0.8),
		NumberSequenceKeypoint.new(0.68, 0.8),
		NumberSequenceKeypoint.new(0.69, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Parent = glints
	-- ...and a shine sweeping over now and then.
	UI.shine(header, 3.5, 8)

	local row = UI.frame({
		Name = "Row",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, header)
	local rowLayout = UI.list(row, Enum.FillDirection.Horizontal, 12)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = UI.frame({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
	}, row)
	icon.ChildAdded:Connect(function()
		icon.Visible = true
	end)
	local titleLabel = StoreKit.label({
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 40,
		Text = title,
		ZIndex = 6,
	}, row)
	UI.textStroke(titleLabel, 4)
	local tabs = UI.frame({
		Name = "Tabs",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, row)
	local tabLayout = UI.list(tabs, Enum.FillDirection.Horizontal, 8)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local close: TextButton? = nil
	if closable ~= false then
		local button = StoreKit.button({
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = StoreKit.Colors.Close,
			TextSize = 34,
			Text = "X",
			ZIndex = 7,
		}, header)
		button.Activated:Connect(function()
			panel.Visible = false
		end)
		close = button
	else
		row.Size = UDim2.new(1, -32, 1, 0) -- no X: the title row gets its room
	end

	local body = UI.frame({
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, panel)
	UI.padding(body, 10)

	-- It springs open with a whoosh.
	local opening = Instance.new("UIScale")
	opening.Name = "Opening"
	opening.Parent = panel
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			opening.Scale = 0.75
			TweenService:Create(opening, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			Sounds.play("Open")
		end
	end)
	return {
		panel = panel,
		title = titleLabel,
		header = header,
		icon = icon,
		tabs = tabs,
		body = body,
		close = close,
	}
end

StoreKit.HEADER_HEIGHT = HEADER_HEIGHT

-- Puts a window's title in the middle of its title bar (windows without tabs or an X).
function StoreKit.centreTitle(window: Window)
	local row = window.title.Parent
	local layout = row and row:FindFirstChildOfClass("UIListLayout")
	if row and row:IsA("Frame") and layout then
		row.Position = UDim2.new()
		row.Size = UDim2.fromScale(1, 1)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

-- A see-through list that scrolls up and down.
function StoreKit.scroller(props: UI.Props, parent: Instance): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 215)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 2
	apply(list, props)
	list.Parent = parent
	return list
end

-- ---------------------------------------------------------------- glitter buttons
-- After the user's "Matchmaking" reference: a gradient from a deeper colour at the bottom left to
-- a light one at the top right, a light band across the top, soft white dots, a thin dark outline
-- with a pale line just inside it, and white rounded words with a dark outline and a drop shadow.

-- A glitter button's colours: the gradient (low at the bottom left, high at the top right), the
-- dark outline, the pale rim inside it, and the outline of its words.
export type Glitter = { low: Color3, mid: Color3, high: Color3, edge: Color3, rim: Color3, ink: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

StoreKit.Glitter = {
	Purple = {
		low = rgb(112, 26, 186),
		mid = rgb(196, 48, 236),
		high = rgb(255, 150, 255),
		edge = rgb(24, 4, 38),
		rim = rgb(242, 214, 255),
		ink = rgb(38, 6, 58),
	},
	Green = {
		low = rgb(16, 138, 34),
		mid = rgb(58, 206, 46),
		high = rgb(176, 255, 128),
		edge = rgb(6, 42, 10),
		rim = rgb(214, 255, 206),
		ink = rgb(8, 52, 14),
	},
	Lime = {
		low = rgb(64, 168, 0),
		mid = rgb(122, 232, 10),
		high = rgb(214, 255, 126),
		edge = rgb(16, 62, 2),
		rim = rgb(232, 255, 200),
		ink = rgb(18, 66, 4),
	},
	Red = {
		low = rgb(168, 18, 30),
		mid = rgb(234, 50, 62),
		high = rgb(255, 152, 142),
		edge = rgb(50, 4, 8),
		rim = rgb(255, 216, 210),
		ink = rgb(60, 6, 10),
	},
	Gold = {
		low = rgb(206, 126, 0),
		mid = rgb(250, 190, 20),
		high = rgb(255, 240, 140),
		edge = rgb(70, 40, 0),
		rim = rgb(255, 246, 204),
		ink = rgb(84, 48, 0),
	},
	Blue = {
		low = rgb(18, 66, 200),
		mid = rgb(36, 146, 252),
		high = rgb(150, 222, 255),
		edge = rgb(4, 18, 52),
		rim = rgb(210, 236, 255),
		ink = rgb(6, 24, 66),
	},
}

local DROP = 3 -- how far a glitter button's words' shadow sits below them
local EDGE_BAND = 0.42 -- how far in from the top and bottom edges the glitter reaches (of the height)

-- Recolours a glitter button (PLAY turns red for LEAVE, gold while you go).
function StoreKit.glitterPaint(button: GuiObject, palette: Glitter)
	local gradient = button:FindFirstChild("Glitter")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, palette.low),
			ColorSequenceKeypoint.new(0.55, palette.mid),
			ColorSequenceKeypoint.new(1, palette.high),
		})
	end
	local border = button:FindFirstChild("Border")
	if border and border:IsA("UIStroke") then
		border.Color = palette.edge
	end
	local rim = button:FindFirstChild("Rim")
	local rimLine = rim and rim:FindFirstChild("Border")
	if rimLine and rimLine:IsA("UIStroke") then
		rimLine.Color = palette.rim
	end
	button:SetAttribute("GlitterInk", palette.ink) -- for words added later
	for _, child in button:GetChildren() do
		if child:IsA("TextLabel") and child:GetAttribute("GlitterText") then
			local outline = child:FindFirstChild("TextOutline")
			if outline and outline:IsA("UIStroke") then
				outline.Color = palette.ink
			end
			if child:GetAttribute("GlitterText") == "shadow" then
				child.TextColor3 = palette.ink
			end
		end
	end
end

-- A glitter button (size it with props; its words go on with StoreKit.glitterText).
function StoreKit.glitterButton(palette: Glitter, props: UI.Props, parent: Instance?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = WHITE
	button.Text = ""
	apply(button, props)
	local height = button.Size.Y.Offset
	local radius = math.max(6, math.floor(height * 0.2))
	UI.corner(button, radius)
	UI.stroke(button, 3, palette.edge)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Glitter"
	gradient.Rotation = -28 -- from the bottom left corner to the top right one
	gradient.Parent = button

	-- Soft white glitter dots round the edges only: thick along the very edge, fading to nothing
	-- towards the middle, so the words sit on a clear patch. One layer fades in from the top and
	-- bottom edges, one from the sides; where they meet in the corners the glitter is brightest.
	local tile = math.floor(height * 0.12 * 16) -- fine glitter: about eight rows of dots
	local function dotLayer(name: string, rotation: number): UIGradient
		local dots = Instance.new("ImageLabel")
		dots.Name = name
		dots.Size = UDim2.fromScale(1, 1)
		dots.BackgroundTransparency = 1
		dots.Image = StoreKit.Images.Dots
		dots.ImageTransparency = 0.2
		dots.ScaleType = Enum.ScaleType.Tile
		dots.TileSize = UDim2.fromOffset(tile, tile)
		dots.ZIndex = 2
		dots.Active = false
		dots.Parent = button
		UI.corner(dots, radius)
		local fade = Instance.new("UIGradient")
		fade.Rotation = rotation
		fade.Parent = dots
		return fade
	end
	-- Visible at both ends, gone `band` of the way in from each.
	local function edgeFade(band: number): NumberSequence
		local into = math.clamp(band, 0.05, 0.45)
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(into, 1),
			NumberSequenceKeypoint.new(1 - into, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	local topAndBottom = dotLayer("DotsTopBottom", 90)
	local sides = dotLayer("DotsSides", 0)
	topAndBottom.Transparency = edgeFade(EDGE_BAND)
	-- The side bands are as thick as the top and bottom ones, whatever the button's shape.
	local function fitSides()
		local size = button.AbsoluteSize
		if size.X > 0 then
			sides.Transparency = edgeFade(EDGE_BAND * size.Y / size.X)
		end
	end
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSides)
	sides.Transparency = edgeFade(EDGE_BAND * height / math.max(button.Size.X.Offset, height))

	-- A light band across the top.
	local sheen = UI.frame({
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Active = false,
	}, button)
	UI.corner(sheen, radius)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.66),
		NumberSequenceKeypoint.new(0.42, 0.9),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = sheen

	-- The pale line just inside the dark outline.
	local rim = UI.frame({
		Name = "Rim",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Active = false,
	}, button)
	UI.corner(rim, math.max(radius - 2, 4))
	local rimLine = UI.stroke(rim, 1.8, palette.rim)
	rimLine.Transparency = 0.12

	StoreKit.glitterPaint(button, palette)

	-- It squishes when you point at it and press it, and clicks.
	local squish = Instance.new("UIScale")
	squish.Name = "Squish"
	squish.Parent = button
	local function scaleTo(value: number)
		TweenService:Create(squish, TweenInfo.new(0.08), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		scaleTo(1.04)
	end)
	button.MouseLeave:Connect(function()
		scaleTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		scaleTo(0.95)
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(1)
	end)
	button.Activated:Connect(function()
		Sounds.play("Click")
	end)
	button.Parent = parent
	return button
end

-- White rounded words on a glitter button, with a dark outline and a drop shadow under them that
-- follows them about. `maxSize` (with TextScaled) keeps them from growing too big.
function StoreKit.glitterText(button: TextButton, props: UI.Props, maxSize: number?): TextLabel
	local label = UI.label({
		FontFace = UI.Fonts.Button,
		TextWrapped = false,
		ZIndex = 7,
	})
	apply(label, props)
	if maxSize then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = label
	end
	UI.textStroke(label, 3)
	local ink = button:GetAttribute("GlitterInk")
	local outline = label:FindFirstChild("TextOutline")
	if typeof(ink) == "Color3" and outline and outline:IsA("UIStroke") then
		outline.Color = ink
	end
	label:SetAttribute("GlitterText", "words")
	local shadow = label:Clone()
	shadow.Name = "Shadow"
	shadow.ZIndex = 6
	shadow.TextTransparency = 0.1
	if typeof(ink) == "Color3" then
		shadow.TextColor3 = ink
	end
	shadow:SetAttribute("GlitterText", "shadow")
	local function place()
		shadow.AnchorPoint = label.AnchorPoint
		shadow.Size = label.Size
		shadow.Position = label.Position + UDim2.fromOffset(0, DROP)
	end
	place()
	label:GetPropertyChangedSignal("Position"):Connect(place)
	label:GetPropertyChangedSignal("Size"):Connect(place)
	for _, key in { "Text", "TextSize", "Visible" } do
		label:GetPropertyChangedSignal(key :: any):Connect(function()
			(shadow :: any)[key] = (label :: any)[key]
		end)
	end
	shadow.Parent = button
	label.Parent = button
	return label
end

-- A glitter button with a picture on the left (an image id, or an ItemModels id for a little
-- turning 3D model) and its name beside it. Returns the button and the name's label.
function StoreKit.glitterIconButton(
	text: string,
	icon: string,
	palette: Glitter,
	props: UI.Props,
	parent: Instance?
): (TextButton, TextLabel)
	local button = StoreKit.glitterButton(palette, props)
	local height = button.Size.Y.Offset
	local picture: UI.Props = {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(height * 0.66, height * 0.66),
		ZIndex = 7,
	}
	local room = height * 0.66 + 20
	if icon:sub(1, 13) == "rbxassetid://" then
		StoreKit.image(icon, picture, button)
	else
		picture.Position = UDim2.new(0, 4, 0.5, 0)
		picture.Size = UDim2.fromOffset(height * 0.9, height * 0.9)
		ItemModels.viewport(icon, picture, button, true)
		room = height * 0.9 + 10
	end
	local label = StoreKit.glitterText(button, {
		Position = UDim2.fromOffset(room, 0),
		Size = UDim2.new(1, -room - 12, 1, -DROP),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	}, math.floor(height * 0.5))
	button.Parent = parent
	return button, label
end

return StoreKit
