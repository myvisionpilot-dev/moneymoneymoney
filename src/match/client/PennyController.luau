--!strict
-- Mr. Penny's speech bubble under the quota panel: his portrait, and each line typing out with soft
-- blips. Lines queue up and show one at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local TYPE_SECONDS = 0.025 -- per letter
local BLIP_EVERY = 3 -- letters between blips

local PennyController = {}

function PennyController.start()
	local root = UI.root(UI.screen("Penny", 10))
	local banner = UI.card(UI.Colors.Panel, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, root)
	UI.padding(banner, 10)

	local portrait = UI.card(UI.Colors.Money, {
		Size = UDim2.fromOffset(54, 54),
	}, banner)
	UI.corner(portrait, 27)
	UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 34, Text = "👨‍💼" }, portrait)

	local name = UI.label({
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.fromOffset(200, 22),
		Font = UI.Fonts.Heading,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "MR. PENNY · THE BANK",
	}, banner)
	UI.textStroke(name, 2.5)

	local text = UI.label({
		Position = UDim2.fromOffset(64, 24),
		Size = UDim2.new(1, -64, 0, 30),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	}, banner)

	local queue: { string } = {}
	local showing = false

	local function showNext()
		local line = table.remove(queue, 1)
		if not line then
			showing = false
			banner.Visible = false
			return
		end
		showing = true
		text.Text = line
		text.MaxVisibleGraphemes = 0
		banner.Visible = true
		UI.pop(banner, 0.06)
		task.spawn(function()
			local length = utf8.len(line) or #line
			for shown = 1, length do
				if text.Text ~= line then
					return -- a newer line took over
				end
				text.MaxVisibleGraphemes = shown
				if shown % BLIP_EVERY == 0 then
					Sounds.play("Click", 1.5 + math.random() * 0.3, 0.35)
				end
				task.wait(TYPE_SECONDS)
			end
			text.MaxVisibleGraphemes = -1
		end)
		task.delay(math.clamp(#line / 15, 3.5, 7) + #line * TYPE_SECONDS, showNext)
	end

	Remotes.match().PennySays:onClient(function(line: Types.PennyLine)
		table.insert(queue, line.text)
		if #queue > 3 then
			table.remove(queue, 1) -- keep up with the game, drop stale lines
		end
		if not showing then
			showNext()
		end
	end)
end

return PennyController
