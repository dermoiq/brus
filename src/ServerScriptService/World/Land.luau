--!strict
-- Terrain shapes for the floating islands: layered island bodies with stalactite undersides, flat discs,
-- strips (paths, rivers), pools and floating debris. Everything takes world-space coordinates.
-- Terrain voxels are 4 studs, so walkable tops sit on multiples of 4 to stay perfectly flat.

local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)

export type Style = {
	Top: Enum.Material,
	Cliff: Enum.Material,
	Under: Enum.Material,
	Deep: Enum.Material,
	Strata: Enum.Material?,
	Rim: Enum.Material?,
	RimWidth: number?,
	Lumps: Enum.Material?,
	Depth: number?,
}

local Terrain = Workspace.Terrain
local TAU = math.pi * 2
local LAYERS = 9

local Land = {
	Air = Enum.Material.Air,
}

function Land.block(cf: CFrame, size: Vector3, material: Enum.Material)
	Terrain:FillBlock(cf, size, material)
	Kit.Stats.TerrainOps += 1
end

function Land.ball(center: Vector3, radius: number, material: Enum.Material)
	Terrain:FillBall(center, radius, material)
	Kit.Stats.TerrainOps += 1
end

function Land.wedge(cf: CFrame, size: Vector3, material: Enum.Material)
	Terrain:FillWedge(cf, size, material)
	Kit.Stats.TerrainOps += 1
end

-- Upright cylinder between two heights.
function Land.disc(x: number, z: number, radius: number, bottom: number, top: number, material: Enum.Material)
	Terrain:FillCylinder(CFrame.new(x, (bottom + top) / 2, z), top - bottom, radius, material)
	Kit.Stats.TerrainOps += 1
end

-- Flat band from a to b (x/z only) with rounded ends.
function Land.strip(a: Vector3, b: Vector3, width: number, bottom: number, top: number, material: Enum.Material)
	local middle = (bottom + top) / 2
	local from = Vector3.new(a.X, middle, a.Z)
	local to = Vector3.new(b.X, middle, b.Z)
	local length = (to - from).Magnitude
	if length > 0.1 then
		Land.block(CFrame.lookAt((from + to) / 2, to), Vector3.new(width, top - bottom, length), material)
	end
	Land.disc(a.X, a.Z, width / 2, bottom, top, material)
	Land.disc(b.X, b.Z, width / 2, bottom, top, material)
end

function Land.path(points: { Vector3 }, width: number, top: number, material: Enum.Material)
	for index = 1, #points - 1 do
		Land.strip(points[index], points[index + 1], width, top - 4, top, material)
	end
end

-- Basin sunk into a flat top. With a fluid it is filled to one stud below the rim.
function Land.pool(
	x: number,
	z: number,
	radius: number,
	top: number,
	depth: number,
	bed: Enum.Material,
	fluid: Enum.Material?
)
	Land.disc(x, z, radius + 3, top - depth - 4, top - depth, bed)
	Land.disc(x, z, radius, top - depth, top + 10, Land.Air)
	if fluid then
		Land.disc(x, z, radius, top - depth, top - 1, fluid)
	end
end

local function layerRadius(radius: number, index: number): number
	return radius * (1 - index / (LAYERS + 1)) ^ 0.85 + 4
end

