--!strict
-- Pickaxe tiers. Visuals come from ReplicatedStorage.Assets.Items.<Id> (a Tool built from MeshParts with
-- SurfaceAppearance) when it exists; otherwise EquipService builds a greybox pickaxe from these colors.

export type Effect = "None" | "Sparkle" | "Frost" | "Embers" | "Stars"

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
	Description: string,
}

local Rarities: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 190, 200),
	Uncommon = Color3.fromRGB(90, 230, 120),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 80, 160),
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
		Description = "Every legend starts somewhere.",
	},
	{
		Id = "IronPick",
		Name = "Iron Pick",
		Rarity = "Common",
		Order = 2,
		Price = 300,
		Power = 2,
		WalkSpeedBonus = 1,
		Color = Color3.fromRGB(196, 202, 212),
		Material = Enum.Material.Metal,
		Effect = "None",
		Description = "Twice the bite of rust.",
	},
	{
		Id = "GildedPick",
		Name = "Gilded Pick",
		Rarity = "Uncommon",
		Order = 3,
		Price = 2_500,
		Power = 5,
		WalkSpeedBonus = 2,
		Color = Color3.fromRGB(255, 196, 64),
		Material = Enum.Material.Foil,
		Effect = "Sparkle",
		Description = "Shiny, heavy, and very effective.",
	},
	{
		Id = "AmethystPick",
		Name = "Amethyst Pick",
		Rarity = "Rare",
		Order = 4,
		Price = 20_000,
		Power = 12,
		WalkSpeedBonus = 3,
		Color = Color3.fromRGB(176, 96, 255),
		Material = Enum.Material.Glass,
		Effect = "Sparkle",
		Description = "Hums with crystal energy.",
	},
	{
		Id = "GlacierPick",
		Name = "Glacier Pick",
		Rarity = "Epic",
		Order = 5,
		Price = 160_000,
		Power = 30,
		WalkSpeedBonus = 4,
		Color = Color3.fromRGB(140, 220, 255),
		Material = Enum.Material.Ice,
		Effect = "Frost",
		Description = "Shatters rock with a single chill.",
	},
	{
		Id = "MagmaPick",
		Name = "Magma Pick",
		Rarity = "Legendary",
		Order = 6,
		Price = 1_400_000,
		Power = 80,
		WalkSpeedBonus = 5,
		Color = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.CrackedLava,
		Effect = "Embers",
		Description = "Forged in the heart of the mountain.",
	},
	{
		Id = "CelestialPick",
		Name = "Celestial Pick",
		Rarity = "Mythic",
		Order = 7,
		Price = 16_000_000,
		Power = 220,
		WalkSpeedBonus = 6,
		Color = Color3.fromRGB(214, 170, 255),
		Material = Enum.Material.Neon,
		Effect = "Stars",
		Description = "Mines starlight itself.",
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
