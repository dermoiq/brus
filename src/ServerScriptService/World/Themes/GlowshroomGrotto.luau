--!strict
-- Glowshroom Grotto: dark mossy slate island. Its centrepiece is a walkable crystal cave (a terrain dome
-- hollowed out with a wide tunnel facing the main path and a skylight), lit by giant glowshrooms and a teal
-- crystal, with nodes inside. Outside: towering glowshrooms, teal pools, vines over the cliffs and a teal
-- waterfall.

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Land = require(World.Land)
local Placer = require(World.Placer)
local Props = require(World.Props)
local Types = require(World.Types)

local M = Enum.Material
local TAU = math.pi * 2
local TEAL = Color3.fromRGB(64, 255, 200)
local CYAN = Color3.fromRGB(90, 220, 255)
local VIOLET = Color3.fromRGB(176, 112, 255)
local MOSS = Color3.fromRGB(64, 112, 78)

local CAVE = Vector3.new(-52, 0, 30)

local function at(ctx: Types.ZoneCtx, x: number, y: number, z: number): Vector3
	return ctx.Center + Vector3.new(x, y, z)
end

-- Small mushroom: stem plus a two-step glowing cap (no light).
local function mushroom(parent: Instance, ground: Vector3, rng: Random, height: number, cap: number, color: Color3)
	local base = CFrame.new(ground)
		* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, TAU), rng:NextNumber(-0.25, 0.25))
	Kit.cylinder(
		parent,
		base * CFrame.new(0, height / 2 - 0.3, 0),
		height,
		math.max(cap * 0.2, 0.25),
		M.Fabric,
		Color3.fromRGB(206, 222, 210)
	)
	Kit.cylinder(parent, base * CFrame.new(0, height, 0), cap * 0.35, cap, M.Neon, color)
	Kit.cylinder(
		parent,
		base * CFrame.new(0, height + cap * 0.3, 0),
		cap * 0.3,
		cap * 0.6,
		M.Neon,
		Kit.tint(color, 0.2)
	)
end

local function cluster(ctx: Types.ZoneCtx, ground: Vector3, rng: Random)
	local colors = { TEAL, CYAN, VIOLET }
	for _ = 1, rng:NextInteger(2, 3) do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		mushroom(
			ctx.Scenery,
			ground + offset,
			rng,
			rng:NextNumber(1.6, 3.4),
			rng:NextNumber(0.9, 1.7),
			colors[rng:NextInteger(1, 3)]
		)
	end
	Placer.block(ctx.Placer, ground.X, ground.Z, 4)
end

