--!strict
-- The cosmetics each player wears (both places), from their saved profile: Style.worn says
-- what's in a slot, and the trail and aura go on their character here (shared/CosmeticFx), so
-- everyone sees them. A trail's particles only stream while you're moving. The Match puts on
-- the rest (paint and underglow on race cars, the bag you carry, zap colours, bank bursts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticFx = require(ReplicatedStorage.Shared.CosmeticFx)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Profiles = require(script.Parent.Profiles)

local MOVING_SPEED = 2 -- studs a second: faster than this and your trail streams
local CHECK_SECONDS = 0.15

local Style = {}

-- What each player has on, to take off before putting on something new.
type Outfit = { trail: { Instance }, aura: { Instance }, streams: { ParticleEmitter } }
local dressed: { [Player]: Outfit } = {}

-- The cosmetic they wear in a slot, if any (and only if they own it).
function Style.worn(player: Player, slot: Cosmetics.Slot): Cosmetics.Item?
	local data = Profiles.get(player)
	local id = if data then data.Equipped[slot] else nil
	if not data or not id or not data.Owned[id] then
		return nil
	end
	local item = Cosmetics.get(id)
	return if item and item.slot == slot then item else nil
end

local function clear(list: { Instance })
	for _, instance in list do
		instance:Destroy()
	end
	table.clear(list)
end

-- Their trail and aura, fresh on their current character.
local function dress(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local current = dressed[player]
	if current then
		clear(current.trail)
		clear(current.aura)
	end
	if not character or not root or not root:IsA("BasePart") then
		dressed[player] = nil
		return
	end
	local outfit: Outfit = { trail = {}, aura = {}, streams = {} }
	local trail = Style.worn(player, "Trail")
	if trail then
		outfit.trail = CosmeticFx.trail(root, trail)
	end
	local aura = Style.worn(player, "Aura")
	if aura then
		outfit.aura = CosmeticFx.aura(root, aura)
	end
	for _, instance in outfit.trail do
		for _, emitter in instance:GetDescendants() do
			if emitter:IsA("ParticleEmitter") and emitter:GetAttribute(CosmeticFx.MoveOnly) then
				table.insert(outfit.streams, emitter)
			end
		end
	end
	dressed[player] = outfit
end

-- After a purchase or a change of outfit.
function Style.refresh(player: Player)
	dress(player)
end

function Style.start()
	Profiles.loaded:Connect(Style.refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			Style.refresh(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		dressed[player] = nil
	end)

	-- Trail particles stream only while you're on the move (standing still, just the ribbon's
	-- end and your aura).
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		for player, outfit in dressed do
			if #outfit.streams == 0 then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local moving = root ~= nil and root:IsA("BasePart") and root.AssemblyLinearVelocity.Magnitude > MOVING_SPEED
			for _, emitter in outfit.streams do
				if emitter.Enabled ~= moving then
					emitter.Enabled = moving
				end
			end
		end
	end)
end

return Style
