--!strict
-- Procedural pickaxe models, one builder per Items Style. The Handle is the shaft: built at the origin, running
-- along +Y and held near its lower end. The head crosses Z at the top of the shaft so it lies in the swing plane
-- (-Z is the front point). Every other part is placed in Handle space, then welded to the Handle.

local Items = require(game:GetService("ReplicatedStorage").Shared.Config.Items)

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local WHITE = Color3.new(1, 1, 1)
-- Turn local -Z (the axis spikes and hooks grow along) to face straight up or down.
local POINT_UP = CFrame.Angles(math.pi / 2, 0, 0)
local POINT_DOWN = CFrame.Angles(-math.pi / 2, 0, 0)
-- A square cross-section turned 45 degrees about X reads as a diamond from the sides.
local DIAMOND = CFrame.Angles(math.pi / 4, 0, 0)
local ROLL_45 = CFrame.Angles(0, 0, math.pi / 4)

type Look = {
	Color: Color3,
	Material: Enum.Material,
	Transparency: number?,
}

type Builder = {
	tool: Tool,
	handle: Part,
	-- Head tips that anchor the swing trail.
	tipA: Vector3,
	tipB: Vector3,
	trail: ColorSequence?,
}

type Piece = {
	Kind: "Block" | "Spike" | "Hook",
	Droop: number,
	Size: Vector3,
	Look: Look,
	Under: Look?,
	Roll: number?,
}

type EmitterSpec = {
	Texture: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence?,
	Lifetime: NumberRange,
	Rate: number,
	Speed: NumberRange,
	SpreadAngle: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	RotSpeed: NumberRange?,
	LightEmission: number?,
	LockedToPart: boolean?,
	Shape: Enum.ParticleEmitterShape?,
	ShapeStyle: Enum.ParticleEmitterShapeStyle?,
	ShapeInOut: Enum.ParticleEmitterShapeInOut?,
}

local PickaxeBuilder = {}

local function look(color: Color3, material: Enum.Material, transparency: number?): Look
	return { Color = color, Material = material, Transparency = transparency }
end

local function neon(color: Color3): Look
	return look(color, Enum.Material.Neon)
end

local function sequence(first: number, middle: number, last: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, first),
		NumberSequenceKeypoint.new(0.5, middle),
		NumberSequenceKeypoint.new(1, last),
	})
end

-- Pops in fast and shrinks away, which reads as a twinkle.
local function twinkle(size: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, size),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function gradient(first: Color3, middle: Color3, last: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, first),
		ColorSequenceKeypoint.new(0.5, middle),
		ColorSequenceKeypoint.new(1, last),
	})
end

local function dress(part: BasePart, name: string, size: Vector3, cframe: CFrame, style: Look)
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = style.Color
	part.Material = style.Material
	part.Transparency = style.Transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function newBuilder(shaftSize: Vector3, style: Look): Builder
	local tool = Instance.new("Tool")
	tool.Grip = CFrame.new(0, -1, 0)

	local handle = Instance.new("Part")
	dress(handle, "Handle", shaftSize, CFrame.new(), style)
	handle.Parent = tool

	return {
		tool = tool,
		handle = handle,
		tipA = Vector3.new(0, 1.6, -1.5),
		tipB = Vector3.new(0, 1.6, 1.5),
	}
end

local function attach(b: Builder, part: BasePart, name: string, size: Vector3, cframe: CFrame, style: Look)
	dress(part, name, size, cframe, style)
	part.Parent = b.tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.handle
	weld.Part1 = part
	weld.Parent = part
end

local function block(b: Builder, name: string, size: Vector3, cframe: CFrame, style: Look): Part
	local part = Instance.new("Part")
	attach(b, part, name, size, cframe, style)
	return part
end

local function wedge(b: Builder, name: string, size: Vector3, cframe: CFrame, style: Look): WedgePart
	local part = Instance.new("WedgePart")
	attach(b, part, name, size, cframe, style)
	return part
end

local function ball(b: Builder, name: string, diameter: number, position: Vector3, style: Look): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	attach(b, part, name, Vector3.one * diameter, CFrame.new(position), style)
	return part
end

-- Round collar around the shaft. Cylinders run along local X, so it is stood upright.
local function ring(b: Builder, name: string, y: number, height: number, diameter: number, style: Look): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local cframe = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
	attach(b, part, name, Vector3.new(height, diameter, diameter), cframe, style)
	return part
end

local function band(b: Builder, name: string, y: number, height: number, width: number, style: Look): Part
	return block(b, name, Vector3.new(width, height, width), CFrame.new(0, y, 0), style)
end

-- Invisible box spanning the head so emitters spawn particles along its whole length.
local function fxVolume(b: Builder, size: Vector3, position: Vector3): Part
	return block(b, "FXVolume", size, CFrame.new(position), look(WHITE, Enum.Material.Glass, 1))
end

-- Two mirrored wedges forming a sharpened point that grows size.Z along the frame's -Z. Returns the tip.
local function spike(b: Builder, name: string, frame: CFrame, size: Vector3, style: Look, under: Look?): Vector3
	local half = Vector3.new(size.X, size.Y / 2, size.Z)
	wedge(b, name .. "Top", half, frame * CFrame.new(0, size.Y / 4, -size.Z / 2), style)
	local flipped = frame * CFrame.new(0, -size.Y / 4, -size.Z / 2) * CFrame.Angles(0, 0, math.pi)
	wedge(b, name .. "Bottom", half, flipped, under or style)
	return frame * Vector3.new(0, 0, -size.Z)
end

-- One wedge whose flat underside continues the frame's lower edge, so the point hooks down to it. Returns the tip.
local function hook(b: Builder, name: string, frame: CFrame, size: Vector3, style: Look): Vector3
	wedge(b, name, size, frame * CFrame.new(0, 0, -size.Z / 2), style)
	return frame * Vector3.new(0, -size.Y / 2, -size.Z)
end

-- Frame at `position` whose -Z runs outward along one arm of the head (side -1 toward -Z, 1 toward +Z), tilted
-- down by `droop` degrees (negative tilts up). Its +Y is the arm's upper edge.
local function armFrame(side: number, position: Vector3, droop: number): CFrame
	local frame = CFrame.new(position) * CFrame.Angles(math.rad(side * droop), 0, 0)
	return if side > 0 then frame * CFrame.Angles(0, math.pi, 0) else frame
end

local function blockPiece(droop: number, size: Vector3, style: Look, roll: number?): Piece
	return { Kind = "Block", Droop = droop, Size = size, Look = style, Roll = roll }
end

local function spikePiece(droop: number, size: Vector3, style: Look, under: Look?, roll: number?): Piece
	return { Kind = "Spike", Droop = droop, Size = size, Look = style, Under = under, Roll = roll }
end

local function hookPiece(droop: number, size: Vector3, style: Look): Piece
	return { Kind = "Hook", Droop = droop, Size = size, Look = style }
end

