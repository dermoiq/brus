--!strict
-- The hub island at the origin: cobblestone plaza and fountain, the spawn, the Upgrade Station, Robux Store
-- and Rebirth Altar, the portal hub, the grand arch towards the bridge, and grassy scenery around it.
-- Players spawn facing +Z (towards the bridge to the first zone).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local Kit = require(script.Parent.Kit)
local Land = require(script.Parent.Land)
local Placer = require(script.Parent.Placer)
local Props = require(script.Parent.Props)
local Types = require(script.Parent.Types)

local M = Enum.Material
local TAU = math.pi * 2
local RADIUS = 104

local LAVENDER = Color3.fromRGB(196, 150, 255)
local WARM = Color3.fromRGB(255, 196, 120)
local GOLD = Color3.fromRGB(240, 196, 92)
local WATER = Color3.fromRGB(90, 190, 255)
local MARBLE: Types.Surface = { Material = M.Marble, Color = Color3.fromRGB(236, 230, 244) }
local SLATE: Types.Surface = { Material = M.Slate, Color = Color3.fromRGB(84, 78, 98) }
local COBBLE: Types.Surface = { Material = M.Cobblestone, Color = Color3.fromRGB(156, 146, 160), Variant = "Lobby_Cobble" }
local FOIL: Types.Surface = { Material = M.Foil, Color = GOLD }
local BRASS: Types.Surface = { Material = M.Metal, Color = Color3.fromRGB(214, 166, 82), Variant = "Lobby_Brass" }

local Lobby = {
	Radius = RADIUS,
	NorthTip = RADIUS,
	Glow = LAVENDER,
}

