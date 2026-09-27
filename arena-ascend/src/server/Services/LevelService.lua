-- XP, levelling up and reward payouts for a single player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)

local LevelService = {}

local function addXP(player, data, amount)
	if data.Level >= Levels.MaxLevel then
		return
	end
	data.XP += amount
	local leveled = false
	while data.Level < Levels.MaxLevel and data.XP >= Levels.XPToNext(data.Level) do
		data.XP -= Levels.XPToNext(data.Level)
		data.Level += 1
		local reward = Levels.LevelReward(data.Level)
		data.Coins += reward
		leveled = true
		Remotes.Notify:FireClient(player, "LevelUp", {
			Level = data.Level,
			Title = Levels.Title(data.Level),
			Reward = reward,
			StatPoints = Levels.StatPointsPerLevel,
			SkillPoints = Levels.SkillPoints(data.Level) - Levels.SkillPoints(data.Level - 1),
		})
		if data.Level % 10 == 0 then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Remotes.Notify:FireClient(other, "Toast", {
						Text = string.format("%s reached level %d!", player.DisplayName, data.Level),
						Color = Color3.fromRGB(255, 196, 80),
					})
				end
			end
		end
	end
	if data.Level >= Levels.MaxLevel then
		data.XP = 0
	end
	if leveled then
		LoadoutService.RefreshStats(player, true)
	end
end

-- Grants XP and coins (after the player's talent bonuses) and shows a reward popup.
function LevelService.Grant(player, xp, coins, source)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local stats = LoadoutService.GetStats(player)
	xp = math.floor(xp * (stats and stats.XPGain or 1) + 0.5)
	coins = math.floor(coins * (stats and stats.CoinGain or 1) + 0.5)
	data.Coins += coins
	addXP(player, data, xp)
	DataService.Push(player)
	Remotes.Notify:FireClient(player, "Reward", { XP = xp, Coins = coins, Source = source })
end

return LevelService
