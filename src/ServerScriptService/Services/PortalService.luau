--!strict
-- Teleport portals: the lobby hub (one portal per zone) and each island's return portal. Prompts are
-- handled on the server, and a zone portal only works once that zone is unlocked.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local ZoneUtil = require(Shared.ZoneUtil)
local Zones = require(Shared.Config.Zones)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes

local PortalService = {}

local limiter = RateLimiter.new(1, 2)
local hooked: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function lobbyCFrame(): CFrame
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 10, 0)
end

local function arrivalCFrame(zoneId: string): CFrame?
	local zonesFolder = Workspace:FindFirstChild("Zones")
	local folder = zonesFolder and zonesFolder:FindFirstChild(zoneId)
	local arrival = folder and folder:FindFirstChild("ArrivalPoint")
	if arrival and arrival:IsA("BasePart") then
		return arrival.CFrame + Vector3.new(0, 4, 0)
	end
	return nil
end

local function teleport(player: Player, target: string)
	if not limiter:Check(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if target == ZoneUtil.LobbyId then
		character:PivotTo(lobbyCFrame())
		return
	end
	local zone = Zones.ById[target]
	local data = DataService.Get(player)
	if not zone or not data then
		return
	end
	if not data.UnlockedZones[zone.Id] then
		Remotes.Notify:FireClient(
			player,
			"Toast",
			`🔒 Unlock {zone.Name} first (💎 {Format.Abbreviate(zone.Price)})`
		)
		return
	end
	local destination = arrivalCFrame(zone.Id)
	if destination then
		character:PivotTo(destination)
	end
end

local function hookPortal(portal: Instance)
	local target = portal:GetAttribute("Zone")
	if typeof(target) ~= "string" then
		return
	end
	for _, descendant in portal:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and not hooked[descendant] then
			hooked[descendant] = true
			descendant.Triggered:Connect(function(player)
				teleport(player, target)
			end)
		end
	end
end

function PortalService.Start()
	for _, portal in CollectionService:GetTagged(ZoneUtil.PortalTag) do
		hookPortal(portal)
	end
	CollectionService:GetInstanceAddedSignal(ZoneUtil.PortalTag):Connect(hookPortal)
end

return PortalService
