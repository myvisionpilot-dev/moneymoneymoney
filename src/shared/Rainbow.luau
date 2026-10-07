--!strict
-- Rainbow cosmetics (client only, both places): every part tagged RainbowGlow, in the world or
-- in a shop picture, slowly runs through the colours, and so does any light inside it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "RainbowGlow"
local CYCLE_SECONDS = 4

local Rainbow = {}

function Rainbow.start()
	RunService.RenderStepped:Connect(function()
		local color = Color3.fromHSV((os.clock() / CYCLE_SECONDS) % 1, 0.75, 1)
		for _, part in CollectionService:GetTagged(TAG) do
			if part:IsA("BasePart") then
				part.Color = color
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = color
				end
			end
		end
	end)
end

return Rainbow
