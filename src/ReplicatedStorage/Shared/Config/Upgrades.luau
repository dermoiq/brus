--!strict
-- Stat upgrades sold at the Upgrade Station. Cost of the next level = BaseCost * CostGrowth ^ currentLevel.
-- Upgrades reset on rebirth.

export type UpgradeDef = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Order: number,
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	Step: number,
}

local List: { UpgradeDef } = {
	{
		Id = "GemMultiplier",
		Name = "Gem Multiplier",
		Icon = "💎",
		Description = "+25% Gems from every swing",
		Order = 1,
		BaseCost = 15,
		CostGrowth = 1.38,
		MaxLevel = 100,
		Step = 0.25,
	},
	{
		Id = "SwingSpeed",
		Name = "Swing Speed",
		Icon = "⚡",
		Description = "-3.5% time between swings",
		Order = 2,
		BaseCost = 35,
		CostGrowth = 1.5,
		MaxLevel = 20,
		Step = 0.035,
	},
	{
		Id = "LuckyStrike",
		Name = "Lucky Strike",
		Icon = "🍀",
		Description = "+2% chance to CRIT for 5x Gems",
		Order = 3,
		BaseCost = 120,
		CostGrowth = 1.55,
		MaxLevel = 25,
		Step = 0.02,
	},
}

local ById: { [string]: UpgradeDef } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
}
