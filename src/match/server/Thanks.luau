--!strict
-- A resident coming to their door at the end of a job: they wave, and if you're close enough
-- they hold out a bill that flies over to you. Then they go back in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtil = require(ReplicatedStorage.Shared.CharacterUtil)
local Config = require(ReplicatedStorage.Shared.Config)
local Gestures = require(script.Parent.Gestures)
local NpcService = require(script.Parent.NpcService)
local PropModels = require(script.Parent.PropModels)
local Residents = require(script.Parent.Residents)
local Throwing = require(script.Parent.Throwing)

local GIFT_RANGE = 45 -- studs: closer than this they hand you the cash
local HANDOVER_DELAY = 1.1 -- seconds after they appear

local Thanks = {}

-- Where a resident stands on their doorstep, facing out (their root).
function Thanks.doorstep(door: BasePart): CFrame
	local outward = Vector3.new(door.CFrame.LookVector.X, 0, door.CFrame.LookVector.Z).Unit
	local ground = door.Position.Y - door.Size.Y / 2
	local at = Vector3.new(door.Position.X, ground + 3, door.Position.Z) + outward * 2.5
	return CFrame.lookAt(at, at + outward)
end

local function giveBill(model: Model, player: Player)
	local hand = model:FindFirstChild("RightHand")
	local root = CharacterUtil.getRoot(player)
	if not hand or not hand:IsA("BasePart") or not root then
		return
	end
	if (root.Position - hand.Position).Magnitude > GIFT_RANGE then
		return
	end
	local from = hand.CFrame * CFrame.new(0, -0.4, 0)
	local bill = PropModels.loose("Bill", from, workspace)
	local seconds = Throwing.fly(bill, from, root.CFrame * CFrame.new(0, 0.5, -0.6), { spin = 2, flat = true })
	task.delay(seconds, function()
		bill:Destroy()
	end)
end

-- The resident of house `id` at `door`. `player`: who to wave at (and hand the bill to).
function Thanks.atDoor(door: BasePart, id: number, player: Player?, gift: boolean?)
	task.spawn(function()
		local resident = Residents.forHouse(id)
		local model = NpcService.makeRig(resident.name, NpcService.lookFromSeed(id))
		local spot = Thanks.doorstep(door)
		local root = player and CharacterUtil.getRoot(player)
		if root then
			local toward = Vector3.new(root.Position.X, spot.Position.Y, root.Position.Z)
			if (toward - spot.Position).Magnitude > 1 then
				spot = CFrame.lookAt(spot.Position, toward)
			end
		end
		NpcService.place(model, spot)
		local modelRoot = model:FindFirstChild("HumanoidRootPart")
		if modelRoot and modelRoot:IsA("BasePart") then
			modelRoot.Anchored = true
		end
		task.wait(0.15)
		Gestures.play(model, "Wave")
		if gift and player then
			task.wait(HANDOVER_DELAY)
			if model.Parent then
				Gestures.play(model, "HandOver")
				task.wait(0.3)
				giveBill(model, player)
			end
		end
		task.delay(Config.Paths.Courier.ThanksSeconds, function()
			model:Destroy()
		end)
	end)
end

return Thanks
