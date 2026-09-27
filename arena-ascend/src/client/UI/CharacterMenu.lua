-- The Hero menu (C): spend attribute points, rank up abilities, and walk the
-- talent tree. Everything shown is computed with the same shared modules the
-- server uses, and every button goes through the Progression remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local Classes = require(Shared:WaitForChild("Classes"))
local Format = require(Shared:WaitForChild("Format"))
local Levels = require(Shared:WaitForChild("Levels"))
local Stats = require(Shared:WaitForChild("Stats"))
local Talents = require(Shared:WaitForChild("Talents"))
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local CharacterMenu = {}
CharacterMenu.__index = CharacterMenu

local SIZE = Vector2.new(880, 560)
local BODY_TOP = 128
local TABS = { "Attributes", "Abilities", "Talents" }

function CharacterMenu.new(playerGui, remote, callbacks)
	local self = setmetatable({}, CharacterMenu)
	self.Remote = remote
	self.Callbacks = callbacks or {}
	self.Tab = "Attributes"
	self.SelectedTalent = nil

	local gui = new("ScreenGui", {
		Name = "HeroMenu",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.Gui = gui
	local dim = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.4,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	dim.Activated:Connect(function()
		self:Close()
	end)

	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		BackgroundColor3 = C.Panel,
		Parent = gui,
	}, { Theme.corner(20), Theme.stroke(C.Stroke, 1.5) })
	self.Panel = panel
	self.Scale = new("UIScale", { Parent = panel })

	self.ClassName = label({
		Font = Theme.Display,
		TextSize = 30,
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(420, 34),
		Parent = panel,
	})
	self.SubTitle = label({
		TextSize = 13,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(26, 50),
		Size = UDim2.fromOffset(420, 16),
		Parent = panel,
	})
	local close = Theme.button("X", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(40, 40),
		TextColor3 = C.Text,
		Parent = panel,
	})
	close.Activated:Connect(function()
		self:Close()
	end)
	local changeClass = Theme.button("CHANGE CLASS", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 20),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 14,
		TextColor3 = C.Text,
		Parent = panel,
	})
	changeClass.Activated:Connect(function()
		self:Close()
		if self.Callbacks.OnChangeClass then
			self.Callbacks.OnChangeClass()
		end
	end)

	-- Point counters
	self.PointText = label({
		RichText = true,
		Font = Theme.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 84),
		Size = UDim2.fromOffset(420, 32),
		Parent = panel,
	})

	-- Tabs
	self.TabButtons = {}
	for index, tab in TABS do
		local button = new("TextButton", {
			Position = UDim2.fromOffset(24 + (index - 1) * 128, 80),
			Size = UDim2.fromOffset(120, 40),
			BackgroundColor3 = C.Raised,
			Text = tab,
			Font = Theme.Bold,
			TextSize = 15,
			TextColor3 = C.Muted,
			AutoButtonColor = false,
			Parent = panel,
		}, { Theme.round() })
		button.Activated:Connect(function()
			self.Tab = tab
			self:Render()
		end)
		self.TabButtons[tab] = button
	end

	self.Body = new("Frame", {
		Position = UDim2.fromOffset(24, BODY_TOP + 8),
		Size = UDim2.fromOffset(SIZE.X - 48, SIZE.Y - BODY_TOP - 32),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local function rescale()
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		self.Scale.Scale = math.min(1, (viewport.X - 24) / SIZE.X, (viewport.Y - 24) / SIZE.Y)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return self
end

function CharacterMenu:Request(action, ...)
	local ok, response = pcall(self.Remote.InvokeServer, self.Remote, action, ...)
	local toast = self.Callbacks.OnToast
	if not ok or type(response) ~= "table" then
		if toast then
			toast("Couldn't reach the server - try again.", C.Danger)
		end
		return
	end
	if toast then
		toast(response.Message, response.Ok and C.Good or C.Danger)
	end
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function statRow(parent, order, name, value)
	local row = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	label({ Text = name, TextColor3 = C.Muted, TextSize = 14, Size = UDim2.fromScale(0.6, 1), Parent = row })
	label({
		Text = value,
		Font = Theme.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		Parent = row,
	})
end

function CharacterMenu:RenderAttributes(profile, stats, class)
	local free = Stats.FreeStatPoints(profile)
	local list = new("Frame", {
		Size = UDim2.new(0, 480, 1, 0),
		BackgroundTransparency = 1,
		Parent = self.Body,
	}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for order, attribute in Stats.Attributes do
		local row = new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = C.Raised,
			Parent = list,
		}, { Theme.corner(14) })
		label({
			Text = attribute,
			Font = Theme.Display,
			TextSize = 20,
			Position = UDim2.fromOffset(16, 12),
			Size = UDim2.fromOffset(200, 24),
			Parent = row,
		})
		label({
			Text = Stats.AttributeInfo[attribute],
			TextSize = 12,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(16, 38),
			Size = UDim2.fromOffset(220, 14),
			Parent = row,
		})
		local allocated = profile.Allocated[attribute] or 0
		label({
			Text = string.format("class %d  +  spent %d", math.floor(stats[attribute] - allocated), allocated),
			TextSize = 11,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(16, 54),
			Size = UDim2.fromOffset(220, 14),
			Parent = row,
		})
		label({
			Text = tostring(math.floor(stats[attribute])),
			Font = Theme.Display,
			TextSize = 32,
			TextColor3 = class.Color,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(220, 20),
			Size = UDim2.fromOffset(80, 36),
			Parent = row,
		})
		for i, amount in { 1, 5 } do
			local enabled = free >= 1
			local button = Theme.button("+" .. amount, enabled and C.XP or C.Hover, {
				Position = UDim2.fromOffset(316 + (i - 1) * 76, 19),
				Size = UDim2.fromOffset(68, 40),
				TextColor3 = enabled and C.Ink or C.Muted,
				AutoButtonColor = enabled,
				Parent = row,
			})
			button.Activated:Connect(function()
				if enabled then
					self:Request("Allocate", attribute, amount)
				end
			end)
		end
	end

	local side = new("Frame", {
		Position = UDim2.fromOffset(500, 0),
		Size = UDim2.new(1, -500, 1, 0),
		BackgroundColor3 = C.Raised,
		Parent = self.Body,
	}, { Theme.corner(14), Theme.padding(16, 14) })
	local statList = new("Frame", {
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		Parent = side,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local rows = {
		{ "Max health", Format.Commas(stats.MaxHealth) },
		{ "Damage blocked", Format.Percent(stats.Defense) },
		{ "Physical power", string.format("x%.2f", stats.PhysicalPower) },
		{ "Spell power", string.format("x%.2f", stats.SpellPower) },
		{ "Healing power", string.format("x%.2f", stats.HealingPower) },
		{ "Basic attack", string.format("%d dmg", math.floor(stats.AttackDamage + 0.5)) },
		{ "Critical chance", Format.Percent(stats.Crit) },
		{ "Critical damage", string.format("x%.2f", stats.CritDamage) },
		{ "Attack speed", string.format("x%.2f", stats.AttackSpeed) },
		{ "Move speed", string.format("%.1f", stats.MoveSpeed) },
		{ "Cooldowns", Format.Percent(stats.CooldownMult) },
		{ "Lifesteal", Format.Percent(stats.Lifesteal) },
	}
	for order, row in rows do
		statRow(statList, order, row[1], row[2])
	end
	local cost = Levels.RespecCost(profile.Level)
	local respec = Theme.button(cost == 0 and "RESPEC (FREE)" or ("RESPEC  " .. Format.Short(cost)), C.Hover, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = C.Text,
		TextSize = 15,
		Parent = side,
	})
	respec.Activated:Connect(function()
		self:Request("Respec")
	end)
end

function CharacterMenu:RenderAbilities(profile, stats)
	local free = Stats.FreeSkillPoints(profile)
	local list = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.Body,
	}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for index, info in Stats.AbilitySlots(profile) do
		local ability = info.Id and Abilities.Get(info.Id)
		local row = new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 86),
			BackgroundColor3 = C.Raised,
			Parent = list,
		}, { Theme.corner(14) })
		local color = ability and ability.Color or C.Stroke
		local icon = new("Frame", {
			Position = UDim2.fromOffset(14, 13),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = C.Panel,
			Parent = row,
		}, { Theme.corner(14), Theme.stroke(info.Unlocked and color or C.Stroke, 2) })
		label({
			Text = ability and Theme.initials(ability.Name) or "?",
			Font = Theme.Display,
			TextSize = 22,
			TextColor3 = info.Unlocked and color or C.Stroke,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = icon,
		})

		if not ability then
			label({
				Text = "Ultimate",
				Font = Theme.Display,
				TextSize = 20,
				Position = UDim2.fromOffset(90, 16),
				Size = UDim2.fromOffset(400, 24),
				Parent = row,
			})
			label({
				Text = "Learn a specialization in the Talents tab at level 10 to unlock your ultimate.",
				TextSize = 13,
				TextColor3 = C.Muted,
				Position = UDim2.fromOffset(90, 44),
				Size = UDim2.fromOffset(560, 16),
				Parent = row,
			})
			continue
		end

		local rank = Abilities.Rank(profile, ability.Id)
		label({
			Text = ability.Name .. (ability.Ultimate and "   ULTIMATE" or ""),
			Font = Theme.Display,
			TextSize = 20,
			Position = UDim2.fromOffset(90, 10),
			Size = UDim2.fromOffset(400, 24),
			Parent = row,
		})
		label({
			Text = ability.Description,
			TextSize = 13,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(90, 36),
			Size = UDim2.fromOffset(520, 16),
			Parent = row,
		})
		local field = ability.Power and "Power" or (ability.Heal and "Heal" or (ability.HealPower and "HealPower"))
		local numbers = string.format("%.1fs cooldown", Stats.AbilityCooldown(stats, profile, ability))
		if field then
			local verb = field == "Power" and "damage" or "healing"
			numbers = string.format("%d %s  -  %s", math.floor(Stats.AbilityPower(stats, profile, ability, field) + 0.5), verb, numbers)
		end
		label({
			Text = numbers,
			Font = Theme.Bold,
			TextSize = 12,
			TextColor3 = color,
			Position = UDim2.fromOffset(90, 58),
			Size = UDim2.fromOffset(400, 14),
			Parent = row,
		})

		-- Rank pips
		for i = 1, Abilities.MaxRank do
			new("Frame", {
				Position = UDim2.fromOffset(560 + (i - 1) * 16, 62),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = (info.Unlocked and i <= rank) and color or C.Stroke,
				Parent = row,
			}, { Theme.round() })
		end

		local text, enabled
		if not info.Unlocked then
			text, enabled = info.Reason:upper(), false
		elseif rank >= Abilities.MaxRank then
			text, enabled = "MAX RANK", false
		else
			local required = Abilities.RankRequirement(info.UnlockLevel, rank + 1)
			if profile.Level < required then
				text, enabled = "RANK " .. (rank + 1) .. " AT LV " .. required, false
			else
				text, enabled = "RANK UP  (1 SP)", free >= 1
			end
		end
		local button = Theme.button(text, enabled and C.XP or C.Hover, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 12),
			Size = UDim2.fromOffset(170, 40),
			TextSize = 13,
			TextColor3 = enabled and C.Ink or C.Muted,
			AutoButtonColor = enabled,
			Parent = row,
		})
		button.Activated:Connect(function()
			if enabled then
				self:Request("RankAbility", ability.Id)
			end
		end)
	end
