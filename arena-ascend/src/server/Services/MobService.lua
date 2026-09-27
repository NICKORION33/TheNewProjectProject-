-- PvE enemies in The Wilds. Each mob is a real R15 rig that chases players
-- in its aggro range, attacks (melee or ranged), leashes back to its camp,
-- and pays out XP, coins and loot to the killer's party.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Visuals = require(Shared.Visuals)

local CombatService = require(script.Parent.CombatService)
local StatusService = require(script.Parent.StatusService)
local RewardService = require(script.Parent.RewardService)

local MobService = {}

local rgb = Color3.fromRGB
local LEASH = 90
local TICK = 0.2
local ANIMATIONS = {
	Walk = "rbxassetid://507777826",
	Slash = "rbxassetid://522635514",
}

MobService.Types = {
	Goblin = {
		Name = "Goblin Raider", Level = 5, Health = 260, Damage = 10, AttackRange = 5, AttackCooldown = 1.2,
		Speed = 14, Aggro = 40, XP = 45, Coins = 25, Respawn = 8, Scale = 0.8,
		Skin = rgb(112, 162, 72), Shirt = rgb(112, 72, 40), Pants = rgb(72, 52, 32),
		Weapon = "IronBlade", Style = "Blade",
		Loot = { { "Weapons", "IronBlade", 0.03 }, { "Armor", "LeatherGuard", 0.03 } },
	},
	Skeleton = {
		Name = "Skeleton Archer", Level = 10, Health = 320, Damage = 12, AttackRange = 45, AttackCooldown = 1.8,
		Ranged = true, ProjectileSpeed = 80, Speed = 12, Aggro = 55, XP = 70, Coins = 35, Respawn = 10, Scale = 1,
		Skin = rgb(226, 220, 200), Shirt = rgb(200, 194, 176), Pants = rgb(180, 174, 156),
		Weapon = "SteelLongsword", Style = "Bow",
		Loot = { { "Weapons", "SteelLongsword", 0.03 }, { "Armor", "Chainmail", 0.03 }, { "Weapons", "TwinFang", 0.02 } },
	},
	Brute = {
		Name = "Orc Brute", Level = 18, Health = 1200, Damage = 28, AttackRange = 7, AttackCooldown = 1.8,
		Speed = 12, Aggro = 40, XP = 220, Coins = 120, Respawn = 15, Scale = 1.4,
		Skin = rgb(92, 122, 82), Shirt = rgb(72, 52, 42), Pants = rgb(52, 42, 32),
		Weapon = "Emberbrand", Style = "Blade", Armor = "KnightPlate",
		Loot = { { "Weapons", "Frostbite", 0.04 }, { "Armor", "KnightPlate", 0.03 }, { "Weapons", "Emberbrand", 0.03 } },
	},
	Warlord = {
		Name = "Ashen Warlord", Boss = true, Level = 30, Health = 12000, Damage = 45, AttackRange = 9, AttackCooldown = 1.6,
		Speed = 13, Aggro = 60, XP = 2500, Coins = 1500, Respawn = 180, Scale = 2.2,
		Skin = rgb(62, 52, 50), Shirt = rgb(42, 32, 32), Pants = rgb(32, 26, 26),
		Weapon = "CrownOfRuin", Style = "Blade", Armor = "Dragonscale",
		Slam = { Radius = 16, Damage = 60, Cooldown = 8, Windup = 1.2 },
		Loot = {
			{ "Weapons", "Stormcaller", 0.25 },
			{ "Armor", "Dragonscale", 0.2 },
			{ "Weapons", "Voidreaver", 0.1 },
			{ "Weapons", "CrownOfRuin", 0.05 },
			{ "Outfits", "AshenCrown", 0.15 },
		},
	},
}

local function attachWeapon(model, def)
	local hand = model:FindFirstChild("RightHand")
	local weaponDef = Items.Get("Weapons", def.Weapon)
	if not (hand and weaponDef) then
		return
	end
	local weapon, gripZ = Visuals.BuildWeapon(weaponDef, def.Style)
	if def.Scale ~= 1 then
		weapon:ScaleTo(def.Scale)
		gripZ *= def.Scale
	end
	local handle = weapon.PrimaryPart
	local grip = hand:FindFirstChild("RightGripAttachment")
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = (grip and grip.CFrame or CFrame.new(0, -hand.Size.Y / 2, 0)) * CFrame.Angles(-math.rad(90), 0, 0)
	weld.C1 = CFrame.new(0, 0, gripZ)
	weld.Parent = handle
	weapon.Name = "Weapon"
	weapon.Parent = model
