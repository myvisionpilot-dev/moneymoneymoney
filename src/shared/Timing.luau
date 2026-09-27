--!strict
-- Server-synced clock and run timers (sped up when Debug.Enabled).

local Config = require(script.Parent.Config)

local Timing = {}

function Timing.now(): number
	return workspace:GetServerTimeNow()
end

function Timing.scaled(seconds: number): number
	if Config.Debug.Enabled then
		return seconds * Config.Debug.TimerScale
	end
	return seconds
end

return Timing
