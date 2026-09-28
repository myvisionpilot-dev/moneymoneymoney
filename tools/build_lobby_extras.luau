-- Adds the Milestone 3 lobby pieces (Lobby place, command bar or MCP): the cosmetics stand and
-- two leaderboard boards. Rebuilds only Workspace.LobbyExtras, so hand-made lobby parts stay.
--
-- Tags the code looks for:
--   CosmeticShop                     the stand's counter (hold E to browse)
--   Leaderboard (+ Board attribute)  "Cred" or "Quota"

local CollectionService = game:GetService("CollectionService")

local FLOOR_Y = -1.5 -- top of the lobby floor

local old = workspace:FindFirstChild("LobbyExtras")
if old then
	old:Destroy()
end
local extras = Instance.new("Folder")
extras.Name = "LobbyExtras"
extras.Parent = workspace

local function part(name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = extras
	return p
end

local function label(target, text, height, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
	gui.Parent = target
end

-- Cosmetics stand on the east side, facing the middle of the lobby.
local standX, standZ = 40, 22
local counter = part(
	"CosmeticsCounter",
	Vector3.new(4, 4, 12),
	Vector3.new(standX, FLOOR_Y + 2, standZ),
	Color3.fromRGB(150, 90, 200),
	Enum.Material.SmoothPlastic
)
CollectionService:AddTag(counter, "CosmeticShop")
label(counter, "COSMETICS\nspend your Cred", 9, Color3.fromRGB(255, 196, 50))
for index, z in { standZ - 6, standZ + 6 } do
	part(
		`AwningPost{index}`,
		Vector3.new(0.8, 10, 0.8),
		Vector3.new(standX + 1.5, FLOOR_Y + 5, z),
		Color3.fromRGB(235, 235, 235)
	)
end
part("Awning", Vector3.new(7, 0.8, 14), Vector3.new(standX, FLOOR_Y + 10.4, standZ), Color3.fromRGB(255, 196, 50))
-- A row of paint samples on the counter.
for index, color in
	{
		Color3.fromRGB(220, 40, 50),
		Color3.fromRGB(40, 110, 220),
		Color3.fromRGB(140, 220, 60),
		Color3.fromRGB(30, 30, 45),
		Color3.fromRGB(255, 196, 50),
	}
do
	local sample = part(
		`Sample{index}`,
		Vector3.new(1.2, 1.2, 1.2),
		Vector3.new(standX, FLOOR_Y + 4.6, standZ - 5 + index * 1.7),
		color
	)
	sample.Shape = Enum.PartType.Ball
	sample.CanCollide = false
end

-- Leaderboards behind the queue pads, facing the spawn.
local BOARD_SIZE = Vector3.new(18, 21, 1) -- matches the sign's 600 x 700 canvas
for _, info in { { "Cred", -30 }, { "Quota", 12 } } do
	local board, x = info[1], info[2]
	local position = Vector3.new(x, FLOOR_Y + 1 + BOARD_SIZE.Y / 2, -40)
	part(`{board}BoardBase`, Vector3.new(20, 1, 3), Vector3.new(x, FLOOR_Y + 0.5, -40), Color3.fromRGB(60, 60, 66))
	local sign =
		part(`{board}Board`, BOARD_SIZE, CFrame.lookAt(position, position + Vector3.zAxis), Color3.fromRGB(22, 28, 24))
	sign:SetAttribute("Board", board)
	CollectionService:AddTag(sign, "Leaderboard")
end

return "Lobby extras built: cosmetics stand and 2 leaderboards"
