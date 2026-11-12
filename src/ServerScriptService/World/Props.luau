--!strict
-- Composite props built from Kit parts: crystal formations, mineable crystal nodes, portals, bridges,
-- lanterns, trees, glowshrooms, ruins and waterfalls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneUtil = require(ReplicatedStorage.Shared.ZoneUtil)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local Kit = require(script.Parent.Kit)
local Land = require(script.Parent.Land)
local Types = require(script.Parent.Types)

type Surface = Types.Surface

export type CrystalOptions = {
	Rock: Enum.Material?,
	RockColor: Color3?,
	Light: boolean?,
	Sparkles: boolean?,
	Solid: boolean?,
	Shards: number?,
	Name: string?,
}

export type FallOptions = {
	Lip: Vector3, -- world point on the cliff lip at the water surface
	Out: Vector3, -- horizontal unit vector pointing away from the island
	Width: number,
	Drop: number,
	Color: Color3,
	Material: Enum.Material?, -- Glass for water, Neon for lava or starlight
	Mist: Color3?,
	Spray: string?, -- particle texture at the lip
}

export type BridgeOptions = {
	Plank: Color3,
	Glow: Color3,
	Frame: Color3?,
	Rope: Color3?,
	Width: number?,
	Sag: number?,
	Lights: number?,
	Variant: string?,
	Seed: number?,
}

local TAU = math.pi * 2
local M = Enum.Material
local WOOD = Color3.fromRGB(104, 72, 50)
local IRON = Color3.fromRGB(56, 52, 62)
local GOLD = Color3.fromRGB(240, 196, 92)

local Props = {}

function Props.paint(part: BasePart, surface: Surface)
	if surface.Variant then
		Kit.variant(part, surface.Variant)
	end
end

function Props.surface(parent: Instance, cf: CFrame, size: Vector3, surface: Surface, mode: Kit.Mode?): Part
	local part = Kit.block(parent, cf, size, surface.Material, surface.Color, mode)
	Props.paint(part, surface)
	return part
end

-- Square prism with a ridged tip standing on `base` (base.UpVector is the shard axis).
function Props.shard(
	parent: Instance,
	base: CFrame,
	width: number,
	height: number,
	material: Enum.Material,
	color: Color3,
	mode: Kit.Mode,
	transparency: number
): Part
	local bodyHeight = height * 0.78
	local tipHeight = height - bodyHeight
	local glassy = material == M.Glass or material == M.Ice
	local body =
		Kit.block(parent, base * CFrame.new(0, bodyHeight / 2, 0), Vector3.new(width, bodyHeight, width), material, color, mode)
	local top = base * CFrame.new(0, bodyHeight + tipHeight / 2, 0)
	local half = Vector3.new(width, tipHeight, width / 2)
	local front = Kit.wedge(parent, top * CFrame.new(0, 0, -width / 4), half, material, color, mode)
	local back =
		Kit.wedge(parent, top * CFrame.new(0, 0, width / 4) * CFrame.Angles(0, math.pi, 0), half, material, color, mode)
	for _, part in { body, front, back } :: { BasePart } do
		part.Transparency = transparency
		if glassy then
			part.Reflectance = 0.15
		end
	end
	return body
end

-- Landmark crystal cluster: a tall glass shard around a neon core, satellite shards and a rocky base.
-- Pure scenery: never tagged as a mineable node.
function Props.crystal(
	parent: Instance,
	ground: CFrame,
	height: number,
	color: Color3,
	rng: Random,
	options: CrystalOptions?
): Model
	local o: CrystalOptions = options or {}
	local model = Kit.model(o.Name or "CrystalFormation")
	local mode: Kit.Mode = if o.Solid == false then "Decor" else "Solid"
	local width = math.max(height * 0.17, 1.6)
	local rockColor = o.RockColor or Color3.fromRGB(72, 66, 80)
	for _ = 1, 3 do
		local size = width * rng:NextNumber(1, 1.6)
		Kit.block(
			model,
			ground
				* CFrame.new(rng:NextNumber(-0.7, 0.7) * width, size * 0.2, rng:NextNumber(-0.7, 0.7) * width)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(size * 1.2, size * 0.7, size),
			o.Rock or M.Slate,
			Kit.vary(rockColor, rng, 0.1),
			mode
		)
	end
	local mainBase = ground
		* CFrame.new(0, -1, 0)
		* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, TAU), rng:NextNumber(-0.08, 0.08))
	Props.shard(model, mainBase, width, height, M.Glass, color, mode, 0.3)
	local core = Kit.block(
		model,
		mainBase * CFrame.new(0, height * 0.42, 0),
		Vector3.new(width * 0.4, height * 0.68, width * 0.4),
		M.Neon,
		Kit.tint(color, 0.25),
		"Decor"
	)
	local count = o.Shards or rng:NextInteger(4, 6)
	for index = 1, count do
		local angle = index / count * TAU + rng:NextNumber(-0.3, 0.3)
		local shardHeight = height * rng:NextNumber(0.25, 0.55)
		local shardWidth = width * rng:NextNumber(0.45, 0.7)
		local spot = ground
			* CFrame.new(math.cos(angle) * width * 0.9, -0.6, math.sin(angle) * width * 0.9)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, -rng:NextNumber(0.25, 0.6))
		if index % 2 == 0 then
			Props.shard(model, spot, shardWidth, shardHeight, M.Glass, Kit.vary(color, rng, 0.08), mode, 0.25)
		else
			local wedge = Kit.wedge(
				model,
				spot * CFrame.new(0, shardHeight / 2, 0),
				Vector3.new(shardWidth, shardHeight, shardWidth),
				M.Glass,
				Kit.vary(color, rng, 0.08),
				mode
			)
			wedge.Transparency = 0.25
			wedge.Reflectance = 0.15
		end
	end
	if o.Light ~= false then
		Kit.pulse(Kit.light(core, color, height * 1.1, 2.2), 0.25, 0.2)
	end
	if o.Sparkles then
		Kit.emitter(core, {
			Texture = Kit.Textures.Sparkles,
			Color = Kit.colors(Kit.tint(color, 0.5), color),
			Size = Kit.seq(0.6, 1.2, 0),
			Transparency = Kit.seq(0.2, 0.4, 1),
			Lifetime = Kit.range(2, 3.5),
			Rate = 10,
			Speed = Kit.range(1, 3),
			Spread = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 1.5, 0),
			LightEmission = 1,
			LightInfluence = 0,
		})
	end
	return Kit.finishModel(model, parent)
