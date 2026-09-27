-- Talent trees. Every class shares a Core branch, and has two specialization
-- branches. Learning a specialization's root (level 10) unlocks its ultimate
-- and permanently locks the other branch until a respec. Inside a branch,
-- the level-15 talents are a pick-one-of-two, so two players of the same
-- class and spec can still end up with different builds.
--
-- Effects are { ModifierKey, AmountPerRank }. Keys are read by Stats.lua;
-- "Ability.<Id>.Damage" boosts one ability's damage or healing.

local Classes = require(script.Parent.Classes)

local Talents = {}

local CORE = {
	{ Id = "Toughness", Name = "Toughness", Level = 2, MaxRank = 5, Effects = { { "MaxHealth", 0.04 } }, Description = "+4% max health per rank." },
	{ Id = "Precision", Name = "Precision", Level = 2, MaxRank = 5, Effects = { { "Crit", 0.02 } }, Description = "+2% critical chance per rank." },
	{ Id = "Haste", Name = "Haste", Level = 4, MaxRank = 5, Effects = { { "Cooldown", 0.03 } }, Description = "-3% ability cooldowns per rank." },
	{ Id = "Fortune", Name = "Fortune", Level = 6, MaxRank = 3, Effects = { { "CoinGain", 0.06 } }, Description = "+6% coins earned per rank." },
	{ Id = "Wisdom", Name = "Wisdom", Level = 6, MaxRank = 3, Effects = { { "XPGain", 0.05 } }, Description = "+5% XP earned per rank." },
}

-- Per spec: root (L10), two exclusive level-15 talents (3 ranks), capstone (L25).
local SPEC_TREES = {
	Guardian = {
		Root = { Name = "Guardian", Effects = { { "MaxHealth", 0.1 }, { "Defense", 0.05 } }, Description = "Unlocks Bulwark. +10% max health, +5% defense." },
		A = { Name = "Stalwart", Effects = { { "Defense", 0.03 } }, Description = "+3% defense per rank." },
		B = { Name = "Retribution", Effects = { { "PhysicalDamage", 0.06 } }, Description = "+6% physical damage per rank." },
		Cap = { Name = "Unbreakable", Effects = { { "MaxHealth", 0.15 }, { "Defense", 0.05 } }, Description = "+15% max health, +5% defense." },
	},
	Berserker = {
		Root = { Name = "Berserker", Effects = { { "PhysicalDamage", 0.1 }, { "Lifesteal", 0.03 } }, Description = "Unlocks Bloodrage. +10% physical damage, 3% lifesteal." },
		A = { Name = "Bloodlust", Effects = { { "Lifesteal", 0.03 } }, Description = "+3% lifesteal per rank." },
		B = { Name = "Rampage", Effects = { { "AttackSpeed", 0.06 } }, Description = "+6% attack speed per rank." },
		Cap = { Name = "Warlord's Fury", Effects = { { "CritDamage", 0.3 }, { "Ability.Whirlwind.Damage", 0.5 } }, Description = "+30% crit damage, Whirlwind +50% damage." },
	},
	Sharpshooter = {
		Root = { Name = "Sharpshooter", Effects = { { "Crit", 0.08 } }, Description = "Unlocks Deadeye. +8% critical chance." },
		A = { Name = "Steady Aim", Effects = { { "PhysicalDamage", 0.06 } }, Description = "+6% physical damage per rank." },
		B = { Name = "Quickdraw", Effects = { { "AttackSpeed", 0.06 } }, Description = "+6% attack speed per rank." },
		Cap = { Name = "Headhunter", Effects = { { "CritDamage", 0.5 } }, Description = "+50% critical damage." },
	},
	Trapper = {
		Root = { Name = "Trapper", Effects = { { "Ability.ArrowRain.Damage", 0.25 }, { "MoveSpeed", 0.08 } }, Description = "Unlocks Snare Field. Arrow Rain +25%, +8% move speed." },
		A = { Name = "Barbed Traps", Effects = { { "Ability.ArrowRain.Damage", 0.15 } }, Description = "Arrow Rain +15% damage per rank." },
		B = { Name = "Fleetfoot", Effects = { { "MoveSpeed", 0.05 } }, Description = "+5% move speed per rank." },
		Cap = { Name = "Warden of the Wild", Effects = { { "Cooldown", 0.1 }, { "MaxHealth", 0.1 } }, Description = "-10% cooldowns, +10% max health." },
	},
	Pyromancer = {
		Root = { Name = "Pyromancer", Effects = { { "SpellDamage", 0.12 } }, Description = "Unlocks Meteor. +12% spell damage." },
		A = { Name = "Kindling", Effects = { { "Ability.Fireball.Damage", 0.15 } }, Description = "Fireball +15% damage per rank." },
		B = { Name = "Combustion", Effects = { { "CritDamage", 0.15 } }, Description = "+15% critical damage per rank." },
		Cap = { Name = "Heart of Flame", Effects = { { "SpellDamage", 0.15 }, { "Crit", 0.05 } }, Description = "+15% spell damage, +5% crit." },
	},
	Frostweaver = {
		Root = { Name = "Frostweaver", Effects = { { "Defense", 0.1 }, { "Ability.FrostNova.Damage", 0.3 } }, Description = "Unlocks Blizzard. +10% defense, Frost Nova +30%." },
		A = { Name = "Permafrost", Effects = { { "Defense", 0.03 } }, Description = "+3% defense per rank." },
		B = { Name = "Shatter", Effects = { { "Crit", 0.04 } }, Description = "+4% critical chance per rank." },
		Cap = { Name = "Eternal Winter", Effects = { { "Cooldown", 0.12 }, { "MaxHealth", 0.1 } }, Description = "-12% cooldowns, +10% max health." },
	},
	Assassin = {
		Root = { Name = "Assassin", Effects = { { "Crit", 0.1 }, { "CritDamage", 0.2 } }, Description = "Unlocks Death Mark. +10% crit, +20% crit damage." },
		A = { Name = "Lethality", Effects = { { "PhysicalDamage", 0.06 } }, Description = "+6% physical damage per rank." },
		B = { Name = "Ambush", Effects = { { "Ability.Shadowstep.Damage", 0.2 } }, Description = "Shadowstep +20% damage per rank." },
		Cap = { Name = "Executioner", Effects = { { "CritDamage", 0.5 } }, Description = "+50% critical damage." },
	},
	Shadowdancer = {
		Root = { Name = "Shadowdancer", Effects = { { "AttackSpeed", 0.1 }, { "MoveSpeed", 0.06 } }, Description = "Unlocks Blade Flurry. +10% attack speed, +6% move speed." },
		A = { Name = "Flow", Effects = { { "AttackSpeed", 0.06 } }, Description = "+6% attack speed per rank." },
		B = { Name = "Smoke & Mirrors", Effects = { { "Defense", 0.03 } }, Description = "+3% defense per rank." },
		Cap = { Name = "Endless Dance", Effects = { { "Cooldown", 0.12 }, { "Lifesteal", 0.05 } }, Description = "-12% cooldowns, 5% lifesteal." },
	},
	Templar = {
		Root = { Name = "Templar", Effects = { { "SpellDamage", 0.08 }, { "Defense", 0.05 } }, Description = "Unlocks Judgment. +8% spell damage, +5% defense." },
		A = { Name = "Zeal", Effects = { { "SpellDamage", 0.06 } }, Description = "+6% spell damage per rank." },
		B = { Name = "Holy Armor", Effects = { { "Defense", 0.03 } }, Description = "+3% defense per rank." },
		Cap = { Name = "Avatar of Light", Effects = { { "Lifesteal", 0.08 }, { "SpellDamage", 0.1 } }, Description = "8% lifesteal, +10% spell damage." },
	},
	Oracle = {
		Root = { Name = "Oracle", Effects = { { "Healing", 0.2 } }, Description = "Unlocks Divine Hymn. +20% healing." },
		A = { Name = "Renewal", Effects = { { "Healing", 0.1 } }, Description = "+10% healing per rank." },
		B = { Name = "Foresight", Effects = { { "Cooldown", 0.04 } }, Description = "-4% cooldowns per rank." },
		Cap = { Name = "Miracle Worker", Effects = { { "Healing", 0.3 } }, Description = "+30% healing." },
	},
}

