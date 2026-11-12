--!strict
-- Pure game-math shared by server (authoritative) and client (display only).

local Shared = script.Parent
local Items = require(Shared.Config.Items)
local Progression = require(Shared.Config.Progression)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)

type PlayerData = Types.PlayerData

local Formulas = {}

function Formulas.UpgradeLevel(data: PlayerData, id: string): number
	return data.Upgrades[id] or 0
end

function Formulas.UpgradeCost(id: string, level: number): number
	local def = Upgrades.ById[id]
	return math.floor(def.BaseCost * def.CostGrowth ^ level)
end

function Formulas.Multiplier(data: PlayerData): number
	local fromUpgrade = 1 + Formulas.UpgradeLevel(data, "GemMultiplier") * Upgrades.ById.GemMultiplier.Step
	local fromRebirths = 1 + data.Rebirths * Progression.RebirthBonus
	local fromLevel = 1 + (data.Level - 1) * Progression.LevelBonus
	return fromUpgrade * fromRebirths * fromLevel
end

function Formulas.Cooldown(data: PlayerData): number
	local reduction = Formulas.UpgradeLevel(data, "SwingSpeed") * Upgrades.ById.SwingSpeed.Step
	return Progression.BaseSwingCooldown * math.max(1 - reduction, Progression.MinCooldownFactor)
end

function Formulas.CritChance(data: PlayerData): number
	return Formulas.UpgradeLevel(data, "LuckyStrike") * Upgrades.ById.LuckyStrike.Step
end

function Formulas.Power(data: PlayerData): number
	local item = Items.ById[data.EquippedItem] or Items.ById[Items.Default]
	return item.Power
end

function Formulas.HitReward(data: PlayerData, zone: Zones.ZoneDef): number
	return math.max(1, math.floor(zone.NodeValue * Formulas.Power(data) * Formulas.Multiplier(data) + 0.5))
end

function Formulas.XPToNext(level: number): number
	return math.floor(25 * level ^ 1.6)
end

function Formulas.RebirthCost(rebirths: number): number
	return Progression.RebirthBaseCost * Progression.RebirthCostGrowth ^ rebirths
end

return Formulas
