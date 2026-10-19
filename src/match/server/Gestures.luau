--!strict
-- What a character's body is doing, as attributes every client reads (client/PoseController
-- animates them; there are no animation assets):
--   JobPose   how they hold what they carry ("Carry", "Push", "Hold", "Tray", "Leash", "Tug")
--   Working   the prompt they're holding right now (its ActionText: scrubbing, hammering...)
--   Gesture + GestureAt   a one-off move ("Cheer", "Throw", "Wave", "HandOver"), restarted
--             every time GestureAt changes
-- Works on players' characters and on NPC rigs (residents waving from their door).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Timing = require(ReplicatedStorage.Shared.Timing)

local Gestures = {}

function Gestures.play(model: Model?, name: string)
	if model and model.Parent then
		model:SetAttribute("Gesture", name)
		model:SetAttribute("GestureAt", Timing.now())
	end
end

function Gestures.playFor(player: Player, name: string)
	Gestures.play(player.Character, name)
end

function Gestures.pose(player: Player, pose: string?)
	local character = player.Character
	if character then
		character:SetAttribute("JobPose", pose)
	end
end

function Gestures.posing(player: Player): string?
	local character = player.Character
	local pose = character and character:GetAttribute("JobPose")
	return if typeof(pose) == "string" then pose else nil
end

-- Holding a prompt: `action` is its ActionText (nil when they let go).
function Gestures.working(player: Player, action: string?)
	local character = player.Character
	if character then
		character:SetAttribute("Working", action)
	end
end

return Gestures
