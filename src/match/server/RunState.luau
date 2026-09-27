--!strict
-- The run's live state. QuotaRunService writes it; other services read it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

type RunState = {
	phase: Types.Phase,
	quotaIndex: number,
	target: number,
	progress: number, -- toward the current quota, including carry-over
	phaseEndsAt: number,
	isEndless: boolean,
	metAt: number?,
	quotaStartedAt: number, -- when the current quota began (steal grace uses it)
	changed: Signal.Signal<()>,
}

local RunState: RunState = {
	phase = "Waiting",
	quotaIndex = 0,
	target = 0,
	progress = 0,
	phaseEndsAt = 0,
	isEndless = false,
	metAt = nil,
	quotaStartedAt = 0,
	changed = Signal.new(),
}

return RunState