-- Builds one arm of the head outward from `start` as a chain of pieces. Each joint pivots on the outer edge of its
-- bend, so the chain curves without opening gaps. Returns the tip and each piece's base frame for decorations.
local function arm(b: Builder, name: string, side: number, start: Vector3, pieces: { Piece }): (Vector3, { CFrame })
	local frames: { CFrame } = {}
	local frame = armFrame(side, start, pieces[1].Droop)
	local tip = start
	for index, piece in pieces do
		if index > 1 then
			local previous = pieces[index - 1]
			local rotation = armFrame(side, Vector3.zero, piece.Droop)
			local edge = if piece.Droop >= previous.Droop then 1 else -1
			local pivot = frame * Vector3.new(0, edge * previous.Size.Y / 2, -previous.Size.Z)
			frame = CFrame.new(pivot - rotation.UpVector * (edge * piece.Size.Y / 2)) * rotation
		end
		frames[index] = frame

		local placed = if piece.Roll then frame * CFrame.Angles(0, 0, math.rad(piece.Roll)) else frame
		local partName = name .. index
		if piece.Kind == "Spike" then
			tip = spike(b, partName, placed, piece.Size, piece.Look, piece.Under)
		elseif piece.Kind == "Hook" then
			tip = hook(b, partName, placed, piece.Size, piece.Look)
		else
			block(b, partName, piece.Size, placed * CFrame.new(0, 0, -piece.Size.Z / 2), piece.Look)
			tip = frame * Vector3.new(0, 0, -piece.Size.Z)
		end
	end
	return tip, frames
end

-- Mirrored arms on both sides of the head; `start` is the +Z side's start. Records both tips for the trail.
local function arms(b: Builder, start: Vector3, pieces: { Piece }): ({ CFrame }, { CFrame })
	local tipA, framesA = arm(b, "PointA", -1, Vector3.new(start.X, start.Y, -start.Z), pieces)
	local tipB, framesB = arm(b, "PointB", 1, start, pieces)
	b.tipA = tipA
	b.tipB = tipB
	return framesA, framesB
end

local function addLight(parent: BasePart, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addEmitter(parent: BasePart, name: string, spec: EmitterSpec): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = spec.Texture
	emitter.Color = spec.Color
	emitter.Size = spec.Size
	emitter.Transparency = spec.Transparency or NumberSequence.new(0, 1)
	emitter.Lifetime = spec.Lifetime
	emitter.Rate = spec.Rate
	emitter.Speed = spec.Speed
	emitter.SpreadAngle = spec.SpreadAngle or Vector2.new(180, 180)
	emitter.Acceleration = spec.Acceleration or Vector3.zero
	emitter.Drag = spec.Drag or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = spec.RotSpeed or NumberRange.new(-30, 30)
	emitter.LightEmission = spec.LightEmission or 1
	emitter.LightInfluence = 0
	emitter.LockedToPart = spec.LockedToPart or false
	emitter.Shape = spec.Shape or Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = spec.ShapeStyle or Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = spec.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	emitter.Parent = parent
	return emitter
end

-- Ribbon spanning the two head tips. It sweeps a wide arc during a swing and stays thin while walking forward.
local function addTrail(b: Builder, def: Items.ItemDef)
	local tipA = Instance.new("Attachment")
	tipA.Name = "TrailTipA"
	tipA.Position = b.tipA
	tipA.Parent = b.handle

	local tipB = Instance.new("Attachment")
	tipB.Name = "TrailTipB"
	tipB.Position = b.tipB
	tipB.Parent = b.handle

	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = tipA
	trail.Attachment1 = tipB
	trail.Lifetime = math.min(0.25, 0.15 + def.Order * 0.01)
	trail.MinLength = 0.05
	trail.FaceCamera = false
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = b.trail or ColorSequence.new(def.Color, def.Color:Lerp(WHITE, 0.5))
	trail.Transparency = sequence(0.15, 0.55, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = b.handle
end

local function buildRusty(def: Items.ItemDef): Builder
	local rust = look(def.Color, Enum.Material.CorrodedMetal)
	local rustDark = look(def.Color:Lerp(Color3.fromRGB(46, 30, 22), 0.45), Enum.Material.CorrodedMetal)
	local wood = look(Color3.fromRGB(122, 96, 70), Enum.Material.Wood)
	local woodPale = look(Color3.fromRGB(156, 128, 96), Enum.Material.Wood)
	local cloth = look(Color3.fromRGB(172, 152, 118), Enum.Material.Fabric)
	local clothDark = look(Color3.fromRGB(118, 100, 78), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.32, 3.4, 0.32), wood)

	-- Splintered shaft: two peeling slivers and a broken, jagged butt end.
	block(
		b,
		"SplinterA",
		Vector3.new(0.06, 0.6, 0.09),
		CFrame.new(0.16, 0.55, 0.05) * CFrame.Angles(0, 0, math.rad(-7)),
		woodPale
	)
	block(
		b,
		"SplinterB",
		Vector3.new(0.08, 0.5, 0.06),
		CFrame.new(0.04, -0.12, -0.16) * CFrame.Angles(math.rad(8), 0, 0),
		woodPale
	)
	hook(b, "SplinterEndA", CFrame.new(0.07, -1.68, 0.06) * POINT_DOWN, Vector3.new(0.14, 0.16, 0.26), woodPale)
	hook(
		b,
		"SplinterEndB",
		CFrame.new(-0.08, -1.68, -0.05) * POINT_DOWN * CFrame.Angles(0, 0, math.pi),
		Vector3.new(0.14, 0.16, 0.18),
		wood
	)

	-- Loosely wound cloth grip and a rag binding under the head.
	block(b, "Wrap", Vector3.new(0.38, 0.9, 0.38), CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(6), 0), cloth)
	block(
		b,
		"WrapBand",
		Vector3.new(0.41, 0.14, 0.41),
		CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(5), math.rad(20), 0),
		clothDark
	)
	block(
		b,
		"WrapTail",
		Vector3.new(0.05, 0.42, 0.14),
		CFrame.new(0.21, -1.5, 0.04) * CFrame.Angles(0, 0, math.rad(10)),
		cloth
	)
	block(
		b,
		"Binding",
		Vector3.new(0.42, 0.26, 0.42),
		CFrame.new(0, 1.18, 0) * CFrame.Angles(0, math.rad(12), math.rad(3)),
		clothDark
	)

	block(b, "Head", Vector3.new(0.46, 0.56, 0.7), CFrame.new(0, 1.6, 0), rust)
	block(b, "Pin", Vector3.new(0.52, 0.1, 0.1), CFrame.new(0, 1.66, -0.2), rustDark)
	b.tipA = arm(b, "PointA", -1, Vector3.new(0, 1.6, -0.33), {
		blockPiece(8, Vector3.new(0.4, 0.46, 0.55), rust),
		spikePiece(22, Vector3.new(0.36, 0.42, 0.68), rust, rustDark),
	})
	-- The back point snapped off, leaving a stepped, chipped stub.
	b.tipB = arm(b, "Broken", 1, Vector3.new(0, 1.6, 0.33), {
		blockPiece(10, Vector3.new(0.4, 0.46, 0.5), rust),
		blockPiece(20, Vector3.new(0.36, 0.38, 0.24), rustDark),
		hookPiece(34, Vector3.new(0.34, 0.2, 0.2), rust),
	})
	return b
