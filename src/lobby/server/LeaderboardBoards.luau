--!strict
-- Leaderboard boards on the bank hall's walls: parts tagged Leaderboard with a Board attribute
-- ("Cred" or "Quota") get a sign showing the top players, refreshed every
-- Leaderboards.RefreshSeconds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(ReplicatedStorage.Shared.UI)
local Leaderboards = require(ServerScriptService.Common.Leaderboards)

local BOARD_TAG = "Leaderboard"
local CANVAS = Vector2.new(600, 700)
local ROW_HEIGHT = 52
local MEDALS = { "1st", "2nd", "3rd" }
local BOARD_GREEN = Color3.fromRGB(32, 78, 57)
local BRASS = Color3.fromRGB(214, 170, 72)

local TITLES: { [Leaderboards.Board]: string } = {
	Cred = "TOP EARNERS",
	Quota = "DEEPEST RUNS",
}

type Sign = {
	board: Leaderboards.Board,
	rows: { TextLabel },
	status: TextLabel,
}

local LeaderboardBoards = {}

local signs: { Sign } = {}

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local text = UI.label({
		Position = position,
		Size = size,
		TextSize = textSize,
		TextColor3 = color,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, parent)
	UI.textStroke(text, if textSize >= 40 then 5 else 3)
	return text
end

local function setupBoard(instance: Instance)
	local board = instance:GetAttribute("Board")
	if not instance:IsA("BasePart") or (board ~= "Cred" and board ~= "Quota") then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = CANVAS
	gui.LightInfluence = 0
	-- The bank's green and brass, inset so the thick border fits on the sign.
	local background = UI.frame({
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = BOARD_GREEN,
	}, gui)
	UI.corner(background, 28)
	UI.stroke(background, 10, BRASS)
	UI.gradient(background, 0.3)

	local title = label(background, UDim2.fromOffset(20, 14), UDim2.new(1, -40, 0, 70), 56, UI.Colors.Gold)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = TITLES[board]
	local subtitle =
		label(background, UDim2.fromOffset(20, 84), UDim2.new(1, -40, 0, 34), 26, Color3.fromRGB(230, 222, 200))
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Text = if board == "Cred" then "All-time Cred earned" else "Highest quota cleared"

	local rows = {}
	for index = 1, Config.Leaderboards.Size do
		local row = label(
			background,
			UDim2.fromOffset(28, 128 + (index - 1) * ROW_HEIGHT),
			UDim2.new(1, -56, 0, ROW_HEIGHT - 6),
			34,
			if index == 1 then UI.Colors.Gold else UI.Colors.Text
		)
		table.insert(rows, row)
	end
	local status = label(background, UDim2.fromOffset(20, 128), UDim2.new(1, -40, 0, 40), 28, UI.Colors.Text)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Text = "Loading..."
	gui.Parent = instance
	table.insert(signs, { board = board, rows = rows, status = status })
end

local function render(sign: Sign)
	local entries = Leaderboards.top(sign.board)
	if not entries then
		sign.status.Text = "Leaderboards are offline right now"
		return
	end
	sign.status.Text = if #entries == 0 then "No runs yet. Be the first!" else ""
	for index, row in sign.rows do
		local entry = entries[index]
		if entry then
			local value = if sign.board == "Cred" then Format.cred(entry.value) else `Quota {entry.value}`
			local rank = MEDALS[index] or `{index}.`
			row.Text = `{rank} {entry.name}  ·  {value}`
		else
			row.Text = ""
		end
	end
end

function LeaderboardBoards.start()
	for _, instance in CollectionService:GetTagged(BOARD_TAG) do
		setupBoard(instance)
	end
	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(setupBoard)
	task.spawn(function()
		while true do
			for _, sign in signs do
				render(sign)
			end
			task.wait(Config.Leaderboards.RefreshSeconds)
		end
	end)
end

return LeaderboardBoards
