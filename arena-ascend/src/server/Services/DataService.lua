-- Loads, caches and saves each player's profile, and pushes changes to the
-- owning client and the leaderboard.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)

local DataService = {}

local STORE_NAME = "ArenaAscend_PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local MAX_ATTEMPTS = 3

local TEMPLATE = {
	Class = "", -- empty until the player picks one on the class screen
	Coins = 150,
	Gems = 0,
	XP = 0,
	Level = 1,
	Kills = 0,
	Deaths = 0,
	BestStreak = 0,
	Owned = {
		Weapons = { WoodenSword = true },
		Armor = { ClothTunic = true },
		Outfits = { Recruit = true },
	},
	Equipped = {
		Weapon = "WoodenSword",
		Armor = "ClothTunic",
		Outfit = "Recruit",
	},
	Allocated = { Strength = 0, Intellect = 0, Vitality = 0, Agility = 0 },
	AbilityRanks = {}, -- [abilityId] = upgrades bought beyond rank 1
	Talents = {}, -- [nodeId] = rank
	Kits = {}, -- [kitId] = true
	Receipts = {}, -- [purchaseId] = true, for idempotent Robux purchases
	ReceiptOrder = {},
}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable; progress will not save this session:", result)
	end
end

-- [player] = { Data = table, CanSave = boolean }
local profiles = {}
local loadedSignals = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fills in any keys the template has that `data` is missing (new fields after updates).
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function retry(fn)
	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt)
	end
	return false, lastError
end

local function createLeaderstats(player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, stat in { "Level", "Kills", "Coins" } do
		local value = Instance.new("IntValue")
		value.Name = stat
		value.Value = data[stat]
		value.Parent = folder
	end
	folder.Parent = player
end

function DataService.Load(player)
	local data
	local canSave = true
	if store then
		local ok, result = retry(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
		else
			-- Never overwrite a save we failed to read.
			canSave = false
			warn("[DataService] Failed to load", player.Name, result)
		end
	else
		canSave = false
	end

	if not player.Parent then
		return nil
	end

	data = reconcile(type(data) == "table" and data or {}, TEMPLATE)
	profiles[player] = { Data = data, CanSave = canSave }
	createLeaderstats(player, data)

	if not canSave and store then
		Remotes.Notify:FireClient(player, "Toast", {
			Text = "Couldn't load your save. Progress this session won't be kept.",
			Color = Color3.fromRGB(255, 90, 90),
		})
	end

	local signal = loadedSignals[player]
	if signal then
		signal:Fire()
	end
	return data
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

-- Yields until the player's profile has loaded (or they leave).
function DataService.WaitFor(player)
	while player.Parent and not profiles[player] do
		local signal = loadedSignals[player]
		if not signal then
			signal = Instance.new("BindableEvent")
			loadedSignals[player] = signal
		end
		signal.Event:Wait()
	end
	return DataService.Get(player)
end

-- Returns true when the profile is safely stored (or there is no DataStore
-- to store it in, e.g. Studio without API access).
function DataService.Save(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not store then
		return true
	end
	if not profile.CanSave then
		return false
	end
	local ok, err = retry(function()
		store:UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
	if not ok then
		warn("[DataService] Failed to save", player.Name, err)
	end
	return ok
end

function DataService.Snapshot(player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local snapshot = deepCopy(data)
	snapshot.Receipts = nil
	snapshot.ReceiptOrder = nil
	snapshot.XPToNext = data.Level >= Levels.MaxLevel and 0 or Levels.XPToNext(data.Level)
	snapshot.Title = Levels.Title(data.Level)
	snapshot.MaxLevel = Levels.MaxLevel
	return snapshot
end

-- Sends the latest profile to its owner and refreshes the leaderboard.
function DataService.Push(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		for _, value in stats:GetChildren() do
			if data[value.Name] ~= nil then
				value.Value = data[value.Name]
			end
		end
	end
	Remotes.ProfileUpdated:FireClient(player, DataService.Snapshot(player))
end

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Coins = math.max(0, data.Coins + amount)
	DataService.Push(player)
end

function DataService.Init()
	Remotes.RequestProfile.OnServerInvoke = function(player)
		DataService.WaitFor(player)
		return DataService.Snapshot(player)
	end

	Players.PlayerAdded:Connect(DataService.Load)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.Load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
		local signal = loadedSignals[player]
		if signal then
			signal:Fire()
			signal:Destroy()
			loadedSignals[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.5)
		end
	end)
end

return DataService
