--!strict
-- Blasters on our side. With the blaster drawn: click (or tap, or the FIRE button on touch
-- screens) to fire where you're aiming; the server decides what it hits. Everyone sees each
-- shot's zap beam, and stars spin over whoever got stunned. If we get zapped, we sit down
-- until the stars clear. A drawn blaster also makes the store tills' hold-up quicker, so we
-- show the quicker hold on those prompts.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local TOOL_NAME = "Blaster"
local STUN_ATTRIBUTE = "Stunned"
local STORE_TAG = "StoreCounter"
local ROB_PROMPT = "RobPrompt"
local AIM_STUDS = 150 -- how far the FIRE button looks for something to aim at
local BEAM_SECONDS = 0.25
local BEAM_COLOR = Color3.fromRGB(90, 230, 255)

local BlasterController = {}

local player = Players.LocalPlayer
local equipped: Tool? = nil
local lastShot = 0

-- The till's hold time on our screen: quicker with a blaster out (the server checks the same).
local function updateHoldUps()
	local settings = Config.Paths.StoreRobbery
	local seconds = if equipped then settings.HoldSeconds / Config.Blasters.HoldUpSpeed else settings.HoldSeconds
	for _, counter in CollectionService:GetTagged(STORE_TAG) do
		local prompt = counter:FindFirstChild(ROB_PROMPT)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.HoldDuration = seconds
			prompt.ActionText = if equipped then "Hold up the till" else "Rob the register"
		end
	end
end

local function fire(target: Vector3)
	local tool = equipped
	if not tool then
		return
	end
	local cooldown = tool:GetAttribute("Cooldown")
	local now = os.clock()
	if now - lastShot < (if typeof(cooldown) == "number" then cooldown else 1) then
		return
	end
	lastShot = now
	Remotes.match().FireBlaster:fire(target)
end

-- What's in the middle of the screen (for the touch FIRE button).
local function screenCentreTarget(): Vector3
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_STUDS, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_STUDS
end

-- A glowing zap from the blaster to where it stopped, and a crackle.
local function drawShot(shot: Types.BlasterFx)
	local length = (shot.to - shot.from).Magnitude
	if length < 0.1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "Zap"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = BEAM_COLOR
	beam.Size = Vector3.new(0.3, 0.3, length)
	beam.CFrame = CFrame.lookAt((shot.from + shot.to) / 2, shot.to)
	beam.Parent = workspace
	Sounds.at("Zap", beam)
	TweenService:Create(beam, TweenInfo.new(BEAM_SECONDS), { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
		:Play()
	Debris:AddItem(beam, 2)
end

-- Spinning stars over a stunned cop or player.
local function showStars(model: Model, seconds: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Stars"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local stars = UI.label({ Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "💫 ⭐ 💫" }, gui)
	gui.Adornee = head
	gui.Parent = player:WaitForChild("PlayerGui")
	Sounds.at("Stun", head)
	TweenService
		:Create(
			stars,
			TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 15 }
		)
		:Play()
	Debris:AddItem(gui, seconds)
end

-- Zapped: sit down (fall over) until the stars clear, then get back up.
local function watchStun(character: Model)
	character:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if character:GetAttribute(STUN_ATTRIBUTE) then
			humanoid.PlatformStand = true
		else
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function BlasterController.start()
	local remotes = Remotes.match()
	local mouse = player:GetMouse()

	local fireButton = if TouchButtons.enabled()
		then TouchButtons.add("🔫", "FIRE", 3, function()
			fire(screenCentreTarget())
		end)
		else nil
	if fireButton then
		fireButton.button.Visible = false
	end

	local function onEquipped(tool: Tool)
		equipped = tool
		tool.Activated:Connect(function()
			if equipped == tool then
				fire(mouse.Hit.Position)
			end
		end)
		if fireButton then
			fireButton.button.Visible = true
		end
		updateHoldUps()
	end
	local function onUnequipped()
		equipped = nil
		if fireButton then
			fireButton.button.Visible = false
		end
		updateHoldUps()
	end

	local function watchCharacter(character: Model)
		onUnequipped()
		watchStun(character)
		character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") and child.Name == TOOL_NAME then
				onEquipped(child)
			end
		end)
		character.ChildRemoved:Connect(function(child: Instance)
			if child == equipped then
				onUnequipped()
			end
		end)
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	-- Stores stream in as you get near, so fix each till's hold time as its prompt appears.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == ROB_PROMPT then
			updateHoldUps()
		end
	end)

	remotes.BlasterFx:onClient(function(shot: Types.BlasterFx)
		drawShot(shot)
		local hit = shot.hit
		if hit and hit.Parent and shot.stunSeconds > 0 then
			showStars(hit, shot.stunSeconds)
		end
	end)
end

return BlasterController
