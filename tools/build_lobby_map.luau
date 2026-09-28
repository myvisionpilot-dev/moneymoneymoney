-- Builds the grey-box Lobby. Run in the Lobby place (Studio command bar or the MCP).
-- Parts only, no scripts. Rebuilds Workspace.Map from scratch each time. Pads are tagged QueuePad.

local CollectionService = game:GetService("CollectionService")

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
local template = workspace:FindFirstChild("SpawnLocation")
if template then
	template:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function part(name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = map
	return p
end

part("Floor", Vector3.new(120, 1, 110), Vector3.new(0, 0.5, 0), Color3.fromRGB(205, 200, 185))

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 1.5, 35)
spawn.Color = Color3.fromRGB(90, 90, 100)
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = map

-- Big title sign facing the spawn.
local sign = part("Sign", Vector3.new(44, 12, 2), Vector3.new(0, 14, -40), Color3.fromRGB(30, 110, 50))
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Back
surface.PixelsPerStud = 20
surface.LightInfluence = 0
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.65)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 205, 60)
title.TextStrokeTransparency = 0
title.Text = "MONEY MONEY MONEY"
title.Parent = surface
local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromScale(0, 0.65)
subtitle.Size = UDim2.fromScale(1, 0.35)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.new(1, 1, 1)
subtitle.Text = "Stand on a pad to pay off Tony"
subtitle.Parent = surface
surface.Parent = sign
part("SignPostWest", Vector3.new(2, 8, 2), Vector3.new(-18, 5, -40), Color3.fromRGB(60, 60, 60))
part("SignPostEast", Vector3.new(2, 8, 2), Vector3.new(18, 5, -40), Color3.fromRGB(60, 60, 60))

-- Two queue pads so two groups can form at once.
for index, x in { -22, 22 } do
	local pad = part(
		`QueuePad{index}`,
		Vector3.new(16, 1, 16),
		Vector3.new(x, 1.1, -8),
		Color3.fromRGB(60, 200, 90),
		Enum.Material.Neon
	)
	pad.Transparency = 0.2
	CollectionService:AddTag(pad, "QueuePad")
end

return "Lobby map built"
