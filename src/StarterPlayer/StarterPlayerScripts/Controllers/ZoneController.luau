--!strict
-- Zone gates (opened locally once unlocked, with an "Unlock" prompt that follows you along the wall)
-- and per-zone lighting moods tweened when the server reports you entered a new zone.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local LightingPresets = require(Shared.LightingPresets)
local Types = require(Shared.Types)
local ZoneUtil = require(Shared.ZoneUtil)
local Zones = require(Shared.Config.Zones)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

type GateState = {
	Gate: Instance,
	Zone: Zones.ZoneDef,
	Anchor: BasePart,
	PromptAttachment: Attachment?,
	Open: boolean,
}

local ZoneController = {}

local gates: { [Instance]: GateState } = {}
local unlocking = false

local function gateParts(gate: Instance): { BasePart }
	if gate:IsA("BasePart") then
		return { gate }
	end
	local parts = {}
	for _, descendant in gate:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function requestUnlock(zone: Zones.ZoneDef)
	if unlocking then
		return
	end
	unlocking = true
	task.spawn(function()
		local ok, success, message = pcall(function()
			return Remotes.Purchase:InvokeServer("Zone", zone.Id)
		end)
		unlocking = false
		if ok and type(message) == "string" then
			HudController.Toast(message, if success then UIKit.Colors.Green else UIKit.Colors.Red)
		end
	end)
end

local function addLockedVisuals(state: GateState)
	local zone = state.Zone
	local attachment = Instance.new("Attachment")
	attachment.Name = "UnlockPrompt"
	attachment.Parent = state.Anchor

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Unlock (💎 {Format.Abbreviate(zone.Price)})`
	prompt.ObjectText = zone.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		requestUnlock(zone)
	end)
	prompt.Parent = attachment

	local billboard = UIKit.Create("BillboardGui", {
		Name = "LockSign",
		Size = UDim2.fromOffset(320, 90),
		StudsOffsetWorldSpace = Vector3.new(0, state.Anchor.Size.Y / 2 + 4, 0),
		MaxDistance = 250,
		LightInfluence = 0,
		Parent = state.Anchor,
	})
	UIKit.Label({
		Size = UDim2.fromScale(1, 0.55),
		Text = `🔒 {zone.Name}`,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})
	UIKit.Label({
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.6),
		Text = `💎 {Format.Abbreviate(zone.Price)}`,
		TextColor3 = UIKit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})
	state.PromptAttachment = attachment
end

local function openGate(state: GateState, animate: boolean)
	state.Open = true
	if state.PromptAttachment then
		state.PromptAttachment:Destroy()
		state.PromptAttachment = nil
	end
	local sign = state.Anchor:FindFirstChild("LockSign")
	if sign then
		sign:Destroy()
	end
	for _, part in gateParts(state.Gate) do
		-- Collision changes on the client only affect this player's own character.
		part.CanCollide = false
		if animate then
			TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		else
			part.Transparency = 1
		end
	end
	if animate then
		HudController.Banner(`{state.Zone.Name} unlocked!`)
	end
end

local function refreshGate(state: GateState, data: Types.PlayerData?, animate: boolean)
	local unlocked = data ~= nil and data.UnlockedZones[state.Zone.Id] == true
	if unlocked and not state.Open then
		openGate(state, animate)
	elseif not unlocked and not state.Open and not state.PromptAttachment then
		addLockedVisuals(state)
	end
end

local function trackGate(gate: Instance)
	local zone = Zones.ById[ZoneUtil.GetZoneId(gate) or ""]
	local anchor = ZoneUtil.GetAnchorPart(gate)
	if not zone or not anchor or gates[gate] then
		return
	end
	local state: GateState = { Gate = gate, Zone = zone, Anchor = anchor, Open = false }
	gates[gate] = state
	refreshGate(state, DataController.Get(), false)
end

-- Keep each locked gate's prompt at the point on the wall closest to the player.
local function updatePromptPositions()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	for _, state in gates do
		local attachment = state.PromptAttachment
		if attachment then
			local half = state.Anchor.Size / 2
			local relative = state.Anchor.CFrame:PointToObjectSpace(root.Position)
			attachment.Position = Vector3.new(
				math.clamp(relative.X, -half.X, half.X),
				math.clamp(relative.Y, -half.Y, half.Y),
				math.clamp(relative.Z, -half.Z, half.Z)
			)
		end
	end
end

local function applyLighting(presetName: string, duration: number)
	local preset = LightingPresets.Presets[presetName] or LightingPresets.Presets[LightingPresets.Default]
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local targets: { [string]: { Instance: Instance?, Goals: { [string]: any } } } = {
		Lighting = { Instance = Lighting, Goals = preset.Lighting },
		Atmosphere = { Instance = Lighting:FindFirstChildOfClass("Atmosphere"), Goals = preset.Atmosphere },
		ColorCorrection = {
			Instance = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
			Goals = preset.ColorCorrection,
		},
		Bloom = { Instance = Lighting:FindFirstChildOfClass("BloomEffect"), Goals = preset.Bloom },
	}
	for _, target in targets do
		if target.Instance then
			TweenService:Create(target.Instance, info, target.Goals):Play()
		end
	end
end

local function onZoneChanged(animate: boolean)
	local zoneId = player:GetAttribute("Zone")
	local zone = if typeof(zoneId) == "string" then Zones.ById[zoneId] else nil
	applyLighting(if zone then zone.Lighting else LightingPresets.Default, if animate then 1.5 else 0)
	if zone and animate then
		HudController.Banner(zone.Name)
	end
end

function ZoneController.Start()
	for _, gate in CollectionService:GetTagged(ZoneUtil.GateTag) do
		trackGate(gate)
	end
	CollectionService:GetInstanceAddedSignal(ZoneUtil.GateTag):Connect(trackGate)
	CollectionService:GetInstanceRemovedSignal(ZoneUtil.GateTag):Connect(function(gate)
		gates[gate] = nil
	end)

	-- Only animate unlocks that happen during this session, not the initial load.
	local seenData = false
	DataController.Observe(function(data)
		for _, state in gates do
			refreshGate(state, data, seenData)
		end
		seenData = true
	end)

	RunService.Heartbeat:Connect(updatePromptPositions)

	onZoneChanged(false)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		onZoneChanged(true)
	end)
end

return ZoneController
