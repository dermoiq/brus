# Phase 4 — Studio Hierarchy & Setup

With Rojo, `default.project.json` creates everything under ReplicatedStorage, ServerScriptService, StarterPlayerScripts and Lighting. Building by hand? Mirror this tree exactly. File suffixes map to Studio classes like this:
`*.server.luau` → **Script**, `*.client.luau` → **LocalScript**, `*.luau` → **ModuleScript** (name = file name without the suffix).

```
game
├── Workspace                              (everything below is built by World/WorldBuilder at server start)
│   ├── Lobby                              Model            hub island at the origin, walkable top at Y ≈ 0
│   │   ├── Spawn                          SpawnLocation    (0, 0.7, -28), faces +Z toward the first bridge
│   │   ├── UpgradeStation                 Model            ProximityPrompt, attribute OpensShop = true
│   │   ├── StoreStation                   Model            ProximityPrompt, attribute OpensStore = true (Robux Store)
│   │   ├── RebirthAltar                   Model            ProximityPrompt, attribute OpensRebirth = true
│   │   ├── PortalHub                      Model/Folder     one portal per zone: tag Portal, attribute Zone = <zoneId>
│   │   └── … plaza, fountain, arch, lamps, trees, banners, waterfall
│   ├── Bridges                            Folder           plank bridges with railings and lanterns between islands
│   └── Zones                              Folder           ← REQUIRED contract if you replace the map
│       ├── SunlitQuarry                   Folder           name = Id in Config/Zones.luau, island centre z = 360
│       │   ├── Bounds                     Part             invisible box; CanCollide/CanQuery/CanTouch = false
│       │   ├── ArrivalPoint               Part             invisible teleport landing spot, attribute Zone
│       │   ├── ReturnPortal               Model            tag Portal, attribute Zone = "Lobby"
│       │   ├── Nodes                      Folder           14 crystal nodes
│       │   │   └── Node_1 …               Model            tag CrystalNode, attribute Zone, PrimaryPart set
│       │   └── Scenery                    Folder           terraces, landmarks, props, effects
│       ├── GlowshroomGrotto               (same as above, plus:)
│       │   └── Gate                       Part/Model       tag ZoneGate, attribute Zone; blocks the incoming bridge
│       ├── FrostfireRift                  z = 1080
│       ├── MagmaForge                     z = 1440
│       └── CelestialVault                 z = 1800
│   (Terrain holds the island landmasses: cliffs, terraces, cave, water, lava; Terrain/Clouds is created if missing)
│
├── Lighting                               LightingStyle = Realistic, PrioritizeLightingQuality = true (+ values in Phase 2)
│   ├── Atmosphere / Bloom / SunRays / ColorCorrection / DepthOfField
│   └── Sky                                (add your skybox)
│
├── MaterialService                        your MaterialVariants (Phase 2). WorldBuilder applies matching names automatically
│
├── ReplicatedStorage
│   ├── Shared                             Folder
│   │   ├── Config                         Folder
│   │   │   ├── Auras                      ModuleScript     cosmetic auras (rebirth / VIP)
│   │   │   ├── Items                      ModuleScript     12 pickaxes (shop, rebirth-exclusive, VIP)
│   │   │   ├── Monetization               ModuleScript     ← paste your game pass / product IDs here
│   │   │   ├── Progression                ModuleScript     balance knobs + save template
│   │   │   ├── Rebirths                   ModuleScript     rebirth formula, 28 ranks, Auto-Rebirth unlock
│   │   │   ├── Tutorial                   ModuleScript     tutorial steps
│   │   │   ├── Upgrades                   ModuleScript     stat upgrades
│   │   │   └── Zones                      ModuleScript     zones in unlock order
│   │   ├── Format                         ModuleScript     1.2K / 3.4M … up to 1e63
│   │   ├── Formulas                       ModuleScript     multiplier, costs, rebirths, perks, ownership
│   │   ├── LightingPresets                ModuleScript     per-zone moods
│   │   ├── Signal                         ModuleScript
│   │   ├── Types                          ModuleScript     PlayerData + Perks types
│   │   └── ZoneUtil                       ModuleScript     tags (CrystalNode, ZoneGate, Portal) + zone lookup
│   ├── Remotes                            Folder           (see table below)
│   └── Assets                             Folder
│       └── Items                          Folder           optional artist Tools named by item Id, e.g. "IronPick"
│
├── ServerScriptService
│   ├── Main                               Script           entry point
│   ├── Services                           Folder
│   │   ├── DataService                    ModuleScript
│   │   ├── EquipService                   ModuleScript
│   │   ├── MiningService                  ModuleScript
│   │   ├── MonetizationService            ModuleScript     passes + ProcessReceipt
│   │   ├── PickaxeBuilder                 ModuleScript     12 procedural pickaxe styles
│   │   ├── PortalService                  ModuleScript
│   │   ├── ProgressionService             ModuleScript
│   │   ├── RateLimiter                    ModuleScript
│   │   ├── TutorialService                ModuleScript
│   │   └── ZoneService                    ModuleScript
│   └── World                              Folder
│       ├── WorldBuilder                   ModuleScript     entry: BuildIfEmpty()
│       ├── Kit / Land / Placer / Props / Types / ZoneIsland / Lobby   ModuleScripts
│       └── Themes                         Folder           SunlitQuarry, GlowshroomGrotto, FrostfireRift, MagmaForge, CelestialVault
│
├── ServerStorage
│   └── BrokenNodes                        Folder           created at runtime (nodes waiting to respawn)
│
├── StarterGui                             (intentionally empty, see below)
│
└── StarterPlayer
    └── StarterPlayerScripts
        ├── Main                           LocalScript      entry point
        ├── Controllers                    Folder
        │   ├── AmbientController          ModuleScript     spinning/bobbing decor (client-only)
        │   ├── DataController             ModuleScript
        │   ├── HudController              ModuleScript
        │   ├── MiningController           ModuleScript
        │   ├── ShopController             ModuleScript
        │   ├── StoreController            ModuleScript     Robux Store + [VIP] chat tag
        │   ├── TutorialController         ModuleScript
        │   └── ZoneController             ModuleScript
        └── UI                             Folder
            ├── UIKit                      ModuleScript     shared UI styling helpers
            └── UIRegistry                 ModuleScript     named targets for the tutorial
```