end

-- Mineable crystal node (tag CrystalNode). The rock is the PrimaryPart; every piece is clickable.
function Props.node(parent: Instance, zone: Zones.ZoneDef, ground: Vector3, rng: Random, index: number): Model
	local node = Kit.model("Node_" .. index)
	local origin = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local rockMaterial = if zone.FloorMaterial == M.Basalt then M.Basalt else M.Slate
	local rockColor = Kit.tint(zone.FloorColor, -0.45)

	local rock = Kit.block(
		node,
		origin * CFrame.new(0, 0.6, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)),
		Vector3.new(5, 2.4, 4.6),
		rockMaterial,
		Kit.vary(rockColor, rng, 0.06),
		"Walk"
	)
	rock.Name = "Rock"
	rock.CastShadow = false
	local chunk = Kit.wedge(
		node,
		origin * CFrame.new(1.7, 0.9, 1.3) * CFrame.Angles(0, 0.8, 0),
		Vector3.new(2.4, 1.8, 2.4),
		rockMaterial,
		Kit.vary(rockColor, rng, 0.08),
		"Crystal"
	)
	chunk.Name = "Chunk"

	local count = rng:NextInteger(3, 5)
	local mainFrame = origin
	local mainHeight = 5
	for shardIndex = 1, count do
		local isMain = shardIndex == 1
		local angle = shardIndex / count * TAU + rng:NextNumber(-0.4, 0.4)
		local reach = if isMain then 0.2 else rng:NextNumber(0.9, 1.5)
		local height = if isMain then rng:NextNumber(4.4, 5.4) else rng:NextNumber(2.2, 3.6)
		local width = if isMain then 1.55 else rng:NextNumber(0.9, 1.25)
		local tilt = if isMain then rng:NextNumber(0, 0.12) else rng:NextNumber(0.28, 0.55)
		local cf = origin
			* CFrame.new(math.cos(angle) * reach, 1.3, math.sin(angle) * reach)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, -tilt)
			* CFrame.Angles(0, math.pi / 4, 0)
			* CFrame.new(0, height / 2, 0)
		local size = Vector3.new(width, height, width)
		local color = Kit.vary(zone.CrystalColor, rng, 0.06)
		local shard: BasePart = if shardIndex % 2 == 0
			then Kit.wedge(node, cf, size, M.Glass, color, "Crystal")
			else Kit.block(node, cf, size, M.Glass, color, "Crystal")
		shard.Name = "Crystal" .. shardIndex
		shard.Transparency = 0.15
		shard.Reflectance = 0.15
		if isMain then
			mainFrame = cf
			mainHeight = height
		end
	end
	local core = Kit.block(
		node,
		mainFrame * CFrame.new(0, -0.4, 0),
		Vector3.new(0.55, mainHeight * 0.65, 0.55),
		M.Neon,
		Kit.tint(zone.CrystalColor, 0.2),
		"Crystal"
	)
	core.Name = "Core"
	Kit.light(core, zone.CrystalColor, 12, 1.5, true)

	node:SetAttribute("Zone", zone.Id)
	Kit.tag(node, ZoneUtil.NodeTag)
	return Kit.finishModel(node, parent, rock, true)
end

