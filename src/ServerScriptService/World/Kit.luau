--!strict
-- Low-level building blocks for the procedural world: anchored parts with consistent collision/query flags,
-- budgeted lights and particle emitters, prompts, signs, MaterialVariant hooks and the tags animated by the
-- client's AmbientController.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")

-- Decor:   pure decoration. No collision and ignored by raycasts, so mouse clicks pass through to crystals.
-- Solid:   decoration players bump into (pillars, trunks). Collidable parts are always hit by raycasts.
-- Walk:    floors, bridges and stairs.
-- Crystal: crystal-node pieces. Clickable but not collidable.
-- Ghost:   invisible markers and emitter anchors.
export type Mode = "Decor" | "Solid" | "Walk" | "Crystal" | "Ghost"

export type EmitterSpec = {
	Texture: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Lifetime: NumberRange,
	Rate: number,
	Speed: NumberRange,
	Spread: Vector2?,
	Acceleration: Vector3?,
	Direction: Enum.NormalId?,
	LightEmission: number?,
	LightInfluence: number?,
	Drag: number?,
	RotSpeed: NumberRange?,
	ZOffset: number?,
	Locked: boolean?,
}

local LIGHT_CAP = 150
local EMITTER_CAP = 120

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local Kit = {
	Textures = {
		Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
	},
	Stats = { Parts = 0, Lights = 0, Emitters = 0, TerrainOps = 0 },
	-- Lights still owed to crystal nodes. Decoration lights never eat into them.
	ReservedLights = 0,
}

local walkable: { [Instance]: boolean } = {}
local variantBase: { [string]: Enum.Material | false } = {}

local function finish(
	part: BasePart,
	cf: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	mode: Mode,
	parent: Instance
)
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if mode == "Decor" then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	elseif mode == "Crystal" then
		part.CanCollide = false
		part.CanQuery = true
		part.CastShadow = false
	elseif mode == "Ghost" then
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	elseif mode == "Walk" then
		part.CanCollide = true
		part.CanQuery = true
		walkable[part] = true
	else
		part.CanCollide = true
		part.CanQuery = true
	end
	part.Parent = parent
	Kit.Stats.Parts += 1
end

function Kit.block(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	mode: Mode?
): Part
	local part = Instance.new("Part")
	finish(part, cf, size, material, color, mode or "Decor", parent)
	return part
end

-- WedgePart: full height at local +Z, sloping down towards local -Z.
function Kit.wedge(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	mode: Mode?
): WedgePart
	local part = Instance.new("WedgePart")
	finish(part, cf, size, material, color, mode or "Decor", parent)
	return part
end

-- Upright cylinder centred on cf; its axis follows cf.UpVector.
function Kit.cylinder(
	parent: Instance,
	cf: CFrame,
	height: number,
	radius: number,
	material: Enum.Material,
	color: Color3,
	mode: Mode?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	finish(
		part,
		cf * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, radius * 2, radius * 2),
		material,
		color,
		mode or "Decor",
		parent
	)
	return part
end