end

local function buildIron(def: Items.ItemDef): Builder
	local steel = look(def.Color, Enum.Material.Metal)
	local steelDark = look(def.Color:Lerp(Color3.fromRGB(40, 44, 52), 0.45), Enum.Material.Metal)
	local plate = look(def.Color:Lerp(Color3.fromRGB(40, 44, 52), 0.2), Enum.Material.DiamondPlate)
	local wood = look(Color3.fromRGB(116, 76, 46), Enum.Material.Wood)
	local leather = look(Color3.fromRGB(86, 54, 36), Enum.Material.Fabric)
	local leatherDark = look(Color3.fromRGB(54, 34, 22), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), wood)

	band(b, "PommelCap", -1.76, 0.2, 0.42, steel)
	band(b, "PommelTip", -1.92, 0.12, 0.3, steelDark)
	block(b, "Grip", Vector3.new(0.4, 1.3, 0.4), CFrame.new(0, -0.95, 0), leather)
	for index, y in { -1.4, -0.95, -0.5 } do
		local cframe = CFrame.new(0, y, 0) * CFrame.Angles(math.rad(16), 0, 0)
		block(b, "Strap" .. index, Vector3.new(0.43, 0.07, 0.44), cframe, leatherDark)
	end
	band(b, "GripCapTop", -0.27, 0.08, 0.43, steelDark)
	band(b, "GripCapBottom", -1.58, 0.08, 0.43, steelDark)
	band(b, "Collar", 1.2, 0.38, 0.46, plate)
	band(b, "CollarLip", 0.99, 0.06, 0.52, steel)

	block(b, "Head", Vector3.new(0.5, 0.64, 0.8), CFrame.new(0, 1.62, 0), steel)
	block(b, "Ridge", Vector3.new(0.3, 0.06, 0.82), CFrame.new(0, 1.96, 0), steelDark)
	for index, z in { -0.24, 0.24 } do
		local rivet = Instance.new("Part")
		rivet.Shape = Enum.PartType.Cylinder
		attach(b, rivet, "Rivet" .. index, Vector3.new(0.56, 0.12, 0.12), CFrame.new(0, 1.62, z), steelDark)
	end
	arms(b, Vector3.new(0, 1.62, 0.38), {
		blockPiece(6, Vector3.new(0.44, 0.5, 0.52), steel),
		spikePiece(16, Vector3.new(0.38, 0.46, 0.78), steel, steelDark),
	})
	return b
end

local function buildGilded(def: Items.ItemDef): Builder
	local gold = look(def.Color, Enum.Material.Foil)
	local goldDeep = look(def.Color:Lerp(Color3.fromRGB(150, 84, 20), 0.45), Enum.Material.Foil)
	local inlay = look(Color3.fromRGB(214, 218, 228), Enum.Material.DiamondPlate)
	local walnut = look(Color3.fromRGB(74, 44, 28), Enum.Material.Wood)
	local velvet = look(Color3.fromRGB(150, 28, 44), Enum.Material.Fabric)
	local sapphire = look(Color3.fromRGB(50, 120, 255), Enum.Material.Glass, 0.15)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), walnut)

	ball(b, "Pommel", 0.44, Vector3.new(0, -1.86, 0), gold)
	ring(b, "PommelCollar", -1.68, 0.1, 0.52, goldDeep)
	block(b, "Grip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, -0.98, 0), velvet)
	ring(b, "GripRingLow", -1.6, 0.08, 0.52, gold)
	ring(b, "GripRingHigh", -0.36, 0.08, 0.52, gold)
	ring(b, "BandMid", 0.35, 0.12, 0.52, goldDeep)
	ring(b, "Collar", 1.18, 0.32, 0.56, gold)

	block(b, "Head", Vector3.new(0.52, 0.66, 0.78), CFrame.new(0, 1.62, 0), gold)
	block(b, "HeadBandA", Vector3.new(0.56, 0.72, 0.1), CFrame.new(0, 1.62, -0.39), goldDeep)
	block(b, "HeadBandB", Vector3.new(0.56, 0.72, 0.1), CFrame.new(0, 1.62, 0.39), goldDeep)
	block(b, "GemSetting", Vector3.new(0.56, 0.34, 0.34), CFrame.new(0, 1.64, 0) * DIAMOND, goldDeep)
	local gem = block(b, "Gem", Vector3.new(0.6, 0.22, 0.22), CFrame.new(0, 1.64, 0) * DIAMOND, sapphire)

	local framesA, framesB = arms(b, Vector3.new(0, 1.62, 0.4), {
		blockPiece(7, Vector3.new(0.44, 0.5, 0.55), gold),
		spikePiece(18, Vector3.new(0.38, 0.46, 0.76), gold, goldDeep),
	})
	for _, frames in { framesA, framesB } do
		block(b, "Inlay", Vector3.new(0.48, 0.3, 0.38), frames[1] * CFrame.new(0, 0, -0.28), inlay)
	end

	addLight(gem, Color3.fromRGB(255, 214, 130), 0.7, 6)
	addEmitter(fxVolume(b, Vector3.new(0.6, 0.7, 3), Vector3.new(0, 1.6, 0)), "Sparkles", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(def.Color:Lerp(WHITE, 0.5), def.Color),
		Size = twinkle(0.28),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 6,
		Speed = NumberRange.new(0.1, 0.4),
	})
	b.trail = ColorSequence.new(def.Color, def.Color:Lerp(WHITE, 0.6))
	return b
end

