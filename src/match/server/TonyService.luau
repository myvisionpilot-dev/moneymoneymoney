--!strict
-- Tony's announcements: run start, quota start, time warnings, pass, fail and the big decision.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local remotes = Remotes.match()

local TonyService = {}

function TonyService.say(text: string)
	remotes.TonySays:fireAll({ text = text })
end

TonyService.Lines = {
	intro = function(quotaSeconds: number): string
		return `Welcome to town, kids. You owe Tony money. Knock on doors, find work, and bring me cash every {Format.clock(
			quotaSeconds
		)}. Only cash on this desk counts!`
	end,

	quotaStart = function(quotaIndex: number, target: number, seconds: number, endless: boolean): string
		local money, clock = Format.money(target), Format.clock(seconds)
		if endless then
			return `Endless quota {quotaIndex}: {money}. Bigger debt, bigger prize. You got {clock}.`
		end
		return `Quota {quotaIndex}: {money} on my desk in {clock}. Chop chop!`
	end,

	quotaMet = function(): string
		return "That's the quota! Anything extra rolls into the next one. Tony loves extra."
	end,

	warning = function(secondsLeft: number, met: boolean): string
		if met then
			return `{Format.clock(secondsLeft)} left. Quota's covered, but Tony never says no to more.`
		end
		return `{Format.clock(secondsLeft)} left and you're short. Tony is getting VERY impatient.`
	end,

	passed = function(quotaIndex: number, carry: number): string
		if carry > 0 then
			return `Quota {quotaIndex} paid in full, and {Format.money(carry)} rolls over. Pleasure doing business.`
		end
		return `Quota {quotaIndex} paid in full. Pleasure doing business.`
	end,

	failed = function(quotaIndex: number): string
		return `You came up short on quota {quotaIndex}. Tony keeps the change. Go home, kids.`
	end,

	decision = function(): string
		return "Big money now. Cash out and walk away, or stay for a bigger quota and a bigger prize. Your call."
	end,
}

return TonyService
