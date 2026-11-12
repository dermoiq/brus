--!strict
-- Shared types for the island builders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Land = require(script.Parent.Land)
local Placer = require(script.Parent.Placer)

export type Surface = { Material: Enum.Material, Color: Color3, Variant: string? }

export type ZoneCtx = {
	Zone: Zones.ZoneDef,
	Folder: Folder,
	Scenery: Folder,
	Nodes: Folder,
	Center: Vector3, -- island centre on the walkable top
	Radius: number,
	SouthTip: number, -- world Z of the island edge facing the incoming bridge
	NorthTip: number,
	IsLast: boolean,
	Rng: Random,
	Placer: Placer.Placer,
	NodeSpots: { Vector3 }, -- preferred node positions (tried before random placement)
}

export type Theme = {
	Style: Land.Style,
	Paving: Surface, -- landing slabs
	Stone: Surface, -- gatehouse
	Path: Enum.Material, -- terrain path material
	Bridge: Color3, -- plank colour of the bridge leading onto this island
	KeepClear: { Vector3 }?, -- local x/z points kept free of rim lumps (waterfalls)
	Build: (ctx: ZoneCtx) -> (),
	Dress: ((ctx: ZoneCtx) -> ())?, -- small filler, placed after the crystal nodes
}

return {}