-- Stone arch with a spinning swirl disc. Faces ground.LookVector; tagged Portal with attribute Zone.
function Props.portal(
	parent: Instance,
	ground: CFrame,
	color: Color3,
	label: string,
	zoneId: string,
	name: string,
	stone: Color3?
): Model
	local model = Kit.model(name)
	local stoneColor = stone or Color3.fromRGB(230, 224, 240)
	local trim = Color3.fromRGB(66, 60, 82)
	local glow = Kit.tint(color, 0.3)

	local base = Kit.block(model, ground * CFrame.new(0, 0.4, 0), Vector3.new(17, 0.8, 12), M.Slate, trim, "Walk")
	base.Name = "Base"
	Kit.cylinder(model, ground * CFrame.new(0, 1.05, 0), 0.5, 6.4, M.Marble, stoneColor, "Walk")
	Kit.cylinder(model, ground * CFrame.new(0, 1.33, 0), 0.06, 5.6, M.Neon, color, "Decor")
	Kit.cylinder(model, ground * CFrame.new(0, 1.35, 0), 0.1, 5.1, M.Marble, Kit.tint(stoneColor, -0.06), "Walk")

	for side = -1, 1, 2 do
		local x = side * 7
		Kit.block(model, ground * CFrame.new(x, 1.4, 0), Vector3.new(3.4, 1.2, 3.4), M.Slate, trim, "Solid")
		Kit.block(model, ground * CFrame.new(x, 7.6, 0), Vector3.new(2.4, 11.6, 2.4), M.Marble, stoneColor, "Solid")
		Kit.block(model, ground * CFrame.new(x, 13.8, 0), Vector3.new(3.4, 1, 3.4), M.Slate, trim, "Solid")
		Kit.block(model, ground * CFrame.new(x, 7.6, -1.25), Vector3.new(0.5, 8, 0.12), M.Neon, color, "Decor")
	end
	local archCenter = ground * CFrame.new(0, 14.3, 0)
	for index = 0, 6 do
		if index ~= 3 then
			local phi = math.pi * index / 6
			Kit.block(
				model,
				archCenter * CFrame.new(math.cos(phi) * 7, math.sin(phi) * 7, 0) * CFrame.Angles(0, 0, phi + math.pi / 2),
				Vector3.new(3.9, 2.2, 2.6),
				M.Marble,
				stoneColor,
				"Solid"
			)
		end
	end
	Kit.block(
		model,
		archCenter * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, 0, math.pi / 4),
		Vector3.new(2.7, 2.7, 2.9),
		M.Neon,
		color,
		"Decor"
	)

	local discCenter = ground * CFrame.new(0, 7.4, 0)
	local swirl = Kit.model("Swirl")
	local disc = Kit.rod(
		swirl,
		discCenter * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0),
		0.3,
		5.7,
		M.ForceField,
		color,
		"Decor"
	)
	local inner = Kit.rod(
		swirl,
		discCenter * CFrame.new(0, 0, 0.25) * CFrame.Angles(0, math.pi / 2, 0),
		0.2,
		5.3,
		M.Neon,
		Kit.tint(color, -0.15),
		"Decor"
	)
	inner.Transparency = 0.35
	for arm = 0, 5 do
		Kit.block(
			swirl,
			discCenter * CFrame.Angles(0, 0, arm * math.pi / 3) * CFrame.new(0, 2.6, -0.35) * CFrame.Angles(0, 0, 0.55),
			Vector3.new(0.4, 4.4, 0.12),
			M.Neon,
			glow,
			"Decor"
		)
	end
	swirl.WorldPivot = discCenter * CFrame.Angles(math.pi / 2, 0, 0)
	Kit.spin(swirl, 75)
	Kit.finishModel(swirl, model, nil, true)
	Kit.light(inner, color, 18, 2.2)
	Kit.emitter(disc, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(Color3.new(1, 1, 1), color),
		Size = Kit.seq(0.5, 0.3, 0),
		Transparency = Kit.seq(0.1, 0.3, 1),
		Lifetime = Kit.range(1.2, 2),
		Rate = 14,
		Speed = Kit.range(2, 5),
		Spread = Vector2.new(35, 35),
		Direction = Enum.NormalId.Right,
		LightEmission = 1,
		LightInfluence = 0,
	})

	local anchor = Kit.block(model, ground * CFrame.new(0, 4, -1.5), Vector3.new(1, 1, 1), M.Glass, color, "Ghost")
	anchor.Name = "PromptAnchor"
	Kit.prompt(anchor, "Teleport", label, 0.25, 10)
	Kit.billboard(anchor, label, glow, 19.5, 14, 160)

	model:SetAttribute("Zone", zoneId)
	Kit.tag(model, ZoneUtil.PortalTag)
	return Kit.finishModel(model, parent, base, true)
end

-- Hanging lantern below `hook`. Returns the glowing core.
function Props.lantern(parent: Instance, hook: Vector3, glow: Color3, withLight: boolean): Part
	Kit.block(parent, CFrame.new(hook + Vector3.new(0, -0.45, 0)), Vector3.new(1.3, 0.3, 1.3), M.Metal, IRON)
	local glass = Kit.block(
		parent,
		CFrame.new(hook + Vector3.new(0, -1.45, 0)),
		Vector3.new(1, 1.7, 1),
		M.Glass,
		Kit.tint(glow, 0.5)
	)
	glass.Transparency = 0.35
	local core = Kit.block(parent, CFrame.new(hook + Vector3.new(0, -1.45, 0)), Vector3.new(0.45, 1, 0.45), M.Neon, glow)
	Kit.block(parent, CFrame.new(hook + Vector3.new(0, -2.45, 0)), Vector3.new(1.2, 0.3, 1.2), M.Metal, IRON)
	if withLight then
		Kit.light(core, glow, 16, 1.4)
	end
	return core
