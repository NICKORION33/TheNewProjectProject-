-- Builds the 3D look of every item out of plain parts, so the game needs no
-- uploaded meshes. The server uses these for real gear; the client uses them
-- for spinning previews in the shop.

local Visuals = {}

local GRIP_LENGTH = 1.1
local GUARD_THICKNESS = 0.25

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

-- Rigidly attaches every BasePart in `model` to `base` at their current offsets.
local function weldAll(model, base)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= base then
			local weld = Instance.new("Weld")
			weld.Part0 = base
			weld.Part1 = p
			weld.C0 = base.CFrame:Inverse() * p.CFrame
			weld.Parent = p
		end
	end
end

local function sparkles(color, rate, size)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.2, 1)
	return emitter
end

---------------------------------------------------------------------------
-- Weapons
---------------------------------------------------------------------------

local function newHandle(model, length)
	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.3, 0.3, length),
		Transparency = 1,
		CFrame = CFrame.identity,
	})
	handle.Parent = model
	model.PrimaryPart = handle
	return handle
end

local function addGlow(host, color, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 8
	light.Brightness = 1.5
	light.Parent = host
end

local function buildBlade(def, model)
	local bladeLength = def.BladeLength
	local total = GRIP_LENGTH + GUARD_THICKNESS + bladeLength
	local bottom = -total / 2
	local handle = newHandle(model, total)

	part({
		Name = "Grip",
		Size = Vector3.new(0.28, 0.28, GRIP_LENGTH),
		Color = def.HiltColor,
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(0, 0, bottom + GRIP_LENGTH / 2),
		Parent = model,
	})
	part({
		Name = "Pommel",
		Size = Vector3.new(0.42, 0.42, 0.22),
		Color = def.HiltColor,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, 0, bottom + 0.11),
		Parent = model,
	})
	part({
		Name = "Guard",
		Size = Vector3.new(0.34, def.BladeWidth * 2.4, GUARD_THICKNESS),
		Color = def.HiltColor,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, 0, bottom + GRIP_LENGTH + GUARD_THICKNESS / 2),
		Parent = model,
	})

	local bladeCenter = bottom + GRIP_LENGTH + GUARD_THICKNESS + bladeLength / 2
	local blade = part({
		Name = "Blade",
		Size = Vector3.new(0.12, def.BladeWidth, bladeLength),
		Color = def.BladeColor,
		Material = def.BladeMaterial or Enum.Material.Metal,
		Reflectance = def.BladeMaterial == Enum.Material.Metal and 0.15 or 0,
		CFrame = CFrame.new(0, 0, bladeCenter),
		Parent = model,
	})
	-- A wedge makes the point.
	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Anchored, tip.CanCollide, tip.CanQuery, tip.CanTouch, tip.Massless = false, false, false, false, true
	tip.CastShadow = false
	tip.Size = Vector3.new(0.12, def.BladeWidth, def.BladeWidth * 1.2)
	tip.Color = def.BladeColor
	tip.Material = blade.Material
	tip.CFrame = CFrame.new(0, 0, bottom + total + def.BladeWidth * 0.6) * CFrame.Angles(0, math.pi, 0)
	tip.Parent = model

	if def.Glow then
		part({
			Name = "Edge",
			Size = Vector3.new(0.16, def.BladeWidth * 0.22, bladeLength * 0.92),
			Color = def.Glow,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, 0, bladeCenter),
			Parent = model,
		})
		addGlow(blade, def.Glow)

		local a0 = Instance.new("Attachment")
		a0.Name = "TrailBase"
		a0.Position = Vector3.new(0, 0, -bladeLength / 2)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailTip"
		a1.Position = Vector3.new(0, 0, bladeLength / 2)
		a1.Parent = blade
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(def.Glow)
		trail.LightEmission = 1
		trail.Lifetime = 0.18
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Parent = blade
	end
	if def.Particles then
		sparkles(def.Glow or def.BladeColor, 14, 0.25).Parent = blade
	end
	return handle, bottom + GRIP_LENGTH / 2
end

local function buildStaff(def, model)
	local length = 3.4 + def.BladeLength * 0.4
	local bottom = -length / 2
	local handle = newHandle(model, length + 1)
	part({
		Name = "Shaft",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, 0.26, 0.26),
		Color = def.HiltColor,
		Material = Enum.Material.Wood,
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		Parent = model,
	})
	part({
		Name = "Cap",
		Size = Vector3.new(0.5, 0.5, 0.3),
		Color = def.BladeColor,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, 0, -bottom),
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Prong",
			Size = Vector3.new(0.14, 0.14, 0.8),
			Color = def.BladeColor,
			Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, side * 0.32, -bottom + 0.45) * CFrame.Angles(side * math.rad(20), 0, 0),
			Parent = model,
		})
	end
	local orbColor = def.Glow or def.BladeColor
	local orb = part({
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (0.55 + def.BladeWidth * 0.5),
		Color = orbColor,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(0, 0, -bottom + 0.6),
		Parent = model,
	})
	addGlow(orb, orbColor, def.Glow and 10 or 5)
	if def.Particles then
		sparkles(orbColor, 16, 0.3).Parent = orb
	end
	return handle, bottom + length * 0.38
