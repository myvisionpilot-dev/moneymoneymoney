--!strict
-- The CUSTOMISATION window (menu bar): every cosmetic Cred buys, a tab per slot (paint,
-- underglow, trails, auras, bags, blasters, zap colours, bank bursts). Tap a card to see it big on
-- the stage on the left, in light rays of its rarity: a race car turns there in your paint and
-- underglow, trying on whatever you picked. The stage's button buys it, wears it or takes it
-- off; buying something new sets off a reveal. Epic and legendary cards catch the light.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Format = require(Shared:WaitForChild("Format"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)
local ShopFrame = require(script.Parent.ShopFrame)

local WINDOW_WIDTH = 900
local STAGE_WIDTH = 240
local CARD_SIZE = UDim2.fromOffset(110, 152)
local CARD_GAP = 8
local ART_HEIGHT = 92
local STAGE_BELOW = 112 -- the name, caption and button under the stage
local TURN_SPEED = 0.6 -- radians a second

local TABS: { ShopFrame.Tab } = {}
for _, info in Cosmetics.Slots do
	table.insert(TABS, { key = info.slot :: string, text = info.name })
end

type Turning = { camera: Camera, center: Vector3, across: number, height: number, angle: number }

local CustomiseWindow = {}

local turning: { [ViewportFrame]: Turning } = setmetatable({}, { __mode = "k" }) :: any

-- Frames the model from a three-quarter angle in `view` (replacing what was there), turning.
local function show(view: ViewportFrame, model: Model, zoom: number?)
	view:ClearAllChildren()
	model.Parent = view
	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local distance = size.Magnitude / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * (zoom or 0.9)
	local direction = Vector3.new(1.1, 0.7, -1.3).Unit * distance
	camera.CFrame = CFrame.lookAt(box.Position + direction, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	turning[view] = {
		camera = camera,
		center = box.Position,
		across = Vector2.new(direction.X, direction.Z).Magnitude,
		height = direction.Y,
		angle = math.atan2(direction.X, direction.Z),
	}
end

local function newViewport(props: UI.Props, parent: Instance): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(170, 170, 180)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -2, -1)
	for key, value in props do
		(view :: any)[key] = value
	end
	view.Parent = parent
	return view
end

-- A race car in a paint, with an underglow: a neon strip under it and a pool of light on the
-- ground (a viewport has no real light, so the pool shows the colour).
local function car(paint: Cosmetics.Item?, glow: Cosmetics.Item?): Model
	local model = ItemModels.model("RaceCar", paint) :: Model
	if glow then
		local box, size = model:GetBoundingBox()
		local ground = box.Position.Y - size.Y / 2
		local strip = Instance.new("Part")
		strip.Name = "Underglow"
		strip.Anchored = true
		strip.Size = Vector3.new(size.X + 0.3, 0.1, size.Z + 0.3)
		strip.CFrame = CFrame.new(box.Position.X, ground + 0.08, box.Position.Z)
		strip.Material = Enum.Material.Neon
		strip.Color = glow.color
		strip.Parent = model
		local pool = Instance.new("Part")
		pool.Name = "GlowPool"
		pool.Anchored = true
		pool.Shape = Enum.PartType.Cylinder
		local across = math.max(size.X, size.Z) * 1.15
		pool.Size = Vector3.new(0.05, across, across)
		pool.CFrame = CFrame.new(box.Position.X, ground - 0.05, box.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		pool.Material = Enum.Material.Neon
		pool.Color = glow.color
		pool.Transparency = 0.45
		pool.Parent = model
		if glow.rainbow then
			strip:AddTag("RainbowGlow")
			pool:AddTag("RainbowGlow")
		end
	end
	return model
end

-- A streak in the trail's colours (trails have no 3D picture). `scale` 1 fills ~100 pixels.
local function trailArt(art: GuiObject, item: Cosmetics.Item, scale: number)
	for index, info in { { 0.62, 18 }, { 0.42, 10 }, { 0.8, 8 } } do
		local streak = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, info[1]),
			Size = UDim2.fromOffset((90 - index * 10) * scale, info[2] * scale),
			Rotation = -12,
			ZIndex = 2,
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, art)
		UI.corner(streak, info[2] * scale)
		local gradient = Instance.new("UIGradient")
		gradient.Color = Cosmetics.sequence(item.colors or { item.color })
		gradient.Transparency = NumberSequence.new(0, 0.85)
		gradient.Parent = streak
	end
end

