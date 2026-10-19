--!strict
-- Throwing (client). While a job lets you throw what you're holding (your character's ThrowKind,
-- ThrowRange and ThrowTarget: server/Throwing), a dotted arc runs from your hand to where you're
-- aiming, with a ring where it'll land (green over the doormat). Click (tap on a touch screen,
-- R2 on a controller) to throw there: the server checks it and flies it. If there's a doormat,
-- the aim only shows once you're within reach of it.
-- Also draws everything that flies (the Toss remote: parcels, letters, the dog's ball, bills,
-- squirrels hopping away) and the little job effects (JobFx: cracks, smashes, chomps, catches).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Particles = require(Shared:WaitForChild("Particles"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ScreenFx = require(Shared:WaitForChild("ScreenFx"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))
local ShoveFx = require(script.Parent:WaitForChild("ShoveFx"))

local DOTS = 14
local SHOW_SLACK = 10 -- studs past your reach of the doormat the aim appears
local TAP_SECONDS = 0.3
local TAP_PIXELS = 12
local FX_RANGE = 220
local MAT_GREEN = Color3.fromRGB(110, 235, 90)
local AIM_WHITE = Color3.fromRGB(255, 255, 255)

local ThrowController = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function skipList(): { Instance }
	local skip: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	for _, name in { "Animals", "NPCs", "ThrowAim" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(skip, found)
		end
	end
	return skip
end

local function dot(parent: Instance, size: number): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- Flights ---------------------------------------------------------------------------------

type Flight = { toss: Types.Toss, started: number, axis: Vector3 }

local flights: { [BasePart]: Flight } = {}

local function flightAt(flight: Flight, elapsed: number): CFrame?
	local toss = flight.toss
	local from, to = toss.from.Position, toss.to.Position
	if elapsed < toss.seconds then
		local t = elapsed / toss.seconds
		local position: Vector3
		if toss.hopping then
			local hops = math.max(2, math.floor((to - from).Magnitude / 3))
			local hop = (t * hops) % 1
			position = from:Lerp(to, t) + Vector3.new(0, toss.height * 4 * hop * (1 - hop), 0)
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			return if flat.Magnitude > 0.01 then CFrame.lookAt(position, position + flat) else CFrame.new(position)
		end
		position = from:Lerp(to, t) + Vector3.new(0, toss.height * 4 * t * (1 - t), 0)
		local turns = (toss.spin or 0) * elapsed * math.pi * 2
		local spin = if toss.flat then CFrame.Angles(0, turns, 0) else CFrame.fromAxisAngle(flight.axis, turns)
		return CFrame.new(position) * spin * toss.from.Rotation:Lerp(toss.to.Rotation, t)
	end
	local after = elapsed - toss.seconds
	local hops = toss.hops or 0
	if after < hops * 0.22 then
		local index = math.floor(after / 0.22)
		local hop = (after % 0.22) / 0.22
		local height = 0.9 / (index + 1)
		return toss.to * CFrame.new(0, height * 4 * hop * (1 - hop), 0)
	end
	return nil
end

-- Tosses whose part hasn't streamed in yet (by TossId), and when they arrived.
local waiting: { [number]: { toss: Types.Toss, at: number } } = {}

local function fly(part: BasePart, toss: Types.Toss)
	local sideways = toss.to.Position - toss.from.Position
	local flat = Vector3.new(sideways.X, 0, sideways.Z)
	local axis = if flat.Magnitude > 0.01 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
	-- Started on the server's clock, so a part that turns up late joins its flight part-way.
	local late = math.max(0, Timing.now() - toss.startedAt)
	flights[part] = { toss = toss, started = os.clock() - late, axis = axis }
end

local function startFlight(toss: Types.Toss)
	local part = toss.part
	if part and part.Parent then
		fly(part, toss)
	else
		waiting[toss.id] = { toss = toss, at = os.clock() }
	end
end

local function arrived(child: Instance)
	local id = child:GetAttribute("TossId")
	local entry = if typeof(id) == "number" then waiting[id] else nil
	if entry and child:IsA("BasePart") then
		waiting[id :: number] = nil
		fly(child, entry.toss)
	end
end

local function stepFlights()
	local now = os.clock()
	for id, entry in waiting do
		if now - entry.at > 5 then
			waiting[id] = nil
		end
	end
	for part, flight in flights do
		local at = if part.Parent and part.Anchored then flightAt(flight, now - flight.started) else nil
		if at then
			part.CFrame = at
		else
			flights[part] = nil
			if part.Parent and part.Anchored then
				part.CFrame = flight.toss.to
			end
		end
	end
end

-- Job effects -----------------------------------------------------------------------------

local function popWord(at: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(200, 70)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = anchor
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextScaled = true,
		FontFace = UI.Fonts.Title,
		TextColor3 = color,
	}, board)
	UI.textStroke(label, 3)
	UI.pop(label, 0.6)
	task.delay(0.9, function()
		anchor:Destroy()
	end)
end

local function jobFx(event: Types.JobFx)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - event.at).Magnitude > FX_RANGE then
		return
	end
	local at = event.at
	local kind = event.kind
	local mine = false
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		mine = (root.Position - at).Magnitude < 7
	end
	if kind == "Crack" then
		Particles.burst(at, {
			{ preset = "Confetti", count = 10, color = Color3.fromRGB(176, 128, 72), scale = 0.6 },
			{ preset = "Sparks", count = 8, color = Color3.fromRGB(255, 240, 200), scale = 0.4 },
		})
		popWord(at, "CRACK!", Color3.fromRGB(255, 200, 80))
		if mine then
			ScreenFx.shake(0.25, 0.2)
		end
	elseif kind == "Smash" then
		Particles.burst(at, {
			{ preset = "Confetti", count = 30, color = Color3.fromRGB(176, 128, 72), scale = 0.9 },
			{ preset = "Confetti", count = 20, color = Color3.fromRGB(230, 240, 255), scale = 0.6 },
			{ preset = "Smoke", count = 6, color = Color3.fromRGB(200, 180, 150) },
		})
		popWord(at, "SMASH!", UI.Colors.Danger)
		if mine then
			ScreenFx.shake(0.6, 0.35)
			ScreenFx.flash(UI.Colors.Danger, 0.3)
		end
	elseif kind == "Chomp" then
		Particles.burst(at, {
			{ preset = "Stars", count = 12, color = Color3.fromRGB(255, 225, 90) },
			{ preset = "Smoke", count = 4, color = Color3.fromRGB(230, 220, 200) },
		})
		popWord(at, "CHOMP!", UI.Colors.Risk)
		if mine then
			ScreenFx.shake(0.45, 0.3)
		end
	elseif kind == "Catch" then
		Particles.burst(at, {
			{ preset = "Stars", count = 14, color = UI.Colors.Gold },
			{ preset = "Sparkles", count = 10, color = Color3.fromRGB(205, 240, 60) },
		})
		popWord(at, "CAUGHT IT!", UI.Colors.Money)
	elseif kind == "Sparkle" then
		Particles.burst(at, {
			{ preset = "Sparkles", count = 16, color = UI.Colors.Gold },
			{ preset = "Stars", count = 8, color = Color3.new(1, 1, 1) },
		})
	elseif kind == "Poof" then
		Particles.burst(at, { { preset = "Smoke", count = 8 } })
	elseif kind == "Splash" then
		Particles.burst(at, { { preset = "Bubbles", count = 16, color = Color3.fromRGB(150, 210, 255) } })
	elseif kind == "Shove" or kind == "KnockOut" then
		ShoveFx.play(event)
	elseif kind == "Pow" then
		Particles.burst(at, {
			{ preset = "Stars", count = 8, color = Color3.fromRGB(255, 225, 90) },
			{ preset = "Flash", count = 1, color = UI.Colors.Danger, scale = 0.3 },
		})
		popWord(at, "POW!", UI.Colors.Danger)
		if mine then
			ScreenFx.shake(0.35, 0.2)
			ScreenFx.flash(UI.Colors.Danger, 0.2)
		end
	end
end

-- Aiming ----------------------------------------------------------------------------------

function ThrowController.start()
	local remotes = Remotes.match()
	local player = Players.LocalPlayer
	remotes.Toss:onClient(startFlight)
	workspace.ChildAdded:Connect(arrived)
	remotes.JobFx:onClient(jobFx)

	local folder = Instance.new("Folder")
	folder.Name = "ThrowAim"
	folder.Parent = workspace
	local dots: { Part } = {}
	for index = 1, DOTS do
		dots[index] = dot(folder, 0.28 - index * 0.008)
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 3, 3)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Parent = folder
	local matRing = ring:Clone()
	matRing.Size = Vector3.new(0.1, Config.Paths.Courier.MatStuds * 2, Config.Paths.Courier.MatStuds * 2)
	matRing.Parent = folder

	local hintGui = UI.root(UI.screen("ThrowHint", 20))
	local hint = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(420, 30),
		FontFace = UI.Fonts.Title,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		Text = "",
		Visible = false,
	}, hintGui)
	UI.textStroke(hint, 2.6)

	local aim: Vector3? = nil
	local showing = false
	local lastTouch: Vector2? = nil

	local function spec(): (string?, number, Vector3?)
		local character = player.Character
		if not character then
			return nil, 0, nil
		end
		local kind = character:GetAttribute("ThrowKind")
		local range = character:GetAttribute("ThrowRange")
		local target = character:GetAttribute("ThrowTarget")
		return if typeof(kind) == "string" then kind else nil,
			if typeof(range) == "number" then range else 0,
			if typeof(target) == "Vector3" then target else nil
	end

	local function holdingTool(): boolean
		local character = player.Character
		return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
	end

	-- `viewport`: the mouse's spot (no top-bar inset); otherwise a touch's (with it).
	local function aimFrom(screen: Vector2, viewport: boolean?): Vector3?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		params.FilterDescendantsInstances = skipList()
		local ray = if viewport
			then camera:ViewportPointToRay(screen.X, screen.Y)
			else camera:ScreenPointToRay(screen.X, screen.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		return if hit then hit.Position else nil
	end

	local function hide()
		for _, part in dots do
			part.Transparency = 1
		end
		ring.Transparency = 1
		matRing.Transparency = 1
		hint.Visible = false
	end

	local function throw()
		if showing and aim and not holdingTool() then
			remotes.Throw:fire(aim)
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
		if mouse or input.KeyCode == Enum.KeyCode.ButtonR2 then
			throw()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
			local started = os.clock()
			local origin = Vector2.new(input.Position.X, input.Position.Y)
			local ended: RBXScriptConnection? = nil
			ended = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState ~= Enum.UserInputState.End then
					return
				end
				if ended then
					ended:Disconnect()
				end
				local moved = (Vector2.new(input.Position.X, input.Position.Y) - origin).Magnitude
				if os.clock() - started <= TAP_SECONDS and moved <= TAP_PIXELS and showing then
					local spot = aimFrom(origin)
					if spot then
						aim = spot
						throw()
					end
				end
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		stepFlights()
		local kind, range, target = spec()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not kind or not root or not root:IsA("BasePart") or holdingTool() then
			showing = false
			hide()
			return
		end
		if
			target
			and (Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)).Magnitude
				> range + SHOW_SLACK
		then
			showing = false
			hide()
			return
		end
		-- Where they're pointing: the mouse, the last tap, or (controller) the mat or straight ahead.
		local pointed: Vector3? = nil
		local touching = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		if UserInputService.MouseEnabled and not touching then
			pointed = aimFrom(UserInputService:GetMouseLocation(), true)
		elseif lastTouch then
			pointed = aimFrom(lastTouch)
		end
		local landing: Vector3 = pointed
			or target
			or (root.Position + root.CFrame.LookVector * range * 0.6 - Vector3.new(0, 3, 0))
		local offset = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
		if offset.Magnitude > range then
			local clamped = root.Position + offset.Unit * range
			landing = Vector3.new(clamped.X, landing.Y, clamped.Z)
		end
		aim = landing
		showing = true

		local onMat = target ~= nil
			and Vector3.new(landing.X - target.X, 0, landing.Z - target.Z).Magnitude
				<= Config.Paths.Courier.MatStuds
		local color = if onMat then MAT_GREEN else AIM_WHITE
		local from = (root.CFrame * CFrame.new(0.9, 1.3, -1)).Position
		local distance = (landing - from).Magnitude
		local height = 2 + distance * 0.22
		for index, part in dots do
			local t = index / (DOTS + 1)
			part.Position = from:Lerp(landing, t) + Vector3.new(0, height * 4 * t * (1 - t), 0)
			part.Color = color
			part.Transparency = 0.15 + t * 0.4
		end
		ring.CFrame = CFrame.new(landing + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = color
		ring.Transparency = 0.35
		if target then
			matRing.CFrame = CFrame.new(target + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
			matRing.Color = MAT_GREEN
			matRing.Transparency = 0.55 + 0.25 * math.sin(os.clock() * 5)
		else
			matRing.Transparency = 1
		end
		local verb = if touching then "TAP" else "CLICK"
		hint.Visible = true
		hint.Text = if kind == "Ball"
			then `{verb} to throw!`
			elseif onMat then `{verb}: on the mat!`
			else `{verb} to throw!`
		hint.TextColor3 = if onMat then UI.Colors.Money else UI.Colors.Gold
	end)
end

return ThrowController
