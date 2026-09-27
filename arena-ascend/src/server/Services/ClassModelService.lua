-- Signature class models. When a player wears their class's signature outfit
-- and a model for that class is installed in ReplicatedStorage.Assets.ClassModels,
-- their body parts are swapped for the model's parts and re-jointed with R15
-- Motor6Ds, so Roblox's default walk/run/jump/tool animations drive it.
--
-- Models split into the 15 R15 parts (assets/models/*.glb) are rigged using the
-- joint data in Shared/ClassRigs.lua. A single-mesh model is welded on as a
-- static costume instead (it moves, but its limbs don't animate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local ClassRigs = require(Shared.ClassRigs)

local DataService = require(script.Parent.DataService)

local ClassModelService = {}

local MODEL_HEIGHT = 5.6 -- studs, roughly a default R15 avatar
local STATIC_TAG = "ClassSkin"

local R15_PARTS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- { joint (Motor6D name), parent part, child part }. Attachments are "<joint>RigAttachment".
local R15_JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso" },
	{ "Waist", "LowerTorso", "UpperTorso" },
	{ "Neck", "UpperTorso", "Head" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm" },
	{ "RightWrist", "RightLowerArm", "RightHand" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot" },
	{ "RightHip", "LowerTorso", "RightUpperLeg" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot" },
}
-- ClassRigs names the root joint "root" and the rest after their Motor6D.
local RIG_KEYS = { Root = "root", Waist = "waist", Neck = "neck" }

-- [character] = what we need to put the original body back
local originals = setmetatable({}, { __mode = "k" })

function ClassModelService.Template(classId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("ClassModels")
	return models and models:FindFirstChild(classId)
end

-- Should this player be wearing their class model right now?
local function wantedTemplate(data)
	if data.Class == "" then
		return nil
	end
	local outfit = Items.Get("Outfits", data.Equipped.Outfit)
	if not (outfit and outfit.Source == "Class" and outfit.Class == data.Class) then
		return nil
	end
	return ClassModelService.Template(data.Class)
end

---------------------------------------------------------------------------
-- Rigged (15-part) models
---------------------------------------------------------------------------

-- Clones the template's 15 body parts into one model scaled to MODEL_HEIGHT.
local function cloneBody(template)
	local source = template:Clone()
	local body = Instance.new("Model")
	for _, name in R15_PARTS do
		local part = source:FindFirstChild(name, true)
		if not (part and part:IsA("BasePart")) then
			source:Destroy()
			body:Destroy()
			return nil
		end
		part.Parent = body
	end
	source:Destroy()
	for _, inst in body:GetDescendants() do
		-- Imported bones/joints would fight the Motor6D rig.
		if inst:IsA("Bone") or inst:IsA("JointInstance") or inst:IsA("WeldConstraint") then
			inst:Destroy()
		end
	end
	local _, size = body:GetBoundingBox()
	body:ScaleTo(MODEL_HEIGHT / math.max(size.Y, 0.01))
	return body
end

local function setAttachment(part, name, worldPosition, rotation)
	local attachment = part:FindFirstChild(name)
	if not (attachment and attachment:IsA("Attachment")) then
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = part
	end
	-- World-aligned on both sides of a joint keeps each part's modelled orientation.
	attachment.WorldCFrame = CFrame.new(worldPosition) * (rotation or CFrame.identity)
	return attachment
end

local function saveOriginal(character, humanoid)
	local saved = {
		Parts = {},
		Extras = {},
		HipHeight = humanoid.HipHeight,
		AutomaticScaling = humanoid.AutomaticScalingEnabled,
	}
	for _, name in R15_PARTS do
		local part = character:FindFirstChild(name)
		if part then
			local copy = part:Clone()
			for _, inst in copy:GetDescendants() do
				-- Joints are rebuilt on restore; the nameplate is recreated live.
				if inst:IsA("JointInstance") or inst.Name == "Nameplate" then
					inst:Destroy()
				end
			end
			saved.Parts[name] = copy
		end
	end
	local rootAttachment = character.HumanoidRootPart:FindFirstChild("RootRigAttachment")
	saved.RootAttachment = rootAttachment and rootAttachment.CFrame
	for _, inst in character:GetChildren() do
		if inst:IsA("Accessory") or inst:IsA("Clothing") or inst:IsA("ShirtGraphic") or inst:IsA("BodyColors") then
			table.insert(saved.Extras, inst:Clone())
			inst:Destroy()
		end
	end
	return saved
end

local function applyRig(character, humanoid, root, template, rig)
	local body = cloneBody(template)
	if not body then
		return false
	end
	local centre, size = body:GetBoundingBox()
	local height = size.Y
	local function joint(key)
		return centre.Position + rig[key] * height
	end

	local parts = {}
	for _, name in R15_PARTS do
		parts[name] = body:FindFirstChild(name)
	end
	local oldGrip = character:FindFirstChild("RightHand") and character.RightHand:FindFirstChild("RightGripAttachment")
	local gripRotation = oldGrip and oldGrip.CFrame.Rotation or CFrame.Angles(-math.rad(90), 0, 0)

	for _, info in R15_JOINTS do
		local jointName, parentName, childName = info[1], info[2], info[3]
		local position = joint(RIG_KEYS[jointName] or jointName)
		if parentName ~= "HumanoidRootPart" then
			setAttachment(parts[parentName], jointName .. "RigAttachment", position)
		end
		setAttachment(parts[childName], jointName .. "RigAttachment", position)
	end
	-- Tools are held at the grip attachment: low in the hand's centre.
	for _, side in { "Right", "Left" } do
		local hand = parts[side .. "Hand"]
		local grip = hand.Position - Vector3.new(0, hand.Size.Y * 0.25, 0)
		local attachment = setAttachment(hand, side .. "GripAttachment", grip)
		attachment.CFrame = CFrame.new(attachment.Position) * gripRotation
	end

	if not originals[character] then
		originals[character] = saveOriginal(character, humanoid)
	end
	humanoid.AutomaticScalingEnabled = false
	for _, name in R15_PARTS do
		local part = parts[name]
		local old = character:FindFirstChild(name)
		if old then
			part.CanCollide = old.CanCollide
			part.CanQuery = old.CanQuery
			part.CanTouch = old.CanTouch
			part.Massless = old.Massless
			part.CollisionGroup = old.CollisionGroup
		end
		part.Anchored = false
		humanoid:ReplaceBodyPartR15(Enum.BodyPartR15[name], part)
	end
	body:Destroy()

	-- The root part's centre sits on the model's root joint; feet on the ground.
	local rootAttachment = root:FindFirstChild("RootRigAttachment")
	if rootAttachment then
		rootAttachment.CFrame = CFrame.identity
	end
	humanoid:BuildRigFromAttachments()
	local groundY = centre.Position.Y - height / 2
	humanoid.HipHeight = math.max(0, joint("root").Y - groundY - root.Size.Y / 2)
	character:SetAttribute("HasClassSkin", true)
	return true
end

local function restoreRig(character, humanoid)
	local saved = originals[character]
	if not saved then
		return
	end
	originals[character] = nil
	for name, copy in saved.Parts do
		humanoid:ReplaceBodyPartR15(Enum.BodyPartR15[name], copy:Clone())
	end
	local rootAttachment = character.HumanoidRootPart:FindFirstChild("RootRigAttachment")
	if rootAttachment and saved.RootAttachment then
		rootAttachment.CFrame = saved.RootAttachment
	end
	humanoid:BuildRigFromAttachments()
	humanoid.HipHeight = saved.HipHeight
	humanoid.AutomaticScalingEnabled = saved.AutomaticScaling
	for _, extra in saved.Extras do
		if extra:IsA("Accessory") then
			humanoid:AddAccessory(extra)
		else
			extra.Parent = character
		end
	end
end

---------------------------------------------------------------------------
-- Static (single-mesh) models: welded over an invisible body
---------------------------------------------------------------------------

local function setBodyVisible(character, visible)
	for _, part in character:GetDescendants() do
		if not (part:IsA("BasePart") or part:IsA("Decal")) then
			continue
		end
		if part.Name == "HumanoidRootPart" or part:FindFirstAncestorOfClass("Tool") then
			continue
		end
		local owner = part:FindFirstAncestorWhichIsA("Model")
		if owner ~= character and not part:FindFirstAncestorOfClass("Accessory") then
			continue -- our own cosmetic models
		end
		if visible then
			if part:GetAttribute("SkinHidden") then
				part.Transparency = part:GetAttribute("SkinHidden")
				part:SetAttribute("SkinHidden", nil)
			end
		elseif part:GetAttribute("SkinHidden") == nil then
			part:SetAttribute("SkinHidden", part.Transparency)
			part.Transparency = 1
		end
	end
end

local function applyStatic(character, humanoid, root, template)
	local skin = template:Clone()
	if skin:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		skin.Parent = wrapper
		wrapper.PrimaryPart = skin
		skin = wrapper
	end
	skin.Name = STATIC_TAG
	local _, size = skin:GetBoundingBox()
	skin:ScaleTo(skin:GetScale() * (template:GetAttribute("Height") or MODEL_HEIGHT) / math.max(size.Y, 0.01))

	local boxCFrame, boxSize = skin:GetBoundingBox()
	local pivotFromBox = boxCFrame:Inverse() * skin:GetPivot()
	local groundY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local yaw = math.rad(template:GetAttribute("Yaw") or 0)
	local target = root.CFrame * CFrame.new(0, groundY + boxSize.Y / 2 - root.Position.Y, 0) * CFrame.Angles(0, yaw, 0)
	skin:PivotTo(target * pivotFromBox)
	for _, part in skin:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = part
			weld.C0 = root.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
	end
	skin.Parent = character
	setBodyVisible(character, false)
	character:SetAttribute("HasClassSkin", true)
end

---------------------------------------------------------------------------

-- Puts the right look on the player's character. Returns true if it changed,
-- in which case the caller should re-equip the weapon (hands may be new parts).
function ClassModelService.Apply(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = DataService.Get(player)
	if not (humanoid and root and data) or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local template = wantedTemplate(data)
	local current = character:GetAttribute("ClassModel")
	local wanted = template and data.Class or nil
	if current == wanted then
		return false
	end

	-- Take off whatever is on now.
	local static = character:FindFirstChild(STATIC_TAG)
	if static then
		static:Destroy()
		setBodyVisible(character, true)
	end
	restoreRig(character, humanoid)
	character:SetAttribute("HasClassSkin", nil)
	character:SetAttribute("ClassModel", nil)

	if template then
		local rig = ClassRigs[data.Class]
		local ok, err = pcall(function()
			if not (rig and applyRig(character, humanoid, root, template, rig)) then
				applyStatic(character, humanoid, root, template)
			end
		end)
		if ok then
			character:SetAttribute("ClassModel", wanted)
		else
			warn("[ClassModelService] Couldn't apply", data.Class, "model:", err)
		end
	end
	return true
end

return ClassModelService
