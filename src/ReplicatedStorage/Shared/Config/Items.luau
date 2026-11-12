--!strict
-- Pickaxes. Visuals come from ReplicatedStorage.Assets.Items.<Id> (a Tool built from MeshParts with
-- SurfaceAppearance) when it exists; otherwise PickaxeBuilder builds a detailed procedural model for Style.
--
-- Shop pickaxes are bought with Gems and reset on rebirth. Exclusive pickaxes are never sold:
--   RebirthRequired -> owned forever once the player has that many rebirths
--   Gamepass        -> owned while the player owns that pass (key in Config/Monetization)

export type Effect = "None" | "Sparkle" | "Frost" | "Embers" | "Stars" | "Void"

export type Style =
	"Rusty"
	| "Iron"
	| "Gilded"
	| "Amethyst"
	| "Glacier"
	| "Magma"
	| "Celestial"
	| "Phoenix"
	| "Void"
	| "Aurora"
	| "Singularity"
	| "Royal"

export type ItemDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Order: number,
	Price: number,
	Power: number,
	WalkSpeedBonus: number,
	Color: Color3,
	Material: Enum.Material,
	Effect: Effect,
	Style: Style,
	Description: string,
	RebirthRequired: number?,
	Gamepass: string?,
}

local Rarities: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 190, 200),
	Uncommon = Color3.fromRGB(90, 230, 120),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 80, 160),
	Rebirth = Color3.fromRGB(255, 110, 70),
	VIP = Color3.fromRGB(255, 215, 90),
}

local List: { ItemDef } = {
	{
		Id = "RustyPick",
		Name = "Rusty Pick",
		Rarity = "Common",
		Order = 1,
		Price = 0,
		Power = 1,
		WalkSpeedBonus = 0,
		Color = Color3.fromRGB(150, 96, 62),
		Material = Enum.Material.CorrodedMetal,
		Effect = "None",
		Style = "Rusty",
		Description = "Every legend starts somewhere.",
	},
	{
		Id = "IronPick",
		Name = "Iron Pick",
		Rarity = "Common",
		Order = 2,
		Price = 120,
		Power = 3,
		WalkSpeedBonus = 1,
		Color = Color3.fromRGB(196, 202, 212),
		Material = Enum.Material.Metal,
		Effect = "None",
		Style = "Iron",
		Description = "Three times the bite of rust.",
	},
	{
		Id = "GildedPick",
		Name = "Gilded Pick",
		Rarity = "Uncommon",
		Order = 3,
		Price = 1_200,
		Power = 8,
		WalkSpeedBonus = 2,
		Color = Color3.fromRGB(255, 196, 64),
		Material = Enum.Material.Foil,
		Effect = "Sparkle",
		Style = "Gilded",
		Description = "Shiny, heavy, and very effective.",
	},
	{
		Id = "AmethystPick",
		Name = "Amethyst Pick",
		Rarity = "Rare",
		Order = 4,
		Price = 30_000,
		Power = 20,
		WalkSpeedBonus = 3,
		Color = Color3.fromRGB(176, 96, 255),
		Material = Enum.Material.Glass,
		Effect = "Sparkle",
		Style = "Amethyst",
		Description = "Hums with crystal energy.",
	},
	{
		Id = "GlacierPick",
		Name = "Glacier Pick",
		Rarity = "Epic",
		Order = 5,
		Price = 250_000,
		Power = 55,
		WalkSpeedBonus = 4,
		Color = Color3.fromRGB(140, 220, 255),
		Material = Enum.Material.Ice,
		Effect = "Frost",
		Style = "Glacier",
		Description = "Shatters rock with a single chill.",
	},
	{
		Id = "MagmaPick",
		Name = "Magma Pick",
		Rarity = "Legendary",
		Order = 6,
		Price = 8_000_000,
		Power = 150,
		WalkSpeedBonus = 5,
		Color = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.CrackedLava,
		Effect = "Embers",
		Style = "Magma",
		Description = "Forged in the heart of the mountain.",
	},
	{
		Id = "CelestialPick",
		Name = "Celestial Pick",
		Rarity = "Mythic",
		Order = 7,
		Price = 600_000_000,
		Power = 420,
		WalkSpeedBonus = 6,
		Color = Color3.fromRGB(214, 170, 255),
		Material = Enum.Material.Neon,
		Effect = "Stars",
		Style = "Celestial",
		Description = "Mines starlight itself.",
	},
	{
		Id = "PhoenixPick",
		Name = "Phoenix Pick",
		Rarity = "Rebirth",
		Order = 8,
		Price = 0,
		Power = 700,
		WalkSpeedBonus = 7,
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		Effect = "Embers",
		Style = "Phoenix",
		Description = "Reborn from its own ashes. Kept through every rebirth.",
		RebirthRequired = 3,
	},
	{
		Id = "VoidPick",
		Name = "Void Reaver",
		Rarity = "Rebirth",
		Order = 9,
		Price = 0,
		Power = 1_600,
		WalkSpeedBonus = 8,
		Color = Color3.fromRGB(120, 60, 255),
		Material = Enum.Material.Neon,
		Effect = "Void",
		Style = "Void",
		Description = "Carved from the space between stars.",
		RebirthRequired = 10,
	},
	{
		Id = "AuroraPick",
		Name = "Aurora Pick",
		Rarity = "Rebirth",
		Order = 10,
		Price = 0,
		Power = 4_000,
		WalkSpeedBonus = 9,
		Color = Color3.fromRGB(80, 255, 200),
		Material = Enum.Material.Glass,
		Effect = "Sparkle",
		Style = "Aurora",
		Description = "Shimmers with the northern lights.",
		RebirthRequired = 25,
	},
	{
		Id = "SingularityPick",
		Name = "Singularity Pick",
		Rarity = "Rebirth",
		Order = 11,
		Price = 0,
		Power = 10_000,
		WalkSpeedBonus = 10,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Effect = "Void",
		Style = "Singularity",
		Description = "A collapsed star on a stick.",
		RebirthRequired = 50,
	},
	{
		Id = "RoyalPick",
		Name = "Royal Pick",
		Rarity = "VIP",
		Order = 12,
		Price = 0,
		Power = 200,
		WalkSpeedBonus = 6,
		Color = Color3.fromRGB(255, 215, 90),
		Material = Enum.Material.Foil,
		Effect = "Sparkle",
		Style = "Royal",
		Description = "Gold, rubies, and a little bit of swagger.",
		Gamepass = "VIP",
	},
}

local ById: { [string]: ItemDef } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
	Rarities = Rarities,
	Default = "RustyPick",
}
