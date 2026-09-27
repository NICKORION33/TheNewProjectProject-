-- Ability input: Q E R F on keyboard, the ability bar buttons on touch,
-- and ButtonX / ButtonY / ButtonL1 / ButtonR1 on gamepad.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Aim = require(script.Parent.Aim)

local AbilityController = {}

local KEYS = {
	{ Enum.KeyCode.Q, Enum.KeyCode.ButtonX },
	{ Enum.KeyCode.E, Enum.KeyCode.ButtonY },
	{ Enum.KeyCode.R, Enum.KeyCode.ButtonL1 },
	{ Enum.KeyCode.F, Enum.KeyCode.ButtonR1 },
}

-- `bar` is the AbilityBar (for cooldown checks); `canCast()` gates input while menus are open.
function AbilityController.Start(bar, canCast)
	local function cast(slot)
		if not canCast() or not bar:IsReady(slot) then
			return
		end
		local point = Aim.Point()
		Aim.Face(point)
		Remotes.CastAbility:FireServer(slot, point)
	end
	AbilityController.Cast = cast

	for slot, keys in KEYS do
		ContextActionService:BindAction("Ability" .. slot, function(_, state)
			if state == Enum.UserInputState.Begin then
				cast(slot)
			end
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(keys))
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind, data)
		if kind == "Cast" then
			bar:StartCooldown(data.Slot, data.Cooldown)
		end
	end)
end

return AbilityController
