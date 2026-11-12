--!strict
-- Frostfire Rift: snow and glacier island with a snow-capped peak (crystal beacon on top), a frozen lake
-- around a giant ice crystal, a frozen waterfall on the west cliff, ice spikes, snowy pines, a glowing rift
-- crack with blue frostfire braziers, aurora ribbons overhead and drifting snow.

local World = script.Parent.Parent
local Kit = require(World.Kit)
local Land = require(World.Land)
local Placer = require(World.Placer)
local Props = require(World.Props)
local Types = require(World.Types)

local M = Enum.Material
local TAU = math.pi * 2
local ICE = Color3.fromRGB(120, 200, 255)
local FROST = Color3.fromRGB(170, 225, 255)
local SNOW = Color3.fromRGB(242, 247, 255)
local FROSTFIRE = Color3.fromRGB(110, 170, 255)

local PEAK = Vector3.new(56, 0, 56)
local LAKE = Vector3.new(-58, 0, 52)

local function at(ctx: Types.ZoneCtx, x: number, y: number, z: number): Vector3
	return ctx.Center + Vector3.new(x, y, z)
end

local function mountain(ctx: Types.ZoneCtx, rng: Random)
	local center = ctx.Center + PEAK
	local layers = {
		{ Radius = 40, Bottom = -4, Top = 8, Material = M.Rock },
		{ Radius = 32, Bottom = 8, Top = 20, Material = M.Rock },
		{ Radius = 24, Bottom = 20, Top = 30, Material = M.Snow },
		{ Radius = 17, Bottom = 30, Top = 40, Material = M.Snow },
		{ Radius = 11, Bottom = 40, Top = 50, Material = M.Snow },
		{ Radius = 6, Bottom = 50, Top = 58, Material = M.Snow },
	}
	for _, layer in layers do
		Land.disc(center.X, center.Z, layer.Radius, layer.Bottom, layer.Top, layer.Material)
	end
	for index = 1, 8 do
		local angle = index / 8 * TAU + rng:NextNumber(-0.2, 0.2)
		local reach = rng:NextNumber(26, 36)
		Land.ball(
			center + Vector3.new(math.cos(angle) * reach, rng:NextNumber(4, 12), math.sin(angle) * reach),
			rng:NextNumber(7, 11),
			if index % 2 == 0 then M.Snow else M.Rock
		)
	end
	for index = 1, 5 do
		local angle = index / 5 * TAU
		Land.ball(
			center + Vector3.new(math.cos(angle) * 20, rng:NextNumber(20, 30), math.sin(angle) * 20),
			rng:NextNumber(5, 8),
			M.Glacier
		)
	end
	Placer.nogo(ctx.Placer, center.X, center.Z, 46)
	Props.crystal(
		ctx.Scenery,
		CFrame.new(center + Vector3.new(0, 57, 0)),
		16,
		ICE,
		rng,
		{ Rock = M.Slate, Sparkles = true, Name = "PeakBeacon" }
	)
end

local function lake(ctx: Types.ZoneCtx, rng: Random)
	local center = ctx.Center + LAKE
	Land.disc(center.X, center.Z, 24, -4, 0, M.Ice)
	Land.disc(center.X, center.Z, 27, -4, -1, M.Glacier)
	for index = 1, 9 do
		local angle = index / 9 * TAU + rng:NextNumber(-0.15, 0.15)
		Land.ball(
			center + Vector3.new(math.cos(angle) * 26, -0.8, math.sin(angle) * 26),
			rng:NextNumber(2.4, 4),
			M.Snow
		)
	end
	Props.crystal(
		ctx.Scenery,
		CFrame.new(center),
		44,
		ICE,
		rng,
		{ Rock = M.Slate, RockColor = Color3.fromRGB(110, 130, 150), Sparkles = true, Name = "GiantIceCrystal" }
	)
	Placer.block(ctx.Placer, center.X, center.Z, 10)
end

