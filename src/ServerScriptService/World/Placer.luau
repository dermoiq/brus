--!strict
-- Finds free, flat, walkable spots on an island. A height model (the plateau plus "Level" areas such as pit
-- floors and cave floors, minus "NoGo" areas such as pools and mesas) says where ground should be; a short
-- downward raycast against Terrain and walkable parts confirms it. Footprints are kept away from feature
-- edges, from each other and from blocked circles (decorations, paths, portals).

local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)

export type Feature = { Kind: "Level" | "NoGo", X: number, Z: number, R: number, Y: number }
export type Circle = { X: number, Z: number, R: number }
export type Placer = {
	Center: Vector3,
	Radius: number,
	Features: { Feature },
	Blocked: { Circle },
}
export type FindOptions = {
	Clear: number, -- radius kept free around the spot (and blocked afterwards unless Keep == false)
	Margin: number?, -- distance kept from feature edges and the island rim
	MinDist: number?, -- annulus around the island centre
	MaxDist: number?,
	Around: Vector3?, -- or: search near this point
	Spread: number?,
	Footprint: number?, -- also probe the corners of a square this wide
	Tries: number?,
	Keep: boolean?,
}

local TAU = math.pi * 2

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local Placer = {}

function Placer.new(center: Vector3, radius: number): Placer
	return { Center = center, Radius = radius, Features = {}, Blocked = {} }
end

-- Flat walkable area at height y (later features override earlier ones).
function Placer.level(placer: Placer, x: number, z: number, radius: number, y: number)
	table.insert(placer.Features, { Kind = "Level", X = x, Z = z, R = radius, Y = y })
end

function Placer.nogo(placer: Placer, x: number, z: number, radius: number)
	table.insert(placer.Features, { Kind = "NoGo", X = x, Z = z, R = radius, Y = 0 })
end

function Placer.block(placer: Placer, x: number, z: number, radius: number)
	table.insert(placer.Blocked, { X = x, Z = z, R = radius })
end

function Placer.blockLine(placer: Placer, a: Vector3, b: Vector3, halfWidth: number)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local steps = math.max(math.ceil(flat.Magnitude / halfWidth), 1)
	for step = 0, steps do
		local point = a + flat * (step / steps)
		Placer.block(placer, point.X, point.Z, halfWidth)
	end
end

function Placer.isFree(placer: Placer, x: number, z: number, radius: number): boolean
	for _, circle in placer.Blocked do
		local dx, dz = x - circle.X, z - circle.Z
		local reach = circle.R + radius
		if dx * dx + dz * dz < reach * reach then
			return false
		end
	end
	return true
end

-- Expected ground height from the height model, or nil if the spot is not flat walkable ground.
function Placer.height(placer: Placer, x: number, z: number, margin: number): number?
	local dx, dz = x - placer.Center.X, z - placer.Center.Z
	local limit = placer.Radius - margin
	if dx * dx + dz * dz > limit * limit then
		return nil
	end
	local height: number? = placer.Center.Y
	for _, feature in placer.Features do
		local distance = math.sqrt((x - feature.X) ^ 2 + (z - feature.Z) ^ 2)
		if feature.Kind == "NoGo" then
			if distance < feature.R + margin then
				height = nil
			end
		elseif math.abs(distance - feature.R) < margin then
			height = nil
		elseif distance < feature.R then
			height = feature.Y
		end
	end
	return height
end

local function probe(x: number, z: number, expected: number): number?
	local result = Workspace:Raycast(Vector3.new(x, expected + 6, z), Vector3.new(0, -14, 0), rayParams)
	if not result then
		-- Nothing to contradict the height model.
		return expected
	end
	local hit = result.Instance
	if not hit:IsA("Terrain") and not Kit.isWalkable(hit) then
		return nil
	end
	if result.Material == Enum.Material.Water or result.Material == Enum.Material.CrackedLava then
		return nil
	end
	if result.Normal.Y < 0.8 or math.abs(result.Position.Y - expected) > 2.5 then
		return nil
	end
	return result.Position.Y
end

-- Confirmed ground height at (x, z); with a footprint the four corners must agree within 1.2 studs.
function Placer.ground(placer: Placer, x: number, z: number, margin: number, footprint: number?): number?
	local expected = Placer.height(placer, x, z, margin)
	if not expected then
		return nil
	end
	local y = probe(x, z, expected)
	if not y or not footprint then
		return y
	end
	local half = footprint / 2
	for _, offset in
		{
			Vector3.new(half, 0, half),
			Vector3.new(-half, 0, half),
			Vector3.new(half, 0, -half),
			Vector3.new(-half, 0, -half),
		}
	do
		local corner = probe(x + offset.X, z + offset.Z, expected)
		if not corner or math.abs(corner - y) > 1.2 then
			return nil
		end
	end
	return y
end

function Placer.find(placer: Placer, rng: Random, options: FindOptions): Vector3?
	local margin = options.Margin or 4
	local maxDist = options.MaxDist or (placer.Radius - margin)
	local minDist = math.min(options.MinDist or 0, maxDist)
	for _ = 1, options.Tries or 40 do
		local angle = rng:NextNumber(0, TAU)
		local x: number, z: number
		local around = options.Around
		if around then
			local reach = math.sqrt(rng:NextNumber(0, 1)) * (options.Spread or 8)
			x, z = around.X + math.cos(angle) * reach, around.Z + math.sin(angle) * reach
		else
			local reach = math.sqrt(rng:NextNumber((minDist / maxDist) ^ 2, 1)) * maxDist
			x, z = placer.Center.X + math.cos(angle) * reach, placer.Center.Z + math.sin(angle) * reach
		end
		if Placer.isFree(placer, x, z, options.Clear) then
			local y = Placer.ground(placer, x, z, margin, options.Footprint)
			if y then
				if options.Keep ~= false then
					Placer.block(placer, x, z, options.Clear)
				end
				return Vector3.new(x, y, z)
			end
		end
	end
	return nil
end

return Placer
