--!strict
-- Click/tap (or hold) to swing. Targets the crystal under the pointer, or the nearest one in reach so
-- mobile players never have to aim precisely. The server re-validates everything.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Progression = require(Shared.Config.Progression)
local ZoneUtil = require(Shared.ZoneUtil)
local Zones = require(Shared.Config.Zones)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local MiningController = {}

local holding = false
local lastSwing = 0
local boundTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local burstAttachment: Attachment
local burstEmitter: ParticleEmitter

local function getCharacterParts(): (Model?, BasePart?, Tool?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and not tool:GetAttribute("ItemId") then
		tool = nil
	end
	return character, if root and root:IsA("BasePart") then root else nil, tool
end

local function findNode(instance: Instance?): Instance?
	local current = instance
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, ZoneUtil.NodeTag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function distanceTo(node: Instance, origin: Vector3): number
	local position = ZoneUtil.GetPosition(node)
	return if position then (position - origin).Magnitude else math.huge
end

local function pickTarget(character: Model, root: BasePart): Instance?
	local camera = Workspace.CurrentCamera
	if camera then
		local pointer = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
		local node = hit and findNode(hit.Instance)
		if node and distanceTo(node, root.Position) <= Progression.MineReach then
			return node
		end
	end

	local best, bestDistance = nil, Progression.MineReach
	for _, node in CollectionService:GetTagged(ZoneUtil.NodeTag) do
		if node:IsDescendantOf(Workspace) then
			local distance = distanceTo(node, root.Position)
			if distance < bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best
end

local function flash(node: Instance)
	local highlight = Instance.new("Highlight")
	highlight.Adornee = node
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = node
	TweenService:Create(highlight, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
	task.delay(0.2, function()
		highlight:Destroy()
	end)
end

local function burst(position: Vector3, color: Color3, count: number)
	burstAttachment.Position = position
	burstEmitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	burstEmitter:Emit(count)
end

local function shakeCamera(strength: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for i = 1, 6 do
			local falloff = strength * (1 - i / 6)
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * falloff
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- The default Animate script plays the tool slash when it sees this value.
local function playSwing(tool: Tool)
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = "Slash"
	animation.Parent = tool
end

local function swing()
	local data = DataController.Get()
	local character, root, tool = getCharacterParts()
	if not data or not character or not root or not tool then
		return
	end
	local now = os.clock()
	if now - lastSwing < Formulas.Cooldown(data) then
		return
	end
	lastSwing = now
	playSwing(tool)

	local node = pickTarget(character, root)
	if node then
		Remotes.MineHit:FireServer(node)
		flash(node)
	end
end

local function bindTool(tool: Tool)
	-- Re-equipping fires ChildAdded again; bind each tool once.
	if not tool:GetAttribute("ItemId") or boundTools[tool] then
		return
	end
	boundTools[tool] = true
	tool.Activated:Connect(function()
		holding = true
		swing()
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
	end)
end

local function onCharacter(character: Model)
	holding = false
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
end

local function zoneColor(zoneId: string?): Color3
	local zone = zoneId and Zones.ById[zoneId]
	return if zone then zone.CrystalColor else UIKit.Colors.Gold
end

function MiningController.Start()
	burstAttachment = Instance.new("Attachment")
	burstAttachment.Name = "MiningBurst"
	burstAttachment.Parent = Workspace.Terrain
	burstEmitter = Instance.new("ParticleEmitter")
	burstEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burstEmitter.Enabled = false
	burstEmitter.LightEmission = 1
	burstEmitter.Lifetime = NumberRange.new(0.35, 0.7)
	burstEmitter.Speed = NumberRange.new(8, 16)
	burstEmitter.SpreadAngle = Vector2.new(180, 180)
	burstEmitter.Acceleration = Vector3.new(0, -30, 0)
	burstEmitter.Size = NumberSequence.new(0.5, 0)
	burstEmitter.Parent = burstAttachment

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	RunService.Heartbeat:Connect(function()
		if holding then
			swing()
		end
	end)

	Remotes.MineFeedback.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "Hit" and typeof(a) == "Instance" then
			local position = ZoneUtil.GetPosition(a)
			if not position then
				return
			end
			local crit = c == true
			local color = zoneColor(ZoneUtil.GetZoneId(a))
			-- Auto-Mine hits arrive without a local click; still show the swing.
			local _, _, tool = getCharacterParts()
			if tool and os.clock() - lastSwing > 0.25 then
				playSwing(tool)
				flash(a)
			end
			burst(position + Vector3.new(0, 2, 0), color, if crit then 24 else 10)
			HudController.Popup(
				position,
				(if crit then "CRIT! +" else "+") .. Format.Abbreviate(b) .. " 💎",
				if crit then UIKit.Colors.Gold else Color3.new(1, 1, 1),
				crit
			)
			if crit then
				shakeCamera(0.35)
			end
		elseif kind == "Break" and typeof(a) == "Vector3" then
			burst(a + Vector3.new(0, 2, 0), zoneColor(b), 40)
		end
	end)
end

return MiningController
