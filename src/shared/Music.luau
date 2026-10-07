--!strict
-- Music on this player's screen (client only), kept quiet: the background track all the time,
-- swapped for the police chase track while you're wanted (Music.setChase). During a chase a
-- siren wails under the music and every other sound effect goes quiet except money, sirens
-- and the quota clock (Sounds.setQuiet, Config.Music.ChaseKeeps).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local Sounds = require(script.Parent.Sounds)

local FADE = TweenInfo.new(1.5)

type Track = { id: number, volume: number }

local Music = {}

local background: Sound? = nil
local chase: Sound? = nil
local siren: Sound? = nil
local chasing = false

local function make(name: string, track: Track): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{track.id}`
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

local function fade(sound: Sound, volume: number, stopAfter: boolean)
	local tween = TweenService:Create(sound, FADE, { Volume = volume })
	tween:Play()
	if stopAfter then
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				sound:Pause()
			end
		end)
	end
end

function Music.start()
	local music = make("BackgroundMusic", Config.Music.Background)
	background = music
	chase = make("ChaseMusic", Config.Music.Chase)
	music:Play()
	fade(music, Config.Music.Background.volume, false)
end

-- On while you're wanted: the chase track from the top with a siren under it, the background
-- faded out and the other sound effects hushed.
function Music.setChase(on: boolean)
	local music, track = background, chase
	if on == chasing or not music or not track then
		return
	end
	chasing = on
	Sounds.setQuiet(on)
	if on then
		track.TimePosition = 0
		track:Play()
		fade(track, Config.Music.Chase.volume, false)
		fade(music, 0, true)
		siren = Sounds.loop("Siren", Config.Music.ChaseSiren)
	else
		fade(track, 0, true)
		music:Resume()
		fade(music, Config.Music.Background.volume, false)
		local wailing = siren
		siren = nil
		if wailing then
			TweenService:Create(wailing, FADE, { Volume = 0 }):Play()
			task.delay(FADE.Time, function()
				wailing:Destroy()
			end)
		end
	end
end

return Music
