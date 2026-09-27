-- Level / XP card, coins, streak, kill feed, toasts, reward popups and the level-up banner.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Stats = require(Shared:WaitForChild("Stats"))
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local HUD = {}
HUD.__index = HUD

local function tween(inst, time, goal, style)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function playSound(id, volume)
	local sound = new("Sound", { SoundId = id, Volume = volume or 0.5 })
	SoundService:PlayLocalSound(sound)
	sound:Destroy()
end

function HUD.new(playerGui, callbacks)
	local self = setmetatable({}, HUD)

	local gui = new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.Gui = gui

	-- Profile card ---------------------------------------------------------
	-- Bottom-left: Roblox's chat owns the top-left corner and the player list the top-right.
	local card = new("Frame", {
		Name = "ProfileCard",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(300, 78),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, { Theme.corner(16), Theme.stroke(C.Stroke) })

	local badge = new("Frame", {
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Raised,
		Parent = card,
	}, { Theme.round(), Theme.stroke(C.XP, 2) })
	label({
		Text = "LVL",
		Font = Theme.Bold,
		TextSize = 10,
		TextColor3 = C.Muted,
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	self.LevelText = label({
		Text = "1",
		Font = Theme.Display,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})

	self.TitleText = label({
		Text = "Recruit",
		Font = Theme.Display,
		TextSize = 20,
		Position = UDim2.fromOffset(80, 10),
		Size = UDim2.fromOffset(206, 22),
		Parent = card,
	})
	local bar = new("Frame", {
		Position = UDim2.fromOffset(80, 38),
		Size = UDim2.fromOffset(206, 12),
		BackgroundColor3 = C.Raised,
		Parent = card,
	}, { Theme.round() })
	self.XPFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.XP,
		Parent = bar,
	}, { Theme.round() })
	self.XPText = label({
		Text = "0 / 100 XP",
		Font = Theme.Bold,
		TextSize = 12,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(80, 54),
		Size = UDim2.fromOffset(206, 14),
		Parent = card,
	})

	-- Coins, gems + streak -------------------------------------------------
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -102),
		Size = UDim2.fromOffset(420, 36),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local coins, coinText = Theme.currencyPill("Coins")
	coins.LayoutOrder = 1
	coins.Parent = row
	self.CoinText = coinText
	local gems, gemText = Theme.currencyPill("Gems")
	gems.LayoutOrder = 2
	gems.Parent = row
	self.GemText = gemText
	self.Streak = new("Frame", {
		LayoutOrder = 3,
		Visible = false,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Ember,
		Parent = row,
	}, { Theme.round(), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	self.StreakText = label({
		Text = "STREAK 0",
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.Ink,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = self.Streak,
	})

	-- Side menu ------------------------------------------------------------
	local menu = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(72, 3 * 72 + 2 * 10),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function menuButton(order, text, key, color, deep, callback)
		local button = new("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = color,
			Text = "",
			AutoButtonColor = true,
			Parent = menu,
		}, { Theme.corner(18), Theme.stroke(deep, 2) })
		label({
			Text = text,
			Font = Theme.Display,
			TextSize = 18,
			TextColor3 = C.Ink,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(0, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		local cap = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 44),
			Size = UDim2.fromOffset(20, 16),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.2,
			Parent = button,
		}, { Theme.corner(4) })
		label({
			Text = key,
			Font = Theme.Bold,
			TextSize = 11,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cap,
		})
		button.Activated:Connect(function()
			if callback then
				callback()
			end
		end)
		return button
	end
	menuButton(1, "SHOP", "B", C.Gold, C.GoldDeep, callbacks.OnShop)
	local hero = menuButton(2, "HERO", "C", C.XP, Color3.fromRGB(40, 140, 200), callbacks.OnCharacter)
	menuButton(3, "PARTY", "P", C.Good, Color3.fromRGB(50, 150, 90), callbacks.OnParty)
	self.PointsBadge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C.Danger,
		Visible = false,
		Parent = hero,
	}, { Theme.round(), Theme.stroke(C.Ink, 2) })
	self.PointsText = label({
		Text = "0",
		Font = Theme.Display,
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.PointsBadge,
	})

	-- Safe zone banner ----------------------------------------------------
	self.SafeBanner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(230, 34),
		BackgroundColor3 = C.Good,
		Visible = false,
		Parent = gui,
	}, { Theme.round() })
	label({
		Text = "SAFE ZONE  -  PvP OFF",
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.Ink,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.SafeBanner,
	})

	-- Kill feed --------------------------------------------------------------
	self.Feed = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(420, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Toasts -----------------------------------------------------------------
	self.Toasts = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -176),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.Order = 0
	return self
end

function HUD:Update(profile)
	self.LevelText.Text = tostring(profile.Level)
	self.TitleText.Text = profile.Class ~= "" and (profile.Title .. "  " .. profile.Class) or profile.Title
	self.CoinText.Text = Format.Commas(profile.Coins)
	self.GemText.Text = Format.Commas(profile.Gems)
	local unspent = Stats.FreeStatPoints(profile) + Stats.FreeSkillPoints(profile)
	self.PointsBadge.Visible = unspent > 0 and profile.Class ~= ""
	self.PointsText.Text = unspent > 99 and "99" or tostring(unspent)
	if profile.XPToNext > 0 then
		local fraction = math.clamp(profile.XP / profile.XPToNext, 0, 1)
		tween(self.XPFill, 0.35, { Size = UDim2.fromScale(fraction, 1) })
		self.XPText.Text = string.format("%s / %s XP", Format.Commas(profile.XP), Format.Commas(profile.XPToNext))
	else
		self.XPFill.Size = UDim2.fromScale(1, 1)
		self.XPText.Text = "MAX LEVEL"
	end
