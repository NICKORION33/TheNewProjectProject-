-- Playable classes. Each has its own base stats and growth, weapon style,
-- basic attack, three core abilities, and two specializations (chosen at
-- level 10 in the talent tree) that each unlock a different ultimate.

local Classes = {}

local rgb = Color3.fromRGB

Classes.Order = { "Knight", "Ranger", "Mage", "Rogue", "Cleric" }

-- Level at which each ability slot unlocks. Slot 4 also needs a specialization.
Classes.SlotUnlockLevels = { 1, 3, 6, 10 }

Classes.List = {
	Knight = {
		Id = "Knight",
		Name = "Knight",
		Role = "Frontline tank",
		Description = "Heavy armor and a shield arm. Soaks up punishment and keeps the party standing.",
		Color = rgb(96, 150, 255),
		WeaponStyle = "Blade",
		Attack = "Melee",
		AttackStat = "Physical",
		AttackMult = 1,
		AttackCooldownMult = 1,
		Base = { Strength = 6, Intellect = 1, Vitality = 7, Agility = 2 },
		Growth = { Strength = 1, Intellect = 0.2, Vitality = 1.2, Agility = 0.4 },
		BaseHealth = 140,
		HealthPerLevel = 7,
		Speed = 15,
		Abilities = { "ShieldBash", "Whirlwind", "RallyingCry" },
		Specs = { "Guardian", "Berserker" },
		Outfit = "KnightTabard",
		Difficulty = 1,
	},
	Ranger = {
		Id = "Ranger",
		Name = "Ranger",
		Role = "Ranged marksman",
		Description = "Picks targets apart from a distance and stays out of reach with quick tumbles.",
		Color = rgb(110, 200, 110),
		WeaponStyle = "Bow",
		Attack = "Arrow",
		AttackStat = "Physical",
		AttackMult = 0.85,
		AttackCooldownMult = 1.05,
		Base = { Strength = 4, Intellect = 2, Vitality = 4, Agility = 7 },
		Growth = { Strength = 0.8, Intellect = 0.2, Vitality = 0.7, Agility = 1.2 },
		BaseHealth = 105,
		HealthPerLevel = 5,
		Speed = 17,
		Abilities = { "PiercingShot", "Tumble", "ArrowRain" },
		Specs = { "Sharpshooter", "Trapper" },
		Outfit = "RangerCloak",
		Difficulty = 2,
	},
	Mage = {
		Id = "Mage",
		Name = "Mage",
		Role = "Spell artillery",
		Description = "Fragile, but hits the hardest of anyone. Controls fights with fire and frost.",
		Color = rgb(180, 110, 255),
		WeaponStyle = "Staff",
		Attack = "Bolt",
		AttackStat = "Spell",
		AttackMult = 0.8,
		AttackCooldownMult = 1.1,
		Base = { Strength = 1, Intellect = 8, Vitality = 3, Agility = 3 },
		Growth = { Strength = 0.2, Intellect = 1.4, Vitality = 0.6, Agility = 0.5 },
		BaseHealth = 90,
		HealthPerLevel = 4,
		Speed = 16,
		Abilities = { "Fireball", "FrostNova", "Blink" },
		Specs = { "Pyromancer", "Frostweaver" },
		Outfit = "MageRobes",
		Difficulty = 3,
	},
	Rogue = {
		Id = "Rogue",
		Name = "Rogue",
		Role = "Burst assassin",
		Description = "Fast, slippery and deadly up close. Wins fights before they start.",
		Color = rgb(255, 84, 100),
		WeaponStyle = "Blade",
		Attack = "Melee",
		AttackStat = "Physical",
		AttackMult = 0.8,
		AttackCooldownMult = 0.75,
		Base = { Strength = 5, Intellect = 1, Vitality = 3, Agility = 8 },
		Growth = { Strength = 0.9, Intellect = 0.1, Vitality = 0.6, Agility = 1.3 },
		BaseHealth = 100,
		HealthPerLevel = 5,
		Speed = 18,
		Abilities = { "Shadowstep", "FanOfKnives", "Evasion" },
		Specs = { "Assassin", "Shadowdancer" },
		Outfit = "RogueLeathers",
		Difficulty = 3,
	},
	Cleric = {
		Id = "Cleric",
		Name = "Cleric",
		Role = "Healer and support",
		Description = "Heals and shields allies, and smites anyone who threatens them. Parties love a Cleric.",
		Color = rgb(255, 214, 110),
		WeaponStyle = "Staff",
		Attack = "Bolt",
		AttackStat = "Spell",
		AttackMult = 0.7,
		AttackCooldownMult = 1.1,
		Base = { Strength = 2, Intellect = 6, Vitality = 6, Agility = 2 },
		Growth = { Strength = 0.3, Intellect = 1.1, Vitality = 1, Agility = 0.4 },
		BaseHealth = 115,
		HealthPerLevel = 5,
		Speed = 16,
		Abilities = { "Smite", "Mend", "Sanctuary" },
		Specs = { "Templar", "Oracle" },
		Outfit = "ClericVestments",
		Difficulty = 1,
	},
}

Classes.Specs = {
	Guardian = { Id = "Guardian", Class = "Knight", Name = "Guardian", Ultimate = "Bulwark", Summary = "Unkillable protector" },
	Berserker = { Id = "Berserker", Class = "Knight", Name = "Berserker", Ultimate = "Bloodrage", Summary = "Lifestealing brawler" },
	Sharpshooter = { Id = "Sharpshooter", Class = "Ranger", Name = "Sharpshooter", Ultimate = "Deadeye", Summary = "Long-range crits" },
	Trapper = { Id = "Trapper", Class = "Ranger", Name = "Trapper", Ultimate = "SnareField", Summary = "Area control" },
	Pyromancer = { Id = "Pyromancer", Class = "Mage", Name = "Pyromancer", Ultimate = "Meteor", Summary = "Explosive burst" },
	Frostweaver = { Id = "Frostweaver", Class = "Mage", Name = "Frostweaver", Ultimate = "Blizzard", Summary = "Slows and survives" },
	Assassin = { Id = "Assassin", Class = "Rogue", Name = "Assassin", Ultimate = "DeathMark", Summary = "One-shot executions" },
	Shadowdancer = { Id = "Shadowdancer", Class = "Rogue", Name = "Shadowdancer", Ultimate = "BladeFlurry", Summary = "Relentless flurries" },
	Templar = { Id = "Templar", Class = "Cleric", Name = "Templar", Ultimate = "Judgment", Summary = "Battle priest" },
	Oracle = { Id = "Oracle", Class = "Cleric", Name = "Oracle", Ultimate = "DivineHymn", Summary = "Master healer" },
}

-- Falls back to Knight for a profile that hasn't picked a class yet.
function Classes.Get(classId)
	return Classes.List[classId] or Classes.List.Knight
end

function Classes.IsValid(classId)
	return Classes.List[classId] ~= nil
end

return Classes
