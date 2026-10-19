-- The game's lighting: a bright, toy-box afternoon (the user's reference: a studded Roblox scene with
-- punchy colours and a deep blue sky). Strong sun, light neutral ambient, very little haze so the
-- sky stays blue, a soft bloom and plenty of saturation.
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

Lighting.Brightness = 3.2
Lighting.Ambient = Color3.fromRGB(110, 110, 120)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ShadowSoftness = 0.3
Lighting.GeographicLatitude = 28
Lighting.GlobalShadows = true

local atmosphere = effect("Atmosphere", "Atmosphere")
atmosphere.Density = 0.18
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(175, 210, 255)
atmosphere.Decay = Color3.fromRGB(90, 140, 230)
atmosphere.Glare = 0.2
atmosphere.Haze = 0.2

local bloom = effect("BloomEffect", "Bloom")
bloom.Intensity = 0.7
bloom.Size = 26
bloom.Threshold = 1.7

local grading = effect("ColorCorrectionEffect", "ColorCorrection")
grading.Brightness = 0.04
grading.Contrast = 0.16
grading.Saturation = 0.5
grading.TintColor = Color3.fromRGB(255, 250, 242)

local rays = effect("SunRaysEffect", "SunRays")
rays.Intensity = 0.05
rays.Spread = 0.45

return "Lighting tuned"
