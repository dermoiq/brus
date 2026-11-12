--!strict
-- Infinite rebirths. A rebirth resets Gems, stat upgrades and shop pickaxes; zones, level, exclusive
-- pickaxes and auras are kept. Every rebirth multiplies all Gems forever:
--   Multiplier(r) = (1 + LinearBonus * r) * CompoundBonus ^ r
--   Cost(r)       = BaseCost * CostGrowth ^ r * Multiplier(r)
-- Cost scales with the player's own multiplier, so every run stays meaningful at any depth.

export type Rank = {
	Name: string,
	Threshold: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

-- 27 named tiers above Novice; rebirths keep counting (and multiplying) past the last one.
local Ranks: { Rank } = {
	{ Name = "Novice", Threshold = 0, Color = rgb(190, 190, 200) },
	{ Name = "Stone", Threshold = 1, Color = rgb(160, 160, 165) },
	{ Name = "Copper", Threshold = 2, Color = rgb(214, 128, 74) },
	{ Name = "Bronze", Threshold = 3, Color = rgb(205, 140, 60) },
	{ Name = "Iron", Threshold = 4, Color = rgb(186, 192, 204) },
	{ Name = "Silver", Threshold = 5, Color = rgb(220, 225, 235) },
	{ Name = "Gold", Threshold = 6, Color = rgb(255, 204, 64) },
	{ Name = "Platinum", Threshold = 8, Color = rgb(196, 236, 246) },
	{ Name = "Emerald", Threshold = 10, Color = rgb(64, 224, 124) },
	{ Name = "Sapphire", Threshold = 12, Color = rgb(70, 130, 255) },
	{ Name = "Ruby", Threshold = 14, Color = rgb(240, 50, 80) },
	{ Name = "Amethyst", Threshold = 16, Color = rgb(176, 96, 255) },
	{ Name = "Diamond", Threshold = 18, Color = rgb(150, 240, 255) },
	{ Name = "Obsidian", Threshold = 20, Color = rgb(120, 90, 160) },
	{ Name = "Mythril", Threshold = 23, Color = rgb(120, 255, 220) },
	{ Name = "Adamant", Threshold = 26, Color = rgb(255, 120, 200) },
	{ Name = "Storm", Threshold = 29, Color = rgb(120, 170, 255) },
	{ Name = "Inferno", Threshold = 32, Color = rgb(255, 110, 40) },
	{ Name = "Glacial", Threshold = 35, Color = rgb(170, 230, 255) },
	{ Name = "Eclipse", Threshold = 38, Color = rgb(255, 190, 90) },
	{ Name = "Nebula", Threshold = 42, Color = rgb(206, 110, 255) },
	{ Name = "Galaxy", Threshold = 46, Color = rgb(140, 120, 255) },
	{ Name = "Quasar", Threshold = 50, Color = rgb(255, 250, 170) },
	{ Name = "Celestial", Threshold = 55, Color = rgb(224, 186, 255) },
	{ Name = "Ascendant", Threshold = 60, Color = rgb(255, 236, 150) },
	{ Name = "Eternal", Threshold = 70, Color = rgb(255, 255, 255) },
	{ Name = "Transcendent", Threshold = 85, Color = rgb(255, 150, 255) },
	{ Name = "Infinity", Threshold = 100, Color = rgb(120, 255, 255) },
}

return {
	LinearBonus = 0.5,
	CompoundBonus = 1.1,
	BaseCost = 2_500_000,
	CostGrowth = 1.4,
	-- Auto-Rebirth becomes available after this many rebirths.
	AutoRebirthUnlock = 3,
	Ranks = Ranks,
}
