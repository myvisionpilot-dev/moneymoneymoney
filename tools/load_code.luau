-- Paste into the Studio command bar (or run via the MCP) after scripts/sync-studio.ps1.
-- Copies the freshly built code into this place's scripts. Set PLACE to "lobby" or "match".
--
-- It only rewrites Source and adds missing folders; it never deletes or moves scripts. (Studio
-- now refuses to let the MCP's code put new scripts into ServerScriptService and friends, so
-- swapping whole folders half-failed once and deleted the server code.) A brand-new script
-- shows up under "missing": create it first (the MCP multi_edit tool, or by hand in Studio)
-- with the right class, then run this again. "extra" lists scripts the build no longer has.
local PLACE = "match"

local model = game:GetObjects(`rbxasset://mmm/{PLACE}-code.rbxm`)[1]
local targets = {
	Shared = game:GetService("ReplicatedStorage"),
	Common = game:GetService("ServerScriptService"),
	Server = game:GetService("ServerScriptService"),
	Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}
local updated, missing, extra = 0, {}, {}

local function sync(source, target)
	if source:IsA("LuaSourceContainer") then
		if target.ClassName ~= source.ClassName then
			table.insert(missing, `{target:GetFullName()} (is a {target.ClassName}, should be a {source.ClassName})`)
		elseif target.Source ~= source.Source then
			target.Source = source.Source
			updated += 1
		end
	end
	for _, child in source:GetChildren() do
		local existing = target:FindFirstChild(child.Name)
		if not existing and child:IsA("Folder") then
			existing = Instance.new("Folder")
			existing.Name = child.Name
			existing.Parent = target
		end
		if existing then
			sync(child, existing)
		else
			table.insert(missing, `{target:GetFullName()}.{child.Name} ({child.ClassName})`)
		end
	end
	for _, child in target:GetChildren() do
		if child:IsA("LuaSourceContainer") and not source:FindFirstChild(child.Name) then
			table.insert(extra, child:GetFullName())
		end
	end
end

for name, parent in targets do
	local source = model:FindFirstChild(name)
	local target = parent:FindFirstChild(name)
	if source and target then
		sync(source, target)
	elseif source then
		table.insert(missing, `{parent:GetFullName()}.{name} ({source.ClassName})`)
	end
end
model:Destroy()
print(`[load_code] {PLACE}: {updated} scripts updated`)
print(`[load_code] missing: {if #missing > 0 then table.concat(missing, "; ") else "none"}`)
print(`[load_code] extra: {if #extra > 0 then table.concat(extra, "; ") else "none"}`)