local function cave(ctx: Types.ZoneCtx, rng: Random)
	local center = ctx.Center + CAVE
	Land.ball(center + Vector3.new(0, -2, 0), 46, M.Slate)
	Land.ball(center + Vector3.new(0, 2, 0), 34, Land.Air)
	Land.disc(center.X, center.Z, 36, -36, 0, M.Slate)
	Land.disc(center.X, center.Z, 31, -4, 0, M.Mud)
	Land.block(CFrame.new(at(ctx, -13, 9, CAVE.Z)), Vector3.new(22, 18, 20), Land.Air)
	Land.ball(center + Vector3.new(6, 42, -4), 9, Land.Air)
	-- Moss and boulders over the dome, away from the entrance (east) and the skylight.
	for index = 1, 8 do
		local yaw = math.rad(70 + index * 28)
		local tilt = rng:NextNumber(0.5, 1.15)
		local direction = Vector3.new(math.cos(yaw) * math.sin(tilt), math.cos(tilt), math.sin(yaw) * math.sin(tilt))
		Land.ball(
			center + Vector3.new(0, -2, 0) + direction * 45,
			rng:NextNumber(5, 8),
			if index % 3 == 0 then M.Rock else M.LeafyGrass
		)
	end
	Placer.nogo(ctx.Placer, center.X, center.Z, 47)
	Placer.level(ctx.Placer, center.X, center.Z, 33, 0)
	Placer.blockLine(ctx.Placer, at(ctx, -24, 0, CAVE.Z), at(ctx, 2, 0, CAVE.Z), 7)

	-- Interior: two glowshrooms, a teal crystal, a pool, stalactites, vines and a shaft of light.
	local function inside(x: number, z: number): Vector3
		return center + Vector3.new(x, 0, z)
	end
	Props.glowshroom(ctx.Scenery, inside(-16, 12), rng, 16, 6.5, TEAL, true, true)
	Props.glowshroom(ctx.Scenery, inside(8, -18), rng, 13, 5.5, VIOLET, true, true)
	Props.crystal(ctx.Scenery, CFrame.new(inside(-14, -12)), 22, CYAN, rng, { Rock = M.Slate, Name = "CaveCrystal" })
	Placer.block(ctx.Placer, center.X - 16, center.Z + 12, 5)
	Placer.block(ctx.Placer, center.X + 8, center.Z - 18, 5)
	Placer.block(ctx.Placer, center.X - 14, center.Z - 12, 7)
	local pool = inside(12, 16)
	Land.pool(pool.X, pool.Z, 6, 0, 4, M.Slate, M.Water)
	Placer.nogo(ctx.Placer, pool.X, pool.Z, 8)
	for _, offset in
		{ Vector3.new(20, 0, -6), Vector3.new(-24, 0, 14), Vector3.new(-4, 0, -26), Vector3.new(20, 0, 22) }
	do
		cluster(ctx, inside(offset.X, offset.Z), rng)
	end
	local skylight = center + Vector3.new(6, 0, -4)
	for index = 1, 9 do
		local angle = index / 9 * TAU
		local reach = rng:NextNumber(10, 24)
		local x, z = math.cos(angle) * reach, math.sin(angle) * reach
		-- Hang from solid rock only, not from the skylight opening.
		if Vector3.new(x - 6, 0, z + 4).Magnitude > 12 then
			local ceiling = 2 + math.sqrt(34 * 34 - reach * reach)
			Props.shard(
				ctx.Scenery,
				CFrame.new(center + Vector3.new(x, ceiling + 1, z)) * CFrame.Angles(math.pi, rng:NextNumber(0, TAU), 0),
				rng:NextNumber(1.4, 2.4),
				rng:NextNumber(5, 9),
				M.Slate,
				Kit.vary(Color3.fromRGB(60, 74, 76), rng, 0.1),
				"Decor",
				0
			)
		end
	end
	for index = 1, 7 do
		local angle = index / 7 * TAU
		local length = rng:NextNumber(8, 15)
		local top = skylight + Vector3.new(math.cos(angle) * 8, 37, math.sin(angle) * 8)
		Kit.block(
			ctx.Scenery,
			CFrame.new(top - Vector3.new(0, length / 2, 0)),
			Vector3.new(0.35, length, 0.35),
			M.LeafyGrass,
			MOSS
		)
		Kit.block(
			ctx.Scenery,
			CFrame.new(top - Vector3.new(0, length + 0.3, 0)),
			Vector3.new(0.6, 0.6, 0.6),
			M.Neon,
			TEAL
		)
	end
	local shaft = Kit.cylinder(
		ctx.Scenery,
		CFrame.new(skylight + Vector3.new(0, 18, 0)),
		36,
		6,
		M.Neon,
		Color3.fromRGB(200, 255, 240)
	)
	shaft.Transparency = 0.93
	local spores = Kit.block(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 10, 0)),
		Vector3.new(50, 16, 50),
		M.Glass,
		TEAL,
		"Ghost"
	)
	Kit.emitter(spores, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(TEAL, CYAN),
		Size = Kit.seq(0.3, 0.4, 0),
		Transparency = Kit.seq(0.3, 0.5, 1),
		Lifetime = Kit.range(6, 10),
		Rate = 18,
		Speed = Kit.range(0.2, 0.8),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
		LightInfluence = 0,
	})

	for _, offset in { Vector3.new(10, 0, -2), Vector3.new(-4, 0, 24), Vector3.new(-26, 0, 0), Vector3.new(-8, 0, 2) } do
		table.insert(ctx.NodeSpots, center + offset)
	end
	-- Tunnel mouth framed by mossy timber.
	local mouth = at(ctx, -7, 0, CAVE.Z)
	for side = -1, 1, 2 do
		Kit.block(
			ctx.Scenery,
			CFrame.new(mouth + Vector3.new(0, 7, side * 9.5)),
			Vector3.new(1.4, 14, 1.4),
			M.Wood,
			Color3.fromRGB(84, 70, 56),
			"Solid"
		)
	end
	Kit.block(
		ctx.Scenery,
		CFrame.new(mouth + Vector3.new(0, 14.6, 0)),
		Vector3.new(1.6, 1.4, 21),
		M.Wood,
		Color3.fromRGB(84, 70, 56),
		"Solid"
	)
	Props.lantern(ctx.Scenery, mouth + Vector3.new(-1, 13.9, 0), TEAL, false)
