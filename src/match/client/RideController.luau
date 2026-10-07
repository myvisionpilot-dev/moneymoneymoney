--!strict
-- R (D-pad up on a controller, the GET OUT button on touch screens): get out of the car you're
-- driving, or ditch a stolen one. It only works while you're in a vehicle; the server checks
-- everything else (a race car keeps you in until the race ends).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local Types = require(Shared:WaitForChild("Types"))
local ClientState = require(script.Parent.ClientState)

local LEAVE_ACTION = "LeaveCar"
local VEHICLE_ATTRIBUTE = "VehicleSpeed"

local RideController = {}

local function inVehicle(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil
end

function RideController.start()
	local remotes = Remotes.match()
	local bound = false

	local function leave()
		remotes.LeaveCar:fire(nil)
	end

	local function onKey(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		leave()
		return Enum.ContextActionResult.Sink
	end

	local touchButton = if TouchButtons.enabled() then TouchButtons.add("", "GET OUT", 2, leave) else nil
	if touchButton then
		touchButton.button.Visible = false
	end

	local function refresh()
		local me = ClientState.me()
		local usable = me ~= nil and me.status == "Active" and inVehicle()
		if usable and not bound then
			ContextActionService:BindAction(LEAVE_ACTION, onKey, false, Enum.KeyCode.R, Enum.KeyCode.DPadUp)
			bound = true
		elseif not usable and bound then
			ContextActionService:UnbindAction(LEAVE_ACTION)
			bound = false
		end
		if touchButton then
			touchButton.button.Visible = usable
		end
	end

	ClientState.changed:Connect(function(_snapshot: Types.RunSnapshot)
		refresh()
	end)
	local function watch(character: Model)
		character:GetAttributeChangedSignal(VEHICLE_ATTRIBUTE):Connect(refresh)
		refresh()
	end
	if Players.LocalPlayer.Character then
		watch(Players.LocalPlayer.Character)
	end
	Players.LocalPlayer.CharacterAdded:Connect(watch)
end

return RideController
