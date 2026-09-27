-- The Armory: Weapons / Armor / Outfits / Premium tabs, a grid of item cards
-- with 3D previews, and a detail pane with stats and the action button.
-- Weapon previews and names follow your class (blade, staff or bow).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared:WaitForChild("Classes"))
local Format = require(Shared:WaitForChild("Format"))
local Items = require(Shared:WaitForChild("Items"))
local Products = require(Shared:WaitForChild("Products"))
local Visuals = require(Shared:WaitForChild("Visuals"))
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local Shop = {}
Shop.__index = Shop

local PANEL_SIZE = Vector2.new(820, 540)
local TABS = { "Weapons", "Armor", "Outfits", "Premium" }
local SOURCE_TAGS = { Class = "CLASS", Kit = "KIT ONLY", Loot = "BOSS DROP" }

---------------------------------------------------------------------------
-- Previews
---------------------------------------------------------------------------

local function previewModel(category, def, style)
	if category == "Weapons" then
		local model = Visuals.BuildWeapon(def, style)
		model:PivotTo(CFrame.Angles(math.rad(-40), 0, 0))
		return model, Vector3.xAxis
	elseif category == "Armor" then
		return Visuals.BuildMannequin(Items.Get("Outfits", "Recruit"), def), Vector3.new(0.55, 0.15, -1)
	end
	return Visuals.BuildMannequin(def, nil), Vector3.new(0.55, 0.15, -1)
end

local function frameCamera(camera, model, direction)
	local cframe, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	local distance = extent / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.15
	camera.CFrame = CFrame.lookAt(cframe.Position + direction.Unit * distance, cframe.Position)
end

local function fillViewport(viewport, category, def, style)
	viewport:ClearAllChildren()
	local camera = new("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local model, direction = previewModel(category, def, style)
	model.Parent = viewport
	frameCamera(camera, model, direction)
	return model
end

local function makeViewport(props)
	local viewport = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.2, 0.6),
	})
	for key, value in props do
		viewport[key] = value
	end
	return viewport
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

function Shop.new(playerGui, shopRemote, callbacks)
	local self = setmetatable({}, Shop)
	self.Remote = shopRemote
	self.Callbacks = callbacks or {}
	self.Profile = nil
	self.Style = "Blade"
	self.Category = "Weapons"
	self.Selected = { Weapons = "WoodenSword", Armor = "ClothTunic", Outfits = "Recruit", Premium = "AdventurerKit" }
	self.Cards = {} -- [category][id] = card refs
	self.Busy = false

	local gui = new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.Gui = gui
	local dim = new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.4,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	dim.Activated:Connect(function()
		self:Close()
	end)

	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = C.Panel,
		Parent = gui,
	}, { Theme.corner(20), Theme.stroke(C.Stroke, 1.5) })
	self.Scale = new("UIScale", { Parent = panel })

	label({
		Text = "ARMORY",
		Font = Theme.Display,
		TextSize = 32,
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(300, 34),
		Parent = panel,
	})
	label({
		Text = "Elite gear and custom outfits",
		TextSize = 13,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(26, 48),
		Size = UDim2.fromOffset(300, 16),
		Parent = panel,
	})
	local wallet = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 20),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	})
	local coins, coinText = Theme.currencyPill("Coins", 40)
	coins.Parent = wallet
	self.CoinText = coinText
	local gems, gemText = Theme.currencyPill("Gems", 40)
	gems.Parent = wallet
	self.GemText = gemText
	local close = Theme.button("X", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(40, 40),
		TextColor3 = C.Text,
		Parent = panel,
	})
	close.Activated:Connect(function()
		self:Close()
	end)

	self.Tabs = {}
	for index, category in TABS do
		local tab = new("TextButton", {
			Position = UDim2.fromOffset(24 + (index - 1) * 124, 80),
			Size = UDim2.fromOffset(116, 40),
			BackgroundColor3 = C.Raised,
			Text = category,
			Font = Theme.Bold,
			TextSize = 15,
			TextColor3 = C.Muted,
			AutoButtonColor = false,
			Parent = panel,
		}, { Theme.round() })
		tab.Activated:Connect(function()
			self:SetCategory(category)
		end)
		self.Tabs[category] = tab
	end

	self.Grids = {}
	for _, category in TABS do
		local grid = new("ScrollingFrame", {
			Position = UDim2.fromOffset(24, 136),
			Size = UDim2.fromOffset(500, PANEL_SIZE.Y - 160),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Stroke,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = panel,
		}, {
			new("UIGridLayout", {
				CellSize = UDim2.fromOffset(154, 176),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		})
		self.Grids[category] = grid
		self.Cards[category] = {}
		if category == "Premium" then
			local order = 0
			for _, list in { Products.Kits, Products.GemPacks } do
				for _, product in list do
					order += 1
					self:BuildProductCard(product, order, grid)
				end
			end
		else
			for order, def in Items[category] do
				self:BuildCard(category, def, order, grid)
			end
		end
	end

	self:BuildDetail(panel)

	local function rescale()
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		self.BaseScale = math.min(1, (viewport.X - 24) / PANEL_SIZE.X, (viewport.Y - 24) / PANEL_SIZE.Y)
		self.Scale.Scale = self.BaseScale
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	self:SetCategory("Weapons")
	return self
end

local function cardShell(order, grid, rarityColor)
	local card = new("TextButton", {
		LayoutOrder = order,
		BackgroundColor3 = C.Raised,
		Text = "",
		AutoButtonColor = false,
		Parent = grid,
	}, { Theme.corner(14) })
	local stroke = Theme.stroke(C.Stroke, 1.5)
	stroke.Parent = card
	new("Frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.fromOffset(12, 0),
		BackgroundColor3 = rarityColor,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(2) })
	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = C.Hover
	end)
	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = C.Raised
	end)
	return card, stroke
