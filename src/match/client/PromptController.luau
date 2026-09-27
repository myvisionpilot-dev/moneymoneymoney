--!strict
-- Hides prompts that aren't for you: OnlyFor = another player's job spot,
-- NotFor = you (the Steal prompt on your own character). The server still checks everything.

local Players = game:GetService("Players")

local PromptController = {}

local function apply(prompt: ProximityPrompt)
	local me = Players.LocalPlayer.UserId
	local onlyFor = prompt:GetAttribute("OnlyFor")
	local notFor = prompt:GetAttribute("NotFor")
	if (typeof(onlyFor) == "number" and onlyFor ~= me) or (typeof(notFor) == "number" and notFor == me) then
		prompt.Enabled = false
	end
end

function PromptController.start()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			apply(descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("ProximityPrompt") then
			apply(descendant)
		end
	end)
end

return PromptController
