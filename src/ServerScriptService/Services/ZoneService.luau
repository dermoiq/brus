--!strict
-- Tracks which zone each player stands in (player attribute "Zone", read by the client for lighting)
-- and returns anyone who slipped past a gate they haven't unlocked back to spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local DataService = require(script.Parent.DataService)

local CHECK_INTERVAL = 0.5
local LOBBY = "Lobby"

local ZoneService = {}

local function contains(part: BasePart, point: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function ZoneService.GetZoneAt(point: Vector3): string?
	local zonesFolder = Workspace:FindFirstChild("Zones")
	if not zonesFolder then
		return nil
	end
	for _, zone in Zones.List do
		local folder = zonesFolder:FindFirstChild(zone.Id)
		local bounds = folder and folder:FindFirstChild("Bounds")
		if bounds and bounds:IsA("BasePart") and contains(bounds, point) then
			return zone.Id
		end
	end
	return nil
end

local function spawnCFrame(): CFrame
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 10, 0)
end

function ZoneService.Start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local data = DataService.Get(player)
				if character and root and root:IsA("BasePart") and data then
					local zoneId = ZoneService.GetZoneAt(root.Position)
					if zoneId and not data.UnlockedZones[zoneId] then
						character:PivotTo(spawnCFrame())
						zoneId = nil
					end
					player:SetAttribute("Zone", zoneId or LOBBY)
				end
			end
		end
	end)
end

return ZoneService