end

local STATE_COLORS = {
	Learned = nil, -- class colour
	Available = C.Text,
	Locked = C.Stroke,
	Excluded = C.Danger,
}

function CharacterMenu:TalentNode(parent, order, profile, class, node)
	local state = Talents.State(profile, node)
	local rank = profile.Talents[node.Id] or 0
	local color = state == "Learned" and class.Color or STATE_COLORS[state]
	local selected = self.SelectedTalent == node.Id
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = selected and C.Hover or C.Panel,
		BackgroundTransparency = state == "Excluded" and 0.5 or 0,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	}, { Theme.corner(10), Theme.stroke(color, selected and 2.5 or 1.5) })
	label({
		Text = node.Name,
		Font = Theme.Bold,
		TextSize = 14,
		TextColor3 = state == "Locked" and C.Muted or C.Text,
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -70, 0, 18),
		Parent = button,
	})
	label({
		Text = state == "Excluded" and "Other path chosen" or ("Lv " .. node.Level),
		TextSize = 11,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -70, 0, 14),
		Parent = button,
	})
	label({
		Text = string.format("%d/%d", rank, node.MaxRank),
		Font = Theme.Display,
		TextSize = 18,
		TextColor3 = rank > 0 and class.Color or C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 11),
		Size = UDim2.fromOffset(60, 22),
		Parent = button,
	})
	button.Activated:Connect(function()
		self.SelectedTalent = node.Id
		self:Render()
	end)
