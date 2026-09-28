--!strict
-- Lobby client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FirstPerson = require(Shared:WaitForChild("FirstPerson"))
local Movement = require(Shared:WaitForChild("Movement"))
local QueueController = require(script:WaitForChild("QueueController"))

FirstPerson.start()
Movement.start()
QueueController.start()
