--!strict
-- Mr. Penny, the bank manager: run start, quota start, time warnings, pass, fail and the big
-- decision. Your family owes the bank, and he's here to collect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Announcer = require(script.Parent.Announcer)

local SPEAKER = "MR. PENNY, THE BANK"

local PennyService = {}

function PennyService.say(text: string)
	Announcer.all(SPEAKER, text)
end

PennyService.Lines = {
	intro = function(quotaSeconds: number): string
		return `Welcome to town. I'm Mr. Penny, from the bank, and you owe us a LOT. Knock on doors, find work, and pay me at the bank every {Format.clock(
			quotaSeconds
		)}. Only deposited cash counts!`
	end,

	quotaStart = function(quotaIndex: number, target: number, seconds: number, endless: boolean): string
		local money, clock = Format.money(target), Format.clock(seconds)
		if endless then
			return `Endless quota {quotaIndex}: {money}. Bigger debt, bigger prize. You have {clock}.`
		end
		return `Quota {quotaIndex}: {money} at the bank in {clock}. The interest won't pay itself!`
	end,

	twist = function(title: string, detail: string): string
		return `This quota's twist: {title}! {detail}`
	end,

	earlyBonus = function(minutes: number): string
		return `Paid {minutes} minute{if minutes == 1 then "" else "s"} early! The bank put a little bonus in everyone's bag.`
	end,

	quotaMet = function(): string
		return "That's the quota! Anything extra rolls into the next one. The bank loves extra."
	end,

	warning = function(secondsLeft: number, met: boolean): string
		if met then
			return `{Format.clock(secondsLeft)} left. You're covered, but the bank never says no to more.`
		end
		return `{Format.clock(secondsLeft)} left and you're short. The bank is getting VERY nervous.`
	end,

	passed = function(quotaIndex: number, carry: number): string
		if carry > 0 then
			return `Quota {quotaIndex} paid in full, and {Format.money(carry)} rolls over. Pleasure doing business.`
		end
		return `Quota {quotaIndex} paid in full. Pleasure doing business.`
	end,

	failed = function(quotaIndex: number): string
		return `You came up short on quota {quotaIndex}. The bank keeps the change. Go home.`
	end,

	decision = function(): string
		return "Big money now. Cash out and walk away, or take on a bigger quota for a bigger prize. Your call."
	end,
}

return PennyService