end

local function buildBow(def, model)
	local limb = 1.6 + def.BladeLength * 0.18
	local angle = math.rad(22)
	local handle = newHandle(model, limb * 2 + 0.8)
	part({
		Name = "Grip",
		Size = Vector3.new(0.32, 0.32, 0.9),
		Color = def.HiltColor,
		Material = Enum.Material.Fabric,
		CFrame = CFrame.identity,
		Parent = model,
	})
	local tipX = 0.1 + math.sin(angle) * limb
	local tipZ = 0.4 + math.cos(angle) * limb
	for _, side in { -1, 1 } do
		part({
			Name = "Limb",
			Size = Vector3.new(0.18, def.BladeWidth * 0.55, limb),
			Color = def.BladeColor,
			Material = def.BladeMaterial or Enum.Material.Wood,
			CFrame = CFrame.new(0.1 + math.sin(angle) * limb / 2, 0, side * (0.4 + math.cos(angle) * limb / 2))
				* CFrame.Angles(0, side * angle, 0),
			Parent = model,
		})
	end
	local stringColor = def.Glow or Color3.fromRGB(235, 230, 215)
	local bowstring = part({
		Name = "String",
		Size = Vector3.new(0.05, 0.05, tipZ * 2),
		Color = stringColor,
		Material = def.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(tipX, 0, 0),
		Parent = model,
	})
	if def.Glow then
		addGlow(bowstring, def.Glow)
	end
	if def.Particles then
		sparkles(def.Glow or def.BladeColor, 12, 0.25).Parent = bowstring
	end
	return handle, 0
end

local BUILDERS = { Blade = buildBlade, Staff = buildStaff, Bow = buildBow }

-- Returns (model, gripZ). `style` is "Blade", "Staff" or "Bow" (the class's weapon style).
-- The PrimaryPart is an invisible "Handle" running along Z; the business end points to +Z.
function Visuals.BuildWeapon(def, style)
	local model = Instance.new("Model")
	model.Name = def.Name
	local handle, gripZ = (BUILDERS[style] or buildBlade)(def, model)
	weldAll(model, handle)
	return model, gripZ
end

---------------------------------------------------------------------------
-- Armor (built around a torso sitting at the origin)
---------------------------------------------------------------------------

function Visuals.BuildArmor(def, torsoSize)
	torsoSize = torsoSize or Vector3.new(2, 2, 1)
	local model = Instance.new("Model")
	model.Name = "Armor"
	if not def.Plates then
		return model
	end

	local tx, ty, tz = torsoSize.X, torsoSize.Y, torsoSize.Z
	part({
		Name = "Chest",
		Size = Vector3.new(tx + 0.12, ty * 0.72, tz + 0.16),
		Color = def.Color,
		Material = def.Material,
		CFrame = CFrame.new(0, ty * 0.12, 0),
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = side < 0 and "LeftPad" or "RightPad",
			Size = Vector3.new(0.95, 0.45, tz + 0.35),
			Color = def.Color,
			Material = def.Material,
			CFrame = CFrame.new(side * (tx / 2 + 0.32), ty / 2 - 0.05, 0) * CFrame.Angles(0, 0, side * -0.25),
			Parent = model,
		})
		if def.Trim then
			part({
				Name = "PadTrim",
				Size = Vector3.new(0.97, 0.12, tz + 0.37),
				Color = def.Trim,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(side * (tx / 2 + 0.32), ty / 2 - 0.25, 0) * CFrame.Angles(0, 0, side * -0.25),
				Parent = model,
			})
		end
	end
	if def.Trim then
		part({
			Name = "Belt",
			Size = Vector3.new(tx + 0.16, 0.14, tz + 0.2),
			Color = def.Trim,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, ty * 0.12 - ty * 0.36, 0),
			Parent = model,
		})
	end
	return model
end

---------------------------------------------------------------------------
-- Outfit extras
---------------------------------------------------------------------------

