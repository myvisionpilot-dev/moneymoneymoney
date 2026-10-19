--!strict
-- Knocked down (server/Stun): while our character is Stunned we fall over and get back up when
-- it clears, and anyone stunned gets spinning stars over their head.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Particles = require(Shared:WaitForChild("Particles"))
local UI = require(Shared:WaitForChild("UI"))

local STUN_ATTRIBUTE = "Stunned"
local STAR_COLOR = Color3.fromRGB(255, 230, 90)

local StunController = {}

local player = Players.LocalPlayer

-- Spinning stars over their head until the stun clears.
local function showStars(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Stars"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local stars = UI.label({ Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "* * *" }, gui)
	gui.Adornee = head
	gui.Parent = player:WaitForChild("PlayerGui")
	local halo = Instance.new("Attachment")
	halo.Name = "StunStars"
	halo.Position = Vector3.new(0, 1.4, 0)
	halo.Parent = head
	local twinkle = Particles.keep(halo, "Stars", 10, STAR_COLOR, 0.5)
	twinkle.SpreadAngle = Vector2.new(180, 15)
	twinkle.Speed = NumberRange.new(1.5, 2.5)
	TweenService:Create(stars, TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {
		Rotation = 15,
	}):Play()
	local connection: RBXScriptConnection? = nil
	local function clear()
		gui:Destroy()
		halo:Destroy()
		if connection then
			connection:Disconnect()
		end
	end
	connection = character:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(function()
		if not character:GetAttribute(STUN_ATTRIBUTE) then
			clear()
		end
	end)
	Debris:AddItem(gui, 10) -- never left behind
	Debris:AddItem(halo, 10)
end

local function watch(character: Model, mine: boolean)
	character:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(function()
		local stunned = character:GetAttribute(STUN_ATTRIBUTE) == true
		if stunned then
			showStars(character)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not mine or not humanoid then
			return
		end
		if stunned then
			humanoid.PlatformStand = true
		else
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function watchPlayer(other: Player)
	if other.Character then
		watch(other.Character, other == player)
	end
	other.CharacterAdded:Connect(function(character: Model)
		watch(character, other == player)
	end)
end

function StunController.start()
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return StunController
