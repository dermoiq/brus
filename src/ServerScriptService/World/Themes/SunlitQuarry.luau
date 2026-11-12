--!strict
-- Sunlit Quarry: golden sandstone island with grassy edges, a terraced open-pit quarry (4-stud benches you
-- can hop down and back up), a crane over the pit, scaffolding, mine-cart rails with a loaded cart, a
-- miners' camp, a natural sandstone arch, a waterfall off the east cliff and a giant amber crystal on a mesa.

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Land = require(World.Land)
local Placer = require(World.Placer)
local Props = require(World.Props)
local Types = require(World.Types)

local M = Enum.Material
local TAU = math.pi * 2
local AMBER = Color3.fromRGB(255, 186, 84)
local WOOD = Color3.fromRGB(122, 86, 56)
local CANVAS = Color3.fromRGB(226, 212, 182)
local SANDSTONE: Types.Surface =
	{ Material = M.Sandstone, Color = Color3.fromRGB(212, 170, 112), Variant = "Quarry_Sandstone" }

local PIT = Vector3.new(56, 0, 16)
local PIT_RADII = { 46, 40, 34, 28, 22, 16 }

local function at(ctx: Types.ZoneCtx, x: number, y: number, z: number): Vector3
	return ctx.Center + Vector3.new(x, y, z)
end

local function pit(ctx: Types.ZoneCtx)
	local center = ctx.Center + PIT
	for index, radius in PIT_RADII do
		local floor = -4 * index
		Land.disc(center.X, center.Z, radius, floor, 40, Land.Air)
		Placer.level(ctx.Placer, center.X, center.Z, radius, floor)
	end
	Land.disc(center.X, center.Z, 16, -28, -24, M.Ground)
	table.insert(ctx.NodeSpots, center + Vector3.new(-6, 0, -3))
	table.insert(ctx.NodeSpots, center + Vector3.new(6, 0, 4))

	-- Sunlit dust hanging over the pit.
	local dust = Kit.block(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 2, 0)),
		Vector3.new(64, 1, 64),
		M.Glass,
		AMBER,
		"Ghost"
	)
	Kit.emitter(dust, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(Color3.fromRGB(255, 232, 176)),
		Size = Kit.seq(0.25, 0.4, 0),
		Transparency = Kit.seq(0.4, 0.6, 1),
		Lifetime = Kit.range(5, 8),
		Rate = 14,
		Speed = Kit.range(0.3, 1),
		Spread = Vector2.new(180, 180),
		LightEmission = 0.6,
		LightInfluence = 0.4,
	})

	-- Scaffold tower standing on the second-lowest bench against the south-west wall.
	local angle = math.rad(205)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local base = center + outward * 19
	local frame = CFrame.lookAt(base, base + outward)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -1.6, 1.6 } do
			Kit.block(ctx.Scenery, frame * CFrame.new(x, -7.5, z), Vector3.new(0.8, 25, 0.8), M.Wood, WOOD, "Solid")
		end
	end
	for _, y in { -12, -4, 4 } do
		Kit.block(
			ctx.Scenery,
			frame * CFrame.new(0, y, 0),
			Vector3.new(6.6, 0.5, 4.4),
			M.WoodPlanks,
			Kit.tint(WOOD, 0.1),
			"Walk"
		)
	end
	for side = -1, 1, 2 do
		Kit.block(
			ctx.Scenery,
			frame * CFrame.new(0, -12, 1.75) * CFrame.Angles(0, 0, side * 0.62),
			Vector3.new(0.4, 13, 0.3),
			M.Wood,
			WOOD
		)
	end
	Props.lantern(ctx.Scenery, (frame * CFrame.new(0, 3.6, 0)).Position, Color3.fromRGB(255, 200, 120), false)
end

