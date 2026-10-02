--!strict
-- Server-side check that a ProximityPrompt was really held for its HoldDuration.
-- Exploiters can fire a prompt instantly; the server sees when the hold began.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PromptGuard = {}

local holdStarts: { [ProximityPrompt]: { [Player]: number } } = {}

-- Call once when creating a prompt that has a HoldDuration.
function PromptGuard.watch(prompt: ProximityPrompt)
	local starts: { [Player]: number } = {}
	holdStarts[prompt] = starts
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		starts[player] = os.clock()
	end)
	prompt.Destroying:Connect(function()
		holdStarts[prompt] = nil
	end)
end

-- True if this trigger followed a long-enough hold. Consumes the recorded hold. `seconds`
-- overrides the prompt's HoldDuration when the hold depends on the player (a store hold-up
-- is quicker with a blaster out).
function PromptGuard.held(prompt: ProximityPrompt, player: Player, seconds: number?): boolean
	local required = seconds or prompt.HoldDuration
	if required <= 0 then
		return true
	end
	local starts = holdStarts[prompt]
	local started = starts and starts[player]
	if not starts or not started then
		return false
	end
	starts[player] = nil
	return os.clock() - started >= required * Config.Security.HoldTolerance
end

return PromptGuard
