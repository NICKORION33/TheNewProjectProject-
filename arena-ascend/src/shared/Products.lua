-- Premium purchases (Robux developer products).
--
-- SETUP: create each product under Creator Dashboard > your experience >
-- Monetization > Developer Products, then paste its ID into ProductId below.
-- A ProductId of 0 means "not set up yet": the shop shows the item but
-- won't open a purchase prompt.
--
-- Fairness rules this game follows:
--   * Everything that raises combat stats can also be earned in play.
--   * Kit gear keeps its normal level requirement to equip.
--   * Gems buy cosmetics and kits only - never raw XP or stat points.

local Products = {}

Products.GemPacks = {
	{ Id = "GemsSmall", Name = "Pouch of Gems", Gems = 100, Robux = 49, ProductId = 0 },
	{ Id = "GemsMedium", Name = "Chest of Gems", Gems = 550, Robux = 249, ProductId = 0, Tag = "+10% bonus" },
	{ Id = "GemsLarge", Name = "Vault of Gems", Gems = 1200, Robux = 499, ProductId = 0, Tag = "Best value" },
}

-- One-time bundles. Buying a kit you already own is refunded as gems.
Products.Kits = {
	{
		Id = "AdventurerKit",
		Name = "Adventurer's Kit",
		Robux = 99,
		ProductId = 0,
		Coins = 2000,
		Gems = 50,
		Items = { Weapons = { "SteelLongsword" }, Armor = { "LeatherGuard" }, Outfits = { "Trailblazer" } },
		Blurb = "A head start for new heroes: a Rare weapon, armor, and the Trailblazer outfit.",
		RefundGems = 100,
	},
	{
		Id = "ChampionKit",
		Name = "Champion's Kit",
		Robux = 299,
		ProductId = 0,
		Coins = 6000,
		Gems = 150,
		Items = { Weapons = { "Frostbite" }, Armor = { "Chainmail" }, Outfits = { "RoyalVanguard" } },
		Blurb = "Epic weapon (usable at level 12), Chainmail, and the Royal Vanguard outfit.",
		RefundGems = 300,
	},
}

local byProductId = {}
local byId = {}
for _, list in { Products.GemPacks, Products.Kits } do
	for _, product in list do
		byId[product.Id] = product
		if product.ProductId ~= 0 then
			byProductId[product.ProductId] = product
		end
	end
end

function Products.ByProductId(productId)
	return byProductId[productId]
end

function Products.Get(id)
	return byId[id]
end

function Products.IsKit(product)
	return product.Items ~= nil
end

return Products
