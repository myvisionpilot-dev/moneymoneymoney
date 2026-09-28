--!strict
-- In-game badges (listed in shared/Catalog): earned once, saved in your profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Profiles = require(script.Parent.Profiles)

local Badges = {}

-- Gives a badge if it's new. Returns its name when it was just earned.
function Badges.award(data: Profiles.Data, id: string): string?
	local badge = Catalog.badge(id)
	if not badge or data.Badges[id] then
		return nil
	end
	data.Badges[id] = os.time()
	return badge.name
end

return Badges