local function buildAmethyst(def: Items.ItemDef): Builder
	local crystal = look(def.Color, Enum.Material.Glass, 0.25)
	local crystalPale = look(def.Color:Lerp(WHITE, 0.4), Enum.Material.Glass, 0.3)
	local crystalDeep = look(def.Color:Lerp(Color3.fromRGB(40, 0, 80), 0.4), Enum.Material.Glass, 0.2)
	local glow = neon(def.Color:Lerp(WHITE, 0.15))
	local silver = look(Color3.fromRGB(206, 210, 222), Enum.Material.Metal)
	local gunmetal = look(Color3.fromRGB(78, 74, 92), Enum.Material.Metal)
	local silk = look(Color3.fromRGB(72, 36, 112), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.32, 3.5, 0.32), gunmetal)

	band(b, "PommelCap", -1.79, 0.16, 0.4, silver)
	spike(
		b,
		"PommelGem",
		CFrame.new(0, -1.86, 0) * POINT_DOWN * ROLL_45,
		Vector3.new(0.24, 0.24, 0.3),
		crystal,
		crystalDeep
	)
	block(b, "Grip", Vector3.new(0.38, 1.2, 0.38), CFrame.new(0, -0.98, 0), silk)
	band(b, "GripCapTop", -0.36, 0.08, 0.42, silver)
	band(b, "GripCapBottom", -1.6, 0.08, 0.42, silver)
	band(b, "Collar", 1.2, 0.3, 0.44, silver)

	-- Silver cradle clamping a glowing core; faceted crystal shards grow out of it.
	block(b, "Socket", Vector3.new(0.5, 0.16, 0.6), CFrame.new(0, 1.4, 0), silver)
	for _, side in { -1, 1 } do
		local cframe = CFrame.new(0, 1.6, side * 0.31) * CFrame.Angles(math.rad(side * 12), 0, 0)
		block(b, "Prong", Vector3.new(0.42, 0.44, 0.07), cframe, silver)
	end
	local core = block(b, "Core", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 1.66, 0) * DIAMOND, glow)

	arms(b, Vector3.new(0, 1.66, 0.2), {
		blockPiece(12, Vector3.new(0.32, 0.32, 0.72), crystal, 45),
		spikePiece(18, Vector3.new(0.32, 0.32, 0.62), crystalPale, crystal, 45),
	})
	for _, side in { -1, 1 } do
		local upper = armFrame(side, Vector3.new(0, 1.78, side * 0.42), -38) * ROLL_45
		spike(b, "ShardUpper", upper, Vector3.new(0.18, 0.22, 0.55), crystalPale, crystal)
		local lower = armFrame(side, Vector3.new(0, 1.52, side * 0.5), 48) * ROLL_45
		spike(b, "ShardLower", lower, Vector3.new(0.16, 0.2, 0.45), crystalDeep, crystal)
	end

	addLight(core, def.Color, 1.5, 8)
	addEmitter(core, "Sparkles", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(def.Color:Lerp(WHITE, 0.5), def.Color),
		Size = twinkle(0.26),
		Lifetime = NumberRange.new(0.7, 1.2),
		Rate = 9,
		Speed = NumberRange.new(0.6, 1.4),
	})
	b.trail = ColorSequence.new(def.Color, def.Color:Lerp(WHITE, 0.5))
	return b
end

local function buildGlacier(def: Items.ItemDef): Builder
	local ice = look(def.Color, Enum.Material.Ice)
	local glacier = look(def.Color:Lerp(Color3.fromRGB(60, 130, 200), 0.35), Enum.Material.Glacier)
	local frost = look(def.Color:Lerp(WHITE, 0.6), Enum.Material.Glass, 0.35)
	local vein = neon(def.Color:Lerp(WHITE, 0.25))
	local frozenWood = look(Color3.fromRGB(140, 160, 178), Enum.Material.Wood)
	local snow = look(Color3.fromRGB(236, 244, 250), Enum.Material.Snow)
	local fur = look(Color3.fromRGB(222, 232, 242), Enum.Material.Fabric)
	local steel = look(Color3.fromRGB(170, 190, 206), Enum.Material.Metal)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), frozenWood)

	band(b, "PommelCap", -1.78, 0.18, 0.42, steel)
	spike(b, "PommelIcicle", CFrame.new(0, -1.86, 0) * POINT_DOWN, Vector3.new(0.22, 0.24, 0.34), ice, frost)
	block(b, "Grip", Vector3.new(0.42, 1.2, 0.42), CFrame.new(0, -0.98, 0), fur)
	block(
		b,
		"FrostCrust",
		Vector3.new(0.4, 0.5, 0.38),
		CFrame.new(0.01, 0.98, -0.01) * CFrame.Angles(0, math.rad(8), math.rad(4)),
		snow
	)
	band(b, "Collar", 1.24, 0.28, 0.48, glacier)

	local head = block(b, "Head", Vector3.new(0.5, 0.66, 0.72), CFrame.new(0, 1.62, 0), glacier)
	block(b, "VeinCore", Vector3.new(0.52, 0.05, 0.5), CFrame.new(0, 1.66, 0) * CFrame.Angles(math.rad(28), 0, 0), vein)

	-- Jagged zig-zag arms, with frost spires rising off the top and icicles hanging underneath.
	local framesA, framesB = arms(b, Vector3.new(0, 1.62, 0.34), {
		blockPiece(-6, Vector3.new(0.44, 0.5, 0.46), ice),
		blockPiece(16, Vector3.new(0.4, 0.44, 0.42), glacier),
		spikePiece(28, Vector3.new(0.36, 0.4, 0.62), ice, frost),
	})
	for _, frames in { framesA, framesB } do
		block(b, "Vein", Vector3.new(0.46, 0.05, 0.4), frames[1] * CFrame.new(0, 0.06, -0.23), vein)
	end
	for _, side in { -1, 1 } do
		local spire = armFrame(side, Vector3.new(0, 1.78, side * 0.62), -52) * CFrame.Angles(0, 0, math.rad(20))
		spike(b, "Spire", spire, Vector3.new(0.18, 0.24, 0.52), frost, ice)
		spike(b, "Icicle", CFrame.new(0, 1.48, side * 0.98) * POINT_DOWN, Vector3.new(0.14, 0.16, 0.3), ice, frost)
	end

	addLight(head, def.Color, 1.2, 8)
	local volume = fxVolume(b, Vector3.new(0.7, 0.8, 3), Vector3.new(0, 1.6, 0))
	addEmitter(volume, "Frost", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE, def.Color),
		Size = twinkle(0.2),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 10,
		Speed = NumberRange.new(0.1, 0.4),
		Acceleration = Vector3.new(0, -3, 0),
		Drag = 1,
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 0.7,
	})
	addEmitter(volume, "ColdMist", {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(def.Color:Lerp(WHITE, 0.7)),
		Size = NumberSequence.new(0.3, 0.9),
		Transparency = NumberSequence.new(0.75, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 3,
		Speed = NumberRange.new(0.05, 0.2),
		Acceleration = Vector3.new(0, -0.8, 0),
		LightEmission = 0.3,
	})
	b.trail = ColorSequence.new(def.Color, WHITE)
	return b
end

local function buildMagma(def: Items.ItemDef): Builder
	local basalt = look(Color3.fromRGB(38, 34, 36), Enum.Material.Basalt)
	local slate = look(Color3.fromRGB(56, 48, 48), Enum.Material.Slate)
	local lava = look(def.Color, Enum.Material.CrackedLava)
	local glow = neon(def.Color)
	local hot = neon(def.Color:Lerp(Color3.fromRGB(255, 220, 90), 0.5))
	local iron = look(Color3.fromRGB(46, 42, 44), Enum.Material.Metal)
	local charcoal = look(Color3.fromRGB(52, 44, 42), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.36, 3.5, 0.36), basalt)

	-- Glowing fissures up the haft: each thin slab shows as a line on two opposite faces.
	block(b, "FissureX", Vector3.new(0.38, 2.1, 0.045), CFrame.new(0, 0.55, 0), glow)
	block(b, "FissureZ", Vector3.new(0.045, 2.1, 0.38), CFrame.new(0, 0.55, 0), glow)
	block(b, "Grip", Vector3.new(0.42, 1.2, 0.42), CFrame.new(0, -0.98, 0), charcoal)
	band(b, "GripCapTop", -0.36, 0.08, 0.44, iron)
	band(b, "GripCapBottom", -1.6, 0.08, 0.44, iron)
	block(b, "Pommel", Vector3.new(0.44, 0.3, 0.44), CFrame.new(0, -1.86, 0) * CFrame.Angles(0, math.pi / 4, 0), basalt)
	band(b, "PommelCore", -1.86, 0.12, 0.48, lava)
	band(b, "Collar", 1.2, 0.34, 0.5, slate)
	band(b, "CollarSeam", 1.2, 0.06, 0.52, glow)

	block(b, "Head", Vector3.new(0.58, 0.72, 0.84), CFrame.new(0, 1.64, 0), basalt)
	local core = block(b, "MoltenCore", Vector3.new(0.62, 0.3, 0.66), CFrame.new(0, 1.64, 0), lava)
	local framesA, framesB = arms(b, Vector3.new(0, 1.64, 0.4), {
		blockPiece(4, Vector3.new(0.5, 0.58, 0.5), basalt),
		blockPiece(14, Vector3.new(0.46, 0.52, 0.36), slate),
		spikePiece(24, Vector3.new(0.42, 0.48, 0.6), lava),
	})
	-- Zig-zag cracks across the side faces of each arm.
	for _, frames in { framesA, framesB } do
		local inner = frames[1] * CFrame.new(0, 0.06, -0.25) * CFrame.Angles(math.rad(22), 0, 0)
		block(b, "Crack", Vector3.new(0.52, 0.045, 0.42), inner, glow)
		local outer = frames[2] * CFrame.new(0, -0.05, -0.18) * CFrame.Angles(math.rad(-30), 0, 0)
		block(b, "Crack", Vector3.new(0.48, 0.045, 0.3), outer, hot)
	end

	addLight(core, def.Color, 1.8, 9)
	local volume = fxVolume(b, Vector3.new(0.7, 0.8, 3.1), Vector3.new(0, 1.6, 0))
	addEmitter(volume, "Embers", {
		Texture = FIRE_TEXTURE,
		Color = gradient(hot.Color, def.Color, Color3.fromRGB(150, 20, 10)),
		Size = sequence(0.18, 0.12, 0),
		Lifetime = NumberRange.new(0.6, 1.2),
		Rate = 14,
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 2.5, 0),
		Drag = 1.5,
	})
	addEmitter(volume, "Smoke", {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(70, 58, 52), Color3.fromRGB(30, 26, 26)),
		Size = NumberSequence.new(0.3, 1.1),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(1, 1.8),
		Rate = 3,
		Speed = NumberRange.new(0.2, 0.5),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 1.2, 0),
		LightEmission = 0,
	})
	b.trail = ColorSequence.new(def.Color, def.Color:Lerp(Color3.fromRGB(200, 20, 10), 0.7))
	return b
