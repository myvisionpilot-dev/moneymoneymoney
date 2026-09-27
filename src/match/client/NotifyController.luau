--!strict
-- Shows server notices (deposits, deliveries, unlocks) as toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Toasts = require(Shared:WaitForChild("Toasts"))
local Types = require(Shared:WaitForChild("Types"))

local NotifyController = {}

function NotifyController.start()
	Remotes.match().Notify:onClient(function(notice: Types.Notice)
		Toasts.show(notice.text, notice.kind)
	end)
end

return NotifyController