local trees = {} -- [classId] = { list = {...}, byId = {...} }

local function copyNode(node, extra)
	local out = table.clone(node)
	for k, v in extra do
		out[k] = v
	end
	return out
end

for classId, class in Classes.List do
	local list, byId = {}, {}
	local function add(node)
		table.insert(list, node)
		byId[node.Id] = node
	end
	for index, node in CORE do
		add(copyNode(node, { Branch = "Core", Tier = index, Requires = {}, Excludes = {} }))
	end
	for specIndex, specId in class.Specs do
		local tree = SPEC_TREES[specId]
		local otherSpec = class.Specs[3 - specIndex]
		local rootId, aId, bId, capId = specId, specId .. "A", specId .. "B", specId .. "Cap"
		add(copyNode(tree.Root, {
			Id = rootId, Branch = specId, Tier = 1, Level = 10, MaxRank = 1, Spec = specId,
			Requires = {}, Excludes = { otherSpec },
		}))
		add(copyNode(tree.A, { Id = aId, Branch = specId, Tier = 2, Level = 15, MaxRank = 3, Requires = { rootId }, Excludes = { bId } }))
		add(copyNode(tree.B, { Id = bId, Branch = specId, Tier = 2, Level = 15, MaxRank = 3, Requires = { rootId }, Excludes = { aId } }))
		add(copyNode(tree.Cap, { Id = capId, Branch = specId, Tier = 3, Level = 25, MaxRank = 1, Requires = { rootId }, Excludes = {} }))
	end
	trees[classId] = { List = list, ById = byId }
end

function Talents.ForClass(classId)
	return trees[Classes.Get(classId).Id].List
end

function Talents.Get(classId, nodeId)
	return trees[Classes.Get(classId).Id].ById[nodeId]
end

-- The specialization this profile has chosen, or nil.
function Talents.Spec(profile)
	local class = Classes.Get(profile.Class)
	for _, specId in class.Specs do
		if (profile.Talents[specId] or 0) > 0 then
			return Classes.Specs[specId]
		end
	end
	return nil
end

-- Returns "Learned" | "Available" | "Locked" | "Excluded" plus a reason, ignoring skill points.
function Talents.State(profile, node)
	local rank = profile.Talents[node.Id] or 0
	if rank >= node.MaxRank then
		return "Learned", "Maxed"
	end
	for _, other in node.Excludes do
		if (profile.Talents[other] or 0) > 0 then
			local blocker = Talents.Get(profile.Class, other)
			return "Excluded", "Locked by " .. (blocker and blocker.Name or other)
		end
	end
	if profile.Level < node.Level then
		return "Locked", "Requires level " .. node.Level
	end
	for _, required in node.Requires do
		if (profile.Talents[required] or 0) <= 0 then
			local req = Talents.Get(profile.Class, required)
			return "Locked", "Requires " .. (req and req.Name or required)
		end
	end
	return rank > 0 and "Learned" or "Available", nil
end

return Talents
