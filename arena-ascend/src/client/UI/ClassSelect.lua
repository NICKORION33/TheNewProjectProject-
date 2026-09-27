-- Full-screen class picker. Shown automatically for new players, and from
-- the Hero menu when changing class (which refunds points and costs coins).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local Classes = require(Shared:WaitForChild("Classes"))
local Format = require(Shared:WaitForChild("Format"))
local Items = require(Shared:WaitForChild("Items"))
local Levels = require(Shared:WaitForChild("Levels"))
local Visuals = require(Shared:WaitForChild("Visuals"))
local Theme = require(script.Parent.Theme)
local ClassModelPreview = require(script.Parent.ClassModelPreview)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local ClassSelect = {}
ClassSelect.__index = ClassSelect

local CARD = Vector2.new(208, 452)
local GAP = 14
local WIDTH = #Classes.Order * CARD.X + (#Classes.Order - 1) * GAP
local HEIGHT = CARD.Y + 130
local MAX_ATTRIBUTE = 8

function ClassSelect.new(playerGui, remote, callbacks)
	local self = setmetatable({}, ClassSelect)
	self.Remote = remote
	self.Callbacks = callbacks or {}
	self.Models = {}

	local gui = new("ScreenGui", {
		Name = "ClassSelect",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.Gui = gui
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.08,
		Parent = gui,
	})

	local content = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.Scale = new("UIScale", { Parent = content })

	self.Title = label({
		Text = "CHOOSE YOUR CLASS",
		Font = Theme.Display,
		TextSize = 44,
		Size = UDim2.new(1, 0, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	self.Subtitle = label({
		Text = "Every class can fight in the Pit, grind the Wilds and join a party. You can change later.",
		TextSize = 15,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	self.Close = Theme.button("CANCEL", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(110, 40),
		TextColor3 = C.Text,
		Visible = false,
		Parent = content,
	})
	self.Close.Activated:Connect(function()
		self:Hide()
	end)

	self.ChooseButtons = {}
	for index, classId in Classes.Order do
		self:BuildCard(content, index, Classes.Get(classId))
	end

	local function rescale()
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		self.Scale.Scale = math.min(1, (viewport.X - 32) / WIDTH, (viewport.Y - 32) / HEIGHT)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return self
end

function ClassSelect:BuildCard(parent, index, class)
	local card = new("Frame", {
		Position = UDim2.fromOffset((index - 1) * (CARD.X + GAP), 96),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundColor3 = C.Panel,
		Parent = parent,
	}, { Theme.corner(18), Theme.stroke(class.Color, 2) })

	local viewport = new("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 170),
		BackgroundColor3 = C.Raised,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.2, 0.6),
		Parent = card,
	}, { Theme.corner(14) })
	local camera = new("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local weapon = Items.Get("Weapons", "WoodenSword")
	local model = ClassModelPreview.Clone(class.Id)
		or Visuals.BuildMannequin(Items.Get("Outfits", class.Outfit), nil, weapon, class.WeaponStyle)
	model.Parent = viewport
	local cframe, size = model:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) / (2 * math.tan(math.rad(15))) * 1.1
	camera.CFrame = CFrame.lookAt(cframe.Position + Vector3.new(0.45, 0.1, -1).Unit * distance, cframe.Position)
	table.insert(self.Models, { Model = model, Pivot = model:GetPivot(), Offset = index })

	label({
		Text = class.Name,
		Font = Theme.Display,
		TextSize = 26,
		TextColor3 = class.Color,
		Position = UDim2.fromOffset(16, 186),
		Size = UDim2.new(1, -32, 0, 28),
		Parent = card,
	})
	label({
		Text = class.Role:upper() .. "   " .. string.rep("*", class.Difficulty) .. string.rep(".", 3 - class.Difficulty),
		Font = Theme.Bold,
		TextSize = 11,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(16, 214),
		Size = UDim2.new(1, -32, 0, 14),
		Parent = card,
	})
	label({
		Text = class.Description,
		TextSize = 12,
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 234),
		Size = UDim2.new(1, -32, 0, 44),
		Parent = card,
	})

	for i, attribute in { "Strength", "Intellect", "Vitality", "Agility" } do
		local y = 282 + (i - 1) * 18
		label({
			Text = attribute:sub(1, 3):upper(),
			Font = Theme.Bold,
			TextSize = 11,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.fromOffset(34, 12),
			Parent = card,
		})
		local track = new("Frame", {
			Position = UDim2.fromOffset(52, y + 3),
			Size = UDim2.new(1, -68, 0, 7),
			BackgroundColor3 = C.Raised,
			Parent = card,
		}, { Theme.round() })
		new("Frame", {
			Size = UDim2.fromScale(math.clamp(class.Base[attribute] / MAX_ATTRIBUTE, 0.06, 1), 1),
			BackgroundColor3 = class.Color,
			Parent = track,
		}, { Theme.round() })
	end

	local abilityNames = {}
	for _, id in class.Abilities do
		table.insert(abilityNames, Abilities.Get(id).Name)
	end
	local specNames = {}
	for _, specId in class.Specs do
		table.insert(specNames, Classes.Specs[specId].Name)
	end
	label({
		RichText = true,
		Text = string.format(
			'<font color="%s">%s</font>\nPaths: %s',
			Theme.hex(C.Text), table.concat(abilityNames, "  /  "), table.concat(specNames, " or ")
		),
		TextSize = 11,
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 358),
		Size = UDim2.new(1, -32, 0, 30),
		Parent = card,
	})

	local choose = Theme.button("CHOOSE", class.Color, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 44),
		TextSize = 18,
		Parent = card,
	})
	choose.Activated:Connect(function()
		self:Choose(class.Id)
	end)
	self.ChooseButtons[class.Id] = choose
