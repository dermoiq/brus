--!strict
-- Client mirror of the player's saved data. Read-only: the server is the only writer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local Remotes = ReplicatedStorage.Remotes

local DataController = {
	Changed = Signal.new(), -- (data)
}

local current: Types.PlayerData? = nil

local function set(data: Types.PlayerData)
	current = data
	DataController.Changed:Fire(data)
end

function DataController.Get(): Types.PlayerData?
	return current
end

-- Calls back now if data is loaded, then on every change.
function DataController.Observe(callback: (Types.PlayerData) -> ()): Signal.Connection
	if current then
		task.spawn(callback, current)
	end
	return DataController.Changed:Connect(callback)
end

function DataController.Start()
	Remotes.DataSync.OnClientEvent:Connect(set)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.GetData:InvokeServer()
		end)
		if ok and type(data) == "table" and not current then
			set(data)
		end
	end)
end

return DataController
