--!strict
-- The energy drink is something you carry: buying one puts an Energy Drink tool in your
-- backpack (one at a time, and again after a respawn). Hold it and click (or tap) to drink:
-- the can tips up and, once it's empty, the speed boost starts (BoostService).
-- A placeholder can for now: plain parts, no scripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoostService = require(script.Parent.BoostService)
local Juice = require(script.Parent.Juice)
local Notifier = require(script.Parent.Notifier)

local TOOL_NAME = "EnergyDrink"
local HOLD_GRIP = CFrame.new(0, -0.3, 0)
-- Tipped up toward the mouth (the old Bloxy Cola grip).
local DRINK_GRIP = CFrame.fromMatrix(Vector3.new(0.4, -0.9, 0.9), Vector3.xAxis, Vector3.new(0, 0.651, -0.759))
local CAN = Color3.fromRGB(60, 200, 90)

local EnergyDrink = {}

local holding: { [Player]: boolean } = {}

function EnergyDrink.holding(player: Player): boolean
	return holding[player] == true
end

local function piece(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Energy Drink: click to drink"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = HOLD_GRIP
	local handle = piece(tool, "Handle", Vector3.new(0.8, 1.3, 0.8), CAN, Enum.Material.SmoothPlastic)
	local label = piece(tool, "Label", Vector3.new(0.84, 0.45, 0.84), Color3.fromRGB(255, 220, 50), Enum.Material.Neon)
	local lid = piece(tool, "Lid", Vector3.new(0.7, 0.1, 0.7), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	lid.CFrame = handle.CFrame * CFrame.new(0, 0.7, 0)
	for _, part in { label, lid } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	return tool
end

local function drink(player: Player, tool: Tool)
	holding[player] = nil -- drinking it uses it up, even if they respawn halfway
	tool.Grip = DRINK_GRIP
	task.delay(Config.Boosts.Energy.drinkSeconds, function()
		tool:Destroy()
		if player.Parent then
			BoostService.give(player, "Energy")
			Juice.sound(player, "Ding")
			local minutes = Config.Boosts.Seconds // 60
			Notifier.send(
				player,
				`Energy drink: walking and sprinting {Config.Boosts.Energy.speed}x as fast for {minutes} minutes!`,
				"Good"
			)
		end
	end)
end

-- Puts their drink in their backpack (again after a respawn).
local function give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not holding[player] or not backpack then
		return
	end
	local character = player.Character
	if backpack:FindFirstChild(TOOL_NAME) or (character and character:FindFirstChild(TOOL_NAME)) then
		return
	end
	local tool = makeTool()
	local drinking = false
	tool.Activated:Connect(function()
		if not drinking and tool.Parent == player.Character then
			drinking = true
			drink(player, tool)
		end
	end)
	tool.Parent = backpack
end

-- ShopService takes the payment (and checks they don't already have one), then calls this.
function EnergyDrink.give(player: Player)
	holding[player] = true
	give(player)
end

function EnergyDrink.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(give, player) -- the backpack empties on respawn
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		holding[player] = nil
	end)
end

return EnergyDrink
