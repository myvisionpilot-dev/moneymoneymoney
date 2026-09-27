--!strict
-- Match client entry point. Controllers start first, then we ask the server for a snapshot.

local ClientState = require(script:WaitForChild("ClientState"))

require(script:WaitForChild("NotifyController")).start()
require(script:WaitForChild("TonyController")).start()
require(script:WaitForChild("HudController")).start()
require(script:WaitForChild("DeliveryController")).start()
require(script:WaitForChild("IntermissionController")).start()
require(script:WaitForChild("DecisionController")).start()
require(script:WaitForChild("ResultsController")).start()

ClientState.start()
