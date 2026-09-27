-- A viewport-ready copy of a class's signature model from
-- ReplicatedStorage.Assets.ClassModels, facing the camera, or nil if none is installed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassModelPreview = {}

function ClassModelPreview.Clone(classId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("ClassModels")
	local template = models and models:FindFirstChild(classId)
	if not template then
		return nil
	end
	local clone = template:Clone()
	if clone:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		clone.Parent = wrapper
		wrapper.PrimaryPart = clone
		clone = wrapper
	end
	local root = clone:FindFirstChild("HumanoidRootPart", true)
	if root then
		root:Destroy()
	end
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	clone:PivotTo(CFrame.Angles(0, math.rad(template:GetAttribute("Yaw") or 0), 0))
	return clone
end

return ClassModelPreview
