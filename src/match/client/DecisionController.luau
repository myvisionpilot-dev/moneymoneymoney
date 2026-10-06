--!strict
-- After quota Match.CashOutAfterQuota and each one after: Mr. Penny asks whether you cash out now or keep
-- going for a bigger quota and prize: his words over his head (or above the answers when he's
-- far away), the two choices as answer cards. Shows the risk plainly; no answer counts as
-- cashing out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Timing = require(Shared:WaitForChild("Timing"))
local Types = require(Shared:WaitForChild("Types"))
local ClientState = require(script.Parent.ClientState)
local Dialogue = require(script.Parent.Dialogue)

local DecisionController = {}

function DecisionController.start()
	local remotes = Remotes.match()
	local prompt: Types.DecisionPrompt? = nil
	local handle: Dialogue.Handle? = nil

	local function close()
		if handle then
			handle.close()
			handle = nil
		end
	end

	remotes.DecisionPrompt:onClient(function(newPrompt: Types.DecisionPrompt)
		close()
		prompt = newPrompt
		local keep = Format.percent(Config.Match.FailKeepPercent)
		handle = Dialogue.open({
			at = newPrompt.speakerAt,
			name = "Mr. Penny",
			line = `Big money now. Walk away with {Format.cred(newPrompt.prizeNow)}, or take on a bigger quota for a bigger prize. Fail it and you keep only {keep} ({Format.cred(
				newPrompt.prizeIfFail
			)}).`,
			options = {
				{ text = "Cash out now", detail = Format.cred(newPrompt.prizeNow) },
				{
					text = `Keep going: quota {newPrompt.nextQuotaIndex}`,
					detail = Format.money(newPrompt.nextTarget),
				},
			},
			onChoose = function(choice: number)
				handle = nil
				remotes.SubmitDecision:fire(if choice == 1 then "CashOut" else "Continue")
			end,
		})
	end)

	ClientState.changed:Connect(function(snapshot: Types.RunSnapshot)
		if snapshot.phase ~= "Decision" then
			prompt = nil
			close()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current, open, snapshot = prompt, handle, ClientState.snapshot
		if not current or not open or not snapshot then
			return
		end
		local active, decided = 0, 0
		for _, row in snapshot.players do
			if row.status == "Active" then
				active += 1
				if row.decided then
					decided += 1
				end
			end
		end
		open.setFooter(
			`{Format.clock(current.endsAt - Timing.now())} left, {decided}/{active} decided. No answer means cash out.`
		)
	end)
end

return DecisionController