local function polar(radius: number, degrees: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function facing(position: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

local function planks(color: Color3): Types.Surface
	return { Material = M.WoodPlanks, Color = color, Variant = "Lobby_WoodPlanks" }
end

local function terrain(rng: Random)
	Land.island(Vector3.zero, RADIUS, {
		Top = M.Grass,
		Cliff = M.Rock,
		Strata = M.Ground,
		Under = M.Rock,
		Deep = M.Rock,
	}, rng, { Vector3.new(-98, 0, -36) })
	Land.disc(0, 0, 68, -4, 0, M.Cobblestone)
	Land.strip(Vector3.new(0, 0, 60), Vector3.new(0, 0, 100), 12, -4, 0, M.Cobblestone)
	-- Grassy hills behind the spawn.
	Land.ball(Vector3.new(66, -16, -62), 26, M.Grass)
	Land.ball(Vector3.new(-60, -18, -68), 27, M.Grass)
	for _, rock in { Vector3.new(80, -2, -44), Vector3.new(50, -1, -78), Vector3.new(-80, -2, -52), Vector3.new(-44, -2, -84) } do
		Land.ball(rock, rng:NextNumber(4, 6), M.Rock)
	end
end

local function plaza(scenery: Instance)
	local disc = Kit.cylinder(scenery, CFrame.new(0, -0.3, 0), 1, 40, M.Cobblestone, COBBLE.Color, "Walk")
	disc.Name = "Plaza"
	Props.paint(disc, COBBLE)
	Kit.cylinder(scenery, CFrame.new(0, -0.4, 0), 1, 42, SLATE.Material, SLATE.Color, "Walk").Name = "PlazaBorder"
	-- Marble inlay ring around the fountain.
	Kit.cylinder(scenery, CFrame.new(0, 0.23, 0), 0.06, 25.2, M.Marble, MARBLE.Color, "Walk")
	local inner = Kit.cylinder(scenery, CFrame.new(0, 0.24, 0), 0.08, 24, M.Cobblestone, Kit.tint(COBBLE.Color, -0.08), "Walk")
	Props.paint(inner, COBBLE)
end

local function spawnPad(lobby: Model, scenery: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	-- A SpawnLocation's front is -Z; turned around so players face +Z.
	spawn.CFrame = CFrame.new(0, 0.7, -28) * CFrame.Angles(0, math.pi, 0)
	spawn.Material = M.Marble
	spawn.Color = MARBLE.Color
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
	Kit.Stats.Parts += 1
	for side = -1, 1, 2 do
		Kit.block(scenery, CFrame.new(side * 5.25, 0.45, -28), Vector3.new(0.5, 0.5, 11), M.Neon, LAVENDER)
		Kit.block(scenery, CFrame.new(0, 0.45, -28 + side * 5.25), Vector3.new(10, 0.5, 0.5), M.Neon, LAVENDER)
	end
	for _, corner in { Vector3.new(7, 0.2, -21), Vector3.new(-7, 0.2, -21), Vector3.new(7, 0.2, -35), Vector3.new(-7, 0.2, -35) } do
		Props.marker(scenery, corner, MARBLE, LAVENDER, 3)
	end
end

local function fountain(scenery: Instance, rng: Random)
	local model = Kit.model("Fountain")
	Kit.cylinder(model, CFrame.new(0, 0.78, 0), 1, 11, M.Marble, MARBLE.Color, "Walk")
	for index = 0, 15 do
		local angle = index / 16 * TAU
		Kit.block(
			model,
			CFrame.new(math.cos(angle) * 10.4, 1.48, math.sin(angle) * 10.4) * CFrame.Angles(0, -(angle + math.pi / 2), 0),
			Vector3.new(4.4, 2.4, 1.4),
			M.Marble,
			Kit.tint(MARBLE.Color, -0.04),
			"Solid"
		)
	end
	local pool = Kit.cylinder(model, CFrame.new(0, 1.75, 0), 0.5, 9.9, M.Glass, WATER)
	pool.Transparency = 0.35
	pool.Reflectance = 0.2
	Kit.cylinder(model, CFrame.new(0, 3.9, 0), 5, 2.2, M.Marble, MARBLE.Color, "Solid")
	Kit.cylinder(model, CFrame.new(0, 6.8, 0), 0.8, 5, M.Marble, MARBLE.Color, "Solid")
	for index = 0, 9 do
		local angle = index / 10 * TAU
		Kit.block(
			model,
			CFrame.new(math.cos(angle) * 4.8, 7.5, math.sin(angle) * 4.8) * CFrame.Angles(0, -(angle + math.pi / 2), 0),
			Vector3.new(3.3, 0.7, 0.6),
			M.Marble,
			MARBLE.Color
		)
	end
	local upper = Kit.cylinder(model, CFrame.new(0, 7.35, 0), 0.3, 4.5, M.Glass, WATER)
	upper.Transparency = 0.3
	upper.Reflectance = 0.2
	Kit.cylinder(model, CFrame.new(0, 8.9, 0), 3, 0.9, M.Marble, MARBLE.Color, "Solid")
	local spout = Kit.cylinder(model, CFrame.new(0, 10.6, 0), 0.4, 1.4, M.Foil, GOLD)
	Kit.emitter(spout, {
		Texture = Kit.Textures.Smoke,
		Color = Kit.colors(Color3.fromRGB(220, 240, 255)),
		Size = Kit.seq(0.5, 1.1, 1.6),
		Transparency = Kit.seq(0.25, 0.5, 1),
		Lifetime = Kit.range(1, 1.4),
		Rate = 40,
		Speed = Kit.range(9, 12),
		Spread = Vector2.new(22, 22),
		Acceleration = Vector3.new(0, -32, 0),
		-- Upright cylinders point their local X (Right face) at the sky.
		Direction = Enum.NormalId.Right,
	})
	local overflow = Kit.block(model, CFrame.new(0, 6.3, 0), Vector3.new(9.4, 0.2, 9.4), M.Glass, WATER, "Ghost")
	Kit.emitter(overflow, {
		Texture = Kit.Textures.Smoke,
		Color = Kit.colors(Color3.fromRGB(200, 232, 255)),
		Size = Kit.seq(0.4, 0.8),
		Transparency = Kit.seq(0.4, 0.7, 1),
		Lifetime = Kit.range(0.5, 0.7),
		Rate = 30,
		Speed = Kit.range(2, 4),
		Direction = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(0, -20, 0),
	})

	local crystal = Kit.model("FountainCrystal")
	local center = CFrame.new(0, 15, 0)
	Kit.block(crystal, center * CFrame.Angles(0, math.pi / 4, 0), Vector3.new(1.8, 5.4, 1.8), M.Glass, LAVENDER).Transparency =
		0.25
	for side = -1, 1, 2 do
		local shard = Kit.block(
			crystal,
			center * CFrame.new(side * 1.3, -0.8, 0) * CFrame.Angles(0, 0, -side * 0.45),
			Vector3.new(1.1, 3.2, 1.1),
			M.Glass,
			Kit.vary(LAVENDER, rng, 0.1)
		)
		shard.Transparency = 0.25
	end
	local core = Kit.block(crystal, center, Vector3.new(0.8, 3.6, 0.8), M.Neon, Kit.tint(LAVENDER, 0.25))
	Kit.light(core, LAVENDER, 26, 2)
	crystal.WorldPivot = center
	Kit.spin(crystal, 30)
	Kit.bob(crystal, 0.8, 0.2)
	Kit.finishModel(crystal, model, nil, true)
	Kit.finishModel(model, scenery)
end

local function upgradeStation(lobby: Model, origin: CFrame)
	local model = Kit.model("UpgradeStation")
	local wood = Color3.fromRGB(128, 88, 58)
	local dark = Color3.fromRGB(86, 58, 40)
	local floor = Props.surface(model, origin * CFrame.new(0, 0.3, 1), Vector3.new(16, 0.6, 12), planks(wood), "Walk")
	floor.Name = "Base"
	local counter = Props.surface(model, origin * CFrame.new(0, 2.2, -3.4), Vector3.new(11, 3.2, 2.6), planks(dark), "Solid")
	counter.Name = "Counter"
	Props.surface(model, origin * CFrame.new(0, 3.95, -3.4), Vector3.new(11.6, 0.3, 3.2), BRASS, "Solid")
	local prompt = Kit.prompt(counter, "Open Shop", "Upgrade Station", 0, 12)
	prompt:SetAttribute("OpensShop", true)

	for _, x in { -7.2, 7.2 } do
		for _, z in { -4.6, 6.4 } do
			Kit.block(model, origin * CFrame.new(x, 5.9, z), Vector3.new(0.8, 11, 0.8), M.Wood, dark, "Solid")
		end
	end
	local stripes = { Color3.fromRGB(150, 92, 220), Color3.fromRGB(255, 206, 110) }
	for index = 0, 3 do
		Kit.block(
			model,
			origin * CFrame.new(-6 + index * 4, 11.4, 0.9) * CFrame.Angles(-0.19, 0, 0),
			Vector3.new(4.05, 0.3, 12.6),
			M.Fabric,
			stripes[index % 2 + 1]
		)
	end
	Kit.block(model, origin * CFrame.new(0, 10, -5.2), Vector3.new(16.4, 1.2, 0.2), M.Fabric, stripes[2])
	Props.surface(model, origin * CFrame.new(0, 4.8, 6.6), Vector3.new(14.4, 9, 0.6), planks(wood), "Solid")
	for side = -1, 1, 2 do
		local tool = origin * CFrame.new(side * 3.5, 5.4, 6.1) * CFrame.Angles(0, 0, side * 0.6)
		Kit.block(model, tool, Vector3.new(0.35, 4.6, 0.35), M.Wood, wood)
		Kit.block(model, tool * CFrame.new(0, 2.1, 0), Vector3.new(3.2, 0.5, 0.4), M.Metal, Color3.fromRGB(160, 162, 172))
	end
	Props.anvil(model, origin * CFrame.new(-4.4, 0.6, 2.4) * CFrame.Angles(0, 0.4, 0))
	Props.barrel(model, (origin * CFrame.new(9.8, 0, 4.6)).Position, wood)
	Props.crate(model, origin * CFrame.new(9.6, 1.25, 1.2) * CFrame.Angles(0, 0.3, 0), 2.5, wood)
	Props.crate(model, origin * CFrame.new(9.7, 3.4, 1.3) * CFrame.Angles(0, -0.2, 0), 1.8, Kit.tint(wood, 0.1))

	local display = Kit.model("PickaxeDisplay")
	local pivot = origin * CFrame.new(0, 7.6, -3.4)
	local handle = pivot * CFrame.Angles(0, 0, 0.5)
	Kit.block(display, handle, Vector3.new(0.35, 4.6, 0.35), M.Wood, wood)
	local head = handle * CFrame.new(0, 2.1, 0)
	local steel = Color3.fromRGB(196, 202, 216)
	Kit.block(display, head, Vector3.new(2.6, 0.55, 0.5), M.Metal, steel)
	Kit.wedge(display, head * CFrame.new(-1.9, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.5, 0.55, 1.2), M.Metal, steel)
	Kit.wedge(display, head * CFrame.new(1.9, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(0.5, 0.55, 1.2), M.Metal, steel)
	Kit.block(display, head * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.62, 0.62, 0.64), M.Neon, LAVENDER)
	display.WorldPivot = pivot
	Kit.spin(display, 40)
	Kit.bob(display, 0.5, 0.3)
	Kit.finishModel(display, model, nil, true)

	Props.lantern(model, (origin * CFrame.new(-6.4, 10.6, -5.4)).Position, WARM, true)
	local board = Props.surface(model, origin * CFrame.new(0, 13.4, -5.4), Vector3.new(10, 2.6, 0.4), planks(dark), "Solid")
	Kit.surfaceText(board, Enum.NormalId.Front, "UPGRADES", Color3.fromRGB(255, 222, 130))
	Kit.billboard(board, "⚒ UPGRADES", Color3.fromRGB(255, 222, 130), 5, 14, 140)
	Kit.finishModel(model, lobby, floor)
end

local function treasureChest(parent: Instance, ground: CFrame, glow: Color3, rng: Random)
	local wood = Color3.fromRGB(122, 74, 46)
	Kit.block(parent, ground * CFrame.new(0, 1.1, 0), Vector3.new(3.6, 2.2, 2.4), M.WoodPlanks, wood, "Solid")
	Kit.block(
		parent,
		ground * CFrame.new(0, 2.2, 1.2) * CFrame.Angles(1.9, 0, 0) * CFrame.new(0, 0.25, -1.2),
		Vector3.new(3.6, 0.5, 2.4),
		M.WoodPlanks,
		wood,
		"Solid"
	)
	for _, x in { -1.2, 1.2 } do
		Kit.block(parent, ground * CFrame.new(x, 1.1, 0), Vector3.new(0.3, 2.3, 2.5), M.Foil, GOLD)
	end
	for index = 1, 4 do
		Kit.block(
			parent,
			ground
				* CFrame.new(-1.2 + (index - 1) * 0.8, 2.35, rng:NextNumber(-0.5, 0.5))
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), rng:NextNumber(0, 1)),
			Vector3.new(0.7, 0.7, 0.7),
			M.Neon,
			if index % 2 == 0 then GOLD else glow
		)
	end
end

local function storeStation(lobby: Model, origin: CFrame, rng: Random)
	local model = Kit.model("StoreStation")
	local green = Color3.fromRGB(70, 255, 140)
	local floor = Props.surface(model, origin * CFrame.new(0, 0.3, 1), Vector3.new(16, 0.6, 12), MARBLE, "Walk")
	floor.Name = "Base"
	Props.surface(model, origin * CFrame.new(0, 0.35, -5.1), Vector3.new(16.2, 0.5, 0.3), FOIL)
	Kit.block(model, origin * CFrame.new(0, 0.12, -5.35), Vector3.new(16.2, 0.2, 0.2), M.Neon, green)
	local counter = Props.surface(model, origin * CFrame.new(0, 2.2, -3.4), Vector3.new(11, 3.2, 2.6), MARBLE, "Solid")
	counter.Name = "Counter"
	Props.surface(model, origin * CFrame.new(0, 3.95, -3.4), Vector3.new(11.6, 0.3, 3.2), FOIL, "Solid")
	Kit.block(model, origin * CFrame.new(0, 2.2, -4.75), Vector3.new(11.2, 0.25, 0.1), M.Neon, green)
	local prompt = Kit.prompt(counter, "Open Store", "Robux Store", 0, 12)
	prompt:SetAttribute("OpensStore", true)

	for _, x in { -7, 7 } do
		Kit.cylinder(model, origin * CFrame.new(x, 5.9, -4.6), 10.6, 0.75, M.Foil, GOLD, "Solid")
		Kit.cylinder(model, origin * CFrame.new(x, 5.9, 6.2), 10.6, 0.75, M.Marble, MARBLE.Color, "Solid")
	end
	Props.surface(model, origin * CFrame.new(0, 11.6, 0.8), Vector3.new(17, 0.9, 13), MARBLE, "Solid")
	Props.surface(model, origin * CFrame.new(0, 11.6, 0.8), Vector3.new(17.4, 0.4, 13.4), FOIL)
	Kit.block(model, origin * CFrame.new(0, 11.05, -5.8), Vector3.new(17.4, 0.2, 0.2), M.Neon, green)
	Props.surface(model, origin * CFrame.new(0, 4.8, 6.6), Vector3.new(13.4, 9, 0.6), MARBLE, "Solid")
	Kit.block(model, origin * CFrame.new(0, 4.8, 6.25), Vector3.new(9, 0.3, 0.1), M.Neon, green)
	Kit.block(model, origin * CFrame.new(0, 7.2, 6.25), Vector3.new(9, 0.3, 0.1), M.Neon, GOLD)
	local board = Props.surface(model, origin * CFrame.new(0, 13.6, -5.2), Vector3.new(11, 3, 0.5), MARBLE, "Solid")
	Props.surface(model, origin * CFrame.new(0, 13.6, -5.15), Vector3.new(11.6, 3.6, 0.3), FOIL)
	Kit.surfaceText(board, Enum.NormalId.Front, "ROBUX STORE", green)
	Kit.billboard(board, "💎 ROBUX STORE", green, 5.5, 16, 140)

	local gem = Props.gem(model, (origin * CFrame.new(0, 18, 0.8)).Position, 3.2, green, 50, 0.8, true)
	local sparkle = Kit.block(gem, CFrame.new((origin * CFrame.new(0, 18, 0.8)).Position), Vector3.new(4, 4, 4), M.Glass, green, "Ghost")
	Kit.emitter(sparkle, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(GOLD, green),
		Size = Kit.seq(0.7, 0.4, 0),
		Transparency = Kit.seq(0, 0.3, 1),
		Lifetime = Kit.range(1.2, 2),
		Rate = 12,
		Speed = Kit.range(1, 3),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
		LightInfluence = 0,
	})
	treasureChest(model, origin * CFrame.new(-5.6, 0.6, 2) * CFrame.Angles(0, 0.35, 0), green, rng)
	for index = 1, 3 do
		Kit.cylinder(
			model,
			origin * CFrame.new(1.5 + index * 1.3, 4.3 + index * 0.15, -3.3),
			index * 0.3,
			0.5,
			M.Foil,
			GOLD
		)
	end
	Kit.block(model, origin * CFrame.new(0, 0.25, -8.2), Vector3.new(6, 0.1, 5), M.Fabric, Color3.fromRGB(30, 110, 70))
	Kit.finishModel(model, lobby, floor)
