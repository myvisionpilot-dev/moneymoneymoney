--!strict
-- Lobby client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

require(Shared:WaitForChild("Sounds")).preload()
require(Shared:WaitForChild("FirstPerson")).start()
require(Shared:WaitForChild("Movement")).start()
require(script:WaitForChild("QueueController")).start()
require(script:WaitForChild("ProfileHud")).start()
require(script:WaitForChild("CosmeticShopController")).start()
require(script:WaitForChild("ProfileState")).start()
