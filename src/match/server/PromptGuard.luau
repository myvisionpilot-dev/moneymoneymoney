--!strict
-- Server-side check that a ProximityPrompt was really held for its HoldDuration.
-- Exploiters can fire a prompt instantly; the server sees when the hold began.
-- While someone holds a watched prompt their character shows it (Gestures.working: scrubbing,
-- knocking, hammering...), so everyone sees them at work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gestures = require(script.Parent.Gestures)

local SHOW_SLACK = 1 -- seconds past the hold the motion stops on its own (a hold that never ended)

local PromptGuard = {}

local holdStarts: { [ProximityPrompt]: { [Player]: number } } = {}

local function stopWorking(player: Player, prompt: ProximityPrompt)
	local character = player.Character
	if character and character:GetAttribute("Working") == prompt.ActionText then
		Gestures.working(player, nil)
	end
end

-- Call once when creating a prompt that has a HoldDuration.
function PromptGuard.watch(prompt: ProximityPrompt)
	local starts: { [Player]: number } = {}
	holdStarts[prompt] = starts
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		local started = os.clock()
		starts[player] = started
		if prompt.HoldDuration > 0 then
			Gestures.working(player, prompt.ActionText)
			task.delay(prompt.HoldDuration + SHOW_SLACK, function()
				if starts[player] == started then
					stopWorking(player, prompt)
				end
			end)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		stopWorking(player, prompt)
	end)
	prompt.Triggered:Connect(function(player: Player)
		stopWorking(player, prompt)
	end)
	prompt.Destroying:Connect(function()
		holdStarts[prompt] = nil
		for player in starts do
			stopWorking(player, prompt)
		end
	end)
end

-- True if this trigger followed a long-enough hold. Consumes the recorded hold. `seconds`
-- overrides the prompt's HoldDuration when the hold depends on the player.
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
