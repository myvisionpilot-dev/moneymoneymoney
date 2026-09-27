-- Paste into the Studio command bar (or run via the MCP) after scripts/sync-studio.ps1.
-- Swaps this place's code for the freshly built model. Set PLACE to "lobby" or "match".
local PLACE = "match"

local model = game:GetObjects(`rbxasset://mmm/{PLACE}-code.rbxm`)[1]
local targets = {
	Shared = game:GetService("ReplicatedStorage"),
	Common = game:GetService("ServerScriptService"),
	Server = game:GetService("ServerScriptService"),
	Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}
for name, parent in targets do
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local new = model:FindFirstChild(name)
	if new then
		new.Parent = parent
	end
end
model:Destroy()
print(`[load_code] {PLACE} code loaded`)
