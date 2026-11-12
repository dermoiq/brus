--!strict
-- Robux Store configuration.
--
-- HOW TO SET UP: create each Game Pass / Developer Product for this experience in the Creator Dashboard
-- (Monetization), then paste its numeric ID into `Id` below. An Id of 0 means "not configured yet":
-- the Store shows the item as unavailable and the server ignores it. Prices are set on the Roblox
-- website, and the Store reads them live.

export type PassDef = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Description: string,
	Order: number,
}

export type ProductKind = "Gems" | "Boost" | "Rebirth"

export type ProductDef = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Description: string,
	Order: number,
	Kind: ProductKind,
	Minutes: number?,
	MinGems: number?,
}

local Gamepasses: { PassDef } = {
	{
		Key = "DoubleGems",
		Id = 0, -- <- paste your 2x Gems game pass ID
		Name = "2x Gems",
		Icon = "💎",
		Description = "Double every Gem you earn, forever.",
		Order = 1,
	},
	{
		Key = "VIP",
		Id = 0, -- <- paste your VIP game pass ID
		Name = "VIP",
		Icon = "👑",
		Description = "Royal Pick, Royal Aura, [VIP] chat tag and +25% Gems.",
		Order = 2,
	},
	{
		Key = "AutoMine",
		Id = 0, -- <- paste your Auto-Mine game pass ID
		Name = "Auto-Mine",
		Icon = "🤖",
		Description = "Your pickaxe mines nearby crystals by itself.",
		Order = 3,
	},
	{
		Key = "ExtraLuck",
		Id = 0, -- <- paste your Extra Luck game pass ID
		Name = "Extra Luck",
		Icon = "🍀",
		Description = "+10% crit chance, and crits pay 50% more.",
		Order = 4,
	},
}

local Products: { ProductDef } = {
	{
		Key = "GemsSmall",
		Id = 0, -- <- paste your Developer Product ID
		Name = "Pouch of Gems",
		Icon = "💰",
		Description = "10 minutes of your current mining income.",
		Order = 1,
		Kind = "Gems",
		Minutes = 10,
		MinGems = 1_000,
	},
	{
		Key = "GemsMedium",
		Id = 0, -- <- paste your Developer Product ID
		Name = "Chest of Gems",
		Icon = "🧰",
		Description = "1 hour of your current mining income.",
		Order = 2,
		Kind = "Gems",
		Minutes = 60,
		MinGems = 10_000,
	},
	{
		Key = "GemsLarge",
		Id = 0, -- <- paste your Developer Product ID
		Name = "Vault of Gems",
		Icon = "🏦",
		Description = "4 hours of your current mining income.",
		Order = 3,
		Kind = "Gems",
		Minutes = 240,
		MinGems = 100_000,
	},
	{
		Key = "Boost2x",
		Id = 0, -- <- paste your Developer Product ID
		Name = "2x Gems Boost",
		Icon = "⚡",
		Description = "Double Gems for 15 minutes. Stacks its duration.",
		Order = 4,
		Kind = "Boost",
		Minutes = 15,
	},
	{
		Key = "InstantRebirth",
		Id = 0, -- <- paste your Developer Product ID
		Name = "Instant Rebirth",
		Icon = "🔁",
		Description = "Rebirth right now, no Gems needed.",
		Order = 5,
		Kind = "Rebirth",
	},
}

local PassByKey: { [string]: PassDef } = {}
for _, pass in Gamepasses do
	PassByKey[pass.Key] = pass
end

return {
	Gamepasses = Gamepasses,
	Products = Products,
	PassByKey = PassByKey,
	-- The server mirrors pass ownership into player attributes named AttributePrefix .. Key.
	AttributePrefix = "Pass_",
	Perks = {
		DoubleGemsMultiplier = 2,
		VIPMultiplier = 1.25,
		ExtraLuckChance = 0.1,
		ExtraLuckCritBonus = 1.5,
		BoostMultiplier = 2,
	},
}
