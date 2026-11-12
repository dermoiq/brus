# Phase 4 — Studio Hierarchy & Setup

With Rojo, `default.project.json` creates everything under ReplicatedStorage, ServerScriptService, StarterPlayerScripts and Lighting. Building by hand? Mirror this tree exactly. File suffixes map to Studio classes like this:
`*.server.luau` → **Script**, `*.client.luau` → **LocalScript**, `*.luau` → **ModuleScript** (name = file name without the suffix).

```
game
├── Workspace
│   ├── Lobby                              Model            (built by PrototypeMap if missing)
│   │   ├── Floor                          Part
│   │   ├── Spawn                          SpawnLocation    faces +Z toward the zones
│   │   └── UpgradeStation                 Model            PrimaryPart = Base
│   │       ├── Base                       Part
│   │       │   └── ProximityPrompt        attribute OpensShop = true  ← opens the shop
│   │       ├── Pillar                     Part
│   │       └── Orb                        Part (Neon) + PointLight + BillboardGui "UPGRADES"
│   └── Zones                              Folder           ← REQUIRED contract for your real map
│       ├── SunlitQuarry                   Folder           name = Id in Config/Zones.luau
│       │   ├── Bounds                     Part             invisible box covering the zone; CanCollide/CanQuery/CanTouch = false
│       │   ├── Floor (+ your art)         Parts / MeshParts / Terrain
│       │   └── Nodes                      Folder
│       │       ├── Node_1                 Model  tag: CrystalNode, attribute Zone = "SunlitQuarry", PrimaryPart set
│       │       └── …
│       ├── GlowshroomGrotto
│       │   ├── Gate                       Part or Model    tag: ZoneGate, attribute Zone = "GlowshroomGrotto"
│       │   ├── Bounds
│       │   └── Nodes …
│       ├── FrostfireRift                  (same as Grotto)
│       ├── MagmaForge                     (same as Grotto)
│       └── CelestialVault                 (same as Grotto)
│
├── Lighting                               LightingStyle = Realistic, PrioritizeLightingQuality = true (+ values in Phase 2)
│   ├── Atmosphere                         Atmosphere
│   ├── Bloom                              BloomEffect
│   ├── SunRays                            SunRaysEffect
│   ├── ColorCorrection                    ColorCorrectionEffect
│   ├── DepthOfField                       DepthOfFieldEffect
│   └── Sky                                Sky              (add your skybox)
│
├── MaterialService                        your MaterialVariants (Phase 2)
│
├── ReplicatedStorage
│   ├── Shared                             Folder
│   │   ├── Config                         Folder
│   │   │   ├── Items                      ModuleScript     pickaxe tiers
│   │   │   ├── Progression                ModuleScript     balance knobs + save template
│   │   │   ├── Tutorial                   ModuleScript     tutorial steps
│   │   │   ├── Upgrades                   ModuleScript     stat upgrades
│   │   │   └── Zones                      ModuleScript     zones in unlock order
│   │   ├── Format                         ModuleScript     1.2K / 3.4M formatting
│   │   ├── Formulas                       ModuleScript     multiplier, costs, cooldown, XP, rebirth
│   │   ├── LightingPresets                ModuleScript     per-zone moods
│   │   ├── Signal                         ModuleScript
│   │   ├── Types                          ModuleScript     PlayerData type
│   │   └── ZoneUtil                       ModuleScript     tags + zone lookup
│   ├── Remotes                            Folder
│   │   ├── GetData                        RemoteFunction
│   │   ├── DataSync                       RemoteEvent
│   │   ├── Notify                         RemoteEvent
│   │   ├── MineHit                        RemoteEvent
│   │   ├── MineFeedback                   UnreliableRemoteEvent
│   │   ├── Purchase                       RemoteFunction
│   │   ├── Equip                          RemoteEvent
│   │   ├── TutorialAction                 RemoteEvent
│   │   └── SetSetting                     RemoteEvent
│   └── Assets                             Folder
│       └── Items                          Folder           Tools named by item Id, e.g. "IronPick" (optional art)
│
├── ServerScriptService
│   ├── Main                               Script           entry point
│   ├── Services                           Folder
│   │   ├── DataService                    ModuleScript
│   │   ├── EquipService                   ModuleScript
│   │   ├── MiningService                  ModuleScript
│   │   ├── ProgressionService             ModuleScript
│   │   ├── RateLimiter                    ModuleScript
│   │   ├── TutorialService                ModuleScript
│   │   └── ZoneService                    ModuleScript
│   └── World                              Folder
│       └── PrototypeMap                   ModuleScript
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
        │   ├── DataController             ModuleScript
        │   ├── HudController              ModuleScript
        │   ├── MiningController           ModuleScript
        │   ├── ShopController             ModuleScript
        │   ├── TutorialController         ModuleScript
        │   └── ZoneController             ModuleScript
        └── UI                             Folder
            ├── UIKit                      ModuleScript     shared UI styling helpers
            └── UIRegistry                 ModuleScript     named targets for the tutorial
```

Created at runtime per player: `Players/<name>/leaderstats` (Gems, Rebirths) and three ScreenGuis in `PlayerGui`: **HUD** (DisplayOrder 5), **Shop** (10) and **Tutorial** (20).

## Remotes reference

| Remote | Type | Direction | Payload | Server validation |
| --- | --- | --- | --- | --- |
| GetData | RemoteFunction | C → S | — | Returns only the caller's own data |
| DataSync | RemoteEvent | S → C | full `PlayerData` | — |
| Notify | RemoteEvent | S → C | `kind, payload` (LevelUp, AutoUpgrade, TutorialComplete, Toast) | — |
| MineHit | RemoteEvent | C → S | `node: Instance` | rate limit, tag, in Workspace, zone owned, reach, held tool, cooldown |
| MineFeedback | UnreliableRemoteEvent | S → C | `"Hit", node, gems, crit` / `"Break", position, zoneId` | cosmetic only |
| Purchase | RemoteFunction | C → S | `kind ("Upgrade"/"Item"/"Zone"/"Rebirth"), id?` → `(ok, message)` | rate limit, types, config lookup, server-side price |
| Equip | RemoteEvent | C → S | `itemId` | rate limit, ownership |
| TutorialAction | RemoteEvent | C → S | `"Skip"` / `"OpenedShop"` | rate limit, current step |
| SetSetting | RemoteEvent | C → S | `"AutoUpgrade", boolean` | rate limit, whitelisted key + type |

## Why StarterGui is empty

All UI is built in code by the controllers (through `UIKit`), so it's version-controlled, consistently styled, and scales across phone/PC/console. Want a designer-made UI instead? Build it in StarterGui, give the buttons the same roles, and call `UIRegistry.Register("ShopButton", yourButton)` so the tutorial can still point at them.

## One-time Studio settings

1. **File → Publish to Roblox** (DataStores need a published place).
2. **Game Settings → Security → Enable Studio Access to API Services** (to test saving in Studio).
3. **Game Settings → Avatar → R15** (the greybox pickaxe grip and slash animation assume R15).
4. **Workspace → StreamingEnabled = true** (default for new places; the code handles streamed-in nodes and gates).
5. If you aren't using Rojo, set the Lighting values from Phase 2 by hand. `LightingStyle` and `PrioritizeLightingQuality` can't be changed by scripts.
6. When your real map is ready, replace the greybox inside `Workspace/Zones` but keep the contract: zone folder names, a `Bounds` part, `CrystalNode`-tagged nodes and `ZoneGate`-tagged gates. `PrototypeMap` stops building once `Zones` has children.
