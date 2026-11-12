--!strict
-- Global balance knobs and the saved-data template. Rebirth tuning lives in Config/Rebirths.

local Types = require(script.Parent.Parent.Types)

local Template: Types.PlayerData = {
	Version = 2,
	Gems = 0,
	TotalGems = 0,
	Level = 1,
	XP = 0,
	Rebirths = 0,
	Upgrades = {},
	OwnedItems = { RustyPick = true },
	EquippedItem = "RustyPick",
	EquippedAura = "None",
	UnlockedZones = { SunlitQuarry = true },
	TutorialStep = 1,
	TutorialProgress = 0,
	TutorialDone = false,
	Boosts = { GemsUntil = 0 },
	ProcessedReceipts = {},
	Settings = { AutoUpgrade = false, AutoRebirth = false, AutoMine = true },
}

return {
	-- Bump the store name only for a deliberate wipe; use Template.Version + migrations otherwise.
	DataStoreName = "CrystalRush_PlayerData_v1",
	AutosaveInterval = 60,

	BaseSwingCooldown = 0.3,
	MinCooldownFactor = 0.35,
	MineReach = 14,
	CritMultiplier = 5,

	LevelBonus = 0.02,

	BaseWalkSpeed = 16,
	AutoUpgradeInterval = 1,

	Template = Template,
}