end

local function buildMob(def, spawnCFrame)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = def.Skin
	description.LeftArmColor = def.Skin
	description.RightArmColor = def.Skin
	description.TorsoColor = def.Shirt
	description.LeftLegColor = def.Pants
	description.RightLegColor = def.Pants
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[MobService] Couldn't build rig:", model)
		return nil
	end
	model.Name = def.Name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.DisplayName = string.format("%sLv %d  %s", def.Boss and "BOSS  " or "", def.Level, def.Name)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = def.Boss and 150 or 70
	humanoid.HealthDisplayDistance = def.Boss and 150 or 70
	humanoid:SetAttribute("BaseSpeed", def.Speed)
	humanoid.WalkSpeed = def.Speed

	model:SetAttribute("Enemy", true)
	model:SetAttribute("Defense", def.Boss and 0.15 or 0)
	model:PivotTo(spawnCFrame * CFrame.new(0, 3, 0))
	if def.Scale ~= 1 then
		model:ScaleTo(def.Scale)
	end
	attachWeapon(model, def)
	local armorDef = def.Armor and Items.Get("Armor", def.Armor)
	local torso = model:FindFirstChild("UpperTorso")
	if armorDef and torso then
		Visuals.AttachTo(Visuals.BuildArmor(armorDef, torso.Size), torso, model)
	end
	if def.Boss then
		local root = model:FindFirstChild("HumanoidRootPart")
		Visuals.AddRootEffects(root, { Aura = rgb(255, 90, 40), Fire = true }, "BossFX")
	end
	return model, humanoid
end

local function loadTracks(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok then
			tracks[name] = track
		end
	end
	if tracks.Walk then
		tracks.Walk.Looped = true
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 and not tracks.Walk.IsPlaying then
				tracks.Walk:Play(0.2)
			elseif speed <= 0.5 and tracks.Walk.IsPlaying then
				tracks.Walk:Stop(0.2)
			end
		end)
	end
	return tracks
end

local function playerTarget(player, root, def, home)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and targetRoot) or not CombatService.IsEnemy(nil, humanoid) then
		return nil
	end
	if (targetRoot.Position - home).Magnitude > LEASH then
		return nil
	end
	return humanoid, targetRoot, (targetRoot.Position - root.Position).Magnitude
end

local function chooseTarget(humanoid, root, def, home)
	-- Fight back against whoever hit us last, even from outside aggro range.
	local attackerId = humanoid:GetAttribute("LastAttacker")
	local hitTime = humanoid:GetAttribute("LastHitTime")
	if attackerId and hitTime and os.clock() - hitTime < 8 then
		local h, r = playerTarget(Players:GetPlayerByUserId(attackerId), root, def, home)
		if h then
			return h, r
		end
	end
	local bestHumanoid, bestRoot, bestDistance
	for _, player in Players:GetPlayers() do
		local h, r, distance = playerTarget(player, root, def, home)
		if h and distance <= def.Aggro and (not bestDistance or distance < bestDistance) then
			bestHumanoid, bestRoot, bestDistance = h, r, distance
		end
	end
	return bestHumanoid, bestRoot
end

local function bossSlam(model, humanoid, root, def, tracks)
	local slam = def.Slam
	Remotes.Effect:FireAllClients("Zone", {
		Position = root.Position - Vector3.new(0, 3 * def.Scale, 0),
		Radius = slam.Radius,
		Duration = 0,
		Delay = slam.Windup,
		Color = rgb(255, 80, 40),
	})
	StatusService.Stun(humanoid, slam.Windup)
	task.wait(slam.Windup)
	if humanoid.Health <= 0 then
		return
	end
	if tracks.Slash then
		tracks.Slash:Play()
	end
	Remotes.Effect:FireAllClients("Ring", { Position = root.Position, Radius = slam.Radius, Color = rgb(255, 80, 40) })
	for _, target in CombatService.InRadius(root.Position, slam.Radius, function(h)
		return CombatService.IsEnemy(nil, h)
	end) do
		CombatService.Damage(nil, target, slam.Damage, { SourceHumanoid = humanoid })
		StatusService.Stun(target, 0.8)
	end
