--!strict
-- Global balance knobs and the saved-data template.

local Types = require(script.Parent.Parent.Types)

local Template: Types.PlayerData = {
	Version = 1,
	Gems = 0,
	TotalGems = 0,
	Level = 1,
	XP = 0,
	Rebirths = 0,
	Upgrades = {},
	OwnedItems = { RustyPick = true },
	EquippedItem = "RustyPick",
	UnlockedZones = { SunlitQuarry = true },
	TutorialStep = 1,
	TutorialProgress = 0,
	TutorialDone = false,
	Settings = { AutoUpgrade = false },
}

return {
	-- Bump the store name only for a deliberate wipe; use Template.Version + migrations otherwise.
	DataStoreName = "CrystalRush_PlayerData_v1",
	AutosaveInterval = 60,

	BaseSwingCooldown = 0.45,
	MinCooldownFactor = 0.2,
	MineReach = 14,
	CritMultiplier = 5,

	LevelBonus = 0.02,
	RebirthBonus = 0.5,
	RebirthBaseCost = 200_000,
	RebirthCostGrowth = 5,

	BaseWalkSpeed = 16,
	AutoUpgradeInterval = 1.5,

	Template = Template,
}