local function crane(ctx: Types.ZoneCtx)
	local base = at(ctx, PIT.X, 0, PIT.Z + 58)
	local frame = CFrame.lookAt(base, base + Vector3.new(0, 0, -1))
	for _, x in { -2.5, 2.5 } do
		for _, z in { -2.5, 2.5 } do
			Kit.block(ctx.Scenery, frame * CFrame.new(x, 15, z), Vector3.new(1, 30, 1), M.Wood, WOOD, "Solid")
		end
	end
	for _, y in { 8, 16, 24 } do
		for _, z in { -2.5, 2.5 } do
			Kit.block(ctx.Scenery, frame * CFrame.new(0, y, z), Vector3.new(6, 0.6, 0.6), M.Wood, Kit.tint(WOOD, -0.1))
		end
	end
	Kit.block(
		ctx.Scenery,
		frame * CFrame.new(0, 32, 0),
		Vector3.new(7, 4, 7),
		M.WoodPlanks,
		Kit.tint(WOOD, 0.12),
		"Solid"
	)
	Kit.block(
		ctx.Scenery,
		frame * CFrame.new(0, 34.3, 0),
		Vector3.new(7.8, 0.5, 7.8),
		M.Metal,
		Color3.fromRGB(150, 70, 50),
		"Solid"
	)
	Kit.block(ctx.Scenery, frame * CFrame.new(0, 33, -17), Vector3.new(1.4, 1.4, 34), M.Wood, WOOD, "Solid")
	Props.surface(ctx.Scenery, frame * CFrame.new(0, 32, 6), Vector3.new(4, 4, 4), SANDSTONE, "Solid")
	Kit.block(
		ctx.Scenery,
		frame * CFrame.new(0, 22, -33),
		Vector3.new(0.2, 22, 0.2),
		M.Fabric,
		Color3.fromRGB(170, 140, 100)
	)
	Kit.cylinder(ctx.Scenery, frame * CFrame.new(0, 9.5, -33), 3, 1.6, M.Metal, Color3.fromRGB(90, 84, 80))
	for side = -1, 1, 2 do
		local shard = Kit.block(
			ctx.Scenery,
			frame * CFrame.new(side * 0.5, 11.3, -33) * CFrame.Angles(0, 0.8, side * 0.35),
			Vector3.new(0.8, 2.4, 0.8),
			M.Glass,
			AMBER
		)
		shard.Transparency = 0.2
	end
	Kit.block(ctx.Scenery, frame * CFrame.new(0, 11, -33), Vector3.new(0.5, 1.6, 0.5), M.Neon, Kit.tint(AMBER, 0.2))
	Placer.block(ctx.Placer, base.X, base.Z, 9)
end

local function railway(ctx: Types.ZoneCtx, rng: Random)
	local x, fromZ, toZ = -40, -78, -6
	local length = toZ - fromZ
	for _, dx in { -1.5, 1.5 } do
		Kit.block(
			ctx.Scenery,
			CFrame.new(at(ctx, x + dx, 0.6, (fromZ + toZ) / 2)),
			Vector3.new(0.35, 0.45, length),
			M.Metal,
			Color3.fromRGB(124, 114, 108)
		)
	end
	for index = 0, math.floor(length / 2.4) - 1 do
		Kit.block(
			ctx.Scenery,
			CFrame.new(at(ctx, x, 0.2, fromZ + 1.2 + index * 2.4)),
			Vector3.new(5.2, 0.4, 0.9),
			M.Wood,
			Kit.vary(WOOD, rng, 0.1)
		)
	end
	-- Loaded mine cart.
	local cart = CFrame.new(at(ctx, x, 0, -46))
	local iron = Color3.fromRGB(78, 72, 74)
	Kit.block(ctx.Scenery, cart * CFrame.new(0, 2.4, 0), Vector3.new(4.2, 0.4, 6), M.WoodPlanks, WOOD, "Solid")
	for side = -1, 1, 2 do
		Kit.block(ctx.Scenery, cart * CFrame.new(side * 2, 3.5, 0), Vector3.new(0.3, 2.2, 6.2), M.Metal, iron, "Solid")
		Kit.block(ctx.Scenery, cart * CFrame.new(0, 3.5, side * 3), Vector3.new(4.2, 2.2, 0.3), M.Metal, iron, "Solid")
		for _, z in { -2, 2 } do
			Kit.rod(ctx.Scenery, cart * CFrame.new(side * 1.75, 1.6, z), 0.4, 0.75, M.Metal, Color3.fromRGB(56, 52, 54))
		end
	end
	for index = 1, 3 do
		local shard = Kit.block(
			ctx.Scenery,
			cart
				* CFrame.new(-1.2 + index * 0.6, 4.6, -1.5 + index * 0.8)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
			Vector3.new(1, 2.6, 1),
			M.Glass,
			Kit.vary(AMBER, rng, 0.08)
		)
		shard.Transparency = 0.2
	end
	Kit.block(ctx.Scenery, cart * CFrame.new(0, 4.4, 0), Vector3.new(0.7, 1.8, 0.7), M.Neon, Kit.tint(AMBER, 0.2))
	-- Buffer stop and ore pile at the end of the line.
	for side = -1, 1, 2 do
		Kit.block(
			ctx.Scenery,
			CFrame.new(at(ctx, x + side * 2.2, 1.5, toZ + 1)),
			Vector3.new(0.8, 3, 0.8),
			M.Wood,
			WOOD,
			"Solid"
		)
	end
	Kit.block(
		ctx.Scenery,
		CFrame.new(at(ctx, x, 2.6, toZ + 1)),
		Vector3.new(5.6, 1.2, 1),
		M.WoodPlanks,
		Color3.fromRGB(170, 60, 40),
		"Solid"
	)
	local pile = at(ctx, x, 0, toZ + 7)
	Land.ball(pile + Vector3.new(0, -1.5, 0), 4, M.Sandstone)
	Props.crystal(
		ctx.Scenery,
		CFrame.new(pile + Vector3.new(0, 1.5, 0)),
		9,
		AMBER,
		rng,
		{ Light = false, Rock = M.Sandstone, RockColor = Color3.fromRGB(196, 150, 96) }
	)
	Placer.blockLine(ctx.Placer, at(ctx, x, 0, fromZ), at(ctx, x, 0, toZ + 8), 5)
