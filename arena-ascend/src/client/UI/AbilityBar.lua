-- Bottom-centre bar: your health, and the four ability slots (Q E R F) with
-- cooldown sweeps, rank pips and lock states. Slots are tappable on mobile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local Classes = require(Shared:WaitForChild("Classes"))
local Stats = require(Shared:WaitForChild("Stats"))
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local AbilityBar = {}
AbilityBar.__index = AbilityBar

AbilityBar.Keys = { "Q", "E", "R", "F" }
local SLOT = 68
local GAP = 12
local WIDTH = 4 * SLOT + 3 * GAP + 120

function AbilityBar.new(gui, onCast)
	local self = setmetatable({}, AbilityBar)
	self.Cooldowns = {} -- [slot] = { Start, Duration }
	self.Slots = {}

	local root = new("Frame", {
		Name = "AbilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(WIDTH, 128),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- Tooltip above the bar
	self.Tooltip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = root,
	}, { Theme.corner(12), Theme.stroke(C.Stroke), Theme.padding(12, 10) })
	self.TooltipText = label({
		RichText = true,
		TextWrapped = true,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.Tooltip,
	})

	-- Health bar
	local health = new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Parent = root,
	}, { Theme.round(), Theme.stroke(C.Stroke) })
	self.HealthFill = new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = C.Good,
		Parent = health,
	}, { Theme.round() })
	self.HealthText = label({
		Text = "",
		Font = Theme.Bold,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = health,
	})

	-- Basic attack hint
	local basic = new("Frame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.fromOffset(104, SLOT),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Parent = root,
	}, { Theme.corner(14), Theme.stroke(C.Stroke) })
	label({
		Text = "CLICK",
		Font = Theme.Display,
		TextSize = 18,
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = basic,
	})
	self.BasicText = label({
		Text = "Attack",
		TextSize = 12,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = basic,
	})

	for index, key in AbilityBar.Keys do
		local button = new("TextButton", {
			Position = UDim2.fromOffset(120 + (index - 1) * (SLOT + GAP), 36),
			Size = UDim2.fromOffset(SLOT, SLOT),
			BackgroundColor3 = C.Raised,
			Text = "",
			AutoButtonColor = false,
			Parent = root,
		}, { Theme.corner(14) })
		local stroke = Theme.stroke(C.Stroke, 2)
		stroke.Parent = button
		local icon = label({
			Text = "",
			Font = Theme.Display,
			TextSize = 24,
			Size = UDim2.new(1, 0, 1, -14),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		local keyCap = new("Frame", {
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromOffset(18, 16),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.25,
			Parent = button,
		}, { Theme.corner(4) })
		label({
			Text = key,
			Font = Theme.Bold,
			TextSize = 11,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = keyCap,
		})
		local pips = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.fromOffset(5 * 6 + 4 * 3, 6),
			BackgroundTransparency = 1,
			Parent = button,
		}, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) }),
		})
		local pipFrames = {}
		for i = 1, Abilities.MaxRank do
			pipFrames[i] = new("Frame", {
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = C.Stroke,
				Parent = pips,
			}, { Theme.round() })
		end
		local shade = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.35,
			ZIndex = 2,
			Parent = button,
		}, { Theme.corner(14) })
		local timer = label({
			Text = "",
			Font = Theme.Display,
			TextSize = 22,
			ZIndex = 3,
			TextStrokeTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		local lock = label({
			Text = "",
			Font = Theme.Bold,
			TextSize = 11,
			TextColor3 = C.Muted,
			ZIndex = 3,
			TextWrapped = true,
			Position = UDim2.fromOffset(4, 22),
			Size = UDim2.new(1, -8, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})

		button.Activated:Connect(function()
			onCast(index)
		end)
		button.MouseEnter:Connect(function()
			self.Hovered = index
			self:RenderTooltip()
		end)
		button.MouseLeave:Connect(function()
			if self.Hovered == index then
				self.Hovered = nil
				self.Tooltip.Visible = false
			end
		end)

		self.Slots[index] = {
			Button = button,
			Stroke = stroke,
			Icon = icon,
			Pips = pipFrames,
			Shade = shade,
			Timer = timer,
			Lock = lock,
		}
	end

	RunService.RenderStepped:Connect(function()
		self:Tick()
	end)
	return self
end

function AbilityBar:Update(profile)
	self.Profile = profile
	local class = Classes.Get(profile.Class)
	self.BasicText.Text = class.Attack == "Melee" and "Swing" or (class.Attack == "Arrow" and "Shoot" or "Cast bolt")
	self.SlotInfo = Stats.AbilitySlots(profile)
	for index, info in self.SlotInfo do
		local slot = self.Slots[index]
		local ability = info.Id and Abilities.Get(info.Id)
		local unlocked = info.Unlocked and profile.Class ~= ""
		slot.Icon.Text = ability and Theme.initials(ability.Name) or "?"
		slot.Icon.TextColor3 = unlocked and ability.Color or C.Stroke
		slot.Stroke.Color = unlocked and ability.Color or C.Stroke
		slot.Lock.Text = unlocked and "" or (profile.Level < info.UnlockLevel and ("LV " .. info.UnlockLevel) or "SPEC")
		local rank = ability and Abilities.Rank(profile, ability.Id) or 0
		for i, pip in slot.Pips do
			pip.BackgroundColor3 = (unlocked and i <= rank) and (ability.Color) or C.Stroke
		end
	end
	self:RenderTooltip()
end

function AbilityBar:SetHealth(health, maxHealth)
	local fraction = maxHealth > 0 and math.clamp(health / maxHealth, 0, 1) or 0
	self.HealthFill.Size = UDim2.new(fraction, -6, 1, -6)
	self.HealthFill.Visible = fraction > 0.01
	self.HealthFill.BackgroundColor3 = fraction > 0.5 and C.Good or (fraction > 0.25 and C.Gold or C.Danger)
	self.HealthText.Text = string.format("%d / %d", math.ceil(health), maxHealth)
end

function AbilityBar:StartCooldown(slot, duration)
	self.Cooldowns[slot] = { Start = os.clock(), Duration = duration }
end

function AbilityBar:IsReady(slot)
	local cd = self.Cooldowns[slot]
	return not cd or os.clock() - cd.Start >= cd.Duration
end

function AbilityBar:Tick()
	local now = os.clock()
	for index, slot in self.Slots do
		local cd = self.Cooldowns[index]
		local remaining = cd and (cd.Duration - (now - cd.Start)) or 0
		if remaining > 0 then
			slot.Shade.Size = UDim2.fromScale(1, remaining / cd.Duration)
			slot.Timer.Text = remaining >= 1 and tostring(math.ceil(remaining)) or string.format("%.1f", remaining)
		else
			slot.Shade.Size = UDim2.fromScale(1, 0)
			slot.Timer.Text = ""
		end
	end
end

function AbilityBar:RenderTooltip()
	local index = self.Hovered
	local info = index and self.SlotInfo and self.SlotInfo[index]
	local ability = info and info.Id and Abilities.Get(info.Id)
	if not (ability and self.Profile) then
		self.Tooltip.Visible = false
		return
	end
	local rank = Abilities.Rank(self.Profile, ability.Id)
	local stats = Stats.Compute(self.Profile)
	local status = info.Unlocked and string.format("Rank %d/%d  -  %.1fs cooldown", rank, Abilities.MaxRank, Stats.AbilityCooldown(stats, self.Profile, ability))
		or info.Reason
	self.TooltipText.Text = string.format(
		'<font size="16" color="%s"><b>%s</b></font>   <font color="%s">%s</font>\n%s',
		Theme.hex(ability.Color), ability.Name, Theme.hex(C.Muted), status or "", ability.Description
	)
	self.Tooltip.Visible = true
end

return AbilityBar
