--!strict
-- Money you can see (client): every payout throws bills from the bottom of the screen into your
-- HOLDING bar, each landing with a clink; big ones flash the screen gold and shake the camera,
-- huge ones rain coins down it too. A deposit pours bills from your bag into the quota bar.
-- Quota progress gets a big pop at 25/50/75% (Config.Fx.Milestones). The flashes, banners and
-- rain are shared/ScreenFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local settings = Config.Fx
local CLINK_GAP = 0.05 -- seconds between landing clinks, so a big payout doesn't deafen you
local MILESTONE_TEXT = { [0.25] = "QUARTER WAY!", [0.5] = "HALFWAY THERE!", [0.75] = "ALMOST THERE!" }

type Flyer = {
	gui: GuiObject,
	scale: UIScale,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	startsAt: number,
	seconds: number,
	spin: number,
	land: (() -> ())?,
}

local CashFx = {}

local flyers: { Flyer } = {}
local lastClink = 0
local rng = Random.new()

local function fly(gui: GuiObject, from: Vector2, to: Vector2, delay: number, seconds: number, land: (() -> ())?)
	gui.Position = UDim2.fromOffset(from.X, from.Y)
	gui.Visible = false
	gui.Parent = ScreenFx.layer()
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	-- Thrown up and out first, then swept into the target.
	local bend = Vector2.new(rng:NextNumber(-180, 180), rng:NextNumber(-260, -90)) * ScreenFx.unit()
	table.insert(flyers, {
		gui = gui,
		scale = scale,
		p0 = from,
		p1 = from + bend,
		p2 = to,
		startsAt = os.clock() + delay,
		seconds = seconds,
		spin = rng:NextNumber(-540, 540),
		land = land,
	})
end

local function clink(pitch: number)
	local now = os.clock()
	if now - lastClink >= CLINK_GAP then
		lastClink = now
		Sounds.play("Coins", pitch + rng:NextNumber(-0.05, 0.08), 0.55)
	end
end

-- How many bills a payout of this size throws.
local function billsFor(amount: number): number
	local scale = math.log10(math.max(amount, 100) / 100) -- 0 at $100, 1 at $1,000, 2 at $10,000
	return math.clamp(math.floor(settings.BillsMin + scale * 7 + 0.5), settings.BillsMin, settings.BillsMax)
end

-- Cash into your bag: `pitch` rises when payouts come close together (JuiceController).
function CashFx.payout(amount: number, pitch: number)
	local size = ScreenFx.layer().AbsoluteSize
	local target = HudController.bagTarget()
	for index = 1, billsFor(amount) do
		local from = Vector2.new(size.X * 0.5 + rng:NextNumber(-120, 120), size.Y - 150 * ScreenFx.unit())
		local piece = if index % 4 == 0 then ScreenFx.coin() else ScreenFx.bill()
		fly(piece, from, target, (index - 1) * 0.035, rng:NextNumber(0.55, 0.8), function()
			HudController.popBag()
			clink(pitch + index * 0.01)
		end)
	end
	if amount >= settings.HugePayout then
		ScreenFx.flash(UI.Colors.Gold, 0.4)
		ScreenFx.shake(settings.ShakeStuds * 2.2, 0.6)
		ScreenFx.rain(40)
		ScreenFx.banner("BIG PAYDAY!", UI.Colors.Gold, nil, 1.2)
	elseif amount >= settings.BigPayout then
		ScreenFx.flash(UI.Colors.Gold, 0.22)
		ScreenFx.shake(settings.ShakeStuds, 0.35)
	end
end

-- A deposit pours from your bag into the quota bar.
function CashFx.deposit(amount: number)
	local from = HudController.bagTarget()
	local to = HudController.quotaTarget()
	Sounds.play("CoinPour")
	for index = 1, billsFor(amount) + 4 do
		local piece = if index % 3 == 0 then ScreenFx.coin() else ScreenFx.bill()
		local start = from + Vector2.new(rng:NextNumber(-30, 30), rng:NextNumber(-6, 6))
		fly(piece, start, to, (index - 1) * 0.045, rng:NextNumber(0.5, 0.75), function()
			HudController.popQuota()
		end)
	end
	if amount >= settings.BigPayout then
		task.delay(0.5, function()
			ScreenFx.flash(UI.Colors.Money, 0.2)
		end)
	end
end

function CashFx.start()
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		for index = #flyers, 1, -1 do
			local flyer = flyers[index]
			local t = (now - flyer.startsAt) / flyer.seconds
			if t >= 0 then
				flyer.gui.Visible = true
				local k = math.clamp(t, 0, 1)
				local eased = k * k * (3 - 2 * k)
				local a = flyer.p0:Lerp(flyer.p1, eased)
				local b = flyer.p1:Lerp(flyer.p2, eased)
				local point = a:Lerp(b, eased)
				flyer.gui.Position = UDim2.fromOffset(point.X, point.Y)
				flyer.gui.Rotation += flyer.spin * dt
				flyer.scale.Scale = 1.15 - 0.55 * eased -- shrinks a little as it reaches the bag
				if t >= 1 then
					table.remove(flyers, index)
					flyer.gui:Destroy()
					if flyer.land then
						flyer.land()
					end
				end
			end
		end
	end)

	-- Quota milestones: a pop the first time progress passes each one this quota.
	local quota = -1
	local passed: { [number]: boolean } = {}
	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.quotaIndex ~= quota then
			quota = snapshot.quotaIndex
			table.clear(passed)
			local fraction = if snapshot.target > 0 then snapshot.progress / snapshot.target else 0
			for _, mark in settings.Milestones do
				passed[mark] = fraction >= mark -- already past it when we joined
			end
			return
		end
		if snapshot.phase ~= "Quota" or snapshot.target <= 0 then
			return
		end
		local fraction = snapshot.progress / snapshot.target
		for _, mark in settings.Milestones do
			if not passed[mark] and fraction >= mark then
				passed[mark] = true
				Sounds.play("Milestone")
				ScreenFx.banner(
					MILESTONE_TEXT[mark] or `{math.floor(mark * 100)}%!`,
					UI.Colors.Money,
					`{math.floor(mark * 100)}% of the quota`
				)
			end
		end
	end)
end

return CashFx
