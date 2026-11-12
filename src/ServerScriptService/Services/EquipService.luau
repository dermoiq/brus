--!strict
-- Gives the equipped pickaxe to the character and applies its look (tool model + tier aura) and stats
-- (walk speed). Prefers an artist-made Tool at ReplicatedStorage.Assets.Items.<ItemId>; falls back to a
-- greybox pickaxe so the game is playable before art exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Progression = require(Shared.Config.Progression)
local RateLimiter = require(script.Parent.RateLimiter)
local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage.Remotes
local ItemAssets = ReplicatedStorage.Assets.Items

local AURA_NAME = "TierAura"
local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local EMBER_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local EquipService = {}

local equipLimiter = RateLimiter.new(2, 4)

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
end

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Handle runs along +Y; the head sits across +Z at the top so it lies in the swing plane.
local function buildFallbackTool(def: Items.ItemDef): Tool
	local tool = Instance.new("Tool")
	tool.Grip = CFrame.new(0, -1, 0)

	local handle = makePart("Handle", Vector3.new(0.32, 3.4, 0.32), Color3.fromRGB(92, 62, 40), Enum.Material.Wood)
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local head = makePart("Head", Vector3.new(0.5, 0.55, 3), def.Color, def.Material)
	head.CFrame = CFrame.new(0, 1.55, 0)
	head.Parent = tool
	weld(handle, head)

	if def.Order >= 3 then
		local trim = makePart(
			"Trim",
			Vector3.new(0.56, 0.18, 3.06),
			def.Color:Lerp(Color3.new(1, 1, 1), 0.35),
			Enum.Material.Neon
		)
		trim.CFrame = CFrame.new(0, 1.55, 0)
		trim.Parent = tool
		weld(handle, trim)

		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Range = 6 + def.Order
		light.Brightness = 1.2
		light.Parent = head
	end
	return tool
end

local function buildTool(def: Items.ItemDef): Tool
	local template = ItemAssets:FindFirstChild(def.Id)
	local tool = if template and template:IsA("Tool") then template:Clone() else buildFallbackTool(def)
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", def.Id)
	return tool
end

local function applyAura(character: Model, def: Items.ItemDef)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local existing = root:FindFirstChild(AURA_NAME)
	if existing then
		existing:Destroy()
	end
	if def.Effect == "None" then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = AURA_NAME

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = if def.Effect == "Embers" then EMBER_TEXTURE else PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(def.Color, def.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 4 + def.Order * 2
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.2, 1)
	if def.Effect == "Embers" then
		emitter.Acceleration = Vector3.new(0, 4, 0)
	elseif def.Effect == "Frost" then
		emitter.Acceleration = Vector3.new(0, -2, 0)
	elseif def.Effect == "Stars" then
		emitter.RotSpeed = NumberRange.new(-90, 90)
	end
	emitter.Parent = attachment

	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 8
	light.Brightness = 0.8
	light.Parent = attachment

	attachment.Parent = root
end

local function refreshCharacter(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not character or not humanoid or not backpack then
		return
	end
	local def = Items.ById[data.EquippedItem] or Items.ById[Items.Default]

	for _, container in { backpack :: Instance, character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ItemId") then
				child:Destroy()
			end
		end
	end

	local tool = buildTool(def)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	humanoid.WalkSpeed = Progression.BaseWalkSpeed + def.WalkSpeedBonus
	applyAura(character, def)
	player:SetAttribute("EquippedItem", def.Id)
end

function EquipService.Equip(player: Player, itemId: string): boolean
	local data = DataService.Get(player)
	if not data or not data.OwnedItems[itemId] or not Items.ById[itemId] then
		return false
	end
	DataService.Update(player, function(d)
		d.EquippedItem = itemId
	end)
	refreshCharacter(player)
	return true
end

function EquipService.Start()
	Remotes.Equip.OnServerEvent:Connect(function(player, itemId)
		if not equipLimiter:Check(player) or typeof(itemId) ~= "string" then
			return
		end
		EquipService.Equip(player, itemId)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			-- The Backpack is rebuilt on spawn; give tools after it settles.
			task.defer(refreshCharacter, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	DataService.ProfileLoaded:Connect(function(player: Player)
		refreshCharacter(player)
	end)
end

return EquipService
