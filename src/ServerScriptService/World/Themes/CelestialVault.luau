--!strict
-- Celestial Vault: white limestone island of marble ruins. A gold-trimmed walkway between colonnades leads
-- to a stepped ziggurat crowned by a floating giant crystal inside spinning rings. Around it: a rotunda with
-- a rune orb, broken arches, a rune circle, floating crystals, a starlight fall and drifting stars.

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Land = require(World.Land)
local Placer = require(World.Placer)
local Props = require(World.Props)
local Types = require(World.Types)

local M = Enum.Material
local TAU = math.pi * 2
local LILAC = Color3.fromRGB(214, 140, 255)
local STARLIGHT = Color3.fromRGB(236, 214, 255)
local GOLD = Color3.fromRGB(246, 204, 104)
local MARBLE: Types.Surface = { Material = M.Marble, Color = Color3.fromRGB(240, 236, 250), Variant = "Vault_Marble" }
local VEINED: Types.Surface = { Material = M.Marble, Color = Color3.fromRGB(222, 214, 240), Variant = "Vault_Marble" }
local TRIM: Types.Surface = { Material = M.Foil, Color = GOLD, Variant = "Vault_GoldTrim" }

local MONUMENT = Vector3.new(0, 0, 52)
local ROTUNDA = Vector3.new(72, 0, 58)

local function at(ctx: Types.ZoneCtx, x: number, y: number, z: number): Vector3
	return ctx.Center + Vector3.new(x, y, z)
end

-- Glowing ring inlaid in a floor: a neon disc with a slightly smaller stone disc on top.
local function runeRing(parent: Instance, center: Vector3, radius: number, width: number, stone: Types.Surface)
	Kit.cylinder(parent, CFrame.new(center + Vector3.new(0, 0.03, 0)), 0.06, radius, M.Neon, LILAC)
	local inner = Kit.cylinder(
		parent,
		CFrame.new(center + Vector3.new(0, 0.05, 0)),
		0.1,
		radius - width,
		stone.Material,
		stone.Color,
		"Walk"
	)
	Props.paint(inner, stone)
end

local function walkway(ctx: Types.ZoneCtx)
	local fromZ, toZ = -112, 24
	local segments = 7
	local length = (toZ - fromZ) / segments
	for index = 0, segments - 1 do
		local z = fromZ + (index + 0.5) * length
		Props.surface(
			ctx.Scenery,
			CFrame.new(at(ctx, 0, -0.3, z)),
			Vector3.new(14, 1, length - 0.15),
			if index % 2 == 0 then MARBLE else VEINED,
			"Walk"
		)
		Kit.block(
			ctx.Scenery,
			CFrame.new(at(ctx, 0, 0.22, z)) * CFrame.Angles(0, math.pi / 4, 0),
			Vector3.new(2, 0.06, 2),
			M.Neon,
			LILAC
		)
	end
	for side = -1, 1, 2 do
		Props.surface(
			ctx.Scenery,
			CFrame.new(at(ctx, side * 7.3, -0.15, (fromZ + toZ) / 2)),
			Vector3.new(0.7, 1, toZ - fromZ),
			TRIM,
			"Walk"
		)
	end
end

local function colonnade(ctx: Types.ZoneCtx, rng: Random)
	for side = -1, 1, 2 do
		local previous: Vector3? = nil
		for index = 0, 7 do
			local spot = at(ctx, side * 12.5, 0, -84 + index * 15)
			local broken = rng:NextNumber() < 0.25
			Props.column(ctx.Scenery, spot, 16, 1.3, MARBLE, TRIM, rng, broken)
			Placer.block(ctx.Placer, spot.X, spot.Z, 4)
			if previous and not broken and rng:NextNumber() < 0.7 then
				local from = previous :: Vector3
				local middle = (from + spot) / 2
				Props.surface(
					ctx.Scenery,
					CFrame.new(middle + Vector3.new(0, 16.7, 0)),
					Vector3.new(3.4, 1.4, 15.6),
					MARBLE,
					"Solid"
				)
			end
			previous = if broken then nil else spot
		end
	end
end

