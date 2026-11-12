--!strict

export type PlayerData = {
	Version: number,
	Gems: number,
	TotalGems: number,
	Level: number,
	XP: number,
	Rebirths: number,
	Upgrades: { [string]: number },
	OwnedItems: { [string]: boolean },
	EquippedItem: string,
	UnlockedZones: { [string]: boolean },
	TutorialStep: number,
	TutorialProgress: number,
	TutorialDone: boolean,
	Settings: { AutoUpgrade: boolean },
}

return {}
