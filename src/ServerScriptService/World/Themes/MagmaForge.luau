--!strict
-- Magma Forge: black basalt island with a smoking volcano, lava rivers that pour off both cliffs as
-- lavafalls, lava pools, obsidian spires, basalt columns, glowing cracks and an ancient forge (furnace,
-- chimney, anvils, chains) whose smoke column is visible from the previous island.

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Land = require(World.Land)
local Placer = require(World.Placer)
local Props = require(World.Props)
local Types = require(World.Types)

local M = Enum.Material
local TAU = math.pi * 2
local LAVA = Color3.fromRGB(255, 110, 30)
local EMBER = Color3.fromRGB(255, 176, 80)
local OBSIDIAN = Color3.fromRGB(26, 20, 30)
local IRON = Color3.fromRGB(62, 58, 64)
local BRICK = Color3.fromRGB(112, 58, 46)

local VOLCANO = Vector3.new(-56, 0, 60)
local FORGE = Vector3.new(58, 0, 40)

local function at(ctx: Types.ZoneCtx, x: number, y: number, z: number): Vector3
	return ctx.Center + Vector3.new(x, y, z)
end

-- `up` is the emitting face pointing skywards: Top for blocks, Right for upright cylinders.
local function embers(parent: Instance, rate: number, up: Enum.NormalId)
	Kit.emitter(parent, {
		Texture = Kit.Textures.Fire,
		Color = Kit.colors(EMBER, LAVA),
		Size = Kit.seq(0.5, 0.3, 0),
		Transparency = Kit.seq(0, 0.3, 1),
		Lifetime = Kit.range(1.5, 3),
		Rate = rate,
		Speed = Kit.range(3, 7),
		Spread = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 3, 0),
		Direction = up,
		LightEmission = 1,
		LightInfluence = 0,
	})
end

local function smoke(parent: Instance, rate: number, size: number, up: Enum.NormalId)
	Kit.emitter(parent, {
		Texture = Kit.Textures.Smoke,
		Color = Kit.colors(Color3.fromRGB(70, 60, 60), Color3.fromRGB(40, 36, 40)),
		Size = Kit.seq(size * 0.4, size, size * 1.6),
		Transparency = Kit.seq(0.35, 0.6, 1),
		Lifetime = Kit.range(7, 11),
		Rate = rate,
		Speed = Kit.range(6, 10),
		Spread = Vector2.new(12, 12),
		Acceleration = Vector3.new(1.5, 1, 0.5),
		Direction = up,
		RotSpeed = Kit.range(-20, 20),
	})
end

-- Molten surface: glowing slab a little below ground level in a carved channel or basin.
local function molten(parent: Instance, cf: CFrame, size: Vector3): Part
	local surface = Kit.block(parent, cf, size, M.Neon, LAVA)
	surface.Transparency = 0.08
	return surface
end

local function volcano(ctx: Types.ZoneCtx, rng: Random)
	local center = ctx.Center + VOLCANO
	local layers = {
		{ Radius = 36, Bottom = -4, Top = 8, Material = M.Basalt },
		{ Radius = 28, Bottom = 8, Top = 20, Material = M.Basalt },
		{ Radius = 21, Bottom = 20, Top = 30, Material = M.Rock },
		{ Radius = 15, Bottom = 30, Top = 38, Material = M.Basalt },
	}
	for _, layer in layers do
		Land.disc(center.X, center.Z, layer.Radius, layer.Bottom, layer.Top, layer.Material)
	end
	for index = 1, 8 do
		local angle = index / 8 * TAU + rng:NextNumber(-0.2, 0.2)
		Land.ball(
			center + Vector3.new(math.cos(angle) * 30, rng:NextNumber(2, 10), math.sin(angle) * 30),
			rng:NextNumber(6, 10),
			M.Basalt
		)
	end
	Land.disc(center.X, center.Z, 9, 26, 70, Land.Air)
	Land.disc(center.X, center.Z, 9.5, 22, 26, M.CrackedLava)
	-- Lava streaming down the south-east flank.
	for step = 0, 6 do
		local reach = 10 + step * 4.4
		local height = 37 - step * 5.6
		Land.ball(center + Vector3.new(reach * 0.6, height, -reach * 0.8), 3.2, M.CrackedLava)
	end
	local pool = molten(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 26.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.5, 17.4, 17.4)
	)
	pool.Shape = Enum.PartType.Cylinder
	Kit.pulse(Kit.light(pool, LAVA, 45, 3), 0.4, 0.25)
	local vent = Kit.block(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 30, 0)),
		Vector3.new(10, 2, 10),
		M.Glass,
		LAVA,
		"Ghost"
	)
	smoke(vent, 5, 22, Enum.NormalId.Top)
	embers(vent, 16, Enum.NormalId.Top)
	Placer.nogo(ctx.Placer, center.X, center.Z, 42)
