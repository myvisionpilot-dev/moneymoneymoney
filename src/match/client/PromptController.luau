--!strict
-- Hides prompts that aren't for you: OnlyFor = another player's job spot,
-- NotFor = you (the Steal prompt on your own character). Pickpocket prompts hide while you
-- push the hot-dog cart (the PushingCart attribute). The server still checks everything.

local Players = game:GetService("Players")

local PICKPOCKET_PROMPT = "PickpocketPrompt"
local CART_ATTRIBUTE = "PushingCart"

local PromptController = {}

local pickpocketPrompts: { [ProximityPrompt]: number } = {} -- prompt -> its real range
local pushing = false

-- The server never changes a pickpocket prompt's range, so a range of 0 here hides it for us.
local function applyCart(prompt: ProximityPrompt)
	prompt.MaxActivationDistance = if pushing then 0 else pickpocketPrompts[prompt]
end

local function apply(prompt: ProximityPrompt)
	local me = Players.LocalPlayer.UserId
	local onlyFor = prompt:GetAttribute("OnlyFor")
	local notFor = prompt:GetAttribute("NotFor")
	if (typeof(onlyFor) == "number" and onlyFor ~= me) or (typeof(notFor) == "number" and notFor == me) then
		prompt.Enabled = false
	end
	if prompt.Name == PICKPOCKET_PROMPT then
		pickpocketPrompts[prompt] = prompt.MaxActivationDistance
		prompt.Destroying:Connect(function()
			pickpocketPrompts[prompt] = nil
		end)
		applyCart(prompt)
	end
end

local function watchCharacter(character: Model)
	local function update()
		pushing = character:GetAttribute(CART_ATTRIBUTE) == true
		for prompt in pickpocketPrompts do
			applyCart(prompt)
		end
	end
	character:GetAttributeChangedSignal(CART_ATTRIBUTE):Connect(update)
	update()
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
	local player = Players.LocalPlayer
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return PromptController
