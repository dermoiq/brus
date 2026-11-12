--!strict
-- Pure game-math shared by server (authoritative) and client (display only).

local Shared = script.Parent
local Auras = require(Shared.Config.Auras)
local Items = require(Shared.Config.Items)
local Monetization = require(Shared.Config.Monetization)
local Progression = require(Shared.Config.Progression)
local Rebirths = require(Shared.Config.Rebirths)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)

type PlayerData = Types.PlayerData
type Perks = Types.Perks

local Formulas = {}

local NO_PERKS: Perks = {}

-- Pass ownership mirrored into attributes by the server's MonetizationService (clients can't change them).
function Formulas.Perks(player: Player): Perks
	local perks: Perks = {}
	for _, pass in Monetization.Gamepasses do
		perks[pass.Key] = player:GetAttribute(Monetization.AttributePrefix .. pass.Key) == true
	end
	return perks
end

function Formulas.UpgradeLevel(data: PlayerData, id: string): number
	return data.Upgrades[id] or 0
end

function Formulas.UpgradeCost(id: string, level: number): number
	local def = Upgrades.ById[id]
	return math.floor(def.BaseCost * def.CostGrowth ^ level)
end

function Formulas.RebirthMultiplier(rebirths: number): number
	return (1 + Rebirths.LinearBonus * rebirths) * Rebirths.CompoundBonus ^ rebirths
end

function Formulas.RebirthCost(rebirths: number): number
	return math.floor(Rebirths.BaseCost * Rebirths.CostGrowth ^ rebirths * Formulas.RebirthMultiplier(rebirths))
end

-- Returns the current rank, its index, and the next rank (nil at the top).
function Formulas.RebirthRank(rebirths: number): (Rebirths.Rank, number, Rebirths.Rank?)
	local index = 1
	for i, rank in Rebirths.Ranks do
		if rebirths >= rank.Threshold then
			index = i
		end
	end
	return Rebirths.Ranks[index], index, Rebirths.Ranks[index + 1]
end

function Formulas.BoostActive(data: PlayerData, now: number?): boolean
	return data.Boosts.GemsUntil > (now or os.time())
end

function Formulas.Multiplier(data: PlayerData, perks: Perks?, now: number?): number
	local p = perks or NO_PERKS
	local fromUpgrade = 1 + Formulas.UpgradeLevel(data, "GemMultiplier") * Upgrades.ById.GemMultiplier.Step
	local fromLevel = 1 + (data.Level - 1) * Progression.LevelBonus
	local total = fromUpgrade * Formulas.RebirthMultiplier(data.Rebirths) * fromLevel
	if p.DoubleGems then
		total *= Monetization.Perks.DoubleGemsMultiplier
	end
	if p.VIP then
		total *= Monetization.Perks.VIPMultiplier
	end
	if Formulas.BoostActive(data, now) then
		total *= Monetization.Perks.BoostMultiplier
	end
	return total
end

function Formulas.Cooldown(data: PlayerData): number
	local reduction = Formulas.UpgradeLevel(data, "SwingSpeed") * Upgrades.ById.SwingSpeed.Step
	return Progression.BaseSwingCooldown * math.max(1 - reduction, Progression.MinCooldownFactor)
end

function Formulas.CritChance(data: PlayerData, perks: Perks?): number
	local chance = Formulas.UpgradeLevel(data, "LuckyStrike") * Upgrades.ById.LuckyStrike.Step
	if perks and perks.ExtraLuck then
		chance += Monetization.Perks.ExtraLuckChance
	end
	return math.min(chance, 0.9)
end

function Formulas.CritMultiplier(perks: Perks?): number
	if perks and perks.ExtraLuck then
		return Progression.CritMultiplier * Monetization.Perks.ExtraLuckCritBonus
	end
	return Progression.CritMultiplier
end

function Formulas.OwnsItem(data: PlayerData, def: Items.ItemDef, perks: Perks?): boolean
	if def.Gamepass then
		return perks ~= nil and perks[def.Gamepass] == true
	elseif def.RebirthRequired then
		return data.Rebirths >= def.RebirthRequired
	end
	return data.OwnedItems[def.Id] == true
end

function Formulas.OwnsAura(data: PlayerData, def: Auras.AuraDef, perks: Perks?): boolean
	if def.Gamepass then
		return perks ~= nil and perks[def.Gamepass] == true
	end
	return data.Rebirths >= (def.RebirthRequired or 0)
end

function Formulas.BestOwnedItem(data: PlayerData, perks: Perks?): string
	local best = Items.ById[Items.Default]
	for _, def in Items.List do
		if def.Power > best.Power and Formulas.OwnsItem(data, def, perks) then
			best = def
		end
	end
	return best.Id
end

-- The pickaxe actually in use: the saved choice while it's owned, otherwise the best owned one. This keeps a
-- VIP pick equipped across joins even though pass ownership is verified a moment after data loads.
function Formulas.EquippedItem(data: PlayerData, perks: Perks?): Items.ItemDef
	local def = Items.ById[data.EquippedItem]
	if def and Formulas.OwnsItem(data, def, perks) then
		return def
	end
	return Items.ById[Formulas.BestOwnedItem(data, perks)]
end

function Formulas.EquippedAura(data: PlayerData, perks: Perks?): Auras.AuraDef
	local def = Auras.ById[data.EquippedAura]
	if def and Formulas.OwnsAura(data, def, perks) then
		return def
	end
	return Auras.ById[Auras.Default]
end

function Formulas.Power(data: PlayerData, perks: Perks?): number
	return Formulas.EquippedItem(data, perks).Power
end

function Formulas.HitReward(data: PlayerData, zone: Zones.ZoneDef, perks: Perks?, now: number?): number
	local raw = zone.NodeValue * Formulas.Power(data, perks) * Formulas.Multiplier(data, perks, now)
	return math.max(1, math.floor(raw + 0.5))
end

function Formulas.BestZone(data: PlayerData): Zones.ZoneDef
	local best = Zones.ById[Zones.Default]
	for _, zone in Zones.List do
		if data.UnlockedZones[zone.Id] and zone.Order > best.Order then
			best = zone
		end
	end
	return best
end

-- Expected income while mining the best unlocked zone, including average crit value.
function Formulas.GemsPerSecond(data: PlayerData, perks: Perks?): number
	local critBonus = 1 + Formulas.CritChance(data, perks) * (Formulas.CritMultiplier(perks) - 1)
	return Formulas.HitReward(data, Formulas.BestZone(data), perks) * critBonus / Formulas.Cooldown(data)
end

function Formulas.GemPackAmount(data: PlayerData, minutes: number, minGems: number, perks: Perks?): number
	return math.max(minGems, math.floor(Formulas.GemsPerSecond(data, perks) * 60 * minutes))
end

function Formulas.XPToNext(level: number): number
	return math.floor(25 * level ^ 1.6)
end

return Formulas
