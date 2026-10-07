-- The game's lighting: a clear afternoon with true colours. Ambient light is soft and neutral
-- (a strong blue ambient washed every colour out and filled in the shadows), the sun is a
-- little warm, there's a light haze in the distance and a touch of contrast and saturation.
-- Run in either place (Edit mode), e.g. with the MCP:
--   require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].lighting)
-- TwistService only changes Lighting.ClockTime (night twists), so these stay put.

local Lighting = game:GetService("Lighting")

local function effect(className, name)
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(95, 95, 108)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 148)
Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ShadowSoftness = 0.3
Lighting.GeographicLatitude = 28
Lighting.GlobalShadows = true

local atmosphere = effect("Atmosphere", "Atmosphere")
atmosphere.Density = 0.27
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(200, 212, 228)
atmosphere.Decay = Color3.fromRGB(110, 118, 135)
atmosphere.Glare = 0.2
atmosphere.Haze = 0.9

local bloom = effect("BloomEffect", "Bloom")
bloom.Intensity = 0.55
bloom.Size = 26
bloom.Threshold = 2

local grading = effect("ColorCorrectionEffect", "ColorCorrection")
grading.Brightness = 0.02
grading.Contrast = 0.1
grading.Saturation = 0.22
grading.TintColor = Color3.fromRGB(255, 250, 242)

local rays = effect("SunRaysEffect", "SunRays")
rays.Intensity = 0.05
rays.Spread = 0.45

return "Lighting tuned"
