--!strict
-- Client-only decoration motion (no network cost): spins instances tagged AmbientSpin (attribute SpinSpeed,
-- degrees/second around their own up axis), bobs instances tagged AmbientBob (BobHeight studs, BobSpeed
-- cycles/second) and pulses the Brightness of lights tagged AmbientPulse (PulseSpeed cycles/second,
-- PulseAmount fraction). Works with anchored BaseParts and Models, survives streaming, and skips anything
-- far from the camera. Motion is driven by server time so every client sees the same phase.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SPIN_TAG = "AmbientSpin"
local BOB_TAG = "AmbientBob"
local PULSE_TAG = "AmbientPulse"
local MAX_DISTANCE = 700
local TAU = math.pi * 2

type Mover = {
	Target: PVInstance,
	Base: CFrame?, -- captured on the first frame after the instance appears
	Spin: number, -- radians per second
	BobHeight: number,
	BobSpeed: number,
	Phase: number,
}

type Pulser = {
	Light: Light,
	Base: number?,
	Speed: number,
	Amount: number,
	Phase: number,
}

local AmbientController = {}

local movers: { [Instance]: Mover } = {}
local pulsers: { [Instance]: Pulser } = {}
local started = false

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function phaseOf(position: Vector3): number
	return (position.X * 0.0173 + position.Y * 0.0071 + position.Z * 0.0119) % 1
end

local function pose(target: PVInstance, cframe: CFrame)
	if target:IsA("BasePart") then
		target.CFrame = cframe
	else
		target:PivotTo(cframe)
	end
end

local function refreshMover(instance: Instance)
	if not instance:IsA("BasePart") and not instance:IsA("Model") then
		return
	end
	local spinning = instance:HasTag(SPIN_TAG)
	local bobbing = instance:HasTag(BOB_TAG)
	local mover = movers[instance]
	if not spinning and not bobbing then
		if mover then
			movers[instance] = nil
			local base = mover.Base
			if base and instance:IsDescendantOf(Workspace) then
				pose(mover.Target, base)
			end
		end
		return
	end
	if not mover then
		mover = { Target = instance :: PVInstance, Spin = 0, BobHeight = 0, BobSpeed = 0, Phase = 0 }
		movers[instance] = mover
	end
	local current = mover :: Mover
	current.Spin = if spinning then math.rad(numberAttribute(instance, "SpinSpeed", 30)) else 0
	current.BobHeight = if bobbing then numberAttribute(instance, "BobHeight", 1) else 0
	current.BobSpeed = if bobbing then numberAttribute(instance, "BobSpeed", 0.25) else 0
end

local function refreshPulser(instance: Instance)
	if not instance:IsA("Light") then
		return
	end
	if not instance:HasTag(PULSE_TAG) then
		local pulser = pulsers[instance]
		pulsers[instance] = nil
		local base = if pulser then pulser.Base else nil
		if base and instance:IsDescendantOf(Workspace) then
			instance.Brightness = base
		end
		return
	end
	pulsers[instance] = pulsers[instance]
		or {
			Light = instance,
			Speed = numberAttribute(instance, "PulseSpeed", 0.5),
			Amount = numberAttribute(instance, "PulseAmount", 0.3),
			Phase = 0,
		}
end

-- Fires both when a tag is removed and when a tagged instance leaves the DataModel (e.g. streams out).
local function onRemoved(instance: Instance)
	if instance:IsDescendantOf(Workspace) then
		refreshMover(instance)
		refreshPulser(instance)
	else
		movers[instance] = nil
		pulsers[instance] = nil
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	local focus = if camera then camera.CFrame.Position else nil
	local now = Workspace:GetServerTimeNow()

	for instance, mover in movers do
		if not instance.Parent then
			movers[instance] = nil
			continue
		end
		local subject = mover.Target
		local base = mover.Base
		if not base then
			local captured = if subject:IsA("BasePart") then subject.CFrame else subject:GetPivot()
			mover.Base = captured
			mover.Phase = phaseOf(captured.Position)
			base = captured
		end
		local origin = base :: CFrame
		if focus and (origin.Position - focus).Magnitude > MAX_DISTANCE then
			continue
		end
		local goal = origin
		if mover.BobHeight ~= 0 then
			goal += Vector3.new(0, math.sin((now * mover.BobSpeed + mover.Phase) * TAU) * mover.BobHeight, 0)
		end
		if mover.Spin ~= 0 then
			goal *= CFrame.Angles(0, (now * mover.Spin + mover.Phase * TAU) % TAU, 0)
		end
		pose(subject, goal)
	end

	for instance, pulser in pulsers do
		if not instance.Parent then
			pulsers[instance] = nil
			continue
		end
		local base = pulser.Base
		if not base then
			base = pulser.Light.Brightness
			pulser.Base = base
			local parent = instance.Parent
			pulser.Phase = if parent and parent:IsA("BasePart") then phaseOf(parent.CFrame.Position) else 0
		end
		pulser.Light.Brightness = (base :: number)
			* (1 + pulser.Amount * math.sin((now * pulser.Speed + pulser.Phase) * TAU))
	end
end

function AmbientController.Start()
	if started then
		return
	end
	started = true
	for _, tag in { SPIN_TAG, BOB_TAG } do
		for _, instance in CollectionService:GetTagged(tag) do
			refreshMover(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(refreshMover)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
	end
	for _, instance in CollectionService:GetTagged(PULSE_TAG) do
		refreshPulser(instance)
	end
	CollectionService:GetInstanceAddedSignal(PULSE_TAG):Connect(refreshPulser)
	CollectionService:GetInstanceRemovedSignal(PULSE_TAG):Connect(onRemoved)
	RunService.RenderStepped:Connect(update)
end

return AmbientController
