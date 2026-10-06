--!strict
-- The first minute, without a tutorial. When you've nothing on, a gold hint under the quota bar
-- and a bouncing marker show the next step: fresh into the run, knock on the nearest door; cash
-- earned but nothing paid yet, take it to the bank. After your first deposit it only speaks up when
-- your bag is full or time's nearly up. Quiet while you have a job, a door offer or a race.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local HOUSE_TAG = "House"
local KNOCK_PROMPT = "KnockPrompt"
local DESK_ATTRIBUTE = "BankCounterPosition" -- set by DepositService
local CHECK_SECONDS = 0.25
local MARKER_HEIGHT = 5
local BOB_STUDS = 0.5
local BOB_SPEED = 3

type Step = { hint: string, marker: string, target: Vector3 }

local GuideController = {}

local player = Players.LocalPlayer
local knocked: { [Instance]: boolean } = {} -- doors you've tried, so we point somewhere new
local hasJob = false
local offerOpen = false

local function nearestDoor(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, house in CollectionService:GetTagged(HOUSE_TAG) do
		local door = house:FindFirstChild("Door")
		if door and door:IsA("BasePart") and not knocked[door] then
			local distance = (door.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = door, distance
			end
		end
	end
	return best
end

-- The bank counter, even when it isn't streamed in.
local function deskPosition(): Vector3?
	local value = ReplicatedStorage:GetAttribute(DESK_ATTRIBUTE)
	return if typeof(value) == "Vector3" then value else nil
end

local function payBank(hint: string): Step?
	local desk = deskPosition()
	return if desk then { hint = hint, marker = "PAY THE BANK", target = desk } else nil
end

local function currentStep(): Step?
	local snapshot = ClientState.snapshot
	local me = ClientState.me()
	local character = player.Character
	if not snapshot or not me or not character or snapshot.phase ~= "Quota" or me.status ~= "Active" then
		return nil
	end
	if hasJob or offerOpen or me.jailedUntil > Timing.now() then
		return nil
	end
	local earned = me.carried > Config.Match.StartingCash
	if me.deposited == 0 and not earned then
		local door = nearestDoor(character:GetPivot().Position)
		return if door then { hint = "Knock on a door to find work", marker = "KNOCK", target = door.Position } else nil
	end
	if me.carried <= 0 then
		return nil
	elseif me.deposited == 0 then
		return payBank("Take your cash to the bank")
	elseif me.carried >= me.bagCapacity then
		return payBank("Bag full! Empty it at the bank")
	elseif snapshot.phaseEndsAt - Timing.now() <= Config.Guide.HurrySeconds and snapshot.progress < snapshot.target then
		return payBank("Pay the bank before time runs out!")
	end
	return nil
end

function GuideController.start()
	local remotes = Remotes.match()
	remotes.JobGuide:onClient(function(guide: Types.JobGuide?)
		hasJob = guide ~= nil
	end)
	remotes.DoorOffer:onClient(function(offer: Types.DoorOffer?)
		offerOpen = offer ~= nil
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == player and prompt.Name == KNOCK_PROMPT and prompt.Parent then
			knocked[prompt.Parent] = true
		end
	end)

	-- The marker: a gold tag bobbing over the target, visible through walls.
	local point = Instance.new("Attachment")
	point.Name = "GuideTarget"
	point.Parent = workspace.Terrain
	local marker = Instance.new("BillboardGui")
	marker.Name = "GuideMarker"
	marker.Adornee = point
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Size = UDim2.fromOffset(150, 58)
	marker.Enabled = false
	local tag = UI.card(UI.Colors.Gold, { Size = UDim2.new(1, 0, 0, 36) }, marker)
	local title = UI.label({ Size = UDim2.fromScale(1, 1), FontFace = UI.Fonts.Title, TextSize = 20 }, tag)
	UI.textStroke(title, 2.5)
	local distance =
		UI.label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20), TextSize = 15 }, marker)
	marker.Parent = player:WaitForChild("PlayerGui")

	local step: Step? = nil
	task.spawn(function()
		while true do
			local newStep = currentStep()
			local changed = (newStep and newStep.marker) ~= (step and step.marker)
			step = newStep
			HudController.setHint(if newStep then newStep.hint else nil)
			marker.Enabled = newStep ~= nil
			if newStep and changed then
				title.Text = newStep.marker
				UI.pop(tag, 0.3)
			end
			task.wait(CHECK_SECONDS)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = step
		local character = player.Character
		if not current or not character then
			return
		end
		local bob = math.sin(os.clock() * BOB_SPEED) * BOB_STUDS
		point.WorldPosition = current.target + Vector3.new(0, MARKER_HEIGHT + bob, 0)
		distance.Text = `{math.floor((character:GetPivot().Position - current.target).Magnitude)} studs`
	end)
end

return GuideController
