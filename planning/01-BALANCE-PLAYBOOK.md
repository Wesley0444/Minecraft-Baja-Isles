# 01 — BALANCE REMEDIATION PLAYBOOK
### Minecraft 1.21.1 · NeoForge 21.1.249 · 6 players · one shared world · months-long campaign
**Rewritten 2026-08-29.** Companion to `00-MODLIST-AUDIT.md`. That doc says *what is broken*. This doc says *what to type*.

---

## 0. WHAT CHANGED IN THIS REWRITE — read this or you will re-litigate settled arguments

The previous version of this file was generated with an **empty tuning payload** (`{"tuning":[],...}`).
Every config key and every JSON snippet in it was invented. `00-MODLIST-AUDIT.md §0.5.4` correctly
tore it apart. That version is preserved at `01-BALANCE-PLAYBOOK.superseded-empty-payload.bak`
— **do not use it for anything.**

This version is written against the real per-mod research. Four things changed:

1. **The anchor rate is re-derived from a design constraint, not from one disputed number.**
   The audit's §0.5.4 objection — that the old band `0.005–0.018` hung entirely on an unsourced
   `P = 1.35` for the Void Forge — is valid and is fixed in §1.2. The new band comes from boss
   time-to-kill, is cross-checked against five tracks, and ships with a sensitivity table.
2. **A second defect class is introduced: MECHANIC DELETIONS (§1.7).** Roughly half the real
   offenders cannot be expressed as a rate at all, because they are binary. "100% damage reduction"
   has no `×`. Forcing those into a rate table is what made the old doc read as confident nonsense.
