--!strict
-- Server notices (Notify remote). There are no pop-ups for them any more (the screen keeps
-- its words to a minimum: money lines, the job guide and banners say what matters); bad news
-- still plays a short sound so you notice when something didn't work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))

local BAD_COOLDOWN = 1 -- seconds between bad-news sounds

local NotifyController = {}

function NotifyController.start()
	local lastBad = 0
	Remotes.match().Notify:onClient(function(notice: Types.Notice)
		if notice.kind == "Bad" and os.clock() - lastBad >= BAD_COOLDOWN then
			lastBad = os.clock()
			Sounds.play("Beep", 0.8, 0.6)
		end
	end)
end

return NotifyController