end

function Shop:BuildCard(category, def, order, grid)
	local rarity = Items.Rarities[def.Rarity]
	local card, stroke = cardShell(order, grid, rarity.Color)
	local viewport = makeViewport({
		Position = UDim2.fromOffset(6, 8),
		Size = UDim2.new(1, -12, 0, 100),
		Parent = card,
	})
	fillViewport(viewport, category, def, self.Style)

	local name = label({
		Text = def.Name,
		Font = Theme.Bold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = card,
	})
	label({
		Text = def.Rarity:upper(),
		Font = Theme.Bold,
		TextSize = 10,
		TextColor3 = rarity.Color,
		Position = UDim2.fromOffset(12, 130),
		Size = UDim2.new(1, -24, 0, 12),
		Parent = card,
	})
	local status = label({
		Text = "",
		Font = Theme.Display,
		TextSize = 15,
		Position = UDim2.fromOffset(12, 148),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = card,
	})
	card.Activated:Connect(function()
		self.Selected[category] = def.Id
		self:Refresh()
	end)
	self.Cards[category][def.Id] = { Card = card, Stroke = stroke, Status = status, Name = name, Viewport = viewport, Def = def }
end

function Shop:BuildProductCard(product, order, grid)
	local isKit = Products.IsKit(product)
	local color = isKit and C.Gold or C.Gem
	local card, stroke = cardShell(order, grid, color)
	local art = new("Frame", {
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.new(1, -24, 0, 88),
		BackgroundColor3 = C.Panel,
		Parent = card,
	}, { Theme.corner(12) })
	if isKit then
		local kitWeapon = Items.Get("Weapons", product.Items.Weapons[1])
		local viewport = makeViewport({ Size = UDim2.fromScale(1, 1), Parent = art })
		fillViewport(viewport, "Weapons", kitWeapon, self.Style)
		self.KitViewports = self.KitViewports or {}
		table.insert(self.KitViewports, { Viewport = viewport, Def = kitWeapon })
	else
		local glyph = Theme.gem(56)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Parent = art
	end
	label({
		Text = product.Name,
		Font = Theme.Bold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = card,
	})
	label({
		Text = isKit and "STARTER KIT" or (product.Tag and product.Tag:upper() or "GEMS"),
		Font = Theme.Bold,
		TextSize = 10,
		TextColor3 = color,
		Position = UDim2.fromOffset(12, 130),
		Size = UDim2.new(1, -24, 0, 12),
		Parent = card,
	})
	local status = label({
		Text = "R$ " .. product.Robux,
		Font = Theme.Display,
		TextSize = 15,
		TextColor3 = C.Good,
		Position = UDim2.fromOffset(12, 148),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = card,
	})
	card.Activated:Connect(function()
		self.Selected.Premium = product.Id
		self:Refresh()
	end)
	self.Cards.Premium[product.Id] = { Card = card, Stroke = stroke, Status = status, Product = product }
