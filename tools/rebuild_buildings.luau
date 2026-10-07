-- Rebuilds only Workspace.Map.Buildings in the Match town (the bank, every shop and business)
-- from tools/town/Buildings, leaving the roads, houses and outdoors alone. Run in the Match
-- place (Edit mode) after scripts/sync-studio.ps1, e.g. with the MCP:
--   require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].rebuild_buildings)
-- Its blasters come from ReplicatedStorage.Shared.BlasterLooks, so sync the code first.

local Buildings = require(script.Parent:WaitForChild("town").Buildings)

local map = workspace:FindFirstChild("Map")
if not map then
	return "No Workspace.Map: run build_town instead"
end
local old = map:FindFirstChild("Buildings")
if old then
	old:Destroy()
end
local folder = Buildings.build(map)
local parts = 0
for _, item in folder:GetDescendants() do
	if item:IsA("BasePart") then
		parts += 1
	end
end
return `Buildings rebuilt: {parts} parts`