end

local function rebirthAltar(lobby: Model, origin: CFrame, rng: Random)
	local model = Kit.model("RebirthAltar")
	local pink = Color3.fromRGB(255, 110, 220)
	local purple = Color3.fromRGB(160, 90, 255)
	local stone = Color3.fromRGB(62, 52, 82)
	Kit.cylinder(model, origin * CFrame.new(0, 0.5, 0), 1, 13, M.Slate, stone, "Walk").Name = "Step1"
	Kit.cylinder(model, origin * CFrame.new(0, 1.5, 0), 1, 10.5, M.Slate, Kit.tint(stone, 0.06), "Walk")
	Kit.cylinder(model, origin * CFrame.new(0, 2.5, 0), 1, 8, M.Slate, Kit.tint(stone, 0.12), "Walk")
	Kit.cylinder(model, origin * CFrame.new(0, 3.03, 0), 0.06, 7.2, M.Neon, pink)
	Kit.cylinder(model, origin * CFrame.new(0, 3.05, 0), 0.1, 6.8, M.Marble, Color3.fromRGB(70, 60, 92), "Walk")

	local altar = Kit.block(model, origin * CFrame.new(0, 4.6, 0), Vector3.new(3.6, 3, 3.6), M.Slate, Color3.fromRGB(40, 32, 56), "Solid")
	altar.Name = "Altar"
	Kit.block(model, origin * CFrame.new(0, 6.35, 0), Vector3.new(4.4, 0.5, 4.4), M.Marble, Color3.fromRGB(226, 214, 246), "Solid")
	for side = -1, 1, 2 do
		Kit.block(model, origin * CFrame.new(0, 4.6, side * 1.83), Vector3.new(2.6, 0.3, 0.06), M.Neon, purple)
		Kit.block(model, origin * CFrame.new(side * 1.83, 4.6, 0), Vector3.new(0.06, 0.3, 2.6), M.Neon, purple)
	end
	local prompt = Kit.prompt(altar, "Rebirth", "Rebirth Altar", 0, 12)
	prompt:SetAttribute("OpensRebirth", true)

	local crystal = Kit.model("RebirthCrystal")
	local center = origin * CFrame.new(0, 11.5, 0)
	Kit.block(crystal, center * CFrame.Angles(0, math.pi / 4, 0), Vector3.new(1.8, 5.5, 1.8), M.Glass, pink).Transparency =
		0.25
	for side = -1, 1, 2 do
		Kit.block(
			crystal,
			center * CFrame.new(side * 1.2, -1, 0.3) * CFrame.Angles(0.2, 0, -side * 0.5),
			Vector3.new(1, 3, 1),
			M.Glass,
			Kit.vary(purple, rng, 0.1)
		).Transparency = 0.25
	end
	local core = Kit.block(crystal, center, Vector3.new(0.8, 3.8, 0.8), M.Neon, Kit.tint(pink, 0.3))
	Kit.pulse(Kit.light(core, purple, 26, 2.4), 0.3, 0.3)
	crystal.WorldPivot = center
	Kit.spin(crystal, 25)
	Kit.bob(crystal, 1, 0.22)
	Kit.finishModel(crystal, model, nil, true)

	Props.ring(model, center * CFrame.Angles(0.45, 0, 0.2), 4.6, 12, 0.35, M.Neon, pink, 45)
	Props.ring(model, center * CFrame.Angles(-0.35, 0.8, -0.5), 5.8, 14, 0.3, M.Neon, purple, -60)
	Props.ring(model, center * CFrame.Angles(0.1, 0, 1.2), 7, 16, 0.25, M.Neon, Color3.fromRGB(255, 190, 245), 30)

	for index = 0, 3 do
		local angle = index / 4 * TAU + math.pi / 4
		local spot = (origin * CFrame.new(math.cos(angle) * 11.6, 0, math.sin(angle) * 11.6)).Position
		local frame = CFrame.lookAt(spot, Vector3.new(origin.Position.X, spot.Y, origin.Position.Z))
		Kit.block(model, frame * CFrame.new(0, 5.5, 0), Vector3.new(1.8, 9, 1.8), M.Slate, Color3.fromRGB(46, 38, 62), "Solid")
		Kit.block(model, frame * CFrame.new(0, 5.5, 0.93), Vector3.new(0.35, 6, 0.08), M.Neon, pink)
		Props.gem(model, (frame * CFrame.new(0, 11.8, 0)).Position, 1.2, purple, 60, 0.4, false)
	end
	local glow = Kit.block(model, origin * CFrame.new(0, 3.3, 0), Vector3.new(12, 0.2, 12), M.Glass, pink, "Ghost")
	Kit.emitter(glow, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(pink, purple),
		Size = Kit.seq(0.5, 0.35, 0),
		Transparency = Kit.seq(0.1, 0.4, 1),
		Lifetime = Kit.range(2.5, 4),
		Rate = 16,
		Speed = Kit.range(1.5, 3),
		Spread = Vector2.new(10, 10),
		LightEmission = 1,
		LightInfluence = 0,
	})
	Kit.billboard(altar, "✦ REBIRTH ✦", Color3.fromRGB(255, 160, 236), 16, 14, 160)
	Kit.finishModel(model, lobby, altar)
