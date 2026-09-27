-- Server-side purchases and equips. The client only ever asks; every check happens here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)

local ShopService = {}

local REQUEST_COOLDOWN = 0.25
local lastRequest = {}

local SOURCE_HINTS = {
	Class = "comes free with its class",
	Kit = "comes in a premium starter kit",
	Loot = "drops from the Ashen Warlord",
}

local function result(ok, message)
	return { Ok = ok, Message = message }
end

local function equip(player, data, category, def)
	data.Equipped[Items.SlotFor[category]] = def.Id
	LoadoutService.Refresh(player, category)
	DataService.Push(player)
end

local function handle(player, action, category, id)
	if type(action) ~= "string" or type(category) ~= "string" or type(id) ~= "string" then
		return result(false, "Invalid request.")
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return result(false, "Slow down!")
	end
	lastRequest[player] = now

	local data = DataService.Get(player)
	local def = Items.IsCategory(category) and Items.Get(category, id)
	if not (data and def) then
		return result(false, "That item doesn't exist.")
	end
	local owned = data.Owned[category][id] == true

	if action == "Buy" then
		if owned then
			return result(false, "You already own " .. def.Name .. ".")
		end
		if not Items.IsBuyable(def) then
			return result(false, def.Name .. " " .. (SOURCE_HINTS[def.Source] or "can't be bought") .. ".")
		end
		if data.Level < def.Level then
			return result(false, string.format("Reach level %d to unlock %s.", def.Level, def.Name))
		end
		local currency = Items.Currency(def)
		if data[currency] < def.Price then
			return result(false, string.format("You need %s more %s.", Format.Commas(def.Price - data[currency]), currency:lower()))
		end
		data[currency] -= def.Price
		data.Owned[category][id] = true
		equip(player, data, category, def)
		task.spawn(DataService.Save, player)
		return result(true, "Unlocked " .. def.Name .. "!")
	elseif action == "Equip" then
		if not owned then
			return result(false, "You don't own that yet.")
		end
		if data.Level < def.Level then
			-- Kit and loot gear keeps its level requirement.
			return result(false, string.format("%s can be equipped at level %d.", def.Name, def.Level))
		end
		equip(player, data, category, def)
		return result(true, def.Name .. " equipped.")
	end
	return result(false, "Unknown action.")
end

function ShopService.Init()
	Remotes.Shop.OnServerInvoke = handle
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