end

-- Street lamp; the arm points along ground.RightVector.
function Props.lampPost(parent: Instance, ground: CFrame, glow: Color3, withLight: boolean, height: number?): Part
	local h = height or 10
	Kit.block(parent, ground * CFrame.new(0, 0.5, 0), Vector3.new(1.8, 1, 1.8), M.Slate, Color3.fromRGB(88, 84, 98), "Solid")
	Kit.cylinder(parent, ground * CFrame.new(0, 1 + h / 2, 0), h, 0.3, M.Metal, IRON, "Solid")
	Kit.block(parent, ground * CFrame.new(0.9, h + 0.7, 0), Vector3.new(2.2, 0.28, 0.28), M.Metal, IRON)
	Kit.ball(parent, (ground * CFrame.new(0, h + 1.2, 0)).Position, 0.4, M.Foil, GOLD)
	return Props.lantern(parent, (ground * CFrame.new(1.8, h + 0.55, 0)).Position, glow, withLight)
end

-- Broadleaf tree: two-piece trunk with a branch and a terrain canopy.
function Props.tree(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	scale: number,
	leaf: Enum.Material,
	bark: Color3?
)
	local trunkColor = bark or Color3.fromRGB(112, 80, 54)
	local base = CFrame.new(ground + Vector3.new(0, -0.6, 0))
		* CFrame.Angles(rng:NextNumber(-0.07, 0.07), rng:NextNumber(0, TAU), rng:NextNumber(-0.07, 0.07))
	local lower = 7 * scale
	Kit.cylinder(parent, base * CFrame.new(0, lower / 2, 0), lower + 0.6, 1.25 * scale, M.Wood, trunkColor, "Solid")
	local bend = base
		* CFrame.new(0, lower, 0)
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
	local upper = 6 * scale
	Kit.cylinder(
		parent,
		bend * CFrame.new(0, upper / 2, 0),
		upper + 0.5,
		0.95 * scale,
		M.Wood,
		Kit.tint(trunkColor, 0.05),
		"Solid"
	)
	local branch = base
		* CFrame.new(0, lower * 0.85, 0)
		* CFrame.Angles(0, rng:NextNumber(0, TAU), 0.85)
		* CFrame.new(0, 2.4 * scale, 0)
	Kit.cylinder(parent, branch, 4.8 * scale, 0.45 * scale, M.Wood, trunkColor)
	local crown = (bend * CFrame.new(0, upper, 0)).Position
	Land.ball(crown + Vector3.new(0, 1.5 * scale, 0), 6.2 * scale, leaf)
	Land.ball(
		crown + Vector3.new(rng:NextNumber(-3, 3) * scale, -0.8 * scale, rng:NextNumber(-3, 3) * scale),
		4.8 * scale,
		leaf
	)
	Land.ball((branch * CFrame.new(0, 2.6 * scale, 0)).Position, 3.8 * scale, leaf)
end

-- Tiered pine, optionally snow-capped.
function Props.pine(parent: Instance, ground: Vector3, rng: Random, scale: number, snowy: boolean)
	local needles = Kit.vary(Color3.fromRGB(46, 92, 70), rng, 0.1)
	local trunkHeight = 4 * scale
	Kit.cylinder(
		parent,
		CFrame.new(ground + Vector3.new(0, trunkHeight / 2 - 0.5, 0)),
		trunkHeight + 1,
		0.75 * scale,
		M.Wood,
		Color3.fromRGB(94, 66, 48),
		"Solid"
	)
	local y = ground.Y + trunkHeight - 0.6
	for tier = 1, 4 do
		local radius = (5.4 - tier * 1.05) * scale
		local height = 3.2 * scale
		local cf = CFrame.new(ground.X, y + height / 2, ground.Z) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
		Kit.cylinder(parent, cf, height, radius, M.LeafyGrass, Kit.tint(needles, tier * 0.03), if tier == 1 then "Solid" else "Decor")
		if snowy then
			Kit.cylinder(
				parent,
				cf * CFrame.new(0, height / 2 + 0.12, 0),
				0.45,
				radius * 0.82,
				M.Snow,
				Color3.fromRGB(242, 247, 255)
			)
		end
		y += height * 0.68
	end
	Kit.block(
		parent,
		CFrame.new(ground.X, y + 1.1 * scale, ground.Z) * CFrame.Angles(0, math.pi / 4, 0),
		Vector3.new(0.9, 2.4, 0.9) * scale,
		if snowy then M.Snow else M.LeafyGrass,
		if snowy then Color3.fromRGB(242, 247, 255) else needles
	)
