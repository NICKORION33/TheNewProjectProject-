-- Server entry point: build the world, then start every service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients connect before services finish starting.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Services = script.Parent:WaitForChild("Services")
local MapBuilder = require(script.Parent:WaitForChild("World"):WaitForChild("MapBuilder"))

local map = MapBuilder.Build()

require(Services.DataService).Init()
require(Services.StatusService).Init()
require(Services.PartyService).Init()
require(Services.LoadoutService).Init()
require(Services.ProgressionService).Init()
require(Services.ShopService).Init()
require(Services.PremiumService).Init()
require(Services.CombatService).Init()
require(Services.AbilityService).Init()
require(Services.GrindService).Init(map)
require(Services.MobService).Init(map)

print("[Arena Ascend] Server ready")