local function monument(ctx: Types.ZoneCtx)
	local center = ctx.Center + MONUMENT
	local tiers = { 44, 32, 20 }
	for index, size in tiers do
		local bottom = (index - 1) * 3
		Props.surface(
			ctx.Scenery,
			CFrame.new(center + Vector3.new(0, bottom + 1.5, 0)),
			Vector3.new(size, 3, size),
			MARBLE,
			"Walk"
		)
		for edge = 0, 3 do
			local frame = CFrame.new(center) * CFrame.Angles(0, edge * math.pi / 2, 0)
			Props.surface(
				ctx.Scenery,
				frame * CFrame.new(0, bottom + 2.8, -size / 2 - 0.15),
				Vector3.new(size + 0.6, 0.5, 0.4),
				TRIM
			)
		end
		-- Stairs up the south face.
		for step = 1, 3 do
			local depth = (3 - step + 0.5) * 1.6
			Props.surface(
				ctx.Scenery,
				CFrame.new(center + Vector3.new(0, bottom + step / 2, -size / 2 - depth)),
				Vector3.new(10, step, 1.6),
				VEINED,
				"Walk"
			)
		end
	end
	runeRing(ctx.Scenery, center + Vector3.new(0, 9, 0), 8, 0.6, MARBLE)
	Props.surface(ctx.Scenery, CFrame.new(center + Vector3.new(0, 11, 0)), Vector3.new(6, 4, 6), VEINED, "Solid")
	Props.surface(ctx.Scenery, CFrame.new(center + Vector3.new(0, 13.2, 0)), Vector3.new(7, 0.5, 7), TRIM, "Solid")

	-- Corner obelisks on the lowest tier.
	for corner = 0, 3 do
		local angle = corner * math.pi / 2 + math.pi / 4
		local spot = center + Vector3.new(math.cos(angle) * 26, 3, math.sin(angle) * 26)
		Props.surface(ctx.Scenery, CFrame.new(spot + Vector3.new(0, 7, 0)), Vector3.new(2.4, 14, 2.4), MARBLE, "Solid")
		Props.surface(
			ctx.Scenery,
			CFrame.new(spot + Vector3.new(0, 14.6, 0)) * CFrame.Angles(0, math.pi / 4, 0),
			Vector3.new(1.8, 1.2, 1.8),
			TRIM
		)
		Kit.block(
			ctx.Scenery,
			CFrame.new(spot + Vector3.new(0, 7, 0)) * CFrame.Angles(0, -angle, 0) * CFrame.new(1.25, 0, 0),
			Vector3.new(0.08, 10, 0.35),
			M.Neon,
			LILAC
		)
	end

	-- Floating giant crystal: two ridged prisms tip to tip around a neon core.
	local float = center + Vector3.new(0, 31, 0)
	local crystal = Kit.model("VaultCrystal")
	Props.shard(crystal, CFrame.new(float), 5.4, 16, M.Glass, LILAC, "Decor", 0.25)
	Props.shard(
		crystal,
		CFrame.new(float) * CFrame.Angles(math.pi, math.pi / 4, 0),
		5.4,
		11,
		M.Glass,
		Kit.tint(LILAC, -0.1),
		"Decor",
		0.25
	)
	local core = Kit.block(
		crystal,
		CFrame.new(float + Vector3.new(0, 2, 0)),
		Vector3.new(2.2, 16, 2.2),
		M.Neon,
		Kit.tint(LILAC, 0.3)
	)
	Kit.pulse(Kit.light(core, LILAC, 60, 2.5), 0.15, 0.2)
	Kit.emitter(core, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(Color3.new(1, 1, 1), LILAC),
		Size = Kit.seq(1, 0.6, 0),
		Transparency = Kit.seq(0, 0.3, 1),
		Lifetime = Kit.range(2.5, 4),
		Rate = 18,
		Speed = Kit.range(2, 5),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
		LightInfluence = 0,
	})
	crystal.WorldPivot = CFrame.new(float)
	Kit.spin(crystal, 10)
	Kit.bob(crystal, 1.6, 0.1)
	Kit.finishModel(crystal, ctx.Scenery, nil, true)
	local hub = CFrame.new(float + Vector3.new(0, 2, 0))
	Props.ring(ctx.Scenery, hub * CFrame.Angles(0.35, 0, 0.15), 12, 18, 0.8, M.Foil, GOLD, 18)
	Props.ring(ctx.Scenery, hub * CFrame.Angles(-0.5, 0.9, 0.3), 15, 20, 0.5, M.Neon, LILAC, -26)
	Props.ring(ctx.Scenery, hub * CFrame.Angles(0.15, 0, 1.25), 18, 24, 0.4, M.Neon, STARLIGHT, 12)
	Placer.nogo(ctx.Placer, center.X, center.Z, 36)
end

