-- Basic attacks with the equipped weapon, and floating damage / heal numbers.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Aim = require(script.Parent.Aim)

local CombatController = {}

local player = Players.LocalPlayer
local hooked = setmetatable({}, { __mode = "k" })

-- Returns false while a menu is open, so clicks on UI don't swing.
CombatController.CanAttack = function()
	return true
end

local function hookTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("WeaponId") or hooked[tool] then
		return
	end
	hooked[tool] = true
	local readyAt = 0
	tool.Activated:Connect(function()
		if os.clock() < readyAt or not CombatController.CanAttack() then
			return
		end
		readyAt = os.clock() + (tool:GetAttribute("Cooldown") or 0.6)
		local point = Aim.Point()
		if tool:GetAttribute("Attack") ~= "Melee" then
			Aim.Face(point)
		end
		Remotes.Attack:FireServer(point)
	end)
end

local function watch(container)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

local function floatingNumber(position, amount, isCrit, isHeal)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(math.random() * 2 - 1, 2.5, math.random() * 2 - 1)
	attachment.Parent = workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = attachment

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	if isHeal then
		text.Text = "+" .. amount
		text.TextColor3 = Color3.fromRGB(110, 240, 150)
		text.TextSize = 24
	else
		text.Text = isCrit and (tostring(amount) .. "!") or tostring(amount)
		text.TextSize = isCrit and 34 or 26
		text.TextColor3 = isCrit and Color3.fromRGB(255, 190, 70) or Color3.fromRGB(255, 255, 255)
	end
	text.TextStrokeTransparency = 0.2
	text.TextStrokeColor3 = Color3.fromRGB(20, 12, 10)
	text.Parent = gui

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		attachment:Destroy()
	end)
end

function CombatController.Start()
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	Remotes.HitMarker.OnClientEvent:Connect(floatingNumber)
end

return CombatController
