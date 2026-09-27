-- Dresses each character in its outfit and armor, hands it the equipped
-- weapon in its class's style, applies computed stats (health, defense,
-- speed), and keeps an overhead nameplate showing level and class.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Classes = require(Shared.Classes)
local Stats = require(Shared.Stats)
local Visuals = require(Shared.Visuals)

local DataService = require(script.Parent.DataService)
local StatusService = require(script.Parent.StatusService)

local LoadoutService = {}

local OUTFIT_TAG = "OutfitFX"
local ARMOR_TAG = "ArmorFX"

local statsCache = {} -- [player] = computed stats

local function getTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function clearTagged(character, tag)
	for _, inst in character:GetDescendants() do
		if inst.Name == tag then
			inst:Destroy()
		end
	end
end

function LoadoutService.GetEquipped(player, category)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return Items.Get(category, data.Equipped[Items.SlotFor[category]])
end

-- Latest computed stats for a player (see Shared/Stats.lua).
function LoadoutService.GetStats(player)
	local cached = statsCache[player]
	if cached then
		return cached
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	cached = Stats.Compute(data)
	statsCache[player] = cached
	return cached
end

function LoadoutService.GetClass(player)
	local data = DataService.Get(player)
	return Classes.Get(data and data.Class)
end

function LoadoutService.ApplyOutfit(player)
	local character = player.Character
	local def = LoadoutService.GetEquipped(player, "Outfits")
	if not (character and def) then
		return
	end
	clearTagged(character, OUTFIT_TAG)

	-- Clothing textures would hide the body colours, so outfits replace them.
	for _, inst in character:GetChildren() do
		if inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then
			inst:Destroy()
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	bodyColors.TorsoColor3 = def.Primary
	bodyColors.LeftArmColor3 = def.Primary
	bodyColors.RightArmColor3 = def.Primary
	bodyColors.LeftLegColor3 = def.Secondary
	bodyColors.RightLegColor3 = def.Secondary

	-- Hoods would clip through hats and hair.
	if def.Hood then
		for _, accessory in character:GetChildren() do
			if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hat then
				accessory:Destroy()
			end
		end
	end

	local torso = getTorso(character)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local extras = Visuals.BuildOutfitExtras(def, torso and torso.Size, head and head.Size)
	if extras.Torso and torso then
		extras.Torso.Name = OUTFIT_TAG
		Visuals.AttachTo(extras.Torso, torso, character)
	end
	if extras.Head and head then
		extras.Head.Name = OUTFIT_TAG
		Visuals.AttachTo(extras.Head, head, character)
	end
	if root then
		Visuals.AddRootEffects(root, def, OUTFIT_TAG)
	end
end

function LoadoutService.ApplyArmor(player)
	local character = player.Character
	local def = LoadoutService.GetEquipped(player, "Armor")
	if not (character and def) then
		return
	end
	clearTagged(character, ARMOR_TAG)
	local torso = getTorso(character)
	if torso then
		local model = Visuals.BuildArmor(def, torso.Size)
		model.Name = ARMOR_TAG
		Visuals.AttachTo(model, torso, character)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and def.Aura then
		Visuals.AddRootEffects(root, { Aura = def.Aura }, ARMOR_TAG)
	end
end

