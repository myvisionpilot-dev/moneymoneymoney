--!strict
-- Sound effects (both places). Sounds.play: a one-off sound for this player (UI, rewards).
-- Sounds.at: a sound coming from somewhere in the world (made on the server, everyone nearby
-- hears it). Ids and volumes live in Config.Sounds.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local CLEANUP_SECONDS = 20

local Sounds = {}

local function make(name: string): Sound?
	local entry = Config.Sounds[name]
	if not entry then
		warn(`[Sounds] There's no sound called {name}`)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{entry.id}`
	sound.Volume = entry.volume
	return sound
end

-- Plays for this player only. `pitch` speeds it up or slows it down (1 = normal); `loudness`
-- scales the configured volume.
function Sounds.play(name: string, pitch: number?, loudness: number?)
	local sound = make(name)
	if not sound then
		return
	end
	sound.PlaybackSpeed = pitch or 1
	sound.Volume *= loudness or 1
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	Debris:AddItem(sound, CLEANUP_SECONDS)
end

-- Plays from a part or attachment. Looped sounds keep going until you destroy them.
function Sounds.at(name: string, parent: Instance, looped: boolean?): Sound?
	local sound = make(name)
	if not sound then
		return nil
	end
	sound.Looped = looped == true
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	sound:Play()
	if not looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, CLEANUP_SECONDS)
	end
	return sound
end

-- Loads every sound up front so the first play isn't silent.
function Sounds.preload()
	local list = {}
	for name in Config.Sounds do
		local sound = make(name)
		if sound then
			table.insert(list, sound)
		end
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(list)
		for _, sound in list do
			sound:Destroy()
		end
	end)
end

return Sounds
