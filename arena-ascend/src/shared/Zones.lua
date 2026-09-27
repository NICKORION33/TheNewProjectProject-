-- Safe-zone checks shared by server (damage rules) and client (HUD banner).

local Zones = {}

local function inside(part, position)
	local offset = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

function Zones.IsSafe(position)
	local map = workspace:FindFirstChild("ArenaMap")
	local zones = map and map:FindFirstChild("SafeZones")
	if not zones then
		return false
	end
	for _, zone in zones:GetChildren() do
		if zone:IsA("BasePart") and inside(zone, position) then
			return true
		end
	end
	return false
end

return Zones