end

local function portalHub(lobby: Model, scenery: Instance)
	local hub = Kit.model("PortalHub")
	local degrees = { 128, 154, 180, 206, 232 }
	for index, zone in Zones.List do
		local spot = polar(56, degrees[index] or (128 + (index - 1) * 26))
		Props.portal(hub, facing(spot, Vector3.zero), zone.CrystalColor, zone.Name, zone.Id, "Portal_" .. zone.Id)
	end
	-- Crystal-topped posts between the portals.
	for index = 0, #Zones.List do
		local spot = polar(60, 115 + index * 26)
		Props.marker(scenery, spot, MARBLE, LAVENDER, 5)
	end
	local sign = Kit.block(hub, CFrame.new(polar(72, 180) + Vector3.new(0, 24, 0)), Vector3.new(1, 1, 1), M.Glass, LAVENDER, "Ghost")
	Kit.billboard(sign, "WORLD PORTALS", LAVENDER, 0, 30, 220)
	Kit.finishModel(hub, lobby)
end

local function grandArch(scenery: Instance)
	local z = 84
	for side = -1, 1, 2 do
		Props.surface(scenery, CFrame.new(side * 11, 0.8, z), Vector3.new(4.6, 1.6, 4.6), SLATE, "Solid")
		Props.surface(scenery, CFrame.new(side * 11, 11.6, z), Vector3.new(3.2, 20, 3.2), MARBLE, "Solid")
		Props.surface(scenery, CFrame.new(side * 11, 22.1, z), Vector3.new(4.2, 1, 4.2), SLATE, "Solid")
		Kit.block(scenery, CFrame.new(side * 11, 11.6, z - 1.65), Vector3.new(0.5, 14, 0.12), M.Neon, LAVENDER)
		Kit.block(scenery, CFrame.new(side * 6.5, 18.1, z - 1.2), Vector3.new(3.4, 9, 0.15), M.Fabric, Color3.fromRGB(120, 70, 200))
	end
	local beam = Props.surface(scenery, CFrame.new(0, 24.4, z), Vector3.new(28, 3.6, 3.6), MARBLE, "Solid")
	Kit.surfaceText(beam, Enum.NormalId.Front, "TO THE CRYSTAL MINES", Color3.fromRGB(150, 100, 230))
	Props.surface(scenery, CFrame.new(0, 26.5, z), Vector3.new(29, 0.6, 4.2), FOIL)
	local keystone = Kit.block(
		scenery,
		CFrame.new(0, 29.2, z) * CFrame.Angles(0, 0, math.pi / 4),
		Vector3.new(3.4, 3.4, 3),
		M.Neon,
		LAVENDER
	)
	Kit.light(keystone, LAVENDER, 24, 1.5)
