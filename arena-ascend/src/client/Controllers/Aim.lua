-- Where the local player is aiming: the mouse's world position on desktop,
-- or straight ahead of the camera on touch devices.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Aim = {}

local player = Players.LocalPlayer

function Aim.Point()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and root) then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local ray
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	else
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	return result and result.Position or (ray.Origin + ray.Direction * 400)
end

-- Turns the character to face the aim point (the client owns its own physics).
function Aim.Face(point)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and point) then
		return
	end
	local flat = Vector3.new(point.X, root.Position.Y, point.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

return Aim