end

local function buildCelestial(def: Items.ItemDef): Builder
	local marble = look(Color3.fromRGB(240, 236, 246), Enum.Material.Marble)
	local gold = look(Color3.fromRGB(255, 206, 96), Enum.Material.Foil)
	local starlight = neon(def.Color:Lerp(WHITE, 0.45))
	local glint = neon(def.Color)
	local haloGlow = neon(def.Color:Lerp(Color3.fromRGB(255, 226, 150), 0.55))
	local night = look(Color3.fromRGB(34, 38, 82), Enum.Material.Slate)
	local silk = look(Color3.fromRGB(232, 224, 248), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.32, 3.5, 0.32), night)

	ball(b, "Pommel", 0.36, Vector3.new(0, -1.86, 0), gold)
	ring(b, "PommelCollar", -1.7, 0.1, 0.5, gold)
	block(b, "Grip", Vector3.new(0.38, 1.2, 0.38), CFrame.new(0, -0.98, 0), silk)
	ring(b, "GripRing", -0.34, 0.1, 0.5, gold)
	ring(b, "Collar", 1.18, 0.3, 0.54, gold)

	-- Marble head around a neon star whose cross-shaped glint pokes out of every face.
	block(b, "Head", Vector3.new(0.44, 0.56, 0.68), CFrame.new(0, 1.62, 0), marble)
	local star = ball(b, "StarCore", 0.54, Vector3.new(0, 1.64, 0), starlight)
	block(b, "GlintV", Vector3.new(0.48, 0.74, 0.05), CFrame.new(0, 1.64, 0), glint)
	block(b, "GlintH", Vector3.new(0.48, 0.05, 0.9), CFrame.new(0, 1.64, 0), glint)

	local framesA, framesB = arms(b, Vector3.new(0, 1.62, 0.32), {
		blockPiece(5, Vector3.new(0.36, 0.42, 0.62), marble),
		spikePiece(15, Vector3.new(0.32, 0.38, 0.86), gold),
	})
	for _, frames in { framesA, framesB } do
		block(b, "Trim", Vector3.new(0.38, 0.06, 0.6), frames[1] * CFrame.new(0, 0.2, -0.31), gold)
	end

	-- Floating halo: thin segments around a slightly tilted ring above the head.
	local haloFrame = CFrame.new(0, 2.26, 0) * CFrame.Angles(math.rad(10), 0, 0)
	local segments = 10
	local radius = 0.5
	local length = 2 * radius * math.sin(math.pi / segments) + 0.04
	for index = 1, segments do
		local cframe = haloFrame * CFrame.Angles(0, index * 2 * math.pi / segments, 0) * CFrame.new(radius, 0, 0)
		block(b, "Halo" .. index, Vector3.new(0.08, 0.08, length), cframe, haloGlow)
	end

	addLight(star, def.Color:Lerp(WHITE, 0.3), 1.8, 9)
	addEmitter(fxVolume(b, Vector3.new(0.9, 1.1, 3), Vector3.new(0, 1.8, 0)), "StarSparkles", {
		Texture = SPARKLE_TEXTURE,
		Color = gradient(def.Color, WHITE, gold.Color),
		Size = twinkle(0.3),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 9,
		Speed = NumberRange.new(0.1, 0.4),
		RotSpeed = NumberRange.new(-60, 60),
	})
	addEmitter(star, "Twinkle", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE),
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.25, 0.4),
		Rate = 3,
		Speed = NumberRange.new(0),
		LockedToPart = true,
	})
	b.trail = ColorSequence.new(def.Color, gold.Color)
	return b
end

