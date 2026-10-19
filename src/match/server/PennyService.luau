--!strict
-- Mr. Penny, the bank manager: run start, quota start, time warnings, pass, fail and the big
-- decision. Your family owes the bank, and he's here to collect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Announcer = require(script.Parent.Announcer)

local SPEAKER = "MR. PENNY"

local PennyService = {}

function PennyService.say(text: string)
	Announcer.all(SPEAKER, text)
end

-- Short and to the point: a line or two of words, never a paragraph.
PennyService.Lines = {
	intro = function(_quotaSeconds: number): string
		return "You owe the bank. Pay up!"
	end,

	quotaStart = function(quotaIndex: number, target: number, seconds: number, endless: boolean): string
		local money, clock = Format.money(target), Format.clock(seconds)
		if endless then
			return `Endless quota {quotaIndex}: {money} in {clock}!`
		end
		return `Quota {quotaIndex}: {money} in {clock}.`
	end,

	twist = function(title: string, _detail: string): string
		return `Twist: {title}!`
	end,

	earlyBonus = function(minutes: number): string
		return `{minutes} min early! Bonus cash!`
	end,

	quotaMet = function(): string
		return "Quota met! Extra rolls over."
	end,

	warning = function(secondsLeft: number, met: boolean): string
		if met then
			return `{Format.clock(secondsLeft)} left. Keep going!`
		end
		return `{Format.clock(secondsLeft)} left! Pay up!`
	end,

	passed = function(quotaIndex: number, carry: number): string
		if carry > 0 then
			return `Quota {quotaIndex} paid! +{Format.money(carry)} rolls over.`
		end
		return `Quota {quotaIndex} paid!`
	end,

	failed = function(quotaIndex: number): string
		return `Quota {quotaIndex} missed. Go home.`
	end,

	decision = function(): string
		return "Cash out, or go bigger?"
	end,
}

return PennyService
