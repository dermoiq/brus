--!strict
-- Cosmetic auras worn around the character. Unlocked by rebirth count or a game pass (key in
-- Config/Monetization); never sold for Gems.

export type AuraEffect = "None" | "Flame" | "Ring" | "Sparkle" | "Prism" | "Void" | "Stars" | "Crown"

export type AuraDef = {
	Id: string,
	Name: string,
	Order: number,
	Effect: AuraEffect,
	Color: Color3,
	Color2: Color3,
	Description: string,
	RebirthRequired: number?,
	Gamepass: string?,
}

local rgb = Color3.fromRGB

local List: { AuraDef } = {
	{
		Id = "None",
		Name = "No Aura",
		Order = 0,
		Effect = "None",
		Color = rgb(200, 200, 200),
		Color2 = rgb(255, 255, 255),
		Description = "Keep it simple.",
	},
	{
		Id = "Ember",
		Name = "Ember Aura",
		Order = 1,
		Effect = "Flame",
		Color = rgb(255, 140, 40),
		Color2 = rgb(255, 60, 20),
		Description = "Smoldering sparks rise around you.",
		RebirthRequired = 1,
	},
	{
		Id = "Tidal",
		Name = "Tidal Aura",
		Order = 2,
		Effect = "Ring",
		Color = rgb(60, 200, 255),
		Color2 = rgb(160, 255, 255),
		Description = "Rippling rings of light at your feet.",
		RebirthRequired = 5,
	},
	{
		Id = "Verdant",
		Name = "Verdant Aura",
		Order = 3,
		Effect = "Sparkle",
		Color = rgb(80, 255, 120),
		Color2 = rgb(200, 255, 160),
		Description = "Leaves of light swirl around you.",
		RebirthRequired = 12,
	},
	{
		Id = "Prism",
		Name = "Prism Aura",
		Order = 4,
		Effect = "Prism",
		Color = rgb(255, 80, 200),
		Color2 = rgb(80, 220, 255),
		Description = "Every color at once.",
		RebirthRequired = 20,
	},
	{
		Id = "Eclipse",
		Name = "Eclipse Aura",
		Order = 5,
		Effect = "Void",
		Color = rgb(120, 60, 255),
		Color2 = rgb(20, 0, 40),
		Description = "A shadow that swallows the light.",
		RebirthRequired = 38,
	},
	{
		Id = "Cosmic",
		Name = "Cosmic Aura",
		Order = 6,
		Effect = "Stars",
		Color = rgb(200, 170, 255),
		Color2 = rgb(255, 255, 255),
		Description = "You carry a small galaxy.",
		RebirthRequired = 60,
	},
	{
		Id = "Royal",
		Name = "Royal Aura",
		Order = 7,
		Effect = "Crown",
		Color = rgb(255, 215, 90),
		Color2 = rgb(255, 255, 220),
		Description = "VIP only. Golden sparkles crown your head.",
		Gamepass = "VIP",
	},
}

local ById: { [string]: AuraDef } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
	Default = "None",
}