local function buildPhoenix(def: Items.ItemDef): Builder
	local flame = def.Color
	local yellow = flame:Lerp(Color3.fromRGB(255, 236, 110), 0.65)
	local red = flame:Lerp(Color3.fromRGB(210, 24, 30), 0.65)
	local gold = look(Color3.fromRGB(255, 192, 72), Enum.Material.Foil)
	local emberWood = look(Color3.fromRGB(92, 32, 24), Enum.Material.Wood)
	local crimson = look(Color3.fromRGB(150, 28, 30), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), emberWood)

	band(b, "PommelCap", -1.76, 0.2, 0.42, gold)
	for _, side in { -1, 1 } do
		local frame = armFrame(side, Vector3.new(0, -1.8, side * 0.08), 62)
		hook(b, "TailFeather", frame, Vector3.new(0.12, 0.2, 0.36), neon(red))
	end
	block(b, "Grip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, -0.98, 0), crimson)
	band(b, "GripCap", -0.36, 0.08, 0.43, gold)
	band(b, "Collar", 1.22, 0.32, 0.46, gold)

	block(b, "Body", Vector3.new(0.42, 0.56, 0.5), CFrame.new(0, 1.62, 0), gold)
	local heart = block(
		b,
		"Heart",
		Vector3.new(0.48, 0.26, 0.26),
		CFrame.new(0, 1.64, 0) * DIAMOND,
		neon(yellow:Lerp(WHITE, 0.3))
	)
	local crest = CFrame.new(0, 1.86, 0) * CFrame.Angles(math.rad(105), 0, 0)
	spike(b, "Crest", crest, Vector3.new(0.16, 0.3, 0.5), neon(flame), neon(yellow))

	-- Flame feathers fanned like wings, cooling from yellow at the top to red at the bottom. The long middle
	-- feather on each side is the pick point.
	for _, side in { -1, 1 } do
		local upper = armFrame(side, Vector3.new(0, 1.74, side * 0.18), -30)
		spike(b, "FeatherUpper", upper, Vector3.new(0.14, 0.3, 1), neon(yellow), neon(yellow:Lerp(flame, 0.5)))
		local mid = armFrame(side, Vector3.new(0, 1.68, side * 0.2), -9)
		spike(b, "FeatherMid", mid, Vector3.new(0.16, 0.32, 1.2), neon(yellow:Lerp(flame, 0.4)), neon(flame))
		local main = armFrame(side, Vector3.new(0, 1.62, side * 0.2), 8)
		local tip = spike(
			b,
			"FeatherMain",
			main,
			Vector3.new(0.2, 0.42, 1.45),
			neon(flame:Lerp(yellow, 0.25)),
			neon(flame:Lerp(red, 0.3))
		)
		local lower = armFrame(side, Vector3.new(0, 1.5, side * 0.18), 38)
		spike(b, "FeatherLower", lower, Vector3.new(0.14, 0.28, 0.95), neon(flame:Lerp(red, 0.5)), neon(red))
		if side < 0 then
			b.tipA = tip
		else
			b.tipB = tip
		end
	end

	addLight(heart, def.Color, 2.2, 10)
	local volume = fxVolume(b, Vector3.new(0.6, 1.2, 3.2), Vector3.new(0, 1.6, 0))
	addEmitter(volume, "Flames", {
		Texture = FIRE_TEXTURE,
		Color = gradient(yellow, flame, red),
		Size = NumberSequence.new(0.45, 0.05),
		Transparency = sequence(0.2, 0.4, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Rate = 16,
		Speed = NumberRange.new(0.4, 1),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 4, 0),
		RotSpeed = NumberRange.new(-90, 90),
	})
	addEmitter(volume, "Embers", {
		Texture = FIRE_TEXTURE,
		Color = ColorSequence.new(yellow, red),
		Size = NumberSequence.new(0.12, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 8,
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 1,
	})
	addEmitter(heart, "Sparks", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE, yellow),
		Size = NumberSequence.new(0.2, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 5,
		Speed = NumberRange.new(1, 2.5),
	})
	b.trail = gradient(yellow, flame, red)
	return b
end

local function buildVoid(def: Items.ItemDef): Builder
	local slate = look(Color3.fromRGB(30, 24, 40), Enum.Material.Slate)
	local basalt = look(Color3.fromRGB(20, 16, 28), Enum.Material.Basalt)
	local edge = neon(def.Color)
	local eye = neon(def.Color:Lerp(Color3.fromRGB(230, 200, 255), 0.35))
	local aura = look(def.Color:Lerp(Color3.fromRGB(200, 120, 255), 0.3), Enum.Material.ForceField)
	local wrap = look(Color3.fromRGB(36, 26, 52), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), basalt)

	for index, y in { 0, 0.45, 0.9 } do
		local cframe = CFrame.new(0, y, 0) * CFrame.Angles(0, math.pi / 4, 0)
		block(b, "Rune" .. index, Vector3.new(0.5, 0.05, 0.5), cframe, edge)
	end
	block(b, "Grip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, -0.98, 0), wrap)
	spike(b, "PommelSpike", CFrame.new(0, -1.72, 0) * POINT_DOWN * ROLL_45, Vector3.new(0.3, 0.3, 0.44), slate, basalt)
	ball(b, "PommelOrb", 0.3, Vector3.new(0, -1.8, 0), eye)
	band(b, "Collar", 1.22, 0.34, 0.46, slate)

	block(b, "Head", Vector3.new(0.44, 0.66, 0.6), CFrame.new(0, 1.64, 0), slate)
	local voidEye = ball(b, "VoidEye", 0.5, Vector3.new(0, 1.66, 0), eye)
	for _, side in { -1, 1 } do
		spike(b, "Horn", armFrame(side, Vector3.new(0, 1.9, side * 0.2), -65), Vector3.new(0.14, 0.18, 0.36), basalt)
	end

	-- Front: a hooked reaver talon. Back: a short upswept spike. Neon runs along their lower edges.
	local talonTip, talon = arm(b, "Talon", -1, Vector3.new(0, 1.66, -0.28), {
		blockPiece(-8, Vector3.new(0.4, 0.52, 0.55), slate),
		blockPiece(22, Vector3.new(0.36, 0.46, 0.5), basalt),
		hookPiece(48, Vector3.new(0.32, 0.46, 0.8), slate),
	})
	local backTip, back = arm(b, "BackSpike", 1, Vector3.new(0, 1.66, 0.28), {
		blockPiece(-10, Vector3.new(0.38, 0.46, 0.45), slate),
		spikePiece(-20, Vector3.new(0.34, 0.42, 0.7), basalt, slate),
	})
	b.tipA = talonTip
	b.tipB = backTip
	block(b, "Edge", Vector3.new(0.42, 0.05, 0.55), talon[1] * CFrame.new(0, -0.26, -0.275), edge)
	block(b, "Edge", Vector3.new(0.38, 0.05, 0.5), talon[2] * CFrame.new(0, -0.23, -0.25), edge)
	block(b, "Edge", Vector3.new(0.34, 0.05, 0.8), talon[3] * CFrame.new(0, -0.23, -0.4), edge)
	block(b, "Edge", Vector3.new(0.4, 0.05, 0.45), back[1] * CFrame.new(0, -0.23, -0.225), edge)

	-- ForceField shells: an aura sphere around the eye and loose casings over both blades.
	local shell = ball(b, "AuraCore", 1.15, Vector3.new(0, 1.66, 0), aura)
	block(b, "AuraTalon", Vector3.new(0.56, 0.72, 1.1), talon[2] * CFrame.new(0, 0.02, -0.12), aura)
	block(b, "AuraSpike", Vector3.new(0.5, 0.6, 0.9), back[1] * CFrame.new(0, 0, -0.4), aura)

	addLight(voidEye, def.Color, 1.6, 9)
	-- Particles spawn on the aura sphere and fall inward, as if pulled into the eye.
	addEmitter(shell, "VoidSwirl", {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(60, 16, 110), Color3.fromRGB(14, 0, 30)),
		Size = NumberSequence.new(0.5, 0.1),
		Transparency = sequence(0.3, 0.5, 1),
		Lifetime = NumberRange.new(0.6, 0.75),
		Rate = 10,
		Speed = NumberRange.new(0.7, 0.9),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	})
	addEmitter(shell, "VoidSparks", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(def.Color:Lerp(WHITE, 0.4), def.Color),
		Size = NumberSequence.new(0.2, 0),
		Lifetime = NumberRange.new(0.5, 0.7),
		Rate = 6,
		Speed = NumberRange.new(0.7, 0.9),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	})
	b.trail = ColorSequence.new(def.Color, def.Color:Lerp(Color3.fromRGB(40, 0, 90), 0.6))
	return b