-- Cylinder lying along cf.RightVector (wheels, logs, rails).
function Kit.rod(
	parent: Instance,
	cf: CFrame,
	length: number,
	radius: number,
	material: Enum.Material,
	color: Color3,
	mode: Mode?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	finish(part, cf, Vector3.new(length, radius * 2, radius * 2), material, color, mode or "Decor", parent)
	return part
end

function Kit.ball(
	parent: Instance,
	center: Vector3,
	radius: number,
	material: Enum.Material,
	color: Color3,
	mode: Mode?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	local diameter = radius * 2
	finish(
		part,
		CFrame.new(center),
		Vector3.new(diameter, diameter, diameter),
		material,
		color,
		mode or "Decor",
		parent
	)
	return part
end

function Kit.isWalkable(instance: Instance): boolean
	return walkable[instance] == true
end

function Kit.clearWalkable()
	table.clear(walkable)
end

-- Positive t lightens towards white, negative t darkens towards black.
function Kit.tint(color: Color3, t: number): Color3
	return if t >= 0 then color:Lerp(WHITE, t) else color:Lerp(BLACK, -t)
end

function Kit.vary(color: Color3, rng: Random, amount: number): Color3
	return Kit.tint(color, rng:NextNumber(-amount, amount))
end

-- Uses the named MaterialVariant (docs/02-visual-style.md) when the developer has added it to MaterialService.
function Kit.variant(part: BasePart, name: string)
	local base = variantBase[name]
	if base == nil then
		local resolved: Enum.Material | false = false
		local found = MaterialService:FindFirstChild(name, true)
		if found and found:IsA("MaterialVariant") then
			resolved = found.BaseMaterial
		end
		variantBase[name] = resolved
		base = resolved
	end
	if base == part.Material then
		part.MaterialVariant = name
	end
end

function Kit.light(parent: Instance, color: Color3, range: number, brightness: number, essential: boolean?): PointLight?
	if essential then
		Kit.ReservedLights = math.max(Kit.ReservedLights - 1, 0)
	elseif Kit.Stats.Lights + Kit.ReservedLights >= LIGHT_CAP then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 60)
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	Kit.Stats.Lights += 1
	return light
end

function Kit.emitter(parent: Instance, spec: EmitterSpec): ParticleEmitter?
	if Kit.Stats.Emitters >= EMITTER_CAP then
		return nil
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.Texture
	emitter.Color = spec.Color
	emitter.Size = spec.Size
	emitter.Transparency = spec.Transparency
	emitter.Lifetime = spec.Lifetime
	emitter.Rate = spec.Rate
	emitter.Speed = spec.Speed
	emitter.SpreadAngle = spec.Spread or Vector2.new(0, 0)
	emitter.Acceleration = spec.Acceleration or Vector3.new(0, 0, 0)
	emitter.EmissionDirection = spec.Direction or Enum.NormalId.Top
	emitter.LightEmission = spec.LightEmission or 0
	emitter.LightInfluence = spec.LightInfluence or 1
	emitter.Drag = spec.Drag or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = spec.RotSpeed or NumberRange.new(0, 0)
	emitter.ZOffset = spec.ZOffset or 0
	emitter.LockedToPart = spec.Locked == true
	emitter.Parent = parent
	Kit.Stats.Emitters += 1
	return emitter
end

function Kit.fire(parent: Instance, size: number, heat: number, color: Color3, secondary: Color3): Fire?
	if Kit.Stats.Emitters >= EMITTER_CAP then
		return nil
	end
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = heat
	fire.Color = color
	fire.SecondaryColor = secondary
	fire.Parent = parent
	Kit.Stats.Emitters += 1
	return fire
end

-- NumberSequence with evenly spaced keypoints.
function Kit.seq(...: number): NumberSequence
	local values = { ... }
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local points = {}
	for index, value in values do
		table.insert(points, NumberSequenceKeypoint.new((index - 1) / (#values - 1), value))
	end
	return NumberSequence.new(points)
end

-- ColorSequence with evenly spaced keypoints.
function Kit.colors(...: Color3): ColorSequence
	local values = { ... }
	if #values == 1 then
		return ColorSequence.new(values[1])
	end
	local points = {}
	for index, value in values do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#values - 1), value))
	end
	return ColorSequence.new(points)
end

function Kit.range(min: number, max: number?): NumberRange
	return NumberRange.new(min, max or min)
end

function Kit.prompt(parent: Instance, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function Kit.tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

function Kit.spin(instance: Instance, degreesPerSecond: number)
	instance:SetAttribute("SpinSpeed", degreesPerSecond)
	CollectionService:AddTag(instance, "AmbientSpin")
end

function Kit.bob(instance: Instance, height: number, cyclesPerSecond: number)
	instance:SetAttribute("BobHeight", height)
	instance:SetAttribute("BobSpeed", cyclesPerSecond)
	CollectionService:AddTag(instance, "AmbientBob")
end

function Kit.pulse(light: Light?, cyclesPerSecond: number, amount: number)
	if light then
		light:SetAttribute("PulseSpeed", cyclesPerSecond)
		light:SetAttribute("PulseAmount", amount)
		CollectionService:AddTag(light, "AmbientPulse")
	end
end

-- Parents a finished model. Atomic streaming keeps multi-part models (and their animation pivots) whole.
function Kit.finishModel(model: Model, parent: Instance, primary: BasePart?, atomic: boolean?): Model
	if primary then
		model.PrimaryPart = primary
	end
	if atomic then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	model.Parent = parent
	return model
end

function Kit.model(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local function styleLabel(label: TextLabel, text: string, color: Color3)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(28, 18, 44)
	stroke.Thickness = 2.5
	stroke.Parent = label
end

-- World-sized floating sign (width in studs).
function Kit.billboard(
	adornee: BasePart,
	text: string,
	color: Color3,
	height: number,
	width: number,
	maxDistance: number?
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromScale(width, width * 0.25)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 180
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	styleLabel(label, text, color)
	label.Parent = gui
	return gui
end

-- Text painted on one face of a part.
function Kit.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = part
	local label = Instance.new("TextLabel")
	styleLabel(label, text, color)
	label.Parent = gui
	return gui
end

return Kit
