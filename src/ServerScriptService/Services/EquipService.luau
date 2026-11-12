--!strict
-- Gives the equipped pickaxe to the character and applies its look (tool model, tier aura, cosmetic aura)
-- and stats (walk speed). Prefers an artist-made Tool at ReplicatedStorage.Assets.Items.<ItemId>; otherwise
-- PickaxeBuilder makes a detailed procedural pickaxe so the game looks finished before custom art exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Config.Auras)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Config.Items)
local Monetization = require(Shared.Config.Monetization)
local Progression = require(Shared.Config.Progression)
local DataService = require(script.Parent.DataService)
local PickaxeBuilder = require(script.Parent.PickaxeBuilder)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes
local ItemAssets = ReplicatedStorage.Assets.Items

local TIER_AURA = "TierAura"
local COSMETIC_AURA = "CosmeticAura"
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local EquipService = {}

local equipLimiter = RateLimiter.new(3, 6)

local function buildTool(def: Items.ItemDef): Tool
	local template = ItemAssets:FindFirstChild(def.Id)
	local tool = if template and template:IsA("Tool") then template:Clone() else PickaxeBuilder.Build(def)
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", def.Id)
	return tool
end

local function emitter(parent: Instance, texture: string, a: Color3, b: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(a, b)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

-- Pickaxe tier aura: soft particles around the body, matching the pickaxe.
local function applyTierAura(root: BasePart, def: Items.ItemDef)
	local existing = root:FindFirstChild(TIER_AURA)
	if existing then
		existing:Destroy()
	end
	if def.Effect == "None" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = TIER_AURA
	local white = def.Color:Lerp(Color3.new(1, 1, 1), 0.5)
	local e = emitter(attachment, if def.Effect == "Embers" then FIRE else SPARKLES, def.Color, white)
	e.Rate = 4 + def.Order * 2
	if def.Effect == "Embers" then
		e.Acceleration = Vector3.new(0, 4, 0)
	elseif def.Effect == "Frost" then
		e.Acceleration = Vector3.new(0, -2, 0)
	elseif def.Effect == "Stars" then
		e.RotSpeed = NumberRange.new(-90, 90)
	elseif def.Effect == "Void" then
		e.Color = ColorSequence.new(def.Color, Color3.new(0.05, 0, 0.1))
		e.LightEmission = 0.4
	end
	light(attachment, def.Color, 8, 0.8)
	attachment.Parent = root
end

-- Shaped emitters need a BasePart parent, so cosmetic auras ride on invisible welded "carrier" parts.
local function carrier(root: BasePart, size: Vector3, offset: CFrame): Part
	local part = Instance.new("Part")
	part.Name = COSMETIC_AURA
	part.Size = size
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = root.Parent
	return part
end

local function applyCosmeticAura(character: Model, root: BasePart, aura: Auras.AuraDef)
	for _, child in character:GetChildren() do
		if child.Name == COSMETIC_AURA then
			child:Destroy()
		end
	end
	if aura.Effect == "None" then
		return
	end

	local body = CFrame.new(0, -0.5, 0)
	local feet = CFrame.new(0, -2.9, 0)
	if aura.Effect == "Flame" then
		local part = carrier(root, Vector3.new(3, 0.2, 3), feet)
		local e = emitter(part, FIRE, aura.Color, aura.Color2)
		e.Rate = 22
		e.Speed = NumberRange.new(2, 4)
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Shape = Enum.ParticleEmitterShape.Disc
		light(part, aura.Color, 10, 1.2)
	elseif aura.Effect == "Ring" or aura.Effect == "Crown" then
		local crown = aura.Effect == "Crown"
		local part = carrier(
			root,
			if crown then Vector3.new(2.2, 0.2, 2.2) else Vector3.new(5, 0.2, 5),
			if crown then CFrame.new(0, 3.4, 0) else feet
		)
		local e = emitter(part, SPARKLES, aura.Color, aura.Color2)
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Rate = if crown then 30 else 45
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(5, 5)
		light(part, aura.Color, if crown then 8 else 12, 1)
	elseif aura.Effect == "Sparkle" or aura.Effect == "Prism" or aura.Effect == "Stars" then
		local part = carrier(root, Vector3.new(4, 5.5, 4), body)
		local e = emitter(part, SPARKLES, aura.Color, aura.Color2)
		e.Shape = if aura.Effect == "Stars" then Enum.ParticleEmitterShape.Sphere else Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Rate = 24
		e.RotSpeed = NumberRange.new(-60, 60)
		if aura.Effect == "Prism" then
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
			})
		end
		light(part, aura.Color, 10, 1)
	elseif aura.Effect == "Void" then
		local part = carrier(root, Vector3.new(3.5, 5, 3.5), body)
		local smoke = emitter(part, SMOKE, aura.Color, aura.Color2)
		smoke.LightEmission = 0.2
		smoke.Rate = 10
		smoke.Size = NumberSequence.new(1.2, 3)
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Shape = Enum.ParticleEmitterShape.Box
		local sparks = emitter(part, SPARKLES, aura.Color, Color3.new(1, 1, 1))
		sparks.Rate = 14
		sparks.Shape = Enum.ParticleEmitterShape.Box
		light(part, aura.Color, 10, 1.5)
	end
end

local function refreshCharacter(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not character or not humanoid or not backpack then
		return
	end
	local perks = Formulas.Perks(player)
	local def = Formulas.EquippedItem(data, perks)

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
	if root and root:IsA("BasePart") then
		applyTierAura(root, def)
		applyCosmeticAura(character, root, Formulas.EquippedAura(data, perks))
	end
	player:SetAttribute("EquippedItem", def.Id)
end

EquipService.Refresh = refreshCharacter

-- kind is "Item" (pickaxe) or "Aura".
function EquipService.Equip(player: Player, kind: string, id: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local perks = Formulas.Perks(player)
	if kind == "Item" then
		local def = Items.ById[id]
		if not def or not Formulas.OwnsItem(data, def, perks) then
			return false
		end
		DataService.Update(player, function(d)
			d.EquippedItem = id
		end)
	elseif kind == "Aura" then
		local def = Auras.ById[id]
		if not def or not Formulas.OwnsAura(data, def, perks) then
			return false
		end
		DataService.Update(player, function(d)
			d.EquippedAura = id
		end)
	else
		return false
	end
	refreshCharacter(player)
	return true
end

function EquipService.Start()
	Remotes.Equip.OnServerEvent:Connect(function(player, kind, id)
		if not equipLimiter:Check(player) or typeof(kind) ~= "string" or typeof(id) ~= "string" then
			return
		end
		EquipService.Equip(player, kind, id)
	end)

	local prefix = Monetization.AttributePrefix
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			-- The Backpack is rebuilt on spawn; give tools after it settles.
			task.defer(refreshCharacter, player)
		end)
		-- Pass ownership arrives a moment after join (or on purchase): re-apply VIP pickaxe/aura.
		player.AttributeChanged:Connect(function(name)
			if string.sub(name, 1, #prefix) == prefix then
				refreshCharacter(player)
			end
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
