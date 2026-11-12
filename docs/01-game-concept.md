# Phase 1 — Niche Analysis & Game Concept

## 1. Where the players and the money are (November 2026)

Snapshot from public trackers on 12 Nov 2026. Treat the numbers as directional, since each tracker samples differently.

| Signal | What it shows |
| --- | --- |
| [Statroblox genre ranking](https://statroblox.com/genres) | **Simulation** has about **46%** of all tracked concurrent players (~4.6M). Survival is next at ~12%. The top simulation games are "Steal / Throw / Break" collection loops ("Steal An Egg", ~830K CCU). |
| [Statroblox Tycoon sub-genre](https://statroblox.com/genres/simulation/tycoon) | Tycoon alone holds ~24% of tracked players across ~7,000 games. |
| [profitable.app genre table](https://profitable.app/roblox/genres) | Simulation: about $3.5B est. revenue, 15.2K games, 1.2M median visits, 92% like ratio. That's the biggest pie and the most crowded. RPG: 592 games, 3.1M median visits, 92% likes, so supply is thin. Roleplay has the highest "market strength" (85) but needs a social/community engine. |
| Roblox Top Earning chart (via BloxRant) | The top earners include **Anime Adventures** (anime tower defense / gacha) and **RIVALS** (shooter). |

### Niche comparison

| Niche | Why it retains | How fast new players get it | Content cost | Monetization | Main risk |
| --- | --- | --- | --- | --- | --- |
| **Simulator (incremental)** | Numbers always go up, the next unlock is always visible, rebirth loops | Seconds: click → gems → upgrade | **Low.** A new zone is a new config row plus art | Multiplier passes, boosts, auto-features | Crowded, so it needs a strong theme and polish to stand out |
| **RNG / Gacha ("Sol's RNG" style)** | Variable-ratio rewards, chasing rare drops, flexing | Seconds: press Roll | Low–medium (items/auras) | Luck boosts, roll speed | Shallow without a progression spine. Paid random items must show odds |
| **Tycoon / "Steal a ___"** | Ownership, base growth, social conflict | Fast | Medium | Very strong (multipliers, raids) | Trend-dependent. Clone saturation. Griefing |
| **Anime / Progression RPG** | Power fantasy, long-term goals | Slow (combat, builds) | **High** (abilities, bosses, balance) | Very strong (gacha units, passes) | Expensive to make and to keep up to date |
| **Tower Defense (unit gacha)** | Collection + strategy + co-op | Medium | High (units, maps, balancing) | Top-earning tier | Balance treadmill. Big studios dominate |
| **Survival** | Tension, co-op stories | Medium | High | Medium | Systems-heavy, harder to make addictive solo |

## 2. Pick: Incremental Simulator × RNG luck layer

The strongest fit for "instantly understood, high retention, achievable from scratch" is an **incremental mining simulator with an RNG layer on top**:

- **Simulator spine.** It's the largest audience on the platform, it's understood with zero explanation (click the shiny thing, number goes up, buy upgrade), and it scales cheaply: every new zone, pickaxe and upgrade is a row in a config file.
- **RNG spice.** Lucky crits now and egg/pet rolls later add variable-ratio rewards, which drive the "one more swing" feeling and support luck-boost monetization without paywalling progress.
- **Rebirths** give a long-term loop: reset for a permanent multiplier, so early zones stay relevant and sessions stay short and satisfying.

What we avoid on purpose: PvP stealing (griefing and trend risk), heavy combat balancing, and paid loot boxes at launch.

## 3. Concept: **Crystal Rush**

> *A floating archipelago of crystal islands drifts above the clouds. Each island deeper into the sky glows brighter and pays more. Grab a rusty pick, smash crystals, and climb from a sunlit quarry to the starlit Celestial Vault.*

The visual hook is **glowing crystals under cinematic lighting**. Every zone has its own lighting mood that the game tweens to as you walk in (see Phase 2). That's what makes thumbnails and first impressions pop.

### Core loop (seconds → minutes)

```
 ┌──────────────┐   click / hold    ┌──────────────┐   spend   ┌───────────────────┐
 │ Mine crystal │ ────────────────▶ │  Gems + XP   │ ────────▶ │ Upgrade / Pickaxe │
 └──────────────┘                   └──────────────┘           └─────────┬─────────┘
        ▲                                                                │
        └──────────── bigger numbers, faster swings, more crits ◀────────┘
```

### Progression loop (minutes → hours)

```
 Save up ─▶ Unlock next zone (new lighting, crystals worth 6–8x) ─▶ New pickaxe tier (new look + aura)
     ▲                                                                              │
     └──────── Rebirth: reset Gems & upgrades, keep pickaxes/zones, +50% Gems forever ◀┘
```

### Content at launch (all defined in `src/ReplicatedStorage/Shared/Config`)

| Zone | Unlock | Crystal value | Lighting mood |
| --- | --- | --- | --- |
| Sunlit Quarry | free | 4 | Golden hour, warm violet haze |
| Glowshroom Grotto | 4K | 24 | Dusk, teal bioluminescence |
| Frostfire Rift | 80K | 160 | Crisp blue daylight, glare |
| Magma Forge | 1.6M | 1.2K | Smoky orange, heavy bloom |
| Celestial Vault | 32M | 10K | Starry night, purple aurora |

Pickaxes: Rusty → Iron → Gilded → Amethyst → Glacier → Magma → Celestial (power 1 → 220). Each higher tier adds glow, a tier aura and walk speed.
Upgrades: **Gem Multiplier** (+25%/lvl), **Swing Speed** (−4% cooldown/lvl), **Lucky Strike** (+2% crit chance for 5x).

### The first 5 minutes (designed, then built into the tutorial)

| Time | Beat |
| --- | --- |
| 0:00 | Spawn facing the quarry. Crystals glow. A golden beam points at the nearest crystal: "MINE ME!" |
| 0:05 | First swing gives a "+4 💎" popup, particles and a crit chance. |
| 0:20 | 40 Gems. The tutorial highlights the **Shop** button, then the **Gem Multiplier** buy button. First upgrade bought. Tutorial completes (+100 Gems reward). |
| ~2:00 | Iron Pick (2x power). The character's look changes. |
| ~6:00 | The Grotto gate's "Unlock" prompt is in reach. Walking in shifts the whole world to teal dusk. |

### Retention roadmap (post-launch, in priority order)

1. Daily login streak + timed playtime gifts (session start and length).
2. **Pet eggs** (RNG collection, 3 equipped pets add multipliers). This is the biggest retention and monetization lever for this hybrid.
3. Quests ("Mine 200 crystals in the Grotto").
4. Global leaderboards (Total Gems, Rebirths) and a crystal "Index" collection book.
5. Weekend events (2x luck, limited-time zone).

### Monetization plan (ethical, non-pay-to-win at the start)

- Game passes: **2x Gems**, **VIP** (chat tag + aura), **Auto-Upgrade** (the system already exists; gate it behind a pass), **+1 pet slot**.
- Developer products: timed luck/gem boosts, gem packs scaled to the player's current zone.
- Rewarded video ads for short boosts. Premium Payouts come from engagement time.
- If you add paid eggs, Roblox policy requires showing each item's odds before purchase.
