-- Casts class abilities. The client only says "slot N, aiming here"; the
-- server checks the slot is unlocked, the cooldown is ready and the caster
-- can act, then runs the ability by Kind using the numbers in Abilities.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Abilities)
local Stats = require(Shared.Stats)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)
local StatusService = require(script.Parent.StatusService)
local CombatService = require(script.Parent.CombatService)

local AbilityService = {}

local COOLDOWN_TOLERANCE = 0.3 -- seconds of slack for network jitter
local cooldowns = {} -- [player] = { [abilityId] = readyAt }

local function flat(vector)
	local v = Vector3.new(vector.X, 0, vector.Z)
	return v.Magnitude > 0.01 and v.Unit or Vector3.new(0, 0, -1)
end

local function enemiesFilter(ctx)
	return function(humanoid)
		return humanoid.Parent ~= ctx.Character and CombatService.IsEnemy(ctx.Player, humanoid)
	end
end

local function alliesNear(ctx, radius)
	local allies = { ctx.Humanoid }
	if radius and radius > 0 then
		for _, humanoid in CombatService.InRadius(ctx.Root.Position, radius, function(h)
			return h ~= ctx.Humanoid and CombatService.IsAlly(ctx.Player, h)
		end) do
			table.insert(allies, humanoid)
		end
	end
	return allies
end

local function power(ctx, field)
	return Stats.AbilityPower(ctx.Stats, ctx.Profile, ctx.Ability, field or "Power")
end

local function hitEnemy(ctx, target, fieldOverride)
	local ability = ctx.Ability
	local isCrit, mult = CombatService.RollCrit(ctx.Stats, ability.AlwaysCrit)
	local dealt = CombatService.Damage(ctx.Player, target, power(ctx, fieldOverride) * mult, { Crit = isCrit })
	if dealt > 0 then
		if ability.Stun then
			StatusService.Stun(target, ability.Stun)
		end
		if ability.Slow and ability.Kind ~= "Zone" then
			StatusService.Slow(target, ability.Slow, ability.SlowDuration or 2)
		end
	end
	return dealt
end

local function groundBelow(position, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return result and result.Position or position
end

local Kinds = {}

function Kinds.Strike(ctx)
	local ability = ctx.Ability
	local box = ctx.Root.CFrame * CFrame.new(0, 0, -ability.Range / 2)
	Remotes.Effect:FireAllClients("Slash", { CFrame = box, Range = ability.Range, Color = ability.Color, Big = true })
	for _, target in CombatService.InBox(box, Vector3.new(ability.Range, 7, ability.Range), enemiesFilter(ctx)) do
		if hitEnemy(ctx, target) > 0 and ability.Knockback and not Players:GetPlayerFromCharacter(target.Parent) then
			local root = target.Parent:FindFirstChild("HumanoidRootPart")
			if root and not root.Anchored then
				root:ApplyImpulse(flat(ctx.Aim) * ability.Knockback * root.AssemblyMass)
			end
		end
	end
end

function Kinds.Nova(ctx)
	local ability = ctx.Ability
	Remotes.Effect:FireAllClients("Ring", { Position = ctx.Root.Position, Radius = ability.Radius, Color = ability.Color })
	if ability.Power then
		for _, target in CombatService.InRadius(ctx.Root.Position, ability.Radius, enemiesFilter(ctx)) do
			hitEnemy(ctx, target)
		end
	end
	if ability.Heal then
		for _, ally in alliesNear(ctx, ability.Radius) do
			CombatService.Heal(ctx.Player, ally, power(ctx, "Heal"))
		end
	end
end

function Kinds.Projectile(ctx)
	local ability = ctx.Ability
	CombatService.FireProjectile({
		Owner = ctx.Player,
		Exclude = { ctx.Character },
		Origin = ctx.Root.Position + Vector3.new(0, 1, 0) + ctx.Aim * 2,
		Direction = ctx.Aim,
		Speed = ability.Speed,
		Range = ability.Range,
		Size = ability.Size or 1.2,
		Pierce = ability.Pierce,
		Color = ability.Color,
		OnHit = function(target)
			if not ability.Explode then
				hitEnemy(ctx, target)
			end
		end,
		OnImpact = ability.Explode and function(position)
			Remotes.Effect:FireAllClients("Ring", { Position = position, Radius = ability.Explode, Color = ability.Color })
			for _, target in CombatService.InRadius(position, ability.Explode, enemiesFilter(ctx)) do
				hitEnemy(ctx, target)
			end
		end or nil,
	})
end

function Kinds.Dash(ctx)
	local ability = ctx.Ability
	local root = ctx.Root
	local direction = flat(ctx.Aim)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.Character }
	local blocked = workspace:Raycast(root.Position, direction * ability.Distance, params)
	local distance = blocked and math.max(0, (blocked.Position - root.Position).Magnitude - 2) or ability.Distance
	local from = root.Position
	local to = from + direction * distance

	if ability.Power then
		local mid = CFrame.lookAt((from + to) / 2, to)
		for _, target in CombatService.InBox(mid, Vector3.new(6, 7, distance + 4), enemiesFilter(ctx)) do
			hitEnemy(ctx, target)
		end
	end
	root.CFrame = CFrame.lookAt(to, to + direction)
	Remotes.Effect:FireAllClients("Dash", { From = from, To = to, Color = ability.Color, Teleport = ability.Teleport })
	if ability.Buff then
		StatusService.Buff(ctx.Humanoid, ability.Buff, ability.Duration or 2)
	end
