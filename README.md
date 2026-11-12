# Crystal Rush

A mining simulator with an RNG luck layer for Roblox: smash glowing crystals, upgrade your pickaxe, and climb through five floating islands, each with its own cinematic lighting mood.

This repository is the full blueprint: design docs for every phase plus a working, strict-typed Luau codebase that syncs into Studio with [Rojo](https://rojo.space/).

**What's in the game**
- A large procedurally built world: a lobby hub plus five themed floating islands with terraced terrain cliffs, a glowing crystal cave, bridges, waterfalls, giant crystal formations, ruins, foliage, a portal hub and lit landmarks. It uses Roblox's built-in PBR materials and terrain, with no plastic.
- 12 pickaxes, each with its own detailed procedural model: 7 shop tiers, 4 rebirth-exclusive picks and a VIP pick. Plus 8 cosmetic auras.
- A fast early game, infinite rebirths with 28 ranks, rebirth-exclusive rewards, and Auto-Upgrade / Auto-Rebirth / Auto-Mine.
- A Robux Store with 4 game passes and 5 Developer Products. Paste your IDs into `src/ReplicatedStorage/Shared/Config/Monetization.luau` (see [docs/03-systems.md](docs/03-systems.md#5-robux-store-game-passes--developer-products)).

| Phase | Document |
| --- | --- |
| 1. Niche analysis & game concept | [docs/01-game-concept.md](docs/01-game-concept.md) |
| 2. Lighting, materials & PBR texturing | [docs/02-visual-style.md](docs/02-visual-style.md) |
| 3. Core systems (tutorial, progression/saving, equipping) | [docs/03-systems.md](docs/03-systems.md) + `src/` |
| 4. Explorer hierarchy & Studio setup | [docs/04-studio-hierarchy.md](docs/04-studio-hierarchy.md) |

## Play it now (no Rojo needed)

1. Download [`CrystalRush.rbxl`](https://github.com/dermoiq/brus/raw/hoplite/thasos-8fa5b364/CrystalRush.rbxl) and double-click it to open in Roblox Studio.
2. Press **Play** (F5). The server builds the world (lobby and five islands) when it starts, so the Workspace is empty in edit mode.
3. Progress doesn't save until you publish the place and enable **Game Settings → Security → Studio Access to API Services**. Until then the game warns in Output and uses temporary data.

`CrystalRush.rbxl` is built from `src/`. After changing code, rebuild it with `rojo build -o CrystalRush.rbxl`.

## Quick start (developers)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs the pinned Rojo, luau-lsp, Selene and StyLua).
2. Either:
   - **Live sync:** run `rojo serve`, open a place in Studio, and connect with the Rojo plugin, or
   - **Build a place file:** run `rojo build -o CrystalRush.rbxl` and open it in Studio.
3. Publish the place, enable **Game Settings → Security → Studio Access to API Services**, and press **Play**.

On first run the server builds the full world (lobby hub and five themed islands with crystals, gates, bridges and portals), so everything is playable before any custom art exists. Replace it with your own map by following the contract in Phase 4.

Not using Rojo? Recreate the tree in [Phase 4](docs/04-studio-hierarchy.md): `*.server.luau` → Script, `*.client.luau` → LocalScript, `*.luau` → ModuleScript.

## Code checks

```sh
rojo sourcemap default.project.json -o sourcemap.json
# globalTypes.d.luau: https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau
luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --platform=roblox src
selene src
stylua --check src
```

## Adding content

Everything is data-driven from `src/ReplicatedStorage/Shared/Config`:

- **New pickaxe:** add an entry to `Items.luau` (optionally add a Tool named after its Id to `ReplicatedStorage/Assets/Items`).
- **New upgrade:** add an entry to `Upgrades.luau` and apply its effect in `Formulas.luau`.
- **New zone:** add an entry to `Zones.luau` and a preset to `LightingPresets.luau`, then build `Workspace/Zones/<Id>` with `Bounds`, a `ZoneGate`-tagged gate and `CrystalNode`-tagged nodes.

The shop, gates, tutorial targeting and saving pick up new entries automatically.
