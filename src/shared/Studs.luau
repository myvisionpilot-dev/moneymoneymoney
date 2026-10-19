--!strict
-- The blocky look (both places): every block wears the "Studs" material, classic Roblox studs
-- tinted by the part's own colour (Config.Studs; MaterialVariants in MaterialService, one per
-- base material, made by tools/studs.luau). Things built while the game runs (props, dogs,
-- cars) put it on with Studs.dress. Glass, neon and see-through parts stay as they are.

local Config = require(script.Parent.Config)

local SKIP: { [Enum.Material]: boolean } = {
	[Enum.Material.Glass] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.ForceField] = true,
}

local Studs = {}

function Studs.dress(part: BasePart)
	if not SKIP[part.Material] and part.Transparency < 0.5 then
		part.MaterialVariant = Config.Studs.Variant
	end
end

-- A part and everything inside it.
function Studs.dressAll(root: Instance)
	if root:IsA("BasePart") then
		Studs.dress(root)
	end
	for _, child in root:GetDescendants() do
		if child:IsA("BasePart") then
			Studs.dress(child)
		end
	end
end

return Studs
