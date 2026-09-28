--!strict
-- R (D-pad up on a controller, the Ride button on touch screens): hop on or off your ride, or ditch a
-- stolen car. The key works once you've bought a kart or while you're in a vehicle; the server
-- checks everything else.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TouchButtons = require(Shared:WaitForChild("TouchButtons"))
local Types = require(Shared:WaitForChild("Types"))
local ClientState = require(script.Parent.ClientState)

local RIDE_ACTION = "Ride"
local VEHICLE_ATTRIBUTE = "VehicleSpeed"

local RideController = {}

local function inVehicle(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and character:GetAttribute(VEHICLE_ATTRIBUTE) ~= nil
end

function RideController.start()
	local remotes = Remotes.match()
	local bound = false

	local function hop()
		remotes.SetRiding:fire(not inVehicle())
	end

	local function toggle(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		hop()
		return Enum.ContextActionResult.Sink
	end

	local touchButton = if TouchButtons.enabled() then TouchButtons.add("🏎️", "RIDE", 2, hop) else nil
	if touchButton then
		touchButton.button.Visible = false
	end

	local function refresh()
		local me = ClientState.me()
		local active = me ~= nil and me.status == "Active"
		local usable = active and (inVehicle() or (me ~= nil and me.rideLevel > 0))
		if usable and not bound then
			ContextActionService:BindAction(RIDE_ACTION, toggle, false, Enum.KeyCode.R, Enum.KeyCode.DPadUp)
			bound = true
		elseif not usable and bound then
			ContextActionService:UnbindAction(RIDE_ACTION)
			bound = false
		end
		if touchButton then
			touchButton.button.Visible = usable
			touchButton.icon.Text = if inVehicle() then "🚶" else "🏎️"
			touchButton.label.Text = if inVehicle() then "GET OUT" else "RIDE"
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
