--!strict
-- Wears your equipped cosmetics (both places): a hat and a trail built from plain parts, and a
-- title over your head. Rebuilt on every spawn and whenever you change them. Kart paint is
-- read by VehicleService through Cosmetics.paint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Profiles = require(script.Parent.Profiles)

local FOLDER_NAME = "Cosmetics" -- inside the character: hat parts
local TITLE_NAME = "CosmeticTitle" -- on the head
local TRAIL_NAME = "CosmeticTrail" -- on the root, with its two attachments
local QUARTER_TURN = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder upright

local Cosmetics = {}

local function equipped(player: Player, slot: Catalog.Slot): Catalog.Cosmetic?
	local data = Profiles.get(player)
	local id = data and data.Equipped[slot]
	if not data or not id or id == "" or not data.Owned[id] then
		return nil
	end
	local item = Catalog.cosmetic(id)
	return if item and item.slot == slot then item else nil
end

function Cosmetics.paint(player: Player): Color3?
	local item = equipped(player, "Paint")
	return if item then item.colors[1] else nil
end

local function hatPiece(
	folder: Instance,
	head: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = "HatPiece"
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function buildHat(item: Catalog.Cosmetic, head: BasePart, folder: Instance)
	local width = head.Size.X
	local top = head.Size.Y / 2
	local color = item.colors[1]
	if item.hat == "Cap" then
		hatPiece(
			folder,
			head,
			Vector3.one * width * 1.05,
			CFrame.new(0, top - width * 0.25, 0),
			color,
			Enum.PartType.Ball
		)
		hatPiece(
			folder,
			head,
			Vector3.new(width * 0.9, 0.12, width * 0.55),
			CFrame.new(0, top - 0.05, -width * 0.6),
			color
		)
	elseif item.hat == "TopHat" then
		local cylinder = Enum.PartType.Cylinder
		hatPiece(
			folder,
			head,
			Vector3.new(0.12, width * 1.5, width * 1.5),
			CFrame.new(0, top, 0) * QUARTER_TURN,
			color,
			cylinder
		)
		hatPiece(
			folder,
			head,
			Vector3.new(width * 0.9, width * 0.95, width * 0.95),
			CFrame.new(0, top + width * 0.45, 0) * QUARTER_TURN,
			color,
			cylinder
		)
		hatPiece(
			folder,
			head,
			Vector3.new(width * 0.15, width * 0.97, width * 0.97),
			CFrame.new(0, top + width * 0.12, 0) * QUARTER_TURN,
			Color3.fromRGB(200, 40, 50),
			cylinder
		)
	elseif item.hat == "Crown" then
		hatPiece(
			folder,
			head,
			Vector3.new(width * 0.3, width * 0.95, width * 0.95),
			CFrame.new(0, top + width * 0.1, 0) * QUARTER_TURN,
			color,
			Enum.PartType.Cylinder
		)
		for index = 0, 4 do
			local angle = math.rad(index * 72)
			local offset = Vector3.new(math.sin(angle), 0, -math.cos(angle)) * width * 0.4
			hatPiece(
				folder,
				head,
				Vector3.new(width * 0.15, width * 0.3, width * 0.15),
				CFrame.new(offset + Vector3.new(0, top + width * 0.35, 0)),
				color
			)
		end
		hatPiece(
			folder,
			head,
			Vector3.one * width * 0.14,
			CFrame.new(0, top + width * 0.1, -width * 0.48),
			Color3.fromRGB(220, 40, 60)
		)
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			part.Material = if item.hat == "Crown" then Enum.Material.Metal else Enum.Material.SmoothPlastic
		end
	end
end

local function buildTitle(player: Player, item: Catalog.Cosmetic, head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = TITLE_NAME
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.PlayerToHideFrom = player
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = item.colors[1]
	label.TextStrokeTransparency = 0.3
	label.Text = item.text or item.name
	label.Parent = gui
	gui.Parent = head
end

local function buildTrail(item: Catalog.Cosmetic, root: BasePart)
	local top = Instance.new("Attachment")
	top.Name = TRAIL_NAME .. "Top"
	top.Position = Vector3.new(0, 0.9, 0.6)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_NAME .. "Bottom"
	bottom.Position = Vector3.new(0, -0.9, 0.6)
	bottom.Parent = root

	local keypoints = {}
	for index, color in item.colors do
		local time = if #item.colors == 1 then 0 else (index - 1) / (#item.colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, item.colors[1]))
	end
	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.5
	trail.LightEmission = 0.4
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.FaceCamera = true
	trail.Parent = root
end

local function clear(character: Model)
	for _, descendant in character:GetDescendants() do
		local name = descendant.Name
		if
			(descendant:IsA("Folder") and name == FOLDER_NAME)
			or name == TITLE_NAME
			or name == TRAIL_NAME
			or name == TRAIL_NAME .. "Top"
			or name == TRAIL_NAME .. "Bottom"
		then
			descendant:Destroy()
		end
	end
end

function Cosmetics.refresh(player: Player)
	local character = player.Character
	if not character then
		return
	end
	clear(character)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	local hat = equipped(player, "Hat")
	if hat then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		buildHat(hat, head, folder)
		folder.Parent = character
	end
	local title = equipped(player, "Title")
	if title then
		buildTitle(player, title, head)
	end
	local trail = equipped(player, "Trail")
	if trail then
		buildTrail(trail, root)
	end
end

function Cosmetics.start()
	Profiles.loaded:Connect(Cosmetics.refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Head", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			Cosmetics.refresh(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Cosmetics
