--!strict
-- Builds the procedural world when Workspace.Zones is empty: the lobby island at the origin, one themed
-- floating island per entry in Config/Zones along +Z, and the plank bridges between them. Everything
-- follows the folder/tag contract in docs/04-studio-hierarchy.md, so a hand-built map placed in
-- Workspace.Zones takes precedence and this does nothing. Synchronous; call once at server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local Kit = require(script.Parent.Kit)
local Land = require(script.Parent.Land)
local Lobby = require(script.Parent.Lobby)
local Placer = require(script.Parent.Placer)
local Props = require(script.Parent.Props)
local Types = require(script.Parent.Types)
local ZoneIsland = require(script.Parent.ZoneIsland)

local Themes = script.Parent.Themes
local THEMES: { [string]: Types.Theme } = {
	SunlitQuarry = require(Themes.SunlitQuarry),
	GlowshroomGrotto = require(Themes.GlowshroomGrotto),
	FrostfireRift = require(Themes.FrostfireRift),
	MagmaForge = require(Themes.MagmaForge),
	CelestialVault = require(Themes.CelestialVault),
}

local M = Enum.Material

local WorldBuilder = {}

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Zones added to Config/Zones later get a plain rocky island with crystal formations in their colour.
local function genericTheme(zone: Zones.ZoneDef): Types.Theme
	return {
		Style = { Top = M.Rock, Cliff = M.Rock, Strata = M.Slate, Under = M.Slate, Deep = M.Basalt },
		Paving = { Material = M.Slate, Color = Kit.tint(zone.FloorColor, -0.3) },
		Stone = { Material = M.Slate, Color = Kit.tint(zone.FloorColor, -0.5) },
		Path = M.Cobblestone,
		Bridge = Color3.fromRGB(120, 88, 60),
		Build = function(ctx: Types.ZoneCtx)
			for index = 1, 4 do
				local spot =
					Placer.find(ctx.Placer, ctx.Rng, { Clear = 9, Margin = 4, MinDist = 30, MaxDist = 110, Tries = 40 })
				if spot then
					Props.crystal(
						ctx.Scenery,
						CFrame.new(spot),
						ctx.Rng:NextNumber(18, 32),
						zone.CrystalColor,
						ctx.Rng,
						{
							Light = index <= 2,
							Sparkles = index == 1,
						}
					)
				end
			end
			Land.debris(ctx.Center, ctx.Radius, ctx.Rng, { M.Rock, M.Slate }, 12)
		end,
	}
end

local function setupTerrain()
	local terrain = Workspace.Terrain
	local palette: { [Enum.Material]: Color3 } = {
		[M.Grass] = Color3.fromRGB(106, 168, 74),
		[M.LeafyGrass] = Color3.fromRGB(78, 142, 66),
		[M.Ground] = Color3.fromRGB(132, 102, 74),
		[M.Rock] = Color3.fromRGB(128, 116, 112),
		[M.Cobblestone] = Color3.fromRGB(150, 140, 152),
		[M.Sandstone] = Color3.fromRGB(214, 168, 110),
		[M.Slate] = Color3.fromRGB(62, 78, 80),
		[M.Mud] = Color3.fromRGB(52, 70, 58),
		[M.Snow] = Color3.fromRGB(240, 246, 255),
		[M.Glacier] = Color3.fromRGB(160, 208, 238),
		[M.Ice] = Color3.fromRGB(186, 224, 250),
		[M.Basalt] = Color3.fromRGB(50, 43, 46),
		[M.Asphalt] = Color3.fromRGB(40, 35, 38),
		[M.CrackedLava] = Color3.fromRGB(255, 120, 50),
		[M.Limestone] = Color3.fromRGB(232, 226, 242),
		[M.Salt] = Color3.fromRGB(242, 238, 252),
		[M.Pavement] = Color3.fromRGB(206, 200, 222),
	}
	for material, color in palette do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = Color3.fromRGB(52, 156, 178)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.7
		clouds.Color = Color3.fromRGB(255, 240, 250)
		clouds.Parent = terrain
	end
end

function WorldBuilder.BuildIfEmpty()
	local existing = Workspace:FindFirstChild("Zones")
	if existing and #existing:GetChildren() > 0 then
		return
	end
	local started = os.clock()
	local zonesFolder = existing or folder("Zones", Workspace)
	local bridges = Workspace:FindFirstChild("Bridges") or folder("Bridges", Workspace)

	setupTerrain()
	Kit.ReservedLights = #Zones.List * ZoneIsland.NodeCount
	Lobby.build()

	local previousTip = Lobby.NorthTip
	for index, zone in Zones.List do
		local theme = THEMES[zone.Id] or genericTheme(zone)
		local ctx = ZoneIsland.build(zonesFolder, zone, theme, index == #Zones.List)
		local bridge =
			Props.bridge(bridges, Vector3.new(0, 0.2, previousTip + 6), Vector3.new(0, 0.2, ctx.SouthTip - 6), {
				Plank = theme.Bridge,
				Glow = zone.CrystalColor,
				Seed = index,
				Variant = if index == 1 then "Lobby_WoodPlanks" else nil,
			})
		bridge.Name = "Bridge_" .. zone.Id
		previousTip = ctx.NorthTip
	end
	Kit.clearWalkable()

	local stats = Kit.Stats
	print(
		string.format(
			"[WorldBuilder] Built lobby + %d islands: %d parts, %d lights, %d particle emitters, %d terrain ops in %.2fs",
			#Zones.List,
			stats.Parts,
			stats.Lights,
			stats.Emitters,
			stats.TerrainOps,
			os.clock() - started
		)
	)
end

return WorldBuilder