local function rotunda(ctx: Types.ZoneCtx, rng: Random)
	local center = ctx.Center + ROTUNDA
	local floor =
		Kit.cylinder(ctx.Scenery, CFrame.new(center + Vector3.new(0, -0.3, 0)), 1, 13, M.Marble, MARBLE.Color, "Walk")
	Props.paint(floor, MARBLE)
	runeRing(ctx.Scenery, center + Vector3.new(0, 0.2, 0), 7, 0.5, VEINED)
	for index = 0, 7 do
		local angle = index / 8 * TAU
		Props.column(
			ctx.Scenery,
			center + Vector3.new(math.cos(angle) * 10.5, 0.2, math.sin(angle) * 10.5),
			14,
			1.1,
			MARBLE,
			TRIM,
			rng,
			false
		)
	end
	Props.ring(ctx.Scenery, CFrame.new(center + Vector3.new(0, 15, 0)), 10.5, 14, 1.6, M.Marble, MARBLE.Color)
	Props.ring(ctx.Scenery, CFrame.new(center + Vector3.new(0, 15.9, 0)), 10.5, 14, 0.4, M.Foil, GOLD)
	Kit.cylinder(ctx.Scenery, CFrame.new(center + Vector3.new(0, 2, 0)), 3.6, 1.4, M.Marble, VEINED.Color, "Solid")
	Props.gem(ctx.Scenery, center + Vector3.new(0, 7, 0), 2.6, LILAC, 45, 0.7, true)
	Props.ring(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 7, 0)) * CFrame.Angles(0.6, 0, 0.3),
		3.4,
		12,
		0.22,
		M.Neon,
		STARLIGHT,
		-70
	)
	Placer.block(ctx.Placer, center.X, center.Z, 15)
end

local function starfall(ctx: Types.ZoneCtx)
	local z = 10
	local lipX = math.sqrt(ctx.Radius ^ 2 - z * z)
	local pool = at(ctx, 106, 0, z)
	Land.pool(pool.X, pool.Z, 8, 0, 4, M.Limestone, M.Water)
	Land.strip(pool, at(ctx, lipX + 6, 0, z), 8, -4, 2, Land.Air)
	Land.strip(pool, at(ctx, lipX - 1, 0, z), 8, -4, -1, M.Water)
	for index = 1, 6 do
		local angle = math.rad(60 + index * 40)
		Props.surface(
			ctx.Scenery,
			CFrame.new(pool + Vector3.new(math.cos(angle) * 9.4, 0.6, math.sin(angle) * 9.4))
				* CFrame.Angles(0, -angle, 0),
			Vector3.new(1.6, 1.6, 4.6),
			MARBLE,
			"Solid"
		)
	end
	Props.waterfall(ctx.Scenery, {
		Lip = at(ctx, lipX - 0.5, -1, z),
		Out = Vector3.new(1, 0, 0),
		Width = 8,
		Drop = 110,
		Color = STARLIGHT,
		Material = M.Neon,
		Mist = Color3.fromRGB(230, 210, 255),
		Spray = Kit.Textures.Sparkles,
	}).Name =
		"Starfall"
	Placer.nogo(ctx.Placer, pool.X, pool.Z, 12)
	Placer.blockLine(ctx.Placer, pool, at(ctx, lipX, 0, z), 7)
end

local function floaters(ctx: Types.ZoneCtx, rng: Random)
	local colors = { LILAC, STARLIGHT, Color3.fromRGB(150, 190, 255) }
	for index = 1, 14 do
		local angle = index / 14 * TAU + rng:NextNumber(-0.15, 0.15)
		local reach = rng:NextNumber(30, 118)
		local spot = ctx.Center + Vector3.new(math.cos(angle) * reach, rng:NextNumber(9, 34), math.sin(angle) * reach)
		Props.gem(
			ctx.Scenery,
			spot,
			rng:NextNumber(1.6, 3.6),
			colors[rng:NextInteger(1, #colors)],
			rng:NextNumber(20, 60),
			rng:NextNumber(0.6, 1.6),
			false
		)
	end
	-- Gold-trimmed ruin blocks drifting just beyond the cliffs.
	for _ = 1, 6 do
		local angle = rng:NextNumber(0, TAU)
		local reach = ctx.Radius + rng:NextNumber(10, 26)
		local x, z = math.cos(angle) * reach, math.sin(angle) * reach
		if math.abs(x) > 40 then
			local block = Props.surface(
				ctx.Scenery,
				CFrame.new(at(ctx, x, rng:NextNumber(-6, 14), z))
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4)),
				Vector3.new(4, 2.4, 3),
				MARBLE,
				"Decor"
			)
			Kit.bob(block, rng:NextNumber(1, 2), rng:NextNumber(0.08, 0.14))
		end
	end
end