end

local function tent(ctx: Types.ZoneCtx, ground: CFrame, color: Color3)
	local height, length, half = 3.8, 5.6, 2.6
	Kit.wedge(
		ctx.Scenery,
		ground * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(length, height, half),
		M.Fabric,
		color,
		"Solid"
	)
	Kit.wedge(
		ctx.Scenery,
		ground * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		Vector3.new(length, height, half),
		M.Fabric,
		Kit.tint(color, -0.08),
		"Solid"
	)
	Kit.rod(
		ctx.Scenery,
		ground * CFrame.new(0, height + 0.1, 0) * CFrame.Angles(0, math.pi / 2, 0),
		length + 0.8,
		0.15,
		M.Wood,
		WOOD
	)
end

local function camp(ctx: Types.ZoneCtx, rng: Random)
	local center = at(ctx, 30, 0, -78)
	Props.campfire(ctx.Scenery, center, rng)
	tent(ctx, CFrame.new(center + Vector3.new(-8, 0, 4)) * CFrame.Angles(0, 0.4, 0), CANVAS)
	tent(ctx, CFrame.new(center + Vector3.new(7, 0, 7)) * CFrame.Angles(0, -0.5, 0), Color3.fromRGB(200, 122, 92))
	for index = 1, 2 do
		local angle = index * 2.2
		Kit.rod(
			ctx.Scenery,
			CFrame.new(center + Vector3.new(math.cos(angle) * 4.5, 0.5, math.sin(angle) * 4.5))
				* CFrame.Angles(0, -angle + math.pi / 2, 0),
			3.6,
			0.5,
			M.Wood,
			Kit.tint(WOOD, -0.1),
			"Solid"
		)
	end
	Props.crate(ctx.Scenery, CFrame.new(center + Vector3.new(-9, 1.25, -5)) * CFrame.Angles(0, 0.3, 0), 2.5, WOOD)
	Props.crate(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(-6.4, 1.1, -6.5)) * CFrame.Angles(0, -0.2, 0),
		2.2,
		Kit.tint(WOOD, 0.1)
	)
	Props.barrel(ctx.Scenery, center + Vector3.new(10, 0, -3), WOOD)
	Props.barrel(ctx.Scenery, center + Vector3.new(11.5, 0, -0.5), Kit.tint(WOOD, -0.1))
	local lean = CFrame.new(center + Vector3.new(-9, 2.6, -3.5)) * CFrame.Angles(0.35, 0, 0.1)
	Kit.block(ctx.Scenery, lean, Vector3.new(0.3, 4.4, 0.3), M.Wood, WOOD)
	Kit.block(
		ctx.Scenery,
		lean * CFrame.new(0, 2, 0),
		Vector3.new(2.8, 0.45, 0.4),
		M.Metal,
		Color3.fromRGB(150, 150, 160)
	)
	Placer.block(ctx.Placer, center.X, center.Z, 17)
