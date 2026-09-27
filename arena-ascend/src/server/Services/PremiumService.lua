-- Robux developer products: gem packs and starter kits.
-- ProcessReceipt only reports PurchaseGranted once the grant is saved, and
-- remembers receipt IDs so a retried receipt is never granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)

local PremiumService = {}

local MAX_REMEMBERED_RECEIPTS = 100
local GOLD = Color3.fromRGB(255, 190, 70)

local function grantKit(player, data, kit)
	if data.Kits[kit.Id] then
		data.Gems += kit.RefundGems
		return string.format("You already own the %s - refunded %d gems.", kit.Name, kit.RefundGems)
	end
	data.Kits[kit.Id] = true
	data.Coins += kit.Coins
	data.Gems += kit.Gems
	for category, ids in kit.Items do
		for _, id in ids do
			if Items.Get(category, id) then
				data.Owned[category][id] = true
			end
		end
	end
	return string.format("%s unlocked! Check the Armory for your new gear.", kit.Name)
end

local function grant(player, data, product)
	if Products.IsKit(product) then
		return grantKit(player, data, product)
	end
	data.Gems += product.Gems
	return string.format("+%d gems. Thank you for supporting the game!", product.Gems)
end

local function rememberReceipt(data, purchaseId)
	data.Receipts[purchaseId] = true
	table.insert(data.ReceiptOrder, purchaseId)
	while #data.ReceiptOrder > MAX_REMEMBERED_RECEIPTS do
		data.Receipts[table.remove(data.ReceiptOrder, 1)] = nil
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitFor(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Receipts[receipt.PurchaseId] then
		-- Already granted; only confirm once that grant is safely stored.
		return DataService.Save(player) and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Products.ByProductId(receipt.ProductId)
	if not product then
		warn("[PremiumService] Receipt for unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local message = grant(player, data, product)
	rememberReceipt(data, receipt.PurchaseId)
	DataService.Push(player)
	if not DataService.Save(player) then
		-- Roblox will retry the receipt; the stored receipt ID stops a double grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	LoadoutService.RefreshStats(player, false)
	Remotes.Notify:FireClient(player, "Toast", { Text = message, Color = GOLD })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PremiumService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return PremiumService
