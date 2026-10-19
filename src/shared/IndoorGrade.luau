--!strict
-- Softer light indoors (client only, both places). The outdoor look (tools/lighting.luau) is
-- bright and very saturated, which blows out the bank's white walls; while the camera is inside
-- (the lobby is all indoors; in the Match, inside a part tagged SafeZone: the bank) a second
-- colour correction calms it down, the bloom eases off and the exposure drops a touch.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CHECK_SECONDS = 0.25
local INDOOR = {
	Brightness = -0.06,
	Contrast = 0.12,
	Saturation = -0.2,
	TintColor = Color3.fromRGB(255, 244, 226),
}
local OUTDOOR = {
	Brightness = 0,
	Contrast = 0,
	Saturation = 0,
	TintColor = Color3.new(1, 1, 1),
}
local EXPOSURE_DROP = 0.9
local BLOOM_INDOOR = 0.08

local IndoorGrade = {}

local function insidePart(point: Vector3, part: BasePart): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- `always`: the whole place is indoors (the lobby). Otherwise indoors is inside a SafeZone part.
-- `amount` (0..1, default 1) is how much of the softening to use: the lobby's hall is darker wood
-- and green, so it only needs a little.
function IndoorGrade.start(always: boolean, amount: number?)
	local share = amount or 1
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IndoorGrade"
	grade.Enabled = true
	grade.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloomOut = if bloom then bloom.Intensity else 0
	local exposureOut = Lighting.ExposureCompensation
	local indoors: boolean? = nil

	local function set(inside: boolean)
		if inside == indoors then
			return
		end
		indoors = inside
		TweenService:Create(
			grade,
			FADE,
			if inside
				then {
					Brightness = INDOOR.Brightness * share,
					Contrast = INDOOR.Contrast * share,
					Saturation = INDOOR.Saturation * share,
					TintColor = OUTDOOR.TintColor:Lerp(INDOOR.TintColor, share),
				}
				else OUTDOOR
		):Play()
		TweenService:Create(Lighting, FADE, {
			ExposureCompensation = exposureOut - (if inside then EXPOSURE_DROP * share else 0),
		}):Play()
		if bloom then
			TweenService:Create(
				bloom,
				FADE,
				{ Intensity = if inside then bloomOut + (BLOOM_INDOOR - bloomOut) * share else bloomOut }
			):Play()
		end
	end

	if always then
		set(true)
		return
	end
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local point = camera.CFrame.Position
		local inside = false
		for _, zone in CollectionService:GetTagged("SafeZone") do
			if zone:IsA("BasePart") and insidePart(point, zone) then
				inside = true
				break
			end
		end
		set(inside)
	end)
end

return IndoorGrade
