--!strict
-- The run state machine: Waiting → Intro → Quota → Intermission → Decision → Results.
-- (Named QuotaRunService so it doesn't clash with Roblox's RunService.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Timing = require(ReplicatedStorage.Shared.Timing)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(ServerScriptService.Common.RateLimiter)
local EconomyService = require(script.Parent.EconomyService)
local Notifier = require(script.Parent.Notifier)
local PathService = require(script.Parent.PathService)
local PrizeMath = require(script.Parent.PrizeMath)
local PrizeService = require(script.Parent.PrizeService)
local QuotaMath = require(script.Parent.QuotaMath)
local RosterService = require(script.Parent.RosterService)
local RunState = require(script.Parent.RunState)
local Stats = require(script.Parent.Stats)
local StealService = require(script.Parent.StealService)
local TonyService = require(script.Parent.TonyService)

local IS_STUDIO = RunService:IsStudio()
local TICK_SECONDS = 0.1

local remotes = Remotes.match()
local decisionLimiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local QuotaRunService = {}

local forcePass = false
local forceStart = false

local function setPhase(phase: Types.Phase, seconds: number)
	RunState.phase = phase
	RunState.phaseEndsAt = Timing.now() + seconds
	RunState.changed:Fire()
end

local function waitUntilPhaseEnds(isDone: (() -> boolean)?)
	while Timing.now() < RunState.phaseEndsAt do
		if isDone and isDone() then
			return
		end
		task.wait(TICK_SECONDS)
	end
end

-- Called by DepositService after EconomyService has moved the cash.
function QuotaRunService.addProgress(amount: number)
	RunState.progress += amount
	if RunState.metAt == nil and RunState.progress >= RunState.target then
		RunState.metAt = Timing.now()
		if not Config.Match.AdvanceWhenMet then
			TonyService.say(TonyService.Lines.quotaMet())
		end
	end
	RunState.changed:Fire()
end

-- Debug: pass the current quota now.
function QuotaRunService.skipQuota(): boolean
	if RunState.phase ~= "Quota" then
		return false
	end
	forcePass = true
	return true
end

-- Debug: set the time left in the current phase.
function QuotaRunService.setTimer(seconds: number): boolean
	if RunState.phase == "Waiting" or RunState.phase == "Ended" then
		return false
	end
	RunState.phaseEndsAt = Timing.now() + math.max(0, seconds)
	RunState.changed:Fire()
	return true
end

-- Debug: start the run without waiting for arrivals.
function QuotaRunService.forceStart(): boolean
	if RunState.phase ~= "Waiting" then
		return false
	end
	forceStart = true
	return true
end

local function waitForPlayers()
	RunState.phase = "Waiting"
	RunState.phaseEndsAt = 0
	RunState.changed:Fire()
	local waitSeconds = if IS_STUDIO then Config.Debug.StudioAutoStartSeconds else Config.Match.ArrivalTimeoutSeconds
	while true do
		local firstArrival = RosterService.firstArrivalAt
		if firstArrival then
			local endsAt = firstArrival + waitSeconds
			if RunState.phaseEndsAt ~= endsAt then
				RunState.phaseEndsAt = endsAt
				RunState.changed:Fire()
			end
			local everyoneHere = not IS_STUDIO and RosterService.allArrived()
			if #RosterService.active() > 0 and (forceStart or everyoneHere or Timing.now() >= endsAt) then
				return
			end
		end
		task.wait(0.25)
	end
end

local function runQuotaTimer()
	local warned: { [number]: boolean } = {}
	while true do
		local secondsLeft = RunState.phaseEndsAt - Timing.now()
		local met = Config.Match.AdvanceWhenMet and RunState.progress >= RunState.target
		if secondsLeft <= 0 or forcePass or met or #RosterService.active() == 0 then
			return
		end
		local line: string? = nil
		for _, mark in Config.Match.TonyWarningSeconds do
			if not warned[mark] and secondsLeft <= Timing.scaled(mark) then
				warned[mark] = true
				line = TonyService.Lines.warning(secondsLeft, RunState.progress >= RunState.target)
			end
		end
		if line then
			TonyService.say(line)
		end
		task.wait(TICK_SECONDS)
	end
end

local function contributions(): { Types.Contribution }
	local team = EconomyService.teamDeposited()
	local rows: { Types.Contribution } = {}
	for _, member in RosterService.all() do
		local account = EconomyService.get(member.userId)
		local deposited = if account then account.deposited else 0
		table.insert(rows, {
			userId = member.userId,
			name = member.name,
			deposited = deposited,
			share = if team > 0 then deposited / team else 0,
		})
	end
	table.sort(rows, function(a: Types.Contribution, b: Types.Contribution): boolean
		return a.deposited > b.deposited
	end)
	return rows
end

local function sendResults(recipients: { RosterService.Member }, reason: Types.EndReason, endsAt: number)
	local rows = PrizeService.rows()
	local mvp = PrizeService.mvpUserId()
	for _, member in recipients do
		if member.player.Parent then
			remotes.RunResults:fireClient(member.player, {
				reason = reason,
				highestQuota = PrizeService.highestCleared(),
				yourPrize = PrizeService.lockedPrize(member.userId) or 0,
				mvpUserId = mvp,
				snakeUserId = StealService.snakeUserId(),
				players = rows,
				endsAt = endsAt,
			})
		end
	end
end

local function cashOut(member: RosterService.Member)
	PrizeService.lock(member.userId, false)
	RosterService.setStatus(member.player, "CashedOut")
	local seconds = Timing.scaled(Config.Match.ResultsSeconds)
	sendResults({ member }, "CashedOut", Timing.now() + seconds)
	task.delay(seconds, function()
		if member.player.Parent then
			RosterService.sendToLobby({ member.player })
		end
	end)
end

-- Ends the run for everyone still active (a failed quota).
local function endRun(reason: Types.EndReason)
	local failed = reason == "Failed"
	local finishing = RosterService.active()
	for _, member in finishing do
		PrizeService.lock(member.userId, failed)
		RosterService.setStatus(member.player, "Finished")
	end
	setPhase("Results", Timing.scaled(Config.Match.ResultsSeconds))
	sendResults(finishing, reason, RunState.phaseEndsAt)
	waitUntilPhaseEnds()
	local players = {}
	for _, member in finishing do
		if member.player.Parent then
			table.insert(players, member.player)
		end
	end
	RosterService.sendToLobby(players)
	setPhase("Ended", 0)
end

-- Each active player chooses to cash out or keep going. Returns true if anyone stays.
local function runDecision(quotaIndex: number): boolean
	local deciders = RosterService.active()
	for _, member in deciders do
		member.decision = nil
	end
	setPhase("Decision", Timing.scaled(Config.Match.DecisionSeconds))
	local nextTarget = QuotaMath.target(quotaIndex + 1, #deciders)
	for _, member in deciders do
		local prizeNow = PrizeService.prizeFor(member.userId, false)
		remotes.DecisionPrompt:fireClient(member.player, {
			quotaIndex = quotaIndex,
			prizeNow = prizeNow,
			prizeIfFail = PrizeMath.failKeep(prizeNow),
			nextQuotaIndex = quotaIndex + 1,
			nextTarget = nextTarget,
			endsAt = RunState.phaseEndsAt,
		})
	end
	TonyService.say(TonyService.Lines.decision())

	waitUntilPhaseEnds(function(): boolean
		for _, member in RosterService.active() do
			if member.decision == nil then
				return false
			end
		end
		return true
	end)

	local stayers = 0
	for _, member in RosterService.active() do
		if member.decision == "Continue" then
			stayers += 1
		else
			cashOut(member) -- no answer counts as cash out
		end
	end
	return stayers > 0
end

local function onSubmitDecision(player: Player, payload: unknown)
	if not decisionLimiter:allow(player) or RunState.phase ~= "Decision" then
		return
	end
	if payload ~= "CashOut" and payload ~= "Continue" then
		return
	end
	local member = RosterService.get(player)
	if not member or member.status ~= "Active" or member.decision ~= nil then
		return
	end
	local choice: Types.Decision = if payload == "CashOut" then "CashOut" else "Continue"
	member.decision = choice
	RosterService.changed:Fire()
	Notifier.send(player, if choice == "CashOut" then "Cashing out. Nice haul!" else "Staying in. Good luck!", "Info")
end

local function runLoop()
	waitForPlayers()
	RosterService.lock()
	for _, member in RosterService.active() do
		EconomyService.setCarried(member.player, Config.Match.StartingCash, "starting cash")
	end
	RosterService.gatherAtTony()
	setPhase("Intro", Timing.scaled(Config.Match.IntroSeconds))
	TonyService.say(TonyService.Lines.intro(Timing.scaled(Config.Match.QuotaDurationSeconds)))
	waitUntilPhaseEnds()

	local quotaIndex = 0
	local carry = 0
	while #RosterService.active() > 0 do
		quotaIndex += 1
		local target = QuotaMath.target(quotaIndex, #RosterService.active())
		RunState.quotaIndex = quotaIndex
		RunState.target = target
		RunState.progress = carry
		RunState.isEndless = quotaIndex > #Config.Match.Quotas
		RunState.metAt = if carry >= target then Timing.now() else nil
		forcePass = false

		local duration = Timing.scaled(Config.Match.QuotaDurationSeconds)
		RunState.quotaStartedAt = Timing.now()
		setPhase("Quota", duration)
		PathService.openQuota(quotaIndex)
		TonyService.say(TonyService.Lines.quotaStart(quotaIndex, target, duration, RunState.isEndless))
		runQuotaTimer()

		if #RosterService.active() == 0 then
			PathService.closeQuota("Time's up! Your job was cancelled.")
			break
		end
		local passed = forcePass or RunState.progress >= target
		forcePass = false
		-- Filled before time ran out, with no cash-out choice due: roll straight into the next
		-- quota. Jobs keep going and nobody is sent back to Tony's.
		local rollOver = passed
			and Config.Match.AdvanceWhenMet
			and quotaIndex < Config.Match.CashOutAfterQuota
			and Timing.now() < RunState.phaseEndsAt
		if not rollOver then
			PathService.closeQuota("Time's up! Your job was cancelled.")
		end
		if not passed then
			TonyService.say(TonyService.Lines.failed(quotaIndex))
			endRun("Failed")
			return
		end

		PrizeService.quotaCleared(quotaIndex)
		for _, member in RosterService.active() do
			Stats.record(member.player, "QuotaCleared", quotaIndex)
		end
		carry = QuotaMath.carry(RunState.progress, target)
		local result: Types.QuotaResult = {
			quotaIndex = quotaIndex,
			passed = true,
			target = target,
			total = RunState.progress,
			contributions = contributions(),
			nextQuotaIndex = quotaIndex + 1,
			nextTarget = QuotaMath.target(quotaIndex + 1, #RosterService.active()),
			endsAt = 0,
			rolledOver = rollOver,
		}
		if rollOver then
			result.endsAt = Timing.now() + Config.Match.QuotaPaidBannerSeconds
			remotes.QuotaResult:fireAll(result)
		else
			TonyService.say(TonyService.Lines.passed(quotaIndex, carry))
			RosterService.gatherAtTony()
			setPhase("Intermission", Timing.scaled(Config.Match.IntermissionSeconds))
			result.endsAt = RunState.phaseEndsAt
			remotes.QuotaResult:fireAll(result)
			waitUntilPhaseEnds()
		end

		if quotaIndex >= Config.Match.CashOutAfterQuota and not runDecision(quotaIndex) then
			-- Everyone cashed out; their results screens are already up.
			setPhase("Results", Timing.scaled(Config.Match.ResultsSeconds))
			waitUntilPhaseEnds()
			break
		end
	end
	setPhase("Ended", 0)
end

function QuotaRunService.start()
	remotes.SubmitDecision:onServer(onSubmitDecision)
	task.spawn(runLoop)
end

return QuotaRunService
