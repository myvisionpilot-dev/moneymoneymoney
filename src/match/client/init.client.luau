--!strict
-- Match client entry point. Controllers start first, then we ask the server for a snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientState = require(script:WaitForChild("ClientState"))

require(Shared:WaitForChild("FirstPerson")).start()
require(Shared:WaitForChild("Movement")).start()
require(script:WaitForChild("PromptController")).start()
require(script:WaitForChild("NotifyController")).start()
require(script:WaitForChild("TonyController")).start()
require(script:WaitForChild("HudController")).start()
require(script:WaitForChild("JobGuideController")).start()
require(script:WaitForChild("DoorController")).start()
require(script:WaitForChild("ShopController")).start()
require(script:WaitForChild("RideController")).start()
require(script:WaitForChild("RaceController")).start()
require(script:WaitForChild("HidingController")).start()
require(script:WaitForChild("IntermissionController")).start()
require(script:WaitForChild("DecisionController")).start()
require(script:WaitForChild("ResultsController")).start()

ClientState.start()
