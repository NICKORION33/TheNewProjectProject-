-- The grind loop: training dummies that respawn and pay XP + coins, and
-- coin crystals scattered around the Training Grounds and the Pit.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LevelService = require(script.Parent.LevelService)
local CombatService = require(script.Parent.CombatService)
local RewardService = require(script.Parent.RewardService)

local GrindService = {}

local TIERS = {
	Straw = {
		Name = "Straw Dummy", Health = 150, XP = 25, Coins = 15, Respawn = 4,
		Body = Color3.fromRGB(206, 174, 96), Eyes = Color3.fromRGB(40, 30, 20), Scale = 1,
	},
	Iron = {
		Name = "Iron Sentinel", Health = 700, XP = 110, Coins = 70, Respawn = 6,
		Body = Color3.fromRGB(140, 146, 160), Eyes = Color3.fromRGB(90, 200, 255), Scale = 1.2,
	},
	Golem = {
		Name = "Elite Golem", Health = 2500, XP = 450, Coins = 300, Respawn = 10,
		Body = Color3.fromRGB(78, 56, 120), Eyes = Color3.fromRGB(255, 72, 104), Scale = 1.6,
	},
}

local MAX_CRYSTALS = 14
local CRYSTAL_RESPAWN = 6
local CRYSTAL_COLOR = Color3.fromRGB(90, 230, 255)

local function body(model, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildDummy(tier, spawnCFrame)
	local s = tier.Scale
	local model = Instance.new("Model")
	model.Name = tier.Name

	local base = spawnCFrame * CFrame.new(0, 0, 0)
	body(model, "Stand", Vector3.new(3, 0.5, 3) * s, base * CFrame.new(0, 0.25 * s, 0), Color3.fromRGB(60, 50, 44), Enum.Material.Wood)
	body(model, "Post", Vector3.new(0.5, 2.5, 0.5) * s, base * CFrame.new(0, 1.5 * s, 0), Color3.fromRGB(96, 70, 48), Enum.Material.Wood)
	local root = body(model, "HumanoidRootPart", Vector3.new(2, 2, 1) * s, base * CFrame.new(0, 3.75 * s, 0), tier.Body)
	root.Transparency = 1
	root.CanCollide = false
	body(model, "Torso", Vector3.new(2, 2, 1) * s, root.CFrame, tier.Body, Enum.Material.Fabric)
	local head = body(model, "Head", Vector3.new(1.3, 1.3, 1.3) * s, root.CFrame * CFrame.new(0, 1.65 * s, 0), tier.Body, Enum.Material.Fabric)
	for _, x in { -0.3, 0.3 } do
		body(model, "Eye", Vector3.new(0.22, 0.22, 0.05) * s, head.CFrame * CFrame.new(x * s, 0.1 * s, -0.66 * s), tier.Eyes, Enum.Material.Neon)
	end
	for _, side in { -1, 1 } do
		body(model, "Arm", Vector3.new(1.6, 0.5, 0.5) * s, root.CFrame * CFrame.new(side * 1.8 * s, 0.6 * s, 0), tier.Body, Enum.Material.Fabric)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = tier.Health
	humanoid.Health = tier.Health
	humanoid.DisplayName = tier.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("Dummy", true)
	model:SetAttribute("Enemy", true)
	return model, humanoid
end

local function knockOver(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Stand" and p.Name ~= "HumanoidRootPart" then
			p.Anchored = false
			p.CanCollide = true
			p.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), 18, math.random(-12, 12))
		end
	end
end

local function runDummy(spawnPart, container)
	local tier = TIERS[spawnPart:GetAttribute("Tier")] or TIERS.Straw
	while spawnPart.Parent do
		local model, humanoid = buildDummy(tier, spawnPart.CFrame)
		model.Parent = container
		humanoid.Died:Wait()

		local killer = CombatService.GetKiller(humanoid)
		if killer then
			RewardService.Kill(killer, tier.XP, tier.Coins, tier.Name, spawnPart.Position, nil)
		end
		knockOver(model)
		task.wait(1.5)
		model:Destroy()
		task.wait(tier.Respawn)
	end
end

local function randomPointIn(zone)
	local half = zone.Size / 2
	local offset = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * Vector3.new(half.X, 0, half.Z)
	return (zone.CFrame * CFrame.new(offset)).Position + Vector3.new(0, 0.8, 0)
end

local function spawnCrystal(zones, container)
	local zone = zones[math.random(1, #zones)]
	local position = randomPointIn(zone)

	local crystal = Instance.new("Part")
	crystal.Name = "CoinCrystal"
	crystal.Size = Vector3.new(1.2, 2.2, 1.2)
	crystal.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi, math.rad(12))
	crystal.Color = CRYSTAL_COLOR
	crystal.Material = Enum.Material.Neon
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CanQuery = false
	crystal.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = CRYSTAL_COLOR
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = crystal
	crystal.Parent = container

	TweenService:Create(
		crystal,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = crystal.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.pi / 2, 0) }
	):Play()

	local claimed = false
	crystal.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (player and humanoid and humanoid.Health > 0) then
			return
		end
		claimed = true
		crystal:Destroy()
		LevelService.Grant(player, 10, math.random(8, 20), "Coin Crystal")
	end)
	return crystal
end

function GrindService.Init(map)
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	for _, spawnPart in map.DummySpawns:GetChildren() do
		task.spawn(runDummy, spawnPart, dummies)
	end

	local crystals = Instance.new("Folder")
	crystals.Name = "CoinCrystals"
	crystals.Parent = workspace
	local zones = map.CrystalZones:GetChildren()
	task.spawn(function()
		while true do
			if #crystals:GetChildren() < MAX_CRYSTALS then
				spawnCrystal(zones, crystals)
			end
			task.wait(CRYSTAL_RESPAWN)
		end
	end)
end

return GrindService