-- Returns { Torso = Model?, Head = Model? } positioned relative to each part.
-- Hoods and crowns both live in Head (a crown sits on top of a hood).
function Visuals.BuildOutfitExtras(def, torsoSize, headSize)
	torsoSize = torsoSize or Vector3.new(2, 2, 1)
	headSize = headSize or Vector3.new(1.2, 1.2, 1.2)
	local result = {}

	if def.Cape then
		local torso = Instance.new("Model")
		torso.Name = "Cape"
		part({
			Name = "Cape",
			Size = Vector3.new(torsoSize.X * 0.95, torsoSize.Y * 1.55, 0.08),
			Color = def.Cape,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(0, torsoSize.Y * 0.5, torsoSize.Z / 2 + 0.06)
				* CFrame.Angles(-math.rad(10), 0, 0)
				* CFrame.new(0, -torsoSize.Y * 0.775, 0),
			Parent = torso,
		})
		result.Torso = torso
	end

	if def.Hood then
		local hood = Instance.new("Model")
		hood.Name = "Hood"
		local hx, hy, hz = headSize.X, headSize.Y, headSize.Z
		part({
			Name = "HoodBack",
			Size = Vector3.new(hx * 1.2, hy * 1.2, hz * 0.7),
			Color = def.Hood,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(0, hy * 0.06, hz * 0.3),
			Parent = hood,
		})
		part({
			Name = "HoodTop",
			Size = Vector3.new(hx * 1.2, hy * 0.2, hz * 1.15),
			Color = def.Hood,
			Material = Enum.Material.Fabric,
			CFrame = CFrame.new(0, hy * 0.58, 0),
			Parent = hood,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "HoodSide",
				Size = Vector3.new(hx * 0.12, hy * 1.1, hz * 1.1),
				Color = def.Hood,
				Material = Enum.Material.Fabric,
				CFrame = CFrame.new(side * hx * 0.56, hy * 0.05, 0),
				Parent = hood,
			})
		end
		result.Head = hood
	end

	if def.Crown then
		local crown = Instance.new("Model")
		crown.Name = "Crown"
		local topY = headSize.Y / 2 + 0.12
		local diameter = math.max(headSize.X, headSize.Z) * 0.95
		part({
			Name = "Band",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.32, diameter, diameter),
			Color = def.Crown,
			Material = Enum.Material.Metal,
			Reflectance = 0.2,
			CFrame = CFrame.new(0, topY, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = crown,
		})
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			part({
				Name = "Spike",
				Size = Vector3.new(0.18, 0.38, 0.18),
				Color = def.Crown,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(math.cos(angle) * diameter * 0.42, topY + 0.3, math.sin(angle) * diameter * 0.42)
					* CFrame.Angles(0, -angle, 0),
				Parent = crown,
			})
		end
		if result.Head then
			crown.Parent = result.Head
		else
			result.Head = crown
		end
	end

	return result
end

-- Particles, fire and trails that live on the HumanoidRootPart.
-- Every instance created is named `tag` so it can be cleared later.
function Visuals.AddRootEffects(root, def, tag)
	if def.Aura then
		local emitter = sparkles(def.Aura, 18, 0.5)
		emitter.Name = tag
		emitter.Parent = root
	end
	if def.Fire then
		local fire = Instance.new("Fire")
		fire.Name = tag
		fire.Color = def.Aura or Color3.fromRGB(255, 120, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
		fire.Heat = 4
		fire.Size = 4
		fire.Parent = root
	end
	if def.Trail then
		local a0 = Instance.new("Attachment")
		a0.Name = tag
		a0.Position = Vector3.new(0, 0.9, 0.3)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = tag
		a1.Position = Vector3.new(0, -0.9, 0.3)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = tag
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(def.Trail)
		trail.LightEmission = 0.8
		trail.Lifetime = 0.45
		trail.Transparency = NumberSequence.new(0.25, 1)
		trail.Parent = root
	end
end

-- Moves every part of `model` (built around the origin) onto `anchor` and welds it there.
function Visuals.AttachTo(model, anchor, parent)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = anchor.CFrame * p.CFrame
		end
	end
	weldAll(model, anchor)
	model.Parent = parent
end

---------------------------------------------------------------------------
-- Shop previews
---------------------------------------------------------------------------

-- A blocky stand-in character wearing an outfit, optional armor, and an optional weapon.
function Visuals.BuildMannequin(outfitDef, armorDef, weaponDef, weaponStyle)
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local skin = Color3.fromRGB(234, 196, 160)
	local function limb(name, size, cf, color)
		local p = part({ Name = name, Size = size, CFrame = cf, Color = color, Anchored = true })
		p.Parent = model
		return p
	end
	local torso = limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), outfitDef.Primary)
	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), skin)
	limb("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), outfitDef.Primary)
	limb("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), outfitDef.Primary)
	limb("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), outfitDef.Secondary)
	limb("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), outfitDef.Secondary)
	model.PrimaryPart = torso

	local function place(sub, anchor)
		for _, p in sub:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = anchor.CFrame * p.CFrame
				p.Anchored = true
			end
		end
		sub.Parent = model
	end
	if armorDef then
		place(Visuals.BuildArmor(armorDef, torso.Size), torso)
	end
	local extras = Visuals.BuildOutfitExtras(outfitDef, torso.Size, head.Size)
	if extras.Torso then
		place(extras.Torso, torso)
	end
	if extras.Head then
		place(extras.Head, head)
	end
	if weaponDef then
		local weapon, gripZ = Visuals.BuildWeapon(weaponDef, weaponStyle)
		-- Held upright in the right hand, business end up.
		weapon:PivotTo(CFrame.new(1.5, 2.1, -0.6) * CFrame.Angles(-math.rad(80), 0, 0) * CFrame.new(0, 0, -gripZ))
		for _, p in weapon:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		weapon.Parent = model
	end
	return model
end

return Visuals