local function frozenFall(ctx: Types.ZoneCtx, rng: Random)
	local z = -20
	local lipX = -math.sqrt(ctx.Radius ^ 2 - z * z)
	local pool = at(ctx, -102, 0, z)
	Land.disc(pool.X, pool.Z, 9, -4, 0, M.Ice)
	Land.strip(pool, at(ctx, lipX, 0, z), 8, -4, 0, M.Ice)
	local curtain =
		Kit.block(ctx.Scenery, CFrame.new(at(ctx, lipX - 1.4, -16, z)), Vector3.new(0.8, 32, 12), M.Glacier, FROST)
	curtain.Transparency = 0.35
	for index = 1, 10 do
		local length = rng:NextNumber(14, 60)
		local width = rng:NextNumber(2, 4.5)
		local offset = rng:NextNumber(-6, 6)
		local top = at(ctx, lipX - 2 - rng:NextNumber(0, 1.5), -0.5, z + offset)
		local column = Kit.block(
			ctx.Scenery,
			CFrame.new(top - Vector3.new(0, length / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			Vector3.new(width, length, width),
			M.Ice,
			Kit.vary(FROST, rng, 0.06)
		)
		column.Transparency = 0.15
		column.Reflectance = 0.2
		if index % 2 == 0 then
			local tip = Kit.wedge(
				ctx.Scenery,
				CFrame.new(top - Vector3.new(0, length + 1.5, 0)) * CFrame.Angles(math.pi, 0, 0),
				Vector3.new(width, 3, width),
				M.Ice,
				Kit.vary(FROST, rng, 0.06)
			)
			tip.Transparency = 0.15
		end
	end
	local mist =
		Kit.block(ctx.Scenery, CFrame.new(at(ctx, lipX - 3, -6, z)), Vector3.new(4, 4, 14), M.Glass, FROST, "Ghost")
	Kit.emitter(mist, {
		Texture = Kit.Textures.Smoke,
		Color = Kit.colors(Color3.fromRGB(230, 244, 255)),
		Size = Kit.seq(4, 9, 14),
		Transparency = Kit.seq(0.6, 0.8, 1),
		Lifetime = Kit.range(4, 6),
		Rate = 6,
		Speed = Kit.range(1, 3),
		Direction = Enum.NormalId.Bottom,
		Spread = Vector2.new(40, 40),
	})
	Placer.nogo(ctx.Placer, pool.X, pool.Z, 12)
end

local function rift(ctx: Types.ZoneCtx)
	local points =
		{ at(ctx, 24, 0, -86), at(ctx, 40, 0, -64), at(ctx, 33, 0, -40), at(ctx, 52, 0, -20), at(ctx, 47, 0, 2) }
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local middle = (a + b) / 2
		local length = (b - a).Magnitude + 1
		local frame = CFrame.lookAt(middle, b)
		Kit.block(ctx.Scenery, frame * CFrame.new(0, 0.04, 0), Vector3.new(1, 0.22, length), M.Neon, ICE)
		Kit.block(
			ctx.Scenery,
			frame * CFrame.new(0.9, 0.03, 0),
			Vector3.new(0.35, 0.2, length * 0.8),
			M.Neon,
			Color3.fromRGB(255, 150, 90)
		)
		Placer.blockLine(ctx.Placer, a, b, 4)
	end
	for index = 2, 4, 2 do
		local spot = points[index]
		local mist = Kit.block(
			ctx.Scenery,
			CFrame.new(spot + Vector3.new(0, 1, 0)),
			Vector3.new(14, 1, 14),
			M.Glass,
			ICE,
			"Ghost"
		)
		Kit.emitter(mist, {
			Texture = Kit.Textures.Smoke,
			Color = Kit.colors(Color3.fromRGB(160, 220, 255)),
			Size = Kit.seq(2, 5, 8),
			Transparency = Kit.seq(0.5, 0.75, 1),
			Lifetime = Kit.range(3, 5),
			Rate = 5,
			Speed = Kit.range(1, 2),
			LightEmission = 0.4,
		})
	end
	-- Frostfire braziers either side of the path near the arrival.
	for side = -1, 1, 2 do
		local base = at(ctx, side * 11, 0, -96)
		Kit.cylinder(
			ctx.Scenery,
			CFrame.new(base + Vector3.new(0, 1.5, 0)),
			3,
			1.2,
			M.Slate,
			Color3.fromRGB(70, 84, 104),
			"Solid"
		)
		local bowl = Kit.cylinder(
			ctx.Scenery,
			CFrame.new(base + Vector3.new(0, 3.4, 0)),
			0.8,
			2.2,
			M.Metal,
			Color3.fromRGB(90, 110, 140),
			"Solid"
		)
		Kit.fire(bowl, 5, 9, FROSTFIRE, Color3.fromRGB(60, 90, 255))
		Kit.pulse(Kit.light(bowl, FROSTFIRE, 22, 1.8), 1.1, 0.2)
		Placer.block(ctx.Placer, base.X, base.Z, 4)
	end
end

local function aurora(ctx: Types.ZoneCtx, rng: Random)
	local anchor = Kit.block(ctx.Scenery, CFrame.new(at(ctx, 0, 140, 20)), Vector3.new(1, 1, 1), M.Glass, ICE, "Ghost")
	anchor.Name = "AuroraAnchor"
	local colors = Kit.colors(Color3.fromRGB(90, 255, 170), Color3.fromRGB(90, 220, 255), Color3.fromRGB(176, 120, 255))
	for index = 1, 4 do
		local start = Instance.new("Attachment")
		start.CFrame = CFrame.new(-170, index * 6 - 10, -70 + index * 34) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
		start.Parent = anchor
		local finish = Instance.new("Attachment")
		finish.CFrame = CFrame.new(170, index * 4 - 6, -40 + index * 30) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
		finish.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = start
		beam.Attachment1 = finish
		beam.Color = colors
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.8, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Width0 = rng:NextNumber(30, 45)
		beam.Width1 = rng:NextNumber(40, 60)
		beam.CurveSize0 = rng:NextNumber(40, 90)
		beam.CurveSize1 = -rng:NextNumber(40, 90)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 40
		beam.Parent = anchor
	end
end

local function snowfall(ctx: Types.ZoneCtx)
	for side = -1, 1, 2 do
		local cloud = Kit.block(
			ctx.Scenery,
			CFrame.new(at(ctx, side * 65, 70, 0)),
			Vector3.new(130, 1, 270),
			M.Glass,
			SNOW,
			"Ghost"
		)
		Kit.emitter(cloud, {
			Texture = Kit.Textures.Smoke,
			Color = Kit.colors(SNOW),
			Size = Kit.seq(0.35, 0.3),
			Transparency = Kit.seq(0.1, 0.2, 1),
			Lifetime = Kit.range(10, 14),
			Rate = 50,
			Speed = Kit.range(4, 7),
			Direction = Enum.NormalId.Bottom,
			Spread = Vector2.new(15, 15),
			Acceleration = Vector3.new(2, -1, 1),
			RotSpeed = Kit.range(-60, 60),
		})
	end
end

local function snowman(ctx: Types.ZoneCtx, ground: Vector3, facingAngle: number)
	local frame = CFrame.new(ground) * CFrame.Angles(0, facingAngle, 0)
	Kit.ball(ctx.Scenery, (frame * CFrame.new(0, 1.8, 0)).Position, 2.2, M.Snow, SNOW, "Solid")
	Kit.ball(ctx.Scenery, (frame * CFrame.new(0, 4.8, 0)).Position, 1.6, M.Snow, SNOW, "Solid")
	Kit.ball(ctx.Scenery, (frame * CFrame.new(0, 7, 0)).Position, 1.1, M.Snow, SNOW)
	Kit.wedge(
		ctx.Scenery,
		frame * CFrame.new(0, 7, -1.5) * CFrame.Angles(math.pi / 2, 0, 0),
		Vector3.new(0.4, 1.4, 0.4),
		M.Fabric,
		Color3.fromRGB(255, 140, 50)
	)
	for side = -1, 1, 2 do
		Kit.block(
			ctx.Scenery,
			frame * CFrame.new(side * 0.4, 7.4, -0.95),
			Vector3.new(0.25, 0.25, 0.25),
			M.Slate,
			Color3.fromRGB(30, 30, 36)
		)
	end
	Kit.block(
		ctx.Scenery,
		frame * CFrame.new(0, 6.1, 0),
		Vector3.new(2.6, 0.5, 2.6),
		M.Fabric,
		Color3.fromRGB(200, 60, 70)
	)
	Placer.block(ctx.Placer, ground.X, ground.Z, 4)
end

-- Walk-in igloo (hollow terrain dome) with its doorway facing the island centre, plus a sled.
local function igloo(ctx: Types.ZoneCtx, rng: Random)
	local spot = Placer.find(ctx.Placer, rng, { Clear = 13, Margin = 4, MinDist = 40, MaxDist = 100, Tries = 40 })
	if not spot then
		return
	end
	Land.ball(spot + Vector3.new(0, -1, 0), 9, M.Snow)
	Land.ball(spot + Vector3.new(0, -1, 0), 7.2, Land.Air)
	Land.disc(spot.X, spot.Z, 8, -8, 0, M.Snow)
	local toward = Vector3.new(ctx.Center.X - spot.X, 0, ctx.Center.Z - spot.Z).Unit
	local door = spot + toward * 8.5 + Vector3.new(0, 2.5, 0)
	Land.block(CFrame.lookAt(door, door + toward), Vector3.new(4.5, 5, 7), Land.Air)
	Props.lantern(ctx.Scenery, spot + Vector3.new(0, 6, 0), ICE, false)
	local side = Vector3.new(toward.Z, 0, -toward.X)
	local sled =
		CFrame.lookAt(spot + side * 11 + Vector3.new(0, 0.5, 0), spot + side * 11 + toward + Vector3.new(0, 0.5, 0))
	for offset = -1, 1, 2 do
		Kit.block(
			ctx.Scenery,
			sled * CFrame.new(offset * 1.1, 0, 0),
			Vector3.new(0.3, 0.4, 5.4),
			M.Wood,
			Color3.fromRGB(110, 76, 52),
			"Solid"
		)
	end
	Kit.block(
		ctx.Scenery,
		sled * CFrame.new(0, 0.6, 0.2),
		Vector3.new(2.8, 0.3, 4.2),
		M.WoodPlanks,
		Color3.fromRGB(176, 60, 56),
		"Solid"
	)
	Placer.nogo(ctx.Placer, spot.X, spot.Z, 12)
	Placer.block(ctx.Placer, spot.X + side.X * 11, spot.Z + side.Z * 11, 4)
end

local function build(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	Land.path(
		{ at(ctx, 0, 0, -ctx.Radius + 6), at(ctx, -3, 0, -20), at(ctx, 3, 0, 60), at(ctx, 0, 0, ctx.Radius - 6) },
		10,
		0,
		M.Cobblestone
	)
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, TAU)
		local reach = rng:NextNumber(20, 112)
		Land.disc(
			ctx.Center.X + math.cos(angle) * reach,
			ctx.Center.Z + math.sin(angle) * reach,
			rng:NextNumber(6, 14),
			-4,
			0,
			M.Glacier
		)
	end
	mountain(ctx, rng)
	lake(ctx, rng)
	frozenFall(ctx, rng)
	rift(ctx)
	aurora(ctx, rng)
	snowfall(ctx)
	Props.crystal(
		ctx.Scenery,
		CFrame.new(at(ctx, -90, 0, -60)),
		22,
		FROST,
		rng,
		{ Rock = M.Slate, Name = "IceCrystal" }
	)
	Placer.block(ctx.Placer, ctx.Center.X - 90, ctx.Center.Z - 60, 8)
	snowman(ctx, at(ctx, 16, 0, -92), 0.4)
	snowman(ctx, at(ctx, -38, 0, 14), -0.9)
	igloo(ctx, rng)

	for _ = 1, 9 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 6, Margin = 3, MinDist = 25, MaxDist = 116, Tries = 30 })
		if spot then
			for _ = 1, 3 do
				local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
				Props.spike(
					ctx.Scenery,
					spot + offset,
					rng:NextNumber(5, 15),
					rng:NextNumber(1.4, 2.8),
					M.Ice,
					Kit.vary(FROST, rng, 0.08),
					rng,
					0.12
				)
			end
		end
	end
	local tops = Land.debris(ctx.Center, ctx.Radius, rng, { M.Glacier, M.Rock, M.Snow }, 14)
	for index, top in tops do
		if index % 3 == 0 then
			Props.spike(ctx.Scenery, top, rng:NextNumber(5, 9), 1.8, M.Ice, FROST, rng, 0.12)
		end
	end