end

function Shop:BuildDetail(panel)
	local detail = new("Frame", {
		Position = UDim2.fromOffset(PANEL_SIZE.X - 24 - 256, 80),
		Size = UDim2.fromOffset(256, PANEL_SIZE.Y - 104),
		BackgroundColor3 = C.Raised,
		Parent = panel,
	}, { Theme.corner(16) })
	self.DetailViewport = makeViewport({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 170),
		Parent = detail,
	})
	self.DetailArt = new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 170),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = detail,
	})
	local bigGem = Theme.gem(96)
	bigGem.AnchorPoint = Vector2.new(0.5, 0.5)
	bigGem.Position = UDim2.fromScale(0.5, 0.5)
	bigGem.Parent = self.DetailArt

	self.DetailName = label({
		Font = Theme.Display,
		TextSize = 22,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 184),
		Size = UDim2.new(1, -32, 0, 26),
		Parent = detail,
	})
	self.DetailRarity = label({
		Font = Theme.Bold,
		TextSize = 11,
		Position = UDim2.fromOffset(16, 212),
		Size = UDim2.new(1, -32, 0, 14),
		Parent = detail,
	})
	self.StatList = new("Frame", {
		Position = UDim2.fromOffset(16, 236),
		Size = UDim2.new(1, -32, 0, 150),
		BackgroundTransparency = 1,
		Parent = detail,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.Action = new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(1, -32, 0, 48),
		BackgroundColor3 = C.Gold,
		Font = Theme.Display,
		TextSize = 18,
		TextColor3 = C.Ink,
		Text = "",
		Parent = detail,
	}, { Theme.corner(12) })
	self.Action.Activated:Connect(function()
		self:OnAction()
	end)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function statsFor(category, def, style)
	if category == "Weapons" then
		local lines = {
			{ "Weapon damage", tostring(def.Damage) },
			{ "Attacks / sec", string.format("%.1f", 1 / def.Cooldown) },
			{ "Crit chance", Format.Percent(def.Crit) },
			{ "Note", "Abilities scale with it" },
		}
		if style == "Blade" then
			table.insert(lines, 3, { "Melee reach", string.format("%g studs", def.Range) })
		end
		return lines
	elseif category == "Armor" then
		return {
			{ "Bonus health", "+" .. def.Health },
			{ "Damage blocked", Format.Percent(def.Defense) },
		}
	end
	local features = {}
	for _, key in { "Cape", "Hood", "Crown", "Aura", "Trail", "Fire" } do
		if def[key] then
			table.insert(features, key == "Fire" and "Flames" or key)
		end
	end
	return {
		{ "Style", #features > 0 and table.concat(features, ", ") or "Classic colours" },
		{ "Effect", "Cosmetic only" },
	}
end

local function productLines(product)
	if not Products.IsKit(product) then
		return { { "Gems", Format.Commas(product.Gems) }, { "Use for", "Premium outfits" } }
	end
	local lines = {}
	for _, category in Items.Categories do
		for _, id in product.Items[category] or {} do
			local def = Items.Get(category, id)
			if def then
				local requirement = def.Level > 1 and (" (Lv " .. def.Level .. ")") or ""
				table.insert(lines, { Items.SlotFor[category], def.Name .. requirement })
			end
		end
	end
	table.insert(lines, { "Coins", "+" .. Format.Commas(product.Coins) })
	table.insert(lines, { "Gems", "+" .. product.Gems })
	return lines
end

function Shop:StateFor(category, def)
	local profile = self.Profile
	if not profile then
		return "LOADING", nil, C.Raised
	end
	local owned = profile.Owned[category][def.Id]
	local equipped = profile.Equipped[Items.SlotFor[category]] == def.Id
	if equipped then
		return "EQUIPPED", nil, C.Hover
	elseif owned then
		if profile.Level < def.Level then
			return "EQUIP AT LV " .. def.Level, nil, C.Hover
		end
		return "EQUIP", "Equip", C.XP
	elseif not Items.IsBuyable(def) then
		return SOURCE_TAGS[def.Source] or "UNAVAILABLE", nil, C.Hover
	elseif profile.Level < def.Level then
		return "UNLOCKS AT LV " .. def.Level, nil, C.Hover
	end
	local currency = Items.Currency(def)
	if profile[currency] < def.Price then
		return "NEED " .. Format.Short(def.Price - profile[currency]) .. " MORE", nil, C.Hover
	end
	return "BUY  " .. Format.Commas(def.Price) .. (currency == "Gems" and " GEMS" or ""), "Buy", currency == "Gems" and C.Gem or C.Gold
end

function Shop:SetCategory(category)
	self.Category = category
	for name, grid in self.Grids do
		grid.Visible = name == category
	end
	for name, tab in self.Tabs do
		local active = name == category
		tab.BackgroundColor3 = active and C.Text or C.Raised
		tab.TextColor3 = active and C.Ink or C.Muted
	end
	self:Refresh()
end

function Shop:RefreshCards()
	local profile = self.Profile
	for category, cards in self.Cards do
		for id, ref in cards do
			local selected = self.Selected[category] == id
			local accent = ref.Def and Items.Rarities[ref.Def.Rarity].Color or C.Gold
			ref.Stroke.Color = selected and accent or C.Stroke
			ref.Stroke.Thickness = selected and 2.5 or 1.5
			if not profile then
				continue
			end
			if ref.Product then
				local ownedKit = Products.IsKit(ref.Product) and profile.Kits[id]
				ref.Status.Text = ownedKit and "OWNED" or ("R$ " .. ref.Product.Robux)
				ref.Status.TextColor3 = ownedKit and C.XP or C.Good
				continue
			end
			local def = ref.Def
			if category == "Weapons" then
				ref.Name.Text = Items.WeaponName(def, self.Style)
			end
			local owned = profile.Owned[category][id]
			local equipped = profile.Equipped[Items.SlotFor[category]] == id
			if equipped then
				ref.Status.Text, ref.Status.TextColor3 = "EQUIPPED", C.Good
			elseif owned then
				ref.Status.Text, ref.Status.TextColor3 = "OWNED", C.XP
			elseif not Items.IsBuyable(def) then
				ref.Status.Text, ref.Status.TextColor3 = SOURCE_TAGS[def.Source] or "", C.Muted
			elseif profile.Level < def.Level then
				ref.Status.Text, ref.Status.TextColor3 = "LV " .. def.Level, C.Muted
			elseif Items.Currency(def) == "Gems" then
				ref.Status.Text, ref.Status.TextColor3 = def.Price .. " GEMS", C.Gem
			else
				ref.Status.Text = def.Price == 0 and "FREE" or Format.Short(def.Price)
				ref.Status.TextColor3 = C.Gold
			end
		end
	end
end

function Shop:ShowLines(lines)
	for _, child in self.StatList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, line in lines do
		local row = new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Parent = self.StatList,
		})
		label({ Text = line[1], TextColor3 = C.Muted, TextSize = 13, Size = UDim2.fromScale(0.45, 1), Parent = row })
		label({
			Text = line[2],
			Font = Theme.Bold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromScale(0.3, 0),
			Size = UDim2.fromScale(0.7, 1),
			Parent = row,
		})
	end
