-- The blocky look, applied to a place in Studio (Edit mode; run in each place):
--   1. MaterialService gets a "Studs" MaterialVariant for every base material (the classic stud
--      maps in Config.Studs: art/studs/make_studs.py).
--   2. Every part in the map (workspace.Map, the baseplates and loose builds in workspace) wears
--      it, except glass, neon, see-through parts and anything showing a decal or sign text.
-- Non-destructive: it only sets MaterialVariant, so clearing that property undoes it. Things the
-- game builds while it runs dress themselves (shared/Studs).

local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")

local MAPS = {
	ColorMap = "rbxassetid://87846760858077",
	NormalMap = "rbxassetid://107204280869366",
	RoughnessMap = "rbxassetid://97245479315696",
}
local STUDS_PER_TILE = 1
local SKIP = { Glass = true, Neon = true, ForceField = true, Air = true, Water = true }

local made, kept = 0, 0
for _, material in Enum.Material:GetEnumItems() do
	if not SKIP[material.Name] then
		local existing: MaterialVariant? = nil
		for _, child in MaterialService:GetChildren() do
			if child:IsA("MaterialVariant") and child.Name == "Studs" and child.BaseMaterial == material then
				existing = child
			end
		end
		local ok = pcall(function()
			local variant = existing or Instance.new("MaterialVariant")
			variant.Name = "Studs"
			variant.BaseMaterial = material
			variant.ColorMap = MAPS.ColorMap
			variant.NormalMap = MAPS.NormalMap
			variant.RoughnessMap = MAPS.RoughnessMap
			variant.StudsPerTile = STUDS_PER_TILE
			variant.Parent = MaterialService
		end)
		if ok then
			if existing then
				kept += 1
			else
				made += 1
			end
		end
	end
end

local function hasArt(part: BasePart): boolean
	for _, child in part:GetChildren() do
		if child:IsA("Decal") or child:IsA("SurfaceGui") or child:IsA("Texture") then
			return true
		end
	end
	return false
end

local dressed, skipped = 0, 0
for _, child in workspace:GetChildren() do
	local isCharacter = child:IsA("Model") and Players:GetPlayerFromCharacter(child) ~= nil
	if not isCharacter and not child:IsA("Camera") and not child:IsA("Terrain") then
		local parts = { child }
		for _, descendant in child:GetDescendants() do
			table.insert(parts, descendant)
		end
		for _, part in parts do
			if part:IsA("BasePart") then
				if SKIP[part.Material.Name] or part.Transparency >= 0.5 or hasArt(part) then
					skipped += 1
				else
					part.MaterialVariant = "Studs"
					dressed += 1
				end
			end
		end
	end
end

return `variants: {made} made, {kept} updated; parts: {dressed} studded, {skipped} left as they were`