end

local function river(ctx: Types.ZoneCtx, points: { Vector3 }, withLight: boolean)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		Land.strip(a, b, 8, -3, 3, Land.Air)
		Land.strip(a, b, 8, -7, -3, M.CrackedLava)
		local middle = (a + b) / 2
		local surface = molten(
			ctx.Scenery,
			CFrame.lookAt(Vector3.new(middle.X, -1.6, middle.Z), Vector3.new(b.X, -1.6, b.Z)),
			Vector3.new(7.2, 0.4, (b - a).Magnitude + 4)
		)
		if withLight and index == 2 then
			Kit.pulse(Kit.light(surface, LAVA, 30, 2), 0.3, 0.2)
		end
		Placer.blockLine(ctx.Placer, a, b, 7)
	end
end

local function lavafall(ctx: Types.ZoneCtx, z: number, side: number)
	local lipX = side * (math.sqrt(ctx.Radius ^ 2 - z * z) - 0.5)
	local fall = Props.waterfall(ctx.Scenery, {
		Lip = at(ctx, lipX, -1.6, z),
		Out = Vector3.new(side, 0, 0),
		Width = 7,
		Drop = 120,
		Color = LAVA,
		Material = M.Neon,
		Mist = Color3.fromRGB(70, 56, 52),
		Spray = Kit.Textures.Fire,
	})
	fall.Name = "Lavafall"
end

local function lavaPool(ctx: Types.ZoneCtx, spot: Vector3, radius: number, rng: Random)
	Land.pool(spot.X, spot.Z, radius, 0, 3, M.CrackedLava)
	Land.disc(spot.X, spot.Z, radius, -4, -3, M.CrackedLava)
	for index = 1, 8 do
		local angle = index / 8 * TAU + rng:NextNumber(-0.2, 0.2)
		Land.ball(
			spot + Vector3.new(math.cos(angle) * (radius + 1.5), -0.8, math.sin(angle) * (radius + 1.5)),
			rng:NextNumber(1.8, 3),
			M.Basalt
		)
	end
	local surface = molten(
		ctx.Scenery,
		CFrame.new(spot.X, -1.6, spot.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.4, radius * 2, radius * 2)
	)
	surface.Shape = Enum.PartType.Cylinder
	Kit.pulse(Kit.light(surface, LAVA, radius * 3, 2), 0.35, 0.25)
	embers(surface, 6, Enum.NormalId.Right)
	Placer.nogo(ctx.Placer, spot.X, spot.Z, radius + 4)
end