end

function Shop:Refresh()
	local profile = self.Profile
	if profile then
		self.CoinText.Text = Format.Commas(profile.Coins)
		self.GemText.Text = Format.Commas(profile.Gems)
	end
	self:RefreshCards()

	local category = self.Category
	if category == "Premium" then
		local product = Products.Get(self.Selected.Premium)
		local isKit = Products.IsKit(product)
		self.DetailName.Text = product.Name
		self.DetailRarity.Text = isKit and "ONE-TIME STARTER KIT" or "PREMIUM CURRENCY"
		self.DetailRarity.TextColor3 = isKit and C.Gold or C.Gem
		self:ShowLines(productLines(product))
		self.DetailArt.Visible = not isKit
		self.DetailViewport.Visible = isKit
		if isKit and self.DetailKey ~= product.Id then
			self.DetailKey = product.Id
			self.DetailModel = fillViewport(self.DetailViewport, "Weapons", Items.Get("Weapons", product.Items.Weapons[1]), self.Style)
			self.DetailPivot = self.DetailModel:GetPivot()
			self.DetailSpin = 0
		end
		local ownedKit = isKit and profile and profile.Kits[product.Id]
		self.Action.Text = ownedKit and "OWNED" or ("BUY  R$ " .. product.Robux)
		self.Action.BackgroundColor3 = ownedKit and C.Hover or C.Good
		self.Action.TextColor3 = ownedKit and C.Muted or C.Ink
		self.PendingAction = not ownedKit and "Robux" or nil
		return
	end

	self.DetailArt.Visible = false
	self.DetailViewport.Visible = true
	local def = Items.Get(category, self.Selected[category])
	if not def then
		return
	end
	local rarity = Items.Rarities[def.Rarity]
	self.DetailName.Text = category == "Weapons" and Items.WeaponName(def, self.Style) or def.Name
	local tag = SOURCE_TAGS[def.Source] or (def.Price == 0 and "STARTER" or ("LV " .. def.Level))
	self.DetailRarity.Text = def.Rarity:upper() .. "  -  " .. tag
	self.DetailRarity.TextColor3 = rarity.Color
	self:ShowLines(statsFor(category, def, self.Style))

	local key = category .. def.Id .. self.Style
	if self.DetailKey ~= key then
		self.DetailKey = key
		self.DetailModel = fillViewport(self.DetailViewport, category, def, self.Style)
		self.DetailPivot = self.DetailModel:GetPivot()
		self.DetailSpin = 0
	end

	local text, action, color = self:StateFor(category, def)
	self.Action.Text = text
	self.Action.BackgroundColor3 = color
	self.Action.TextColor3 = action and C.Ink or C.Muted
	self.Action.AutoButtonColor = action ~= nil
	self.PendingAction = action
