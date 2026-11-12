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
| `DataService` | DataStore load/save with session locking, retries, 60 s autosave, `BindToClose`, template reconcile + migrations, `SaveNow` for purchases. The only writer of player data (`DataService.Update`). |
| `ProgressionService` | Gems/XP/levels, every Gem purchase (upgrade, pickaxe, zone), infinite rebirths, Auto-Upgrade, Auto-Rebirth, leaderstats (Gems, Rebirths, Rank) |
| `MonetizationService` | Game pass ownership (mirrored into `Pass_<Key>` player attributes), `ProcessReceipt` for Developer Products |
| `MiningService` | Validates swings and awards gems (crits use the server RNG, perks applied). Auto-Mine. Breaks and respawns nodes |
| `EquipService` + `PickaxeBuilder` | Gives the equipped pickaxe Tool (artist template or detailed procedural model), tier aura, cosmetic aura, walk speed. Re-applies on respawn and when passes change |
| `TutorialService` | Server-side tutorial state and rewards. Handles skip |
| `ZoneService` | Sets the player `Zone` attribute (drives lighting). Returns anyone inside a locked zone to spawn |
| `PortalService` | Lobby portal hub + island return portals (server-validated teleports) |
| `World/WorldBuilder` | Builds the full five-island world if `Workspace.Zones` is empty |

| Client controller | Responsibility |
| --- | --- |
| `DataController` | Read-only mirror of saved data (`Observe`, `Get`) |
| `HudController` | Gems (count-up), multiplier + boost timer, level bar, rebirth rank, Shop/Rebirth/Store buttons, toasts, banners, floating popups |
| `ShopController` | Data-driven shop (Upgrades / Pickaxes / Zones / Rebirth / Auras tabs), Auto-Upgrade, Auto-Mine and Auto-Rebirth toggles |
| `StoreController` | Robux Store (game passes + Developer Products with live prices) and the [VIP] chat tag |
| `MiningController` | Click/tap/hold to swing, aim assist, hit flash, particles, crit camera shake, Auto-Mine swing animation |
| `ZoneController` | Local gate opening + "Unlock" prompts, per-zone lighting tweens |
| `TutorialController` | Step card, Skip button, UI highlight + arrow, world beam + "MINE ME!" marker |
| `AmbientController` | Local spin/bob animation for decorations (no network cost) |

## 1. Skippable interactive tutorial

- Steps are data in `Config/Tutorial.luau`: **Mine → Collect 40 Gems → Open Shop → Buy Gem Multiplier** (+100 Gems on completion).
- **"Skip Tutorial ✕"** sits on the tutorial card for the whole tutorial. It hides immediately on the client, and the server marks `TutorialDone` (no reward).
- Guidance is non-blocking. A small card sits at the top of the screen. UI targets get a pulsing gold ring plus a bobbing arrow, and the ring has `Active = false` so clicks pass through to the real button. World targets get a glowing Beam from the player to the nearest unlocked crystal plus a bouncing "MINE ME!" marker.
- If the target is inside the closed shop (`Upgrade:GemMultiplier`), the highlight points at the Shop button first.
- Progress is saved (`TutorialStep`, `TutorialProgress`), so a player who leaves mid-tutorial resumes at the same step.
- **Exploit-safe:** only server events advance mining/collect/purchase steps. The client can only report "opened shop", which grants nothing. Buying any upgrade completes the tutorial, so players who race ahead aren't stuck.

To add a step: append it to `Steps`, give its target a key with `UIRegistry.Register("MyKey", button)`, and advance it in `TutorialService` from the server event that proves it happened.

## 2. Progression, upgrades & saving

Saved data (`Types.PlayerData`): `Gems`, `TotalGems`, `Level`, `XP`, `Rebirths`, `Upgrades{id → level}`, `OwnedItems{id → true}`, `EquippedItem`, `EquippedAura`, `UnlockedZones{id → true}`, tutorial state, `Boosts.GemsUntil`, `ProcessedReceipts` (last 100 purchase ids), `Settings` (AutoUpgrade / AutoRebirth / AutoMine).

