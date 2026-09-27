-- Parties of up to four players. Party members can't hurt each other, share
-- XP and coins from kills made near them, and get their own loot rolls.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Classes = require(Shared.Classes)

local DataService = require(script.Parent.DataService)

local PartyService = {}

PartyService.MaxSize = 4
local INVITE_LIFETIME = 30
local PARTY_COLORS = {
	Color3.fromRGB(88, 208, 255),
	Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(255, 190, 70),
	Color3.fromRGB(220, 130, 255),
	Color3.fromRGB(255, 120, 150),
}

local parties = {} -- [partyId] = { Id, Leader, Members = { player }, Color }
local partyOf = {} -- [player] = party
local invites = {} -- [invitee] = { [inviterUserId] = expiresAt }
local colorIndex = 0

local function result(ok, message)
	return { Ok = ok, Message = message }
end

local function toast(player, text, color)
	Remotes.Notify:FireClient(player, "Toast", { Text = text, Color = color })
end

local function snapshot(party)
	local members = {}
	for _, member in party.Members do
		local data = DataService.Get(member)
		table.insert(members, {
			UserId = member.UserId,
			Name = member.DisplayName,
			Level = data and data.Level or 1,
			Class = data and data.Class ~= "" and Classes.Get(data.Class).Name or "Adventurer",
		})
	end
	return { Id = party.Id, Leader = party.Leader.UserId, Color = party.Color, Members = members }
end

function PartyService.Push(party)
	if not party then
		return
	end
	local snap = snapshot(party)
	for _, member in party.Members do
		Remotes.PartyUpdated:FireClient(member, snap)
	end
end

local function create(leader)
	colorIndex = colorIndex % #PARTY_COLORS + 1
	local party = {
		Id = HttpService:GenerateGUID(false),
		Leader = leader,
		Members = { leader },
		Color = PARTY_COLORS[colorIndex],
	}
	parties[party.Id] = party
	partyOf[leader] = party
	leader:SetAttribute("PartyId", party.Id)
	return party
end

local function removeMember(player, reason)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	if player.Parent then
		player:SetAttribute("PartyId", nil)
		Remotes.PartyUpdated:FireClient(player, nil)
	end
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	for _, member in party.Members do
		toast(member, string.format("%s %s the party.", player.DisplayName, reason or "left"))
	end
	if #party.Members <= 1 then
		-- A party of one is no party.
		for _, member in party.Members do
			partyOf[member] = nil
			member:SetAttribute("PartyId", nil)
			Remotes.PartyUpdated:FireClient(member, nil)
		end
		parties[party.Id] = nil
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
		toast(party.Leader, "You're the party leader now.")
	end
	PartyService.Push(party)
end

function PartyService.GetParty(player)
	return partyOf[player]
end

function PartyService.AreAllies(a, b)
	if a == b then
		return true
	end
	local party = partyOf[a]
	return party ~= nil and party == partyOf[b]
end

-- Party members (including `player`) whose characters are within `radius` of `position`.
function PartyService.MembersNear(player, position, radius)
	local party = partyOf[player]
	local list = party and party.Members or { player }
	local near = {}
	for _, member in list do
		local character = member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if member == player or (root and (root.Position - position).Magnitude <= radius) then
			table.insert(near, member)
		end
	end
	return near
end

local handlers = {}

function handlers.Invite(player, userId)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return result(false, "That player isn't here.")
	end
	if partyOf[target] then
		return result(false, target.DisplayName .. " is already in a party.")
	end
	local party = partyOf[player]
	if party and #party.Members >= PartyService.MaxSize then
		return result(false, "Your party is full.")
	end
	invites[target] = invites[target] or {}
	invites[target][player.UserId] = os.clock() + INVITE_LIFETIME
	Remotes.Notify:FireClient(target, "PartyInvite", { FromUserId = player.UserId, FromName = player.DisplayName })
	return result(true, "Invited " .. target.DisplayName .. ".")
end

function handlers.Accept(player, userId)
	local pending = invites[player]
	local expires = pending and type(userId) == "number" and pending[userId]
	local inviter = expires and Players:GetPlayerByUserId(userId)
	if not (expires and expires > os.clock() and inviter) then
		return result(false, "That invite has expired.")
	end
	pending[userId] = nil
	if partyOf[player] then
		removeMember(player, "left")
	end
	local party = partyOf[inviter] or create(inviter)
	if #party.Members >= PartyService.MaxSize then
		return result(false, "That party is full.")
	end
	table.insert(party.Members, player)
	partyOf[player] = party
	player:SetAttribute("PartyId", party.Id)
	for _, member in party.Members do
		if member ~= player then
			toast(member, player.DisplayName .. " joined the party!", Color3.fromRGB(120, 230, 140))
		end
	end
	PartyService.Push(party)
	return result(true, "Joined " .. inviter.DisplayName .. "'s party.")
end

function handlers.Decline(player, userId)
	local pending = invites[player]
	if pending and type(userId) == "number" then
		pending[userId] = nil
		local inviter = Players:GetPlayerByUserId(userId)
		if inviter then
			toast(inviter, player.DisplayName .. " declined your invite.")
		end
	end
	return result(true, "Invite declined.")
end

function handlers.Leave(player)
	if not partyOf[player] then
		return result(false, "You're not in a party.")
	end
	removeMember(player, "left")
	return result(true, "You left the party.")
end

function handlers.Kick(player, userId)
	local party = partyOf[player]
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not party or party.Leader ~= player then
		return result(false, "Only the leader can remove members.")
	end
	if not target or partyOf[target] ~= party or target == player then
		return result(false, "They're not in your party.")
	end
	removeMember(target, "was removed from")
	toast(target, "You were removed from the party.")
	return result(true, "Removed " .. target.DisplayName .. ".")
end

function PartyService.Init()
	Remotes.Party.OnServerInvoke = function(player, action, userId)
		local handler = type(action) == "string" and handlers[action]
		if not handler then
			return result(false, "Unknown action.")
		end
		return handler(player, userId)
	end
	Players.PlayerRemoving:Connect(function(player)
		removeMember(player, "left")
		invites[player] = nil
	end)
	-- Keep members' levels and classes fresh in everyone's party frames.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, party in parties do
				PartyService.Push(party)
			end
		end
	end)
end

return PartyService