3. **Apotheosis `P = 4.10`** (Doc 00's source-derived figure), not the old doc's undefended `2.00`.
4. **The worst offender in the pack is not on the audit's radar at all.** It is Deeper and Darker's
   Resonarium armor — a literal arithmetic bug in shipping code granting total damage immunity from
   iron-tier gear. See §2.1. It outranks everything else by a distance.

### 0.1 ⚠ ATTRIBUTE-ID SYNTAX — settle this before you write a single override

> ✅ **RESOLVED 2026-08-30 — verified empirically on a headless vanilla 1.21.1 server.**
> `attribute <zombie> minecraft:generic.max_health get` → `20.0`; `minecraft:max_health` →
> *"Can't find element … of type 'minecraft:attribute'"*. Same for `attack_damage`.
> **1.21.1 requires the `generic.` prefix.** Everything below stands; change nothing on disk.

`datapacks/parity-underreward/data/undergarden/recipe/utherium_sword.json` currently contains:

```text
"type": "minecraft:generic.attack_damage"
```

**On 1.21.1 that is correct and you should NOT "fix" it.** The brief that commissioned this doc
claims 1.21 renamed `generic.attack_damage` → `attack_damage`. **That rename landed in 1.21.2
(snapshot 24w40a), not 1.21.** On 1.21.1 the `generic.` prefix is still required, and dropping it
fails *silently* — the component is discarded, the item keeps its default stats, and nothing in
chat tells you.

> 🔍 **VERIFY BEFORE APPLYING — 30 seconds, once, then trust it forever.**
> Load the server with one recipe override in place, craft the item, hover it. Tooltip shows *your*
> number → prefix is right. Tooltip shows the *mod's* number → flip the prefix and `/reload`.
> Grep `logs/latest.log` for `Unknown attribute` while you are in there.
> My confidence on the 1.21.2 attribution is ~80%. The in-game check is 100%. **Do the check.**

What *did* change in 1.20.5–1.21 and is safe to rely on — the on-disk packs already use all of it:

| Thing | Pre-1.20.5 | **1.21.1 (correct)** |
|---|---|---|
| Data folders | `recipes/` `loot_tables/` `tags/items/` `advancements/` | **singular**: `recipe/` `loot_table/` `tags/item/` `advancement/` |
| Recipe result | `"result": {"item": "x", "count": 1}` | `"result": {"id": "x", "count": 1}` |
| Ingredients | `{"item": "x"}` | `{"item": "x"}` / `{"tag": "x"}` — *object form; plain strings are 1.21.2+* |
| Modifier identity | `"uuid"` + `"name"` | `"id": "namespace:path"` |
| Modifier operations | `addition` / `multiply_base` / `multiply_total` | `add_value` / `add_multiplied_base` / `add_multiplied_total` |
| Attribute id prefix | `generic.` | **`generic.` — UNCHANGED on 1.21.1** |
| `pack_format` | — | **48** |
| Enchantments | hardcoded | **datapack JSON**, `data/<ns>/enchantment/<id>.json` |

---

## 1. THE PARITY PHILOSOPHY

### 1.1 The design statement, in one paragraph

> **This pack is a hub, not a spine.** Six players pick different tracks and play them at the same
> time. The pack is balanced when **two players who spend the same effort on different tracks come
> out comparably powerful** — not when every track is equally deep, not when the strongest item is
> weak, and not when everyone finishes everything. Absolute ceilings barely matter. **Payoff per
> hour is the whole game.** A 40-damage sword after 80 hours is fine. A 40-damage sword after 10
> hours is a defect. **So is a 7-damage sword after 60 hours** — under-rewarding is a defect of
> equal priority, and its fix is a buff, not an apology.

### 1.2 The metric, and the arithmetic behind the band

```
R = (P − 1.00) / (H × T)
```

- **`P`** — power as a multiple of the vanilla baseline. **Baseline = netherite sword + Sharpness V
  = 11.25 damage × 1.6 attack speed = 18.0 DPS = `1.00×`.**
- **`H`** — hours to reach that reward from world start, for one player.
- **`T`** — tedium coefficient (§1.5). Encodes "how much did this cost the human."
- **`R`** — **marginal gain per effort-hour.** Vanilla scores exactly `0.000`, because vanilla's
  gain over vanilla is zero. *(This is why the audit's §2 `P÷H` column is unusable: it credits
  vanilla with `0.083/hr` of gain over itself. Do not quote that column at anyone.)*

**Deriving the anchor `R*` — the step the old doc skipped.**

The old anchor came from asserting `P = 1.35` for one weapon and dividing. Instead, derive it from a
constraint the group actually cares about: **how long should the hardest fight in the pack take?**

Fixed and source-verified: L_Ender's Cataclysm's **Netherite Monstrosity is 600 HP, 12 armor,
25 damage, 100% knockback resistance.** It is the pack's difficulty benchmark and it is not getting
re-tuned. A designed multi-phase boss should live long enough for its mechanics to happen — call it
**60–90 seconds of real combat, of which ~25% is uninterrupted DPS uptime** (the rest is dodging,
repositioning, phase transitions, and being knocked around by something you cannot knock back).

```
DPS window            = 75 s × 0.25 uptime   ≈ 19 s of actual swinging
Required sustained DPS = 600 HP ÷ 19 s       ≈ 32 DPS      (ignores its 12 armor, so this is generous)
As a multiple of base  = 32 ÷ 18.0           ≈ 1.8×
```

That should be reachable at the **top of the long band (~80 h)**, with the pack ceiling sitting
modestly above so the deepest content still feels like an achievement. Ceiling **2.2× at 80 hours**:

```
R* = (2.20 − 1.00) / (80 × 1.0) = 1.20 / 80 = 0.015 per effort-hour
```

**Cross-check — `R* = 0.015` is internally consistent across every band by construction:**

| Band | Hours | Target `P` = `1 + R*·H` | Target DPS | Reads to a player as |
|---|---|---|---|---|
| Short | 10 | **1.15×** | 20.7 | "a real but modest upgrade" |
| Medium | 20 | **1.30×** | 23.4 | "clearly better than netherite" |
| Medium | 30 | **1.45×** | 26.1 | "that was worth the weekend" |
| Long | 50 | **1.75×** | 31.5 | "kills the Monstrosity in a fair fight" |
| Long | 80 | **2.20×** | 39.6 | "campaign-defining" |

### 1.3 ⚠ Sensitivity — how far the band moves if I am wrong

The audit's fair criticism was that a three-significant-figure band hid a judgment call. Here is
mine, exposed. The only soft input above is **DPS uptime**:

| Assumed uptime | Required DPS | Ceiling `P` @ 80 h | **`R*`** | Band (`R*`÷2 → ×2) |
|---|---|---|---|---|
| 15% (heavily mechanical boss) | 53 | 3.1× | 0.026 | 0.013 – 0.052 |
| **25% (used above)** | **32** | **2.2×** | **0.015** | **0.0075 – 0.030** |
| 40% (tank-and-spank) | 20 | 1.4× | 0.005 | 0.0025 – 0.010 |

**How to read this honestly:** band edges are soft by a factor of ~3, resting on an assumption
nobody has measured. **Therefore: only act on tracks that miss the band by more than 2×.** Every 🔴
and 🔵 verdict in §5 misses by 4× or more, so none of them are sensitive to this. The single genuine
🟡 row — Iron's Spells — *is* sensitive, and the right response there is **measure `H` first**, not
tune. That is why it sits in §6, not §5.

### 1.4 THE SIX RULES — the checklist for mod #151, six months from now

Print these. When someone proposes a mod, walk the list. Any 🔴 is a blocking objection.

> **RULE 1 — RATE CEILING.** *No track may exceed `R = 0.030`.*
> Compute `(P − 1) / (H × T)`. Above **0.030 marginal power per effort-hour** a track is stealing
> payoff from every other track. **Fix by raising `H` (gate it) before you touch `P` (nerf it)** —
> gating preserves the mod's content, nerfing deletes it.
> *Violators today: D&D 0.217 · Artifacts 0.185 · Grim and Bleak 0.175 · Apotheosis 0.129 ·
> Antarchy 0.119 · Expanded Combat 0.104 · Simply Bows 0.103.*

> **RULE 2 — RATE FLOOR.** *No track may fall below `R = 0.0075`.*
> Below **0.0075 per effort-hour** the player who picked it feels robbed, and that is exactly as
> much of a defect as an overpayer. **A negative `R` — a reward weaker than the gear you brought to
> earn it — is a bug report, not a design choice.**
> *Violators today: Paradise Lost −0.025 · Undergarden −0.015 · Eternal Starlight −0.006 ·
> Cataclysm stat-line −0.003 · Twilight Forest ~0.000.*

> **RULE 3 — NO UNGATED MECHANIC DELETIONS.** *An ability that removes a design axis has no `R`.
> Gate it or cut it. Do not scale it.*
> Damage immunity, instant-kill executes, permanent flight, knockback immunity, fall-damage
> immunity, debuff immunity, infinite-resource loops — all **binary**. Scaling them 20% does
> nothing. Each must sit behind a gate proportional to *the entire axis it deletes*, or come out.
> **This rule catches more real offenders than Rule 1 does.**

> **RULE 4 — THE ÷6 RULE.** *If a reward is freely giftable, divide its `H` by 6 before applying
> Rule 1.*
> One shared world. One player who finishes a gear track equips all six. A craftable item's true
> cost is `H/6`, so **gear tracks must be gated ~6× harder than knowledge tracks to reach the same
> rate.** Knowledge progression (Ars glyphs, Iron's school research, Apotheosis world tiers,
> consumed Life Shards) is ÷6-proof and can be gated loosely.
> *Worked example: Epic Knights steel plate at `H = 2` is really `H = 0.33`. Nothing survives that.*

> **RULE 5 — AXIS DECLARATION.** *Every track declares one primary reward axis, and tracks are only
> compared within an axis.*
> Six axes: **raw damage · ranged burst & safety · survivability · mobility · economy & automation ·
> exploration & cosmetics.** Two tracks can both score `R = 0.015` and still feel unfair if one pays
> in DPS and the other pays in scenery. The fix is not numeric — it is **disclosure**, which is what
> §4 exists for. Never silently sell an economy track to someone who wanted a sword.

> **RULE 6 — BUY PARITY WITH SPEED, NOT DAMAGE.**
> When buffing an under-rewarding track, raise **attack speed**, not the damage number.
> (a) The group's alarm is triggered by the *displayed damage number* — `12 dmg @ 2.1` reads as
> reasonable where `25 dmg @ 1.0` reads as broken, at identical DPS.
> (b) Apotheosis flat-damage affixes and Better Combat's 5-target cleave both **multiply flat
> damage**, so a big base number compounds into an outlier while a fast one does not.
> (c) It keeps you under the North Star ceiling of ~13 damage @ 1.0 speed.

### 1.5 The tedium coefficient `T` — effort ≠ hours

Sixty hours of tense boss fights is not the same investment as sixty hours of strip-mining.

| `T` | Kind of effort | Tracks here |
|---|---|---|
| **0.8** | Tense, skill-gated, failure-punishing | L_Ender's Cataclysm, Mowzie's Mobs, Twilight Forest bosses |
| **0.9** | Exploration with real risk | Aether, Eternal Starlight, Deeper and Darker, When Dungeons Arise |
| **1.0** | Mixed / neutral | Most dimension tracks, Epic Knights, Simply Swords |
| **1.1** | Building, planning, logistics | Ars Nouveau, Ars Elemental, Minecolonies |
| **1.2** | Repetitive with variance (RNG chases) | Apotheosis affix farming, Artifacts looting |
| **1.3** | Flat grind, low decision density | Antarchy ore mining, Apothic Spawners AFK, chest lotteries |

**The consequence, stated out loud:** `T` means a grind track must pay **~60% more raw power** than
a boss track to be judged equal. If that feels wrong, it is because you are thinking about power and
the group is thinking about *whether the evening was fun*. `T` is the term that encodes
"whether the evening was fun," and it is the reason Antarchy reads worse than its damage numbers
alone would suggest.

### 1.6 The rate table

`(src)` = derived from mod source, shipped data files, or an official wiki. `(est)` = judgment call,
and the weakest link in every row it appears in. **Every `H` in this table is `(est)`.**

| Track | Axis | `P` | `H` | `T` | **`R`** | vs `R*` | Verdict |
|---|---|---|---|---|---|---|---|
| **Deeper and Darker** — Sonorous Staff + Volume III | Ranged burst | 4.9 (src) | 20 | 0.9 | **0.217** | **14×** | 🔴 §2.1 |
| **Artifacts** — Power Glove + Feral Claws | Raw damage | 1.50 (src) | 3 | 0.9 | **0.185** | **12×** | 🔴 §2.4 |
| **Grim and Bleak** — Thunder Sword, charged | Raw damage | 5.8 (src) | 25 | 1.1 | **0.175** | **12×** | 🔴 §2.2 |
| **Apotheosis** — mythic affix weapon | Raw damage | 4.10 (src) | 20 | 1.2 | **0.129** | **8.6×** | 🔴 §2.5 |
| **Antarchy** — Big Bertha | Raw damage | 3.33 (src) | 15 | 1.3 | **0.119** | **7.9×** | 🔴 §2.3 |
| **Expanded Combat** — iron dagger, hour 3 | Raw damage | 1.28 (src) | 3 | 0.9 | **0.104** | **6.9×** | 🔴 §2.6 |
| **Simply Bows** — Buzzkill, 5 frames | Ranged burst | 3.0 (est) | 15 | 1.3 | **0.103** | **6.9×** | 🔴 §2.7 |
| **Expanded Combat** — netherite bow + gold arrows | Ranged burst | 2.9 (src) | 20 | 1.0 | **0.095** | **6.3×** | 🔴 §2.6 |
| **Antarchy** — Ultimate Sword | Raw damage | 2.76 (src) | 15 | 1.3 | **0.090** | **6.0×** | 🔴 §2.3 |
| **Grim and Bleak** — Thunder Sword, uncharged | Raw damage | 2.22 (src) | 25 | 1.1 | **0.044** | 2.9× | 🔴 §2.2 |
| **Iron's Spells** — one school, fully geared | Ranged burst | 2.75 (src) | 45 | 1.1 | **0.035** | 2.3× | 🟡 §2.9 |
| **Aether** — 10 Life Shards (+20 max HP) | Survivability | 2.00 (src) | 40 | 0.9 | **0.028** | 1.9× | ✅ in band |
| ***— PARITY ANCHOR —*** | — | — | — | — | ***0.015*** | ***1.0×*** | *target* |
| **Cataclysm** — Void Forge, *utility counted* | Raw damage | 1.35 (est) | 40 | 0.8 | **0.011** | 0.7× | 🔵 §2.8 |
| **Knaves' Needs** — Warden Katana | Raw damage | 1.11 (src) | 25 | 0.9 | **0.005** | 0.3× | 🟡 §2.13 |
| **Twilight Forest** — Fiery / Yeti / Knightmetal | Mixed | 1.00 (src) | 45 | 0.8 | **0.000** | 0× | 🔵 §2.10 |
| **Cataclysm** — Void Forge, **stat line only** | Raw damage | 0.90 (src) | 40 | 0.8 | **−0.003** | **NEG** | 🔵 §2.8 |
| **Eternal Starlight** — Moonring Greatsword | Raw damage | 0.70 (src) | 55 | 0.9 | **−0.006** | **NEG** | 🔵 §2.11 |
| **Ars Nouveau** — *damage axis only* | ⚠ wrong axis | 0.60 (src) | 40 | 1.1 | **−0.009** | **NEG** | ⚪ §2.14 |
| **The Undergarden** — Utherium / Forgotten | Raw damage | 0.67 (src) | 20 | 1.1 | **−0.015** | **NEG** | 🔵 §2.12 |
| **Paradise Lost** — Surtrum, craftable ceiling | Raw damage | 0.44 (src) | 20 | 1.1 | **−0.025** | **NEG** | 🔵 §2.15 |

**Read the bottom half before the top half.** Five tracks pay a player *less than the netherite
sword they walked in with*, after 20–55 hours. That is the group's stated nightmare, already
present, and no overpowered mod causes it. It is caused by mod authors balancing against
**unenchanted** netherite (8 damage) while your players carry Sharpness V (11.25).

### 1.7 MECHANIC DELETIONS — the defects with no `R`

Not multipliers, so not in §1.6. **Each removes an entire design axis from the whole pack, for all
six players, permanently.** Rule 3 governs them.

| Deletion | Source | Axis removed | Real gate | Fix |
|---|---|---|---|---|
| **100% damage reduction** | D&D Resonarium armor, 4 pc | *All combat difficulty* | Farm a splitting trash mob, iron tier | 🔴 §2.1 — **first** |
| **Instant-kill below 25% HP** | Simply Swords Omen, 75%/hit | Every boss's final phase | Chest loot, hour 1 | 🔴 §2.7 |
| **Instant-kill below 25% HP** | Apotheosis `executing`, mythic | Every boss's final phase | Post-Wither | 🔴 §2.5 |
| **Permanent creative flight** | Apothic Attributes Potion of Flying | Exploration, Elytra, Waystones | Post-dragon, then renewable | 🔴 §2.5 |
| **~Permanent flight** (84 s up / 78 s cd) | Iron's Spells Angel Wings L5 | Exploration, Elytra, Waystones | Legendary scroll | 🔴 §2.9 |
| **100% knockback immunity** | Epic Knights, **2 pieces** of steel plate | Boss knockback phases, creepers, ledges | Blast furnace, hour 2 | 🔴 §2.16 |
| **Fall damage deleted** | Artifacts Bunny Hoppers | Verticality as a threat | Chest loot, hour 2 | 🔴 §2.4 |
| **All debuffs capped at 5 s** | Artifacts Antidote Vessel | Every status-effect boss design | Chest loot, hour 2 | 🔴 §2.4 |
| **Recipe-graph reversal** | Twilight Forest Uncrafting Table | ***Every mod's*** recipe gating | 1 diamond portal, hour 1 | 🔴 §2.10 |
| **Infinite Nether Stars** | Gateways ➜ Apothic Spawners | Resource scarcity, beacon cost | 1 wither skull | 🔴 §2.17 |
| **Free Prot V ×4, past vanilla cap** | Antarchy Ultimate Armor | Enchanting economy, armor progression | Iron pickaxe | 🔴 §2.3 |
| **i-frame-bypassing 9 × 50 burst** | Eternal Starlight Starfall Longbow | Boss HP bars | Post-dragon | 🔴 §2.11 |
| **Uncapped damage scalar** | Paradise Lost Soul Blade, +0.25/mob type | *Scales with your modlist size* | Kill one of everything | 🔴 §2.15 |
| **Permanent fire immunity** | Aether Phoenix armor, full set | Nether + Cataclysm Ignis fire design | Bronze/Silver dungeon | 🟡 §2.18 |
| **6.5-block melee reach** | Aether Valkyrie Lance | Boss engagement distance | Bronze dungeon, hour 6 | 🟡 §2.18 |
| **Full-damage 5-target cleave** | Better Combat + Sweeping Edge | Crowd content as a threat | Free, always on | 🟡 §2.19 |
| **Passive mob-drop farming** | Ars Nouveau Drygmy | *Every combat mod's* material gate | Mid Ars Nouveau | 🟡 §2.14 |

### 1.8 The ÷6 audit — which tracks collapse when one player finishes them

Rule 4 in practice. This is the second-order effect the group had not raised, and it changes *which*
mods need gating most.

| Reward shape | Divides by 6? | Tracks | Consequence |
|---|---|---|---|
| **Craftable gear** | ✅ **fully** | Epic Knights, Expanded Combat, Antarchy, Undergarden, Twilight Forest, Eternal Starlight, Paradise Lost, D&D Resonarium/Warden, Ars Elemental | One player's 20 h becomes the group's 3.3 h. **Gate hardest.** |
| **Loot-RNG gear** | ✅ with variance | Artifacts, Simply Bows, Simply Swords Uniques, Aether dungeon loot | Six players open six times the chests. Effective group rate ≈ 6× solo. |
| **Consumables** | ✅ and renewably | Apothic Attributes flight potions, Ars Elixirum, G&B Blood Bottles | Worst case — one chorus farm flies the whole server forever. |
| **Per-player knowledge** | ❌ **no** | Ars Nouveau glyphs, Iron's Spells school research, Apotheosis world tiers | Naturally ÷6-proof. **Gate loosely.** |
| **Consumed on use** | ❌ no | Aether Life Shards | Each player earns their own. Well designed — copy this pattern. |

**The finding:** every gear track collapses; every magic track does not. That is why Iron's Spells
and Ars Nouveau read as "fine" in the rate table while Epic Knights and Antarchy do not — it is not
that the magic mods are weaker, it is that **their progression cannot be handed to a friend.**
Spend your gating effort on the gear mods.

### 1.9 Axis mismatches — equal rate, wrong currency

Rule 5 in practice. These pairs are numerically comparable and will still generate an argument:

| Pair | Both roughly | But one pays in… | and the other in… | Mitigation |
|---|---|---|---|---|
| **Ars Nouveau** vs **L_Ender's Cataclysm** | 40 h | automation, logistics, source infrastructure | raw damage + boss trophies | The classic. §4 must say this in the menu text, out loud. |
| **Eternal Starlight** vs **Iron's Spells** | 45–55 h | 22 biomes, 19 discs, 4 armor trims | 66-damage ranged burst | ES pays in *scenery*. Sell it to the right person. |
| **Minecolonies** vs **Epic Knights** | 30 h | a working town | a full plate kit | Different games entirely; do not let one player pick both blind. |
| **Aether** vs **Twilight Forest** | 40 h | +20 max HP, mobility toys | netherite-parity gear, boss trophies | Closest match on the list. Genuinely fair swaps. |
| **Apothic Spawners** vs **anything** | any | infinite everything | a number | Not a track. It is an economy solvent. §2.17. |

### 1.10 THE TWO VARIABLES NOBODY ASKED ABOUT — and they both outrank every mod in §2

Everything above this line balances **payoff per hour**. That is the right metric and it answers the
question that was asked. But two inputs sit *outside* the metric, neither has been decided, and
either one can produce a bigger power gap than every mod in this document combined.

#### 1.10.1 ⚠ UNEQUAL HOURS — the parity failure that no config file can fix

The stated fear is *"two people put in equal effort and get different rewards."* **The far more
likely event in a six-person friend group is unequal effort.** You host. You will be on this server
more than anyone, probably by a factor of three to six. Dan and David have jobs and will not.

Run the arithmetic against the anchor. `P = 1 + R*·H` with `R* = 0.015`:

| Player | Hours in 3 months | `P` at perfect rate parity | Reads as |
|---|---|---|---|
| Wesley (host) | 120 | **2.80×** | "one-shots the Monstrosity" |
| Leyton | 60 | **1.90×** | "comfortable in Cataclysm" |
| Dan | 20 | **1.30×** | "still dies to Ignis" |

**That is a 2.2× spread produced by a pack with ZERO balance defects.** It is larger than the gap
between Cataclysm (`R = −0.003`) and Iron's Spells (`R = 0.035`) — the worst legitimate rate mismatch
in §1.6 — and no datapack in §3 touches it. A perfectly balanced pack still ships this.

Worse, it **compounds with the ÷6 rule in the wrong direction**. §1.8 says a finished gear track
equips all six players. In practice the person who finishes it is the person with the hours, so the
high-hour player becomes the group's *supplier*, and the low-hour players stop earning gear
altogether — they receive it. Their track choice stops mattering, which is the hub premise dying of
a cause this document does not model.

**Four levers, in ascending order of intrusiveness. Pick one before launch, not after Dan quits.**

| Lever | What it does | Cost | Verdict |
|---|---|---|---|
| **Do nothing, say it out loud** | Add one line to the House Rules: *"Wesley will out-gear everyone. That is hours, not balance. Say something if it stops being fun."* | Free | **Do this regardless.** It is the §4 disclosure principle applied to the one axis §4 currently ignores. |
| **Bountiful as a catch-up faucet** | Bountiful is already in the pack and is datapack-driven. Scale bounty rewards to *inverse* playtime, or just hand the low-hour players richer boards. | 1 loot file | **Recommended.** Cheapest real fix, uses a mod already installed, and §Doc 00 §10.6 already nominates Bountiful as the compensating-reward mechanism. |
| **Group-locked progression** | The big gates (Cataclysm bosses, Apotheosis world tiers) only advance when 3+ players are online. | Advancement/KubeJS work | Fits the campaign framing. Adds scheduling pressure to a group that already struggles to schedule. |
| **Shared-account gear pool** | A public shulker of spare gear at spawn; the high-hour player's surplus is the group's floor. | A chest | **Do this too.** Zero engineering, converts the ÷6 problem from a leak into a feature. |

> **The honest framing for the group:** this pack is balanced so that *an hour spent on any track is
> worth about the same as an hour spent on any other track*. It is **not** balanced so that everyone
> ends up equal, because everyone will not play the same amount. Those are different promises and
> only the first one is deliverable.

#### 1.10.2 ⚠ DEATH PENALTY — currently undecided, and it silently re-weights every track

`02-SERVER-BUILD-PLAN.md §3.4` ships `difficulty=hard` with **`keepInventory` unset (= false)** and
**no grave mod anywhere in the modlist**. Nobody has decided this; it is the vanilla default
inherited by accident. It is a balance decision of the same magnitude as any nerf in §2.

**Why it re-weights the parity table:** every `P` in §1.6 is the value of a reward *you are holding*.
Multiply it by the probability you still hold it. That multiplier is **not uniform across axes**:

| Reward shape | Survives death? | Tracks |
|---|---|---|
| **Crafted/looted gear** | ❌ — lava, void, a 25-damage boss, a 5-minute despawn timer in a dimension you now cannot re-enter without it | Epic Knights, Undergarden, Twilight Forest, Eternal Starlight, Antarchy, D&D, Aether gear |
| **Per-player knowledge** | ✅ **fully** | Ars Nouveau glyphs, Iron's Spells school research, Apotheosis world tiers |
| **Permanent attributes** | ✅ fully | Aether Life Shards, Confluence Life Crystals, The Awakening powers |
| **Infrastructure** | ✅ fully | Minecolonies, Ars automation |

So `keepInventory=false` is a **systematic tax on exactly the gear tracks §1.8 already identified as
the ones that need the most gating** — and a systematic exemption for the magic and economy tracks.
It pushes gear tracks *down* relative to knowledge tracks, on top of everything else. That is not
necessarily wrong, but it is currently happening **by default, unmeasured, and in the same direction
as several of the nerfs in §2**, which risks double-dipping.

It also interacts badly with the pack's difficulty ceiling: Cataclysm's Netherite Monstrosity is
600 HP / 25 damage / knockback-immune, and Simply Entity Equipment can produce 100+ HP cave trash.
Full loss on death against that content is what makes a group stop attempting the hard content —
which means the *reference track* goes unplayed and every rate in §1.6 is anchored to a fight nobody
fights.

**Recommendation, in order of preference:**

1. **Add a grave mod.** `Corail Tombstone` or `Gravestone Mod` (1.21.1 NeoForge, both maintained).
   Keeps the death *sting* — the run back, the lost XP, the recovery trip — while removing the
   catastrophic-loss outcome that stops people engaging with 600 HP bosses. **This is the option
   that best preserves the numbers already in this document.**
   ⚠ Corail Tombstone ships its own progression (knowledge points, enchantments, a "Grave Key" that
   trivialises recovery) — **audit it against Rule 1 before shipping, or disable its perk system**.
   Do not import a fifth reward track through the back door of a QoL fix.
2. **`keepInventory=true`.** Simplest. But it deletes an entire risk axis pack-wide, which is a
   Rule 3 mechanic deletion — and it makes the Aether's Life Shards, Artifacts' Cross Necklace and
   Epic Knights' whole defensive premise worth measurably less. If you do this, revisit §2.16 and
   §2.18, because you have just nerfed the survivability axis for free.
3. **Leave it `false` and say so loudly in the Track Menu.** Legitimate, but then the House Rules
   must state that gear tracks carry loss risk that magic tracks do not, so the pick is informed.

**Do not leave this undecided.** It is currently decided *by omission*, in the harshest direction,
against the tracks this document spends the most effort protecting.

#### 1.10.3 Footnote — `pvp=true` is also currently a default, not a decision

`server.properties` ships `pvp=true`. In a pack with 36-damage swords (pre-cut), instant-kill Omen
procs, and freely giftable gear, a six-player friend server with an accidental swing has a much
worse outcome than vanilla. Not a balance defect — just another inherited default worth a
thirty-second conversation.

---

## 2. PER-MOD FIXES

**Format:** every subsection gives the defect, the file path, the exact keys/values, and pastable
JSON where a datapack is the only lever. Blocks tagged 🔍 **VERIFY BEFORE APPLYING** rest on research
I could not fully confirm — test them in singleplayer before they touch the shared world.

**Universal caveat on config filenames.** Several of these mods generate their config on first boot
and the exact filename/extension varies by loader and version. **Boot the server once with the mods
installed and no config edits, then read the generated `config/` directory.** Where I am unsure of a
filename I say so rather than guessing.

---

### 2.1 🔴 Deeper and Darker — **FIX THIS FIRST. Nothing else matters until it is done.**

**Defect 1 — Resonarium armor grants literal 100% damage immunity.** This is an arithmetic bug in
shipping 1.4.1 code, not a design choice. In `DeeperDarkerEvents.livingDamageEvent`:

```java
float reduction = incoming / 4;              // computed ONCE, outside the loop
for (ItemStack stack : entity.getArmorSlots()) {
    if (stack.is(DDTags.Items.RESONARIUM_ARMOR)) {
        incoming -= reduction;               // subtracted once PER PIECE
    }
}
```

Four pieces subtract a *constant* 25% four times: `incoming − 4 × (incoming/4) = 0`. **Full set =
zero damage** from everything not tagged `minecraft:bypasses_armor`. The armor is upgraded from
**iron**, using Resonarium that drops from a common splitting trash mob. Not a boss. Not netherite.
A farm. It is freely giftable, so one afternoon ends combat for all six players permanently.

**The fix is one file.** Empty the tag the guard checks. The armor stays craftable and wearable as a
normal 20-armor set; only the broken event stops firing.

`datapacks/deeperdarker-parity/data/deeperdarker/tags/item/resonarium_armor.json`
```json
{
  "replace": true,
  "values": []
}
```

> ⚠ **The file on disk right now is WRONG.** It lists three pieces (chestplate, leggings, boots),
> which leaves **75% damage reduction** — still far past netherite's ~64% *and* still stacking on
> top of the armor points. Three-quarters immunity is not a fix. **Replace it with the empty array
> above.** If you want to keep a flavour of the mechanic, keep exactly **one** piece in the tag
> (25%) — but understand that 25% flat, on top of armor, on top of Protection, is already generous.

> 🔍 **VERIFY BEFORE APPLYING** — confirm the folder is singular `tags/item/` (1.21 rename) and that
> the tag id in `DDTags.Items` really is `deeperdarker:resonarium_armor`. Test: wear the full set in
> creative, `/damage @s 20 minecraft:generic`, watch the health bar. It should drop.

**Defect 2 — Sonorous Staff, 88 damage piercing AoE on a 1-second cooldown.** `R = 0.217`, fourteen
times the anchor. Damage is hardcoded in Java and is **not datapack-reachable.** Your lever is the
enchantment that scales it, which *is* datapack JSON on 1.21:

`datapacks/deeperdarker-parity/data/deeperdarker/enchantment/volume.json`
```json
{
  "description": { "translate": "enchantment.deeperdarker.volume" },
  "supported_items": "#minecraft:enchantable/weapon",
  "weight": 5,
  "max_level": 1,
  "min_cost":  { "base": 15, "per_level_above_first": 9 },
  "max_cost":  { "base": 65, "per_level_above_first": 9 },
  "anvil_cost": 4,
  "slots": ["mainhand"],
  "effects": {}
}
```
Dropping `max_level` from 3 → 1 takes the staff from 88 back to its 50 base (`P` 4.9 → 2.8). Still
above band. If the group wants it properly in band, **delete the recipe** instead:

`datapacks/deeperdarker-parity/data/deeperdarker/recipe/sonorous_staff.json` — an override with an
unobtainable ingredient is safer than an empty file (an empty file throws on datapack load):
```json
{
  "type": "minecraft:crafting_shaped",
  "category": "equipment",
  "key": { "#": { "item": "minecraft:barrier" } },
  "pattern": ["#"],
  "result": { "id": "deeperdarker:sonorous_staff", "count": 1 }
}
```

**Defect 3 — the three ungated summon spells.** `SummonShatteredSpell`,
`SummonSculkCentipedeSpell` and `SummonSculkSnapperSpell` each override `requiresLearning()` to
return `false`, walking around Iron's Spells' Eldritch research gate — the longest gate in that mod.
Fix via Iron's Spells' own spell-config datapack surface (datapack **overrides** the config folder):

`datapacks/deeperdarker-parity/data/deeperdarker/irons_spellbooks_spell_config/summoned_shattered.json`
```json
{ "allow_crafting": false, "min_rarity": "legendary" }
```
Repeat for `summoned_sculk_centipede.json` and `summoned_sculk_snapper.json`.

**Defect 4 — Summon Warden pet, ~416 HP / ~38 damage, 600 s duration on a 180 s cooldown** (uptime
is therefore permanent). Same surface:

`.../irons_spellbooks_spell_config/summoned_warden.json`
```json
{ "power_multiplier": 0.5, "cooldown_in_seconds": 600 }
```
`power_multiplier` scales *both* HP and damage. 0.5 → ~208 HP / ~19 damage, and 600 s cooldown vs
600 s duration ends the permanent-uptime problem.

**Also set, in `config/deeperdarker-common.toml`** (filename unconfirmed — check after first boot):
- `soulElytraCooldown = -1` — disables the free rocket-less elytra boost.
- `snapperDropLimit = 1` (from 8) — Sculk Snappers are an enchanted-book faucet feeding Apotheosis.

**Not fixable by datapack:** Warden armor's 24 armor / 4.0 toughness / **+50% permanent walk speed**
(`MOVEMENT_SPEED +0.05 ADD_VALUE` on a 0.1 base — every wiki reporting this as "5%" is wrong).
Item attribute defaults are baked at registration. Options: delete the smithing recipes, or accept
it. Given it costs 7–20 Warden kills, **accept it** — that gate is real.

---

### 2.2 🔴 Grim and Bleak — **recommend CUT. If kept, it needs KubeJS, not a datapack.**

`R = 0.175` charged. Thunder Sword is **25 base damage + 10–40 from charge**, entry gate is
*chiseled deepslate* — a first-hour vanilla stonecutter product.

**There is no config file.** I searched CurseForge, Modrinth, MCreator and every changelog across
nine releases and found none; MCreator does not generate one unless the author builds it, and there
is no evidence this one did. **No spawn toggles, no damage sliders, no way to disable Dimensional
Breaching, no boss tuning.**

**And a datapack cannot fix the damage.** On 1.21 an item's base attack damage is an item component
baked in at registration. Recipes and loot tables *are* overridable; the item's stat line is not.
Fixing this mod requires **KubeJS `ItemEvents.modification`** — a scripting dependency you would be
adding solely to patch one mod.

**Three more things a datapack also cannot touch**, all MCreator procedure logic:
- **Dimensional Breaching** — after *any one player* kills the Gate Guardian, hostile abominations
  spawn in the Overworld **every night, permanently, for all six players**, including those who
  never opted into this mod. No documented way to revert. On a months-long world this is a one-way
  door pressed by whoever finishes first.
- **"Killing villagers restores your worthiness"** — makes the ritual currency farmable off a
  breedable mob, and collides directly with Minecolonies.
- **Blood Bottles + Carbon Blood armor** — "significantly repairs armor" on a renewable mob drop.

**If you keep it anyway**, the minimum viable gate is to re-cost the portal item so the dimension
opens post-Nether instead of pre-iron:

`datapacks/grimbleak-gate/data/grim_and_bleak/recipe/compass_of_pains.json`
```json
{
  "type": "minecraft:crafting_shaped",
  "category": "misc",
  "key": {
    "N": { "item": "minecraft:nether_star" },
    "D": { "item": "minecraft:crying_obsidian" },
    "C": { "item": "minecraft:compass" }
  },
  "pattern": [ " D ", "DCD", " N " ],
  "result": { "id": "grim_and_bleak:compass_of_pains", "count": 1 }
}
```
> 🔍 **VERIFY BEFORE APPLYING** — the real item id is **unconfirmed**; the mod page defers all
> recipes to JEI. Get the id from JEI (`F3+H` shows ids on tooltips) before writing this file.

**My recommendation: cut it.** A mod with no config, no source, unfixable stat lines, an
irreversible server-wide state change, and a 25-damage pre-iron sword is not worth a KubeJS
dependency and a permanent Overworld mutation.

---

### 2.3 🔴 Antarchy — **the mod the group named. They were right, but about the wrong item.**

`R = 0.119` (Big Bertha) and `0.090` (Ultimate Sword). But **the sword is not the problem** — the
armor is.

**Ultimate Armor auto-grants Protection V, Blast Protection V, Fire Protection V AND Projectile
Protection V, for free, at 32 armor points, reachable with an iron pickaxe.** That combination is
*impossible in vanilla* (Protection caps at IV and is mutually exclusive with the other three). It
pins the wearer at the **80% damage-reduction hard cap** with zero enchanting, zero XP, zero anvil
cost — deleting Apotheosis's entire enchanting economy in one craft. That is a Rule 3 mechanic
deletion, and the auto-enchant is **code-driven, not datapack-reachable.**

**Good news: this mod has an exceptional config surface** — `AntarchySettings` is ~110 KB of pure
tunables, and the author's own page says "a ridiculous amount of config options." Everything below
is a real key.

**Config** (filename unconfirmed — likely emitted by the `Integrated API` dependency; read
`config/` after first boot):

| Key | Default | **Set to** | Why |
|---|---|---|---|
| `ultimateSwordAttackDamage` | 34.0 | **13.0** | North Star ceiling; `P` 2.76 → ~1.16 |
| `bigBerthaAttackDamage` | 62.0 | **20.0** | `P` 3.33 → 1.11 at 1.0 speed |
| `ultimateAxeAttackDamage` | 42.0 | **15.0** | keep the axe/sword gap, drop the magnitude |
| `ultimateBowAttackDamage` | 18.0 | **8.0** | vanilla bow ≈ 6 |
| `ultimateHelmetArmorValue` | 6 | **3** | 32 → 20 armor points, netherite parity |
| `ultimateChestplateArmorValue` | 11 | **8** | ″ |
| `ultimateLeggingsArmorValue` | 9 | **6** | ″ |
| `ultimateBootsArmorValue` | 6 | **3** | ″ |
| `duplicatorTreeEnabled` | true | **false** | economy solvent |
| `minersDreamEnabled` | true | **false** | 96-block auto-mining, `T`-destroying |
| `gravityGunEnabled` | true | *your call* | utility, not power |

**The armor auto-enchant still is not fixed by any of that.** Only two real options:
1. **Recipe-gate it** so it is not an iron-tier item (below). This is the recommended path.
2. Cap `data/minecraft/enchantment/protection.json` `max_level` — **global, affects the whole pack,
   almost certainly not worth it.**

**Recipe gate — the highest-value single change for this mod:**

`datapacks/antarchy-gate/data/antarchy/recipe/ultimate_chestplate.json`
```json
{
  "type": "minecraft:smithing_transform",
  "template": { "item": "minecraft:netherite_upgrade_smithing_template" },
  "base":     { "item": "antarchy:titanium_chestplate" },
  "addition": { "item": "cataclysm:ignitium_ingot" },
  "result":   { "id": "antarchy:ultimate_chestplate", "count": 1 }
}
```
> 🔍 **VERIFY BEFORE APPLYING** — `antarchy:titanium_chestplate` and `cataclysm:ignitium_ingot` are
> both **unconfirmed ids**. Pull the real ones from JEI. The *pattern* is the point: make Antarchy's
> capstone consume a **Cataclysm boss drop**, which simultaneously gates Antarchy and gives
> Cataclysm's under-rewarding track a reason to exist (§2.8). Two defects, one file.

**Also datapack the ore gate** — there are no ore keys in the config, so worldgen JSON is the only
route. Move uranium/titanium into `minecraft:needs_diamond_tool`:

`datapacks/antarchy-gate/data/minecraft/tags/block/needs_diamond_tool.json`
```json
{
  "replace": false,
  "values": [ "antarchy:uranium_ore", "antarchy:deepslate_uranium_ore",
              "antarchy:titanium_ore", "antarchy:deepslate_titanium_ore" ]
}
```

---

### 2.4 🔴 Artifacts — **`R = 0.185`. The highest rate in the pack, from hour-two chest loot.**

Nothing here is a 30-damage sword. **Power Glove is `+4 flat damage to every attack, weapon-agnostic,
permanent, un-losable, freely giftable, from a pillager outpost in hour 2–6.** Netherite sword
8 → 12. With Feral Claws (+40% attack speed) that is 26.9 DPS = `1.50×` at `H = 3`.

Worse than the number: a *flat, weapon-agnostic* bonus **inflates the floor without inflating the
ceiling**, which compresses the felt value of every gear upgrade the other twelve tracks ask you to
earn. It is the single most corrosive item in the pack for a hub design.

**Fix A — game rules.** These are per-world, settable live with `/gamerule`, no restart. This is an
unusually good tuning surface; use it.

```
/gamerule artifacts.powerGlove.attackDamageBonus 1
/gamerule artifacts.crystalHeart.healthBonus 4
/gamerule artifacts.feralClaws.attackSpeedBonus 15
/gamerule artifacts.vampiricGlove.absorptionRatio 10
/gamerule artifacts.vampiricGlove.maxHealingPerHit 2
/gamerule artifacts.crossNecklace.bonusInvincibilityTicks 5
/gamerule artifacts.antidoteVessel.maxEffectDuration 15
/gamerule artifacts.goldenHook.experienceBonus 25
/gamerule artifacts.steadfastSpikes.knockbackResistance 4
/gamerule artifacts.superstitiousHat.lootingLevelBonus 0
/gamerule artifacts.luckyScarf.fortuneBonus 0
/gamerule artifacts.bunnyHoppers.doCancelFallDamage false
/gamerule artifacts.scarfOfInvisibility.enabled false
```

> 🔍 **VERIFY BEFORE APPLYING** — the exact game-rule value *syntax* (bare number vs `"4 damage"`
> string) is not confirmed; the wiki documents defaults as human-readable strings like
> `"4 damage"`. Run `/gamerule artifacts.powerGlove.attackDamageBonus` with no value first to see
> the format the server expects, then set it.

**Fix B — the better fix, loot placement.** The rate problem is *when* these arrive, not what they
do. Strip the two strongest artifacts out of hour-two structures and leave them in late ones:

`datapacks/artifacts-parity/data/minecraft/loot_table/chests/pillager_outpost.json` — copy the
vanilla table and remove the Artifacts injection, **or** neutralise it with a NeoForge modifier:

`datapacks/artifacts-parity/data/neoforge/loot_modifiers/global_loot_modifiers.json`
```json
{
  "replace": false,
  "entries": [ "artifacts_parity:strip_early_artifacts" ]
}
```

**Also flag two items the game rules do not reach cleanly:**
- **Everlasting Beef / Eternal Steak** — food that is *not consumed*, 1/500 from a cow, **hour one**.
  Permanently ends hunger for the whole server. Remove from the cow drop; keep it in bastion stables.
- **Aqua-Dashers** — sprint on **lava**. Deletes the Nether's and the Undergarden's biggest
  traversal hazard.

**Slot-count caveat:** Power Glove, Feral Claws and Vampiric Glove are all "hands" items. Whether
you can wear two of the three depends on the built-in slot count on 13.x, which I could not confirm.
If hands has one slot, the ceiling is 19.2 DPS (`P` 1.07) not 26.9, and this whole section is
roughly half as urgent. **Check in-game before you spend an evening on it.**

---

### 2.5 🔴 Apotheosis — `R = 0.129`. Keep it. It needs surgery, not removal.

Apotheosis is not a parallel track competing on rate — **it is a multiplier on every other track**,
because affixes roll onto modded gear through item tags. That is precisely the
Antarchy-breaks-Cataclysm shape, with Apotheosis as the amplifier.

The mod's saving grace: **almost its entire balance surface is a datapack registry.** Download the
version-matched *Stock Datapack* from CurseForge's Additional Files tab and edit from there rather
than authoring blind.

**Fix 1 — `executing`. The single highest-value line in this whole audit.** Read
`ExecutingAffix.java`: on a hit at ≥98% attack strength, if the target is below the threshold, the
code does not deal damage — it **sets health to zero and calls `die()` directly.** Mythic band is
0.15–0.25, so a mythic weapon deletes the final **25%** of any entity's HP bar. I could not confirm
whether bosses are excluded. Assume they are not.

`datapacks/apotheosis-parity/data/apotheosis/affixes/melee/executing.json`
```json
{
  "type": "apotheosis:melee/executing",
  "definition": {
    "affix_type": "ability",
    "exclusive_set": [],
    "weights": {
      "haven":    { "weight": 0 },
      "frontier": { "weight": 0 },
      "ascent":   { "weight": 0 },
      "summit":   { "weight": 0 },
      "pinnacle": { "weight": 0 }
    }
  },
  "values": {
    "apotheosis:epic":   { "min": 0.03, "max": 0.05 },
    "apotheosis:mythic": { "min": 0.05, "max": 0.08 }
  }
}
```
All weights zero removes it from rolls entirely while keeping the file valid (deleting the file
outright can break datagen references). If the group would rather keep it as flavour, restore the
weights and leave the 5–8% values — an execute at 8% is a satisfying finisher, not a boss-deleter.
The on-disk `executing.OPTION-B-keep-as-flavour.json` looks like it was written for exactly this.

**Fix 2 — `piercing` (Armor Pierce +5 to +12 flat).** Full netherite is 20 armor. A mythic weapon
ignoring 12 of it is a **60% armor bypass**, which undercuts every tank-flavoured mod on the list
simultaneously (Epic Knights, Cataclysm Ignitium, Aether).

`datapacks/apotheosis-parity/data/apotheosis/affixes/melee/attribute/piercing.json`
```json
{
  "type": "apotheosis:attribute",
  "attribute": "apothic_attributes:armor_pierce",
  "categories": ["apotheosis:melee_weapon"],
  "definition": { "affix_type": "stat", "exclusive_set": [] },
  "operation": "add_value",
  "values": {
    "apotheosis:common":    { "min": 0.5, "max": 1.0 },
    "apotheosis:uncommon":  { "min": 1.0, "max": 1.5 },
    "apotheosis:rare":      { "min": 1.5, "max": 2.5 },
    "apotheosis:epic":      { "min": 2.5, "max": 3.5 },
    "apotheosis:mythic":    { "min": 3.5, "max": 5.0 }
  }
}
```

**Fix 3 — the `unbreakable` roll.** `rarities/mythic.json` contains a 0.99-chance durability branch
and a **1% chance to grant `minecraft:unbreakable` outright**. On its own that is fine. Combined
with Twilight Forest's **Glass Sword (40 damage, 1 durability)** it produces a permanent ~64 DPS
weapon — 3.5× the baseline. Delete the unbreakable branch from `rarities/mythic.json`, **and**
tag the Glass Sword out of affix eligibility (§2.10).

**Fix 4 — ⭐ the highest-leverage lever in the entire pack.** World-tier unlocks are plain
advancement JSON. **Weld Apotheosis's progression onto Cataclysm's** so the two tracks gate each
other instead of undercutting each other:

`datapacks/apotheosis-parity/data/apotheosis/advancement/progression/pinnacle.json` — replace the
`kill_ender_dragon` criterion:
```json
{
  "parent": "apotheosis:progression/summit",
  "criteria": {
    "kill_cataclysm_boss": {
      "trigger": "minecraft:player_killed_entity",
      "conditions": {
        "entity": [{ "condition": "minecraft:entity_properties",
                     "entity": "this",
                     "predicate": { "type": "cataclysm:netherite_monstrosity" } }]
      }
    }
  },
  "requirements": [["kill_cataclysm_boss"]]
}
```
> 🔍 **VERIFY BEFORE APPLYING — this snippet is deliberately incomplete.** Do **not** paste it as
> written: the stock `pinnacle.json` also carries an `equip_epic`-style criterion requiring
> epic-or-better gear in all five slots, and dropping it would make Pinnacle reachable with no gear
> requirement at all — the opposite of the intent.
> **Correct procedure:** open the stock datapack's `pinnacle.json`, **delete only the
> `kill_ender_dragon` criterion**, paste `kill_cataclysm_boss` in its place, and add
> `"kill_cataclysm_boss"` to the existing `requirements` array alongside the equip criterion.
> Confirm the entity id from JEI. Worth getting right: it is the one change that makes the pack's
> biggest overpayer *require* the pack's biggest underpayer.

**Fix 5 — `config/apotheosis/adventure.cfg`:**
- `Curse Boss Items = true` — the mod's own comment says "Enable this if you want bosses to be less
  overpowered." Free win.
- `Upgrade Level Cost = 50` (from **225**) and `Reroll Level Cost = 40` (from **175**).
  **This is the anti-variance fix and it matters more than it looks.** At 225 levels per upgrade,
  the only affordable path is building an Apothic Spawner farm — so the intended endgame loop is
  gated behind the thing that breaks the economy (§2.17). Cutting the cost decouples them and
  directly attacks the intra-mod RNG variance problem (two players, same hours, wildly different
  affix luck).
- `Enable Manual World Tier Changes = false` — stops one player skipping ahead.
- `Cleave Players = false` — already the default; keep it, six-player friendly fire is misery.

**Fix 6 — Apothic Attributes' Potion of Flying.** Creative flight, brewed, stackable, giftable,
30 minutes a bottle, all ingredients renewable. Post-dragon, which sounds gated until you notice it
then costs a phantom membrane and a chorus fruit forever. **There is no config toggle. Datapack
only** — override the brewing mix with an unobtainable ingredient (do **not** ship an empty file,
it throws on load):

`datapacks/apotheosis-parity/data/apothic_attributes/brewing_mixes/flying_from_levitation.json`
```json
{
  "input":      "minecraft:levitation",
  "ingredient": "minecraft:barrier",
  "output":     "apothic_attributes:flying"
}
```
Overriding just this one file breaks the whole chain, since `long_flying` and `extra_long_flying`
derive from it. **Better idea than deleting it:** change `ingredient` to a Cataclysm or Deeper and
Darker boss drop. Flight becomes a *reward* for a specific track instead of a byproduct — and under
Rule 5 that gives the exploration-heavy tracks a mobility payout they can advertise.

**Fix 7 — Apothic Attributes rewrote armor math pack-wide and nobody noticed.** Armor toughness no
longer reduces damage at all; the vanilla 20-armor cap is gone. Net effect: **mid-tier armor got
stealth-nerfed and endgame armor got stealth-buffed**, widening the exact gap this document exists
to close. Restore vanilla behaviour in `config/apotheosis/apothic_attributes.cfg`:
```
Armor Formula = 1 - min(max(armor - damage / (2 + toughness / 4), armor / 5), 20) / 25
```
(The vanilla expression is quoted in the config's own comment — copy it from there, not from here.)
Also add boss damage types to `apothic_attributes:cannot_critically_strike` so crit-stacking cannot
melt Cataclysm bosses.

---

### 2.6 🔴 Expanded Combat — **`R = 0.104` at iron tier. The audit says cut. I agree, with a caveat.**

The audit's §4.2 recommends cutting. The research supports that *for the weapons*, but the mod's
gauntlets, shields and quivers are genuinely good and carry none of the problems.

**The worst number is ranged, and the audit's melee-focused table missed it.** Netherite bow +
**gold** arrows ≈ 17–18 damage per shot, on renewable, recoverable ammo, at safe range, versus
vanilla's ~6. Gold arrows have *higher* base damage than diamond (4.0 vs 3.75) and gold is
infinitely renewable via bartering. `P = 2.9`, `R = 0.095`.

**Recommended: keep the mod, switch the weapons off.** One key:

`config/expanded_combat.json5` (Cloth AutoConfig; exact filename unconfirmed — check after boot)
```
enableWeapons = false
```
That removes the fourth redundant weapon ladder (you already have Simply Swords, Epic Knights and
Knaves' Needs competing for the same niche) and keeps a good support mod.

**If you keep weapons on**, these are the minimum edits — all verified config fields:

| Key | Default | **Set to** | Effect |
|---|---|---|---|
| netherite `arrowDamage` | 4.5 | **2.75** | kills the worst offender |
| netherite `velocityMultiplier` | 1.45 | **1.15** | ″ |
| gold `arrowDamage` | 4.0 | **2.25** | the *cheap* version was the worse one |
| Dancer's Sword `attackSpeed` | −1.8 | **−2.4** | 22.0 → ~16 DPS |
| Dagger `attackSpeed` | −1.2 | **−1.8** | breaks the dual-wield stack |

**Also empty the early treasure tables** — EC injects uniques into `shipwreck_treasure`,
`buried_treasure` and `underwater_ruin_big` at 5–10%. Those are hour-one-to-three structures, so a
netherite-adjacent weapon can land before anyone sees the Nether.

**Do NOT add "EC × L_Ender's Cataclysm Compat."** It builds EC shields, quivers and gauntlets out of
Ignitium, Cursium and Witherite — pulling Cataclysm's boss-gated materials into EC's cheap crafting
ladder. That is the exact inversion this document exists to prevent.

---

### 2.7 🔴 Simply Bows + Simply Swords — one config line fixes the worst of it

**Simply Swords — the Omen execute.** From `OmenEffect.java`:
```java
if (pLivingEntity.getHealth() <= pthreshold && pPlayer != null) {
    pLivingEntity.damage(DamageSource.GENERIC, 1000);
}
```
`pthreshold` = 25% of max health, fired at **75% chance per hit**, with **no boss check, no health
cap, no exclusions** — I read the file looking for them. This deletes the last quarter of every boss
in the pack: Cataclysm's eight, the Wither's 300 HP, the Ender Dragon, Mowzie's, Twilight Forest's,
Eternal Starlight's. It arrives on a **chest-loot warglaive with no progression gate.**

**One value in `config/simplyswords/*` (Cloth-generated; filename unconfirmed):**
```
omen_instantkill_threshold = 0        # from 0.25 — kills the execute outright
add_weapons_to_loot_tables = false    # stop diluting every modded structure chest
cutlass_attackspeed  = -2.3           # from -2.0; 16 DPS -> ~13
katana_attackspeed   = -2.3
twinblade_attackspeed = -2.3
```

`add_weapons_to_loot_tables = false` deserves its own note: it is `true` by default and injects into
"many modded structure chests," so every When Dungeons Arise, Twilight Forest, Aether, Undergarden,
Deeper and Darker and Cataclysm chest also rolls a generic Simply Swords weapon. **That dulls the
reward identity of the exact structure mods the campaign is built around.** Turning it off is a
buff to five other tracks disguised as a nerf to one.

**Simply Bows — `R = 0.103`, and it is a pure rate failure.** Per-arrow damage is *below* vanilla by
design; the problem is that a village or mineshaft chest hands you a named bow at **15%**, and
upgrade components drop at **20% per chest**. A melee player grinds 60–120 h toward a Unique; a
ranged player has a maxed kit in 10–25 h.

`config/simplybows/*` (Fzzy Config; filename unconfirmed):

| Key | Default | **Set to** |
|---|---|---|
| `loot.boostedBowChance` | 15.0 | **2.0** |
| `loot.baseUniqueBowChance` | 2.0 | **0.5** |
| `loot.baseStringChance` | 20.0 | **5.0** |
| `loot.baseFrameChance` | 20.0 | **5.0** |
| `upgrades.damageMultiplierPerFrame` | 0.55 | **0.25** |
| `general.enableNonPlayerBowUse` | true | **false** |
| `echoBow.chaosBlackHolePullStrength` | 0.09 | **0.03** |
| `echoBow.painExplosionBaseHpDamage` | 0.16 | **0.05** |

⚠ **`enableNonPlayerBowUse = true` is a stealth early-game difficulty spike** most people miss:
skeletons get unique bows and fire their abilities at 0.5× damage. Combined with Simply Entity
Equipment (which *does* hand skeletons modded bows) and Skeleton Uses Custom Bow (which makes those
bows actually fire their abilities), you get three mods compounding into homing echo arrows at
hour 3. Turn it off unless the group explicitly wants that.

> 🔍 **VERIFY BEFORE APPLYING** — `painExplosionBaseHpDamage` **may be percent-of-max-HP**. The key
> names strongly imply it (16% base, +6%/frame, 55% cap), but I could not find the implementation —
> those keys do not appear in `EchoBowItem.java`. If it *is* percent-max-HP, a chest-loot bow melts
> high-HP bosses proportionally and becomes the worst item in the batch. **Test in singleplayer
> against a 300 HP target before the server goes live.**

**Datapack is useless here.** Simply Bows injects loot in code (`SimplyBowsChestLootRules` walks
every `minecraft:chests/*` table), not through datapack loot tables. A loot datapack will silently
do nothing. **Budget config time, not datapack time.** The existing `datapacks/simplybows-parity/`
recipe pack is the right idea for the opposite reason — it converts RNG acquisition into a
deterministic craft, which fixes variance rather than rate. Keep both.

---

### 2.8 🔵 **BUFF** — L_Ender's Cataclysm. `R = −0.003`. The clearest defect in the pack.

**Print this sentence:** *Dan fights a 600 HP, 12-armor, knockback-immune boss for 40 hours and
receives a weapon that lowers his DPS.*

Void Forge and Infernal Forge are **13 damage @ 1.0 attack speed = 13 DPS**, against a Sharpness V
netherite sword's **18 DPS**. The mod author balanced against *unenchanted* netherite (8 damage) and
was correct to; your players are not carrying unenchanted netherite.

**Target under Rule 6 — buy the parity with speed, not damage.** `H = 40`, `T = 0.8`:
```
Target P = 1 + (0.015 × 40 × 0.8) = 1.48×  =  26.6 DPS
```
Getting there on the raw stat line alone would need 26 damage @ 1.0 — exactly the number the group
is afraid of. Don't. Split it: **raise attack speed to reach ~1.16× on the stat line, and let the
mod's own AoE ability carry the rest.** That respects both the anchor and the group's instincts.

`datapacks/parity-underreward/data/cataclysm/recipe/void_forge.json`
```json
{
  "type": "minecraft:smithing_transform",
  "template": { "item": "cataclysm:void_forge_upgrade_smithing_template" },
  "base":     { "item": "cataclysm:infernal_forge" },
  "addition": { "item": "cataclysm:void_core" },
  "result": {
    "id": "cataclysm:void_forge",
    "count": 1,
    "components": {
      "minecraft:attribute_modifiers": {
        "modifiers": [
          {
            "type": "minecraft:generic.attack_damage",
            "id": "minecraft:base_attack_damage",
            "amount": 15.0,
            "operation": "add_value",
            "slot": "mainhand"
          },
          {
            "type": "minecraft:generic.attack_speed",
            "id": "minecraft:base_attack_speed",
            "amount": -2.6,
            "operation": "add_value",
            "slot": "mainhand"
          }
        ]
      }
    }
  }
}
```
`amount: 15.0` on `attack_damage` displays as **16 damage** (player base 1.0 is added), and
`-2.6` on `attack_speed` gives **1.4 speed** → **22.4 DPS = 1.24×**. With the void-rune AoE counted
as utility, that lands at roughly the 1.48× target. **Under the 13-damage-@-1.0 North Star ceiling
in spirit** — you spent the budget on speed.

> 🔍 **VERIFY BEFORE APPLYING** — item ids (`cataclysm:void_forge`, `:infernal_forge`, `:void_core`,
> `:void_forge_upgrade_smithing_template`) are all **unconfirmed**. Pull them from JEI. Also confirm
> the real recipe *type* — if the Mechanical Fusion Anvil uses a custom recipe type rather than
> `minecraft:smithing_transform`, this override will not bind and you must copy the mod's own
> recipe JSON and edit only the `result` block.

**Do the same for Infernal Forge** (`amount: 14.0`, `-2.7` → 15 dmg @ 1.3 = 19.5 DPS = 1.08×) and
note that it keeps unbreakable + pickaxe + shield-break, which is where the rest of its value lives.

**Second, cheaper lever with the same effect:** Better Combat weapon attributes. Cataclysm weapons
can be given a better combo profile without touching their stat line at all —
`data/cataclysm/weapon_attributes/void_forge.json` inheriting `bettercombat:claymore` with a
`damage_multiplier` above 1.0 on the finisher. Cheaper to author and it does not interact with
Apotheosis affix scaling. **Prefer this if the recipe override proves fiddly.**

---

### 2.9 🟡 Iron's Spells — **measure `H` before you tune. Then fix Angel Wings regardless.**

`R = 0.035` at `H = 45`, which is 2.3× the anchor — inside the "soft edge" zone from §1.3 and
therefore **not actionable yet**. But Doc 00 §0.5.3 flags that Doc 00 says `H = 45` and the old Doc
01 said `H = 25`, and nobody measured. At `H = 25` the rate is **0.064** — over four times the
anchor, and firmly actionable. **A 1.8× disagreement on `H` is the difference between "leave it" and
"emergency."** Measure it (§6.5) before spending an evening here.

**Angel Wings needs fixing either way — it is a Rule 3 deletion, not a rate problem.**
Level 5: 120 s cooldown, duration = `spellPower × 20` ticks. A Priest set (+40% Holy, +20% general)
pushes ~50 s to **~84 s**, while Ancient Codex (+20% CDR) + Ring of Recovery (+15%) cuts the
cooldown to **~78 s**. **Uptime exceeds downtime: that is functionally permanent flight**, in any
dimension, with no End City raid and no firework economy.

It devalues *every* exploration track at once — Aether, Twilight Forest, Deeper and Darker,
Undergarden, Eternal Starlight, Aquamirae, When Dungeons Arise — and it does so for whichever two
players picked magic, while the other four are still walking. Under Rule 5 that is an axis
violation as well as a rate one.

As of v3.15.0 spell parameters are datapack-driven and **datapacks override the global config
entirely** — so pick one surface and commit; do not split settings across both.

`datapacks/ironsspells-parity/data/irons_spellbooks/irons_spellbooks_spell_config/angel_wings.json`
```json
{
  "max_level": 2,
  "cooldown_in_seconds": 400,
  "power_multiplier": 0.6
}
```
That is ~30 s of flight on a ~400 s cooldown after CDR — a real mobility *tool*, not a replacement
for the Elytra.

**Also worth doing:**
- `config/irons_spellbooks-server.toml` → `maxUpgrades = 2` (from 3). Single best global power dial.
- `manaRegenMultiplier = 0.7` — makes mana an actual resource.
- `additionalWanderingTraderTrades = false` — removes the hour-one shortcut into magic gear.
- `priestHouseWeight = 0` — there is a known TPS problem here.
- Buff the Dead King (500 HP) and Tyros (1000 HP) via the per-boss `additionalHealth` blocks.
  **500 HP dies very fast to six people**, and every boss stat in this pack was tuned for one player.
- `scrollMerging = false` — stops junk scrolls being laundered into good ones.
- Raise `min_rarity` on **Portal**, **Recall** and **Summon Ender Chest**. Portal and Recall
  compete directly with Waystones; Summon Ender Chest quietly guts both backpack mods.

---

### 2.10 🔵 **BUFF + one urgent nerf** — Twilight Forest

**The buff.** `R ≈ 0.000` at 45 hours. Fiery Sword is **8 damage @ 1.6 = exactly a netherite sword**,
plus free 15-second ignite. Yeti armor is a dead-on netherite clone (20 armor / 12 toughness). Every
TF armor material has **0.0 knockback resistance** in source, so netherite keeps a real edge. After
45 hours a player is at parity with the gear they started with.

The on-disk `datapacks/parity-underreward/.../equipment/fiery_sword.json` is the right idea. Target
under Rule 6 (`H = 45`, `T = 0.8`): `P = 1 + 0.015 × 36 = 1.54×` = 27.7 DPS.

```json
{
  "type": "minecraft:crafting_shaped",
  "category": "equipment",
  "key": {
    "#": { "item": "twilightforest:fiery_ingot" },
    "/": { "item": "minecraft:stick" }
  },
  "pattern": [ "#", "#", "/" ],
  "result": {
    "id": "twilightforest:fiery_sword",
    "count": 1,
    "components": {
      "minecraft:attribute_modifiers": {
        "modifiers": [
          { "type": "minecraft:generic.attack_damage", "id": "minecraft:base_attack_damage",
            "amount": 10.0, "operation": "add_value", "slot": "mainhand" },
          { "type": "minecraft:generic.attack_speed", "id": "minecraft:base_attack_speed",
            "amount": -2.3, "operation": "add_value", "slot": "mainhand" }
        ]
      }
    }
  }
}
```
11 damage @ 1.7 speed = **18.7 DPS**, plus the 15 s ignite (~15 extra damage per hit on anything not
fire-immune) → roughly the 1.54× target once burn is counted. **Note this override strips the free
Fire Aspect II the vanilla item ships with** — if you want to keep it you must re-add the
`minecraft:enchantments` component, or the "buff" is a net nerf. Check the tooltip.

**The urgent nerf — the Uncrafting Table.** This is a **pack-wide** Rule 3 deletion and it is by far
the most dangerous thing in this mod. It reverse-crafts generically off the recipe graph, so it
applies to **all 150 mods**: decompose a cheap craft into expensive components, bypassing recipe
gating for Apotheosis, Ars Nouveau, Iron's Spells, Epic Knights and Cataclysm. It also has a long
documented history of *actual duplication bugs* (TeamTwilight #582, #2362; FTB Revelation 2 #132 —
diamonds duped 7× and nether stars doubled for 2 XP levels; ATM-6 #3175). Modpacks routinely
disable it outright.

`config/twilightforest-common.toml` → **UNCRAFTING** section:
```
disableUncraftingOnly = true          # keeps repair + disenchant, kills reverse-crafting
uncraftingXpCostMultiplier = 10.0
allowShapelessUncrafting = false      # already default; keep it
flipUncraftingModIdList = true        # turns the blacklist into an ALLOWLIST
blacklistedUncraftingModIds = ["twilightforest"]
```
`flipUncraftingModIdList = true` is the important one — **allowlist, not blacklist.** In a 150-mod
pack you cannot enumerate what to exclude, so invert the logic and permit only TF's own items.

**Also set** `multiplayerFightAdjuster = MORE_HEALTH` (not `MORE_LOOT`). Six players melt a TF boss
designed for one; `MORE_LOOT` would inflate the giftable pool and make the ÷6 problem worse.

**And tag the Glass Sword out of Apotheosis.** 40 damage, 1 durability, and a GLASS material
enchantment value of **30** — triple diamond's. Self-limiting until someone lands Unbreaking,
Mending, or an Apotheosis unbreakable affix, at which point it is a permanent ~64 DPS weapon
(FTB-Modpack-Issues #10819 exists on exactly this). The issue title cuts both ways — it suggests the
shatter may be hardcoded and the exploit currently fails — but it proves players try it.
**Cheap insurance, do it anyway:**

`datapacks/apotheosis-parity/data/apotheosis/tags/item/affix_blacklist.json`
```json
{ "replace": false, "values": ["twilightforest:glass_sword"] }
```
> 🔍 **VERIFY BEFORE APPLYING** — the affix-exclusion tag id is unconfirmed. Find the real one in
> the Apotheosis stock datapack's `tags/` directory.

---

### 2.11 🔵 **BUFF + one nerf** — Eternal Starlight

**The buff.** `R = −0.006` after ~55 hours, **post-Ender-Dragon.** Moonring Greatsword is 10.5 dmg @
1.2 = **12.6 DPS**; Unrealium — the wiki's "strongest material" — produces a sword of *exactly*
8 damage / 1.6 speed, byte-identical to netherite. Starlit Diamond armor is exactly netherite
(20 armor / 3.0 toughness / 0.1 KB). **A post-End track that pays netherite parity is the purest
Rule 2 violation on the list.**

Target (`H = 55`, `T = 0.9`): `P = 1 + 0.015 × 49.5 = 1.74×` = 31.3 DPS.

```json
{
  "type": "minecraft:crafting_shaped",
  "category": "equipment",
  "key": {
    "#": { "item": "eternal_starlight:moonring_ingot" },
    "/": { "item": "minecraft:stick" }
  },
  "pattern": [ "#", "#", "/" ],
  "result": {
    "id": "eternal_starlight:moonring_greatsword",
    "count": 1,
    "components": {
      "minecraft:attribute_modifiers": {
        "modifiers": [
          { "type": "minecraft:generic.attack_damage", "id": "minecraft:base_attack_damage",
            "amount": 15.0, "operation": "add_value", "slot": "mainhand" },
          { "type": "minecraft:generic.attack_speed", "id": "minecraft:base_attack_speed",
            "amount": -2.2, "operation": "add_value", "slot": "mainhand" }
        ]
      }
    }
  }
}
```
16 damage @ 1.8 = **28.8 DPS = 1.60×**, plus the Lunar Thorns proc → ~1.74×. ✅

> 🔍 **VERIFY BEFORE APPLYING** — `moonring_ingot` is a guess; the real recipe may use a different
> reagent entirely. Copy the mod's own recipe JSON and change **only** the `result` block.

**The nerf — Starfall Longbow.** One arrow summons **9 Aethersent Meteors directly onto the hit
entity**, and natural meteors deal **50 damage each, ignoring invulnerability frames.** Composite
~450 single-target burst per arrow. Both component numbers are wiki-verified; the composite is
inference, so **test it** — but the direction is not in doubt.

⚠ **The config key that looks like the fix is not the fix.** `playerAethersentMeteorDamageScale`
(default 1) is scoped, by its name, to damage dealt **to players**. It will not touch meteor damage
against mobs. There is no config lever. Datapack-remove the recipe (same barrier-ingredient pattern
as §2.1) or accept a boss-deleter.

**Third — the pre-dragon ambush, a playability bug rather than a balance one.** The Gatekeeper
(175 HP, 15 armor) auto-spawns within 50 blocks of any Portal Ruin and per the wiki **cannot be
defeated before the Ender Dragon dies.** Portal Ruins are five separate structure sets at
spacing 36 / separation 30 in plains, desert, forest, snowy and jungle — i.e. dense, in exactly the
biomes people settle. **Six players scouting Waystone and Minecolonies sites will absolutely walk
into an unkillable boss.** Set `enableBossRespawn = false` and investigate
`GatekeeperConfig.canAlwaysHurtWhenFighting`, or thin the Portal Ruin structure sets by datapack.

Also set `bossRespawnCooldown` much higher than 36000, or six players will farm boss loot.

---

### 2.12 🔵 **BUFF** — The Undergarden. `R = −0.015`, the worst rate on the list after Paradise Lost.

**Every single weapon in this mod is at or below a netherite sword.** Best sustained DPS is the
Utherium sword at 7.5 @ 1.6 = **12.0 DPS** (baseline 18.0). The highest single hit is the Forgotten
Battleaxe at 11.0 — but at 0.6 attack speed that is **6.6 DPS**, barely a third of baseline.
Meanwhile Utherium *armor* is 20 armor / 3.0 toughness, i.e. netherite parity, reachable in 8–12 h
**without ever entering the Nether**. So the mod simultaneously under-rewards on offence and
shortcuts on defence. Both need fixing, in opposite directions.

⚠ **The on-disk override is insufficient.** `datapacks/parity-underreward/.../utherium_sword.json`
currently sets `amount: 8.0` → 9 damage @ 1.6 = **14.4 DPS = 0.80×**. Still below baseline. It is a
buff that does not reach parity, which is the worst of both worlds — you have spent the political
capital of "we buffed it" and Dan still feels robbed.

**Corrected targets** (Rule 6 — speed, not damage):

| Item | Track depth | `H` | `T` | Target `P` | **Set `amount` / speed** | Result |
|---|---|---|---|---|---|---|
| Utherium Sword | mid | 12 | 1.1 | 1.20× | `10.0` / `-2.0` | 11 dmg @ **2.0** = **22.0 DPS = 1.22×** ✅ |
| Forgotten Sword | deep | 25 | 1.1 | 1.41× | `11.0` / `-1.9` | 12 dmg @ **2.1** = **25.2 DPS = 1.40×** ✅ |

```json
{
  "type": "minecraft:crafting_shaped",
  "category": "equipment",
  "key": {
    "#": { "item": "undergarden:utherium_crystal" },
    "/": { "tag": "c:rods/wooden" }
  },
  "pattern": [ "#", "#", "/" ],
  "result": {
    "id": "undergarden:utherium_sword",
    "count": 1,
    "components": {
      "minecraft:attribute_modifiers": {
        "modifiers": [
          { "type": "minecraft:generic.attack_damage", "id": "minecraft:base_attack_damage",
            "amount": 10.0, "operation": "add_value", "slot": "mainhand" },
          { "type": "minecraft:generic.attack_speed", "id": "minecraft:base_attack_speed",
            "amount": -2.0, "operation": "add_value", "slot": "mainhand" }
        ]
      }
    }
  }
}
```
Note **11 damage @ 2.0 reads as reasonable** where 22 damage @ 1.0 would read as broken, at
identical DPS. That is Rule 6 doing its job.

**The counterpart nerf — gate the entry.** Utherium armor at netherite parity without a Nether trip
is a shortcut past a vanilla progression step. The portal Catalyst is craftable early; add a
Nether-only ingredient:

`datapacks/undergarden-gate/data/undergarden/recipe/catalyst.json` — add `minecraft:blaze_rod` or
`minecraft:ancient_debris` to the existing pattern. **One file moves the whole mod from
"skips the Nether" to "post-Nether", which resolves its only over-reward issue.**

**Config is nearly useless here** — `UndergardenConfig` exposes exactly four keys and none touch
balance (portal frame block, fog toggle, infection overlay, infection number display). Datapack is
the only real lever, which is why this mod gets more JSON than most.

---

### 2.13 🟡 Knaves' Needs — **one line fixes it, and that line also fixes Simply Swords**

`R = 0.005` — below the floor, but that is not the real problem. Knaves adds **zero new gate**;
every weapon costs exactly what the host mod's own sword costs. The defect is that at each
already-earned tier it hands you a **strictly better** weapon than the host mod's own:

| Host mod's weapon | Knaves' reskin | Delta |
|---|---|---|
| D&D Warden Sword — 9 @ 1.6 = 14.4 DPS | Warden Katana — 10 @ 2.0 = **20.0 DPS** | **+39%**, same Reinforced Echo Shard cost |
| TF Fiery Sword — 8 @ 1.6 = 12.8 DPS | Fiery Katana — 8 @ 2.0 = **16.0 DPS** | **+25%** |
| Undergarden Utherium — 7.5 @ 1.6 | Utherium Katana — 8.5 @ 2.0 = **17.0 DPS** | **+25%** |

**Root cause: this is inherited Simply Swords balance, not a Knaves invention.** The
katana/twinblade/cutlass shapes get **2.0 attack speed with a 0.0 damage penalty** — a free +25% DPS
over the longsword shape at every tier, in every mod Knaves touches.

**The one edit, and it is high-leverage:** Knaves reads Simply Swords' *own* config file directly
(`KnavesSimplyConfig.loadConfig()` parses it and only fills gaps with `putIfAbsent`). So editing
`config/simplyswords/weapon_attributes.json5` retunes **Simply Swords AND all 520 Knaves weapons
simultaneously**:
```
katana_attackspeed    = -2.4     # from -2.0
twinblade_attackspeed = -2.4
cutlass_attackspeed   = -2.4
```
That removes the "strictly better than the host mod's sword" property across Twilight Forest, The
Undergarden, Deeper and Darker and Simply Swords itself, in three lines. **Do this whether or not
you keep Knaves** — Simply Swords alone has the same defect (§2.7).

**Separately, and more decisive than any of the above: the version risk.** Knaves is beta-only on
1.21.1, no stable release in ~3 years, 513 downloads, source unpublished, one jar spanning eleven
MC versions, registering **520 items**. On a months-long shared campaign, a mod that registers 520
items and then renames them on update means **mass item loss for everyone who invested in them.**
That is a worse outcome than any DPS number here. My call: **cut it** — you already have three
weapon ladders competing for the niche.

---

### 2.14 ⚪ Ars Nouveau — **`R = −0.009` and that is FINE. Do not "fix" it.**

The negative rate is a **Rule 5 axis artefact, not a defect.** Ars Nouveau's damage ceiling is ~19
(Flare, fully amplified, max Spell Damage thread) because **every damage glyph hard-caps Amplify at
2 by default.** That cap is doing your balance work for free — leave it alone. The mod's real
payout is utility, automation and logistics, and it is genuinely good at it.

Its own sword is *byte-for-byte a netherite sword* (`new EnchantersSword(Tiers.NETHERITE, 3, -2.4F)`)
and its best armor has **zero toughness**. So an Ars player at 50 hours is a glass cannon standing
next to a Cataclysm player who shrugs off the hit that kills them. **That is the axis-mismatch
problem in §1.9 and the fix is disclosure (§4), not numbers.**

**Two things do need attention:**

**1. The Drygmy — a Rule 3 deletion.** It passively converts penned, living mobs into their
loot-table drops with zero combat. Every combat mod on the list (Cataclysm, Mowzie's, Alex's Caves,
Aquamirae, Macabre, Cult of Azazel) balances its crafting materials around *killing the mob being
the cost*. A Drygmy pen turns that cost into an afternoon of building, and the output is fully
tradeable so one player supplies all six. **This is the ÷6 problem in its purest form.**

`datapacks/ars-parity/data/ars_nouveau/tags/entity_type/drygmy_blacklist.json`
```json
{
  "replace": false,
  "values": [
    "cataclysm:netherite_monstrosity", "cataclysm:ender_guardian",
    "cataclysm:ancient_remnant", "cataclysm:ignis", "cataclysm:the_leviathan",
    "cataclysm:harbinger", "cataclysm:maledictus", "cataclysm:the_scylla",
    "mowziesmobs:frostmaw", "mowziesmobs:umvuthi", "mowziesmobs:ferrous_wroughtnaut",
    "deeperdarker:stalker", "eternal_starlight:the_gatekeeper"
  ]
}
```
> 🔍 **VERIFY BEFORE APPLYING** — every entity id above is my best guess. Pull the real ones from
> JEI or `/summon` tab-completion. There is also a `DrygmyLootCondition` you can reference inside
> other mods' loot tables to exclude specific *entries* while keeping the mob farmable.

Also soften the rate in `config/ars_nouveau-common.toml`:
```
drygmyUniqueBonus = 0        # from 2 — kills the "5 mob types = 16 items/cycle" stack
drygmyManaCost    = 3000     # from 1000
drygmyMaxProgress = 40       # from 20
```

**2. Warp Portals vs Waystones — pure functional overlap.** The Stable Warp Scroll builds permanent
two-way portals at Nether tier, no waystone discovery, no per-use cost. **Pick one:**
```
[warp_portals]
enableWarpPortals = false
```

**Also:** `spawnBook = false` (currently the mod *hands* every player its entry item on first login
— free entry is fine, but a track that starts in your inventory is not a choice), `spawnTomes =
false` (stops pre-made Caster Tomes generating in When Dungeons Arise loot), and leave
`enforceCapOnCast` / `enforceGlyphLimitOnCast` **true** — turning them off removes the Amplify cap
that is doing all your balancing.

**Ars Elemental** ships one genuine outlier: **Heavy Elemental armor at 25 armor / 16 toughness**,
which beats full netherite on *both* stats. The mage track ending up tankier than the knight track
inverts two tracks at once. ⚠ **The armor values are NOT config-exposed and NOT datapack-reachable**
(baked into `AAMaterials.java`) — fixing them needs KubeJS. The practical alternative is to raise
the recipe cost via `sourceCost` in `data/ars_elemental/recipe/`, and to drop the Mark of Mastery
recipe's `count: 5` to `1` — **five Marks per Chimera kill means the gate is paid once for the whole
group**, which is Rule 4 again.

**Ars 'n Spells: 🟢 keep, but set `mana_mode = separate`.** The audit calls it mandatory
infrastructure and that is right *if* you run both magic mods. But its default `iss_primary` mode
plus `spell_power_cap = 3.0` lets Iron's gear **triple** Ars potency and lets Apotheosis affix RNG
drive Ars spell damage — collapsing two parallel tracks into one shared pool, which is the exact
opposite of this pack's premise. `separate` keeps the compatibility and drops the collapse. Also
set `source_jar_synergy_multiplier = 1.0` (from **5.0**) — at 5.0, an automatable Ars source farm
feeds Iron's mana pool and deletes Iron's single most important balancing constraint.

---

### 2.15 🔵🔴 Paradise Lost — **`R = −0.025`, worst on the list, AND an uncapped scalar. Recommend CUT.**

Both failure modes in one mod, which is unusual and decisive.

**Under-reward:** the craftable ceiling is **16 armor points with 0.0 toughness** (netherite: 20 /
12) and an **8-damage** sword. That is worse than netherite on defence and equal on offence, after
15–25 hours, in a dimension with **no bosses** to make the effort tense. `P = 0.44`.

**Over-reward:** the **Soul Blade**. `SoulSwordItem.getBonusAttackDamage()` returns
`super.getBonusAttackDamage(...) + (getSoulCount(itemStack) * 0.25F)`, where a "soul" is each
**distinct EntityType** ever killed with it. **No cap. No diminishing returns. No config.** The devs
balanced for vanilla+PL (~50 types → 16 damage, fine; there is even an advancement at 50 souls).
In a 150-mod pack containing Cataclysm, Mowzie's, Jurassic Reborn, Twilight Forest, Undergarden,
Deeper and Darker, Aquamirae, Grim and Bleak, Macabre, Incision and Cult of Azazel, the distinct
entity count is plausibly **250–500** → **60–90 attack damage.**

*(The 250–500 estimate is mine and unmeasured. The uncapped `* 0.25F` scalar is verified source.)*

**Its power is a function of how many mods you install**, and the incentive it creates is perverse
for exactly this group: **the more of the other five tracks the party plays, the stronger this one
sword gets.** A player can farm it by tagging along on everyone else's content. It requires no boss,
no dungeon, no gate — just killing one of everything, once.

**No datapack can fix it.** The scalar is a Java method override — not a config value, not a
component default, not a tag. Options: (a) delete the recipe and every loot entry so it never
enters the world, (b) remove the item with a tweaker mod, (c) cut Paradise Lost.

**And there is no config file.** I searched the entire 3,516-file tree; the only `*Config.java`
files are worldgen feature records. Cloth Config is a declared dependency (which normally implies a
screen exists), so I may have missed one — but I could not find it, and the official wiki returns
HTTP 403.

**Recommendation: cut.** It is a second skylands dimension sitting next to The Aether, which does
the same thing better and has actual bosses. Under-rewards on the honest path, has an unfixable
outlier on the dishonest one, and no config surface to mediate. On a pack already carrying Twilight
Forest, Undergarden, Deeper and Darker, Eternal Starlight and The Aether, this is the marginal
dimension nobody has hours left for.

---

### 2.16 🔴 Epic Knights — **the ÷6 rule's worst case. `H = 2` becomes `H = 0.33`.**

**Steel = one iron ingot smelted in a blast furnace.** The mod's entire top-tier plate line and its
highest-burst two-handed weapons unlock in the **iron age, pre-Nether, pre-diamond.**

**The real defect is not the 12.74-damage steel halberd — it is knockback resistance.** Every plate
set carries **0.5 knockback_resistance PER PIECE** (jousting/stechhelm carry **1.5**) against
netherite's 0.1. The vanilla attribute clamps at 1.0 = total immunity, so **two pieces of steel
knight plate grant 100% knockback immunity at roughly hour 2.** Full netherite grants 40%.

Knockback immunity is not a stat, it is a **mechanic deletion**: it removes creeper displacement,
skeleton chip-and-shove, ledge knockoffs, and — the part that matters — **the knockback phases of
every modded boss** (Cataclysm, Mowzie's, Saint's Dragons). A single `magistuarmory:stechhelm` at
1.5 exceeds the cap on its own.

**Fix — config, `config/epicknights/`** (five sections: `general`, `weapons`, `shields`, `armor`,
`mobEquipments`). Every number in this section is a live config value, which is why this is a tuning
job and not a cut.

**The single highest-value change in this mod:** set `knockbackResistance` to **0.10** on every
armor set and **0.0** on `stechhelm` / `jousting`. That alone converts the mod from "deletes an
axis" to "slightly tanky."

Then:
```
disableAttackReach = true                 # until you've tested reach stacking with Better Combat
```
Pike/Ranseur/Guisarme/Giant Lance carry `ENTITY_INTERACTION_RANGE` bonuses up to **+3.0**, doubling
the player's 3.0-block melee reach to **6.0**. Better Combat *also* handles attack range. Whether
they stack is untested — **a 6-block-reach pike would let a player out-range most melee bosses
entirely.** Test before enabling.

Also drop `defenseForSlot` by 1–2 per slot on knight/gothic/maximilian/jousting so no *steel* kit
matches netherite, and shave `baseAttackDamage` on `club` (7.00), `lochaberAxe` (7.00) and
`concaveEdgedHalberd` (7.30).

**Better: move the gate with a datapack, one file.** Everything content-side is plain JSON under
`data/magistuarmory/`. Replace the iron-ingot-in-a-blast-furnace steel recipe with one requiring a
Nether reagent:

`datapacks/epicknights-gate/data/magistuarmory/recipe/steel_ingot.json`
```json
{
  "type": "minecraft:smelting",
  "category": "misc",
  "ingredient": { "item": "minecraft:netherite_scrap" },
  "result": { "id": "magistuarmory:steel_ingot", "count": 2 },
  "experience": 1.0,
  "cookingtime": 200
}
```
> 🔍 **VERIFY BEFORE APPLYING** — confirm the real steel recipe id and whether it is
> `minecraft:blasting` rather than `minecraft:smelting`. **Alternative and arguably better:** retag
> `c:plates/steel` so plates require a gated intermediate — that rewrites *every* armor recipe at
> once without touching them individually.

⚠ **Audit your other steel sources.** Steel registers under the common `c:ingots/steel` tag. Any
*other* mod adding a cheaper `c:ingots/steel` silently becomes an alternate, cheaper gate into Epic
Knights' entire plate line. And because steel is 1:1 smelted iron, **a single iron farm
mass-produces the mod's near-best gear for all six players indefinitely** — Rule 4, again.

---

### 2.17 🔴 Apothic Spawners + Gateways to Eternity — **a combo neither mod causes alone**

Individually: medium risk. Together: **an infinite Nether Star engine, reachable in 8–15 hours.**

**The chain, every link verified:**
1. Gateways' `hellish_fortress` pearl costs **one wither skeleton skull**.
2. The gateway is 4 waves whose hardest enemy is a ~100 HP piglin brute. `GateRules` defaults
   `lives` to **−1** — infinite player deaths allowed; it can only be failed on the timer.
3. Completion reward includes `{"type":"gateways:stack","stack":{"id":"minecraft:spawner", …
   "SpawnData":{"entity":{"id":"minecraft:wither_skeleton"}}}}` — **a Wither Skeleton Spawner.**
4. Apothic Spawners makes that spawner run at 1 spawn cycle/second, 16 spawns per cycle, 32 nearby,
   mobs at 20% HP, no player needed, **4× loot and 4× XP** (Echoing III).
5. → infinite wither skulls → infinite Withers → **infinite Nether Stars** → permanent beacons for
   all six players, **plus infinite `Ignore Players` modifiers for every other spawner.**

**One skull in, infinite skulls out.**

**Fix 1 — delete the spawner reward. Highest-value single change of the pair.**
`planning/datapacks/pack-balance/data/gateways/gateways/hellish_fortress.json` — remove the
`gateways:stack` spawner entry from the top-level `rewards` array. *(A file is already on disk at
this path — confirm the entry is actually gone, not just re-weighted.)*

**Fix 2 — `config/apothic_spawners.cfg`:**
```
Spawner Silk Level   = -1      # disables spawner harvesting entirely; kills ~80% of the risk
Spawners Drop Empty  = true    # OR this instead: keeps the mechanic, re-gates it behind Capturing
Entity Despawn Delay = 200     # perf
```
`Spawners Drop Empty = true` is the better middle ground if the group likes spawner-moving — a
harvested spawner loses its mob type, so you must re-type it with a Capturing egg.

**Fix 3 — cap the modifiers.** Every one is a recipe at
`data/apothic_spawners/recipe/spawner_modifiers/<stat>.json`, with a parallel `_inverse/` folder
that **must be edited to match** or players can reverse past your caps:

| Modifier | Item | Ship default | **Set** |
|---|---|---|---|
| `echoing` | echo shard | max 3 (4× loot **and** 4× XP) | **max 1** |
| `min_delay` | sugar | min 20 ticks | **min 100** |
| `max_delay` | clock | min 20 | **min 100** |
| `spawn_count` | fermented spider eye | max 16 | **max 6** |
| `max_nearby_entities` | ghast tear | max 32 | **max 10** |

*(The on-disk `pack-balance` pack already has `echoing.json` at `max: 2` — take it to 1, and check
that `_inverse/echoing.json` matches.)*

**Fix 4 — the blacklist tag.** It currently contains **only**
`["minecraft:warden", "minecraft:elder_guardian", "#c:bosses"]`. Every non-boss modded elite from
Cataclysm, Mowzie's, Aquamirae etc. is farmable **unless that mod self-tags into `#c:bosses`, which
I could not verify for any of them.** Do not assume:

`datapacks/pack-balance/data/apothic_spawners/tags/entity_type/blacklisted_from_spawners.json`
```json
{
  "replace": false,
  "values": [
    "cataclysm:netherite_monstrosity", "cataclysm:ender_guardian", "cataclysm:ignis",
    "cataclysm:ancient_remnant", "cataclysm:the_leviathan", "cataclysm:harbinger",
    "mowziesmobs:frostmaw", "mowziesmobs:umvuthi", "mowziesmobs:ferrous_wroughtnaut",
    "deeperdarker:stalker", "eternal_starlight:the_gatekeeper", "twilightforest:hydra",
    "twilightforest:naga", "twilightforest:lich", "twilightforest:ur_ghast"
  ]
}
```

**Fix 5 — Gateways has NO config file at all.** Verified: no config class in the repo, no `.cfg`,
no config `.toml`. **100% of tuning is datapack.** Download the stock datapack (generated per
release since 5.1.0) and set, on every gateway:
```json
{ "lives": 3, "spacing": 128, "player_damage_only": true, "requires_nearby_player": true }
```
`lives: 3` makes death cost something. `player_damage_only` + `requires_nearby_player` block
AFK/turret-farming. `spacing: 128` stops concurrent-gateway lag.

**Also — and this is the under-reward half, flagged with equal priority:** `emerald_grove` pays
**16 hay blocks, 96 saplings and 24 farm animals** for a 4-wave fight behind a mid-game pearl. Two
players pick Emerald Grove, two pick Hellish Fortress, identical effort — one pair gets farm
animals, the other an infinite wither skeleton farm. **That is this group's stated fear reproduced
inside a single mod.** Buff `emerald_grove`'s rewards substantially or delete it; as written it is
a trap.

**Waves do not scale with player count.** Either add ~50% to every wave `count` or ship a
six-player variant of each gateway.

---

### 2.18 🟡 The Aether — front-loaded over-reward, back-loaded under-reward

Two problems in opposite directions, which is why it is 🟡 and not 🔴.

**Front-loaded:** Bronze dungeon `structure_set` is **spacing 6 / separation 5** — roughly one every
~96 blocks of Aether island, ~5× denser than vanilla villages. The Slider (400 HP) is a slow crush
puzzle, not a DPS check, so it is farmable in diamond gear. Its chest can roll a **Valkyrie Lance**
(+3.5 reach → **6.5-block melee**, a Rule 3 deletion — it out-ranges most melee bosses entirely),
a Flaming Sword, a Phoenix Bow, a Cloud Staff, an Agility Cape and Neptune armor. **A pair entering
at hour 4 can be better-equipped by hour 8 than a pair grinding Cataclysm.**

`datapacks/aether-parity/data/aether/worldgen/structure_set/bronze_dungeon.json` — raise `spacing`
from **6 to 20** and `separation` to **12**. *(This also cuts Aether chunkgen cost, which matters on
a 32 GB box hosting a gaming rig.)*

Then strip the Lance from the Bronze pool —
`data/aether/loot_table/chests/dungeon/bronze/bronze_dungeon_treasure.json`, remove
`aether:valkyrie_lance` (weight 1 of 6). ⚠ **The +3.5 reach is baked into the item's default
attribute modifiers in Java** and cannot be datapacked away, so removing it from loot is the only
clean fix short of KubeJS.

**Back-loaded:** gear caps at **netherite parity and never exceeds it** — best sword 7 damage
(netherite is 8), best armor 20 points / 3.0 toughness (netherite exactly), **zero knockback
resistance across every material.** After hour ~25 the curve is flat.

**But the Aether is not actually under-rewarding**, because its real payout is **Life Shards**:
+2.0 max health each, config cap 10 → **20 HP → 40 HP**, `P = 2.00` on the survivability axis at
`H = 40`, `R = 0.028` — **inside the band.** That is a genuinely well-designed reward and it is
÷6-proof (consumed on use, Gold Dungeon only, no recipe). **Copy this pattern elsewhere.**

Set `"Maximum consumable Life Shards"` to **6** rather than 10 if 40 HP feels like too much (it
halves the threat of every boss tuned against 20 HP). Also set `"Only whitelisted users access Sun
Altars" = true` — on a shared world, one person should not flip the day/night cycle for six.

**Phoenix armor's permanent `clearFire()`** is a Rule 3 deletion: it removes the Nether's fire
pressure and flatly deletes the fire mechanic of Cataclysm's **Ignis**. Gate it or accept it; it is
at least behind real dungeon progression.

**The Altar** repairs *vanilla* diamond gear with no XP cost and no anvil prior-work penalty
(`diamond_sword_repairing.json`, `bow_repairing.json`, etc. all ship). That undercuts Apotheosis's
gear economy. **Delete the non-Aether repairing recipes; keep the Aether ones.**

**Aether II: not installable.** Earliest build targets 1.21.8. Treat Aether and Aether II as
mutually exclusive regardless — same team, same dimension, same Slider, same tier ladder.

---

### 2.19 🟡 Better Combat — not a track, but it changes the floor for everyone

Single-target damage is **exactly 1.00×** — every bundled preset's `damage_multiplier` is ≤ 1.4 and
combos average ~1.0. It creates no player-vs-player parity gap. But it creates three distortions:

**1. Crowd content deletion.** `reworked_sweeping_extra_target_count = 4` means one swing hits up to
5 entities, and **Sweeping Edge removes the damage penalty entirely.** A Sharpness V netherite sword
goes from ~11.25 per swing to **up to 56**. That is a 3–5× crowd-DPS multiplier, and it compresses
Cataclysm arena waves, When Dungeons Arise dungeons, Cult of Azazel groups and Mowzie's packs — all
tuned around vanilla single-target melee.

**2. Melee vs caster.** It hands melee free reach and free cleave — exactly what Iron's Spells and
Ars Nouveau charge 30+ hours of research, mana and ritual progression to obtain. A Rule 5 violation
delivered for free.

**3. The subtle one — accidental weapon-mod tiering.** `fallback_compatibility_enabled = true`
auto-assigns generic attributes to weapons the mod does not know. **Simply Swords is an official
partner and gets hand-tuned combos and reach; Epic Knights, Antarchy and Expanded Combat weapons may
land on generic fallbacks.** Two players who invest equal hours in two different weapon mods end up
with meaningfully different reach and combo quality **for reasons neither of them chose.** That is
this group's exact failure mode, arriving through a compatibility layer nobody thought about.

`config/bettercombat/server.json5`:
```
reworked_sweeping_extra_target_count = 2      # from 4
server_target_range_validation       = true   # from false — server should validate claimed hits
dual_wielding_off_hand_damage_multiplier = 0.6  # from 1.0; EC daggers spike hard otherwise
player_relation_to_teammates = NEUTRAL        # keep — six-player friendly fire is misery
```
Then **audit `config/bettercombat/fallback_config.conf` after the pack is assembled** and hand-author
`weapon_attributes` JSON for any weapon mod that landed on a bad fallback.

**The upside — this is the best cross-mod tuning surface in the whole pack.**
`data/<namespace>/weapon_attributes/<item_path>.json` fully overrides any item's category,
`two_handed`, `range_bonus` and per-swing `damage_multiplier`, and inherits from 33 bundled presets.
**You can nerf any weapon from any mod with a one-file datapack, without touching that mod's own
config**, and it does not interact with Apotheosis affix scaling the way a stat-line change does:

```json
{
  "parent": "bettercombat:claymore",
  "attributes": { "attack_range": 0.0 },
  "attacks": [
    { "damage_multiplier": 0.7, "upswing": 0.5, "angle": 90, "hitbox": "HORIZONTAL_PLANE" }
  ]
}
```
**Reach for this first** whenever Cataclysm / Epic Knights / Simply Swords / Expanded Combat weapons
need re-tiering against each other.

---

### 2.20 Quick verdicts — mods needing no fix, or no longer installable

| Mod | Verdict | Why |
|---|---|---|
| **Simply Tooltips** | 🟢 **keep — mandatory** | Zero gameplay effect, but it is a **hard required dependency** of both Simply Swords and Simply Bows. ⚠ Modrinth marks it `server_side: unsupported` while Simply Swords' NeoForge build declares it **required** — **ship it on the server too** or the server refuses to load Simply Swords. Bonus idea: its `item_themes/defaults.json` lets you map items across all 150 mods to rarity themes **by your own power assessment**, giving the group a consistent at-a-glance tier signal. Cheap partial mitigation for this whole document. |
| **Simply Swords Reforged** (RP) | 🟢 keep | Cosmetic. Last updated 2024-09; expect missing models on Uniques added since. Visual bug, not balance. |
| **Skeleton Uses Custom Bow** | 🟢 keep as shipped | **Inert by default** — ships three data files, none sets `chance`, which defaults to 0.0. ⚠ **Footgun:** the README example pairs `chance: 0.25` with `drop_chance: 0.05`, and the mod ships adapters for Cataclysm's Cursed Bow and Wrath of the Desert. Writing that entry makes a Cataclysm boss bow farmable off skeletons at ~1-in-80. **Never set `chance > 0` on a boss weapon.** Put every Cataclysm / Aether / TF / Simply Bows endgame bow into `skeletonusescustombow:skeleton_do_not_use` on day one. |
| **Simply Entity Equipment** | 🔴 **datapack or cut** | **No config file exists** — verified by walking the repo. Ships `max_health` modifiers of `add_multiplied_total` **4.34** (a 20 HP zombie → ~107 HP), which **stacks with Apotheosis affix mobs** → 300+ HP trash mobs in overworld caves. Also drops `simplyswords:runefused_gem` from ordinary skeletons, making Simply Swords' socket progression **AFK-farmable**. ⚠ Entries *append* across packs, so you cannot subtract the defaults — you must **shadow** `data/simplyentityequipment/simplyentityequipment/spawn_equipment/example.json` with `[]`. **Verify that path-shadowing works before relying on it.** Also: v0.1.0, five days old, 576 downloads, mixins into mob spawning and melee AI. Highest-variance component in the pack. |
| **T.O Magic 'n Extras** | 🔴 **cut** | No 1.21.1 build worth shipping (alpha, ~20% ported). Closed source, no wiki, **no published damage or armor value for any of its 12 weapons or 5 armor sets.** Unmeasurable power that explicitly re-tunes Cataclysm. |
| **Ars Elixirum** | 🔴 **cut** | 1.21.1 is a `version_type: alpha` from Oct 2024 with an empty changelog, from an unfinished Mod Jam entry. Not fit for a months-long world. *(Its 1.20.1 line adds a craftable Totem of Undying — a farmable death-insurance item that would nullify the death stakes of every boss on the list. Not in the 1.21.1 build, but watch for it if a port lands.)* |
| **Alex's Caves / Alex's Mobs** | 🔴 unavailable | 1.20.1 only, no update since 2024. No drop-in replacement. |
| **Saint's Dragons** | 🔴 unavailable | No 1.21.1 build found. |
| **Majrusz's Progressive Difficulty** | 🔴 unavailable | Abandoned since Apr 2024, 1.20.1 max. **The biggest structural loss** vs Beyond Depth — its Normal→Expert→Master state machine has no 1.21.1 equivalent. |
| **Aether II** | 🔴 unavailable | Earliest build is 1.21.8. |

---

## 3. THE DATAPACK SKELETON

### 3.1 Layout

Five separate packs, not one. Separation means you can disable a single fix when it misbehaves at
2 a.m. without reverting everything, and it makes `/datapack list` legible.

```
C:\Game Servers\Minecraft\datapacks\
│
├── 01-parity-nerf\                     ← the overpayers
│   ├── pack.mcmeta
│   └── data\
│       ├── apotheosis\
│       │   ├── affixes\melee\executing.json
│       │   ├── affixes\melee\attribute\piercing.json
│       │   ├── affixes\armor\attribute\winged.json
│       │   ├── rarities\mythic.json
│       │   ├── advancement\progression\pinnacle.json
│       │   └── tags\item\affix_blacklist.json
│       ├── apothic_attributes\brewing_mixes\flying_from_levitation.json
│       ├── apothic_spawners\
│       │   ├── recipe\spawner_modifiers\echoing.json
│       │   ├── recipe\spawner_modifiers\_inverse\echoing.json     ← DO NOT FORGET
│       │   └── tags\entity_type\blacklisted_from_spawners.json
│       ├── gateways\gateways\hellish_fortress.json
│       ├── deeperdarker\
│       │   ├── tags\item\resonarium_armor.json                    ← the empty one
│       │   ├── enchantment\volume.json
│       │   └── irons_spellbooks_spell_config\summoned_warden.json
│       └── ars_nouveau\tags\entity_type\drygmy_blacklist.json
│
├── 02-parity-buff\                     ← the underpayers
│   └── data\
│       ├── cataclysm\recipe\void_forge.json
│       ├── undergarden\recipe\utherium_sword.json
│       ├── undergarden\recipe\forgotten_sword_smithing.json
│       ├── twilightforest\recipe\equipment\fiery_sword.json
│       ├── eternal_starlight\recipe\moonring_greatsword.json
│       └── gateways\gateways\emerald_grove.json
│
├── 03-parity-gate\                     ← move the gate, don't touch the numbers (PREFERRED)
│   └── data\
│       ├── magistuarmory\recipe\steel_ingot.json
│       ├── antarchy\recipe\ultimate_chestplate.json
│       ├── undergarden\recipe\catalyst.json
│       ├── minecraft\tags\block\needs_diamond_tool.json
│       └── aether\
│           ├── worldgen\structure_set\bronze_dungeon.json
│           └── loot_table\chests\dungeon\bronze\bronze_dungeon_treasure.json
│
├── 04-weapon-attributes\               ← Better Combat cross-mod re-tiering
│   └── data\
│       ├── cataclysm\weapon_attributes\void_forge.json
│       ├── magistuarmory\weapon_attributes\concave_edged_halberd.json
│       └── expanded_combat\weapon_attributes\dancers_sword.json
│
└── 05-structure-collision\             ← already on disk; leave it alone
    └── data\dungeons_arise\worldgen\structure_set\*.json
```

### 3.2 `pack.mcmeta` — 1.21.1

```json
{
  "pack": {
    "pack_format": 48,
    "description": "01 — Parity nerfs. Rate ceiling R<=0.030. See planning/01-BALANCE-PLAYBOOK.md",
    "supported_formats": { "min_inclusive": 48, "max_inclusive": 48 }
  }
}
```
`pack_format 48` = 1.21 / 1.21.1. `supported_formats` pinned to 48 exactly means the pack **loudly
fails** rather than silently half-loading if someone bumps the server to 1.21.2 mid-campaign, where
the attribute-id rename would break every override in `02-parity-buff`. That is the failure you
want — loud.

### 3.3 The folder names that will bite you

**1.21 renamed every data folder to singular.** Getting this wrong produces **no error** — the file
is simply never read, and you spend an evening wondering why a nerf did not land.

| ❌ Wrong (pre-1.21) | ✅ Right (1.21.1) |
|---|---|
| `recipes/` | **`recipe/`** |
| `loot_tables/` | **`loot_table/`** |
| `advancements/` | **`advancement/`** |
| `tags/items/` | **`tags/item/`** |
| `tags/blocks/` | **`tags/block/`** |
| `tags/entity_types/` | **`tags/entity_type/`** |
| `predicates/` | **`predicate/`** |
| `structures/` | **`structure/`** |
| `worldgen/structure_sets/` | **`worldgen/structure_set/`** |

`enchantment/` and `damage_type/` were singular from birth.

### 3.4 Load order

Later packs override earlier ones. Order matters wherever two packs touch the same file.

**Option A — per-world (simplest).** Copy the folders into `<world>/datapacks/`, then:
```
/datapack list
/datapack enable "file/03-parity-gate" last
/reload
```

**Option B — Paxi (recommended for a 150-mod pack).** Drop the packs in
`config/paxi/datapacks/` and control order with `config/paxi/datapack_load_order.json`:
```json
[
  "01-parity-nerf",
  "02-parity-buff",
  "03-parity-gate",
  "04-weapon-attributes",
  "05-structure-collision"
]
```
Paxi auto-loads them into **every** world, so a world reset does not silently drop your balance
work. Given this campaign may span a world regeneration, use Paxi.

### 3.5 Two things that will silently do nothing

Both are already noted above; they are repeated here because they cost the most time to discover.

1. **Simply Bows injects loot in code**, not through datapack loot tables. A loot datapack aimed at
   it is dead weight. Use its config.
2. **Item attribute defaults are baked at registration on 1.21.1.** A datapack can set attributes on
   an item **produced by a recipe you override** (that is what §2.8/2.11/2.12 do — the component
   rides on the recipe `result`), but it **cannot** change an item obtained from a **loot table, a
   boss drop, or `/give`**. Anything acquired other than by your overridden recipe keeps the mod's
   original stats.
   > ⚠ **This is the single biggest limitation in this whole document.** Cataclysm's Void Forge is
   > crafted at a Mechanical Fusion Anvil, so §2.8 works. But if a mod's capstone weapon is a
   > **boss drop**, no recipe override reaches it and you need **KubeJS `ItemEvents.modification`**.
   > Check acquisition method *before* writing the JSON.

---

## 4. THE TRACK MENU — paste this into Discord

Everything below the line is written for the players, not for you. It exists to prevent the
"I put in 40 hours and got less than you" argument **before** it happens — by making the trade
visible at pick time. Under Rule 5, disclosure *is* the fix for axis mismatch.

**Grouped by commitment, not by play order. You are meant to pick from a menu, not walk a path.**

---

> # 🗺️ THE TRACK MENU
> **Pick what sounds fun. There is no "correct" order and no track is required.**
>
> You will not finish this pack. Nobody will. That is the design — most of this content will
> never be touched by anyone and **that is completely fine.**
>
> Two things worth knowing before you pick:
> - **Tracks in the same tier are meant to be fair swaps.** Same effort in, comparable power out.
>   If that stops being true in practice, say so and it gets patched — that is a bug, not bad luck.
> - **⚠ Read the "you get paid in" line.** Two tracks can be equally strong and still feel unfair if
>   one pays you in damage and the other pays you in a working town. Pick the *currency* you want,
>   not just the hours.
>
> ---
>
> ## ☕ WEEKEND TRACKS — 5 to 15 hours
> *Dip in, come out meaningfully stronger, go do something else.*
>
> | Track | What it is | You get paid in | You walk away with |
> |---|---|---|---|
> | **Gateways to Eternity** | Summon a wave arena at your base, fight it, get the pile | Loot & gear | Bulk loot, a decent weapon, no travel required |
> | **When Dungeons Arise + Towns and Towers** | Overworld structures worth actually raiding | Loot & gear | Good chests, a reason to explore in a direction |
> | **Aquaculture + Bountiful** | Fishing and bounty boards, low stress | Economy | Steady materials, good food, zero deaths |
> | **Artifacts** | Trinket hunting — small permanent perks | Utility | A handful of always-on quality-of-life buffs |
> | **Deeper and Darker: Spellbooks** | One armor set, one staff, four spells | Ranged burst | A solid magic starter kit |
>
> **Fair swaps:** any of these against any other. Roughly 10 hours, roughly the same power out.
>
> ---
>
> ## 🔨 CAMPAIGN TRACKS — 20 to 35 hours
> *The main body of the pack. Most people should live here. Pick two over a few months.*
>
> | Track | What it is | You get paid in | You walk away with |
> |---|---|---|---|
> | **The Twilight Forest** | Boss ladder in a forest dimension, gated by progression | Damage + trophies | Netherite-plus gear, several distinct boss kills |
> | **The Undergarden** | Parallel underground dimension, its own materials | Damage + building | A full gear tier, a lot of very good blocks |
> | **Deeper and Darker** | Sculk dimension below the Ancient City — Warden-tier gear | Damage + survivability | A strong armor set and a genuinely hard gate (7–20 Warden kills) |
> | **The Aether** | Sky islands, dungeon puzzles, flying mounts | **Survivability** | **+20 max HP** (double your health), mobility toys |
> | **Apotheosis** | Affixed loot, gems, sockets, enchanting depth | Damage + gambling | The strongest single weapon in the pack, eventually |
> | **Epic Knights** | Historical plate armor and polearms | **Defense** | The tankiest kit available, lots of silhouettes |
> | **Minecolonies** | Build and run a town with NPC workers | **Economy** | A settlement that produces for you forever |
> | **Cobblemon** | Catch and battle a team — it is a whole separate game | **Its own currency** | A team. Nothing that helps in a Cataclysm fight. |
>
> ⚠ **Aether pays in health, not damage.** You will end up harder to kill, not hitting harder. If
> you want a bigger number on your sword, pick Twilight Forest or Undergarden instead.
> ⚠ **Minecolonies pays in a town.** It is the best track here and it will not make you stronger in
> a fight. Go in wanting that.
> ⚠ **Cobblemon is a parallel game, not a track.** It is genuinely great and it is not comparable to
> anything else on this menu. Pick it because you want it, not because you are optimising.
>
> **Fair swaps:** Twilight Forest ↔ Undergarden (closest match on the list — both pay in gear).
> Aether ↔ Epic Knights (both pay in survivability). Apotheosis ↔ Twilight Forest.
> **Not a fair swap:** Minecolonies ↔ anything combat. Different game, on purpose.
>
> ---
>
> ## ⚔️ LONG HAUL — 40 to 80 hours
> *Campaign-defining. These end with the strongest things in the world. Pick **one**.*
>
> | Track | What it is | You get paid in | You walk away with |
> |---|---|---|---|
> | **L_Ender's Cataclysm** | 8 hand-built bosses, dungeon-gated, genuinely hard | **Damage + bragging rights** | The Void Forge, plus the hardest kills on the server |
> | **Iron's Spells 'n Spellbooks** | Pick a magic school, build into it | **Ranged burst + safety** | Kill things from 30 blocks away, in relative safety |
> | **Ars Nouveau (+ Ars Elemental)** | Design your own spells; automate everything | **Automation + logistics** | Infrastructure, not a weapon. Ars Elemental is the same track's back half — its armor is the tankiest mage kit in the pack. |
> | **Eternal Starlight** | Post-Ender-Dragon dimension, 22 biomes | **Exploration + cosmetics** | Scenery, music discs, armor trims, and a good sword |
>
> ⚠ **Ars Nouveau will NOT make you hit harder.** Its damage is deliberately capped and always will
> be. What it gives you is machines, spell design, and a base that runs itself. It is the best track
> on this list **if that is what you want**, and the worst one if you wanted a sword. **Do not pick
> this expecting DPS.**
> ⚠ **Eternal Starlight is the scenic route.** It is post-dragon, it is beautiful, and its gear is
> good but not the best in the pack. Pick it for the trip.
> ⚠ **Cataclysm is the hardest content here.** The Netherite Monstrosity is 600 HP, hits for 25, and
> **cannot be knocked back.** If you want the fights, this is the track.
>
> **Fair swaps:** Cataclysm ↔ Iron's Spells (one melee, one ranged, similar power out).
> Ars Nouveau ↔ Eternal Starlight (both pay in something other than damage).
> **Not a fair swap:** Cataclysm ↔ Ars Nouveau. Same hours, completely different currencies. This
> is the pairing most likely to cause an argument, so it is called out here on purpose.
>
> ---
>
> ## 🤝 HOUSE RULES
>
> 1. **Gear is shareable and that is encouraged** — but it means a track finished by one person is
>    effectively finished for all six. If a track's reward is a *craftable item*, expect it to be
>    priced accordingly.
> 2. **If a track feels bad, say so immediately.** Under-rewarding is treated as an equal-priority
>    bug to overpowered. Both get patched. Nobody has to grind 60 hours to prove a point.
> 3. **Balance patches are datapacks and can land mid-campaign.** Existing items generally keep
>    their stats; new ones use the new numbers.
> 4. **Nobody is expected to finish anything.** The menu is bigger than the group. On purpose.
> 5. **⚠ Wesley will out-gear everyone, and that is hours, not balance.** He hosts, so he is on here
>    more than any of you — probably 3–6×. The pack is tuned so that *an hour on any track is worth
>    about the same as an hour on any other track*. It is **not** tuned so everyone ends up equal,
>    because nobody plays the same amount. There is a **shared gear chest at spawn** — his surplus is
>    your floor, use it. And if the gap stops being fun, say so; the bounty boards can be tilted
>    toward whoever has the least time.
> 6. **⚠ Death rules — decided, not defaulted:** *[fill in before launch — see §1.10.2. The choice is
>    grave mod / `keepInventory` / full loss, and it is currently sitting on "full loss" purely
>    because nobody picked.]* Whichever it is, know that **gear tracks carry loss risk that magic and
>    town tracks do not.** Ars glyphs, Iron's Spells research and your Minecolonies town survive death
>    unconditionally; a full Epic Knights kit does not. Factor that into your pick.
> 7. **PvP is currently ON.** With the swords in this pack that is a bigger deal than in vanilla.
>    Say if you want it off.

---

## 5. WHAT TO FIX FIRST

Highest impact per unit of effort, descending. **Direction is labeled on every row —
this is not a nerf list.** Five of the top twenty are buffs, and one of them is #6.

### Tier 0 — before anyone joins the world

| # | Dir | Fix | Effort | Why it is first |
|---|---|---|---|---|
| 1 | 🔴 **NERF** | **D&D Resonarium — empty the `resonarium_armor` tag** (§2.1) | **1 file, 2 min** | 100% damage immunity from **iron-tier** gear, farmable off a trash mob, giftable to all six. One afternoon ends combat for the whole server, permanently. ⚠ **The file on disk right now leaves 75%.** |
| 2 | 🔴 **NERF** | **Simply Swords — `omen_instantkill_threshold = 0`** (§2.7) | **1 line** | 75%-per-hit instant kill below 25% HP, **no boss check in the code**. Deletes the final phase of all 8 Cataclysm bosses, the Wither and the Dragon. Chest loot, hour one. |
| 3 | 🔴 **NERF** | **Apotheosis — zero the `executing` weights** (§2.5) | **1 file** | Identical execute mechanic from the other direction. Both must go or neither matters. |
| 4 | 🔴 **NERF** | **Gateways — delete the Wither Skeleton Spawner reward** (§2.17) | **1 edit** | Infinite Nether Stars in 8–15 h. Neither mod causes it alone. |
| 5 | 🔴 **NERF** | **Epic Knights — `knockbackResistance = 0.10` on every set, `0.0` on stechhelm** (§2.16) | **~8 values** | **Two pieces of iron-tier steel = 100% knockback immunity at hour 2.** Deletes the knockback phases of every modded boss. |
| 6 | 🔵 **BUFF** | **Cataclysm — Void Forge / Infernal Forge to ~1.2–1.5×** (§2.8) | **2 files** | `R = −0.003`. *Dan fights a 600 HP knockback-immune boss for 40 hours and gets a weapon that lowers his DPS.* This is the group's stated nightmare, already live. **Do it in the same sitting as #1–5, not "later."** |
| 7 | 🔴 **NERF** | **Twilight Forest — `flipUncraftingModIdList = true` + `disableUncraftingOnly = true`** (§2.10) | **4 lines** | Pack-wide recipe-gating bypass across **all 150 mods**, plus documented dupe bugs. |
| 8 | 🔴 **NERF** | **Antarchy — `ultimateSwordAttackDamage 34→13`, `bigBerthaAttackDamage 62→20`, armor 32→20** (§2.3) | **~8 values** | The mod the group named. Config surface is excellent; this is 10 minutes. |

### Tier 1 — first week

| # | Dir | Fix | Effort | Why |
|---|---|---|---|---|
| 9 | 🔵 **BUFF** | **Undergarden — Utherium/Forgotten swords to 1.2×/1.4×** (§2.12) | 2 files | `R = −0.015`. ⚠ **The on-disk override only reaches 0.80× — it does not fix the problem.** |
| 10 | 🔴 **NERF** | **Artifacts — game rules + strip Power Glove/Crystal Heart from hour-2 loot** (§2.4) | 13 rules + 1 loot file | `R = 0.185`, the highest rate in the pack. A flat weapon-agnostic +4 compresses the felt value of **every** other track's gear. |
| 11 | 🔴 **NERF** | **Simply Bows — 4 loot-chance values** (§2.7) | 4 values | `R = 0.103`. `boostedBowChance 15 → 2` alone fixes most of it. |
| 12 | 🔴 **NERF** | **Apothic Spawners — `Spawner Silk Level = -1`, or `Spawners Drop Empty = true`** (§2.17) | 1 line | Kills ~80% of the economy risk. Pairs with #4. |
| 13 | 🔵 **BUFF** | **Eternal Starlight — Moonring Greatsword to ~1.6×** (§2.11) | 1 file | A **post-Ender-Dragon** track paying netherite parity is the purest Rule 2 violation on the list. |
| 14 | 🔴 **NERF** | **Expanded Combat — `enableWeapons = false`** (§2.6) | 1 line | Removes a redundant fourth weapon ladder *and* the 17-damage gold-arrow bow. Keeps the good half of the mod. |
| 15 | 🔴 **NERF** | **Iron's Spells — Angel Wings `max_level 2`, `cooldown 400`** (§2.9) | 1 file | Functionally permanent flight devalues **every** exploration track simultaneously. |
| 16 | ⚙️ **BOTH** | **Simply Swords — `katana/twinblade/cutlass_attackspeed → -2.4`** (§2.13) | 3 lines | Nerfs Simply Swords **and** un-undercuts Twilight Forest, Undergarden and D&D in the same edit. Best effort-to-effect ratio in the document. |

### Tier 2 — first month

| # | Dir | Fix | Effort | Why |
|---|---|---|---|---|
| 17 | ⭐ **STRUCTURAL** | **Weld Apotheosis's Pinnacle tier to a Cataclysm boss kill** (§2.5) | 1 advancement | Makes the biggest overpayer *require* the biggest underpayer. Fixes both directions with one file. ⚠ **But read the caveat below before doing it.** |

> ⚠ **#17 is serial gating, and serial gating is in tension with the hub premise.** §1.1 and §4 both
> promise *"pick from a menu, not walk a path."* Welding Pinnacle to a Cataclysm kill converts two
> parallel Long-Haul tracks into one 60-hour chain, and the Track Menu tells players to pick **one**
> Long Haul track — so a player who picks Apotheosis now silently owes 40 hours of a track they did
> not pick. That is the group's stated fear (unequal reward for equal effort) arriving through the
> fix rather than the defect.
>
> **It is still the right call, but only under one of these two framings — choose one and say it in
> the menu:**
> - **(a) Merge them into one advertised track.** "Cataclysm + Apotheosis" becomes a single 60-hour
>   Long Haul entry that pays in both bosses and mythic gear. Honest, and it fixes both rates at
>   once. **Preferred.**
> - **(b) Gate on *any* comparable capstone, not Cataclysm specifically.** Accept a Twilight Forest
>   Snow Queen, an Aether Sun Spirit, a Deeper and Darker Warden or a Cataclysm boss. Same gating
>   magnitude, no forced path, and it rewards four tracks instead of taxing one.
>
> **What NOT to do:** ship the weld silently and let someone discover at hour 25 that their track has
> a prerequisite. Whatever you pick, it goes in §4 before anyone picks a track.
| 18 | 🔵 **BUFF** | **Gateways `emerald_grove` rewards** (§2.17) | 1 file | Two players, identical effort — one gets farm animals, one gets an infinite spawner. This group's fear, inside one mod. |
| 19 | 🔴 **NERF** | **Ars Nouveau — Drygmy blacklist + `drygmyUniqueBonus = 0`** (§2.14) | 1 file + 3 values | Passive mob-drop farming undercuts every combat mod's material gate at once. |
| 20 | 🔴 **NERF** | **Apothic Attributes — Potion of Flying brewing mix** (§2.5) | 1 file | Better: re-point the ingredient at a boss drop so **flight becomes a track reward** instead of a byproduct. |
| 21 | 🔵 **BUFF** | **Twilight Forest — Fiery Sword** (§2.10) | 1 file | ⚠ Re-add the Fire Aspect II component or the buff is a net nerf. |
| 22 | 🔴 **NERF** | **Better Combat — `reworked_sweeping_extra_target_count 4 → 2`** (§2.19) | 1 line | 3–5× crowd DPS compresses every wave/dungeon mod in the pack. |
| 23 | 🔴 **NERF** | **Apotheosis — `piercing` values, `unbreakable` roll, `Curse Boss Items = true`** (§2.5) | 3 edits | Armor Pierce 12 = 60% bypass of full netherite. |
| 24 | ⚙️ **BOTH** | **Apotheosis — `Upgrade Level Cost 225 → 50`** (§2.5) | 1 line | Anti-variance. At 225 the only affordable path is building the thing that breaks the economy. |
| 25 | 🔴 **GATE** | **Epic Knights steel → Nether-gated; Undergarden Catalyst → Nether-gated** (§2.16, §2.12) | 2 files | Rule 1 says gate before you nerf. These preserve every item and move only the timing. |

### Tier 3 — decisions, not edits

| # | Dir | Decision |
|---|---|---|
| 26 | ✂️ **CUT** | **Grim and Bleak** (§2.2) — no config, unfixable stat lines, **irreversible server-wide Overworld mutation** triggered by one player. |
| 27 | ✂️ **CUT** | **Paradise Lost** (§2.15) — under-rewards *and* ships an **uncapped scalar that grows with your modlist size**. No config file found. |
| 28 | ✂️ **CUT** | **T.O Magic 'n Extras** (§2.20), **Ars Elixirum** (§2.20), **Knaves' Needs** (§2.13) — unmeasurable, alpha, and 520-item-rename-risk respectively. |
| 29 | 🔬 **MEASURE** | **Iron's Spells `H`** (§6.5) — Doc 00 says 45 h, old Doc 01 said 25 h. At 45 it needs nothing; at 25 it needs work. **Measure before tuning.** |
| 30 | 🔬 **MEASURE** | **Artifacts hands-slot count** (§2.4) — if it is 1 rather than 2, the whole §2.4 urgency halves. |
| 31 | ⭐ **DECIDE** | **Death penalty** (§1.10.2) — grave mod vs `keepInventory` vs full loss. **Currently decided by omission, in the harshest direction.** It taxes gear tracks and exempts magic tracks, systematically, on top of every nerf in §2. Recommendation: grave mod with its own perk system disabled. **Decide this before Tier 0, not after** — it changes which §2 fixes are still needed. |
| 32 | ⭐ **DECIDE** | **Unequal hours** (§1.10.1) — a zero-defect pack still ships a **2.2× spread** between a 120 h host and a 20 h player. Bigger than any rate mismatch in §1.6 and untouched by every datapack in §3. Minimum: House Rule 5 + a shared gear chest at spawn. Better: tilt Bountiful boards toward low-hour players. |
| 33 | 🔬 **AUDIT** | **Overgrown's Origins** (Doc 00 §2.1) — a **zero-hour** permanent-ability grant has an undefined rate, which Rule 1 cannot evaluate. Audit it or cut it; do not ship it unmeasured. |
| 34 | 🔬 **AUDIT** | **The unpriced `keep` tracks** (Doc 00 §2.1) — Aquamirae and **Cult of Azazel** especially. An unmeasured boss mod in the Nether stack is exactly the shape of the next Antarchy. |

### What NOT to do

- **Do not fix Ars Nouveau's negative rate.** It is a Rule 5 axis artefact. The Amplify cap is doing
  your balancing for free. Touching it makes things worse.
- **Do not act on the 🟡 rows in §1.6 yet.** The band edges are soft by ~3× (§1.3). Anything inside
  2× of the anchor is noise until `R*` is measured.
- **Do not nerf a mod when you could gate it.** Rule 1. Nerfing deletes content the group paid for
  in install time; gating preserves it and only moves the timing.
- **Do not retroactively nerf gear players already own.** Datapack recipe changes affect newly
  crafted items. Let existing ones stand; it costs almost nothing and buys a lot of goodwill.

---

## 6. TESTING PROTOCOL

### 6.1 Did the nerf actually land? — the 90-second check

For any weapon/armor stat change:

```
/gamemode creative
/give @s <namespace>:<item>
```
Hover it. **The tooltip is authoritative** — it renders the item's real attribute component. If your
number is not there, the override did not bind.

Then verify on the *player*, which catches slot and stacking bugs the tooltip hides:
```
/attribute @s minecraft:generic.attack_damage get
/attribute @s minecraft:generic.armor get
/attribute @s minecraft:generic.armor_toughness get
/attribute @s minecraft:generic.knockback_resistance get
/attribute @s minecraft:generic.movement_speed get
```
> ⚠ **`generic.` prefix on 1.21.1** (§0.1). If these commands **error on the attribute name**, you
> are on 1.21.2+ and every attribute id in this document needs the prefix stripped. **That single
> error message is the definitive test** — it settles §0.1 in one command. Run it first.

**The knockback-immunity check (§2.16)** — the important one, because the tooltip does not make it
obvious:
```
/attribute @s minecraft:generic.knockback_resistance get
```
Two pieces of steel plate should now read **0.20**, not **1.0**. At 1.0 you are immune.

**The Resonarium check (§2.1)** — the single most important test in this document:
```
/gamemode survival
/damage @s 20 minecraft:generic
```
Your health **must** drop. If it does not, the tag override did not take — check that the folder is
singular `tags/item/` and that the tag id matches `DDTags.Items`.

### 6.2 Did the recipe change land? — JEI

`/reload`, then in JEI type the item name and press **U** (uses) / **R** (recipes).

- **Recipe still shows the old ingredients** → your override did not bind. Ninety percent of the
  time this is (a) plural folder name (`recipes/` not `recipe/`), (b) wrong namespace, or (c) the
  filename does not match the recipe id exactly.
- **Recipe is gone entirely** → you overrode it with an invalid JSON. Check `logs/latest.log` for a
  parse error at server start.
- **Recipe shows but the crafted item has default stats** → the `components` block is malformed, or
  the attribute id prefix is wrong. Back to §6.1.
- **⚠ Recipe is right but a *dropped* copy of the item has old stats** → expected, and it is §3.5's
  limitation. Your override only touches the crafted instance. If the item is primarily a boss drop,
  you need KubeJS.

**JEI is also your id source.** `F3+H` turns on advanced tooltips showing real item ids — use it to
replace every `🔍 VERIFY BEFORE APPLYING` guess in §2 with a real id before writing the file.

### 6.3 Did the rate actually change? — the DPS bench

Numbers on a tooltip are not DPS. Build a bench once and reuse it:

```
/summon minecraft:zombie ~ ~ ~2 {Attributes:[{id:"minecraft:generic.max_health",base:600}],Health:600f,NoAI:1b,PersistenceRequired:1b}
```
600 HP matches the Netherite Monstrosity, so **time-to-kill on this dummy is directly comparable to
the §1.2 derivation.** Swing continuously and count seconds.

| Weapon | Expected TTK on 600 HP | If you get… |
|---|---|---|
| Netherite + Sharp V (baseline, `1.00×`) | **~33 s** | this is your calibration — measure it first |
| A track at target `1.5×` | ~22 s | ✅ correct |
| A track at `0.9×` (Void Forge today) | ~37 s | 🔵 under-rewarding, confirmed |
| A track at `3.0×` | ~11 s | 🔴 over-rewarding, confirmed |

**Do the baseline measurement first, every session.** If your netherite+SharpV number is not ~33 s,
something else in the pack (Better Combat, an Apotheosis affix, an Artifacts trinket you forgot you
were wearing) is already moving the floor, and every comparison after it is wrong.

⚠ **Strip your accessories before benching.** A Power Glove in a Curios slot silently adds +4 to
every measurement in the session.

### 6.4 Did the loot change land?

```
/loot give @s loot minecraft:chests/pillager_outpost
```
Run it 20 times. Count. Cheaper and far more reliable than flying to a structure. For structure
density changes, use `/locate structure <id>` repeatedly from spawn and eyeball the distances
against your `spacing` value.

### 6.5 Measuring `H` — the task §5 #29 asks for

Rate parity is meaningless without real hour counts, and every `H` in §1.6 is a guess. **Do this
once, early, and the whole document gets sharper.**

Cheapest method: **have each player post a one-line note in Discord when they cross a milestone**
("first Cataclysm boss down, ~14 h in"). Six players × a few milestones gives real data in two
weeks. That is better than any spreadsheet nobody fills in.

Two specific measurements worth prioritising:
1. **Iron's Spells: hours to a fully-geared single school.** Settles the 25-vs-45 disagreement, which
   is the difference between "leave it alone" and "emergency" (§2.9).
2. **The anchor itself: hours to a Void Forge.** `H = 40` is a guess; it drives `R*` and therefore
   every verdict in this document.

### 6.6 Bisecting a crash in a 150-mod pack

Binary search. ~7–8 restarts for 150 mods. Do not remove mods one at a time — that is 150 restarts.

1. **Read `logs/latest.log` first.** Real information is usually in there and this whole section is
   often unnecessary. Look for the **last mod id mentioned before the stack trace**, and for
   `Mixin apply failed` / `ClassNotFoundException` / `AbstractMethodError` — the last two almost
   always mean a **library version mismatch**, not a content mod.
2. **Check the known conflicts before bisecting**, because these three are already documented:
   - `IllegalStateException: Mod 'architectury' is not available!` → **do not reinstall
     Architectury.** Something is bundling **OmegaConfig**. Go find it.
   - `Conflicting default methods: DeferredSupplier.getKey` → the **Architectury × Apotheosis**
     conflict (issue #592). Architectury 13.0.11 may already fix it; verify, do not assume.
   - Missing-dependency failure on **Simply Swords** → you did not ship **Simply Tooltips** on the
     server (§2.20).
3. **Bisect.** Move half of `mods/` to `mods_disabled/`. Boot.
   - Crashes → the culprit is in the half you kept. Halve again.
   - Boots → the culprit is in the half you removed. Swap and halve.
   - **⚠ Keep every library mod in place on every pass** (Architectury, Curios, GeckoLib, Balm,
     Moonlight, YUNG's API, Puzzles Lib, Bookshelf, Collective, Resourceful Lib, TerraBlender,
     Lithostitched, Kotlin for Forge). Removing a library produces a *different* crash and sends you
     down a false trail. Bisect content mods only.
4. **Datapack crashes bisect separately and faster** — `/datapack disable "file/<name>"` then
   `/reload`, no restart needed. Do this *before* touching `mods/`; if the crash started right after
   you added a balance pack, it is the pack.
5. **Once isolated, reproduce in a fresh singleplayer world** with just that mod plus its
   dependencies. That is the report an author will actually act on.

### 6.7 Pin everything, and never auto-update mid-campaign

The Architectury/OmegaConfig and Architectury/Apotheosis conflicts are both **version-specific**.
A silent launcher bump is how a months-old world stops booting on a Tuesday.

- **Pin NeoForge at 21.1.249.** Pin every library at pack-freeze.
- **Back up the world before any mod update.** The house convention already covers this — use it.
- **Test balance changes in singleplayer first**, with the same datapacks. A `/reload` on the live
  server with a malformed JSON drops **every** datapack, silently reverting your entire balance pass
  mid-session, and nobody will notice for a week.

### 6.8 The parity smoke test — run this once, a month in

The real test is not a number, it is a conversation. A month into the campaign, ask each player two
questions:

1. *"Roughly how many hours are you into your track?"*
2. *"On a scale of 1–10, how strong do you feel compared to everyone else?"*

Plot answer 2 against answer 1. **If the line is flat, the pack is balanced** — that is literally
what rate parity means. If someone is well below the line, they are the Dan case from §1.6 and their
track needs a buff. If someone is well above it, you found an overpayer this document missed.

**This test outranks every number in this document,** because it measures the thing the group
actually asked for and none of the arithmetic above can observe.
