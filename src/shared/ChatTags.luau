--!strict
-- Chat tags (client, both places): a gold [VIP] in front of the name of anyone with the VIP game
-- pass (the server marks them with the Pass_VIP attribute, serverCommon/Passes).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Config = require(script.Parent.Config)

local ChatTags = {}

function ChatTags.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if not player or player:GetAttribute("Pass_VIP") ~= true then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = `<font color="{Config.Store.VipTagColor}">[VIP]</font> {message.PrefixText}`
		return properties
	end
end

return ChatTags
