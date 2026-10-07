-- Dresses the bank in the Match town like the lobby's hall, in place: only the bank's inside
-- changes (see tools/town/BankInterior.luau), so nothing else in the town is rebuilt and hand
-- edits elsewhere stay. Run in the Match place (Edit mode), e.g. with the MCP:
--   require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].restyle_bank)

local BankInterior = require(script.Parent:WaitForChild("town").BankInterior)

local map = workspace:FindFirstChild("Map")
local buildings = map and map:FindFirstChild("Buildings")
local bank = buildings and buildings:FindFirstChild("Bank")
if not bank then
	return "No Workspace.Map.Buildings.Bank to dress"
end
return BankInterior.dress(bank)
