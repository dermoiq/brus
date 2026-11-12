--!strict
-- Shared scaffolding for every zone island: base terrain, bridge landings, the gatehouse and price gate,
-- ArrivalPoint, ReturnPortal, crystal nodes and the Bounds box. The zone's theme adds terrain features
-- and scenery in between.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneUtil = require(ReplicatedStorage.Shared.ZoneUtil)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local Kit = require(script.Parent.Kit)
local Land = require(script.Parent.Land)
local Placer = require(script.Parent.Placer)
local Props = require(script.Parent.Props)
local Types = require(script.Parent.Types)

local RADIUS = 130
local SPACING = 360
local NODE_COUNT = 14
local GATE_INSET = 4 -- the gate stands this far inside the island's south tip
local TAU = math.pi * 2
local M = Enum.Material
local LOBBY_GLOW = Color3.fromRGB(200, 160, 255)

local ZoneIsland = {
	Radius = RADIUS,
	Spacing = SPACING,
	NodeCount = NODE_COUNT,
}

-- Paved slab where a bridge meets the island: 6 studs over the void, 14 studs onto the island.
local function landing(ctx: Types.ZoneCtx, theme: Types.Theme, tipZ: number, outward: number)
	local length = 20
	local centerZ = tipZ + outward * (6 - length / 2)
	local slab =
		Props.surface(ctx.Scenery, CFrame.new(0, -0.4, centerZ), Vector3.new(22, 1.2, length), theme.Paving, "Walk")
	slab.Name = "Landing"
	Props.surface(
		ctx.Scenery,
		CFrame.new(0, -4.4, tipZ + outward * 2),
		Vector3.new(18, 7, 8),
		{ Material = theme.Paving.Material, Color = Kit.tint(theme.Paving.Color, -0.2), Variant = theme.Paving.Variant },
		"Solid"
	)
	for side = -1, 1, 2 do
		Props.marker(ctx.Scenery, Vector3.new(side * 10, 0.2, tipZ + outward * 4.5), theme.Stone, ctx.Zone.CrystalColor)
	end
	Placer.block(ctx.Placer, 0, centerZ, 16)
end

-- Monumental towers and lintel framing the entrance (scenery; they stay solid after the gate opens).
local function gatehouse(ctx: Types.ZoneCtx, theme: Types.Theme, gateZ: number)
	local color = ctx.Zone.CrystalColor
	for side = -1, 1, 2 do
		local tower =
			Props.surface(ctx.Scenery, CFrame.new(side * 32, 13, gateZ), Vector3.new(12, 74, 12), theme.Stone, "Solid")
		tower.Name = "GateTower"
		Props.surface(ctx.Scenery, CFrame.new(side * 32, 51, gateZ), Vector3.new(14, 2, 14), theme.Stone, "Solid")
		Kit.block(
			ctx.Scenery,
			CFrame.new(side * 32, 55, gateZ) * CFrame.Angles(0, math.pi / 4, 0),
			Vector3.new(3, 6, 3),
			M.Neon,
			color
		)
		Kit.block(ctx.Scenery, CFrame.new(side * 32, 20, gateZ - 6.05), Vector3.new(1, 40, 0.15), M.Neon, color)
	end
	local lintel = Props.surface(ctx.Scenery, CFrame.new(0, 47, gateZ), Vector3.new(76, 6, 10), theme.Stone, "Solid")
	lintel.Name = "Lintel"
	Kit.surfaceText(lintel, Enum.NormalId.Front, ctx.Zone.Name, Kit.tint(color, 0.35))
	Kit.block(ctx.Scenery, CFrame.new(0, 43.8, gateZ - 5.1), Vector3.new(76, 0.5, 0.3), M.Neon, color)
	Kit.light(lintel, color, 40, 1.4)
end

-- Price gate (tag ZoneGate). The panel is the PrimaryPart; every part may be faded out by the client.
local function gate(ctx: Types.ZoneCtx, gateZ: number)
	local zone = ctx.Zone
	local model = Kit.model("Gate")
	local panel =
		Kit.block(model, CFrame.new(0, 14, gateZ), Vector3.new(52, 36, 1.6), M.ForceField, zone.CrystalColor, "Solid")
	panel.Name = "Panel"
	panel.CastShadow = false
	-- Only takes effect once the client makes the opened gate non-collidable: clicks then pass through.
	panel.CanQuery = false
	for _, y in { 4, 14, 24 } do
		local bar = Kit.block(
			model,
			CFrame.new(0, y, gateZ - 0.95),
			Vector3.new(52, 0.35, 0.3),
			M.Neon,
			Kit.tint(zone.CrystalColor, 0.2)
		)
		bar.Transparency = 0.15
	end
	for _, y in { 9, 19 } do
		Kit.block(
			model,
			CFrame.new(0, y, gateZ - 0.95) * CFrame.Angles(0, 0, math.pi / 4),
			Vector3.new(2.2, 2.2, 0.2),
			M.Neon,
			Kit.tint(zone.CrystalColor, 0.35)
		)
	end
	model:SetAttribute("Zone", zone.Id)
	Kit.tag(model, ZoneUtil.GateTag)
	Kit.finishModel(model, ctx.Folder, panel, true)
end

