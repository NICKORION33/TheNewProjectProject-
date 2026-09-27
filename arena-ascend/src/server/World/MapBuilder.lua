-- Builds the whole map from parts at server start so the place file can be
-- an empty baseplate. Layout:
--   Plaza (safe zone, spawns, Armory kiosk)  at (0, 0, 0)
--   The Pit (PvP arena)                       at (0, 0, -170)
--   Training Grounds (dummies, crystals)      at (170, 0, 0)

local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local COLORS = {
	Stone = Color3.fromRGB(70, 74, 86),
	StoneDark = Color3.fromRGB(44, 46, 56),
	Sand = Color3.fromRGB(176, 146, 106),
	Grass = Color3.fromRGB(78, 112, 64),
	Dirt = Color3.fromRGB(118, 96, 70),
	Wood = Color3.fromRGB(120, 84, 52),
	Gold = Color3.fromRGB(255, 190, 70),
	Ember = Color3.fromRGB(255, 96, 60),
	Frost = Color3.fromRGB(90, 200, 255),
}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function marker(parent, name, cframe, size)
	return part(parent, {
		Name = name,
		CFrame = cframe,
		Size = size or Vector3.new(2, 1, 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function sign(parent, text, position, color)
	local anchor = marker(parent, "Sign", CFrame.new(position), Vector3.new(1, 1, 1))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(18, 4)
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 16)
	label.Parent = gui
	return anchor
end

local function lamp(parent, position, color)
	part(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.8, 12, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Metal,
	})
	local bulb = part(parent, {
		Name = "LampBulb",
		Size = Vector3.new(1.6, 1.6, 1.6),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(position + Vector3.new(0, 12.6, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26
	light.Brightness = 1.6
	light.Parent = bulb
end

local function buildGround(map)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = COLORS.Grass
		baseplate.Material = Enum.Material.Grass
		baseplate.Size = Vector3.new(1024, baseplate.Size.Y, 1024)
		local texture = baseplate:FindFirstChildOfClass("Texture")
		if texture then
			texture:Destroy()
		end
	else
		part(map, {
			Name = "Ground",
			Size = Vector3.new(1024, 2, 1024),
			CFrame = CFrame.new(0, -1, 0),
			Color = COLORS.Grass,
			Material = Enum.Material.Grass,
		})
	end
end

local function buildPlaza(map)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map

	part(plaza, {
		Name = "Floor",
		Size = Vector3.new(90, 1, 90),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = COLORS.Stone,
		Material = Enum.Material.Slate,
	})
	for _, edge in {
		{ Vector3.new(90, 0.2, 1), Vector3.new(0, 1.05, 45) },
		{ Vector3.new(90, 0.2, 1), Vector3.new(0, 1.05, -45) },
		{ Vector3.new(1, 0.2, 90), Vector3.new(45, 1.05, 0) },
		{ Vector3.new(1, 0.2, 90), Vector3.new(-45, 1.05, 0) },
	} do
		part(plaza, {
			Name = "Trim",
			Size = edge[1],
			CFrame = CFrame.new(edge[2]),
			Color = COLORS.Gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end

	for _, offset in { Vector3.new(-12, 0, -8), Vector3.new(12, 0, -8), Vector3.new(-12, 0, 8), Vector3.new(12, 0, 8) } do
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 3
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(offset + Vector3.new(0, 1.5, 0))
		spawn.Color = COLORS.StoneDark
		spawn.Material = Enum.Material.Marble
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = plaza
	end

	-- Armory kiosk
	local kiosk = Instance.new("Model")
	kiosk.Name = "ShopKiosk"
	kiosk.Parent = plaza
	part(kiosk, {
		Name = "Base",
		Size = Vector3.new(16, 1, 8),
		CFrame = CFrame.new(0, 1.5, 30),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Marble,
	})
	local counter = part(kiosk, {
		Name = "Counter",
		Size = Vector3.new(12, 3.5, 2.5),
		CFrame = CFrame.new(0, 3.75, 28),
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -7, 7 } do
		part(kiosk, {
			Name = "Pillar",
			Size = Vector3.new(1, 10, 1),
			CFrame = CFrame.new(x, 7, 32),
			Color = COLORS.Wood,
			Material = Enum.Material.Wood,
		})
	end
	part(kiosk, {
		Name = "Roof",
		Size = Vector3.new(17, 1, 9),
		CFrame = CFrame.new(0, 12.5, 30),
		Color = Color3.fromRGB(150, 36, 44),
		Material = Enum.Material.Fabric,
	})
	part(kiosk, {
		Name = "RoofTrim",
		Size = Vector3.new(17.2, 0.3, 9.2),
		CFrame = CFrame.new(0, 11.9, 30),
		Color = COLORS.Gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Open Armory"
	prompt.ObjectText = "Gear & Outfits"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E is an ability key
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	sign(kiosk, "ARMORY", Vector3.new(0, 15.5, 30), COLORS.Gold)

	for _, corner in { Vector3.new(-40, 1, -40), Vector3.new(40, 1, -40), Vector3.new(-40, 1, 40), Vector3.new(40, 1, 40) } do
		lamp(plaza, corner, COLORS.Gold)
	end

	sign(plaza, "TO THE PIT", Vector3.new(0, 9, -42), COLORS.Ember)
	sign(plaza, "TO TRAINING", Vector3.new(42, 9, 0), COLORS.Frost)
	sign(plaza, "TO THE WILDS", Vector3.new(-42, 9, 0), Color3.fromRGB(140, 220, 120))
end

local function buildArena(map)
	local arena = Instance.new("Folder")
	arena.Name = "ThePit"
	arena.Parent = map
	local center = Vector3.new(0, 0, -170)
	local half = 80

	part(arena, {
		Name = "Walkway",
		Size = Vector3.new(18, 1, 46),
		CFrame = CFrame.new(0, 0.5, -67.5),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Cobblestone,
	})
	part(arena, {
		Name = "Floor",
		Size = Vector3.new(half * 2, 1, half * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = COLORS.Sand,
		Material = Enum.Material.Sand,
	})

	-- Walls, leaving a 20-stud gate on the side facing the plaza.
	local wallHeight, thickness, gate = 12, 3, 20
	local function wall(size, offset)
		part(arena, {
			Name = "Wall",
			Size = size,
			CFrame = CFrame.new(center + offset),
			Color = COLORS.StoneDark,
			Material = Enum.Material.Brick,
		})
	end
	wall(Vector3.new(half * 2, wallHeight, thickness), Vector3.new(0, wallHeight / 2 + 1, -half))
	wall(Vector3.new(thickness, wallHeight, half * 2), Vector3.new(-half, wallHeight / 2 + 1, 0))
	wall(Vector3.new(thickness, wallHeight, half * 2), Vector3.new(half, wallHeight / 2 + 1, 0))
	local sideLength = half - gate / 2
	wall(Vector3.new(sideLength, wallHeight, thickness), Vector3.new(-(gate / 2 + sideLength / 2), wallHeight / 2 + 1, half))
	wall(Vector3.new(sideLength, wallHeight, thickness), Vector3.new(gate / 2 + sideLength / 2, wallHeight / 2 + 1, half))
	part(arena, {
		Name = "GateArch",
		Size = Vector3.new(gate + 4, 3, thickness + 1),
		CFrame = CFrame.new(center + Vector3.new(0, wallHeight + 2.5, half)),
		Color = COLORS.Ember,
		Material = Enum.Material.Neon,
	})
	sign(arena, "THE PIT", center + Vector3.new(0, wallHeight + 7, half), COLORS.Ember)

	-- Cover pillars in a ring.
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		local position = center + Vector3.new(math.cos(angle) * 48, 0, math.sin(angle) * 48)
		part(arena, {
			Name = "Pillar",
			Size = Vector3.new(5, 14, 5),
			CFrame = CFrame.new(position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, angle, 0),
			Color = COLORS.Stone,
			Material = Enum.Material.Rock,
		})
	end

	-- King's Hill: raised centre platform with four ramps.
	part(arena, {
		Name = "KingsHill",
		Size = Vector3.new(30, 4, 30),
		CFrame = CFrame.new(center + Vector3.new(0, 3, 0)),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Slate,
	})
	part(arena, {
		Name = "HillRing",
		Size = Vector3.new(0.4, 14, 14),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(center + Vector3.new(0, 5.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.Ember,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local position = center + direction * 21 + Vector3.new(0, 3, 0)
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Anchored = true
		ramp.Size = Vector3.new(10, 4, 12)
		-- A wedge's high end is its +Z face, so face -Z away from the hill.
		ramp.CFrame = CFrame.lookAt(position, position + direction)
		ramp.Color = COLORS.StoneDark
		ramp.Material = Enum.Material.Slate
		ramp.Parent = arena
	end

	for _, corner in { Vector3.new(-70, 1, -70), Vector3.new(70, 1, -70), Vector3.new(-70, 1, 70), Vector3.new(70, 1, 70) } do
		lamp(arena, center + corner, COLORS.Ember)
	end
end

local function buildTrainingGrounds(map)
	local grounds = Instance.new("Folder")
	grounds.Name = "TrainingGrounds"
	grounds.Parent = map
	local center = Vector3.new(170, 0, 0)

	part(grounds, {
		Name = "Walkway",
		Size = Vector3.new(71, 1, 14),
		CFrame = CFrame.new(80, 0.5, 0),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Cobblestone,
	})
	part(grounds, {
		Name = "Floor",
		Size = Vector3.new(110, 1, 90),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = COLORS.Dirt,
		Material = Enum.Material.Ground,
	})
	for _, fence in {
		{ Vector3.new(110, 3, 1), Vector3.new(0, 2.5, -45) },
		{ Vector3.new(110, 3, 1), Vector3.new(0, 2.5, 45) },
		{ Vector3.new(1, 3, 90), Vector3.new(55, 2.5, 0) },
	} do
		part(grounds, {
			Name = "Fence",
			Size = fence[1],
			CFrame = CFrame.new(center + fence[2]),
			Color = COLORS.Wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	sign(grounds, "TRAINING GROUNDS", Vector3.new(115, 10, 0), COLORS.Frost)

	-- Dummy spawn points, easiest nearest the plaza.
	local spawns = Instance.new("Folder")
	spawns.Name = "DummySpawns"
	spawns.Parent = map
	local facing = Vector3.new(-1, 0, 0)
	local rows = {
		{ Tier = "Straw", X = 135, Z = { -30, -15, 0, 15, 30 } },
		{ Tier = "Iron", X = 165, Z = { -24, -8, 8, 24 } },
		{ Tier = "Golem", X = 200, Z = { -15, 15 } },
	}
	for _, row in rows do
		for _, z in row.Z do
			local position = Vector3.new(row.X, 1, z)
			local spawn = marker(spawns, "DummySpawn", CFrame.lookAt(position, position + facing))
			spawn:SetAttribute("Tier", row.Tier)
		end
		sign(grounds, row.Tier:upper(), Vector3.new(row.X, 12, -40), Color3.fromRGB(235, 235, 245))
	end

	for _, corner in { Vector3.new(-50, 1, -40), Vector3.new(50, 1, -40), Vector3.new(-50, 1, 40), Vector3.new(50, 1, 40) } do
		lamp(grounds, center + corner, COLORS.Frost)
	end
end

local function tree(parent, position, scale)
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8 * scale, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(86, 62, 44),
		Material = Enum.Material.Wood,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9 * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 9.5 * scale, 0)),
		Color = Color3.fromRGB(52, 96, 52),
		Material = Enum.Material.Grass,
	})
end

local function buildWilds(map)
	local wilds = Instance.new("Folder")
	wilds.Name = "TheWilds"
	wilds.Parent = map
	local center = Vector3.new(-190, 0, 0)

	part(wilds, {
		Name = "Walkway",
		Size = Vector3.new(76, 1, 14),
		CFrame = CFrame.new(-82.5, 0.5, 0),
		Color = COLORS.StoneDark,
		Material = Enum.Material.Cobblestone,
	})
	part(wilds, {
		Name = "Floor",
		Size = Vector3.new(140, 1, 130),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(62, 92, 54),
		Material = Enum.Material.Grass,
	})
	sign(wilds, "THE WILDS  -  PvE  Lv 5-30", Vector3.new(-118, 10, 0), COLORS.Ember)

	-- A ring of trees around the edge; a fixed seed keeps the layout identical every server.
	local random = Random.new(1337)
	for i = 1, 26 do
		local angle = i / 26 * math.pi * 2
		local radius = 58 + random:NextNumber(-4, 6)
		local position = center + Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius * 0.92)
		if position.X < -128 or math.abs(position.Z) > 12 then
			tree(wilds, position, random:NextNumber(0.8, 1.3))
		end
	end

	-- Goblin camp: tents around a campfire.
	local camp = Vector3.new(-152, 1, -18)
	local fire = part(wilds, {
		Name = "Campfire",
		Size = Vector3.new(3, 0.6, 3),
		CFrame = CFrame.new(camp + Vector3.new(0, 0.3, 0)),
		Color = Color3.fromRGB(70, 50, 40),
		Material = Enum.Material.Rock,
	})
	local flames = Instance.new("Fire")
	flames.Size = 6
	flames.Parent = fire
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.Ember
	glow.Range = 22
	glow.Parent = fire
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		local position = camp + Vector3.new(math.cos(angle) * 12, 3, math.sin(angle) * 12)
		for _, side in { -1, 1 } do
			local half = Instance.new("WedgePart")
			half.Anchored = true
			half.Size = Vector3.new(7, 6, 4)
			half.CFrame = CFrame.lookAt(position, camp) * CFrame.Angles(0, math.rad(90 * side), 0) * CFrame.new(0, 0, -2)
			half.Color = Color3.fromRGB(150, 110, 70)
			half.Material = Enum.Material.Fabric
			half.Parent = wilds
		end
	end

	-- Ruins where skeletons lurk.
	for i = 0, 5 do
		local position = Vector3.new(-200 + (i % 3) * 12, 1, 26 + math.floor(i / 3) * 16)
		local height = 6 + (i * 7) % 9
		part(wilds, {
			Name = "RuinPillar",
			Size = Vector3.new(3, height, 3),
			CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad((i % 2) * 6)),
			Color = Color3.fromRGB(150, 146, 136),
			Material = Enum.Material.Cobblestone,
		})
	end

	-- Boss altar.
	local altar = Vector3.new(-228, 0, -34)
	part(wilds, {
		Name = "Altar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 40, 40),
		CFrame = CFrame.new(altar + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(46, 40, 40),
		Material = Enum.Material.Basalt,
	})
	part(wilds, {
		Name = "AltarRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 36, 36),
		CFrame = CFrame.new(altar + Vector3.new(0, 2.55, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.Ember,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2 + math.pi / 4
		local position = altar + Vector3.new(math.cos(angle) * 21, 1, math.sin(angle) * 21)
		local brazier = part(wilds, {
			Name = "Brazier",
			Size = Vector3.new(2, 5, 2),
			CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)),
			Color = COLORS.StoneDark,
			Material = Enum.Material.Metal,
		})
		local brazierFire = Instance.new("Fire")
		brazierFire.Size = 4
		brazierFire.Parent = brazier
	end
	sign(wilds, "ASHEN ALTAR  -  BOSS", altar + Vector3.new(0, 16, 0), COLORS.Ember)

	-- Mob spawn points.
	local spawns = Instance.new("Folder")
	spawns.Name = "MobSpawns"
	spawns.Parent = map
	local function mobSpawn(mobType, position)
		local spawn = marker(spawns, "MobSpawn", CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
		spawn:SetAttribute("MobType", mobType)
	end
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		mobSpawn("Goblin", camp + Vector3.new(math.cos(angle) * 18, 0, math.sin(angle) * 18))
	end
	for i = 0, 3 do
		mobSpawn("Skeleton", Vector3.new(-206 + i * 10, 1, 40))
	end
	mobSpawn("Brute", Vector3.new(-172, 1, 30))
	mobSpawn("Brute", Vector3.new(-236, 1, 12))
	mobSpawn("Warlord", altar + Vector3.new(0, 2.5, 0))
end

local function buildZones(map)
	local safe = Instance.new("Folder")
	safe.Name = "SafeZones"
	safe.Parent = map
	local zone = marker(safe, "Plaza", CFrame.new(0, 20, 0), Vector3.new(92, 42, 92))
	zone.Color = Color3.fromRGB(80, 200, 120)

	local crystals = Instance.new("Folder")
	crystals.Name = "CrystalZones"
	crystals.Parent = map
	marker(crystals, "Training", CFrame.new(170, 2, 0), Vector3.new(96, 1, 76))
	marker(crystals, "Pit", CFrame.new(0, 2, -170), Vector3.new(140, 1, 140))
	marker(crystals, "Wilds", CFrame.new(-180, 2, 0), Vector3.new(100, 1, 100))
end

local function setLighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(60, 60, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 116, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Color = Color3.fromRGB(220, 190, 170)
		atmosphere.Decay = Color3.fromRGB(110, 90, 120)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1.4
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 28
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Saturation = 0.12
		grade.Contrast = 0.08
		grade.Parent = Lighting
	end
end

function MapBuilder.Build()
	local existing = workspace:FindFirstChild("ArenaMap")
	if existing then
		return existing
	end
	local map = Instance.new("Folder")
	map.Name = "ArenaMap"
	buildGround(map)
	buildPlaza(map)
	buildArena(map)
	buildTrainingGrounds(map)
	buildWilds(map)
	buildZones(map)
	setLighting()
	map.Parent = workspace
	return map
end

return MapBuilder