Created at runtime per player: `Players/<name>/leaderstats` (Gems, Rebirths, Rank), `Pass_<Key>` attributes for owned game passes, and four ScreenGuis in `PlayerGui`: **HUD** (DisplayOrder 5), **Shop** (10), **Store** (11) and **Tutorial** (20).

## Remotes reference

| Remote | Type | Direction | Payload | Server validation |
| --- | --- | --- | --- | --- |
| GetData | RemoteFunction | C → S | — | Returns only the caller's own data |
| DataSync | RemoteEvent | S → C | full `PlayerData` | — |
| Notify | RemoteEvent | S → C | `kind, payload` (LevelUp, AutoUpgrade, AutoRebirth, RankUp, Unlock, Purchase, TutorialComplete, Toast) | — |
| MineHit | RemoteEvent | C → S | `node: Instance` | rate limit, tag, in Workspace, zone owned, reach, held tool, cooldown |
| MineFeedback | UnreliableRemoteEvent | S → C | `"Hit", node, gems, crit` / `"Break", position, zoneId` | cosmetic only |
| Purchase | RemoteFunction | C → S | `kind ("Upgrade"/"Item"/"Zone"/"Rebirth"), id?` → `(ok, message)` | rate limit, types, config lookup, server-side price |
| Equip | RemoteEvent | C → S | `kind ("Item"/"Aura"), id` | rate limit, ownership (bought / rebirths / pass) |
| TutorialAction | RemoteEvent | C → S | `"Skip"` / `"OpenedShop"` | rate limit, current step |
| SetSetting | RemoteEvent | C → S | `"AutoUpgrade" / "AutoRebirth" / "AutoMine", boolean` | rate limit, whitelisted key + type, Auto-Rebirth unlock |

Robux purchases don't use custom remotes. The client calls `MarketplaceService:PromptGamePassPurchase` / `PromptProductPurchase`, and the server grants them through `PromptGamePassPurchaseFinished` and `ProcessReceipt`.

## Why StarterGui is empty

All UI is built in code by the controllers (through `UIKit`), so it's version-controlled, consistently styled, and scales across phone/PC/console. Want a designer-made UI instead? Build it in StarterGui, give the buttons the same roles, and call `UIRegistry.Register("ShopButton", yourButton)` so the tutorial can still point at them.

## One-time Studio settings

1. **File → Publish to Roblox** (DataStores and Robux products need a published place).
2. **Game Settings → Security → Enable Studio Access to API Services** (to test saving in Studio).
3. **Game Settings → Avatar → R15** (pickaxe grips and the slash animation assume R15).
4. **Workspace → StreamingEnabled = true** (default for new places; the code handles streamed-in nodes, gates and portals).
5. If you aren't using Rojo, set the Lighting values from Phase 2 by hand. `LightingStyle` and `PrioritizeLightingQuality` can't be changed by scripts.
6. Paste your game pass and Developer Product IDs into `Config/Monetization.luau` (see Phase 3, section 5).
7. To replace the generated world with your own map, build it in `Workspace` and keep the contract: zone folder names, a `Bounds` part per zone, `CrystalNode`-tagged nodes, `ZoneGate`-tagged gates, `ArrivalPoint` parts, `Portal`-tagged portals and a `SpawnLocation`. `WorldBuilder` stops building once `Workspace.Zones` has children.
