--!strict
-- A level-up (client): a big LEVEL 7! banner with stars and a purple flash, the pay bonus it
-- brings, and the Cred when it's a fifth level; the HUD's level bar bounces. Everyone nearby
-- also sees a pillar of light on you (WorldFxController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local UI = require(Shared:WaitForChild("UI"))
local HudController = require(script.Parent.HudController)

local LEVEL_COLOR = Color3.fromRGB(205, 140, 255)

local LevelController = {}

function LevelController.levelUp(level: number, cred: number)
	local bonus = math.floor(Config.Levels.PayPerLevel * (level - 1) * 100 + 0.5)
	local subtitle = `+{bonus}% pay for the rest of the run`
	if cred > 0 then
		subtitle = `{subtitle}  ·  +{Format.cred(cred)}`
	end
	if level >= Config.Levels.MaxLevel then
		subtitle = `MAX LEVEL  ·  {subtitle}`
	end
	Sounds.play("LevelUp")
	ScreenFx.flash(LEVEL_COLOR, 0.14)
	ScreenFx.banner(`LEVEL {level}!`, if cred > 0 then UI.Colors.Gold else LEVEL_COLOR, subtitle, 2)
	ScreenFx.stars(HudController.levelTarget(), 12, LEVEL_COLOR)
	HudController.popLevel()
end

return LevelController
