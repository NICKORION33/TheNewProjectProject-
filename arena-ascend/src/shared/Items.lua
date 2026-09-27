-- Every item that can be bought in the Armory.
-- Prices are in Coins; Level is the minimum player level needed to buy it.

local Items = {}

Items.Categories = { "Weapons", "Armor", "Outfits" }

-- Which slot in profile.Equipped each category fills.
Items.SlotFor = {
	Weapons = "Weapon",
	Armor = "Armor",
	Outfits = "Outfit",
}

Items.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(176, 182, 196) },
	Rare = { Order = 2, Color = Color3.fromRGB(76, 156, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(184, 104, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 176, 48) },
	Mythic = { Order = 5, Color = Color3.fromRGB(255, 72, 104) },
}

local rgb = Color3.fromRGB

Items.Weapons = {
	{
		Id = "WoodenSword", Name = "Wooden Sword", Rarity = "Common", Price = 0, Level = 1,
		Damage = 12, Cooldown = 0.55, Range = 7, Crit = 0.05,
		BladeColor = rgb(160, 116, 72), HiltColor = rgb(92, 64, 40), BladeLength = 3, BladeWidth = 0.5,
		BladeMaterial = Enum.Material.Wood,
	},
	{
		Id = "IronBlade", Name = "Iron Blade", Rarity = "Common", Price = 250, Level = 2,
		Damage = 16, Cooldown = 0.55, Range = 7, Crit = 0.05,
		BladeColor = rgb(170, 174, 182), HiltColor = rgb(60, 60, 66), BladeLength = 3.2, BladeWidth = 0.5,
		BladeMaterial = Enum.Material.Metal,
	},
	{
		Id = "SteelLongsword", Name = "Steel Longsword", Rarity = "Rare", Price = 900, Level = 5,
		Damage = 22, Cooldown = 0.6, Range = 8, Crit = 0.06,
		BladeColor = rgb(205, 212, 222), HiltColor = rgb(40, 60, 110), BladeLength = 3.8, BladeWidth = 0.5,
		BladeMaterial = Enum.Material.Metal,
	},
	{
		Id = "TwinFang", Name = "Twin Fang", Rarity = "Rare", Price = 1200, Level = 8,
		Damage = 14, Cooldown = 0.32, Range = 6, Crit = 0.12,
		BladeColor = rgb(120, 220, 170), HiltColor = rgb(30, 40, 38), BladeLength = 2, BladeWidth = 0.4,
		BladeMaterial = Enum.Material.Metal,
	},
	{
		Id = "Frostbite", Name = "Frostbite Edge", Rarity = "Epic", Price = 3500, Level = 12,
		Damage = 30, Cooldown = 0.6, Range = 8, Crit = 0.1,
		BladeColor = rgb(170, 225, 255), HiltColor = rgb(40, 70, 110), BladeLength = 4, BladeWidth = 0.55,
		BladeMaterial = Enum.Material.Glass, Glow = rgb(120, 210, 255),
	},
	{
		Id = "Emberbrand", Name = "Emberbrand", Rarity = "Epic", Price = 5200, Level = 16,
		Damage = 34, Cooldown = 0.62, Range = 8, Crit = 0.1,
		BladeColor = rgb(60, 36, 30), HiltColor = rgb(120, 40, 20), BladeLength = 4, BladeWidth = 0.6,
		BladeMaterial = Enum.Material.Basalt, Glow = rgb(255, 110, 40),
	},
	{
		Id = "Stormcaller", Name = "Stormcaller", Rarity = "Legendary", Price = 12000, Level = 22,
		Damage = 42, Cooldown = 0.58, Range = 8.5, Crit = 0.15,
		BladeColor = rgb(230, 236, 255), HiltColor = rgb(40, 40, 80), BladeLength = 4.4, BladeWidth = 0.6,
		BladeMaterial = Enum.Material.Metal, Glow = rgb(255, 240, 120), Particles = true,
	},
	{
		Id = "Voidreaver", Name = "Voidreaver", Rarity = "Legendary", Price = 20000, Level = 30,
		Damage = 50, Cooldown = 0.65, Range = 9, Crit = 0.15,
		BladeColor = rgb(24, 16, 40), HiltColor = rgb(70, 30, 110), BladeLength = 4.8, BladeWidth = 0.7,
		BladeMaterial = Enum.Material.Glass, Glow = rgb(170, 80, 255), Particles = true,
	},
	{
		Id = "CrownOfRuin", Name = "Crown of Ruin", Rarity = "Mythic", Price = 45000, Level = 40,
		Damage = 68, Cooldown = 0.8, Range = 10, Crit = 0.18,
		BladeColor = rgb(40, 8, 12), HiltColor = rgb(200, 150, 40), BladeLength = 5.6, BladeWidth = 0.9,
		BladeMaterial = Enum.Material.Basalt, Glow = rgb(255, 40, 70), Particles = true,
	},
	{
		Id = "AscendantBlade", Name = "Ascendant Blade", Rarity = "Mythic", Price = 90000, Level = 55,
		Damage = 80, Cooldown = 0.6, Range = 10, Crit = 0.25,
		BladeColor = rgb(255, 250, 235), HiltColor = rgb(255, 200, 60), BladeLength = 5.2, BladeWidth = 0.75,
		BladeMaterial = Enum.Material.Neon, Glow = rgb(255, 215, 110), Particles = true,
	},
}