end

local function arch(ctx: Types.ZoneCtx)
	local north, south = at(ctx, -98, 0, -8), at(ctx, -98, 0, -40)
	for _, foot in { north, south } do
		Land.disc(foot.X, foot.Z, 6, -4, 26, M.Sandstone)
		Land.ball(foot + Vector3.new(0, 1, 0), 7.5, M.Rock)
		Placer.nogo(ctx.Placer, foot.X, foot.Z, 10)
	end
	Land.block(CFrame.new(at(ctx, -98, 27, -24)), Vector3.new(12, 10, 46), M.Sandstone)
	Land.ball(at(ctx, -98, 31, -24), 8, M.Sandstone)
	Land.ball(at(ctx, -97, 33, -14), 5, M.Grass)
end

local function waterfall(ctx: Types.ZoneCtx, rng: Random)
	local pool = at(ctx, 104, 0, -40)
	local lipX = math.sqrt(ctx.Radius ^ 2 - 40 ^ 2)
	Land.pool(pool.X, pool.Z, 9, 0, 5, M.Rock, M.Water)
	Land.strip(pool, at(ctx, lipX + 6, 0, -40), 8, -4, 2, Land.Air)
	Land.strip(pool, at(ctx, lipX - 1, 0, -40), 8, -4, -1, M.Water)
	for index = 1, 6 do
		local angle = math.rad(30 + index * 50)
		Land.ball(
			pool + Vector3.new(math.cos(angle) * 10.5, -0.5, math.sin(angle) * 10.5),
			rng:NextNumber(2.2, 3.4),
			M.Rock
		)
	end
	Props.waterfall(ctx.Scenery, {
		Lip = at(ctx, lipX - 0.5, -1, -40),
		Out = Vector3.new(1, 0, 0),
		Width = 8,
		Drop = 105,
		Color = Color3.fromRGB(150, 210, 245),
	})
	Placer.nogo(ctx.Placer, pool.X, pool.Z, 13)
	Placer.blockLine(ctx.Placer, pool, at(ctx, lipX, 0, -40), 7)
end

local function mesa(ctx: Types.ZoneCtx, rng: Random)
	local center = at(ctx, -62, 0, 58)
	Land.disc(center.X, center.Z, 22, -4, 12, M.Sandstone)
	Land.disc(center.X, center.Z, 19, 8, 12, M.Grass)
	for index = 1, 7 do
		local angle = index / 7 * TAU + rng:NextNumber(-0.2, 0.2)
		Land.ball(
			center + Vector3.new(math.cos(angle) * 20, rng:NextNumber(0, 4), math.sin(angle) * 20),
			rng:NextNumber(5, 8),
			M.Rock
		)
	end
	Placer.nogo(ctx.Placer, center.X, center.Z, 30)
	Props.crystal(ctx.Scenery, CFrame.new(center + Vector3.new(0, 12, 0)), 42, AMBER, rng, {
		Sparkles = true,
		Rock = M.Sandstone,
		RockColor = Color3.fromRGB(200, 154, 98),
		Name = "GiantAmberCrystal",
	})
	Props.crystal(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(9, 12, -8)),
		15,
		Kit.tint(AMBER, 0.1),
		rng,
		{ Light = false, Rock = M.Sandstone }
	)
	Props.tree(ctx.Scenery, center + Vector3.new(-10, 12, 6), rng, 1.1, M.LeafyGrass)
end

local function rimTrees(ctx: Types.ZoneCtx, rng: Random)
	for _ = 1, 11 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 7, Margin = 3, MinDist = 113, MaxDist = 121, Tries = 30 })
		if spot then
			Props.tree(ctx.Scenery, spot, rng, rng:NextNumber(0.85, 1.2), M.LeafyGrass)
		end
	end
end

