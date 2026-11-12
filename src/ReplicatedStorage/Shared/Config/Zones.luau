--!strict
-- Zones in unlock order. Each zone must exist as Workspace.Zones.<Id> (see docs/04-studio-hierarchy.md).
-- Lighting names a preset in Shared/LightingPresets.

export type ZoneDef = {
	Id: string,
	Name: string,
	Order: number,
	Price: number,
	NodeValue: number,
	NodeHits: number,
	RespawnTime: number,
	XPPerHit: number,
	Lighting: string,
	CrystalColor: Color3,
	FloorColor: Color3,
	FloorMaterial: Enum.Material,
}

local List: { ZoneDef } = {
	{
		Id = "SunlitQuarry",
		Name = "Sunlit Quarry",
		Order = 1,
		Price = 0,
		NodeValue = 4,
		NodeHits = 6,
		RespawnTime = 4,
		XPPerHit = 1,
		Lighting = "Quarry",
		CrystalColor = Color3.fromRGB(255, 186, 84),
		FloorColor = Color3.fromRGB(214, 176, 128),
		FloorMaterial = Enum.Material.Sandstone,
	},
	{
		Id = "GlowshroomGrotto",
		Name = "Glowshroom Grotto",
		Order = 2,
		Price = 4_000,
		NodeValue = 24,
		NodeHits = 9,
		RespawnTime = 5,
		XPPerHit = 2,
		Lighting = "Grotto",
		CrystalColor = Color3.fromRGB(64, 255, 200),
		FloorColor = Color3.fromRGB(58, 74, 70),
		FloorMaterial = Enum.Material.Rock,
	},
	{
		Id = "FrostfireRift",
		Name = "Frostfire Rift",
		Order = 3,
		Price = 80_000,
		NodeValue = 160,
		NodeHits = 12,
		RespawnTime = 6,
		XPPerHit = 4,
		Lighting = "Frost",
		CrystalColor = Color3.fromRGB(120, 200, 255),
		FloorColor = Color3.fromRGB(200, 226, 245),
		FloorMaterial = Enum.Material.Glacier,
	},
	{
		Id = "MagmaForge",
		Name = "Magma Forge",
		Order = 4,
		Price = 1_600_000,
		NodeValue = 1_200,
		NodeHits = 16,
		RespawnTime = 7,
		XPPerHit = 8,
		Lighting = "Magma",
		CrystalColor = Color3.fromRGB(255, 96, 32),
		FloorColor = Color3.fromRGB(52, 40, 40),
		FloorMaterial = Enum.Material.Basalt,
	},
	{
		Id = "CelestialVault",
		Name = "Celestial Vault",
		Order = 5,
		Price = 32_000_000,
		NodeValue = 10_000,
		NodeHits = 20,
		RespawnTime = 8,
		XPPerHit = 16,
		Lighting = "Celestial",
		CrystalColor = Color3.fromRGB(214, 140, 255),
		FloorColor = Color3.fromRGB(236, 230, 250),
		FloorMaterial = Enum.Material.Marble,
	},
}

local ById: { [string]: ZoneDef } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
	Default = "SunlitQuarry",
}
