--!strict
-- Announcements for everyone: who's talking and what they say. They slide down from under
-- the quota panel one at a time (client AnnouncementController). Mr. Penny talks through
-- PennyService; town news (new jobs, town events) comes from here too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local remotes = Remotes.match()

local Announcer = {
	TOWN_NEWS = "TOWN NEWS",
}

function Announcer.all(speaker: string, text: string)
	remotes.Announce:fireAll({ speaker = speaker, text = text })
end

return Announcer
