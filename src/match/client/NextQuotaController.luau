--!strict
-- Telling you the next quota at the right moment. After a quota is paid you get the QUOTA PAID
-- banner, then who paid, then the hustle pick; only once you've picked (or the pick timed out)
-- does the next quota crash in ("QUOTA 2! · $27,500 · 8:42 on the clock") and Mr. Penny get to
-- say his piece about it. NextQuotaController.holding() is true until then, and the
-- announcement drawer waits on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)
local HustleController = require(script.Parent.HustleController)

-- No hustle offer by this long into the quota (nothing left to offer): announce it anyway.
local SAFETY_SECONDS = Config.Match.QuotaPaidBannerSeconds + 4

type Pending = { index: number, since: number }

local NextQuotaController = {}

local pending: Pending? = nil

function NextQuotaController.holding(): boolean
	return pending ~= nil
end

local function announce()
	local current = pending
	local snapshot = ClientState.snapshot
	pending = nil
	if not current or not snapshot or snapshot.phase ~= "Quota" or snapshot.quotaIndex ~= current.index then
		return
	end
	local left = math.max(snapshot.phaseEndsAt - Timing.now(), 0)
	local name = if snapshot.isEndless then `ENDLESS QUOTA {current.index}!` else `QUOTA {current.index}!`
	Sounds.play("Fanfare", 1.1, 0.8)
	ScreenFx.banner(name, UI.Colors.Risk, `{Format.money(snapshot.target)} · {Format.clock(left)} on the clock`, 2.4)
	HudController.popQuota()
end

function NextQuotaController.start()
	local lastQuota: number? = nil
	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase == "Results" or snapshot.phase == "Ended" then
			pending = nil
			return
		end
		if snapshot.phase ~= "Quota" or snapshot.quotaIndex == lastQuota then
			return
		end
		local first = lastQuota == nil -- joined mid-run: nothing to hold back
		lastQuota = snapshot.quotaIndex
		if not first and snapshot.quotaIndex > 1 then
			pending = { index = snapshot.quotaIndex, since = os.clock() }
		end
	end)

	-- A quota paid with the next one starting straight away: hold from this moment (the news of
	-- the next quota can arrive before the snapshot that says it's started).
	Remotes.match().QuotaResult:onClient(function(result: Types.QuotaResult)
		if result.passed and result.rolledOver then
			lastQuota = result.nextQuotaIndex
			pending = { index = result.nextQuotaIndex, since = os.clock() }
		end
	end)

	HustleController.closed:Connect(function()
		if pending then
			task.delay(0.5, announce) -- just after HUSTLE PICKED!, so it crashes in on top
		end
	end)

	RunService.Heartbeat:Connect(function()
		local current = pending
		if current and not HustleController.isOpen() and os.clock() - current.since > SAFETY_SECONDS then
			announce()
		end
	end)
end

return NextQuotaController
