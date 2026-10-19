--!strict
-- Match client entry point. Controllers start first, then we ask the server for a snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientState = require(script:WaitForChild("ClientState"))

require(Shared:WaitForChild("Sounds")).preload()
require(Shared:WaitForChild("Cursor")).start()
require(Shared:WaitForChild("Movement")).start()
require(Shared:WaitForChild("Rainbow")).start()
require(Shared:WaitForChild("IndoorGrade")).start(false) -- softer light inside the bank
require(Shared:WaitForChild("ChatTags")).start()
require(script:WaitForChild("PromptController")).start()
require(script:WaitForChild("NotifyController")).start()
require(script:WaitForChild("HudController")).start()
require(script:WaitForChild("StoreButton")).start() -- the Shop, under the status panel
require(script:WaitForChild("CashFx")).start()
require(script:WaitForChild("StreakController")).start()
require(script:WaitForChild("BoostMeters")).start()
require(script:WaitForChild("WorldFxController")).start()
require(script:WaitForChild("AnnouncementController")).start()
require(script:WaitForChild("EventAlertController")).start()
require(script:WaitForChild("TwistController")).start()
require(script:WaitForChild("EventController")).start()
require(script:WaitForChild("LooseCashController")).start()
require(script:WaitForChild("EventPropsController")).start()
require(script:WaitForChild("GigController")).start()
require(script:WaitForChild("HustleController")).start()
require(script:WaitForChild("NextQuotaController")).start()
require(script:WaitForChild("JobGuideController")).start()
require(script:WaitForChild("GuideController")).start()
require(script:WaitForChild("DoorController")).start()
require(script:WaitForChild("ShopController")).start()
require(script:WaitForChild("TalkController")).start()
require(script:WaitForChild("RideController")).start()
require(script:WaitForChild("CarController")).start()
require(script:WaitForChild("DodgeController")).start()
require(script:WaitForChild("PoseController")).start() -- job poses, prompts being worked, cheers, waves
require(script:WaitForChild("ProneController")).start() -- C: lie down
require(script:WaitForChild("BreakInController")).start() -- back doors, lasers
require(script:WaitForChild("DogController")).start()
require(script:WaitForChild("ThrowController")).start()
require(script:WaitForChild("TugController")).start()
require(script:WaitForChild("TutorialController")).start()
require(script:WaitForChild("RaceController")).start()
require(script:WaitForChild("HidingController")).start()
require(script:WaitForChild("JuiceController")).start()
require(script:WaitForChild("PickpocketController")).start()
require(script:WaitForChild("LockpickController")).start()
require(script:WaitForChild("RegisterController")).start()
require(script:WaitForChild("StoreChimeController")).start()
require(script:WaitForChild("StunController")).start()
require(script:WaitForChild("CrateController")).start() -- the crate reveal
require(script:WaitForChild("ScannerController")).start()
require(script:WaitForChild("IntermissionController")).start()
require(script:WaitForChild("DecisionController")).start()
require(script:WaitForChild("ResultsController")).start()

ClientState.start()