end

local function pools(ctx: Types.ZoneCtx, rng: Random)
	for _, spec in { { 34, 62, 10 }, { 78, -78, 8 } } do
		local pool = at(ctx, spec[1], 0, spec[2])
		Land.pool(pool.X, pool.Z, spec[3], 0, 4, M.Slate, M.Water)
		for index = 1, 7 do
			local angle = index / 7 * TAU + rng:NextNumber(-0.2, 0.2)
			local reach = spec[3] + 1.5
			Land.ball(
				pool + Vector3.new(math.cos(angle) * reach, -0.6, math.sin(angle) * reach),
				rng:NextNumber(1.8, 3),
				if index % 2 == 0 then M.LeafyGrass else M.Rock
			)
		end
		Placer.nogo(ctx.Placer, pool.X, pool.Z, spec[3] + 4)
		cluster(ctx, pool + Vector3.new(spec[3] + 4, 0, 2), rng)
	end
end

local function waterfall(ctx: Types.ZoneCtx, rng: Random)
	local pool = at(ctx, 106, 0, 10)
	local lipX = math.sqrt(ctx.Radius ^ 2 - 10 ^ 2)
	Land.pool(pool.X, pool.Z, 8, 0, 5, M.Slate, M.Water)
	Land.strip(pool, at(ctx, lipX + 6, 0, 10), 8, -4, 2, Land.Air)
	Land.strip(pool, at(ctx, lipX - 1, 0, 10), 8, -4, -1, M.Water)
	for index = 1, 5 do
		local angle = math.rad(70 + index * 45)
		Land.ball(
			pool + Vector3.new(math.cos(angle) * 9.5, -0.5, math.sin(angle) * 9.5),
			rng:NextNumber(2, 3.2),
			M.LeafyGrass
		)
	end
	Props.waterfall(ctx.Scenery, {
		Lip = at(ctx, lipX - 0.5, -1, 10),
		Out = Vector3.new(1, 0, 0),
		Width = 8,
		Drop = 110,
		Color = Color3.fromRGB(90, 220, 205),
		Mist = Color3.fromRGB(190, 255, 240),
	})
	Placer.nogo(ctx.Placer, pool.X, pool.Z, 12)
	Placer.blockLine(ctx.Placer, pool, at(ctx, lipX, 0, 10), 7)
end

local function vines(ctx: Types.ZoneCtx, rng: Random)
	for index = 1, 18 do
		local angle = index / 18 * TAU + rng:NextNumber(-0.1, 0.1)
		local ux, uz = math.cos(angle), math.sin(angle)
		if math.abs(ux) > 0.45 then
			local length = rng:NextNumber(10, 26)
			local top = ctx.Center + Vector3.new(ux * (ctx.Radius + 0.8), -0.5, uz * (ctx.Radius + 0.8))
			Kit.block(
				ctx.Scenery,
				CFrame.new(top - Vector3.new(0, length / 2, 0)),
				Vector3.new(0.5, length, 0.5),
				M.LeafyGrass,
				Kit.vary(MOSS, rng, 0.12)
			)
			if index % 3 == 0 then
				Kit.block(
					ctx.Scenery,
					CFrame.new(top - Vector3.new(0, length + 0.4, 0)),
					Vector3.new(0.8, 0.8, 0.8),
					M.Neon,
					TEAL
				)
			end
		end
	end
end

