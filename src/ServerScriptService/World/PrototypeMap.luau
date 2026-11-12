--!strict
-- Builds a playable greybox world when Workspace.Zones is empty. Once your real map exists (following the
-- same folder/tag contract, see docs/04-studio-hierarchy.md) this does nothing, so it's safe to leave in.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ZoneUtil = require(Shared.ZoneUtil)
local Zones = require(Shared.Config.Zones)

local ZONE_LENGTH = 100
local ZONE_WIDTH = 110
local FIRST_ZONE_START = 30
local NODES_PER_ZONE = 10

local PrototypeMap = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function invisibleWall(parent: Instance, size: Vector3, position: Vector3)
	makePart({
		Name = "Boundary",
		Size = size,
		Position = position,
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
end

local function buildLobby()
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	makePart({
		Name = "Floor",
		Size = Vector3.new(70, 4, 60),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(150, 140, 160),
		Parent = lobby,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	-- Rotated so players spawn facing the zones (+Z).
	spawn.CFrame = CFrame.new(0, 0.5, -12) * CFrame.Angles(0, math.pi, 0)
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(235, 225, 255)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	local station = Instance.new("Model")
	station.Name = "UpgradeStation"
	local base = makePart({
		Name = "Base",
		Size = Vector3.new(8, 1, 8),
		Position = Vector3.new(-16, 0.5, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(240, 235, 255),
		Parent = station,
	})
	makePart({
		Name = "Pillar",
		Size = Vector3.new(2, 5, 2),
		Position = Vector3.new(-16, 3.5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(255, 200, 90),
		Parent = station,
	})
	local orb = makePart({
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = Vector3.new(-16, 7.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 110, 255),
		CanCollide = false,
		Parent = station,
	})
	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 16
	light.Brightness = 2
	light.Parent = orb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Upgrade Station"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensShop", true)
	prompt.Parent = base

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 50)
	sign.StudsOffset = Vector3.new(0, 3, 0)
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "UPGRADES"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = sign
	sign.Parent = orb

	station.PrimaryPart = base
	station.Parent = lobby
	lobby.Parent = Workspace

	invisibleWall(lobby, Vector3.new(2, 30, 60), Vector3.new(36, 15, 0))
	invisibleWall(lobby, Vector3.new(2, 30, 60), Vector3.new(-36, 15, 0))
	invisibleWall(lobby, Vector3.new(70, 30, 2), Vector3.new(0, 15, -31))
end

local function buildNode(parent: Instance, zone: Zones.ZoneDef, position: Vector3, random: Random, index: number)
	local node = Instance.new("Model")
	node.Name = "Node_" .. index

	local base = makePart({
		Name = "Rock",
		Size = Vector3.new(4.5, 2, 4.5),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
		Material = Enum.Material.Slate,
		Color = zone.FloorColor:Lerp(Color3.new(0, 0, 0), 0.35),
		Parent = node,
	})

	for i = 1, 3 do
		local height = random:NextNumber(3.5, 6)
		local offset = Vector3.new(random:NextNumber(-1.2, 1.2), 0, random:NextNumber(-1.2, 1.2))
		local tilt = CFrame.Angles(random:NextNumber(-0.45, 0.45), 0, random:NextNumber(-0.45, 0.45))
		makePart({
			Name = "Crystal" .. i,
			Size = Vector3.new(1.3, height, 1.3),
			CFrame = CFrame.new(position + offset + Vector3.new(0, 1.5 + height / 2 - 0.6, 0)) * tilt,
			Material = Enum.Material.Glass,
			Color = zone.CrystalColor,
			Transparency = 0.15,
			Reflectance = 0.15,
			CastShadow = false,
			Parent = node,
		})
	end

	local glow = Instance.new("PointLight")
	glow.Color = zone.CrystalColor
	glow.Range = 12
	glow.Brightness = 1.6
	glow.Parent = base

	node.PrimaryPart = base
	node:SetAttribute("Zone", zone.Id)
	CollectionService:AddTag(node, ZoneUtil.NodeTag)
	node.Parent = parent
end

local function buildZone(zonesFolder: Instance, zone: Zones.ZoneDef)
	local folder = Instance.new("Folder")
	folder.Name = zone.Id
	local centerZ = FIRST_ZONE_START + ZONE_LENGTH / 2 + (zone.Order - 1) * ZONE_LENGTH

	makePart({
		Name = "Floor",
		Size = Vector3.new(ZONE_WIDTH, 4, ZONE_LENGTH),
		Position = Vector3.new(0, -2, centerZ),
		Material = zone.FloorMaterial,
		Color = zone.FloorColor,
		Parent = folder,
	})

	makePart({
		Name = "Bounds",
		Size = Vector3.new(ZONE_WIDTH, 80, ZONE_LENGTH),
		Position = Vector3.new(0, 38, centerZ),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})

	if zone.Price > 0 then
		local gate = makePart({
			Name = "Gate",
			Size = Vector3.new(ZONE_WIDTH, 40, 2),
			Position = Vector3.new(0, 20, centerZ - ZONE_LENGTH / 2),
			Material = Enum.Material.ForceField,
			Color = zone.CrystalColor,
			CastShadow = false,
			Parent = folder,
		})
		gate:SetAttribute("Zone", zone.Id)
		CollectionService:AddTag(gate, ZoneUtil.GateTag)
	end

	local side = ZONE_WIDTH / 2 + 1
	invisibleWall(folder, Vector3.new(2, 40, ZONE_LENGTH), Vector3.new(side, 20, centerZ))
	invisibleWall(folder, Vector3.new(2, 40, ZONE_LENGTH), Vector3.new(-side, 20, centerZ))
	if zone.Order == #Zones.List then
		invisibleWall(folder, Vector3.new(ZONE_WIDTH, 40, 2), Vector3.new(0, 20, centerZ + ZONE_LENGTH / 2 + 1))
	end

	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder

	local random = Random.new(zone.Order * 7919)
	local placed: { Vector3 } = {}
	for index = 1, NODES_PER_ZONE do
		for _ = 1, 30 do
			local candidate = Vector3.new(
				random:NextNumber(-ZONE_WIDTH / 2 + 10, ZONE_WIDTH / 2 - 10),
				0,
				random:NextNumber(centerZ - ZONE_LENGTH / 2 + 12, centerZ + ZONE_LENGTH / 2 - 10)
			)
			local clear = true
			for _, other in placed do
				if (other - candidate).Magnitude < 12 then
					clear = false
					break
				end
			end
			if clear then
				table.insert(placed, candidate)
				buildNode(nodes, zone, candidate, random, index)
				break
			end
		end
	end

	folder.Parent = zonesFolder
end

function PrototypeMap.BuildIfEmpty()
	local zonesFolder = Workspace:FindFirstChild("Zones")
	if zonesFolder and #zonesFolder:GetChildren() > 0 then
		return
	end
	if not zonesFolder then
		local folder = Instance.new("Folder")
		folder.Name = "Zones"
		folder.Parent = Workspace
		zonesFolder = folder
	end
	assert(zonesFolder, "Zones folder")

	if not Workspace:FindFirstChild("Lobby") then
		buildLobby()
	end
	for _, zone in Zones.List do
		buildZone(zonesFolder, zone)
	end
end

return PrototypeMap
