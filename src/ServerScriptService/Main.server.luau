--!strict
-- Server entry point. Services are plain ModuleScripts; listeners are wired before DataService starts
-- loading players so no ProfileLoaded event is missed.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.Services
local PrototypeMap = require(ServerScriptService.World.PrototypeMap)

PrototypeMap.BuildIfEmpty()

local startOrder: { { Start: () -> () } } = {
	require(Services.EquipService),
	require(Services.ProgressionService),
	require(Services.ZoneService),
	require(Services.MiningService),
	require(Services.TutorialService),
	require(Services.DataService),
}

for _, service in startOrder do
	service.Start()
end