end

function Shop:OnAction()
	local action = self.PendingAction
	if not action or self.Busy then
		return
	end
	local toast = self.Callbacks.OnToast
	if action == "Robux" then
		local product = Products.Get(self.Selected.Premium)
		if product.ProductId == 0 then
			if toast then
				toast("This product isn't set up yet (add its ID in Products.lua).", C.Gold)
			end
			return
		end
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.ProductId)
		return
	end

	self.Busy = true
	local category, id = self.Category, self.Selected[self.Category]
	self.Action.Text = "..."
	local ok, response = pcall(self.Remote.InvokeServer, self.Remote, action, category, id)
	self.Busy = false
	if not ok or type(response) ~= "table" then
		if toast then
			toast("The Armory is busy - try again.", C.Danger)
		end
	elseif toast then
		toast(response.Message, response.Ok and C.Good or C.Danger)
	end
	self:Refresh()
end

function Shop:Update(profile)
	self.Profile = profile
	local style = Classes.Get(profile.Class).WeaponStyle
	if style ~= self.Style then
		-- Class changed: redraw weapon previews in the new style.
		self.Style = style
		for _, ref in self.Cards.Weapons do
			fillViewport(ref.Viewport, "Weapons", ref.Def, style)
		end
		for _, entry in self.KitViewports or {} do
			fillViewport(entry.Viewport, "Weapons", entry.Def, style)
		end
		self.DetailKey = nil
	end
	self:Refresh()
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

function Shop:Open()
	if self.Gui.Enabled then
		return
	end
	self.Gui.Enabled = true
	self.Scale.Scale = self.BaseScale * 0.92
	TweenService:Create(self.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = self.BaseScale }):Play()
	self:Refresh()
	self.SpinConnection = RunService.RenderStepped:Connect(function(dt)
		if self.DetailModel and self.DetailModel.Parent then
			self.DetailSpin += dt * 0.8
			self.DetailModel:PivotTo(CFrame.Angles(0, self.DetailSpin, 0) * self.DetailPivot)
		end
	end)
end

function Shop:Close()
	self.Gui.Enabled = false
	if self.SpinConnection then
		self.SpinConnection:Disconnect()
		self.SpinConnection = nil
	end
end

function Shop:Toggle()
	if self.Gui.Enabled then
		self:Close()
	else
		self:Open()
	end
end

return Shop