end

local function dress(ctx: Types.ZoneCtx)
	local rng = ctx.Rng
	for _ = 1, 18 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 5.5, Margin = 3, MinDist = 18, MaxDist = 122, Tries = 25 })
		if spot then
			Props.pine(ctx.Scenery, spot, rng, rng:NextNumber(0.9, 1.5), true)
		end
	end
	for _ = 1, 10 do
		local spot = Placer.find(ctx.Placer, rng, { Clear = 4, Margin = 3, MinDist = 15, MaxDist = 122, Tries = 20 })
		if spot then
			Land.ball(
				spot + Vector3.new(0, -1.2, 0),
				rng:NextNumber(2.4, 4.2),
				if rng:NextNumber() < 0.6 then M.Snow else M.Rock
			)
		end
	end
end

local Theme: Types.Theme = {
	Style = {
		Top = M.Snow,
		Cliff = M.Glacier,
		Strata = M.Rock,
		Under = M.Rock,
		Deep = M.Glacier,
		Lumps = M.Ice,
	},
	Paving = { Material = M.Snow, Color = Color3.fromRGB(234, 242, 252), Variant = "Frost_PackedSnow" },
	Stone = { Material = M.Glacier, Color = Color3.fromRGB(168, 208, 236), Variant = "Frost_Glacier" },
	Bridge = Color3.fromRGB(150, 132, 116),
	KeepClear = { Vector3.new(-128, 0, -20) },
	Build = build,
	Dress = dress,
}

return Theme