**Multiplier is derived, not stored:** `Formulas.Multiplier = (1 + 0.25·GemMultiplierLv) × Rebirth(r) × (1 + 0.02·(Level−1)) × perks`, where `Rebirth(r) = (1 + 0.5·r) × 1.1^r` and perks are 2x Gems, VIP (+25%) and an active 2x boost. Storing a derived value invites desyncs and duplication bugs.

The shop is automated in two ways:
1. **Data-driven.** Every entry in `Config/Upgrades`, `Config/Items`, `Config/Zones` and `Config/Auras` gets a shop row automatically. Adding content means adding a table entry.
2. **Auto-Upgrade.** When toggled on, the server buys the cheapest useful purchase every second: the next stat upgrade level or the next stronger shop pickaxe.

DataStore safety:
- Load uses `UpdateAsync` to take a **session lock** (`JobId` + timestamp). If another server holds a fresh lock, it waits and retries, then takes over after about 15–20 s (crashed-server case). In Studio it falls back to temporary data immediately.
- Saves refresh the lock. If the lock was taken by another server, this server stops saving and kicks the player, which prevents rollback and duplication.
- A failed load in a live game **kicks** rather than playing on default data (that would overwrite real progress on save).
- `reconcile` adds new template fields to old saves (v1 saves pick up the v2 fields automatically). Bump `Template.Version` and write a migration in `migrate` for breaking changes.
- For a large live launch, [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) is a hardened drop-in replacement for `DataService`, with the same `Get`/`Update` usage pattern.

## 3. Item equipping & visuals

`EquipService.Equip(player, "Item" | "Aura", id)` checks ownership (bought, rebirth count, or game pass), saves the choice, then:
1. Removes old pickaxe tools from Backpack + character.
2. Clones `ReplicatedStorage/Assets/Items/<ItemId>` (your SurfaceAppearance art). **If it's missing, `PickaxeBuilder` builds a detailed procedural model** for that tier's style (12 styles with multi-part heads, wedge blades, grip wraps, gems, Neon veins, lights, particles and a swing trail on higher tiers).
3. Equips it, sets `WalkSpeed = 16 + WalkSpeedBonus`, and adds the pickaxe's **tier aura** plus the chosen **cosmetic aura** (flame, ring, sparkle, prism, void, stars, crown).
4. Runs again on every respawn and whenever pass ownership changes.

Power comes from the *effective* pickaxe (`Formulas.EquippedItem`): the saved choice while it's owned, otherwise the best owned one. The server reads it from saved data, never from the tool.

## 4. Deep rebirth system

- `ProgressionService.Rebirth(player, free)` checks the cost (skipped for the Instant Rebirth product), resets Gems, upgrades and shop pickaxes, keeps zones, level, exclusive pickaxes and auras, then re-equips the best owned pickaxe.
- Rebirths are infinite: `Cost(r) = 2.5M × 1.4^r × Rebirth(r)`. Because the cost scales with the player's own multiplier, each run asks for a similar, gently growing amount of mining.
- 28 ranks live in `Config/Rebirths.luau` (shown on the HUD, the Rebirth tab and the leaderboard). Rank-ups, new exclusive pickaxes and new auras are announced with a banner and toasts.
- Auto-Rebirth unlocks at 3 rebirths. The server rebirths automatically when affordable, and rejects the setting while it's still locked.

## 5. Robux Store (game passes & Developer Products)

Setup:
1. Create the passes and products in the Creator Dashboard (your experience → Monetization), then paste their IDs into `src/ReplicatedStorage/Shared/Config/Monetization.luau`. Each entry is marked `-- <- paste your ... ID`. Rebuild the place, or edit that ModuleScript directly in Studio.
2. An ID of `0` shows the item as "Coming soon" and the server ignores it. Prices are read live with `MarketplaceService:GetProductInfoAsync`.
3. To test perks before IDs exist, set `StudioOwnsAllPasses = true` (Studio only).

