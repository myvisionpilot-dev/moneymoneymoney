--!strict
-- Per-player throttle for remotes and prompts: at most `maxCalls` per `windowSeconds`.

local Players = game:GetService("Players")

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
}

local RateLimiter = {}

function RateLimiter.new(maxCalls: number, windowSeconds: number): RateLimiter
	local history: { [Player]: { number } } = {}

	Players.PlayerRemoving:Connect(function(player: Player)
		history[player] = nil
	end)

	local function allow(_self: RateLimiter, player: Player): boolean
		local now = os.clock()
		local calls = history[player]
		if not calls then
			calls = {}
			history[player] = calls
		end
		while #calls > 0 and now - calls[1] > windowSeconds do
			table.remove(calls, 1)
		end
		if #calls >= maxCalls then
			return false
		end
		table.insert(calls, now)
		return true
	end

	return { allow = allow }
end

return RateLimiter
