--!strict
-- Strength bought with Cred, and the rewards for bringing people in (Config.Social), in both
-- places:
--   Strength   the Shop's Strength packs (Config.Store.StrengthPacks) cost Cred; it's saved for good
--   Invite     a friend you invited joins the game: +InviteCred Cred from every run, for good.
--              Their join says who invited them (Roblox's ReferredByPlayerId, or our invite's
--              LaunchData "invite:<UserId>"), so it's written to a DataStore under the inviter
--              (Config.Social.StoreName) and picked up by the inviter's own server when they're
--              next in (or within RecheckSeconds if they're on now).
--   Group      being in the game's group: +GroupCred Cred from every run and GroupLuck luck
--              (checked on join, every RecheckSeconds and when the BOOSTS window asks).
-- What each player has goes on them as attributes the screens read: Strength, CredBalance,
-- Referred, InGroup.

local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local Profiles = require(script.Parent.Profiles)
local RateLimiter = require(script.Parent.RateLimiter)

local settings = Config.Social
local limiter = RateLimiter.new(Config.Security.RemotesPerSecond, 1)

local Social = {}

local store = DataStoreService:GetDataStore(Profiles.storeName(settings.StoreName))
local inGroup: { [Player]: boolean } = {}
local notifyFn: ((Player, string, Types.NoticeKind) -> ())? = nil

local function notify(player: Player, text: string, kind: Types.NoticeKind)
	if notifyFn then
		notifyFn(player, text, kind)
	end
end

-- The group whose members get the group reward (0: none).
function Social.groupId(): number
	if settings.GroupId > 0 then
		return settings.GroupId
	end
	return if game.CreatorType == Enum.CreatorType.Group then game.CreatorId else 0
end

function Social.publish(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	player:SetAttribute("Strength", data.Strength)
	player:SetAttribute("CredBalance", data.Cred)
	player:SetAttribute("Referred", data.Referred)
	player:SetAttribute("InGroup", inGroup[player] == true)
end

-- Extra Cred from every run's prize (0.1 = +10%).
function Social.credBonus(player: Player): number
	local data = Profiles.get(player)
	local bonus = 0
	if data and data.Referred then
		bonus += settings.InviteCred
	end
	if inGroup[player] then
		bonus += settings.GroupCred
	end
	return bonus
end

-- The chance of a second, better roll on luck (pickpocket wallets).
function Social.luck(player: Player): number
	return if inGroup[player] then settings.GroupLuck else 0
end

-- Is this player in the group? A fresh look (IsInGroupAsync can be cached for the whole server).
local function checkGroup(player: Player)
	local id = Social.groupId()
	if id <= 0 then
		return
	end
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	local member = false
	if ok and typeof(groups) == "table" then
		for _, group in groups do
			if group.Id == id then
				member = true
			end
		end
	elseif not ok then
		local fallback, result = pcall(function()
			return player:IsInGroupAsync(id)
		end)
		member = fallback and result == true
	end
	local first = inGroup[player] == nil -- the check on join: no cheer for old members
	local was = inGroup[player] == true
	inGroup[player] = member
	if member and not was and not first then
		notify(player, `Group joined! +{Format.percent(settings.GroupCred)} Cred and Luck!`, "Good")
	end
	Social.publish(player)
end

-- Did a friend they invited join? Then the invite reward is theirs, for good.
local function claimInvites(player: Player)
	local data = Profiles.get(player)
	if not data or data.Referred then
		return
	end
	local ok, friends = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(friends) == "table" and #friends > 0 then
		data.Referred = true
		print(`[Social] {player.Name}'s invited friend joined: invite reward on`)
		Profiles.markChanged(player)
		Profiles.save(player)
		notify(player, `Your friend joined! +{Format.percent(settings.InviteCred)} Cred for good!`, "Good")
		Social.publish(player)
	end
end

-- They came in on someone's invite: write it down under the inviter (once per friend).
local function recordReferral(player: Player)
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(join) ~= "table" then
		return
	end
	local referrer = (join :: any).ReferredByPlayerId
	if (typeof(referrer) ~= "number" or referrer <= 0) and typeof(join.LaunchData) == "string" then
		referrer = tonumber(join.LaunchData:match("^invite:(%d+)$"))
	end
	if typeof(referrer) ~= "number" or referrer <= 0 or referrer == player.UserId then
		return
	end
	local friend = player.UserId
	local saved = pcall(function()
		store:UpdateAsync(tostring(referrer), function(old: any): any
			local list = if typeof(old) == "table" then old else {}
			if table.find(list, friend) then
				return nil -- already counted
			end
			table.insert(list, friend)
			return list
		end)
	end)
	if saved then
		print(`[Social] {player.Name} joined on {referrer}'s invite`)
		local inviter = Players:GetPlayerByUserId(referrer)
		if inviter then
			claimInvites(inviter)
		end
	end
end

local function buyStrength(player: Player, payload: unknown)
	if not limiter:allow(player) or typeof(payload) ~= "number" then
		return
	end
	local pack = Config.Store.StrengthPacks[payload]
	local data = Profiles.get(player)
	if not pack or not data then
		return
	end
	if data.Cred < pack.price then
		notify(player, `You need {Format.cred(pack.price - data.Cred)} more.`, "Bad")
		return
	end
	Profiles.addCred(player, data, -pack.price, `bought {pack.strength} Strength`)
	data.Strength += pack.strength
	Profiles.markChanged(player)
	Profiles.save(player)
	Social.publish(player)
end

-- `remotes` is this place's set (both have BuyStrength, CheckGroup and Notify).
function Social.start(remotes: { BuyStrength: any, CheckGroup: any, Notify: any })
	notifyFn = function(player: Player, text: string, kind: Types.NoticeKind)
		remotes.Notify:fireClient(player, { text = text, kind = kind })
	end
	remotes.BuyStrength:onServer(buyStrength)
	remotes.CheckGroup:onServer(function(player: Player)
		if limiter:allow(player) then
			task.spawn(checkGroup, player)
		end
	end)
	Profiles.loaded:Connect(function(player: Player)
		Social.publish(player)
		task.spawn(recordReferral, player)
		task.spawn(claimInvites, player)
		task.spawn(checkGroup, player)
	end)
	Profiles.changed:Connect(Social.publish)
	Players.PlayerRemoving:Connect(function(player: Player)
		inGroup[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(settings.RecheckSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(claimInvites, player)
				task.spawn(checkGroup, player)
			end
		end
	end)
end

return Social