end

-- Giant glowing mushroom: fabric stem, stepped neon cap, optional light and drifting spores.
function Props.glowshroom(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	height: number,
	capRadius: number,
	color: Color3,
	withLight: boolean,
	spores: boolean
): Model
	local model = Kit.model("Glowshroom")
	local stemColor = Kit.vary(Color3.fromRGB(196, 214, 204), rng, 0.05)
	local base = CFrame.new(ground + Vector3.new(0, -0.5, 0))
		* CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, TAU), rng:NextNumber(-0.12, 0.12))
	local stemRadius = math.max(capRadius * 0.17, 0.45)
	Kit.cylinder(model, base * CFrame.new(0, height / 2, 0), height, stemRadius, M.Fabric, stemColor, "Solid")
	Kit.cylinder(model, base * CFrame.new(0, 0.7, 0), 1.6, stemRadius * 1.5, M.Fabric, Kit.tint(stemColor, -0.12), "Solid")
	local cap = base * CFrame.new(0, height, 0)
	Kit.cylinder(model, cap * CFrame.new(0, -0.15, 0), 0.6, capRadius * 0.92, M.Fabric, Kit.tint(color, -0.55))
	local rim = Kit.cylinder(model, cap * CFrame.new(0, 0.55, 0), 1.2, capRadius, M.Neon, color)
	Kit.cylinder(model, cap * CFrame.new(0, 1.55, 0), 1, capRadius * 0.72, M.Neon, Kit.tint(color, 0.12))
	Kit.cylinder(model, cap * CFrame.new(0, 2.35, 0), 0.8, capRadius * 0.42, M.Neon, Kit.tint(color, 0.25))
	if withLight then
		Kit.pulse(Kit.light(rim, color, capRadius * 3.6, 2), 0.2, 0.25)
	end
	if spores then
		Kit.emitter(rim, {
			Texture = Kit.Textures.Sparkles,
			Color = Kit.colors(Kit.tint(color, 0.4), color),
			Size = Kit.seq(0.35, 0.5, 0),
			Transparency = Kit.seq(0.3, 0.5, 1),
			Lifetime = Kit.range(4, 7),
			Rate = 8,
			Speed = Kit.range(0.4, 1.2),
			Spread = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -0.3, 0),
			LightEmission = 1,
			LightInfluence = 0,
		})
	end
	return Kit.finishModel(model, parent)
end

-- Ring of segments lying in the pivot's XZ plane (its normal is pivot.UpVector), optionally spinning.
function Props.ring(
	parent: Instance,
	pivot: CFrame,
	radius: number,
	segments: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	spin: number?
): Model
	local model = Kit.model("Ring")
	local length = TAU * radius / segments * 1.05
	for index = 0, segments - 1 do
		local angle = index / segments * TAU
		Kit.block(
			model,
			pivot * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius) * CFrame.Angles(0, -(angle + math.pi / 2), 0),
			Vector3.new(length, thickness, thickness),
			material,
			color
		)
	end
	model.WorldPivot = pivot
	if spin then
		Kit.spin(model, spin)
	end
	return Kit.finishModel(model, parent, nil, true)
end

-- Floating faceted gem (a cube balanced on its corner) with a neon heart.
function Props.gem(
	parent: Instance,
	center: Vector3,
	size: number,
	color: Color3,
	spin: number,
	bob: number,
	withLight: boolean
): Model
	local model = Kit.model("FloatingGem")
	local corner = CFrame.new(center) * CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local shell = Kit.block(model, corner, Vector3.new(size, size, size), M.Glass, color)
	shell.Transparency = 0.25
	shell.Reflectance = 0.2
	local core = Kit.block(model, corner, Vector3.new(size, size, size) * 0.5, M.Neon, Kit.tint(color, 0.2))
	if withLight then
		Kit.light(core, color, size * 4, 1.6)
	end
	model.WorldPivot = CFrame.new(center)
	Kit.spin(model, spin)
	if bob > 0 then
		Kit.bob(model, bob, 0.16)
	end
	return Kit.finishModel(model, parent, nil, true)
end

-- Tall prism with a ridged tip (ice spikes, obsidian spires).
function Props.spike(
	parent: Instance,
	ground: Vector3,
	height: number,
	width: number,
	material: Enum.Material,
	color: Color3,
	rng: Random,
	transparency: number?
): Part
	local base = CFrame.new(ground + Vector3.new(0, -1, 0))
		* CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(0, TAU), rng:NextNumber(-0.18, 0.18))
	return Props.shard(parent, base, width, height + 1, material, color, "Solid", transparency or 0)
end

