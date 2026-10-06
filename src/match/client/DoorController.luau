--!strict
-- The door offer, as a conversation with whoever answered: their greeting over their head and
-- their two jobs as numbered answer cards with the pay (orange for crimes, with the heat they
-- bring; blue for honest work), plus "Walk away". Press the number or click.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local Dialogue = require(script.Parent.Dialogue)

local DoorController = {}

local function detailFor(option: Types.DoorOfferOption): string
	local pay = Format.money(option.pay)
	return if option.heat > 0 then `{pay} · +{option.heat} heat` else pay
end

function DoorController.start()
	local remotes = Remotes.match()
	local offer: Types.DoorOffer? = nil
	local handle: Dialogue.Handle? = nil

	remotes.DoorOffer:onClient(function(newOffer: Types.DoorOffer?)
		if handle then
			handle.close()
			handle = nil
		end
		offer = newOffer
		if not newOffer then
			return
		end
		local options: { Dialogue.Option } = {}
		for _, option in newOffer.options do
			table.insert(options, { text = option.title, detail = detailFor(option), heat = option.heat > 0 })
		end
		table.insert(options, { text = "Walk away" })
		handle = Dialogue.open({
			at = newOffer.speakerAt,
			name = newOffer.residentName,
			line = newOffer.greeting,
			options = options,
			onChoose = function(choice: number)
				handle = nil
				offer = nil
				local picked = newOffer.options[choice]
				remotes.ChooseDoorOffer:fire(if picked then picked.slot else 0)
			end,
		})
	end)

	RunService.RenderStepped:Connect(function()
		local current, open = offer, handle
		if current and open then
			open.setFooter(`The door closes in {Format.clock(current.expiresAt - Timing.now())}`)
		end
	end)
end

return DoorController