end

function Kinds.Buff(ctx)
	local ability = ctx.Ability
	for _, ally in alliesNear(ctx, ability.Radius) do
		StatusService.Buff(ally, ability.Buff, ability.Duration)
		if ability.Heal then
			CombatService.Heal(ctx.Player, ally, power(ctx, "Heal"))
		end
		local root = ally.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			Remotes.Effect:FireAllClients("Aura", { Part = root, Color = ability.Color, Duration = ability.Duration })
		end
	end
end

function Kinds.Heal(ctx)
	local ability = ctx.Ability
	Remotes.Effect:FireAllClients("Ring", { Position = ctx.Root.Position, Radius = ability.Radius, Color = ability.Color, Soft = true })
	for _, ally in alliesNear(ctx, ability.Radius) do
		CombatService.Heal(ctx.Player, ally, power(ctx, "Heal"))
		if ability.Buff then
			StatusService.Buff(ally, ability.Buff, ability.Duration or 5)
		end
		local root = ally.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			Remotes.Effect:FireAllClients("Aura", { Part = root, Color = ability.Color, Duration = 1.2 })
		end
	end
end

function Kinds.Zone(ctx)
	local ability = ctx.Ability
	local offset = ctx.AimPoint - ctx.Root.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude > ability.Range then
		flatOffset = flatOffset.Unit * ability.Range
	end
	local center = groundBelow(ctx.Root.Position + flatOffset, { ctx.Character })
	local delay = ability.Delay or 0
	Remotes.Effect:FireAllClients("Zone", {
		Position = center,
		Radius = ability.Radius,
		Duration = ability.Duration,
		Delay = delay,
		Color = ability.Color,
	})

	task.spawn(function()
		if delay > 0 then
			task.wait(delay)
		end
		local ticks = ability.Ticks or 1
		local interval = ticks > 1 and ability.Duration / ticks or 0
		for tick = 1, ticks do
			if ability.Power then
				for _, target in CombatService.InRadius(center, ability.Radius, enemiesFilter(ctx)) do
					local isCrit, mult = CombatService.RollCrit(ctx.Stats, ability.AlwaysCrit)
					local dealt = CombatService.Damage(ctx.Player, target, power(ctx) * mult, { Crit = isCrit })
					if dealt > 0 then
						if ability.Slow then
							StatusService.Slow(target, ability.Slow, interval + 0.4)
						end
						if ability.Stun and tick == 1 then
							StatusService.Stun(target, ability.Stun)
						end
					end
				end
			end
			if ability.HealPower then
				for _, ally in CombatService.InRadius(center, ability.Radius, function(h)
					return CombatService.IsAlly(ctx.Player, h)
				end) do
					CombatService.Heal(ctx.Player, ally, power(ctx, "HealPower"))
				end
			end
			if interval > 0 then
				task.wait(interval)
			end
		end
	end)
end

local function onCast(player, slot, aimPoint)
	if type(slot) ~= "number" or slot % 1 ~= 0 then
		return
	end
	local profile = DataService.Get(player)
	local stats = LoadoutService.GetStats(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (profile and stats and humanoid and root) or humanoid.Health <= 0 or StatusService.IsStunned(humanoid) then
		return
	end
	if profile.Class == "" then
		return
	end
	local slotInfo = Stats.AbilitySlots(profile)[slot]
	local ability = slotInfo and slotInfo.Unlocked and Abilities.Get(slotInfo.Id)
	if not ability then
		return
	end

	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if (playerCooldowns[ability.Id] or 0) - COOLDOWN_TOLERANCE > now then
		return
	end
	local cooldown = Stats.AbilityCooldown(stats, profile, ability)
	playerCooldowns[ability.Id] = now + cooldown

	local aim = CombatService.AimDirection(root, aimPoint)
	local ctx = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Stats = stats,
		Profile = profile,
		Ability = ability,
		Aim = aim,
		AimPoint = (typeof(aimPoint) == "Vector3" and aimPoint == aimPoint) and aimPoint or root.Position + aim * 20,
	}
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		CombatService.PlaySlash(tool)
	end
	Kinds[ability.Kind](ctx)
	Remotes.Notify:FireClient(player, "Cast", { Slot = slot, Id = ability.Id, Cooldown = cooldown })
end

function AbilityService.Init()
	Remotes.CastAbility.OnServerEvent:Connect(onCast)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return AbilityService
