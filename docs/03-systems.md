# Phase 3 — Core Systems & Luau Code

All code lives in `src/` and is strict-mode typed (`--!strict`). The server is the only source of truth: clients send *intentions* ("I swung at this node", "buy upgrade X") and never amounts, prices or results.

## Architecture

```
ReplicatedStorage/Shared   config + pure math, used by both sides (server decides, client only displays)
ServerScriptService        Main (Script) starts the Services (ModuleScripts) in dependency order
StarterPlayerScripts       Main (LocalScript) starts the Controllers (ModuleScripts) in dependency order
```

| Server service | Responsibility |
| --- | --- |
| `DataService` | DataStore load/save with session locking, retries, 60 s autosave, `BindToClose`, template reconcile + migrations. The only writer of player data (`DataService.Update`). |
| `ProgressionService` | Gems/XP/levels, every purchase (upgrade, pickaxe, zone, rebirth), Auto-Upgrade, leaderstats |
| `MiningService` | Validates swings and awards gems (crits use the server RNG). Breaks and respawns nodes |
| `EquipService` | Gives the equipped pickaxe Tool, applies the tier aura + walk speed, re-applies on respawn |
| `TutorialService` | Server-side tutorial state and rewards. Handles skip |
| `ZoneService` | Sets the player `Zone` attribute (drives lighting). Returns anyone inside a locked zone to spawn |
| `World/PrototypeMap` | Builds a greybox world if `Workspace.Zones` is empty |

| Client controller | Responsibility |
| --- | --- |
| `DataController` | Read-only mirror of saved data (`Observe`, `Get`) |
| `HudController` | Gems (count-up), multiplier, level bar, rebirths, Shop/Rebirth buttons, toasts, zone banner, floating popups |
| `ShopController` | Data-driven shop (Upgrades / Pickaxes / Zones / Rebirth tabs) + Auto-Upgrade toggle |
| `MiningController` | Click/tap/hold to swing, aim assist, hit flash, particles, crit camera shake |
| `ZoneController` | Local gate opening + "Unlock" prompts, per-zone lighting tweens |
| `TutorialController` | Step card, Skip button, UI highlight + arrow, world beam + "MINE ME!" marker |

## 1. Skippable interactive tutorial

- Steps are data in `Config/Tutorial.luau`: **Mine → Collect 40 Gems → Open Shop → Buy Gem Multiplier** (+100 Gems on completion).
- **"Skip Tutorial ✕"** sits on the tutorial card for the whole tutorial. It hides immediately on the client, and the server marks `TutorialDone` (no reward).
- Guidance is non-blocking. A small card sits at the top of the screen. UI targets get a pulsing gold ring plus a bobbing arrow, and the ring has `Active = false` so clicks pass through to the real button. World targets get a glowing Beam from the player to the nearest unlocked crystal plus a bouncing "MINE ME!" marker.
- If the target is inside the closed shop (`Upgrade:GemMultiplier`), the highlight points at the Shop button first.
- Progress is saved (`TutorialStep`, `TutorialProgress`), so a player who leaves mid-tutorial resumes at the same step.
- **Exploit-safe:** only server events advance mining/collect/purchase steps. The client can only report "opened shop", which grants nothing. Buying any upgrade completes the tutorial, so players who race ahead aren't stuck.

To add a step: append it to `Steps`, give its target a key with `UIRegistry.Register("MyKey", button)`, and advance it in `TutorialService` from the server event that proves it happened.

## 2. Progression, upgrades & saving

Saved data (`Types.PlayerData`): `Gems`, `TotalGems`, `Level`, `XP`, `Rebirths`, `Upgrades{id → level}`, `OwnedItems{id → true}`, `EquippedItem`, `UnlockedZones{id → true}`, tutorial state, `Settings.AutoUpgrade`.

**Multiplier is derived, not stored:** `Formulas.Multiplier = (1 + 0.25·GemMultiplierLv) × (1 + 0.5·Rebirths) × (1 + 0.02·(Level−1))`. Storing a derived value invites desyncs and duplication bugs.

The shop is automated in two ways:
1. **Data-driven.** Every entry in `Config/Upgrades`, `Config/Items` and `Config/Zones` gets a shop row automatically. Adding content means adding a table entry.
2. **Auto-Upgrade.** When toggled on, the server buys the cheapest affordable stat upgrade every 1.5 s. It's a natural game-pass candidate.

DataStore safety:
- Load uses `UpdateAsync` to take a **session lock** (`JobId` + timestamp). If another server holds a fresh lock, it waits and retries, then takes over after about 20 s (crashed-server case).
- Saves refresh the lock. If the lock was taken by another server, this server stops saving and kicks the player, which prevents rollback and duplication.
- A failed load in a live game **kicks** rather than playing on default data (that would overwrite real progress on save). In Studio without API access it falls back to temporary data with a warning.
- `reconcile` adds new template fields to old saves. Bump `Template.Version` and write a migration in `migrate` for breaking changes.
- For a large live launch, [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) is a hardened drop-in replacement for `DataService`, with the same `Get`/`Update` usage pattern.

## 3. Item equipping & visuals

`EquipService.Equip(player, itemId)` checks ownership, saves `EquippedItem`, then:
1. Removes old pickaxe tools from Backpack + character.
2. Clones `ReplicatedStorage/Assets/Items/<ItemId>` (your SurfaceAppearance art). **If it's missing, it builds a greybox pickaxe** from the item's color/material, with a Neon trim and PointLight for tier 3+.
3. Equips it, sets `WalkSpeed = 16 + WalkSpeedBonus`, and adds a **tier aura** (sparkles/frost/embers/stars particles + light) to the HumanoidRootPart.
4. Runs again on every respawn.

Power (gems per hit) comes from `Items[EquippedItem].Power`. The server reads it from saved data, never from the tool.

## Security model

| Threat | Mitigation |
| --- | --- |
| Remote spam / auto-clickers | Per-player token-bucket `RateLimiter` on every remote, plus a server-side swing cooldown (with 20% jitter tolerance) |
| Fake amounts or prices | Clients never send numbers. Rewards and costs are computed on the server from shared config |
| Mining from across the map | Server distance check: reach + node size + 4 studs tolerance |
| Mining in locked zones / noclip past gates | Zone ownership checked per hit. `ZoneService` returns intruders to spawn |
| Mining without the right tool | The held Tool's `ItemId` must equal the saved `EquippedItem` |
| Equipping unowned items | Ownership check in `EquipService.Equip` |
| Bad argument types | `typeof` checks on every remote argument. Unknown ids fail lookup |
| Race-condition double spends | "Check, then deduct" happens in one non-yielding call |
| Data duplication by server hopping | DataStore session locking |
| Tutorial reward farming | Completed once, server-validated, and skip gives no reward |

## Testing checklist (Studio)

1. **Game Settings → Security → Enable Studio Access to API Services** (to test saving), then press Play.
2. Greybox world appears → tutorial card + beam → mine 40 gems → Shop highlight → buy Gem Multiplier → reward toast.
3. Rejoin: gems/upgrades persist and the tutorial doesn't reappear. Repeat on a fresh account and press **Skip Tutorial**.
4. Buy the Iron Pick: the tool looks different and walk speed rises. Reset the character: the pick and aura come back.
5. Unlock the Grotto at its gate: the gate fades locally, and walking in tweens the lighting to teal dusk with a zone banner.
6. **Test → Clients and Servers** with 2 players: gates open only for the buyer, and the other player is pushed back if they try to clip through.
