--!strict
-- The police scanner boost (convenience stores): while it's on, every cop in town wears a
-- 🚔 marker you can see through walls, with how far away they are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Timing = require(Shared:WaitForChild("Timing"))
local UI = require(Shared:WaitForChild("UI"))
local ClientState = require(script.Parent.ClientState)

local COP_NAME = "Police"
local CHECK_SECONDS = 0.5

local ScannerController = {}

local player = Players.LocalPlayer
local markers: { [Model]: { gui: BillboardGui, distance: TextLabel } } = {}

local function scannerOn(): boolean
	local me = ClientState.me()
	local endsAt = me and me.boosts.Scanner
	return endsAt ~= nil and endsAt > Timing.now()
end

local function markerFor(cop: Model)
	local head = cop:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ScannerMarker"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(70, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	UI.label({ Size = UDim2.new(1, 0, 0, 26), TextScaled = true, Text = "🚔" }, gui)
	local distance = UI.label({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), TextSize = 14 }, gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	markers[cop] = { gui = gui, distance = distance }
end

local function update()
	local on = scannerOn()
	local npcs = workspace:FindFirstChild("NPCs")
	local character = player.Character
	for cop, marker in markers do
		if not on or not cop.Parent then
			marker.gui:Destroy()
			markers[cop] = nil
		end
	end
	if not on or not npcs then
		return
	end
	for _, cop in npcs:GetChildren() do
		if cop:IsA("Model") and cop.Name == COP_NAME and not markers[cop] then
			markerFor(cop)
		end
	end
	if character then
		for cop, marker in markers do
			marker.distance.Text =
				`{math.floor((cop:GetPivot().Position - character:GetPivot().Position).Magnitude)} studs`
		end
	end
end

function ScannerController.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			update()
		end
	end)
end

return ScannerController
