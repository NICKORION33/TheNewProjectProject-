-- Pays out kills. Party members near the kill split the XP and coins (with a
-- bonus for grouping up), and every one of them gets their own loot roll so
-- nobody has to fight over drops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LevelService = require(script.Parent.LevelService)
local PartyService = require(script.Parent.PartyService)

local RewardService = {}

local SHARE_RADIUS = 150
local GROUP_BONUS = 0.25 -- +25% total rewards per extra member present
local DUPLICATE_REFUND = 0.25 -- share of an item's price paid out for a duplicate drop
local MIN_REFUND = 150

-- lootTable = { { Category, Id, Chance }, ... }
function RewardService.RollLoot(player, lootTable)
	local data = DataService.Get(player)
	if not (data and lootTable) then
		return
	end
	for _, entry in lootTable do
		local category, id, chance = entry[1], entry[2], entry[3]
		local def = Items.Get(category, id)
		if def and math.random() < chance then
			local rarityColor = Items.Rarities[def.Rarity].Color
			if data.Owned[category][id] then
				local refund = math.max(MIN_REFUND, math.floor((def.Currency and 0 or def.Price) * DUPLICATE_REFUND))
				data.Coins += refund
				Remotes.Notify:FireClient(player, "Toast", {
					Text = string.format("Duplicate %s salvaged for %d coins", def.Name, refund),
					Color = rarityColor,
				})
			else
				data.Owned[category][id] = true
				Remotes.Notify:FireClient(player, "Loot", {
					Name = def.Name,
					Rarity = def.Rarity,
					Category = category,
					Color = rarityColor,
				})
			end
			DataService.Push(player)
		end
	end
end

-- Rewards the killer's party for a kill at `position`.
function RewardService.Kill(killer, xp, coins, source, position, lootTable)
	local members = PartyService.MembersNear(killer, position, SHARE_RADIUS)
	local count = #members
	local share = (1 + GROUP_BONUS * (count - 1)) / count
	for _, member in members do
		local label = source
		if count > 1 then
			label = source .. "  (party x" .. count .. ")"
		end
		LevelService.Grant(member, math.max(1, math.floor(xp * share + 0.5)), math.floor(coins * share + 0.5), label)
		RewardService.RollLoot(member, lootTable)
	end
end

return RewardService