end

function ClassSelect:Choose(classId)
	if self.Busy then
		return
	end
	self.Busy = true
	local ok, response = pcall(self.Remote.InvokeServer, self.Remote, "ChooseClass", classId)
	self.Busy = false
	local toast = self.Callbacks.OnToast
	if ok and type(response) == "table" then
		if toast then
			toast(response.Message, response.Ok and C.Good or C.Danger)
		end
		if response.Ok then
			self:Hide()
		end
	elseif toast then
		toast("Couldn't reach the server - try again.", C.Danger)
	end
end

-- `profile` decides whether this is a first pick (free, can't cancel) or a class change.
function ClassSelect:Show(profile)
	local firstPick = profile.Class == ""
	self.Close.Visible = not firstPick
	if firstPick then
		self.Title.Text = "CHOOSE YOUR CLASS"
		self.Subtitle.Text = "Every class can fight in the Pit, grind the Wilds and join a party. You can change later."
	else
		local cost = Levels.ClassChangeCost(profile.Level)
		self.Title.Text = "CHANGE CLASS"
		self.Subtitle.Text = string.format(
			"Your level and gear stay. Attribute, ability and talent points are refunded. Cost: %s coins.",
			cost == 0 and "free" or Format.Commas(cost)
		)
	end
	for classId, button in self.ChooseButtons do
		local current = classId == profile.Class
		button.Text = current and "CURRENT" or "CHOOSE"
		button.AutoButtonColor = not current
	end
	self.Gui.Enabled = true
	if not self.Spin then
		local angle = 0
		self.Spin = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.6
			for _, entry in self.Models do
				entry.Model:PivotTo(CFrame.Angles(0, math.sin(angle + entry.Offset) * 0.6, 0) * entry.Pivot)
			end
		end)
	end
end

function ClassSelect:Hide()
	self.Gui.Enabled = false
	if self.Spin then
		self.Spin:Disconnect()
		self.Spin = nil
	end
end

function ClassSelect:IsOpen()
	return self.Gui.Enabled
end

return ClassSelect
