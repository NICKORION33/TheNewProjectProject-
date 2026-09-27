-- Party frames (left side), the Party menu (P) for inviting players on the
-- server, the invite popup, and outlines on your teammates in the world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared:WaitForChild("Classes"))
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local new, label = Theme.new, Theme.label

local PartyUI = {}
PartyUI.__index = PartyUI

local player = Players.LocalPlayer
local INVITE_SECONDS = 30

function PartyUI.new(gui, remote, callbacks)
	local self = setmetatable({}, PartyUI)
	self.Remote = remote
	self.Callbacks = callbacks or {}
	self.Party = nil
	self.Rows = {}
	self.Highlights = {}

	-- Member frames
	self.Frames = new("Frame", {
		Position = UDim2.new(0, 16, 0.5, -80),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Party menu
	local menu = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -104, 0.5, 0),
		Size = UDim2.fromOffset(340, 440),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(18), Theme.stroke(C.Stroke, 1.5) })
	self.Menu = menu
	label({
		Text = "PARTY",
		Font = Theme.Display,
		TextSize = 26,
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(200, 30),
		Parent = menu,
	})
	label({
		Text = "Up to 4. No friendly fire. Shared XP + coins, personal loot.",
		TextSize = 11,
		TextColor3 = C.Muted,
		TextWrapped = true,
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 0, 28),
		Parent = menu,
	})
	local close = Theme.button("X", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(34, 34),
		TextColor3 = C.Text,
		Parent = menu,
	})
	close.Activated:Connect(function()
		self:CloseMenu()
	end)
	self.List = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 80),
		Size = UDim2.new(1, -28, 1, -148),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = menu,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.LeaveButton = Theme.button("LEAVE PARTY", C.Danger, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 44),
		Visible = false,
		Parent = menu,
	})
	self.LeaveButton.Activated:Connect(function()
		self:Request("Leave")
	end)

	-- Invite popup
	self.Invite = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 250),
		Size = UDim2.fromOffset(360, 104),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(16), Theme.stroke(C.Good, 2) })
	self.InviteText = label({
		RichText = true,
		TextSize = 15,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.Invite,
	})
	local accept = Theme.button("ACCEPT", C.Good, {
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(0.5, -22, 0, 40),
		Parent = self.Invite,
	})
	local decline = Theme.button("DECLINE", C.Raised, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 52),
		Size = UDim2.new(0.5, -22, 0, 40),
		TextColor3 = C.Text,
		Parent = self.Invite,
	})
	accept.Activated:Connect(function()
		if self.PendingInvite then
			self:Request("Accept", self.PendingInvite)
		end
		self:HideInvite()
	end)
	decline.Activated:Connect(function()
		if self.PendingInvite then
			self:Request("Decline", self.PendingInvite)
		end
		self:HideInvite()
	end)

	-- Keep party health bars live.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 then
			accumulator = 0
			self:RefreshHealth()
		end
	end)
	Players.PlayerAdded:Connect(function()
		self:RenderMenu()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:RenderMenu()
		end)
	end)
	return self
end

function PartyUI:Request(action, userId)
	local ok, response = pcall(self.Remote.InvokeServer, self.Remote, action, userId)
	local toast = self.Callbacks.OnToast
	if toast then
		if ok and type(response) == "table" then
			toast(response.Message, response.Ok and C.Good or C.Danger)
		else
			toast("Couldn't reach the server - try again.", C.Danger)
		end
	end
end

local function inParty(party, userId)
	if not party then
		return false
	end
	for _, member in party.Members do
		if member.UserId == userId then
			return true
		end
	end
	return false
end

function PartyUI:SetParty(party)
	self.Party = party
	for _, row in self.Rows do
		row.Frame:Destroy()
	end
	self.Rows = {}
	self.Frames.Visible = party ~= nil
	if party then
		for order, member in party.Members do
			local isLeader = member.UserId == party.Leader
			local frame = new("Frame", {
				LayoutOrder = order,
				Size = UDim2.fromOffset(230, 46),
				BackgroundColor3 = C.Panel,
				BackgroundTransparency = 0.08,
				Parent = self.Frames,
			}, { Theme.corner(10), Theme.stroke(party.Color, member.UserId == player.UserId and 2 or 1) })
			label({
				Text = member.Name .. (isLeader and "  (leader)" or ""),
				Font = Theme.Bold,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 5),
				Size = UDim2.new(1, -20, 0, 16),
				Parent = frame,
			})
			local classDef = Classes.List[member.Class]
			label({
				Text = string.format("Lv %d %s", member.Level, member.Class),
				TextSize = 11,
				TextColor3 = classDef and classDef.Color or C.Muted,
				Position = UDim2.fromOffset(10, 21),
				Size = UDim2.new(1, -20, 0, 12),
				Parent = frame,
			})
			local track = new("Frame", {
				Position = UDim2.fromOffset(10, 36),
				Size = UDim2.new(1, -20, 0, 5),
				BackgroundColor3 = C.Raised,
				Parent = frame,
			}, { Theme.round() })
			local fill = new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.Good,
				Parent = track,
			}, { Theme.round() })
			table.insert(self.Rows, { Frame = frame, Fill = fill, UserId = member.UserId })
		end
	end
	self:RefreshHighlights()
	self:RenderMenu()