local function build(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	-- Mossy patches across the plateau, then the path on top of them.
	for _ = 1, 9 do
		local angle = rng:NextNumber(0, TAU)
		local reach = rng:NextNumber(20, 110)
		Land.disc(
			ctx.Center.X + math.cos(angle) * reach,
			ctx.Center.Z + math.sin(angle) * reach,
			rng:NextNumber(8, 16),
			-4,
			0,
			M.LeafyGrass
		)
	end
	Land.path(
		{ at(ctx, 0, 0, -ctx.Radius + 6), at(ctx, 2, 0, -30), at(ctx, -2, 0, 50), at(ctx, 0, 0, ctx.Radius - 6) },
		10,
		0,
		M.Mud
	)
	cave(ctx, rng)
	pools(ctx, rng)
	waterfall(ctx, rng)
	vines(ctx, rng)

	-- Towering glowshrooms visible from the quarry.
	local giants = {
		{ X = 44, Z = -36, Height = 28, Cap = 11, Color = CYAN },
		{ X = 70, Z = 46, Height = 34, Cap = 13, Color = TEAL },
		{ X = 20, Z = 96, Height = 24, Cap = 9, Color = VIOLET },
	}
	for _, giant in giants do
		local spot = at(ctx, giant.X, 0, giant.Z)
		Props.glowshroom(ctx.Scenery, spot, rng, giant.Height, giant.Cap, giant.Color, true, true)
		Placer.block(ctx.Placer, spot.X, spot.Z, 6)
	end
	Props.crystal(
		ctx.Scenery,
		CFrame.new(at(ctx, -84, 0, -50)),
		30,
		TEAL,
		rng,
		{ Sparkles = true, Name = "GiantTealCrystal" }
	)
	Placer.block(ctx.Placer, ctx.Center.X - 84, ctx.Center.Z - 50, 9)
	Props.crystal(ctx.Scenery, CFrame.new(at(ctx, 80, 0, 74)), 22, CYAN, rng, {})
	Placer.block(ctx.Placer, ctx.Center.X + 80, ctx.Center.Z + 74, 8)

	-- Fallen mossy log with mushrooms.
	local log = at(ctx, -40, 0, -64)
	Kit.rod(
		ctx.Scenery,
		CFrame.new(log + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.6, 0),
		14,
		1.4,
		M.Wood,
		Color3.fromRGB(88, 72, 58),
		"Solid"
	)
	cluster(ctx, log + Vector3.new(0, 2.4, 0), rng)
	Placer.block(ctx.Placer, log.X, log.Z, 8)

	local tops = Land.debris(ctx.Center, ctx.Radius, rng, { M.Slate, M.Rock, M.LeafyGrass }, 14)
	for index, top in tops do
		if index % 3 == 0 then
			cluster(ctx, top, rng)
		end
	end
end

local function dress(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	for _ = 1, 8 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 120, Tries = 20 })
		if spot then
			cluster(ctx, spot, rng)
		end
	end
	for _ = 1, 12 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 122, Tries = 20 })
		if spot then
			Land.ball(
				spot + Vector3.new(0, -1.2, 0),
				rng:NextNumber(2.4, 4.4),
				if rng:NextNumber() < 0.5 then M.LeafyGrass else M.Rock
			)
		end
	end
	local haze = Kit.block(
		ctx.Scenery,
		CFrame.new(ctx.Center + Vector3.new(0, 14, 0)),
		Vector3.new(220, 20, 220),
		M.Glass,
		TEAL,
		"Ghost"
	)
	Kit.emitter(haze, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(TEAL, VIOLET),
		Size = Kit.seq(0.35, 0.5, 0),
		Transparency = Kit.seq(0.2, 0.5, 1),
		Lifetime = Kit.range(6, 10),
		Rate = 40,
		Speed = Kit.range(0.3, 1),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
		LightInfluence = 0,
	})
end

local Theme: Types.Theme = {
	Style = {
		Top = M.Slate,
		Rim = M.LeafyGrass,
		RimWidth = 10,
		Cliff = M.Slate,
		Strata = M.Mud,
		Under = M.Rock,
		Deep = M.Slate,
	},
	Paving = { Material = M.Slate, Color = Color3.fromRGB(70, 86, 88), Variant = "Grotto_WetSlate" },
	Stone = { Material = M.Rock, Color = Color3.fromRGB(78, 96, 90), Variant = "Grotto_MossRock" },
	Path = M.Mud,
	Bridge = Color3.fromRGB(104, 88, 72),
	KeepClear = { Vector3.new(126, 0, 10) },
	Build = build,
	Dress = dress,
}

return Theme