-- Classical column; broken ones are shorter and leave a fallen drum beside them.
function Props.column(
	parent: Instance,
	ground: Vector3,
	height: number,
	radius: number,
	stone: Surface,
	trim: Surface,
	rng: Random,
	broken: boolean
)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	Props.surface(parent, CFrame.new(ground + Vector3.new(0, 0.6, 0)) * yaw, Vector3.new(radius * 2.7, 1.2, radius * 2.7), trim, "Solid")
	local shaftHeight = if broken then height * rng:NextNumber(0.3, 0.65) else height - 2.2
	local shaftFrame = CFrame.new(ground + Vector3.new(0, 1.2 + shaftHeight / 2, 0))
	if broken then
		shaftFrame *= CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
	end
	local shaft = Kit.cylinder(parent, shaftFrame, shaftHeight, radius, stone.Material, Kit.vary(stone.Color, rng, 0.04), "Solid")
	Props.paint(shaft, stone)
	if broken then
		local drum = Kit.rod(
			parent,
			CFrame.new(ground + Vector3.new(radius * 3.2, radius, rng:NextNumber(-2, 2))) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			height * 0.28,
			radius,
			stone.Material,
			stone.Color,
			"Solid"
		)
		Props.paint(drum, stone)
	else
		Props.surface(parent, CFrame.new(ground + Vector3.new(0, height - 0.5, 0)) * yaw, Vector3.new(radius * 2.9, 1, radius * 2.9), trim, "Solid")
		Props.surface(parent, CFrame.new(ground + Vector3.new(0, height - 1.4, 0)), Vector3.new(radius * 2.2, 0.5, radius * 2.2), trim)
	end
end

-- Stone arch spanning ground's local X. `missing` interior stones are knocked out and lie on the ground.
function Props.archway(
	parent: Instance,
	ground: CFrame,
	span: number,
	pillarHeight: number,
	stone: Surface,
	trim: Surface,
	rng: Random,
	missing: number
)
	local half = span / 2
	for side = -1, 1, 2 do
		Props.surface(parent, ground * CFrame.new(side * half, pillarHeight / 2, 0), Vector3.new(3, pillarHeight, 3), stone, "Solid")
		Props.surface(parent, ground * CFrame.new(side * half, 0.6, 0), Vector3.new(4.2, 1.2, 4.2), trim, "Solid")
		Props.surface(parent, ground * CFrame.new(side * half, pillarHeight - 0.4, 0), Vector3.new(4, 0.8, 4), trim, "Solid")
	end
	local pieces = 9
	local skip: { [number]: boolean } = {}
	for _ = 1, missing do
		skip[rng:NextInteger(2, pieces - 3)] = true
	end
	local center = ground * CFrame.new(0, pillarHeight, 0)
	local length = math.pi * half / (pieces - 1) * 1.1
	for index = 0, pieces - 1 do
		if not skip[index] then
			local phi = math.pi * index / (pieces - 1)
			Props.surface(
				parent,
				center * CFrame.new(math.cos(phi) * half, math.sin(phi) * half, 0) * CFrame.Angles(0, 0, phi + math.pi / 2),
				Vector3.new(length, 2.6, 2.8),
				stone,
				"Solid"
			)
		end
	end
	for _ = 1, missing do
		Props.surface(
			parent,
			ground
				* CFrame.new(rng:NextNumber(-half, half), 1, rng:NextNumber(2.5, 5))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
			Vector3.new(length, 2.2, 2.6),
			stone,
			"Solid"
		)
	end
end

function Props.crate(parent: Instance, cf: CFrame, size: number, color: Color3)
	Kit.block(parent, cf, Vector3.new(size, size, size), M.WoodPlanks, color, "Solid")
	Kit.block(parent, cf, Vector3.new(size + 0.14, size * 0.2, size + 0.14), M.Wood, Kit.tint(color, -0.3))
end

function Props.barrel(parent: Instance, ground: Vector3, color: Color3)
	Kit.cylinder(parent, CFrame.new(ground + Vector3.new(0, 1.5, 0)), 3, 1.15, M.Wood, color, "Solid")
	for _, y in { 0.6, 2.4 } do
		Kit.cylinder(parent, CFrame.new(ground + Vector3.new(0, y, 0)), 0.25, 1.22, M.Metal, IRON)
	end
end

-- Fabric banner on a pole; the cloth faces ground.LookVector.
function Props.banner(parent: Instance, ground: CFrame, color: Color3, height: number)
	Kit.cylinder(parent, ground * CFrame.new(0, height / 2, 0), height, 0.28, M.Wood, WOOD, "Solid")
	Kit.rod(parent, ground * CFrame.new(0, height - 0.6, 0), 4.2, 0.18, M.Wood, WOOD)
	local clothHeight = height * 0.44
	local cloth = ground * CFrame.new(0, height - 0.8 - clothHeight / 2, -0.35)
	Kit.block(parent, cloth, Vector3.new(3.6, clothHeight, 0.12), M.Fabric, color)
	Kit.block(
		parent,
		cloth * CFrame.new(0, clothHeight * 0.12, -0.1) * CFrame.Angles(0, 0, math.pi / 4),
		Vector3.new(1.1, 1.1, 0.06),
		M.Neon,
		Kit.tint(color, 0.4)
	)
	Kit.ball(parent, (ground * CFrame.new(0, height + 0.3, 0)).Position, 0.45, M.Foil, GOLD)
