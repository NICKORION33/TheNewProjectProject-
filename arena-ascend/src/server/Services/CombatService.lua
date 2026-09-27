-- Server-authoritative combat: who can hurt whom, damage and healing math,
-- hitbox queries, simulated projectiles, basic attacks and knockout rewards.
-- Abilities and mobs all go through the functions here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)
local StatusService = require(script.Parent.StatusService)
local PartyService = require(script.Parent.PartyService)
local RewardService = require(script.Parent.RewardService)

local CombatService = {}

local KILL_CREDIT_WINDOW = 10 -- seconds a hit counts toward a knockout
local COOLDOWN_TOLERANCE = 0.85 -- accept swings slightly early to absorb network jitter
local MAX_DEFENSE = 0.8

local lastSwing = {}
local streaks = {}

---------------------------------------------------------------------------
-- Targeting rules
---------------------------------------------------------------------------

local function rootOf(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function inSafeZone(model)
	local root = rootOf(model)
	return root ~= nil and Zones.IsSafe(root.Position)
end

-- The Humanoid that owns `part`, if any.
function CombatService.HumanoidOf(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Can `attacker` (a Player, or nil for a mob) damage this humanoid?
function CombatService.IsEnemy(attacker, humanoid)
	if humanoid.Health <= 0 then
		return false
	end
	local model = humanoid.Parent
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if attacker == nil then
		-- Mobs only fight players outside the safe zone.
		return targetPlayer ~= nil and not inSafeZone(model)
	end
	if targetPlayer then
		if PartyService.AreAllies(attacker, targetPlayer) then
			return false
		end
		if inSafeZone(model) or inSafeZone(attacker.Character) then
			return false
		end
		return model:FindFirstChildOfClass("ForceField") == nil
	end
	return model:GetAttribute("Enemy") == true
end

-- Is this humanoid the caster or one of the caster's living party members?
function CombatService.IsAlly(caster, humanoid)
	if humanoid.Health <= 0 then
		return false
	end
	local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	return targetPlayer ~= nil and PartyService.AreAllies(caster, targetPlayer)
end

local function collect(parts, filter)
	local found, seen = {}, {}
	for _, part in parts do
		local humanoid = CombatService.HumanoidOf(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			if filter(humanoid) then
				table.insert(found, humanoid)
			end
		end
	end
	return found
end

function CombatService.InBox(cframe, size, filter)
	return collect(workspace:GetPartBoundsInBox(cframe, size), filter)
end

function CombatService.InRadius(position, radius, filter)
	return collect(workspace:GetPartBoundsInRadius(position, radius), filter)
end

---------------------------------------------------------------------------
-- Damage and healing
---------------------------------------------------------------------------

function CombatService.RollCrit(stats, always)
	if always or math.random() < stats.Crit then
		return true, stats.CritDamage
	end
	return false, 1
end

-- Deals `amount` (before buffs and defense) from `attacker` (Player or nil).
-- opts.SourceHumanoid: the attacking mob's humanoid, for its buffs.
function CombatService.Damage(attacker, humanoid, amount, opts)
	opts = opts or {}
	if not CombatService.IsEnemy(attacker, humanoid) then
		return 0
	end
	local model = humanoid.Parent
	local sourceHumanoid = opts.SourceHumanoid
	if attacker and attacker.Character then
		sourceHumanoid = attacker.Character:FindFirstChildOfClass("Humanoid")
	end
	local damageMult = 1 + (sourceHumanoid and StatusService.GetBuff(sourceHumanoid, "Damage") or 0)
	local defense = (model:GetAttribute("Defense") or 0) + StatusService.GetBuff(humanoid, "Defense")
	local dealt = math.max(1, math.floor(amount * damageMult * (1 - math.clamp(defense, 0, MAX_DEFENSE)) + 0.5))

	if attacker then
		humanoid:SetAttribute("LastAttacker", attacker.UserId)
		humanoid:SetAttribute("LastHitTime", os.clock())
	end
	humanoid:TakeDamage(dealt)

	local root = rootOf(model) or model:FindFirstChildWhichIsA("BasePart")
	if attacker then
		if root then
			Remotes.HitMarker:FireClient(attacker, root.Position, dealt, opts.Crit == true, false)
		end
		local stats = LoadoutService.GetStats(attacker)
		local lifesteal = (stats and stats.Lifesteal or 0)
			+ (sourceHumanoid and StatusService.GetBuff(sourceHumanoid, "Lifesteal") or 0)
		if lifesteal > 0 and sourceHumanoid then
			CombatService.Heal(nil, sourceHumanoid, dealt * lifesteal)
		end
	end
	if opts.OnDamaged then
		opts.OnDamaged(humanoid)
	end
	return dealt
end

function CombatService.Heal(caster, humanoid, amount)
	if humanoid.Health <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	local healed = math.floor(humanoid.Health - before)
	local root = rootOf(humanoid.Parent)
	if caster and healed >= 1 and root then
		Remotes.HitMarker:FireClient(caster, root.Position, healed, false, true)
	end
	return healed
end

---------------------------------------------------------------------------
-- Projectiles (simulated here, drawn by every client)
---------------------------------------------------------------------------

-- p = { Owner, Exclude, Origin, Direction, Speed, Range, Size, Pierce, Color,
--       OnHit(humanoid, position), OnImpact(position) }
function CombatService.FireProjectile(p)
	local direction = p.Direction.Unit
	Remotes.Effect:FireAllClients("Projectile", {
		Origin = p.Origin,
		Direction = direction,
		Speed = p.Speed,
		Range = p.Range,
		Size = p.Size,
		Color = p.Color,
	})

	local exclude = table.clone(p.Exclude or {})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	task.spawn(function()
		local position, travelled = p.Origin, 0
		local hit = {}
		while travelled < p.Range do
			local dt = RunService.Heartbeat:Wait()
			local step = math.min(p.Speed * dt, p.Range - travelled)
			local result = workspace:Spherecast(position, p.Size / 2, direction * step, params)
			if not result then
				position += direction * step
				travelled += step
				continue
			end
			local humanoid = CombatService.HumanoidOf(result.Instance)
			local isEnemy = humanoid ~= nil and CombatService.IsEnemy(p.Owner, humanoid)
			if isEnemy and not hit[humanoid] then
				hit[humanoid] = true
				if p.OnHit then
					p.OnHit(humanoid, result.Position)
				end
			end
			if humanoid and (not isEnemy or p.Pierce) then
				-- Fly through allies (and through enemies when piercing).
				table.insert(exclude, humanoid.Parent)
				params.FilterDescendantsInstances = exclude
				travelled += (result.Position - position).Magnitude
				position = result.Position
				continue
			end
			position = result.Position
			break
		end
		Remotes.Effect:FireAllClients("Impact", { Position = position, Color = p.Color })
		if p.OnImpact then
			p.OnImpact(position)
		end
	end)
end

---------------------------------------------------------------------------
-- Basic attacks
---------------------------------------------------------------------------

function CombatService.AimDirection(root, aim)
	if typeof(aim) == "Vector3" and aim == aim and aim.Magnitude < 1e5 then
		local offset = aim - root.Position
		if offset.Magnitude > 1 then
			return offset.Unit
		end
	end
	return root.CFrame.LookVector
end

local function playSlash(tool)
	-- The default Animate script plays its slash animation when it sees this value.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	local slash = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Slash")
	if slash then
		slash:Play()
	end
end
CombatService.PlaySlash = playSlash

local function onAttack(player, aim)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)
	local stats = LoadoutService.GetStats(player)
	if not (humanoid and root and stats) or humanoid.Health <= 0 or StatusService.IsStunned(humanoid) then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not (tool and tool:GetAttribute("WeaponId") == stats.Weapon.Id) then
		return
	end

	local cooldown = stats.AttackCooldown / (1 + StatusService.GetBuff(humanoid, "AttackSpeed"))
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < cooldown * COOLDOWN_TOLERANCE then
		return
	end
	lastSwing[player] = now
	playSlash(tool)

	local class = stats.Class
	local color = stats.Weapon.Glow or class.Color
	if class.Attack == "Melee" then
		local range = stats.Weapon.Range
		local box = root.CFrame * CFrame.new(0, 0, -range / 2)
		Remotes.Effect:FireAllClients("Slash", { CFrame = box, Range = range, Color = color })
		local targets = CombatService.InBox(box, Vector3.new(range * 0.9, 7, range), function(h)
			return h.Parent ~= character and CombatService.IsEnemy(player, h)
		end)
		for _, target in targets do
			local isCrit, mult = CombatService.RollCrit(stats)
			CombatService.Damage(player, target, stats.AttackDamage * mult, { Crit = isCrit })
		end
	else
		local isArrow = class.Attack == "Arrow"
		local direction = CombatService.AimDirection(root, aim)
		CombatService.FireProjectile({
			Owner = player,
			Exclude = { character },
			Origin = root.Position + Vector3.new(0, 1, 0) + direction * 2,
			Direction = direction,
			Speed = isArrow and 140 or 100,
			Range = isArrow and 80 or 65,
			Size = isArrow and 0.8 or 1.2,
			Color = color,
			OnHit = function(target)
				local isCrit, mult = CombatService.RollCrit(stats)
				CombatService.Damage(player, target, stats.AttackDamage * mult, { Crit = isCrit })
			end,
		})
	end
end

---------------------------------------------------------------------------
-- Knockouts
---------------------------------------------------------------------------

-- Who gets credit for this humanoid's knockout, if anyone.
function CombatService.GetKiller(humanoid)
	local userId = humanoid:GetAttribute("LastAttacker")
	local hitTime = humanoid:GetAttribute("LastHitTime")
	if not (userId and hitTime) or os.clock() - hitTime > KILL_CREDIT_WINDOW then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function setStreak(player, value)
	streaks[player] = value
	player:SetAttribute("Streak", value)
end

local function onPlayerDied(victim, humanoid)
	local victimData = DataService.Get(victim)
	local victimStreak = streaks[victim] or 0
	setStreak(victim, 0)
	StatusService.Clear(humanoid)
	if victimData then
		victimData.Deaths += 1
		DataService.Push(victim)
	end

	local killer = CombatService.GetKiller(humanoid)
	local killerData = killer and killer ~= victim and DataService.Get(killer)
	if not killerData then
		return
	end

	local streak = (streaks[killer] or 0) + 1
	setStreak(killer, streak)
	killerData.Kills += 1
	killerData.BestStreak = math.max(killerData.BestStreak, streak)

	local xp, coins = Levels.KillReward(victimData and victimData.Level or 1, victimStreak)
	local source = "Knocked out " .. victim.DisplayName
	if victimStreak >= 3 then
		source = string.format("Ended %s's %d streak", victim.DisplayName, victimStreak)
	end
	local root = rootOf(humanoid.Parent)
	RewardService.Kill(killer, xp, coins, source, root and root.Position or Vector3.zero, nil)

	local weapon = LoadoutService.GetEquipped(killer, "Weapons")
	local class = LoadoutService.GetClass(killer)
	Remotes.Notify:FireAllClients("KillFeed", {
		Killer = killer.DisplayName,
		Victim = victim.DisplayName,
		Weapon = weapon and Items.WeaponName(weapon, class.WeaponStyle) or "",
		Streak = streak,
	})
	if streak == 3 or streak == 5 or streak % 10 == 0 then
		Remotes.Notify:FireAllClients("Toast", {
			Text = string.format("%s is on a %d knockout streak!", killer.DisplayName, streak),
			Color = Color3.fromRGB(255, 120, 60),
		})
	end
end

function CombatService.Init()
	Remotes.Attack.OnServerEvent:Connect(onAttack)

	local function setup(player)
		setStreak(player, 0)
		local function onCharacter(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Once(function()
					onPlayerDied(player, humanoid)
				end)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		streaks[player] = nil
	end)
end

return CombatService
