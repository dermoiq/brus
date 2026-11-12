# Phase 2 — Visual Style, Lighting & Texturing

**Art direction:** stylized-realistic. Chunky readable shapes with physically based (PBR) materials. Crystals are the hero: saturated, emissive, bloomed. Everything else is muted and textured so the crystals pop. **No flat plastic anywhere.**

> **Important (2025+ engine change):** `Lighting.Technology` (Future/ShadowMap/Voxel) is **deprecated** and was replaced by **Unified Lighting**:
> `LightingStyle` + `PrioritizeLightingQuality`. The old **Future** maps to `LightingStyle = Realistic` and `PrioritizeLightingQuality = true`.
> Neither can be set from scripts, so set them in Studio (this repo's `default.project.json` already bakes them into the place).

## 1. Lighting settings (exact values)

Studio shows colors as 0–255 RGB. These same values are in `default.project.json` and in the `Quarry` preset in `src/ReplicatedStorage/Shared/LightingPresets.luau`.

### `Lighting`

| Property | Value | Why |
| --- | --- | --- |
| LightingStyle | **Realistic** | Full shadows/specular, the modern "Future" |
| PrioritizeLightingQuality | **true** | Keeps lighting quality and drops draw distance first on weak devices |
| Brightness | **3** | Strong, punchy sun for crisp shadows |
| Ambient | **62, 58, 82** | Dim cool-violet fill in occluded areas, so caves stay moody and not black |
| OutdoorAmbient | **134, 122, 158** | Soft lavender sky fill, gives the dreamy look |
| ColorShift_Top | **255, 222, 184** | Warm sunlit highlights (golden hour) |
| ColorShift_Bottom | **58, 44, 92** | Cool violet bounce light, adds complementary contrast |
| EnvironmentDiffuseScale | **1** | Lets the skybox light surfaces (needed for PBR to look right) |
| EnvironmentSpecularScale | **1** | Sky reflections on metal/glass. **Without this, PBR metal looks dead** |
| ExposureCompensation | **0.1** | Slight lift for mobile screens |
| GlobalShadows | **true** | |
| ShadowSoftness | **0.2** | Mostly crisp with a little softness |
| ClockTime | **16.4** | Golden hour: long shadows, warm rim light |
| GeographicLatitude | **35** | Sun angle that gives readable shadows at 16.4 |

### Post-processing (children of `Lighting`)

| Object | Property values |
| --- | --- |
| **Atmosphere** | Density **0.3**, Offset **0.2**, Color **198, 178, 255**, Decay **104, 84, 150**, Glare **0.4**, Haze **1.5** |
| **BloomEffect** ("Bloom") | Intensity **0.8**, Size **30**, Threshold **1.3**. The threshold above 1 means only Neon/emissive surfaces and sun glints bloom, not white UI-like plastic |
| **SunRaysEffect** ("SunRays") | Intensity **0.06**, Spread **0.7**. Subtle god rays; higher values wash out the screen |
| **ColorCorrectionEffect** ("ColorCorrection") | Brightness **0.02**, Contrast **0.12**, Saturation **0.2**, TintColor **255, 246, 236** |
| **DepthOfFieldEffect** (optional) | FarIntensity **0.12**, FocusDistance **45**, InFocusRadius **70**, NearIntensity **0**. Softens distant islands only |
| **Sky** (add one) | A stylized gradient/cloud skybox from the Creator Store. `CelestialBodiesShown` true, `SunAngularSize` 11, `StarCount` 3000 (stars show in the Celestial zone) |
| **Clouds** (`Workspace.Terrain` → Insert → Clouds) | Cover **0.55**, Density **0.7**, Color **255, 240, 250** |

`FogStart`/`FogEnd`/`FogColor` are ignored while an `Atmosphere` exists, so don't tune them.

### Per-zone moods (tweened automatically)

The client's `ZoneController` tweens Lighting, Atmosphere, ColorCorrection and Bloom over 1.5 s when you enter a zone. Tune the values in `LightingPresets.luau`:

| Preset | ClockTime | Feel | Key values |
| --- | --- | --- | --- |
| Quarry | 16.4 | Golden hour | the table above |
| Grotto | 20.5 | Teal dusk, glowing fungi | Ambient 40,74,82 · Atmosphere 90,200,190 density 0.42 · Bloom 1.1 / threshold 1.1 |
| Frost | 10.5 | Crisp bright cold | Ambient 90,110,140 · Glare 0.6 · Saturation 0.05 · Tint 232,244,255 |
| Magma | 18.2 | Smoky ember glow | Ambient 90,40,30 · Atmosphere 255,140,90 density 0.48 · Bloom 1.2 / size 40 |
| Celestial | 0.2 | Starry purple night | Ambient 70,55,120 · Atmosphere 160,120,255 · Saturation 0.35 · Bloom 1.3 |

## 2. Materials & textures: making every surface high-end

Use one rule to decide which tool to use:

| Asset type | Use | Why |
| --- | --- | --- |
| Floors, cliffs, walls, terrain, any Part-built geometry | **MaterialVariant** (tiling PBR material) | One texture set covers unlimited surface. Works on Parts *and* Terrain |
| Tools, weapons, pickaxes, crystals, props, anything unique | **MeshPart + SurfaceAppearance** (UV-mapped PBR) | Hand-painted detail, baked wear, emissive veins |

### 2a. MaterialVariant workflow (environment)

1. **View → Material Manager** (this edits `MaterialService`).
2. Pick a base material (e.g. *Rock*) → **Create Material Variant**. Name it with a zone prefix (`Grotto_MossRock`).
3. Assign maps: **ColorMap** (albedo, sRGB), **NormalMap** (OpenGL / +Y green), **RoughnessMap**, **MetalnessMap**. Use the 1024×1024 maximum for hero surfaces.
4. **StudsPerTile:** 8–12 for rock/ground, 4–6 for bricks/planks, 16+ for big cliffs.
5. **MaterialPattern = Organic** for natural surfaces (breaks visible tiling). Use **Regular** for bricks/tiles/planks.
6. Apply it:
   - **Per part:** set `Part.Material` to the base material and `Part.MaterialVariant` to the variant name.
   - **Whole game:** in Material Manager choose **Set as Override**, or call `MaterialService:SetBaseMaterialOverride(Enum.Material.Rock, "Grotto_MossRock")`. Every Rock part *and* Rock terrain then uses it.
7. Newer engines also expose **EmissiveMaskContent / EmissiveStrength / EmissiveTint** on variants and SurfaceAppearance. Use them for glowing magma cracks and crystal veins (Bloom picks them up).

Suggested variant set:

| Zone | Variants (base material) |
| --- | --- |
| Lobby | `Lobby_Cobble` (Cobblestone), `Lobby_WoodPlanks` (WoodPlanks), `Lobby_Brass` (Metal) |
| Sunlit Quarry | `Quarry_Sandstone` (Sandstone), `Quarry_Gravel` (Pebble) |
| Glowshroom Grotto | `Grotto_MossRock` (Rock), `Grotto_WetSlate` (Slate) |
| Frostfire Rift | `Frost_Glacier` (Glacier), `Frost_PackedSnow` (Snow) |
| Magma Forge | `Magma_Basalt` (Basalt, emissive cracks), `Magma_Obsidian` (Slate) |
| Celestial Vault | `Vault_Marble` (Marble), `Vault_GoldTrim` (Foil) |

### 2b. SurfaceAppearance workflow (items, tools, weapons, props)

1. **Model** in Blender. Keep a clean low-poly mesh (pickaxe ~1.5–4K tris, crystal cluster ~1–2K) and UV-unwrap it with texel density matching the other assets.
2. **Bake** high-poly detail (chips, engravings) to the normal map.
3. **Texture** in Substance Painter or Blender. Export: BaseColor (sRGB), Normal (**OpenGL**), Roughness, Metallic. Use 1024² for hero tools and 512² for small props.
4. **Import** with the 3D Importer (FBX/glTF) as MeshParts. Add a **SurfaceAppearance** child to each MeshPart and assign ColorMap / NormalMap / RoughnessMap / MetalnessMap.
5. **AlphaMode:**
   - `Overlay`: ColorMap alpha reveals `MeshPart.Color` underneath (cheap recolors).
   - `Transparency`: cut-outs (chains, leaves, glass panes).
   - `TintMask`: ColorMap alpha masks where `SurfaceAppearance.Color` tints. That's one textured pickaxe recolored per tier.
6. **Script limits.** The texture maps are plugin-only: game scripts **cannot** swap them at runtime. Build one prefab per variant and **clone** it (this is exactly what `EquipService` does). Scripts *can* change `SurfaceAppearance.Color`, `EmissiveStrength` and `EmissiveTint`, which is good for pulsing a pickaxe on crits.

### 2c. Dropping your art into the code (no code changes needed)

- **Pickaxes:** create a `Tool` named after the item Id (e.g. `IronPick`) under `ReplicatedStorage/Assets/Items`. Put a MeshPart `Handle` inside it plus any extra MeshParts welded to it with WeldConstraints, and set the Tool's `Grip`. `EquipService` clones it automatically instead of the procedural `PickaxeBuilder` model.
- **Crystal nodes:** a Model (set `PrimaryPart`) of MeshParts with SurfaceAppearance and emissive veins, placed in `Workspace/Zones/<ZoneId>/Nodes`, **tagged `CrystalNode`**. Add a PointLight in the crystal's color.
- **Gates:** any Part/Model tagged `ZoneGate` with a `Zone` attribute.

### 2d. Performance budget (60 FPS on mid-range phones)

| Item | Budget |
| --- | --- |
| Texture size | 1024² for hero tools/terrain variants, 512² props, 256² for small/distant |
| Reuse | Same asset IDs load once, so share trim sheets across props |
| Triangles | Hero tool ≤ 5K, props ≤ 2K, keep the visible scene ≲ 500K |
| Shadows | `CastShadow = false` on small props, crystals and VFX parts |
| Collision | `CollisionFidelity = Box/Hull` for decor. `CanQuery/CanTouch = false` on pure decoration |
| Streaming | Keep `StreamingEnabled` on. Use `ModelStreamingMode = Atomic` for multi-part nodes |
| Lights | ≤ ~8 overlapping PointLights per view. Use emissive + bloom instead of more lights |

### 2e. "No basic plastic" checklist

- [ ] Zero `Plastic`/`SmoothPlastic` in the environment. Every Part uses a MaterialVariant or a textured base material.
- [ ] Neon only for emissive accents (< 5% of screen).
- [ ] Vary color ±5–10% between neighboring rocks/planks to break repetition.
- [ ] Every tool/weapon/prop is a MeshPart with SurfaceAppearance (all 4 maps).
- [ ] Crystals have emissive veins + a PointLight + bloom-friendly colors.
- [ ] Check the scene at Graphics Quality 1 and 10, on phone emulation, and in each zone's lighting preset.

Texture sources: the Creator Store (check licenses), [Poly Haven](https://polyhaven.com/textures) and [ambientCG](https://ambientcg.com/) (CC0 PBR sets), or your own Substance materials.
