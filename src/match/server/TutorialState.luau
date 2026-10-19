--!strict
-- Whether this server is running the first-join tutorial, and for whom (server/Tutorial runs
-- it). Other systems check it to stay out of the way: no town events, phone gigs or Mr. Penny
-- chatter, and the police chase you but never arrest you.

local TutorialState = {
	server = false, -- this whole server is a tutorial
}

local players: { [Player]: boolean } = {}

function TutorialState.add(player: Player)
	TutorialState.server = true
	players[player] = true
	player:SetAttribute("Tutorial", true) -- the client's guides step aside
end

function TutorialState.remove(player: Player)
	players[player] = nil
	if player.Parent then
		player:SetAttribute("Tutorial", nil)
	end
end

function TutorialState.isIn(player: Player): boolean
	return players[player] == true
end

return TutorialState