end

function CharacterMenu:RenderTalents(profile, stats, class)
	local nodes = Talents.ForClass(profile.Class)
	local columns = { { Branch = "Core", Title = "Core", Summary = "Open to every class" } }
	for _, specId in class.Specs do
		local spec = Classes.Specs[specId]
		table.insert(columns, { Branch = specId, Title = spec.Name, Summary = spec.Summary .. "  -  ultimate: " .. Abilities.Get(spec.Ultimate).Name })
	end
	local width = (SIZE.X - 48 - 2 * 16) / 3
	for index, column in columns do
		local frame = new("Frame", {
			Position = UDim2.fromOffset((index - 1) * (width + 16), 0),
			Size = UDim2.new(0, width, 1, -86),
			BackgroundColor3 = C.Raised,
			Parent = self.Body,
		}, { Theme.corner(14), Theme.padding(10, 10) })
		local list = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = frame,
		}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		label({
			LayoutOrder = 0,
			Text = column.Title,
			Font = Theme.Display,
			TextSize = 18,
			TextColor3 = column.Branch == "Core" and C.Text or class.Color,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = list,
		})
		label({
			LayoutOrder = 1,
			Text = column.Summary,
			TextSize = 11,
			TextColor3 = C.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = list,
		})
		local order = 2
		for _, node in nodes do
			if node.Branch == column.Branch then
				if node.Tier == 2 and node.Id:sub(-1) == "B" then
					label({
						LayoutOrder = order,
						Text = "- OR -",
						Font = Theme.Bold,
						TextSize = 10,
						TextColor3 = C.Muted,
						Size = UDim2.new(1, 0, 0, 10),
						TextXAlignment = Enum.TextXAlignment.Center,
						Parent = list,
					})
					order += 1
				end
				self:TalentNode(list, order, profile, class, node)
				order += 1
			end
		end
	end

	-- Detail strip for the selected talent
	local detail = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = C.Raised,
		Parent = self.Body,
	}, { Theme.corner(14) })
	local node = self.SelectedTalent and Talents.Get(profile.Class, self.SelectedTalent)
	if not node then
		label({
			Text = "Pick a talent to see what it does. Specializations lock the other branch - choose your path!",
			TextSize = 14,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Parent = detail,
		})
		return
	end
	local state, reason = Talents.State(profile, node)
	label({
		Text = node.Name,
		Font = Theme.Display,
		TextSize = 20,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(500, 24),
		Parent = detail,
	})
	label({
		Text = node.Description .. (reason and reason ~= "Maxed" and ("   (" .. reason .. ")") or ""),
		TextSize = 13,
		TextColor3 = C.Muted,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -230, 0, 32),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})
	local rank = profile.Talents[node.Id] or 0
	local canLearn = (state == "Available" or (state == "Learned" and rank < node.MaxRank)) and Stats.FreeSkillPoints(profile) >= 1
	local text = rank >= node.MaxRank and "LEARNED" or (canLearn and "LEARN  (1 SP)" or state:upper())
	local learn = Theme.button(text, canLearn and class.Color or C.Hover, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(190, 44),
		TextColor3 = canLearn and C.Ink or C.Muted,
		AutoButtonColor = canLearn,
		Parent = detail,
	})
	learn.Activated:Connect(function()
		if canLearn then
			self:Request("LearnTalent", node.Id)
		end
	end)
