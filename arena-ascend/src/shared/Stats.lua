-- Turns a profile (class, level, allocated points, talents, gear) into the
-- numbers combat uses. Shared so the character screen shows exactly what
-- the server will apply.

local Classes = require(script.Parent.Classes)
local Items = require(script.Parent.Items)
local Talents = require(script.Parent.Talents)
local Abilities = require(script.Parent.Abilities)
local Levels = require(script.Parent.Levels)

local Stats = {}

Stats.Attributes = { "Strength", "Intellect", "Vitality", "Agility" }
Stats.AttributeInfo = {
	Strength = "Physical damage",
	Intellect = "Spell damage and healing",
	Vitality = "Max health and defense",
	Agility = "Crit, attack speed and move speed",
}

function Stats.Mods(profile)
	local mods = {}
	for nodeId, rank in profile.Talents do
		local node = Talents.Get(profile.Class, nodeId)
		if node and rank > 0 then
			for _, effect in node.Effects do
				mods[effect[1]] = (mods[effect[1]] or 0) + effect[2] * rank
			end
		end
	end
	return mods
end

function Stats.Compute(profile)
	local class = Classes.Get(profile.Class)
	local level = profile.Level
	local mods = Stats.Mods(profile)
	local function mod(key)
		return mods[key] or 0
	end
	local weapon = Items.Get("Weapons", profile.Equipped.Weapon) or Items.Weapons[1]
	local armor = Items.Get("Armor", profile.Equipped.Armor) or Items.Armor[1]

	local s = { Mods = mods, Class = class, Weapon = weapon, Armor = armor }
	for _, attr in Stats.Attributes do
		s[attr] = class.Base[attr] + class.Growth[attr] * (level - 1) + (profile.Allocated[attr] or 0)
	end

	s.MaxHealth = math.floor(
		(class.BaseHealth + class.HealthPerLevel * (level - 1) + s.Vitality * 8 + armor.Health) * (1 + mod("MaxHealth"))
	)
	s.Defense = math.min(0.6, armor.Defense + s.Vitality * 0.003 + mod("Defense"))
	s.PhysicalPower = (1 + s.Strength * 0.02 + s.Agility * 0.005) * (1 + mod("Damage") + mod("PhysicalDamage"))
	s.SpellPower = (1 + s.Intellect * 0.025) * (1 + mod("Damage") + mod("SpellDamage"))
	s.HealingPower = (1 + s.Intellect * 0.025) * (1 + mod("Healing"))
	s.Crit = math.min(0.6, weapon.Crit + s.Agility * 0.004 + mod("Crit"))
	s.CritDamage = 1.6 + mod("CritDamage")
	s.AttackSpeed = 1 + s.Agility * 0.008 + mod("AttackSpeed")
	s.MoveSpeed = math.min(26, class.Speed * (1 + s.Agility * 0.004 + mod("MoveSpeed")))
	s.CooldownMult = math.max(0.6, 1 - mod("Cooldown"))
	s.Lifesteal = mod("Lifesteal")
	s.CoinGain = 1 + mod("CoinGain")
	s.XPGain = 1 + mod("XPGain")

	s.AttackPower = class.AttackStat == "Spell" and s.SpellPower or s.PhysicalPower
	s.AttackDamage = weapon.Damage * class.AttackMult * s.AttackPower
	s.AttackCooldown = weapon.Cooldown * class.AttackCooldownMult / s.AttackSpeed
	return s
end

-- Damage (or healing, for Heal / HealPower) an ability does per hit at the profile's rank.
function Stats.AbilityPower(stats, profile, ability, field)
	local rank = Abilities.Rank(profile, ability.Id)
	local power
	if field == "Heal" or field == "HealPower" then
		power = stats.HealingPower
	else
		power = ability.Stat == "Spell" and stats.SpellPower or stats.PhysicalPower
	end
	local bonus = 1 + (stats.Mods["Ability." .. ability.Id .. ".Damage"] or 0)
	return stats.Weapon.Damage * (ability[field] or 0) * power * Abilities.PowerMult(rank) * bonus
end

function Stats.AbilityCooldown(stats, profile, ability)
	local rank = Abilities.Rank(profile, ability.Id)
	return ability.Cooldown * Abilities.CooldownMult(rank) * stats.CooldownMult
end

-- The four ability slots for a profile: { Id?, UnlockLevel, Unlocked, Reason? }.
function Stats.AbilitySlots(profile)
	local class = Classes.Get(profile.Class)
	local spec = Talents.Spec(profile)
	local slots = {}
	for index, unlock in Classes.SlotUnlockLevels do
		local id = index <= 3 and class.Abilities[index] or (spec and spec.Ultimate)
		local slot = { Id = id, UnlockLevel = unlock }
		if profile.Level < unlock then
			slot.Reason = "Unlocks at level " .. unlock
		elseif not id then
			slot.Reason = "Choose a specialization"
		else
			slot.Unlocked = true
		end
		slots[index] = slot
	end
	return slots
end

function Stats.SpentStatPoints(profile)
	local spent = 0
	for _, value in profile.Allocated do
		spent += value
	end
	return spent
end

function Stats.SpentSkillPoints(profile)
	local spent = 0
	for _, upgrades in profile.AbilityRanks do
		spent += upgrades
	end
	for _, rank in profile.Talents do
		spent += rank
	end
	return spent
end

function Stats.FreeStatPoints(profile)
	return Levels.StatPoints(profile.Level) - Stats.SpentStatPoints(profile)
end

function Stats.FreeSkillPoints(profile)
	return Levels.SkillPoints(profile.Level) - Stats.SpentSkillPoints(profile)
end

return Stats
