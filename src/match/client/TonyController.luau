--!strict
-- Tony's announcement banner under the quota panel. Lines queue up and show one at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UI = require(Shared:WaitForChild("UI"))

local TonyController = {}

function TonyController.start()
	local root = UI.root(UI.screen("Tony", 10))
	local banner = UI.frame({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 102),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, root)
	UI.corner(banner, 12)
	UI.stroke(banner, 3, UI.Colors.Gold)
	UI.padding(banner, 10)

	local name = UI.label({
		Size = UDim2.fromOffset(60, 22),
		Font = UI.Fonts.Heading,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "TONY",
	}, banner)
	UI.textStroke(name)

	local text = UI.label({
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -64, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
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
		banner.Visible = true
		task.delay(math.clamp(#line / 15, 3.5, 7), showNext)
	end

	Remotes.match().TonySays:onClient(function(line: Types.TonyLine)
		table.insert(queue, line.text)
		if #queue > 3 then
			table.remove(queue, 1) -- keep up with the game, drop stale lines
		end
		if not showing then
			showNext()
		end
	end)
end

return TonyController