local function forge(ctx: Types.ZoneCtx, rng: Random)
	local base = ctx.Center + FORGE
	local origin = CFrame.lookAt(base, Vector3.new(ctx.Center.X, 0, base.Z))
	local basalt: Types.Surface = { Material = M.Basalt, Color = Color3.fromRGB(64, 56, 58), Variant = "Magma_Basalt" }
	local brick: Types.Surface = { Material = M.Brick, Color = BRICK }
	Props.surface(ctx.Scenery, origin * CFrame.new(0, 0.4, 0), Vector3.new(30, 1.2, 24), basalt, "Walk")
	Props.surface(ctx.Scenery, origin * CFrame.new(0, 8, 7), Vector3.new(14, 14, 10), brick, "Solid")
	Props.surface(ctx.Scenery, origin * CFrame.new(0, 15.3, 7), Vector3.new(15, 0.8, 11), basalt, "Solid")
	local mouth = Kit.block(ctx.Scenery, origin * CFrame.new(0, 4.6, 1.85), Vector3.new(7, 5.4, 0.4), M.Neon, LAVA)
	Kit.fire(mouth, 8, 10, EMBER, LAVA)
	Kit.pulse(Kit.light(mouth, EMBER, 32, 3), 0.8, 0.3)
	for side = -1, 1, 2 do
		Props.surface(
			ctx.Scenery,
			origin * CFrame.new(side * 4.4, 4.6, 1.6),
			Vector3.new(1.6, 6.6, 1.2),
			basalt,
			"Solid"
		)
	end
	Props.surface(ctx.Scenery, origin * CFrame.new(0, 8.3, 1.6), Vector3.new(10.4, 1.6, 1.2), basalt, "Solid")
	local chimneyTop = origin * CFrame.new(3, 47, 9)
	Kit.cylinder(ctx.Scenery, origin * CFrame.new(3, 31, 9), 32, 3.2, M.Brick, BRICK, "Solid")
	local rim = Kit.cylinder(ctx.Scenery, chimneyTop, 0.6, 3.5, M.Neon, LAVA)
	smoke(rim, 6, 16, Enum.NormalId.Right)
	embers(rim, 8, Enum.NormalId.Right)

	Props.anvil(ctx.Scenery, origin * CFrame.new(-6, 1, -5) * CFrame.Angles(0, 0.3, 0))
	Props.anvil(ctx.Scenery, origin * CFrame.new(6, 1, -4) * CFrame.Angles(0, -0.5, 0))
	-- Gantry with hanging chains.
	for side = -1, 1, 2 do
		Kit.block(ctx.Scenery, origin * CFrame.new(side * 12, 7, -7), Vector3.new(0.9, 12, 0.9), M.Metal, IRON, "Solid")
	end
	Kit.block(ctx.Scenery, origin * CFrame.new(0, 13.2, -7), Vector3.new(25, 0.9, 0.9), M.Metal, IRON, "Solid")
	for _, x in { -7, 0, 7 } do
		local links = rng:NextInteger(4, 6)
		for link = 1, links do
			Kit.block(
				ctx.Scenery,
				origin
					* CFrame.new(x, 13 - link * 0.95, -7)
					* CFrame.Angles(0, if link % 2 == 0 then math.pi / 2 else 0, 0),
				Vector3.new(0.7, 1.15, 0.25),
				M.Metal,
				IRON
			)
		end
		Kit.wedge(
			ctx.Scenery,
			origin * CFrame.new(x, 12.4 - links * 0.95, -7) * CFrame.Angles(math.pi, 0, 0),
			Vector3.new(0.4, 0.8, 0.9),
			M.Metal,
			IRON
		)
	end
	-- Quench trough and a glowing coal heap.
	Kit.block(ctx.Scenery, origin * CFrame.new(-10, 1.8, 3), Vector3.new(2.6, 1.6, 5), M.Metal, IRON, "Solid")
	local water = Kit.block(
		ctx.Scenery,
		origin * CFrame.new(-10, 2.55, 3),
		Vector3.new(2.2, 0.15, 4.6),
		M.Glass,
		Color3.fromRGB(90, 160, 200)
	)
	water.Transparency = 0.3
	local heap = (origin * CFrame.new(10, 0, 4)).Position
	Land.ball(heap + Vector3.new(0, -0.5, 0), 3, M.Basalt)
	for _ = 1, 4 do
		Kit.block(
			ctx.Scenery,
			CFrame.new(
				heap + Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(1.6, 2.4), rng:NextNumber(-1.6, 1.6))
			) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0),
			Vector3.new(0.9, 0.7, 0.8),
			M.Neon,
			Kit.vary(LAVA, rng, 0.15)
		)
	end
	Placer.block(ctx.Placer, base.X, base.Z, 21)
