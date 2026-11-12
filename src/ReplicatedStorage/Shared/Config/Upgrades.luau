--!strict
-- Stat upgrades sold at the Upgrade Station. Cost of the next level = BaseCost * CostGrowth ^ currentLevel.

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
		BaseCost = 40,
		CostGrowth = 1.55,
		MaxLevel = 60,
		Step = 0.25,
	},
	{
		Id = "SwingSpeed",
		Name = "Swing Speed",
		Icon = "⚡",
		Description = "-4% time between swings",
		Order = 2,
		BaseCost = 120,
		CostGrowth = 1.7,
		MaxLevel = 20,
		Step = 0.04,
	},
	{
		Id = "LuckyStrike",
		Name = "Lucky Strike",
		Icon = "🍀",
		Description = "+2% chance to CRIT for 5x Gems",
		Order = 3,
		BaseCost = 500,
		CostGrowth = 1.9,
		MaxLevel = 20,
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