Items.Armor = {
	{
		Id = "ClothTunic", Name = "Cloth Tunic", Rarity = "Common", Price = 0, Level = 1,
		Health = 0, Defense = 0,
		Color = rgb(150, 130, 100), Material = Enum.Material.Fabric, Plates = false,
	},
	{
		Id = "LeatherGuard", Name = "Leather Guard", Rarity = "Common", Price = 300, Level = 3,
		Health = 20, Defense = 0.03,
		Color = rgb(120, 78, 46), Material = Enum.Material.Leather, Plates = true,
	},
	{
		Id = "Chainmail", Name = "Chainmail", Rarity = "Rare", Price = 1100, Level = 6,
		Health = 40, Defense = 0.06,
		Color = rgb(150, 156, 166), Material = Enum.Material.DiamondPlate, Plates = true,
	},
	{
		Id = "KnightPlate", Name = "Knight Plate", Rarity = "Epic", Price = 4000, Level = 14,
		Health = 70, Defense = 0.1,
		Color = rgb(196, 202, 214), Material = Enum.Material.Metal, Plates = true, Trim = rgb(76, 156, 255),
	},
	{
		Id = "Dragonscale", Name = "Dragonscale", Rarity = "Legendary", Price = 15000, Level = 25,
		Health = 120, Defense = 0.14,
		Color = rgb(40, 110, 70), Material = Enum.Material.Slate, Plates = true, Trim = rgb(255, 176, 48),
	},
	{
		Id = "CelestialAegis", Name = "Celestial Aegis", Rarity = "Mythic", Price = 60000, Level = 45,
		Health = 200, Defense = 0.2,
		Color = rgb(245, 240, 255), Material = Enum.Material.Marble, Plates = true, Trim = rgb(255, 215, 110),
		Aura = rgb(255, 230, 150),
	},
}

