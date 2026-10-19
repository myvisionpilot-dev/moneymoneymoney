-- Builds the lobby's Lucky Wheel into the place (Edit mode, in the lobby; sync the code first), so
-- it shows in Studio and can be moved like any model: the game uses the saved one wherever it
-- stands (lobby/server/WheelService). Running it again replaces it at Config.Wheel.Position.
--   require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_wheel)
local ServerScriptService = game:GetService("ServerScriptService")

local builder = ServerScriptService.Server.WheelBuilder:Clone() -- fresh: Studio keeps old requires
builder.Parent = ServerScriptService.Server
local ok, result = pcall(require, builder)
builder:Destroy()
if not ok then
	error(result)
end
local wheel = result.build()
return `Lucky Wheel built at {wheel:GetPivot().Position}`
