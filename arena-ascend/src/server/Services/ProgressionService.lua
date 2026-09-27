-- Character development: picking a class, spending attribute points,
-- ranking up abilities, learning talents, and respeccing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Abilities)
local Classes = require(Shared.Classes)
local Items = require(Shared.Items)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local Stats = require(Shared.Stats)
local Talents = require(Shared.Talents)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)

local ProgressionService = {}

local REQUEST_COOLDOWN = 0.15
local lastRequest = {}

local function result(ok, message)
	return { Ok = ok, Message = message }
end

local function resetPoints(data)
	data.Allocated = { Strength = 0, Intellect = 0, Vitality = 0, Agility = 0 }
	data.AbilityRanks = {}
	data.Talents = {}
end

local function commit(player, category)
	LoadoutService.Refresh(player, category or "Stats")
	DataService.Push(player)
end

local handlers = {}

function handlers.ChooseClass(player, data, classId)
	if type(classId) ~= "string" or not Classes.IsValid(classId) then
		return result(false, "Unknown class.")
	end
	if data.Class == classId then
		return result(false, "You're already a " .. classId .. ".")
	end
	local firstPick = data.Class == ""
	local cost = firstPick and 0 or Levels.ClassChangeCost(data.Level)
	if data.Coins < cost then
		return result(false, string.format("Changing class costs %s coins.", Format.Commas(cost)))
	end
	data.Coins -= cost

	local class = Classes.Get(classId)
	local previous = data.Class ~= "" and Classes.Get(data.Class) or nil
	data.Class = classId
	resetPoints(data)
	data.Owned.Outfits[class.Outfit] = true
	-- Swap to the new class's outfit if still wearing a starter look.
	local current = Items.Get("Outfits", data.Equipped.Outfit)
	if not current or current.Id == "Recruit" or (previous and current.Id == previous.Outfit) then
		data.Equipped.Outfit = class.Outfit
	end
	commit(player, "All")
	return result(true, firstPick and ("Welcome, " .. class.Name .. "!") or ("You are now a " .. class.Name .. ". Points refunded."))
end

function handlers.Allocate(player, data, attribute, amount)
	if not table.find(Stats.Attributes, attribute) then
		return result(false, "Unknown attribute.")
	end
	amount = type(amount) == "number" and math.floor(amount) or 1
	local free = Stats.FreeStatPoints(data)
	if amount < 1 or free < 1 then
		return result(false, "No attribute points to spend.")
	end
	amount = math.min(amount, free)
	data.Allocated[attribute] += amount
	commit(player)
	return result(true, string.format("+%d %s", amount, attribute))
end

function handlers.RankAbility(player, data, abilityId)
	local slotUnlock
	for _, slot in Stats.AbilitySlots(data) do
		if slot.Unlocked and slot.Id == abilityId then
			slotUnlock = slot.UnlockLevel
		end
	end
	local ability = slotUnlock and Abilities.Get(abilityId)
	if not ability then
		return result(false, "You can't rank that ability.")
	end
	local nextRank = Abilities.Rank(data, abilityId) + 1
	if nextRank > Abilities.MaxRank then
		return result(false, ability.Name .. " is already max rank.")
	end
	local required = Abilities.RankRequirement(slotUnlock, nextRank)
	if data.Level < required then
		return result(false, string.format("Rank %d needs level %d.", nextRank, required))
	end
	if Stats.FreeSkillPoints(data) < 1 then
		return result(false, "No skill points left.")
	end
	data.AbilityRanks[abilityId] = (data.AbilityRanks[abilityId] or 0) + 1
	commit(player)
	return result(true, string.format("%s is now rank %d!", ability.Name, nextRank))
end

function handlers.LearnTalent(player, data, nodeId)
	if data.Class == "" then
		return result(false, "Choose a class first.")
	end
	local node = type(nodeId) == "string" and Talents.Get(data.Class, nodeId)
	if not node then
		return result(false, "Unknown talent.")
	end
	local state, reason = Talents.State(data, node)
	if state == "Locked" or state == "Excluded" then
		return result(false, reason)
	end
	if (data.Talents[nodeId] or 0) >= node.MaxRank then
		return result(false, node.Name .. " is maxed.")
	end
	if Stats.FreeSkillPoints(data) < 1 then
		return result(false, "No skill points left.")
	end
	data.Talents[nodeId] = (data.Talents[nodeId] or 0) + 1
	commit(player)
	if node.Spec then
		local ultimate = Abilities.Get(Classes.Specs[node.Spec].Ultimate)
		return result(true, string.format("You are now a %s! Ultimate unlocked: %s", node.Name, ultimate.Name))
	end
	return result(true, "Learned " .. node.Name .. ".")
end

function handlers.Respec(player, data)
	local cost = Levels.RespecCost(data.Level)
	if data.Coins < cost then
		return result(false, string.format("A respec costs %s coins.", Format.Commas(cost)))
	end
	data.Coins -= cost
	resetPoints(data)
	commit(player, "All")
	return result(true, "All points refunded. Build something new!")
end

function ProgressionService.Init()
	Remotes.Progression.OnServerInvoke = function(player, action, ...)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return result(false, "Slow down!")
		end
		lastRequest[player] = now
		local data = DataService.Get(player)
		local handler = type(action) == "string" and handlers[action]
		if not (data and handler) then
			return result(false, "Unknown action.")
		end
		return handler(player, data, ...)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ProgressionService