function LoadoutService.GiveWeapon(player)
	local def = LoadoutService.GetEquipped(player, "Weapons")
	if not def then
		return
	end
	local class = LoadoutService.GetClass(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and tool:GetAttribute("WeaponId") then
					tool:Destroy()
				end
			end
		end
	end
	if not backpack then
		return
	end

	local model, gripZ = Visuals.BuildWeapon(def, class.WeaponStyle)
	local tool = Instance.new("Tool")
	tool.Name = Items.WeaponName(def, class.WeaponStyle)
	tool.ToolTip = string.format("%s %s", def.Rarity, class.WeaponStyle)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", def.Id)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool.GripPos = Vector3.new(0, 0, gripZ)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()

	local equipSound = Instance.new("Sound")
	equipSound.Name = "Unsheath"
	equipSound.SoundId = "rbxasset://sounds/unsheath.wav"
	equipSound.Volume = 0.6
	equipSound.Parent = tool.Handle
	local slash = Instance.new("Sound")
	slash.Name = "Slash"
	slash.SoundId = "rbxasset://sounds/swordslash.wav"
	slash.Volume = 0.7
	slash.Parent = tool.Handle
	tool.Equipped:Connect(function()
		equipSound:Play()
	end)

	LoadoutService.UpdateToolStats(player, tool)
	tool.Parent = backpack
	-- Weapons stay in hand: the ability bar replaces the backpack hotbar.
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

-- The client reads the attack cooldown and style from the tool.
function LoadoutService.UpdateToolStats(player, tool)
	local stats = LoadoutService.GetStats(player)
	if stats then
		tool:SetAttribute("Cooldown", stats.AttackCooldown)
		tool:SetAttribute("Attack", stats.Class.Attack)
	end
end

function LoadoutService.UpdateNameplate(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = DataService.Get(player)
	if not (head and humanoid and data) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local class = Classes.Get(data.Class)
	player:SetAttribute("Class", data.Class)

	local gui = head:FindFirstChild("Nameplate")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Nameplate"
		gui.Size = UDim2.fromOffset(200, 52)
		gui.StudsOffset = Vector3.new(0, 2.8, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.Parent = head

		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 20)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 16
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Text = player.DisplayName
		name.Parent = gui

		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Position = UDim2.fromOffset(0, 20)
		info.Size = UDim2.new(1, 0, 0, 16)
		info.Font = Enum.Font.GothamBold
		info.TextSize = 13
		info.TextStrokeTransparency = 0.5
		info.Parent = gui

		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, 40)
		bar.Size = UDim2.fromOffset(110, 6)
		bar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		bar.BorderSizePixel = 0
		bar.Parent = gui
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(96, 220, 140)
		fill.BorderSizePixel = 0
		fill.Parent = bar

		local function onHealth()
			fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
		end
		humanoid.HealthChanged:Connect(onHealth)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(onHealth)
	end
	local info = gui.Info
	if data.Class == "" then
		info.Text = "Lv " .. data.Level
		info.TextColor3 = Color3.fromRGB(200, 200, 210)
	else
		info.Text = string.format("Lv %d  %s", data.Level, class.Name)
		info.TextColor3 = class.Color
	end
end

-- Recomputes stats from the profile and applies them. `heal` fills health.
function LoadoutService.RefreshStats(player, heal)
	statsCache[player] = nil
	local stats = LoadoutService.GetStats(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (stats and humanoid) or humanoid.Health <= 0 then
		return
	end
	local oldMax = humanoid.MaxHealth
	local fraction = oldMax > 0 and humanoid.Health / oldMax or 1
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = heal and stats.MaxHealth or math.clamp(stats.MaxHealth * fraction, 1, stats.MaxHealth)
	humanoid:SetAttribute("BaseSpeed", stats.MoveSpeed)
	StatusService.Refresh(humanoid)
	character:SetAttribute("Defense", stats.Defense)

	local tool = character:FindFirstChildOfClass("Tool")
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool = tool or (backpack and backpack:FindFirstChildOfClass("Tool"))
	if tool then
		LoadoutService.UpdateToolStats(player, tool)
	end
	LoadoutService.UpdateNameplate(player)
end

-- Re-applies whatever a change in `category` affects. "All" rebuilds everything.
function LoadoutService.Refresh(player, category)
	statsCache[player] = nil
	if category == "Weapons" or category == "All" then
		LoadoutService.GiveWeapon(player)
	end
	if category == "Armor" or category == "All" then
		LoadoutService.ApplyArmor(player)
	end
	if category == "Outfits" or category == "All" then
		LoadoutService.ApplyOutfit(player)
	end
	LoadoutService.RefreshStats(player, false)
end

local function waitForAppearance(player)
	local deadline = os.clock() + 5
	while not player:HasAppearanceLoaded() and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	DataService.WaitFor(player)
	waitForAppearance(player)
	if player.Character ~= character then
		return
	end
	StatusService.Clear(humanoid)
	LoadoutService.ApplyOutfit(player)
	LoadoutService.ApplyArmor(player)
	LoadoutService.GiveWeapon(player)
	LoadoutService.RefreshStats(player, true)
end

function LoadoutService.Init()
	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		statsCache[player] = nil
	end)
end

return LoadoutService