local function build(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	Land.path(
		{ at(ctx, 0, 0, -ctx.Radius + 6), at(ctx, -3, 0, -40), at(ctx, 3, 0, 40), at(ctx, 0, 0, ctx.Radius - 6) },
		10,
		0,
		M.Ground
	)
	pit(ctx)
	crane(ctx)
	railway(ctx, rng)
	camp(ctx, rng)
	arch(ctx)
	waterfall(ctx, rng)
	mesa(ctx, rng)
	rimTrees(ctx, rng)
	-- Stacks of cut sandstone blocks waiting to be hauled.
	for _ = 1, 3 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 7, Margin = 3, MinDist = 20, MaxDist = 110, Tries = 30 })
		if spot then
			local frame = CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
			for row = 0, 2 do
				for column = 0, 2 - row do
					Props.surface(
						ctx.Scenery,
						frame
							* CFrame.new((column - (2 - row) / 2) * 3.1, 1.25 + row * 2.5, 0)
							* CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0),
						Vector3.new(3, 2.5, 3.4),
						SANDSTONE,
						"Solid"
					)
				end
			end
		end
	end
	-- Lamps along the rail line.
	for _, z in { -66, -36, -10 } do
		Props.lampPost(ctx.Scenery, CFrame.new(at(ctx, -35.5, 0, z)) * CFrame.Angles(0, math.pi, 0), AMBER, false, 8)
	end
	for index = 1, 3 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 9, Margin = 4, MinDist = 30, MaxDist = 108, Tries = 40 })
		if spot then
			Props.crystal(ctx.Scenery, CFrame.new(spot), rng:NextNumber(16, 24), AMBER, rng, {
				Light = index <= 2,
				Rock = M.Sandstone,
				RockColor = Color3.fromRGB(196, 150, 96),
			})
		end
	end
	local tops = Land.debris(ctx.Center, ctx.Radius, rng, { M.Sandstone, M.Rock }, 14)
	for index, top in tops do
		if index % 3 == 0 then
			Props.crystal(
				ctx.Scenery,
				CFrame.new(top),
				rng:NextNumber(7, 11),
				AMBER,
				rng,
				{ Light = false, Solid = false, Shards = 3 }
			)
		end
	end
end

local function dress(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	-- Low wooden fence along the near side of the pit rim.
	local center = ctx.Center + PIT
	for index = 0, 13 do
		local angle = math.rad(110 + index * 13)
		local spot = center + Vector3.new(math.cos(angle) * 48.5, 0, math.sin(angle) * 48.5)
		if Placer.isFree(ctx.Placer, spot.X, spot.Z, 1) then
			local frame = CFrame.new(spot) * CFrame.Angles(0, -(angle + math.pi / 2), 0)
			Kit.block(ctx.Scenery, frame * CFrame.new(0, 1.2, 0), Vector3.new(0.5, 2.4, 0.5), M.Wood, WOOD)
			Kit.block(
				ctx.Scenery,
				frame * CFrame.new(5.5, 1.8, 0),
				Vector3.new(11.2, 0.35, 0.3),
				M.Wood,
				Kit.tint(WOOD, 0.08)
			)
		end
	end
	for _ = 1, 12 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 120, Tries = 20 })
		if spot then
			Land.ball(
				spot + Vector3.new(0, -1.2, 0),
				rng:NextNumber(2.4, 4.2),
				if rng:NextNumber() < 0.6 then M.Sandstone else M.Rock
			)
		end
	end
	for _ = 1, 4 do
		local angle = rng:NextNumber(0, TAU)
		local reach = ctx.Radius + rng:NextNumber(10, 24)
		local x, z = math.cos(angle) * reach, math.sin(angle) * reach
		if math.abs(x) > 40 then
			local size = rng:NextNumber(3, 5)
			local rock = Kit.block(
				ctx.Scenery,
				CFrame.new(at(ctx, x, rng:NextNumber(-8, 10), z))
					* CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0),
				Vector3.new(size, size * 0.8, size * 1.2),
				M.Sandstone,
				Kit.vary(Color3.fromRGB(206, 160, 104), rng, 0.08)
			)
			Kit.bob(rock, rng:NextNumber(1, 2), rng:NextNumber(0.08, 0.15))
		end
	end
end

local Theme: Types.Theme = {
	Style = {
		Top = M.Sandstone,
		Rim = M.Grass,
		RimWidth = 18,
		Cliff = M.Sandstone,
		Strata = M.Rock,
		Under = M.Rock,
		Deep = M.Sandstone,
	},
	Paving = { Material = M.Pebble, Color = Color3.fromRGB(196, 172, 136), Variant = "Quarry_Gravel" },
	Stone = SANDSTONE,
	Bridge = Color3.fromRGB(140, 100, 64),
	KeepClear = { Vector3.new(124, 0, -40) },
	Build = build,
	Dress = dress,
}

return Theme
