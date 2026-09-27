-- Creates the remotes on the server and waits for them on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	Attack = "RemoteEvent", -- client -> server: (aimPosition) basic attack with the equipped weapon
	CastAbility = "RemoteEvent", -- client -> server: (slot, aimPosition)
	Shop = "RemoteFunction", -- client -> server: ("Buy" | "Equip", category, id) -> { Ok, Message }
	Progression = "RemoteFunction", -- client -> server: (action, ...) class, stats, abilities, talents -> { Ok, Message }
	Party = "RemoteFunction", -- client -> server: (action, userId?) -> { Ok, Message }
	RequestProfile = "RemoteFunction", -- client -> server: -> profile snapshot
	ProfileUpdated = "RemoteEvent", -- server -> client: profile snapshot
	PartyUpdated = "RemoteEvent", -- server -> client: party snapshot or nil
	Notify = "RemoteEvent", -- server -> client: (kind, data)
	HitMarker = "RemoteEvent", -- server -> client: (position, amount, isCrit, isHeal)
	Effect = "RemoteEvent", -- server -> all clients: (kind, params) ability visuals
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for name in DEFINITIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