-- A starburst of dots in the burst's colours.
local function burstArt(art: GuiObject, item: Cosmetics.Item, scale: number)
	local colors = item.colors or { item.color }
	for index = 0, 13 do
		local angle = index / 14 * math.pi * 2
		local reach = (if index % 2 == 0 then 28 else 18) * scale
		local size = (if index % 3 == 0 then 11 else 7) * scale
		local dot = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * reach, 0.5, math.sin(angle) * reach),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 2,
			BackgroundColor3 = colors[index % #colors + 1],
		}, art)
		UI.corner(dot, size)
		UI.stroke(dot, 1.5)
	end
end

-- An aura's picture: a little figure in a soft glow of its colour, with sparks rising round it
-- (they keep rising: see the RenderStepped below).
type Riser = { x: number, phase: number, speed: number }
local risers: { [Frame]: Riser } = setmetatable({}, { __mode = "k" }) :: any

local function auraArt(art: GuiObject, item: Cosmetics.Item, scale: number)
	UI.glow(item.color, {
		Size = UDim2.fromOffset(120 * scale, 120 * scale),
		ImageTransparency = 0.2,
		ZIndex = 2,
	}, art)
	local body = UI.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.88),
		Size = UDim2.fromOffset(22 * scale, 30 * scale),
		BackgroundColor3 = UI.Colors.Ink,
		ZIndex = 3,
	}, art)
	UI.corner(body, 7 * scale)
	local head = UI.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.88, -33 * scale),
		Size = UDim2.fromOffset(16 * scale, 16 * scale),
		BackgroundColor3 = UI.Colors.Ink,
		ZIndex = 3,
	}, art)
	UI.corner(head, 8 * scale)
	for index = 1, 12 do
		local size = math.random(4, 8) * scale
		local spark = UI.frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = if index % 3 == 0 then Color3.new(1, 1, 1) else item.color,
			ZIndex = 4,
		}, art)
		UI.corner(spark, size)
		risers[spark] = { x = (math.random() - 0.5) * 0.6, phase = math.random(), speed = 0.4 + math.random() * 0.5 }
	end
end

-- Light rays behind the stage in the rarity's colour.
local RAY_COLORS: { [Cosmetics.Tier]: Color3 } = {
	Common = Color3.new(1, 1, 1),
	Rare = Color3.fromRGB(150, 255, 170),
	Epic = Color3.fromRGB(220, 160, 255),
	Legendary = Color3.fromRGB(255, 220, 110),
}

local function worn(view: Types.ProfileView, slot: Cosmetics.Slot): Cosmetics.Item?
	local id = view.equipped[slot]
	return if id then Cosmetics.get(id) else nil
end

-- The picture of an item: a turning model, or drawn art for trails and bursts. The stage passes
-- the profile so the car also wears your other car cosmetic.
local function picture(parent: GuiObject, item: Cosmetics.Item, scale: number, view: Types.ProfileView?)
	if item.slot == "Trail" then
		trailArt(parent, item, scale)
		return
	elseif item.slot == "Burst" then
		burstArt(parent, item, scale)
		return
	elseif item.slot == "Aura" then
		auraArt(parent, item, scale)
		return
	end
	local model: Model?
	if item.slot == "Paint" then
		model = car(item, if view then worn(view, "Glow") else nil)
	elseif item.slot == "Glow" then
		model = car(if view then worn(view, "Paint") else nil, item)
	elseif item.slot == "Zap" then
		local blaster = if view then worn(view, "Blaster") else nil
		model = ItemModels.model(if blaster and blaster.model then blaster.model else "Zapper", item)
	elseif item.slot == "Blaster" then
		model = ItemModels.model(item.model or "Zapper", if view then worn(view, "Zap") else nil)
	else
		model = ItemModels.model(item.model or "Sack")
	end
	if model then
		-- On the stage it fills more of the frame (a bag less so: the sacks are tall).
		local zoom = if not view then nil elseif item.slot == "Bag" then 0.85 else 0.72
		show(newViewport({ Size = UDim2.fromScale(1, 1), ZIndex = 2 }, parent), model, zoom)
	end
end