end

function Props.campfire(parent: Instance, ground: Vector3, rng: Random, flame: Color3?)
	local model = Kit.model("Campfire")
	local fireColor = flame or Color3.fromRGB(255, 150, 70)
	for index = 1, 7 do
		local angle = index / 7 * TAU
		Kit.block(
			model,
			CFrame.new(ground + Vector3.new(math.cos(angle) * 2, 0.3, math.sin(angle) * 2)) * CFrame.Angles(0, -angle, 0),
			Vector3.new(0.9, 0.7, 1.2),
			M.Slate,
			Kit.vary(Color3.fromRGB(96, 92, 98), rng, 0.1)
		)
	end
	for index = 1, 2 do
		Kit.rod(
			model,
			CFrame.new(ground + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, index * math.pi / 2 + 0.3, 0.12),
			3.2,
			0.3,
			M.Wood,
			Color3.fromRGB(82, 56, 40)
		)
	end
	local heart = Kit.block(model, CFrame.new(ground + Vector3.new(0, 0.7, 0)), Vector3.new(1, 0.6, 1), M.Neon, fireColor)
	Kit.fire(heart, 4, 7, fireColor, Kit.tint(fireColor, -0.4))
	Kit.pulse(Kit.light(heart, fireColor, 18, 1.8), 1.3, 0.25)
	Kit.finishModel(model, parent)
end

function Props.anvil(parent: Instance, ground: CFrame)
	Kit.cylinder(parent, ground * CFrame.new(0, 1.2, 0), 2.4, 1.3, M.Wood, Color3.fromRGB(96, 66, 44), "Solid")
	Kit.block(parent, ground * CFrame.new(0, 2.8, 0), Vector3.new(1.2, 0.8, 1.6), M.Metal, IRON, "Solid")
	Kit.block(parent, ground * CFrame.new(0, 3.6, 0), Vector3.new(1.6, 0.9, 3.2), M.Metal, IRON, "Solid")
	Kit.wedge(parent, ground * CFrame.new(0, 3.6, -2.3), Vector3.new(1.2, 0.9, 1.4), M.Metal, IRON, "Solid")
end

-- Sheet waterfall pouring off a cliff lip into the void, with spray at the top and mist where it fades.
function Props.waterfall(parent: Instance, options: FallOptions): Model
	local model = Kit.model("Waterfall")
	local material = options.Material or M.Glass
	local segments = 5
	local segment = options.Drop / segments
	local foam = Kit.tint(options.Color, 0.55)
	for index = 1, segments do
		local outward = 1.4 + (index - 1) * 1.2
		local middle = options.Lip + options.Out * outward - Vector3.new(0, segment * (index - 0.5), 0)
		local cf = CFrame.lookAt(middle, middle + options.Out)
		local width = options.Width * (1 - (index - 1) * 0.05)
		local fade = (index - 1) / (segments - 1)
		local sheet = Kit.block(model, cf, Vector3.new(width, segment + 0.8, 0.7), material, options.Color)
		sheet.Transparency = 0.2 + fade * 0.6
		if material == M.Glass then
			sheet.Reflectance = 0.12
		end
		local streak = Kit.block(model, cf * CFrame.new(0, 0, -0.45), Vector3.new(width * 0.4, segment + 0.8, 0.3), material, foam)
		streak.Transparency = 0.35 + fade * 0.55
	end
	local lipCenter = options.Lip + options.Out * 1.2
	local lip = Kit.block(model, CFrame.lookAt(lipCenter, lipCenter + options.Out), Vector3.new(options.Width, 0.8, 1.2), material, foam)
	lip.Transparency = 0.3
	Kit.emitter(lip, {
		Texture = options.Spray or Kit.Textures.Smoke,
		Color = Kit.colors(foam),
		Size = Kit.seq(2.5, 6, 9),
		Transparency = Kit.seq(0.35, 0.6, 1),
		Lifetime = Kit.range(1.6, 2.6),
		Rate = 22,
		Speed = Kit.range(8, 14),
		Spread = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, -50, 0),
		Direction = Enum.NormalId.Bottom,
		LightEmission = if material == M.Neon then 1 else 0,
		Drag = 0.6,
	})
	local mistCenter = options.Lip + options.Out * (1.4 + segments * 1.2) - Vector3.new(0, options.Drop - 4, 0)
	local mist = Kit.block(model, CFrame.lookAt(mistCenter, mistCenter + options.Out), Vector3.new(options.Width, 2, 4), M.Glass, foam, "Ghost")
	Kit.emitter(mist, {
		Texture = Kit.Textures.Smoke,
		Color = Kit.colors(options.Mist or Color3.new(1, 1, 1)),
		Size = Kit.seq(8, 18, 26),
		Transparency = Kit.seq(0.55, 0.8, 1),
		Lifetime = Kit.range(3, 5),
		Rate = 7,
		Speed = Kit.range(2, 5),
		Spread = Vector2.new(180, 180),
		Drag = 1,
	})
	return Kit.finishModel(model, parent)
end