end

local function buildAurora(def: Items.ItemDef): Builder
	local green = def.Color
	local cyan = def.Color:Lerp(Color3.fromRGB(70, 170, 255), 0.6)
	local pink = def.Color:Lerp(Color3.fromRGB(255, 100, 220), 0.75)
	local frozen = look(Color3.fromRGB(196, 236, 236), Enum.Material.Ice)
	local silver = look(Color3.fromRGB(214, 226, 236), Enum.Material.Metal)
	local teal = look(Color3.fromRGB(22, 74, 84), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.32, 3.5, 0.32), frozen)

	band(b, "PommelCap", -1.78, 0.16, 0.4, silver)
	spike(
		b,
		"PommelPrism",
		CFrame.new(0, -1.86, 0) * POINT_DOWN * ROLL_45,
		Vector3.new(0.24, 0.24, 0.34),
		look(pink, Enum.Material.Glass, 0.25),
		look(cyan, Enum.Material.Glass, 0.25)
	)
	block(b, "Grip", Vector3.new(0.38, 1.2, 0.38), CFrame.new(0, -0.98, 0), teal)
	band(b, "GripCap", -0.36, 0.07, 0.41, silver)
	block(b, "ShaftSeam", Vector3.new(0.34, 2, 0.04), CFrame.new(0, 0.6, 0), neon(green:Lerp(WHITE, 0.3)))
	band(b, "Collar", 1.2, 0.3, 0.44, silver)

	block(
		b,
		"Prism",
		Vector3.new(0.5, 0.62, 0.56),
		CFrame.new(0, 1.62, 0),
		look(cyan:Lerp(WHITE, 0.3), Enum.Material.Glass, 0.3)
	)
	local core = block(
		b,
		"PrismCore",
		Vector3.new(0.3, 0.3, 0.3),
		CFrame.new(0, 1.62, 0) * CFrame.Angles(math.pi / 4, math.pi / 4, 0),
		neon(green:Lerp(WHITE, 0.2))
	)

	-- Three translucent curtains per side, fanned at different angles so their tints overlap like an aurora. Each
	-- has a neon seam along its ridge; the green middle curtain carries the pick point.
	local curtains = {
		{ x = 0, y = 1.62, droop = 12, size = Vector3.new(0.1, 0.56, 1.5), color = green },
		{ x = -0.15, y = 1.72, droop = -4, size = Vector3.new(0.08, 0.46, 1.3), color = cyan },
		{ x = 0.15, y = 1.52, droop = 28, size = Vector3.new(0.08, 0.44, 1.2), color = pink },
	}
	for _, side in { -1, 1 } do
		for index, curtain in curtains do
			local frame = armFrame(side, Vector3.new(curtain.x, curtain.y, side * 0.22), curtain.droop)
			local tip = spike(
				b,
				"Curtain" .. index,
				frame,
				curtain.size,
				look(curtain.color, Enum.Material.Glass, 0.25),
				look(curtain.color:Lerp(WHITE, 0.2), Enum.Material.Glass, 0.3)
			)
			local seamSize = Vector3.new(curtain.size.X + 0.02, 0.035, curtain.size.Z * 0.72)
			local seam = frame * CFrame.new(0, 0, -curtain.size.Z * 0.36)
			block(b, "Seam" .. index, seamSize, seam, neon(curtain.color:Lerp(WHITE, 0.45)))
			if index == 1 then
				if side < 0 then
					b.tipA = tip
				else
					b.tipB = tip
				end
			end
		end
	end

	addLight(core, def.Color, 1.6, 9)
	local volume = fxVolume(b, Vector3.new(0.6, 1, 3.2), Vector3.new(0, 1.55, 0))
	local colors = gradient(green, cyan, pink)
	addEmitter(volume, "Shimmer", {
		Texture = SPARKLE_TEXTURE,
		Color = colors,
		Size = twinkle(0.26),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 10,
		Speed = NumberRange.new(0.1, 0.35),
		RotSpeed = NumberRange.new(-45, 45),
	})
	addEmitter(volume, "Veil", {
		Texture = SMOKE_TEXTURE,
		Color = colors,
		Size = NumberSequence.new(0.4, 1),
		Transparency = sequence(0.85, 0.75, 1),
		Lifetime = NumberRange.new(1.2, 2),
		Rate = 3,
		Speed = NumberRange.new(0.05, 0.15),
		Acceleration = Vector3.new(0, 0.4, 0),
	})
	b.trail = colors
	return b
end