function CustomiseWindow.start(root: Frame): UI.Window
	local remotes = Remotes.lobby()
	local currentSlot: Cosmetics.Slot = "Paint"
	local picked: { [string]: string } = {} -- slot -> the card you tapped
	local toTop = true
	local render: () -> ()

	local shop = ShopFrame.new(root, "CUSTOMISATION", WINDOW_WIDTH, TABS, function(key: string)
		currentSlot = key :: Cosmetics.Slot
		toTop = true
		render()
	end)
	local window = shop.window
	local columns = UI.list(window.body, Enum.FillDirection.Horizontal, 12)
	columns.VerticalAlignment = Enum.VerticalAlignment.Top

	-- The stage: the picked item, big, with its name and the button.
	local side = UI.frame({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(STAGE_WIDTH, 300),
		BackgroundTransparency = 1,
	}, window.body)
	local stage = UI.frame({
		Size = UDim2.new(1, 0, 1, -STAGE_BELOW),
		BackgroundColor3 = Color3.fromRGB(26, 42, 92),
	}, side)
	UI.corner(stage, 14)
	UI.stroke(stage, 3)
	local stageRays: Instance = UI.rays(stage, 420, nil, 14)
	local stageArt = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, stage)
	local stageTier = UI.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.5, -10, 0, 18),
		ZIndex = 3,
		FontFace = UI.Fonts.Heading,
		TextSize = 13,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, stage)
	local stageWorn = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.new(0.5, -10, 0, 18),
		ZIndex = 3,
		FontFace = UI.Fonts.Heading,
		TextSize = 13,
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "WEARING",
	}, stage)
	local itemName = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -82),
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
	}, side)
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 26
	nameLimit.Parent = itemName
	local caption = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(1, 0, 0, 32),
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
	}, side)
	local action = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 42),
		TextSize = 20,
		Text = "",
	}, side)
	local onAction: () -> () = function() end
	action.Activated:Connect(function()
		onAction()
	end)

	local list = ShopFrame.scroller({ LayoutOrder = 2, Size = UDim2.new(1, -STAGE_WIDTH - 12, 0, 300) }, window.body)
	UI.padding(list, 4)
	local layout = UI.grid(list, CARD_SIZE, CARD_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local borders: { [string]: UIStroke } = {}

	local function pickedItem(view: Types.ProfileView): Cosmetics.Item?
		local id = picked[currentSlot]
		local item = if id then Cosmetics.get(id) else nil
		if item then
			return item
		end
		item = worn(view, currentSlot)
		if item then
			return item
		end
		for _, entry in Cosmetics.Items do
			if entry.slot == currentSlot then
				return entry
			end
		end
		return nil
	end

	local function renderStage(view: Types.ProfileView)
		local item = pickedItem(view)
		stageArt:ClearAllChildren()
		for id, border in borders do
			local selected = item ~= nil and item.id == id
			border.Color = if selected then Color3.new(1, 1, 1) else UI.Colors.Ink
			border.Thickness = if selected then 4 else 3
		end
		if not item then
			return
		end
		stageRays:Destroy()
		stageRays = UI.rays(stage, 420, RAY_COLORS[item.tier], 14)
		picture(stageArt, item, 2.2, view)
		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		stageTier.Text = item.tier:upper()
		stageTier.TextColor3 = Cosmetics.TierColors[item.tier]
		stageWorn.Visible = wearing
		itemName.Text = item.name
		local slotText = ""
		for _, info in Cosmetics.Slots do
			if info.slot == item.slot then
				slotText = info.text
			end
		end
		caption.Text = slotText
		local id = item.id
		if wearing then
			action.Text = "TAKE OFF"
			action.BackgroundColor3 = UI.Colors.PanelDark
			onAction = function()
				remotes.EquipCosmetic:fire(id)
			end
		elseif owned then
			action.Text = "WEAR"
			action.BackgroundColor3 = UI.Colors.Money
			onAction = function()
				remotes.EquipCosmetic:fire(id)
			end
		else
			local text, color, affordable = ShopFrame.buyLook(view.cred, Cosmetics.price(item))
			action.Text = `BUY  {text}`
			action.BackgroundColor3 = color
			onAction = function()
				if affordable then
					remotes.BuyCredItem:fire(id)
				else
					Sounds.play("Fail", 1, 0.6)
				end
			end
		end
	end

	local function card(order: number, item: Cosmetics.Item, view: Types.ProfileView)
		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		local panel, frame =
			UI.panel(Cosmetics.TierColors[item.tier], { LayoutOrder = order }, list, CARD_SIZE.Y.Offset)
		local border = panel:FindFirstChild("Border")
		if border and border:IsA("UIStroke") then
			borders[item.id] = border
		end
		local art = UI.frame({
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, ART_HEIGHT),
			BackgroundTransparency = 1,
		}, frame)
		UI.rays(art, 170, RAY_COLORS[item.tier], 10)
		picture(art, item, 0.85, nil)
		-- The rarest cards catch the light now and then.
		if item.tier == "Legendary" then
			UI.shine(panel, 2.5 + math.random(), 12)
		elseif item.tier == "Epic" then
			UI.shine(panel, 5 + math.random() * 2, 12)
		end
		UI.label({
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0, 14),
			ZIndex = 3,
			FontFace = UI.Fonts.Heading,
			TextSize = 10,
			TextColor3 = UI.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = item.tier:upper(),
		}, art)
		local name = UI.label({
			Position = UDim2.fromOffset(4, ART_HEIGHT + 9),
			Size = UDim2.new(1, -8, 0, 18),
			FontFace = UI.Fonts.Heading,
			TextScaled = true,
			Text = item.name,
		}, frame)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 14
		limit.Parent = name
		UI.label({
			Position = UDim2.fromOffset(4, ART_HEIGHT + 30),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = if owned then UI.Fonts.Heading else UI.Fonts.Number,
			TextSize = if owned then 13 else 16,
			TextColor3 = if wearing then UI.Colors.Gold elseif owned then UI.Colors.Muted else UI.Colors.Text,
			Text = if wearing
				then "WEARING"
				elseif owned then "OWNED"
				else `{Format.number(Cosmetics.price(item))} Cred`,
		}, frame)
		-- The whole card is the button that puts it on the stage.
		local hit = Instance.new("TextButton")
		hit.Name = "Pick"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 5
		hit.Parent = frame
		hit.Activated:Connect(function()
			picked[currentSlot] = item.id
			Sounds.play("Click")
			UI.pop(panel, 0.05)
			if ProfileState.view then
				renderStage(ProfileState.view)
			end
		end)
	end

	function render()
		local view = ProfileState.view
		if not view or not window.panel.Visible then
			return
		end
		shop.cred.Text = Format.cred(view.cred)
		ShopFrame.showTab(shop, currentSlot)
		local height = shop.bodyHeight()
		side.Size = UDim2.fromOffset(STAGE_WIDTH, height)
		list.Size = UDim2.new(1, -STAGE_WIDTH - 12, 0, height)
		local scroll = if toTop then Vector2.zero else list.CanvasPosition
		toTop = false
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(borders)
		local order = 0
		for _, item in Cosmetics.Items do
			if item.slot == currentSlot then
				order += 1
				card(order, item, view)
			end
		end
		list.CanvasPosition = scroll -- buying something shouldn't jump you back to the top
		renderStage(view)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		for view, turn in turning do
			if view.Parent and view.Visible then
				turn.angle += dt * TURN_SPEED
				local offset =
					Vector3.new(math.sin(turn.angle) * turn.across, turn.height, math.cos(turn.angle) * turn.across)
				turn.camera.CFrame = CFrame.lookAt(turn.center + offset, turn.center)
			end
		end
		-- Aura pictures: sparks drifting up round the little figure, over and over.
		local now = os.clock()
		for spark, riser in risers do
			if spark.Parent then
				local t = (now * riser.speed + riser.phase) % 1
				spark.Position =
					UDim2.fromScale(0.5 + riser.x + math.sin(t * 6 + riser.phase * 6) * 0.04, 0.9 - t * 0.75)
				spark.BackgroundTransparency = t * t
			end
		end
	end)

	-- Something new: the rarity's colour floods the screen, stars burst off the stage, a banner
	-- names it (and a legendary rains coins).
	local function reveal(item: Cosmetics.Item)
		local color = Cosmetics.TierColors[item.tier]
		local middle = stage.AbsolutePosition + stage.AbsoluteSize / 2
		local big = item.tier == "Epic" or item.tier == "Legendary"
		ScreenFx.flash(color, if big then 0.3 else 0.18)
		ScreenFx.stars(middle, if big then 30 else 18, color)
		ScreenFx.stars(middle, 10, Color3.new(1, 1, 1))
		ScreenFx.banner(`NEW {item.tier:upper()}!`, color, item.name, 1.8, 0.2)
		Sounds.play(if big then "Fanfare" else "Milestone")
		if item.tier == "Legendary" then
			ScreenFx.rain(45)
		end
		UI.pop(stage, 0.12)
	end

	window.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		toTop = true
		render()
	end)
	local lastCred: number? = nil
	local lastOwned: { [string]: boolean }? = nil
	ProfileState.changed:Connect(function(view: Types.ProfileView)
		render()
		if window.panel.Visible and lastCred and lastCred ~= view.cred then
			UI.pop(shop.cred, 0.3)
		end
		lastCred = view.cred
		local owned: { [string]: boolean } = {}
		for _, id in view.owned do
			owned[id] = true
			local item = Cosmetics.get(id)
			if lastOwned and not lastOwned[id] and item and window.panel.Visible then
				reveal(item)
			end
		end
		lastOwned = owned
	end)
	return window
end

return CustomiseWindow
