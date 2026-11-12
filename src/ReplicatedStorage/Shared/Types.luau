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
	EquippedAura: string,
	UnlockedZones: { [string]: boolean },
	TutorialStep: number,
	TutorialProgress: number,
	TutorialDone: boolean,
	-- Unix time (seconds) when the purchased 2x Gems boost runs out.
	Boosts: { GemsUntil: number },
	-- Recent Developer Product PurchaseIds, so a receipt is never granted twice.
	ProcessedReceipts: { string },
	Settings: { AutoUpgrade: boolean, AutoRebirth: boolean, AutoMine: boolean },
}

-- Game pass ownership by pass Key (see Config/Monetization).
export type Perks = { [string]: boolean }

return {}