end

local function northLanding(scenery: Instance)
	local slab = Props.surface(scenery, CFrame.new(0, -0.4, RADIUS - 3), Vector3.new(22, 1.2, 18), COBBLE, "Walk")
	slab.Name = "Landing"
	Props.surface(scenery, CFrame.new(0, -4.4, RADIUS + 2), Vector3.new(18, 7, 8), SLATE, "Solid")
	for side = -1, 1, 2 do
		Props.marker(scenery, Vector3.new(side * 10, 0.2, RADIUS + 3.5), MARBLE, LAVENDER)
	end
	for index, zone in Zones.List do
		if index <= 3 then
			for side = -1, 1, 2 do
				local spot = Vector3.new(side * 8.5, 0, 40 + index * 12)
				Props.banner(scenery, facing(spot, Vector3.new(0, 0, spot.Z)), zone.CrystalColor, 11)
			end
		end
	end
end

local function lamps(scenery: Instance)
	for index = 0, 7 do
		local degrees = 22.5 + index * 45
		local spot = polar(45.5, degrees)
		Props.lampPost(scenery, facing(spot, Vector3.zero) * CFrame.Angles(0, math.pi / 2, 0), WARM, true, 9)
	end
end

local function benches(scenery: Instance)
	for index = 0, 3 do
		local spot = polar(17, 45 + index * 90)
		local frame = facing(spot, Vector3.zero)
		local wood = Color3.fromRGB(132, 92, 62)
		Kit.block(scenery, frame * CFrame.new(0, 1.35, 0), Vector3.new(5, 0.4, 1.6), M.WoodPlanks, wood, "Solid")
		Kit.block(scenery, frame * CFrame.new(0, 2.4, 0.75), Vector3.new(5, 1.4, 0.3), M.WoodPlanks, wood, "Solid")
		for side = -1, 1, 2 do
			Kit.block(scenery, frame * CFrame.new(side * 2.1, 0.75, 0.1), Vector3.new(0.4, 1.1, 1.5), M.Metal, Color3.fromRGB(56, 52, 62))
		end
	end