local function build(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, TAU)
		local reach = rng:NextNumber(20, 112)
		Land.disc(
			ctx.Center.X + math.cos(angle) * reach,
			ctx.Center.Z + math.sin(angle) * reach,
			rng:NextNumber(6, 14),
			-4,
			0,
			M.Salt
		)
	end
	Land.path({ at(ctx, 0, 0, 24), at(ctx, 0, 0, 30) }, 12, 0, M.Pavement)
	walkway(ctx)
	colonnade(ctx, rng)
	monument(ctx)
	rotunda(ctx, rng)
	starfall(ctx)

	local arches = {
		{ Spot = Vector3.new(-70, 0, -20), Yaw = 0.4 },
		{ Spot = Vector3.new(78, 0, -50), Yaw = -0.7 },
		{ Spot = Vector3.new(-62, 0, 88), Yaw = 1.2 },
	}
	for _, arch in arches do
		local spot = ctx.Center + arch.Spot
		Props.archway(ctx.Scenery, CFrame.new(spot) * CFrame.Angles(0, arch.Yaw, 0), 12, 13, MARBLE, TRIM, rng, 2)
		Placer.block(ctx.Placer, spot.X, spot.Z, 13)
	end
	local circle = at(ctx, -60, 0, 30)
	local disc = Kit.cylinder(
		ctx.Scenery,
		CFrame.new(circle + Vector3.new(0, -0.35, 0)),
		0.8,
		14.6,
		M.Marble,
		MARBLE.Color,
		"Walk"
	)
	Props.paint(disc, MARBLE)
	runeRing(ctx.Scenery, circle + Vector3.new(0, 0.05, 0), 13.6, 0.6, MARBLE)
	for index = 0, 3 do
		Kit.block(
			ctx.Scenery,
			CFrame.new(circle + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, index * math.pi / 4, 0),
			Vector3.new(0.4, 0.06, 24),
			M.Neon,
			LILAC
		)
	end
	Props.gem(ctx.Scenery, circle + Vector3.new(0, 8, 0), 3.4, STARLIGHT, 35, 1.2, false)
	Placer.block(ctx.Placer, circle.X, circle.Z, 15)

	for _, spec in { { Spot = Vector3.new(-96, 0, 40), Height = 26 }, { Spot = Vector3.new(86, 0, -60), Height = 24 } } do
		local spot = ctx.Center + spec.Spot
		Props.crystal(
			ctx.Scenery,
			CFrame.new(spot),
			spec.Height,
			LILAC,
			rng,
			{ Rock = M.Marble, RockColor = Color3.fromRGB(226, 220, 240) }
		)
		Placer.block(ctx.Placer, spot.X, spot.Z, 8)
	end
	floaters(ctx, rng)

	local sky = Kit.block(
		ctx.Scenery,
		CFrame.new(ctx.Center + Vector3.new(0, 40, 0)),
		Vector3.new(260, 60, 260),
		M.Glass,
		STARLIGHT,
		"Ghost"
	)
	Kit.emitter(sky, {
		Texture = Kit.Textures.Sparkles,
		Color = Kit.colors(Color3.new(1, 1, 1), STARLIGHT, LILAC),
		Size = Kit.seq(0, 0.6, 0),
		Transparency = Kit.seq(0.1, 0.2, 1),
		Lifetime = Kit.range(4, 7),
		Rate = 60,
		Speed = Kit.range(0, 0.4),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
		LightInfluence = 0,
	})
	local tops = Land.debris(ctx.Center, ctx.Radius, rng, { M.Limestone, M.Salt, M.Limestone }, 14)
	for index, top in tops do
		if index % 3 == 0 then
			Props.crystal(
				ctx.Scenery,
				CFrame.new(top),
				rng:NextNumber(6, 10),
				LILAC,
				rng,
				{ Light = false, Solid = false, Shards = 3, Rock = M.Marble, RockColor = Color3.fromRGB(226, 220, 240) }
			)
		end
	end
end

local function dress(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	for _ = 1, 10 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 122, Tries = 20 })
		if spot then
			local height = rng:NextNumber(1, 2.4)
			Props.surface(
				ctx.Scenery,
				CFrame.new(spot + Vector3.new(0, height / 2 - 0.2, 0))
					* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
				Vector3.new(rng:NextNumber(2, 3.5), height, rng:NextNumber(2, 3.5)),
				if rng:NextNumber() < 0.5 then MARBLE else VEINED,
				"Solid"
			)
		end
	end
end

local Theme: Types.Theme = {
	Style = {
		Top = M.Limestone,
		Cliff = M.Limestone,
		Strata = M.Salt,
		Under = M.Limestone,
		Deep = M.Salt,
		Lumps = M.Limestone,
	},
	Paving = MARBLE,
	Stone = VEINED,
	Bridge = Color3.fromRGB(176, 150, 122),
	KeepClear = { Vector3.new(126, 0, 10) },
	Markers = false,
	Build = build,
	Dress = dress,
}

return Theme
