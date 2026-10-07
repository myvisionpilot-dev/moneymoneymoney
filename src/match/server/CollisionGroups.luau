--!strict
-- Cars never hit people: every physics car part is in the Cars group, every player character
-- and NPC in People, and the two groups pass through each other. A driver joins Cars while
-- seated (or pedestrians would bump the driver, and the whole car with them). Pedestrians
-- still dash out of the way: see DodgeService. Cash flying out of people (client effects) is in
-- Fx: it lands on the ground but goes through people, cars and itself.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local CARS = "Cars"
local PEOPLE = "People"
local FX = "Fx"

local CollisionGroups = {}

local function setGroup(model: Instance, group: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
	model.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group -- hats and tools added later
		end
	end)
end

function CollisionGroups.people(model: Model)
	setGroup(model, PEOPLE)
end

function CollisionGroups.car(model: Model)
	setGroup(model, CARS)
end

-- Moves a character between People (on foot) and Cars (driving).
function CollisionGroups.driving(character: Model, driving: boolean)
	local group = if driving then CARS else PEOPLE
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

function CollisionGroups.start()
	PhysicsService:RegisterCollisionGroup(CARS)
	PhysicsService:RegisterCollisionGroup(PEOPLE)
	PhysicsService:CollisionGroupSetCollidable(CARS, PEOPLE, false)
	PhysicsService:RegisterCollisionGroup(FX)
	for _, other in { CARS, PEOPLE, FX } do
		PhysicsService:CollisionGroupSetCollidable(FX, other, false)
	end
	local function watch(player: Player)
		if player.Character then
			CollisionGroups.people(player.Character)
		end
		player.CharacterAdded:Connect(CollisionGroups.people)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return CollisionGroups