local function arrival(ctx: Types.ZoneCtx, z: number)
	-- Centre at standing HumanoidRootPart height, facing into the island (+Z).
	local point = Kit.block(
		ctx.Folder,
		CFrame.new(0, 3, z) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(4, 1, 4),
		M.Glass,
		ctx.Zone.CrystalColor,
		"Ghost"
	)
	point.Name = "ArrivalPoint"
	point:SetAttribute("Zone", ctx.Zone.Id)
	Placer.block(ctx.Placer, 0, z, 10)
end

local function returnPortal(ctx: Types.ZoneCtx, z: number)
	local spot = Vector3.new(-24, 0, z)
	Props.portal(
		ctx.Folder,
		CFrame.lookAt(spot, spot + Vector3.new(1, 0, 0)),
		LOBBY_GLOW,
		"Lobby",
		ZoneUtil.LobbyId,
		"ReturnPortal"
	)
	Placer.block(ctx.Placer, -24, z, 12)
end

local function placeNodes(ctx: Types.ZoneCtx)
	local placed = 0
	local function add(position: Vector3?)
		if position and placed < NODE_COUNT then
			placed += 1
			Props.node(ctx.Nodes, ctx.Zone, position, ctx.Rng, placed)
		end
	end
	local spec: Placer.FindOptions = { Clear = 6.5, Margin = 5, Footprint = 5, Tries = 16, Spread = 3 }
	for _, spot in ctx.NodeSpots do
		spec.Around = spot
		add(Placer.find(ctx.Placer, ctx.Rng, spec))
	end
	-- One attempt per sector, alternating inner and outer rings, so nodes spread over the whole island.
	local remaining = NODE_COUNT - placed
	spec.Spread = 18
	spec.Tries = 30
	for index = 1, remaining do
		local angle = index / remaining * TAU + ctx.Rng:NextNumber(-0.2, 0.2)
		local reach = if index % 2 == 0 then ctx.Rng:NextNumber(36, 64) else ctx.Rng:NextNumber(70, 96)
		spec.Around = ctx.Center + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
		add(Placer.find(ctx.Placer, ctx.Rng, spec))
	end
	local fallback: Placer.FindOptions =
		{ Clear = 6.5, Margin = 5, Footprint = 5, Tries = 300, MinDist = 20, MaxDist = RADIUS - 16 }
	while placed < NODE_COUNT do
		local position = Placer.find(ctx.Placer, ctx.Rng, fallback)
		if not position then
			break
		end
		add(position)
	end
	if placed < 12 then
		warn(`[WorldBuilder] only placed {placed} crystal nodes in {ctx.Zone.Id}`)
	end
end

local function bounds(ctx: Types.ZoneCtx, minZ: number, maxZ: number)
	local box = Kit.block(
		ctx.Folder,
		CFrame.new(0, 50, (minZ + maxZ) / 2),
		Vector3.new((RADIUS + 30) * 2, 220, maxZ - minZ),
		M.Glass,
		ctx.Zone.CrystalColor,
		"Ghost"
	)
	box.Name = "Bounds"
end

function ZoneIsland.centerZ(zone: Zones.ZoneDef): number
	return zone.Order * SPACING
end

function ZoneIsland.build(
	zonesFolder: Instance,
	zone: Zones.ZoneDef,
	theme: Types.Theme,
	isLast: boolean
): Types.ZoneCtx
	local centerZ = ZoneIsland.centerZ(zone)
	local center = Vector3.new(0, 0, centerZ)

	local folder = Instance.new("Folder")
	folder.Name = zone.Id
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder
	folder.Parent = zonesFolder

	local ctx: Types.ZoneCtx = {
		Zone = zone,
		Folder = folder,
		Scenery = scenery,
		Nodes = nodes,
		Center = center,
		Radius = RADIUS,
		SouthTip = centerZ - RADIUS,
		NorthTip = centerZ + RADIUS,
		IsLast = isLast,
		Rng = Random.new(zone.Order * 7919 + 101),
		Placer = Placer.new(center, RADIUS),
		NodeSpots = {},
	}

	local keepClear = {}
	local clearPoints: { Vector3 } = theme.KeepClear or {}
	for _, point in clearPoints do
		table.insert(keepClear, center + point)
	end
	Land.island(center, RADIUS, theme.Style, ctx.Rng, keepClear)

	local gateZ = ctx.SouthTip + GATE_INSET
	landing(ctx, theme, ctx.SouthTip, -1)
	if not isLast then
		landing(ctx, theme, ctx.NorthTip, 1)
	end
	gatehouse(ctx, theme, gateZ)
	if zone.Price > 0 then
		gate(ctx, gateZ)
	end
	Placer.block(ctx.Placer, 0, gateZ, 30)
	arrival(ctx, ctx.SouthTip + 26)
	returnPortal(ctx, ctx.SouthTip + 36)
	-- Keep the main walkway along the island's axis clear of nodes and clutter.
	Placer.blockLine(
		ctx.Placer,
		Vector3.new(0, 0, ctx.SouthTip),
		Vector3.new(0, 0, if isLast then centerZ else ctx.NorthTip),
		7
	)

	theme.Build(ctx)
	placeNodes(ctx)
	if theme.Dress then
		theme.Dress(ctx)
	end

	-- Starts just behind the gate so players waiting on the bridge side are never inside a locked zone.
	local minZ = if zone.Price > 0 then gateZ + 2 else ctx.SouthTip - 4
	bounds(ctx, minZ, ctx.NorthTip + 24)
	return ctx
end

return ZoneIsland
