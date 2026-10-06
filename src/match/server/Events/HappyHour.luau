--!strict
-- Happy hour at the bank: for a while, deposits count Events.HappyHour.Bonus extra toward the
-- quota (DepositService asks HappyHour.bonus()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TownEvent = require(script.Parent.TownEvent)

local DESK_ATTRIBUTE = "BankCounterPosition" -- on ReplicatedStorage (DepositService sets it)

local settings = Config.Events.HappyHour

local active = false

local HappyHour = {
	id = "HappyHour",
	title = "HAPPY HOUR",
	seconds = settings.Seconds,
}

function HappyHour.bonus(): number
	return if active then settings.Bonus else 0
end

function HappyHour.canStart(): boolean
	return true
end

function HappyHour.start(ctx: TownEvent.Context)
	active = true
	local desk = ReplicatedStorage:GetAttribute(DESK_ATTRIBUTE)
	ctx.announce(
		`Mr. Penny's in a good mood: deposits count {math.floor(settings.Bonus * 100 + 0.5)}% extra toward the quota!`,
		if typeof(desk) == "Vector3" then desk else nil
	)
end

function HappyHour.tick() end

function HappyHour.stop()
	active = false
end

return HappyHour
