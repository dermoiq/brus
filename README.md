# Crystal Rush

A mining simulator with an RNG luck layer for Roblox: smash glowing crystals, upgrade your pickaxe, and climb through five floating islands, each with its own cinematic lighting mood.

This repository is the full blueprint: design docs for every phase plus a working, strict-typed Luau codebase that syncs into Studio with [Rojo](https://rojo.space/).

| Phase | Document |
| --- | --- |
| 1. Niche analysis & game concept | [docs/01-game-concept.md](docs/01-game-concept.md) |
| 2. Lighting, materials & PBR texturing | [docs/02-visual-style.md](docs/02-visual-style.md) |
| 3. Core systems (tutorial, progression/saving, equipping) | [docs/03-systems.md](docs/03-systems.md) + `src/` |
| 4. Explorer hierarchy & Studio setup | [docs/04-studio-hierarchy.md](docs/04-studio-hierarchy.md) |

## Quick start

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder (installs the pinned Rojo, luau-lsp, Selene and StyLua).
2. Either:
   - **Live sync:** run `rojo serve`, open a place in Studio, and connect with the Rojo plugin, or
   - **Build a place file:** run `rojo build -o CrystalRush.rbxl` and open it in Studio.
3. Publish the place, enable **Game Settings → Security → Studio Access to API Services**, and press **Play**.

On first run the server builds a greybox world (lobby, upgrade station and five zones with crystals and gates) so everything is playable before any art exists. Replace it with your real map by following the contract in Phase 4.

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