end

function PartyUI:RefreshHealth()
	for _, row in self.Rows do
		local member = Players:GetPlayerByUserId(row.UserId)
		local humanoid = member and member.Character and member.Character:FindFirstChildOfClass("Humanoid")
		local fraction = humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 0
		row.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		row.Fill.BackgroundColor3 = fraction > 0.5 and C.Good or (fraction > 0.25 and C.Gold or C.Danger)
	end
	-- Characters respawn; re-attach outlines when needed.
	if self.Party then
		for _, member in self.Party.Members do
			local other = Players:GetPlayerByUserId(member.UserId)
			local highlight = self.Highlights[member.UserId]
			if other and other ~= player and other.Character and (not highlight or highlight.Parent ~= other.Character) then
				self:RefreshHighlights()
				break
			end
		end
	end
end

function PartyUI:RefreshHighlights()
	for _, highlight in self.Highlights do
		highlight:Destroy()
	end
	self.Highlights = {}
	local party = self.Party
	if not party then
		return
	end
	for _, member in party.Members do
		local other = Players:GetPlayerByUserId(member.UserId)
		if other and other ~= player and other.Character then
			self.Highlights[member.UserId] = new("Highlight", {
				FillTransparency = 1,
				OutlineColor = party.Color,
				OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.Occluded,
				Parent = other.Character,
			})
		end
	end
end

function PartyUI:RenderMenu()
	if not self.Menu.Visible then
		return
	end
	for _, child in self.List:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local party = self.Party
	local isLeader = party and party.Leader == player.UserId
	local full = party and #party.Members >= 4
	self.LeaveButton.Visible = party ~= nil

	local others = Players:GetPlayers()
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	local order = 0
	for _, other in others do
		if other == player then
			continue
		end
		order += 1
		local member = inParty(party, other.UserId)
		local classId = other:GetAttribute("Class")
		local classDef = classId and Classes.List[classId]
		local stats = other:FindFirstChild("leaderstats")
		local level = stats and stats:FindFirstChild("Level")
		local row = new("Frame", {
			LayoutOrder = member and -order or order,
			Size = UDim2.new(1, -6, 0, 52),
			BackgroundColor3 = C.Raised,
			Parent = self.List,
		}, { Theme.corner(10), member and Theme.stroke(party.Color, 1.5) or nil })
		label({
			Text = other.DisplayName,
			Font = Theme.Bold,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -120, 0, 18),
			Parent = row,
		})
		label({
			Text = string.format("Lv %s %s", level and level.Value or "?", classDef and classDef.Name or ""),
			TextSize = 11,
			TextColor3 = classDef and classDef.Color or C.Muted,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -120, 0, 14),
			Parent = row,
		})
		local text, color, action
		if member then
			if isLeader then
				text, color, action = "REMOVE", C.Danger, "Kick"
			else
				text, color = "IN PARTY", C.Hover
			end
		elseif other:GetAttribute("PartyId") then
			text, color = "IN A PARTY", C.Hover
		elseif full then
			text, color = "FULL", C.Hover
		else
			text, color, action = "INVITE", C.Good, "Invite"
		end
		local button = Theme.button(text, color, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(96, 36),
			TextSize = 13,
			TextColor3 = action and C.Ink or C.Muted,
			AutoButtonColor = action ~= nil,
			Parent = row,
		})
		button.Activated:Connect(function()
			if action then
				self:Request(action, other.UserId)
			end
		end)
	end
	if order == 0 then
		label({
			Text = "Nobody else is on this server yet.",
			TextSize = 13,
			TextColor3 = C.Muted,
			Size = UDim2.new(1, 0, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = self.List }),
		})
	end
end

function PartyUI:ShowInvite(data)
	self.PendingInvite = data.FromUserId
	self.InviteText.Text = string.format('<b>%s</b> invited you to their party', Theme.escape(data.FromName))
	self.Invite.Visible = true
	local token = {}
	self.InviteToken = token
	task.delay(INVITE_SECONDS, function()
		if self.InviteToken == token then
			self:HideInvite()
		end
	end)
end

function PartyUI:HideInvite()
	self.Invite.Visible = false
	self.PendingInvite = nil
	self.InviteToken = nil
end

function PartyUI:OpenMenu()
	self.Menu.Visible = true
	self:RenderMenu()
end

function PartyUI:CloseMenu()
	self.Menu.Visible = false
end

function PartyUI:ToggleMenu()
	if self.Menu.Visible then
		self:CloseMenu()
	else
		self:OpenMenu()
	end
end

return PartyUI
