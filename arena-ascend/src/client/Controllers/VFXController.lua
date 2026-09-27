-- Draws ability and attack visuals locally from server Effect events:
-- projectiles, impacts, slashes, rings, dashes, ground zones and auras.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local VFXController = {}

local folder

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		p[key] = value
	end
	p.Parent = folder
	return p
end

local function fade(part, time, goal)
	goal = goal or {}
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(time + 0.05, function()
		part:Destroy()
	end)
end

-- A flat disc lying on the ground at `position`.
local function disc(position, diameter, color, transparency)
	return fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency or 0.4,
	})
end

-- The ground under `position`, ignoring characters, mobs and effects.
local function ground(position)
	local exclude = { folder }
	for _, name in { "Mobs", "Dummies" } do
		local container = workspace:FindFirstChild(name)
		if container then
			table.insert(exclude, container)
		end
	end
	for _, other in game:GetService("Players"):GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
	return hit and hit.Position or position
end

local Effects = {}

function Effects.Projectile(p)
	local ball = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * p.Size,
		CFrame = CFrame.new(p.Origin),
		Color = p.Color,
	})
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 8
	light.Parent = ball
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local travelled, position = 0, p.Origin
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local step = math.min(p.Speed * dt, p.Range - travelled)
		local hit = workspace:Raycast(position, p.Direction * step, params)
		if hit and not hit.Instance:FindFirstAncestorOfClass("Model") then
			-- Stop at walls; characters are handled by the server's Impact event.
			step = (hit.Position - position).Magnitude
			travelled = p.Range
		end
		position += p.Direction * step
		travelled += step
		ball.CFrame = CFrame.new(position)
		if travelled >= p.Range then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
	task.delay(p.Range / p.Speed + 0.5, function()
		if connection.Connected then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
end

function Effects.Impact(p)
	local burst = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		CFrame = CFrame.new(p.Position),
		Color = p.Color,
		Transparency = 0.2,
	})
	fade(burst, 0.25, { Size = Vector3.one * 4 })
end

function Effects.Slash(p)
	local size = p.Range * (p.Big and 1.2 or 0.9)
	local arc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, size, size),
		CFrame = p.CFrame * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = p.Color,
		Transparency = 0.55,
	})
	fade(arc, 0.18, { Size = Vector3.new(0.15, size * 1.15, size * 1.15) })
end

function Effects.Ring(p)
	local ring = disc(ground(p.Position) + Vector3.new(0, 0.2, 0), 2, p.Color, p.Soft and 0.6 or 0.35)
	fade(ring, 0.45, { Size = Vector3.new(0.2, p.Radius * 2, p.Radius * 2) })
end

function Effects.Dash(p)
	local offset = p.To - p.From
	if offset.Magnitude < 0.5 then
		return
	end
	if p.Teleport then
		for _, position in { p.From, p.To } do
			local puff = fxPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 3,
				CFrame = CFrame.new(position),
				Color = p.Color,
				Transparency = 0.3,
			})
			fade(puff, 0.35, { Size = Vector3.one * 6 })
		end
		return
	end
	local streak = fxPart({
		Size = Vector3.new(1.4, 3, offset.Magnitude),
		CFrame = CFrame.lookAt((p.From + p.To) / 2, p.To),
		Color = p.Color,
		Transparency = 0.5,
	})
	fade(streak, 0.3, { Size = Vector3.new(0.2, 0.5, offset.Magnitude) })
end

function Effects.Zone(p)
	local total = (p.Delay or 0) + (p.Duration or 0)
	local area = disc(p.Position + Vector3.new(0, 0.15, 0), p.Radius * 2, p.Color, 0.7)
	if (p.Delay or 0) > 0 then
		-- Telegraph: an inner ring grows to the edge, then the blow lands.
		local fill = disc(p.Position + Vector3.new(0, 0.2, 0), 0.5, p.Color, 0.45)
		TweenService:Create(fill, TweenInfo.new(p.Delay, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.2, p.Radius * 2, p.Radius * 2),
		}):Play()
		local meteor = fxPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * math.min(p.Radius * 0.5, 8),
			CFrame = CFrame.new(p.Position + Vector3.new(0, 60, 0)),
			Color = p.Color,
		})
		TweenService:Create(meteor, TweenInfo.new(p.Delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(p.Position),
		}):Play()
		task.delay(p.Delay, function()
			meteor:Destroy()
			fade(fill, 0.3)
			Effects.Ring({ Position = p.Position, Radius = p.Radius * 1.2, Color = p.Color })
		end)
	end
	task.delay(math.max(total, 0.2), function()
		fade(area, 0.4)
	end)
end

function Effects.Aura(p)
	local part = p.Part
	if not (part and part.Parent) then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(p.Color)
	emitter.LightEmission = 1
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = part
	task.delay(p.Duration or 1, function()
		emitter.Enabled = false
		task.wait(1)
		emitter:Destroy()
	end)
end

function VFXController.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalVFX"
	folder.Parent = workspace
	Remotes.Effect.OnClientEvent:Connect(function(kind, params)
		local handler = Effects[kind]
		if handler and type(params) == "table" then
			handler(params)
		end
	end)
end

return VFXController
