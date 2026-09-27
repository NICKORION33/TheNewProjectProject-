-- Every class ability. Behaviour comes from `Kind`; the numbers are data.
--
--   Strike      hitbox in front of the caster
--   Nova        burst around the caster (damage enemies and/or heal allies)
--   Projectile  travels toward the aim point; may pierce or explode
--   Dash        moves the caster toward the aim point, optionally hitting what it passes
--   Buff        temporary stat boost on the caster (and allies within Radius)
--   Heal        heals the caster and allies within Radius
--   Zone        area at the aim point that ticks damage/healing over time
--
-- Power / Heal are multiples of the equipped weapon's damage, scaled by the
-- caster's Physical or Spell power. Each rank above 1 adds 15% power and
-- trims 5% off the cooldown.

local Abilities = {}

local rgb = Color3.fromRGB

Abilities.MaxRank = 5
Abilities.RankPower = 0.15
Abilities.RankCooldown = 0.05
Abilities.LevelsPerRank = 4 -- each rank past the first needs this many more levels

Abilities.List = {
	-- Knight ---------------------------------------------------------------
	ShieldBash = {
		Name = "Shield Bash", Kind = "Strike", Stat = "Physical", Cooldown = 7,
		Power = 1.4, Range = 8, Stun = 1.2, Knockback = 45, Color = rgb(120, 170, 255),
		Description = "Slam enemies in front of you, stunning them.",
	},
	Whirlwind = {
		Name = "Whirlwind", Kind = "Nova", Stat = "Physical", Cooldown = 10,
		Power = 1.6, Radius = 11, Color = rgb(200, 220, 255),
		Description = "Spin your blade, hitting everything around you.",
	},
	RallyingCry = {
		Name = "Rallying Cry", Kind = "Buff", Stat = "Physical", Cooldown = 18,
		Radius = 30, Duration = 6, Heal = 0.8, Buff = { Defense = 0.15, Damage = 0.1 }, Color = rgb(255, 210, 90),
		Description = "Heal and embolden yourself and nearby party members.",
	},
	Bulwark = {
		Name = "Bulwark", Kind = "Buff", Stat = "Physical", Cooldown = 40, Ultimate = true,
		Radius = 30, Duration = 7, Heal = 1.5, Buff = { Defense = 0.35 }, Color = rgb(120, 200, 255),
		Description = "Raise an unbreakable wall: huge damage reduction for your party.",
	},
	Bloodrage = {
		Name = "Bloodrage", Kind = "Buff", Stat = "Physical", Cooldown = 40, Ultimate = true,
		Radius = 0, Duration = 8, Buff = { Damage = 0.4, Lifesteal = 0.2, Speed = 0.15 }, Color = rgb(255, 60, 60),
		Description = "Enter a frenzy: more damage, lifesteal and speed.",
	},

	-- Ranger ---------------------------------------------------------------
	PiercingShot = {
		Name = "Piercing Shot", Kind = "Projectile", Stat = "Physical", Cooldown = 6,
		Power = 1.6, Speed = 160, Range = 90, Size = 1.2, Pierce = true, Color = rgb(170, 255, 140),
		Description = "An arrow that passes through every enemy in a line.",
	},
	Tumble = {
		Name = "Tumble", Kind = "Dash", Stat = "Physical", Cooldown = 8,
		Distance = 22, Buff = { Speed = 0.25 }, Duration = 2, Color = rgb(150, 230, 150),
		Description = "Roll toward your aim and gain a burst of speed.",
	},
	ArrowRain = {
		Name = "Arrow Rain", Kind = "Zone", Stat = "Physical", Cooldown = 14,
		Power = 0.5, Range = 60, Radius = 12, Duration = 3, Ticks = 6, Slow = 0.3, Color = rgb(190, 255, 150),
		Description = "Rain arrows on an area, slowing and damaging enemies.",
	},
	Deadeye = {
		Name = "Deadeye", Kind = "Projectile", Stat = "Physical", Cooldown = 35, Ultimate = true,
		Power = 5, Speed = 240, Range = 140, Size = 1.6, Pierce = true, AlwaysCrit = true, Color = rgb(255, 255, 160),
		Description = "A guaranteed critical shot that crosses the map.",
	},
	SnareField = {
		Name = "Snare Field", Kind = "Zone", Stat = "Physical", Cooldown = 35, Ultimate = true,
		Power = 0.35, Range = 60, Radius = 16, Duration = 5, Ticks = 10, Slow = 0.6, Stun = 1.5, Color = rgb(120, 200, 90),
		Description = "Cover an area in traps that root, slow and wound.",
	},

	-- Mage -----------------------------------------------------------------
	Fireball = {
		Name = "Fireball", Kind = "Projectile", Stat = "Spell", Cooldown = 5,
		Power = 2, Speed = 90, Range = 80, Size = 2, Explode = 8, Color = rgb(255, 120, 40),
		Description = "Hurl a fireball that explodes on impact.",
	},
	FrostNova = {
		Name = "Frost Nova", Kind = "Nova", Stat = "Spell", Cooldown = 11,
		Power = 1, Radius = 12, Slow = 0.5, SlowDuration = 3, Color = rgb(140, 220, 255),
		Description = "Blast of cold that damages and slows everything nearby.",
	},
	Blink = {
		Name = "Blink", Kind = "Dash", Stat = "Spell", Cooldown = 9,
		Distance = 28, Teleport = true, Color = rgb(200, 150, 255),
		Description = "Teleport a short distance toward your aim.",
	},
	Meteor = {
		Name = "Meteor", Kind = "Zone", Stat = "Spell", Cooldown = 40, Ultimate = true,
		Power = 5, Range = 70, Radius = 14, Delay = 1, Duration = 0, Ticks = 1, Stun = 1, Color = rgb(255, 90, 30),
		Description = "Call down a meteor that crushes everything it lands on.",
	},
	Blizzard = {
		Name = "Blizzard", Kind = "Zone", Stat = "Spell", Cooldown = 40, Ultimate = true,
		Power = 0.45, Range = 70, Radius = 18, Duration = 6, Ticks = 12, Slow = 0.6, Color = rgb(170, 230, 255),
		Description = "A howling storm that freezes and grinds down enemies.",
	},

	-- Rogue ----------------------------------------------------------------
	Shadowstep = {
		Name = "Shadowstep", Kind = "Dash", Stat = "Physical", Cooldown = 7,
		Distance = 20, Power = 1.5, Color = rgb(150, 60, 90),
		Description = "Dash through enemies, cutting everything in your path.",
	},
	FanOfKnives = {
		Name = "Fan of Knives", Kind = "Nova", Stat = "Physical", Cooldown = 9,
		Power = 1.3, Radius = 11, Color = rgb(220, 220, 230),
		Description = "Throw knives in every direction.",
	},
	Evasion = {
		Name = "Evasion", Kind = "Buff", Stat = "Physical", Cooldown = 16,
		Radius = 0, Duration = 5, Buff = { Defense = 0.3, Speed = 0.3 }, Color = rgb(120, 120, 140),
		Description = "Become hard to hit and hard to catch.",
	},
	DeathMark = {
		Name = "Death Mark", Kind = "Strike", Stat = "Physical", Cooldown = 35, Ultimate = true,
		Power = 6, Range = 9, AlwaysCrit = true, Color = rgb(255, 40, 70),
		Description = "A single guaranteed critical strike of enormous power.",
	},
	BladeFlurry = {
		Name = "Blade Flurry", Kind = "Buff", Stat = "Physical", Cooldown = 35, Ultimate = true,
		Radius = 0, Duration = 8, Buff = { AttackSpeed = 0.6, Damage = 0.2 }, Color = rgb(255, 150, 170),
		Description = "Attack much faster and harder for a short time.",
	},

	-- Cleric ---------------------------------------------------------------
	Smite = {
		Name = "Smite", Kind = "Projectile", Stat = "Spell", Cooldown = 5,
		Power = 1.6, Speed = 110, Range = 80, Size = 1.4, Color = rgb(255, 230, 120),
		Description = "A bolt of holy light.",
	},
	Mend = {
		Name = "Mend", Kind = "Heal", Stat = "Spell", Cooldown = 9,
		Radius = 30, Heal = 2.2, Color = rgb(140, 255, 170),
		Description = "Heal yourself and party members around you.",
	},
	Sanctuary = {
		Name = "Sanctuary", Kind = "Zone", Stat = "Spell", Cooldown = 18,
		HealPower = 0.6, Range = 50, Radius = 14, Duration = 6, Ticks = 6, Color = rgb(255, 240, 170),
		Description = "Consecrate ground that heals allies standing in it.",
	},
	Judgment = {
		Name = "Judgment", Kind = "Nova", Stat = "Spell", Cooldown = 35, Ultimate = true,
		Power = 3.5, Radius = 16, Stun = 1.5, Color = rgb(255, 220, 90),
		Description = "Holy fire erupts around you, stunning all enemies.",
	},
	DivineHymn = {
		Name = "Divine Hymn", Kind = "Heal", Stat = "Spell", Cooldown = 45, Ultimate = true,
		Radius = 40, Heal = 6, Buff = { Defense = 0.2 }, Duration = 6, Color = rgb(200, 255, 220),
		Description = "A massive party heal that also hardens allies.",
	},
}

for id, def in Abilities.List do
	def.Id = id
end

function Abilities.Get(id)
	return Abilities.List[id]
end

-- Current rank of an ability (1..MaxRank) for a profile.
function Abilities.Rank(profile, id)
	return 1 + ((profile.AbilityRanks and profile.AbilityRanks[id]) or 0)
end

-- Level needed to buy `nextRank` of an ability whose slot unlocks at `slotUnlock`.
function Abilities.RankRequirement(slotUnlock, nextRank)
	return slotUnlock + (nextRank - 1) * Abilities.LevelsPerRank
end

function Abilities.PowerMult(rank)
	return 1 + Abilities.RankPower * (rank - 1)
end

function Abilities.CooldownMult(rank)
	return 1 - Abilities.RankCooldown * (rank - 1)
end

return Abilities