local function buildSingularity(def: Items.ItemDef): Builder
	local violet = Color3.fromRGB(160, 110, 255)
	local white = neon(def.Color)
	local horizon = look(def.Color:Lerp(violet, 0.6), Enum.Material.ForceField)
	local shard = look(Color3.fromRGB(22, 20, 30), Enum.Material.Basalt)
	local facet = look(Color3.fromRGB(44, 36, 66), Enum.Material.Slate)
	local chrome = look(Color3.fromRGB(34, 34, 42), Enum.Material.Metal)
	local strip = neon(def.Color:Lerp(violet, 0.25))
	local wrap = look(Color3.fromRGB(26, 24, 34), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), chrome)

	block(b, "StripX", Vector3.new(0.36, 2.1, 0.04), CFrame.new(0, 0.55, 0), strip)
	block(b, "StripZ", Vector3.new(0.04, 2.1, 0.36), CFrame.new(0, 0.55, 0), strip)
	block(b, "Grip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, -0.98, 0), wrap)
	band(b, "GripCap", -0.36, 0.06, 0.42, strip)
	band(b, "PommelCap", -1.76, 0.18, 0.42, chrome)
	ball(b, "PommelOrb", 0.3, Vector3.new(0, -1.92, 0), white)
	band(b, "Collar", 1.16, 0.3, 0.46, chrome)

	local center = Vector3.new(0, 1.66, 0)
	local core = ball(b, "Core", 0.72, center, white)
	local shell = ball(b, "Horizon", 1.08, center, horizon)

	-- Dark shards radiating from the core in the swing plane; angle is about X, from -Z (0) toward +Y (90). The
	-- near-horizontal pair are the pick points.
	local shards = {
		{ angle = -8, size = Vector3.new(0.3, 0.44, 1.3) },
		{ angle = 188, size = Vector3.new(0.3, 0.44, 1.3) },
		{ angle = 48, size = Vector3.new(0.24, 0.32, 0.6) },
		{ angle = 132, size = Vector3.new(0.24, 0.32, 0.6) },
		{ angle = 90, size = Vector3.new(0.24, 0.32, 0.46) },
		{ angle = -52, size = Vector3.new(0.22, 0.3, 0.46) },
		{ angle = 232, size = Vector3.new(0.22, 0.3, 0.46) },
	}
	for index, spec in shards do
		local frame = CFrame.new(center) * CFrame.Angles(math.rad(spec.angle), 0, 0) * CFrame.new(0, 0, -0.28)
		local tip = spike(b, "Shard" .. index, frame, spec.size, shard, facet)
		if index == 1 then
			b.tipA = tip
		elseif index == 2 then
			b.tipB = tip
		end
	end

	addLight(core, def.Color, 3, 12)
	addLight(shell, violet, 1.2, 7)
	-- Spawned on the horizon sphere and pulled inward to the core.
	addEmitter(shell, "Infall", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(def.Color, violet),
		Size = NumberSequence.new(0.22, 0.05),
		Lifetime = NumberRange.new(0.45, 0.55),
		Rate = 14,
		Speed = NumberRange.new(0.9, 1.1),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	})
	addEmitter(shell, "DarkMatter", {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(40, 20, 70), Color3.fromRGB(10, 0, 20)),
		Size = NumberSequence.new(0.45, 0.1),
		Transparency = sequence(0.4, 0.55, 1),
		Lifetime = NumberRange.new(0.5, 0.6),
		Rate = 6,
		Speed = NumberRange.new(0.8, 1),
		RotSpeed = NumberRange.new(-240, 240),
		LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	})
	addEmitter(core, "Flares", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE),
		Size = NumberSequence.new(0.7, 0),
		Lifetime = NumberRange.new(0.2, 0.35),
		Rate = 3,
		Speed = NumberRange.new(0),
		LockedToPart = true,
	})
	b.trail = ColorSequence.new(def.Color, violet)
	return b
end

local function buildRoyal(def: Items.ItemDef): Builder
	local gold = look(def.Color, Enum.Material.Foil)
	local goldDeep = look(def.Color:Lerp(Color3.fromRGB(160, 96, 20), 0.4), Enum.Material.Foil)
	local marble = look(Color3.fromRGB(244, 240, 234), Enum.Material.Marble)
	local ruby = look(Color3.fromRGB(225, 20, 52), Enum.Material.Glass, 0.1)
	local rubyClear = look(Color3.fromRGB(225, 20, 52), Enum.Material.Glass, 0.35)
	local rubyGlow = neon(Color3.fromRGB(255, 40, 70))
	local velvet = look(Color3.fromRGB(96, 32, 150), Enum.Material.Fabric)

	local b = newBuilder(Vector3.new(0.34, 3.5, 0.34), marble)

	ball(b, "Pommel", 0.4, Vector3.new(0, -1.84, 0), gold)
	ball(b, "PommelRuby", 0.18, Vector3.new(0, -2, 0), rubyGlow)
	block(b, "Grip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, -0.98, 0), velvet)
	band(b, "GripCap", -0.36, 0.08, 0.43, gold)
	band(b, "Collar", 1.2, 0.34, 0.46, gold)
	block(
		b,
		"CollarStar",
		Vector3.new(0.46, 0.2, 0.46),
		CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.pi / 4, 0),
		goldDeep
	)

	-- Marble head set with rubies; a ruby heart glows through clear glass.
	block(b, "Head", Vector3.new(0.48, 0.62, 0.72), CFrame.new(0, 1.62, 0), marble)
	block(b, "CrownBand", Vector3.new(0.52, 0.08, 0.76), CFrame.new(0, 1.95, 0), gold)
	local heart = block(b, "HeartRuby", Vector3.new(0.54, 0.3, 0.3), CFrame.new(0, 1.6, 0) * DIAMOND, rubyClear)
	block(b, "HeartGlow", Vector3.new(0.5, 0.2, 0.2), CFrame.new(0, 1.6, 0) * DIAMOND, rubyGlow)

	local framesA, framesB = arms(b, Vector3.new(0, 1.62, 0.34), {
		blockPiece(4, Vector3.new(0.42, 0.5, 0.5), gold),
		spikePiece(14, Vector3.new(0.36, 0.46, 0.85), gold, goldDeep),
	})
	for _, frames in { framesA, framesB } do
		block(b, "Ruby", Vector3.new(0.5, 0.2, 0.2), frames[1] * CFrame.new(0, 0, -0.25) * DIAMOND, ruby)
	end

	-- Crown: a tall jewelled center spike, a flared inner pair, and small corner points.
	spike(b, "CrownSpike", CFrame.new(0, 1.95, 0) * POINT_UP, Vector3.new(0.16, 0.24, 0.42), gold, goldDeep)
	ball(b, "CrownJewel", 0.14, Vector3.new(0, 2.38, 0), rubyGlow)
	for _, side in { -1, 1 } do
		local flare = CFrame.new(0, 1.95, side * 0.2) * CFrame.Angles(math.rad(90 + side * 10), 0, 0)
		spike(b, "CrownSpike", flare, Vector3.new(0.14, 0.2, 0.34), gold, goldDeep)
		block(b, "CrownPoint", Vector3.new(0.12, 0.18, 0.18), CFrame.new(0, 1.97, side * 0.32) * DIAMOND, gold)
	end

	addLight(heart, Color3.fromRGB(255, 214, 140), 1.4, 8)
	addEmitter(fxVolume(b, Vector3.new(0.7, 0.9, 3.1), Vector3.new(0, 1.7, 0)), "RoyalSparkle", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE, def.Color),
		Size = twinkle(0.3),
		Lifetime = NumberRange.new(0.7, 1.2),
		Rate = 8,
		Speed = NumberRange.new(0.1, 0.4),
	})
	addEmitter(heart, "RubyGlint", {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(rubyGlow.Color),
		Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Rate = 3,
		Speed = NumberRange.new(0),
		LockedToPart = true,
	})
	b.trail = ColorSequence.new(def.Color, ruby.Color)
	return b
end

local STYLE_BUILDERS: { [string]: (Items.ItemDef) -> Builder } = {
	Rusty = buildRusty,
	Iron = buildIron,
	Gilded = buildGilded,
	Amethyst = buildAmethyst,
	Glacier = buildGlacier,
	Magma = buildMagma,
	Celestial = buildCelestial,
	Phoenix = buildPhoenix,
	Void = buildVoid,
	Aurora = buildAurora,
	Singularity = buildSingularity,
	Royal = buildRoyal,
}

-- Returns an unparented Tool for def.Style (unknown styles use the Iron look). The caller names it.
function PickaxeBuilder.Build(def: Items.ItemDef): Tool
	local build = STYLE_BUILDERS[def.Style] or buildIron
	local b = build(def)
	if def.Order >= 3 then
		addTrail(b, def)
	end
	return b.tool
end

return PickaxeBuilder
