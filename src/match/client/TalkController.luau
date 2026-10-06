--!strict
-- Conversations the server starts (shopkeepers: CounterService): shows them with Dialogue and
-- sends back the answer you pick. Walking away ends the conversation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Dialogue = require(script.Parent.Dialogue)

local WALK_AWAY_STUDS = 16

local TalkController = {}

function TalkController.start()
	local remotes = Remotes.match()
	local handle: Dialogue.Handle? = nil

	remotes.Talk:onClient(function(talk: Types.Talk?)
		if handle then
			handle.close()
			handle = nil
		end
		if not talk then
			return
		end
		local options: { Dialogue.Option } = {}
		for _, option in talk.options do
			table.insert(options, {
				text = option.text,
				detail = option.detail,
				heat = option.heat,
				locked = option.locked,
			})
		end
		handle = Dialogue.open({
			at = talk.speakerAt,
			name = talk.name,
			line = talk.line,
			options = options,
			progress = talk.progress,
			closeBeyond = if #options > 0 then WALK_AWAY_STUDS else nil,
			onChoose = function(choice: number)
				handle = nil
				remotes.TalkAnswer:fire({ id = talk.id, choice = choice })
			end,
		})
	end)
end

return TalkController
