--!strict
-- Lobby client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirstPerson = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FirstPerson"))
local QueueController = require(script:WaitForChild("QueueController"))

FirstPerson.start()
QueueController.start()
