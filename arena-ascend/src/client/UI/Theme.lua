-- Colours, fonts and small builders shared by every screen.

local Theme = {}

local rgb = Color3.fromRGB

Theme.Colors = {
	Ink = rgb(11, 12, 18),
	Panel = rgb(21, 23, 33),
	Raised = rgb(31, 34, 47),
	Hover = rgb(40, 44, 60),
	Stroke = rgb(54, 58, 78),
	Text = rgb(243, 244, 248),
	Muted = rgb(158, 164, 186),
	Gold = rgb(255, 190, 70),
	GoldDeep = rgb(196, 128, 24),
	XP = rgb(88, 208, 255),
	Ember = rgb(255, 112, 64),
	Good = rgb(96, 220, 140),
	Danger = rgb(255, 84, 96),
	Gem = rgb(190, 120, 255),
	GemDeep = rgb(120, 60, 200),
}

Theme.Display = Enum.Font.FredokaOne
Theme.Body = Enum.Font.GothamMedium
Theme.Bold = Enum.Font.GothamBold

-- new("Frame", { Size = ... }, { child, child })
function Theme.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.corner(radius)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.round()
	return Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Theme.stroke(color, thickness, transparency)
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(x, y)
	y = y or x
	return Theme.new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	})
end

function Theme.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Theme.new("TextLabel", defaults)
end

-- A gold coin glyph built from frames.
function Theme.coin(size)
	return Theme.new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Colors.Gold,
	}, {
		Theme.round(),
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.56, 0.56),
			BackgroundTransparency = 1,
		}, {
			Theme.round(),
			Theme.stroke(Theme.Colors.GoldDeep, 2),
		}),
	})
end

-- A purple gem glyph (premium currency).
function Theme.gem(size)
	return Theme.new("Frame", {
		Name = "Gem",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, {
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.72),
			Rotation = 45,
			BackgroundColor3 = Theme.Colors.Gem,
		}, {
			Theme.corner(3),
			Theme.stroke(Theme.Colors.GemDeep, 2),
		}),
	})
end

-- A pill-shaped currency counter: returns (frame, valueLabel).
function Theme.currencyPill(kind, height)
	height = height or 36
	local pill = Theme.new("Frame", {
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
	}, {
		Theme.round(),
		Theme.stroke(Theme.Colors.Stroke),
		Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) }),
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	local glyph = kind == "Gems" and Theme.gem(height - 14) or Theme.coin(height - 14)
	glyph.Parent = pill
	local value = Theme.label({
		Text = "0",
		Font = Theme.Display,
		TextSize = 20,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = pill,
	})
	return pill, value
end

-- A solid rounded button.
function Theme.button(text, color, props)
	local button = Theme.new("TextButton", {
		Text = text,
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = Theme.Colors.Ink,
		BackgroundColor3 = color or Theme.Colors.Gold,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(120, 40),
	}, { Theme.corner(10) })
	for key, value in props or {} do
		button[key] = value
	end
	return button
end

-- Two-letter monogram used as an ability icon.
function Theme.initials(name)
	local letters = {}
	for word in name:gmatch("%a+") do
		table.insert(letters, word:sub(1, 1):upper())
	end
	if #letters == 1 then
		return name:sub(1, 2):upper()
	end
	return (letters[1] or "") .. (letters[2] or "")
end

function Theme.hex(color)
	local function byte(v)
		return math.floor(v * 255 + 0.5)
	end
	return string.format("#%02X%02X%02X", byte(color.R), byte(color.G), byte(color.B))
end

-- Makes arbitrary text (player names) safe inside RichText.
function Theme.escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

return Theme