end

local function runAI(model, humanoid, def, home)
	local root = model:FindFirstChild("HumanoidRootPart")
	local tracks = loadTracks(humanoid)
	local nextAttack, nextSlam = 0, os.clock() + 5
	while humanoid.Health > 0 and model.Parent do
		task.wait(TICK)
		if humanoid.Health <= 0 then
			break
		end
		if StatusService.IsStunned(humanoid) then
			humanoid:MoveTo(root.Position)
			continue
		end
		local targetHumanoid, targetRoot = chooseTarget(humanoid, root, def, home)
		if not targetHumanoid or (root.Position - home).Magnitude > LEASH then
			-- Walk home and recover.
			if (root.Position - home).Magnitude > 4 then
				humanoid:MoveTo(home)
			end
			if humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.02)
			end
			continue
		end

		local now = os.clock()
		local distance = (targetRoot.Position - root.Position).Magnitude
		local reach = def.AttackRange * def.Scale ^ 0.5
		if def.Slam and now >= nextSlam and distance <= def.Slam.Radius then
			nextSlam = now + def.Slam.Cooldown
			humanoid:MoveTo(root.Position)
			bossSlam(model, humanoid, root, def, tracks)
			continue
		end
		if distance > reach * 0.9 then
			humanoid:MoveTo(targetRoot.Position)
			continue
		end
		humanoid:MoveTo(root.Position)
		local flatTarget = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, flatTarget)
		if now < nextAttack then
			continue
		end
		nextAttack = now + def.AttackCooldown
		if tracks.Slash then
			tracks.Slash:Play()
		end
		if def.Ranged then
			local origin = root.Position + Vector3.new(0, 1.5, 0)
			CombatService.FireProjectile({
				Owner = nil,
				Exclude = { model },
				Origin = origin + (targetRoot.Position - origin).Unit * 2,
				Direction = targetRoot.Position - origin,
				Speed = def.ProjectileSpeed,
				Range = def.AttackRange + 15,
				Size = 0.8,
				Color = rgb(200, 230, 255),
				OnHit = function(target)
					CombatService.Damage(nil, target, def.Damage, { SourceHumanoid = humanoid })
				end,
			})
		else
			task.delay(0.25, function()
				if humanoid.Health > 0 and targetRoot.Parent and (targetRoot.Position - root.Position).Magnitude <= reach + 2 then
					CombatService.Damage(nil, targetHumanoid, def.Damage, { SourceHumanoid = humanoid })
				end
			end)
		end
	end
end

local function runSpawn(spawnPart, container)
	local def = MobService.Types[spawnPart:GetAttribute("MobType")]
	if not def then
		return
	end
	local home = spawnPart.Position
	while spawnPart.Parent do
		local model, humanoid = buildMob(def, spawnPart.CFrame)
		if not model then
			task.wait(30)
			continue
		end
		model.Parent = container
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			root:SetNetworkOwner(nil)
		end
		if def.Boss then
			Remotes.Notify:FireAllClients("Toast", {
				Text = def.Name .. " has risen in The Wilds! Gather a party.",
				Color = rgb(255, 110, 60),
			})
		end
		task.spawn(runAI, model, humanoid, def, home)

		humanoid.Died:Wait()
		local killer = CombatService.GetKiller(humanoid)
		if killer then
			RewardService.Kill(killer, def.XP, def.Coins, def.Name, root and root.Position or home, def.Loot)
			if def.Boss then
				Remotes.Notify:FireAllClients("Toast", {
					Text = killer.DisplayName .. "'s party defeated the " .. def.Name .. "!",
					Color = rgb(255, 190, 70),
				})
			end
		end
		task.wait(3)
		model:Destroy()
		task.wait(def.Respawn)
	end
end

function MobService.Init(map)
	local container = Instance.new("Folder")
	container.Name = "Mobs"
	container.Parent = workspace
	for _, spawnPart in map.MobSpawns:GetChildren() do
		task.spawn(runSpawn, spawnPart, container)
	end
end

return MobService