How it works:
- **Passes:** on join the server calls `UserOwnsGamePassAsync` for each configured pass and mirrors the result into `Pass_<Key>` player attributes. `PromptGamePassPurchaseFinished` grants new purchases instantly. Perks read those attributes on both sides, and clients can't change server-set attributes.
- **Products:** `MarketplaceService.ProcessReceipt` waits for the player's data and skips any `PurchaseId` already in `ProcessedReceipts`. It then grants the product (gem pack sized to current income, 2x boost, or instant rebirth) and records the receipt in the same frame. It **saves before returning `PurchaseGranted`**. If saving fails it returns `NotProcessedYet`, and the history check prevents a double grant when Roblox retries.
- **VIP:** Royal Pick and Royal Aura (owned while the pass is owned), +25% Gems, and a gold `[VIP]` chat prefix via `TextChatService.OnIncomingMessage`.
- **Auto-Mine:** the server mines the nearest reachable crystal at your swing speed, with the same validation as manual swings. It can be toggled off in the Upgrades tab.

## Security model

| Threat | Mitigation |
| --- | --- |
| Remote spam / auto-clickers | Per-player token-bucket `RateLimiter` on every remote, plus a server-side swing cooldown (with 20% jitter tolerance) |
| Fake amounts or prices | Clients never send numbers. Rewards and costs are computed on the server from shared config |
| Mining from across the map | Server distance check: reach + node size + 4 studs tolerance |
| Mining in locked zones / noclip past gates | Zone ownership checked per hit. `ZoneService` returns intruders to spawn |
| Mining without the right tool | The held Tool's `ItemId` must equal the effective equipped pickaxe |
| Equipping unowned items or auras | Ownership check (bought / rebirth count / pass attribute) in `EquipService.Equip` |
| Bad argument types | `typeof` checks on every remote argument. Unknown ids fail lookup |
| Race-condition double spends | "Check, then deduct" happens in one non-yielding call |
| Data duplication by server hopping | DataStore session locking |
| Tutorial reward farming | Completed once, server-validated, and skip gives no reward |
| Faking game pass perks | Perks come only from server-set `Pass_<Key>` attributes, verified with `UserOwnsGamePassAsync` |
| Double-granted Robux purchases | Saved `ProcessedReceipts` history, grant + record in one frame, save before `PurchaseGranted` |
| Buying exclusive pickaxes with Gems | Rejected server-side; they're owned only via rebirth count or pass |
| Teleporting into locked zones | `PortalService` checks the unlock, and `ZoneService` catches anyone who slips in |

## Testing checklist (Studio)

1. **Game Settings → Security → Enable Studio Access to API Services** (to test saving), then press Play.
2. The five-island world builds → tutorial card + beam → mine 40 gems → Shop highlight → buy Gem Multiplier → reward toast.
3. Rejoin: gems/upgrades persist and the tutorial doesn't reappear. Repeat on a fresh account and press **Skip Tutorial**.
4. Buy the Iron Pick: the tool model changes and walk speed rises. Reset the character: the pick and aura come back.
5. Unlock the Grotto at its gate: the gate fades locally, and walking in tweens the lighting to teal dusk with a zone banner. Lobby portals now teleport there.
6. Rebirth (temporarily lower `BaseCost` in `Config/Rebirths.luau` to test quickly): Gems, upgrades and shop picks reset, the rank appears on the HUD, and an Ember Aura unlocks in the Auras tab.
7. Set `StudioOwnsAllPasses = true`: the Royal Pick, Royal Aura, [VIP] chat tag, 2x multiplier and Auto-Mine all work. Developer products need real IDs (Studio purchases are free test purchases).
8. **Test → Clients and Servers** with 2 players: gates open only for the buyer, and the other player is pushed back if they try to clip through.
