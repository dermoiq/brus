--!strict
-- Server-authoritative mining. The client only says "I swung at this node"; the server checks the node,
-- zone access, reach, held tool and swing cooldown, then decides the reward (including crits and perks).
-- Auto-Mine (game pass) runs through the exact same checks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Progression = require(Shared.Config.Progression)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local ZoneUtil = require(Shared.ZoneUtil)
local Zones = require(Shared.Config.Zones)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes

-- Accept manual swings slightly faster than the cooldown to absorb network jitter.
local COOLDOWN_TOLERANCE = 0.8
local REACH_TOLERANCE = 4
local AUTO_MINE_TICK = 0.05

local MiningService = {
	Mined = Signal.new(), -- (player, gems)
}

local hitLimiter = RateLimiter.new(12, 12)
local lastHit: { [Player]: number } = {}
local random = Random.new()

local brokenStorage = Instance.new("Folder")
brokenStorage.Name = "BrokenNodes"
brokenStorage.Parent = ServerStorage

local function nodeRadius(node: Instance): number
	if node:IsA("BasePart") then
		return node.Size.Magnitude / 2
	elseif node:IsA("Model") then
		return node:GetExtentsSize().Magnitude / 2
	end
	return 0
end

local function setupNode(node: Instance)
	local zone = Zones.ById[ZoneUtil.GetZoneId(node) or ""]
	if zone and node:GetAttribute("HitsLeft") == nil then
		node:SetAttribute("HitsLeft", zone.NodeHits)
	end
end

local function breakNode(node: Instance, zone: Zones.ZoneDef)
	local position = ZoneUtil.GetPosition(node)
	local parent = node.Parent
	node.Parent = brokenStorage
	if position then
		Remotes.MineFeedback:FireAllClients("Break", position, zone.Id)
	end
	task.delay(zone.RespawnTime, function()
		node:SetAttribute("HitsLeft", zone.NodeHits)
		node.Parent = parent
	end)
end

local function getRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return character, root
end

local function tryMine(player: Player, node: Instance, cooldownTolerance: number): boolean
	if not CollectionService:HasTag(node, ZoneUtil.NodeTag) or not node:IsDescendantOf(Workspace) then
		return false
	end
	local data = DataService.Get(player)
	local character, root = getRoot(player)
	if not data or not character or not root then
		return false
	end

	local perks = Formulas.Perks(player)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("ItemId") ~= Formulas.EquippedItem(data, perks).Id then
		return false
	end

	local zoneId = ZoneUtil.GetZoneId(node)
	local zone = zoneId and Zones.ById[zoneId]
	if not zone or not data.UnlockedZones[zone.Id] then
		return false
	end

	local position = ZoneUtil.GetPosition(node)
	local reach = Progression.MineReach + nodeRadius(node) + REACH_TOLERANCE
	if not position or (position - root.Position).Magnitude > reach then
		return false
	end

	local now = os.clock()
	if now - (lastHit[player] or 0) < Formulas.Cooldown(data) * cooldownTolerance then
		return false
	end
	lastHit[player] = now

	local reward = Formulas.HitReward(data, zone, perks)
	local crit = random:NextNumber() < Formulas.CritChance(data, perks)
	if crit then
		reward = math.floor(reward * Formulas.CritMultiplier(perks) + 0.5)
	end

	ProgressionService.AwardGems(player, reward, zone.XPPerHit)
	Remotes.MineFeedback:FireClient(player, "Hit", node, reward, crit)
	MiningService.Mined:Fire(player, reward)

	local hitsLeft = node:GetAttribute("HitsLeft")
	local remaining = (if typeof(hitsLeft) == "number" then hitsLeft else zone.NodeHits) - 1
	if remaining <= 0 then
		breakNode(node, zone)
	else
		node:SetAttribute("HitsLeft", remaining)
	end
	return true
end

local function onMineHit(player: Player, node: unknown)
	if not hitLimiter:Check(player) or typeof(node) ~= "Instance" then
		return
	end
	tryMine(player, node, COOLDOWN_TOLERANCE)
end

local function nearestMineableNode(data: Types.PlayerData, origin: Vector3): Instance?
	local best, bestDistance = nil, math.huge
	for _, node in CollectionService:GetTagged(ZoneUtil.NodeTag) do
		local zoneId = ZoneUtil.GetZoneId(node)
		local position = ZoneUtil.GetPosition(node)
		if position and zoneId and data.UnlockedZones[zoneId] and node:IsDescendantOf(Workspace) then
			local distance = (position - origin).Magnitude
			if distance < bestDistance and distance <= Progression.MineReach + nodeRadius(node) then
				best, bestDistance = node, distance
			end
		end
	end
	return best
end

local function autoMineTick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data and data.Settings.AutoMine and Formulas.Perks(player).AutoMine then
			local _, root = getRoot(player)
			if root and now - (lastHit[player] or 0) >= Formulas.Cooldown(data) then
				local node = nearestMineableNode(data, root.Position)
				if node then
					tryMine(player, node, 1)
				end
			end
		end
	end
end

function MiningService.Start()
	for _, node in CollectionService:GetTagged(ZoneUtil.NodeTag) do
		setupNode(node)
	end
	CollectionService:GetInstanceAddedSignal(ZoneUtil.NodeTag):Connect(setupNode)

	Remotes.MineHit.OnServerEvent:Connect(onMineHit)

	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTO_MINE_TICK)
			autoMineTick()
		end
	end)
end

return MiningService
