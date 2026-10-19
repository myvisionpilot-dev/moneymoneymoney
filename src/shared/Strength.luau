--!strict
-- Strength (bought in the Shop, saved on your profile): how hard your shove hits. The server
-- puts it on you as the Strength attribute (serverCommon/Purchases); everyone reads it here.

local Config = require(script.Parent.Config)

export type Tier = { at: number, name: string }

local settings = Config.Shove

local Strength = {}

function Strength.of(player: Player): number
	local value = player:GetAttribute("Strength")
	return if typeof(value) == "number" then value else 0
end

-- Which tier this much strength is in (1 = an ordinary shove), and the tier itself.
function Strength.tier(points: number): (number, Tier)
	local index = 1
	for at, tier in settings.Tiers do
		if points >= tier.at then
			index = at
		end
	end
	return index, settings.Tiers[index]
end

-- How many times as far a shove sends them.
function Strength.push(points: number): number
	return math.min(1 + points * settings.StrengthPush, settings.MaxPush)
end

return Strength
