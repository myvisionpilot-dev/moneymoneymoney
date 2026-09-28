--!strict
-- Leaderboard boards in the lobby: parts tagged Leaderboard with a Board attribute ("Cred" or
-- "Quota") get a sign showing the top players, refreshed every Leaderboards.RefreshSeconds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Leaderboards = require(ServerScriptService.Common.Leaderboards)

local BOARD_TAG = "Leaderboard"
local CANVAS = Vector2.new(600, 700)
local ROW_HEIGHT = 52

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
	local text = Instance.new("TextLabel")
	text.Position = position
	text.Size = size
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = ""
	text.Parent = parent
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
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(22, 28, 24)
	background.Parent = gui

	local title =
		label(background, UDim2.fromOffset(24, 12), UDim2.new(1, -48, 0, 70), 56, Color3.fromRGB(255, 196, 50))
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = TITLES[board]
	local subtitle =
		label(background, UDim2.fromOffset(24, 80), UDim2.new(1, -48, 0, 34), 26, Color3.fromRGB(175, 185, 175))
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Text = if board == "Cred" then "All-time Cred earned" else "Highest quota cleared"

	local rows = {}
	for index = 1, Config.Leaderboards.Size do
		local row = label(
			background,
			UDim2.fromOffset(36, 124 + (index - 1) * ROW_HEIGHT),
			UDim2.new(1, -72, 0, ROW_HEIGHT - 6),
			34,
			if index == 1 then Color3.fromRGB(255, 196, 50) else Color3.fromRGB(245, 245, 235)
		)
		table.insert(rows, row)
	end
	local status =
		label(background, UDim2.fromOffset(24, 124), UDim2.new(1, -48, 0, 40), 28, Color3.fromRGB(175, 185, 175))
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
			row.Text = `{index}. {entry.name}  ·  {value}`
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