end

local function spires(ctx: Types.ZoneCtx, rng: Random)
	for index = 1, 9 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 6, Margin = 3, MinDist = 25, MaxDist = 116, Tries = 30 })
		if spot then
			local height = rng:NextNumber(14, 30)
			local spire = Props.spike(ctx.Scenery, spot, height, rng:NextNumber(3, 4.8), M.Glass, OBSIDIAN, rng, 0)
			if index % 2 == 0 then
				Kit.block(
					ctx.Scenery,
					spire.CFrame * CFrame.new(0, 0, -spire.Size.Z / 2 - 0.05),
					Vector3.new(0.3, spire.Size.Y * 0.8, 0.08),
					M.Neon,
					LAVA
				)
			end
			Props.spike(
				ctx.Scenery,
				spot + Vector3.new(rng:NextNumber(2, 3.5), 0, rng:NextNumber(-3, 3)),
				height * 0.45,
				2.2,
				M.Glass,
				OBSIDIAN,
				rng,
				0
			)
		end
	end
end

local function columns(ctx: Types.ZoneCtx, rng: Random)
	for _ = 1, 3 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 8, Margin = 3, MinDist = 90, MaxDist = 118, Tries = 30 })
		if spot then
			for _ = 1, 7 do
				local offset = Vector3.new(rng:NextNumber(-4.5, 4.5), 0, rng:NextNumber(-4.5, 4.5))
				local height = rng:NextNumber(3, 10)
				Kit.cylinder(
					ctx.Scenery,
					CFrame.new(spot + offset + Vector3.new(0, height / 2 - 0.5, 0)),
					height,
					rng:NextNumber(1.3, 2),
					M.Basalt,
					Kit.vary(Color3.fromRGB(58, 50, 54), rng, 0.1),
					"Solid"
				)
			end
		end
	end
end

local function cracks(ctx: Types.ZoneCtx, rng: Random)
	for _ = 1, 8 do
		local spot = Placer.find(
			ctx.Placer,
			rng,
			{ Clear = 3, Margin = 3, MinDist = 15, MaxDist = 118, Tries = 20, Keep = false }
		)
		if spot then
			local heading = rng:NextNumber(0, TAU)
			local point = spot
			for _ = 1, 3 do
				heading += rng:NextNumber(-0.9, 0.9)
				local length = rng:NextNumber(3, 6)
				local nextPoint = point + Vector3.new(math.cos(heading) * length, 0, math.sin(heading) * length)
				Kit.block(
					ctx.Scenery,
					CFrame.lookAt(
						(point + nextPoint) / 2 + Vector3.new(0, 0.02, 0),
						nextPoint + Vector3.new(0, 0.02, 0)
					),
					Vector3.new(0.4, 0.2, length + 0.3),
					M.Neon,
					Kit.vary(LAVA, rng, 0.1)
				)
				point = nextPoint
			end
		end
	end
end

