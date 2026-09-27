-- Stuns, slows and timed buffs on any Humanoid (players, mobs, dummies).
-- Movement speed is derived from the humanoid's "BaseSpeed" attribute.

local RunService = game:GetService("RunService")

local StatusService = {}

-- [humanoid] = { StunUntil = number, Slows = { {Amount, Until} }, Buffs = { {Stats, Until} } }
local states = {}

local function stateFor(humanoid)
	local state = states[humanoid]
	if not state then
		state = { StunUntil = 0, Slows = {}, Buffs = {} }
		states[humanoid] = state
		humanoid.AncestryChanged:Connect(function(_, parent)
			if not parent then
				states[humanoid] = nil
			end
		end)
	end
	return state
end

local function prune(list, now)
	for i = #list, 1, -1 do
		if list[i].Until <= now then
			table.remove(list, i)
		end
	end
end

function StatusService.IsStunned(humanoid)
	local state = states[humanoid]
	return state ~= nil and state.StunUntil > os.clock()
end

-- Sum of an active buff stat (Damage, Defense, Speed, AttackSpeed, Lifesteal).
function StatusService.GetBuff(humanoid, key)
	local state = states[humanoid]
	if not state then
		return 0
	end
	local now, total = os.clock(), 0
	for _, buff in state.Buffs do
		if buff.Until > now then
			total += buff.Stats[key] or 0
		end
	end
	return total
end

local function setJump(humanoid, enabled)
	if humanoid.UseJumpPower then
		humanoid.JumpPower = enabled and 50 or 0
	else
		humanoid.JumpHeight = enabled and 7.2 or 0
	end
end

local function applyMovement(humanoid)
	local state = states[humanoid]
	local base = humanoid:GetAttribute("BaseSpeed") or 16
	if not state then
		humanoid.WalkSpeed = base
		return
	end
	local now = os.clock()
	prune(state.Slows, now)
	prune(state.Buffs, now)
	if state.StunUntil > now then
		humanoid.WalkSpeed = 0
		setJump(humanoid, false)
		humanoid:SetAttribute("Stunned", true)
		return
	end
	if humanoid:GetAttribute("Stunned") then
		humanoid:SetAttribute("Stunned", nil)
		setJump(humanoid, true)
	end
	local slow = 0
	for _, entry in state.Slows do
		slow = math.max(slow, entry.Amount)
	end
	humanoid.WalkSpeed = base * (1 + StatusService.GetBuff(humanoid, "Speed")) * (1 - slow)
end

function StatusService.Stun(humanoid, duration)
	local state = stateFor(humanoid)
	state.StunUntil = math.max(state.StunUntil, os.clock() + duration)
	applyMovement(humanoid)
end

function StatusService.Slow(humanoid, amount, duration)
	table.insert(stateFor(humanoid).Slows, { Amount = amount, Until = os.clock() + duration })
	applyMovement(humanoid)
end

function StatusService.Buff(humanoid, stats, duration)
	table.insert(stateFor(humanoid).Buffs, { Stats = stats, Until = os.clock() + duration })
	applyMovement(humanoid)
end

-- Call after changing BaseSpeed.
function StatusService.Refresh(humanoid)
	applyMovement(humanoid)
end

function StatusService.Clear(humanoid)
	states[humanoid] = nil
	humanoid:SetAttribute("Stunned", nil)
end

function StatusService.Init()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		for humanoid in states do
			if humanoid.Parent then
				applyMovement(humanoid)
			end
		end
	end)
end

return StatusService