-- A floating island whose walkable top is a flat disc at center.Y. Below it the body steps inwards layer by
-- layer (an inverted ziggurat softened by bulges) and ends in stalactites. Rim lumps never rise above the
-- top and skip the bridge landings (±Z) and any keepClear points.
function Land.island(center: Vector3, radius: number, style: Style, rng: Random, keepClear: { Vector3 }?)
	local cx, cy, cz = center.X, center.Y, center.Z
	local depth = style.Depth or 150
	local layerHeight = (depth - 24) / LAYERS

	Land.disc(cx, cz, radius, cy - 24, cy, style.Cliff)
	if style.Strata then
		Land.disc(cx, cz, radius + 1.5, cy - 17, cy - 11, style.Strata)
	end
	if style.Rim then
		Land.disc(cx, cz, radius - 1.5, cy - 4, cy, style.Rim)
		Land.disc(cx, cz, radius - (style.RimWidth or 16), cy - 4, cy, style.Top)
	else
		Land.disc(cx, cz, radius - 2, cy - 4, cy, style.Top)
	end

	local ox, oz = 0, 0
	for index = 1, LAYERS do
		local r = layerRadius(radius, index)
		ox += rng:NextNumber(-1, 1) * radius * 0.02
		oz += rng:NextNumber(-1, 1) * radius * 0.02
		local top = cy - 24 - (index - 1) * layerHeight
		local material = if index <= 3 then style.Cliff elseif index <= 6 then style.Under else style.Deep
		Land.disc(cx + ox, cz + oz, r, top - layerHeight - 1, top + 1, material)
		for _ = 1, 3 do
			local angle = rng:NextNumber(0, TAU)
			local bulge = math.min(r * 0.35, rng:NextNumber(6, 13))
			local reach = r - bulge * 0.5
			Land.ball(
				Vector3.new(cx + ox + math.cos(angle) * reach, top - bulge * 0.7, cz + oz + math.sin(angle) * reach),
				bulge,
				material
			)
		end
	end

	-- Central spike.
	local tipY = cy - depth
	local spike = 10
	while spike > 2 do
		Land.ball(Vector3.new(cx + ox, tipY, cz + oz), spike, style.Deep)
		tipY -= spike * 1.15
		spike *= 0.72
	end

	-- Hanging stalactites, starting from the deepest layer that still covers their spot.
	for _ = 1, 7 do
		local angle = rng:NextNumber(0, TAU)
		local reach = radius * rng:NextNumber(0.2, 0.7)
		local startY = cy - 24
		for index = 1, LAYERS do
			if layerRadius(radius, index) > reach + 6 then
				startY = cy - 24 - index * layerHeight
			end
		end
		local x, z = cx + math.cos(angle) * reach, cz + math.sin(angle) * reach
		local size = rng:NextNumber(6, 10)
		local y = startY + 2
		while size > 1.8 do
			Land.ball(Vector3.new(x, y, z), size, if size > 6 then style.Under else style.Deep)
			y -= size * 1.25
			x += rng:NextNumber(-1, 1)
			z += rng:NextNumber(-1, 1)
			size *= 0.74
		end
	end

	-- Rocky lumps along the cliff edge.
	for index = 1, 18 do
		local angle = index / 18 * TAU + rng:NextNumber(-0.12, 0.12)
		local ux, uz = math.cos(angle), math.sin(angle)
		local px, pz = cx + ux * (radius - 1), cz + uz * (radius - 1)
		local clear = math.abs(ux) >= 0.5
		if clear and keepClear then
			for _, point in keepClear do
				if Vector3.new(point.X - px, 0, point.Z - pz).Magnitude < 34 then
					clear = false
					break
				end
			end
		end
		if clear then
			local size = rng:NextNumber(6, 10)
			Land.ball(Vector3.new(px, cy - size - rng:NextNumber(3, 9), pz), size, style.Lumps or style.Cliff)
		end
	end
end

-- Floating rocks around an island, kept out of the bridge corridor along Z. Returns the top of each rock.
function Land.debris(
	center: Vector3,
	radius: number,
	rng: Random,
	materials: { Enum.Material },
	count: number
): { Vector3 }
	local tops = {}
	local tries = 0
	while #tops < count and tries < count * 8 do
		tries += 1
		local angle = rng:NextNumber(0, TAU)
		local reach = radius + rng:NextNumber(20, 90)
		local x, z = math.cos(angle) * reach, math.sin(angle) * reach
		if math.abs(x) > 56 then
			local size = rng:NextNumber(4, 10)
			local material = materials[rng:NextInteger(1, #materials)]
			local position = center + Vector3.new(x, rng:NextNumber(-95, 25), z)
			Land.ball(position, size, material)
			Land.ball(
				position + Vector3.new(rng:NextNumber(-0.6, 0.6) * size, -size * 0.5, rng:NextNumber(-0.6, 0.6) * size),
				size * 0.65,
				material
			)
			Land.ball(position + Vector3.new(0, -size * 1.15, 0), size * 0.38, material)
			table.insert(tops, position + Vector3.new(0, size * 0.75, 0))
		end
	end
	return tops
end

return Land