-- Outfits are purely cosmetic: body colours, plus capes, hoods, crowns, auras and trails.
-- Source: "Shop" (default, bought with Coins or Gems), "Class" (free with a class),
-- "Kit" (premium starter kits only), "Loot" (boss drops only).
Items.Outfits = {
	{
		Id = "Recruit", Name = "Recruit", Rarity = "Common", Price = 0, Level = 1,
		Primary = rgb(110, 116, 130), Secondary = rgb(50, 54, 64),
	},
	-- Class starter outfits
	{
		Id = "KnightTabard", Name = "Knight's Tabard", Rarity = "Common", Price = 0, Level = 1, Source = "Class", Class = "Knight",
		Primary = rgb(60, 92, 170), Secondary = rgb(62, 64, 74), Cape = rgb(40, 70, 150),
	},
	{
		Id = "RangerCloak", Name = "Ranger's Cloak", Rarity = "Common", Price = 0, Level = 1, Source = "Class", Class = "Ranger",
		Primary = rgb(62, 104, 62), Secondary = rgb(84, 66, 46), Hood = rgb(48, 84, 50),
	},
	{
		Id = "MageRobes", Name = "Mage Robes", Rarity = "Common", Price = 0, Level = 1, Source = "Class", Class = "Mage",
		Primary = rgb(84, 52, 146), Secondary = rgb(62, 40, 112), Hood = rgb(72, 42, 132),
	},
	{
		Id = "RogueLeathers", Name = "Rogue Leathers", Rarity = "Common", Price = 0, Level = 1, Source = "Class", Class = "Rogue",
		Primary = rgb(42, 38, 44), Secondary = rgb(30, 28, 32), Hood = rgb(120, 24, 36),
	},
	{
		Id = "ClericVestments", Name = "Cleric Vestments", Rarity = "Common", Price = 0, Level = 1, Source = "Class", Class = "Cleric",
		Primary = rgb(236, 230, 214), Secondary = rgb(200, 170, 96), Cape = rgb(232, 200, 112),
	},
	-- Coin outfits
	{
		Id = "CrimsonRanger", Name = "Crimson Ranger", Rarity = "Common", Price = 150, Level = 1,
		Primary = rgb(170, 40, 50), Secondary = rgb(40, 34, 36),
	},
	{
		Id = "OceanDrifter", Name = "Ocean Drifter", Rarity = "Rare", Price = 600, Level = 4,
		Primary = rgb(30, 110, 170), Secondary = rgb(230, 220, 190), Cape = rgb(20, 70, 120),
	},
	{
		Id = "ShadowNinja", Name = "Shadow Ninja", Rarity = "Rare", Price = 900, Level = 7,
		Primary = rgb(24, 24, 30), Secondary = rgb(18, 18, 22), Hood = rgb(24, 24, 30), Trail = rgb(255, 60, 80),
	},
	{
		Id = "GoldenKnight", Name = "Golden Knight", Rarity = "Epic", Price = 3000, Level = 12,
		Primary = rgb(220, 180, 70), Secondary = rgb(120, 30, 40), Cape = rgb(150, 20, 40), Crown = rgb(255, 205, 60),
	},
	{
		Id = "NeonPhantom", Name = "Neon Phantom", Rarity = "Epic", Price = 4500, Level = 18,
		Primary = rgb(20, 20, 34), Secondary = rgb(20, 20, 34), Trail = rgb(0, 255, 210), Aura = rgb(0, 255, 210),
	},
	{
		Id = "InfernoLord", Name = "Inferno Lord", Rarity = "Legendary", Price = 12000, Level = 28,
		Primary = rgb(60, 20, 16), Secondary = rgb(30, 12, 10), Cape = rgb(255, 90, 30),
		Aura = rgb(255, 110, 40), Trail = rgb(255, 150, 40), Fire = true,
	},
	{
		Id = "GalaxyEmperor", Name = "Galaxy Emperor", Rarity = "Mythic", Price = 40000, Level = 45,
		Primary = rgb(40, 20, 90), Secondary = rgb(14, 10, 40), Cape = rgb(110, 60, 220),
		Crown = rgb(255, 230, 140), Aura = rgb(190, 140, 255), Trail = rgb(140, 200, 255),
	},
	-- Gem outfits (premium currency, cosmetic only)
	{
		Id = "Starforged", Name = "Starforged", Rarity = "Epic", Price = 250, Currency = "Gems", Level = 1,
		Primary = rgb(30, 40, 80), Secondary = rgb(20, 24, 50), Cape = rgb(255, 200, 90), Trail = rgb(255, 220, 140),
	},
	{
		Id = "VoidSamurai", Name = "Void Samurai", Rarity = "Legendary", Price = 450, Currency = "Gems", Level = 1,
		Primary = rgb(16, 12, 24), Secondary = rgb(120, 20, 40), Hood = rgb(16, 12, 24), Aura = rgb(170, 60, 255), Trail = rgb(170, 60, 255),
	},
	{
		Id = "CelestialDragon", Name = "Celestial Dragon", Rarity = "Mythic", Price = 900, Currency = "Gems", Level = 1,
		Primary = rgb(240, 236, 255), Secondary = rgb(90, 200, 230), Cape = rgb(80, 210, 240),
		Crown = rgb(160, 240, 255), Aura = rgb(150, 240, 255), Trail = rgb(200, 250, 255),
	},
	-- Kit exclusives
	{
		Id = "Trailblazer", Name = "Trailblazer", Rarity = "Rare", Price = 0, Level = 1, Source = "Kit",
		Primary = rgb(200, 110, 40), Secondary = rgb(60, 50, 44), Cape = rgb(230, 140, 50), Trail = rgb(255, 180, 90),
	},
	{
		Id = "RoyalVanguard", Name = "Royal Vanguard", Rarity = "Epic", Price = 0, Level = 1, Source = "Kit",
		Primary = rgb(120, 20, 40), Secondary = rgb(230, 200, 120), Cape = rgb(90, 10, 30), Crown = rgb(255, 210, 90),
	},
	-- Boss drop
	{
		Id = "AshenCrown", Name = "Ashen Crown", Rarity = "Legendary", Price = 0, Level = 20, Source = "Loot",
		Primary = rgb(50, 44, 42), Secondary = rgb(30, 26, 26), Crown = rgb(255, 110, 50), Aura = rgb(255, 90, 40), Fire = true,
	},
}

-- Names each weapon takes in the hands of a staff or bow class.
local STYLE_NAMES = {
	WoodenSword = { Staff = "Oak Staff", Bow = "Hunting Bow" },
	IronBlade = { Staff = "Iron Rod", Bow = "Iron Recurve" },
	SteelLongsword = { Staff = "Adept's Staff", Bow = "Steel Longbow" },
	TwinFang = { Staff = "Viper Wand", Bow = "Twin Fang Bow" },
	Frostbite = { Staff = "Frostbite Staff", Bow = "Frostbite Bow" },
	Emberbrand = { Staff = "Ember Staff", Bow = "Emberstring" },
	Stormcaller = { Staff = "Stormcaller Staff", Bow = "Stormcaller Bow" },
	Voidreaver = { Staff = "Void Scepter", Bow = "Voidreaver Bow" },
	CrownOfRuin = { Staff = "Staff of Ruin", Bow = "Ruinshot" },
	AscendantBlade = { Staff = "Ascendant Staff", Bow = "Ascendant Bow" },
}

function Items.WeaponName(def, style)
	local names = STYLE_NAMES[def.Id]
	return names and names[style] or def.Name
end

function Items.Currency(def)
	return def.Currency or "Coins"
end

-- Only Shop items can be bought directly.
function Items.IsBuyable(def)
	return (def.Source or "Shop") == "Shop"
end

-- id -> def lookup per category
local lookup = {}
for _, category in Items.Categories do
	lookup[category] = {}
	for _, def in Items[category] do
		lookup[category][def.Id] = def
	end
end

function Items.Get(category, id)
	local map = lookup[category]
	return map and map[id] or nil
end

function Items.IsCategory(category)
	return lookup[category] ~= nil
end

return Items