local function build(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	Land.path(
		{ at(ctx, 0, 0, -ctx.Radius + 6), at(ctx, 3, 0, -10), at(ctx, -2, 0, 60), at(ctx, 0, 0, ctx.Radius - 6) },
		10,
		0,
		M.Asphalt
	)
	volcano(ctx, rng)
	local westZ = -12
	river(
		ctx,
		{
			at(ctx, -36, 0, 36),
			at(ctx, -62, 0, 14),
			at(ctx, -94, 0, -2),
			at(ctx, -math.sqrt(ctx.Radius ^ 2 - westZ ^ 2) + 1, 0, westZ),
		},
		true
	)
	lavafall(ctx, westZ, -1)
	local eastZ = -24
	lavaPool(ctx, at(ctx, 36, 0, -20), 9, rng)
	river(
		ctx,
		{
			at(ctx, 44, 0, -22),
			at(ctx, 72, 0, -32),
			at(ctx, 100, 0, -26),
			at(ctx, math.sqrt(ctx.Radius ^ 2 - eastZ ^ 2) - 1, 0, eastZ),
		},
		false
	)
	lavafall(ctx, eastZ, 1)
	lavaPool(ctx, at(ctx, -30, 0, -60), 8, rng)
	forge(ctx, rng)
	Props.crystal(ctx.Scenery, CFrame.new(at(ctx, -84, 0, -56)), 40, Color3.fromRGB(255, 96, 32), rng, {
		Rock = M.Basalt,
		RockColor = Color3.fromRGB(50, 42, 44),
		Sparkles = true,
		Name = "GiantMagmaCrystal",
	})
	Placer.block(ctx.Placer, ctx.Center.X - 84, ctx.Center.Z - 56, 10)
	Props.crystal(
		ctx.Scenery,
		CFrame.new(at(ctx, 24, 0, 86)),
		24,
		EMBER,
		rng,
		{ Rock = M.Basalt, RockColor = Color3.fromRGB(50, 42, 44) }
	)
	Placer.block(ctx.Placer, ctx.Center.X + 24, ctx.Center.Z + 86, 8)
	spires(ctx, rng)
	columns(ctx, rng)

	local ash = Kit.block(
		ctx.Scenery,
		CFrame.new(ctx.Center + Vector3.new(0, 6, 0)),
		Vector3.new(230, 4, 230),
		M.Glass,
		EMBER,
		"Ghost"
	)
	Kit.emitter(ash, {
		Texture = Kit.Textures.Fire,
		Color = Kit.colors(EMBER, LAVA),
		Size = Kit.seq(0.25, 0.15, 0),
		Transparency = Kit.seq(0, 0.4, 1),
		Lifetime = Kit.range(4, 7),
		Rate = 45,
		Speed = Kit.range(1, 3),
		Spread = Vector2.new(60, 60),
		Acceleration = Vector3.new(0.5, 2, 0.3),
		LightEmission = 1,
		LightInfluence = 0,
	})
	local tops = Land.debris(ctx.Center, ctx.Radius, rng, { M.Basalt, M.Basalt, M.Rock }, 14)
	for index, top in tops do
		if index % 4 == 0 then
			Kit.block(
				ctx.Scenery,
				CFrame.new(top + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
				Vector3.new(0.5, 0.3, 6),
				M.Neon,
				LAVA
			)
		end
	end
end

local function dress(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	cracks(ctx, rng)
	for _ = 1, 12 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 122, Tries = 20 })
		if spot then
			Land.ball(
				spot + Vector3.new(0, -1.2, 0),
				rng:NextNumber(2.4, 4.4),
				if rng:NextNumber() < 0.7 then M.Basalt else M.Rock
			)
		end
	end
end

local Theme: Types.Theme = {
	Style = {
		Top = M.Basalt,
		Cliff = M.Basalt,
		Strata = M.Asphalt,
		Under = M.Rock,
		Deep = M.Basalt,
		Lumps = M.Basalt,
	},
	Paving = { Material = M.Basalt, Color = Color3.fromRGB(62, 54, 56), Variant = "Magma_Basalt" },
	Stone = { Material = M.Slate, Color = Color3.fromRGB(34, 28, 38), Variant = "Magma_Obsidian" },
	Path = M.Asphalt,
	Bridge = Color3.fromRGB(84, 62, 52),
	KeepClear = { Vector3.new(-129, 0, -12), Vector3.new(127, 0, -24) },
	Build = build,
	Dress = dress,
}

return Theme