-- Gently sagging plank bridge with posts, rails, rope and hanging lanterns between two deck-level points.
function Props.bridge(parent: Instance, from: Vector3, to: Vector3, options: BridgeOptions): Model
	local model = Kit.model("Bridge")
	local rng = Random.new(options.Seed or 7)
	local width = options.Width or 14
	local sag = options.Sag or 3.5
	local frame = options.Frame or Color3.fromRGB(96, 66, 46)
	local rope = options.Rope or Color3.fromRGB(150, 120, 84)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local forward = flat.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local rise = to.Y - from.Y

	local function pointAt(t: number): Vector3
		return from:Lerp(to, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local function tangentAt(t: number): Vector3
		return (forward + Vector3.new(0, (rise - sag * 4 * (1 - 2 * t)) / length, 0)).Unit
	end

	local planks = math.max(math.floor(length / 2.6), 2)
	local plankLength = length / planks - 0.25
	for index = 0, planks - 1 do
		local t = (index + 0.5) / planks
		local center = pointAt(t) - Vector3.new(0, 0.45, 0)
		local plank = Kit.block(
			model,
			CFrame.lookAt(center, center + tangentAt(t)) * CFrame.Angles(0, 0, rng:NextNumber(-0.012, 0.012)),
			Vector3.new(width + rng:NextNumber(-0.4, 0.4), 0.9, plankLength),
			M.WoodPlanks,
			Kit.vary(options.Plank, rng, 0.08),
			"Walk"
		)
		if options.Variant then
			Kit.variant(plank, options.Variant)
		end
	end

	local segments = math.max(math.round(length / 10), 2)
	local tops: { { Vector3 } } = { {}, {} }
	local ropes: { { Attachment } } = { {}, {} }
	for index = 0, segments do
		local deck = pointAt(index / segments)
		for side = 1, 2 do
			local sign = if side == 1 then 1 else -1
			local foot = deck + right * sign * (width / 2 + 0.25)
			local center = foot + Vector3.new(0, 1.4, 0)
			local post = Kit.block(model, CFrame.lookAt(center, center + forward), Vector3.new(0.9, 5.6, 0.9), M.Wood, frame, "Solid")
			local attachment = Instance.new("Attachment")
			attachment.Name = "Rope"
			attachment.CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, -math.pi / 2)
			attachment.Parent = post
			table.insert(ropes[side], attachment)
			table.insert(tops[side], foot + Vector3.new(0, 3.6, 0))
		end
	end
	for side = 1, 2 do
		local sign = if side == 1 then 1 else -1
		for index = 1, segments do
			local a, b = tops[side][index], tops[side][index + 1]
			Kit.block(model, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.45, 0.45, (b - a).Magnitude + 0.5), M.Wood, Kit.tint(frame, 0.08), "Solid")
			local beam = Instance.new("Beam")
			beam.Attachment0 = ropes[side][index]
			beam.Attachment1 = ropes[side][index + 1]
			beam.CurveSize0 = 0.9
			beam.CurveSize1 = -0.9
			beam.Width0 = 0.22
			beam.Width1 = 0.22
			beam.FaceCamera = true
			beam.Segments = 8
			beam.Color = ColorSequence.new(rope)
			beam.Transparency = NumberSequence.new(0)
			beam.Parent = model
			local p0 = pointAt((index - 1) / segments) + right * sign * (width / 2 - 1) - Vector3.new(0, 1.3, 0)
			local p1 = pointAt(index / segments) + right * sign * (width / 2 - 1) - Vector3.new(0, 1.3, 0)
			Kit.block(model, CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.8, 1, (p1 - p0).Magnitude + 0.4), M.Wood, Kit.tint(frame, -0.1))
		end
	end

	local lit = 0
	for pick, fraction in { 0.25, 0.5, 0.75 } do
		local index = math.clamp(math.round(segments * fraction), 1, segments - 1)
		local side = if pick % 2 == 0 then 2 else 1
		local sign = if side == 1 then 1 else -1
		local armCenter = tops[side][index + 1] + Vector3.new(0, 0.9, 0) + right * sign
		Kit.block(model, CFrame.lookAt(armCenter, armCenter + right * sign), Vector3.new(0.35, 0.35, 2.4), M.Wood, frame)
		lit += 1
		Props.lantern(model, armCenter + right * sign, options.Glow, lit <= (options.Lights or 2))
	end
	return Kit.finishModel(model, parent)
end

-- Stone post topped with a small glowing crystal (bridge landings, path edges).
function Props.marker(parent: Instance, ground: Vector3, stone: Surface, glow: Color3, height: number?)
	local h = height or 4
	Props.surface(parent, CFrame.new(ground + Vector3.new(0, h / 2 - 0.3, 0)), Vector3.new(1.6, h + 0.6, 1.6), stone, "Solid")
	Kit.block(
		parent,
		CFrame.new(ground + Vector3.new(0, h + 0.9, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		Vector3.new(0.9, 1.8, 0.9),
		M.Neon,
		glow
	)
end

return Props
