--!strict
-- The Customise window (menu bar), in the store look (StoreKit): every cosmetic Cred buys, a picture tab per slot (paint,
-- underglow, trails, auras, bags, bank bursts). Each is a store card in
-- its rarity's colour, sunburst rays behind its picture, with its price on a green button. Tap
-- one to see it big on the stage on the left: a race car turns there in your paint and
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
local StoreKit = require(Shared:WaitForChild("StoreKit"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ProfileState = require(script.Parent.ProfileState)
local ShopFrame = require(script.Parent.ShopFrame)

local WINDOW_WIDTH = 900
local STAGE_WIDTH = 240
local CARD_SIZE = UDim2.fromOffset(112, 166) -- five across
local CARD_GAP = 8
local ART_TOP = 22
local ART_HEIGHT = 86
local STAGE_ABOVE = 0 -- room over the stage (your Cred is on the title bar now)
local STAGE_BELOW = 112 -- the name, caption and button under the stage
local TURN_SPEED = 0.6 -- radians a second

type Turning = { camera: Camera, center: Vector3, across: number, height: number, angle: number }

local CustomiseWindow = {}

-- A plain table, emptied as views are destroyed: a weak-keyed one let Luau drop views that were
-- still on screen, and their pictures stopped turning.
local turning: { [ViewportFrame]: Turning } = {}

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
	if not turning[view] then
		view.Destroying:Once(function()
			turning[view] = nil
		end)
	end
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
		Size = UDim2.fromOffset(150 * scale, 150 * scale),
		ImageTransparency = 0,
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
	else
		model = ItemModels.model(item.model or "Sack")
	end
	if model then
		-- On the stage it fills more of the frame (a bag less so: the sacks are tall).
		local zoom = if not view then nil elseif item.slot == "Bag" then 0.85 else 0.72
		show(newViewport({ Size = UDim2.fromScale(1, 1), ZIndex = 2 }, parent), model, zoom)
	end
end

-- A tab per slot, its picture the slot's first item (short names, to fit under the tabs).
local SHORT_NAMES: { [string]: string } = { Glow = "Glow", Burst = "Bursts" }

local function slotTabs(): { ShopFrame.Tab }
	local tabs: { ShopFrame.Tab } = {}
	for _, info in Cosmetics.Slots do
		local first: Cosmetics.Item? = nil
		for _, item in Cosmetics.Items do
			if item.slot == info.slot then
				first = item
				break
			end
		end
		table.insert(tabs, {
			key = info.slot :: string,
			text = SHORT_NAMES[info.slot] or info.name,
			draw = function(art: Frame)
				if first then
					picture(art, first, 0.42, nil)
				end
			end,
		})
	end
	return tabs
end

function CustomiseWindow.start(root: Frame): UI.Window
	local remotes = Remotes.lobby()
	local currentSlot: Cosmetics.Slot = "Paint"
	local picked: { [string]: string } = {} -- slot -> the card you tapped
	local toTop = true
	local render: () -> ()

	local shop = ShopFrame.new(root, "Customise", WINDOW_WIDTH, slotTabs(), function(key: string)
		currentSlot = key :: Cosmetics.Slot
		toTop = true
		render()
	end)
	local window = shop.window
	window.title.TextSize = 34
	local columns = UI.list(window.body, Enum.FillDirection.Horizontal, 12)
	columns.VerticalAlignment = Enum.VerticalAlignment.Top

	-- The stage: your Cred, the picked item big on a card of its rarity, its name and the button.
	local side = UI.frame({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(STAGE_WIDTH, 300),
		BackgroundTransparency = 1,
	}, window.body)
	local stage = UI.frame({
		Position = UDim2.fromOffset(0, STAGE_ABOVE),
		Size = UDim2.new(1, 0, 1, -STAGE_BELOW - STAGE_ABOVE),
		BackgroundColor3 = Cosmetics.TierColors["Common" :: Cosmetics.Tier],
	}, side)
	UI.corner(stage, 14)
	local stageBorder = UI.stroke(stage, 4)
	UI.gradient(stage, 0.16)
	local stageRays: CanvasGroup = UI.rays(stage, 520, nil, 14, Vector2.new(0.5, 0.55))
	local stageArt = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, stage)
	local stageTier = UI.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.5, -10, 0, 20),
		ZIndex = 3,
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, stage)
	local stageWorn = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.new(0.5, -10, 0, 20),
		ZIndex = 3,
		FontFace = UI.Fonts.Heading,
		TextSize = 16,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "WEARING",
	}, stage)
	local itemName = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -80),
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = UI.Fonts.Title,
		TextScaled = true,
	}, side)
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 28
	nameLimit.Parent = itemName
	UI.textStroke(itemName, 3)
	local caption = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(1, 0, 0, 32),
		TextSize = 14,
	}, side)
	local action = StoreKit.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 22,
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

	local borders: { [string]: { stroke: UIStroke, color: Color3 } } = {} -- each card's outline, and its own colour

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
			border.stroke.Color = if selected then Color3.new(1, 1, 1) else border.color
			border.stroke.Thickness = if selected then 4.5 else 3.5
		end
		if not item then
			return
		end
		-- The stage turns the rarity's colour, rays and all.
		local color = Cosmetics.TierColors[item.tier]
		stage.BackgroundColor3 = color
		stageBorder.Color = UI.shade(color, 0.5)
		stageRays:Destroy()
		stageRays = UI.rays(stage, 520, color:Lerp(Color3.new(1, 1, 1), 0.6), 14, Vector2.new(0.5, 0.55))
		picture(stageArt, item, 2.2, view)
		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		stageTier.Text = item.tier:upper()
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
			ShopFrame.wordButton(action, "TAKE OFF", UI.Colors.PanelDark)
			onAction = function()
				remotes.EquipCosmetic:fire(id)
			end
		elseif owned then
			ShopFrame.wordButton(action, "WEAR", UI.Colors.Money)
			onAction = function()
				remotes.EquipCosmetic:fire(id)
			end
		else
			local affordable = ShopFrame.priceButton(action, view.cred, Cosmetics.price(item))
			onAction = function()
				if affordable then
					remotes.BuyCredItem:fire(id)
				else
					Sounds.play("Fail", 1, 0.6)
				end
			end
		end
	end

	-- A store card: name on top, the picture in its rays, the price (or WEARING / OWNED) on a
	-- button along the bottom. The whole card picks it for the stage.
	local function card(order: number, item: Cosmetics.Item, view: Types.ProfileView)
		local owned = table.find(view.owned, item.id) ~= nil
		local wearing = view.equipped[item.slot] == item.id
		local color = Cosmetics.TierColors[item.tier]
		local panel, frame = StoreKit.card(
			color,
			{ LayoutOrder = order },
			list,
			Vector2.new(0.5, (ART_TOP + ART_HEIGHT / 2) / CARD_SIZE.Y.Offset),
			260
		)
		local border = panel:FindFirstChild("Border")
		if border and border:IsA("UIStroke") then
			borders[item.id] = { stroke = border, color = border.Color }
		end
		local name = StoreKit.label({
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.new(1, -8, 0, 20),
			TextScaled = true,
			Text = item.name,
		}, frame)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 16
		limit.Parent = name
		UI.textStroke(name, 2)
		local art = UI.frame({
			Position = UDim2.fromOffset(6, ART_TOP),
			Size = UDim2.new(1, -12, 0, ART_HEIGHT),
			BackgroundTransparency = 1,
		}, frame)
		picture(art, item, 0.85, nil)
		-- The rarest cards catch the light now and then.
		if item.tier == "Legendary" then
			UI.shine(panel, 2.5 + math.random(), 14)
		elseif item.tier == "Epic" then
			UI.shine(panel, 5 + math.random() * 2, 14)
		end
		StoreKit.label({
			Position = UDim2.fromOffset(4, ART_TOP + ART_HEIGHT - 2),
			Size = UDim2.new(1, -8, 0, 14),
			TextSize = 11,
			TextColor3 = Color3.fromRGB(255, 245, 200),
			Text = item.tier:upper(),
		}, frame)
		local price = StoreKit.button({
			Name = "Price",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -14, 0, 30),
			Active = false,
			AutoButtonColor = false,
		}, frame)
		if wearing then
			ShopFrame.wordButton(price, "WEARING", UI.Colors.Gold)
		elseif owned then
			ShopFrame.wordButton(price, "OWNED", UI.Colors.PanelDark)
		else
			ShopFrame.priceButton(price, view.cred, Cosmetics.price(item))
		end
		-- The whole card is the button that puts it on the stage.
		local hit = Instance.new("TextButton")
		hit.Name = "Pick"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 6
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
		shop.cred.Text = Format.number(view.cred)
		ShopFrame.showTab(shop, currentSlot)
		local height = shop.bodyHeight() + STAGE_ABOVE
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