end

---------------------------------------------------------------------------

function CharacterMenu:Render()
	local profile = self.Profile
	if not (profile and self.Gui.Enabled) then
		return
	end
	local class = Classes.Get(profile.Class)
	local stats = Stats.Compute(profile)
	local spec = Talents.Spec(profile)

	self.ClassName.Text = class.Name .. (spec and ("  -  " .. spec.Name) or "")
	self.ClassName.TextColor3 = class.Color
	self.SubTitle.Text = string.format("Level %d %s  -  %s", profile.Level, profile.Title, class.Role)
	self.PointText.Text = string.format(
		'Attribute points <font color="%s">%d</font>     Skill points <font color="%s">%d</font>',
		Theme.hex(C.XP), Stats.FreeStatPoints(profile), Theme.hex(C.Gold), Stats.FreeSkillPoints(profile)
	)
	for tab, button in self.TabButtons do
		local active = tab == self.Tab
		button.BackgroundColor3 = active and C.Text or C.Raised
		button.TextColor3 = active and C.Ink or C.Muted
	end

	self.Body:ClearAllChildren()
	if self.Tab == "Attributes" then
		self:RenderAttributes(profile, stats, class)
	elseif self.Tab == "Abilities" then
		self:RenderAbilities(profile, stats)
	else
		self:RenderTalents(profile, stats, class)
	end
end

function CharacterMenu:Update(profile)
	self.Profile = profile
	self:Render()
end

function CharacterMenu:Open()
	if not self.Profile or self.Profile.Class == "" then
		return
	end
	self.Gui.Enabled = true
	self:Render()
end

function CharacterMenu:Close()
	self.Gui.Enabled = false
end

function CharacterMenu:Toggle()
	if self.Gui.Enabled then
		self:Close()
	else
		self:Open()
	end
end

return CharacterMenu