end

function HUD:SetStreak(streak)
	self.Streak.Visible = streak >= 2
	self.StreakText.Text = "STREAK " .. streak
end

function HUD:SetSafe(isSafe)
	self.SafeBanner.Visible = isSafe
end

function HUD:NextOrder()
	self.Order += 1
	return self.Order
end

function HUD:Toast(text, color)
	local toast = new("Frame", {
		LayoutOrder = self:NextOrder(),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Parent = self.Toasts,
	}, {
		Theme.round(),
		Theme.stroke(color or C.Stroke, 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
	})
	local text_ = label({
		Text = text,
		Font = Theme.Bold,
		TextSize = 15,
		TextColor3 = color or C.Text,
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = toast,
	})
	task.delay(3.2, function()
		tween(toast, 0.4, { BackgroundTransparency = 1 })
		tween(text_, 0.4, { TextTransparency = 1 })
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.4, { Transparency = 1 })
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

function HUD:KillFeed(data)
	local entry = new("Frame", {
		LayoutOrder = -self:NextOrder(),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Parent = self.Feed,
	}, { Theme.corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local streak = data.Streak >= 2 and string.format('  <font color="%s">x%d</font>', Theme.hex(C.Ember), data.Streak) or ""
	label({
		RichText = true,
		Text = string.format(
			'<font color="%s">%s</font>  <font color="%s">[%s]</font>  %s%s',
			Theme.hex(C.Gold), Theme.escape(data.Killer), Theme.hex(C.Muted), Theme.escape(data.Weapon), Theme.escape(data.Victim), streak
		),
		Font = Theme.Bold,
		TextSize = 14,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = entry,
	})
	local entries = {}
	for _, child in self.Feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	if #entries > 5 then
		table.sort(entries, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		entries[1]:Destroy()
	end
	task.delay(6, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

function HUD:Reward(data)
	local text = string.format(
		'<font color="%s">+%s XP</font>   <font color="%s">+%s</font>',
		Theme.hex(C.XP), Format.Commas(data.XP), Theme.hex(C.Gold), Format.Commas(data.Coins)
	)
	local popup = label({
		RichText = true,
		Text = text,
		Font = Theme.Display,
		TextSize = 26,
		TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.64, 0),
		Size = UDim2.fromOffset(400, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.Gui,
	})
	local source = label({
		Text = data.Source or "",
		Font = Theme.Bold,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextStrokeTransparency = 0.6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.64, 24),
		Size = UDim2.fromOffset(400, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.Gui,
	})
	for _, item in { popup, source } do
		local goal = item.Position - UDim2.fromOffset(0, 40)
		tween(item, 1.2, { Position = goal })
		task.delay(0.8, function()
			tween(item, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.55)
			item:Destroy()
		end)
	end
end

function HUD:Loot(data)
	playSound("rbxasset://sounds/electronicpingshort.wav", 0.6)
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 250),
		Size = UDim2.fromOffset(320, 70),
		BackgroundColor3 = C.Panel,
		Parent = self.Gui,
	}, { Theme.corner(14), Theme.stroke(data.Color, 2) })
	local scale = new("UIScale", { Scale = 0.6, Parent = card })
	label({
		Text = "LOOT  -  " .. data.Rarity:upper(),
		Font = Theme.Bold,
		TextSize = 12,
		TextColor3 = data.Color,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label({
		Text = data.Name,
		Font = Theme.Display,
		TextSize = 26,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.5, function()
		tween(scale, 0.25, { Scale = 0 })
		task.wait(0.3)
		card:Destroy()
	end)
end

function HUD:LevelUp(data)
	playSound("rbxasset://sounds/electronicpingshort.wav", 0.8)
	local banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(420, 150),
		BackgroundTransparency = 1,
		Parent = self.Gui,
	})
	local scale = new("UIScale", { Scale = 0.4, Parent = banner })
	local parts = {
		label({
			Text = "LEVEL UP",
			Font = Theme.Display,
			TextSize = 22,
			TextColor3 = C.XP,
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = banner,
		}),
		label({
			Text = tostring(data.Level),
			Font = Theme.Display,
			TextSize = 80,
			TextStrokeTransparency = 0.3,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 82),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = banner,
		}),
		label({
			RichText = true,
			Text = string.format('%s  <font color="%s">+%s coins</font>', data.Title, Theme.hex(C.Gold), Format.Commas(data.Reward)),
			Font = Theme.Bold,
			TextSize = 18,
			Position = UDim2.fromOffset(0, 110),
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = banner,
		}),
		label({
			Text = string.format("+%d attribute points   +%d skill point%s   (press C)", data.StatPoints, data.SkillPoints, data.SkillPoints == 1 and "" or "s"),
			Font = Theme.Bold,
			TextSize = 14,
			TextColor3 = C.XP,
			Position = UDim2.fromOffset(-40, 136),
			Size = UDim2.new(1, 80, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = banner,
		}),
	}
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		for _, item in parts do
			tween(item, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		task.wait(0.55)
		banner:Destroy()
	end)
end

return HUD
