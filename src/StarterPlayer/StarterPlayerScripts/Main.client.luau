--!strict
-- Client entry point. Waits for the initial replication, then starts controllers in dependency order.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Parent:WaitForChild("Controllers")

local startOrder = {
	"DataController",
	"HudController",
	"StoreController",
	"ShopController",
	"MiningController",
	"ZoneController",
	"TutorialController",
	"AmbientController",
}

for _, name in startOrder do
	local controller = require(Controllers:WaitForChild(name)) :: any
	controller.Start()
end
