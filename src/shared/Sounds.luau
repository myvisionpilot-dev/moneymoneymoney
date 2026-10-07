--!strict
-- Sound effects (both places). Sounds.play: a one-off sound for this player (UI, rewards).
-- Sounds.at: a sound coming from somewhere in the world (made on the server, everyone nearby
-- hears it). Sounds.loop: a sound for this player that keeps going until destroyed. Ids and
-- volumes live in Config.Sounds.
-- Every effect is in one of two SoundGroups: "Effects", which goes quiet on your screen while
-- the chase music plays (Sounds.setQuiet), and "Always" for the few you still hear then:
-- money, sirens, the quota clock and the cell door (Config.Music.ChaseKeeps).

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)

local CLEANUP_SECONDS = 20
local QUIET_FADE = TweenInfo.new(0.4)

local keeps: { [string]: boolean } = {}
for _, name in Config.Music.ChaseKeeps do
	keeps[name] = true
end
local quiet = false

local Sounds = {}

local function group(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = if name == "Effects" and quiet then 0 else 1
	created.Parent = SoundService
	return created
end

-- The server makes both groups up front, so every screen has the same two.
if RunService:IsServer() then
	group("Effects")
	group("Always")
end

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
	sound.SoundGroup = group(if keeps[name] then "Always" else "Effects")
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

-- Plays for this player only, over and over, until you destroy it.
function Sounds.loop(name: string, loudness: number?): Sound?
	local sound = make(name)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.Volume *= loudness or 1
	sound.Parent = SoundService
	sound:Play()
	return sound
end

-- On this player's screen only: hush every effect except the ones in Config.Music.ChaseKeeps.
function Sounds.setQuiet(on: boolean)
	quiet = on
	for _, child in SoundService:GetChildren() do
		if child:IsA("SoundGroup") and child.Name == "Effects" then
			TweenService:Create(child, QUIET_FADE, { Volume = if on then 0 else 1 }):Play()
		end
	end
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