end

local function waterfall(scenery: Instance, rng: Random)
	local pool = Vector3.new(-84, 0, -36)
	Land.pool(pool.X, pool.Z, 9, 0, 5, M.Rock, M.Water)
	Land.strip(pool, Vector3.new(-104, 0, -36), 7, -4, 2, Land.Air)
	Land.strip(pool, Vector3.new(-96.5, 0, -36), 7, -4, -1, M.Water)
	for index = 1, 6 do
		local angle = math.rad(-150 + index * 50)
		Land.ball(pool + Vector3.new(math.cos(angle) * 10.5, -0.5, math.sin(angle) * 10.5), rng:NextNumber(2.2, 3.2), M.Rock)
	end
	local lipX = -math.sqrt(RADIUS * RADIUS - 36 * 36)
	Props.waterfall(scenery, {
		Lip = Vector3.new(lipX - 0.5, -1, -36),
		Out = Vector3.new(-1, 0, 0),
		Width = 7,
		Drop = 100,
		Color = Color3.fromRGB(140, 205, 245),
	})
end

local function greenery(scenery: Instance, placer: Placer.Placer, rng: Random)
	for _ = 1, 16 do
		local spot = Placer.find(placer, rng, { Clear = 7, Margin = 3, MinDist = 74, MaxDist = 97, Tries = 30 })
		if spot then
			Props.tree(scenery, spot, rng, rng:NextNumber(0.9, 1.3), M.LeafyGrass)
		end
	end
	-- Trees on the hills.
	for _, top in { Vector3.new(56, 5.8, -52), Vector3.new(72, 6.3, -50), Vector3.new(-50, 5.8, -76), Vector3.new(-70, 5.8, -60) } do
		Props.tree(scenery, top, rng, rng:NextNumber(1, 1.25), M.LeafyGrass)
	end
	local blossoms = {
		Color3.fromRGB(255, 160, 210),
		Color3.fromRGB(255, 236, 140),
		Color3.fromRGB(250, 250, 255),
		Color3.fromRGB(196, 160, 255),
	}
	for _ = 1, 12 do
		local spot = Placer.find(placer, rng, { Clear = 3, Margin = 3, MinDist = 50, MaxDist = 98, Tries = 20 })
		if spot then
			Land.ball(spot + Vector3.new(0, -0.8, 0), rng:NextNumber(2.2, 3), M.LeafyGrass)
			for _ = 1, 3 do
				local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(1.3, 1.9), rng:NextNumber(-1.6, 1.6))
				Kit.ball(scenery, spot + offset, 0.35, M.Fabric, blossoms[rng:NextInteger(1, #blossoms)])
			end
		end
	end
end

local function skyDebris(scenery: Instance, rng: Random)
	local tops = Land.debris(Vector3.zero, RADIUS, rng, { M.Rock, M.Rock, M.Grass }, 12)
	for index, top in tops do
		if index <= 3 then
			Props.crystal(scenery, CFrame.new(top), rng:NextNumber(7, 10), LAVENDER, rng, { Light = false, Solid = false })
		end
	end
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, TAU)
		local reach = RADIUS + rng:NextNumber(12, 30)
		local x, z = math.cos(angle) * reach, math.sin(angle) * reach
		if math.abs(x) > 40 then
			local size = rng:NextNumber(3, 6)
			local rock = Kit.block(
				scenery,
				CFrame.new(x, rng:NextNumber(-6, 14), z) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0),
				Vector3.new(size, size * 0.8, size * 1.1),
				M.Slate,
				Kit.vary(Color3.fromRGB(110, 100, 118), rng, 0.1)
			)
			Kit.bob(rock, rng:NextNumber(1, 2.2), rng:NextNumber(0.08, 0.16))
		end
	end
end

-- Builds Workspace.Lobby unless one already exists. Returns the model it built (or nil).
function Lobby.build(): Model?
	if Workspace:FindFirstChild("Lobby") then
		return nil
	end
	local rng = Random.new(1337)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = lobby
	lobby.Parent = Workspace

	terrain(rng)
	plaza(scenery)
	spawnPad(lobby, scenery)
	fountain(scenery, rng)

	upgradeStation(lobby, facing(polar(30, -38) + Vector3.new(0, 0.2, 0), Vector3.zero))
	storeStation(lobby, facing(polar(31, 6) + Vector3.new(0, 0.2, 0), Vector3.zero), rng)
	rebirthAltar(lobby, facing(polar(64, 42), Vector3.zero), rng)
	portalHub(lobby, scenery)
	grandArch(scenery)
	northLanding(scenery)
	lamps(scenery)
	benches(scenery)
	waterfall(scenery, rng)

	Props.crystal(scenery, CFrame.new(66, 9, -62), 40, Color3.fromRGB(205, 150, 255), rng, { Sparkles = true })
	Props.crystal(scenery, CFrame.new(-61, 8, -67), 22, Color3.fromRGB(150, 200, 255), rng, { Sparkles = false })

	local placer = Placer.new(Vector3.zero, RADIUS)
	Placer.nogo(placer, 0, 0, 70)
	Placer.nogo(placer, 66, -62, 24)
	Placer.nogo(placer, -60, -68, 25)
	Placer.nogo(placer, -84, -36, 16)
	Placer.block(placer, 49, 43, 18)
	Placer.blockLine(placer, Vector3.new(0, 0, 60), Vector3.new(0, 0, RADIUS + 6), 14)
	Placer.blockLine(placer, Vector3.new(-84, 0, -36), Vector3.new(-104, 0, -36), 8)
	greenery(scenery, placer, rng)
	skyDebris(scenery, rng)
	return lobby
end

return Lobby
