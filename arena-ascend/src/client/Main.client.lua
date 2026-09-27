-- Client entry point: HUD, ability bar, menus, input and server notifications.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Zones = require(Shared:WaitForChild("Zones"))

local UI = script.Parent:WaitForChild("UI")
local HUD = require(UI:WaitForChild("HUD"))
local Shop = require(UI:WaitForChild("Shop"))
local AbilityBar = require(UI:WaitForChild("AbilityBar"))
local CharacterMenu = require(UI:WaitForChild("CharacterMenu"))
local ClassSelect = require(UI:WaitForChild("ClassSelect"))
local PartyUI = require(UI:WaitForChild("PartyUI"))
local Controllers = script.Parent:WaitForChild("Controllers")
local CombatController = require(Controllers:WaitForChild("CombatController"))
local AbilityController = require(Controllers:WaitForChild("AbilityController"))
local VFXController = require(Controllers:WaitForChild("VFXController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Our own health bar and ability bar replace the default ones.
for _, coreType in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
end

local shop, hero, classSelect, party, bar
local latestProfile

local function toast(text, color)
	-- Defined before the HUD exists; looked up lazily.
	if HUD.Instance then
		HUD.Instance:Toast(text, color)
	end
end

local hud = HUD.new(playerGui, {
	OnShop = function()
		shop:Toggle()
	end,
	OnCharacter = function()
		hero:Toggle()
	end,
	OnParty = function()
		party:ToggleMenu()
	end,
})
HUD.Instance = hud

shop = Shop.new(playerGui, Remotes.Shop, { OnToast = toast })
classSelect = ClassSelect.new(playerGui, Remotes.Progression, { OnToast = toast })
hero = CharacterMenu.new(playerGui, Remotes.Progression, {
	OnToast = toast,
	OnChangeClass = function()
		if latestProfile then
			classSelect:Show(latestProfile)
		end
	end,
})
party = PartyUI.new(hud.Gui, Remotes.Party, { OnToast = toast })

local function menuOpen()
	return shop.Gui.Enabled or hero.Gui.Enabled or classSelect:IsOpen()
end

bar = AbilityBar.new(hud.Gui, function(slot)
	if AbilityController.Cast then
		AbilityController.Cast(slot)
	end
end)

local function onProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	latestProfile = profile
	hud:Update(profile)
	shop:Update(profile)
	hero:Update(profile)
	bar:Update(profile)
	if profile.Class == "" and not classSelect:IsOpen() then
		classSelect:Show(profile)
	end
end
Remotes.ProfileUpdated.OnClientEvent:Connect(onProfile)
task.spawn(function()
	onProfile(Remotes.RequestProfile:InvokeServer())
end)

Remotes.PartyUpdated.OnClientEvent:Connect(function(snapshot)
	party:SetParty(snapshot)
end)

Remotes.Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "Toast" then
		hud:Toast(data.Text, data.Color)
	elseif kind == "Reward" then
		hud:Reward(data)
	elseif kind == "LevelUp" then
		hud:LevelUp(data)
	elseif kind == "KillFeed" then
		hud:KillFeed(data)
	elseif kind == "Loot" then
		hud:Loot(data)
	elseif kind == "PartyInvite" then
		party:ShowInvite(data)
	end
end)

local function onStreak()
	hud:SetStreak(player:GetAttribute("Streak") or 0)
end
player:GetAttributeChangedSignal("Streak"):Connect(onStreak)
onStreak()

-- Health bar follows the current character.
local function watchHealth(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local function update()
		bar:SetHealth(humanoid.Health, humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end
player.CharacterAdded:Connect(watchHealth)
if player.Character then
	task.spawn(watchHealth, player.Character)
end

-- Menu hotkeys
local function bindMenu(name, key, callback)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin and not classSelect:IsOpen() then
			callback()
		end
		return Enum.ContextActionResult.Pass
	end, false, key)
end
bindMenu("ToggleArmory", Enum.KeyCode.B, function()
	shop:Toggle()
end)
bindMenu("ToggleHero", Enum.KeyCode.C, function()
	hero:Toggle()
end)
bindMenu("ToggleParty", Enum.KeyCode.P, function()
	party:ToggleMenu()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		shop:Open()
	end
end)

CombatController.CanAttack = function()
	return not menuOpen()
end
CombatController.Start()
AbilityController.Start(bar, function()
	return not menuOpen()
end)
VFXController.Start()

-- Safe-zone banner
task.spawn(function()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		hud:SetSafe(root ~= nil and Zones.IsSafe(root.Position))
		task.wait(0.3)
	end
end)
