# MODLIST AUDIT — Minecraft 1.21.1 NeoForge, 6-player shared campaign

**Target:** 120–150 mods · NeoForge 21.1.249 · one world, months long · Wesley + Leyton, DJ, David, Dan
**Governing metric:** payoff-per-hour across *concurrent parallel tracks*. Not absolute ceiling. Not sequencing.
**Both ends are defects.** A track that overpays cheaply and a track that underpays after 60h fail the same test.
**Audit date:** 2026-08-29 · Numbers not read from source or a first-party page are marked **(unverified)**.

---

## 1. TL;DR — the ten findings that change decisions

> ### ⚠ FINDING ZERO — the two biggest levers are not mods, and neither has been decided
> *(Added by completeness review. Read this before the ten below, because both outrank all of them.)*
>
> **(a) Unequal playtime.** A pack with *zero* balance defects still ships a **2.2× power spread**
> between a 120-hour host and a 20-hour player. That is larger than the worst legitimate rate
> mismatch on this list, and it is untouched by every config and datapack in these three documents.
> The stated fear was "equal effort, unequal reward." The far likelier event is **unequal effort**,
> and until now nothing here modelled it. → `01-BALANCE-PLAYBOOK.md §1.10.1`
>
> **(b) The death penalty.** The build ships `difficulty=hard`, no `keepInventory`, and **no grave
> mod** — three balance decisions inherited by accident rather than chosen. Full loss on death
> **taxes every gear track and exempts every knowledge track**, pushing in the same direction as half
> the nerfs below (so they may now be double-counting), and it decides whether anyone ever seriously
> attempts the 600 HP knockback-immune boss that **the entire parity anchor is derived from**.
> → `01-BALANCE-PLAYBOOK.md §1.10.2`
>
> Both are nearly free to fix now and expensive to fix two months into a shared world.

1. **Deeper and Darker's Resonarium armor is a 100% damage-immunity bug, confirmed in shipping 1.4.1 source.** `float reduction = incoming / 4;` is computed *outside* the per-piece loop, then subtracted once per piece. Four pieces = exactly zero damage from everything not tagged `bypasses_armor`. It is diamond-tier + a looted template, not a boss fight. **Fix is five lines: empty the `deeperdarker:resonarium_armor` item tag in a datapack.** The dimension, mobs, structures and Warden gear all survive. Do this before anyone joins.

2. **Antarchy is exactly as bad as Leyton guessed, but not for the reason he guessed.** The 35-damage Ultimate Sword (56 DPS, 4.4× netherite) is netherite-gated and almost defensible. **Ultimate *Armor* is the break:** 32 armor / 18 toughness / 0.6 KB resist that **auto-applies Protection V + Blast V + Fire V + Projectile V every tick**, built from 11 uranium + 13 titanium ingots — **zero netherite, zero bosses, iron pickaxe only**, ore in a uniform 96-layer overworld band. That is the 80% damage-reduction cap in ~4–8 hours. It also ships a default-on **duplicator tree** that copies netherite and diamond blocks on random tick.

3. **Macabre is a harder cut than Antarchy and nobody flagged it hard enough.** Its *second* ore tier (ferrum, 23 armor / 16 toughness) beats full netherite at ~4h from an ungated overworld dungeon. Top set is 108 armor / 26 toughness / 20 KB resist / 60 HP. Worse, its full-set routine **resets player attribute base values every tick**, which silently nulls Curios-sourced stats — that breaks Artifacts, Apotheosis affixes, Iron's Spells buffs and Awakening relics *while worn*. No 1.21.1 config exists. **Cut.**

4. **Confluence: Otherworld is a second game, not a mod.** 36-damage unbreakable swords (4.5× netherite per hit), 29-armor sets, and **Life Crystals at +4 max HP each up to 100 HP total, hardcoded in Java so no datapack can retune them** — obtainable by ordinary caving on day one and tradeable to all six. And killing the Wall of Flesh **flips the entire server to Hardmode**, converting terrain and spawns for four players who never opted in. **Cut.**

5. **Grim and Bleak is a pre-iron portal leading to a 25-damage-base sword.** Chiseled Deepslate frame, hour-one entry, better-than-netherite armor at ~5–12h, and a Gate Guardian kill permanently spawns nightly Overworld abominations **for everyone, irreversibly**. Closed-source MCreator mod with **no armor numbers published anywhere**. **Cut, or gate the portal behind a Nether Star and delete the Thunder Sword recipe.**

6. **The under-rewarding half is real and it is the Undergarden, Eternal Starlight, Ars Nouveau and Simply Swords.** Every Undergarden weapon is at or below a netherite sword (best is 12.0 DPS vs 12.8) after 15–30h. Eternal Starlight's post-*Ender-Dragon* ceiling is a 10.5-damage greatsword and exactly-netherite armor after 40–70h. Ars Nouveau's best armor is 20 armor / **0 toughness**. Simply Swords is 60–120h for 1.4×. If Dan takes Eternal Starlight and DJ takes Apotheosis, Dan is objectively weaker after comparable hours.

7. **Two mods on the lists do not exist on 1.21.1 and everyone assumed they did.** **Alex's Caves** (DJ's list, no annotation) is 1.20.1-only, last updated Oct 2024 — and it is a *hard dependency* of T.O Magic 'n Extras. **Saint's Dragons** (David, "maybe") has no 1.21.1 build on either platform. Both are `cut-na`. §6 corrects the friends' annotations in both directions.

8. **Apothic Enchanting's damage numbers were overstated ~2× in first-pass research, and the corrected figures still matter.** Real auto-raised caps are **Sharpness 9 / Smite 10 / Protection 8** (a superlinear `+ diff × (level − maxLevel)^1.6` cost penalty applies above vanilla max), not 19/25/19 — and the table can only *roll* Sharp 7. But the exclusive-set demolition is real and verified: **Sharpness stacks with Smite**, **Protection stacks with Fire/Blast/Projectile Protection**. Ceiling vs undead is **38**, not 80.5. The **echo shard 1→4 infusion** is the bigger problem — it makes Deeper and Darker's progression currency infinite.

9. **Apotheosis' `Executing` affix has no boss check — confirmed.** `doPostAttack` calls `living.setHealth(0); living.die(src)` below the threshold; it does not deal damage, so boss damage caps, i-frames and phase gating are all bypassed. Mythic is gated behind Summit tier (a Wither kill), which is real mitigation, but every Cataclysm / Mowzie's-tier boss loses its last quarter to a 25%-per-hit proc. **Simply Swords ships the same mechanic** (`OmenEffect`: `damage(GENERIC, 1000)` at ≤25% HP, 75% chance, no boss check) on a *chest-loot* warglaive. Datapack both.

10. **Redundancy calls, made:** Better Combat **in**, Expanded Combat **out**. Sophisticated Backpacks **in**, Traveler's **out**. Terralith **in**, Biomes O' Plenty **out**. Ars Nouveau **and** Iron's Spells both **in** — but **Ars 'n Spells out**, because merging them collapses two parallel tracks into one and is the exact opposite of the hub design. Simply Swords is the primary weapon ladder; Epic Knights survives as armor-with-config; Knaves' Needs is **broken, not overpowered** (Warden tier stubbed at 0.0 → a 1-damage sword) and cut on quality grounds.

---

## 2. THE PARITY TABLE

> ### ⚠ READ THIS BEFORE YOU QUOTE ANY NUMBER IN THIS TABLE
>
> **This table is a triage sort, not the governing metric.** `01-BALANCE-PLAYBOOK.md §1.2` supersedes
> it, and the two tables deliberately disagree. Do not put them side by side and try to reconcile the
> cells — reconcile the *methods* first:
>
> | | **This table (Doc 00 §2)** | **The playbook (Doc 01 §1.6)** |
> |---|---|---|
> | Formula | `P ÷ H` | `R = (P − 1) ÷ (H × T)` |
> | Baseline `1.00×` | **unenchanted** netherite — 8 dmg, **12.8 DPS** | **Sharpness V** netherite — 11.25 dmg, **18.0 DPS** |
> | Tedium term | none | `T`, 0.8–1.3 (§1.5) |
> | Vanilla scores | **0.083/hr** ← the bug | **0.000** ← correct |
> | Band | 0.03–0.10 | 0.0075–0.030, anchor 0.015 |
>
> **`P ÷ H` credits vanilla with 0.083/hr of improvement over itself**, so this column cannot express
> an *under*-rewarding track at all — it bottoms out at zero instead of going negative. That is why
> Undergarden reads `0.038` here and `−0.015` there. The playbook's `R` is the number that answers
> the actual question. **When the two disagree, the playbook wins.**
>
> Also: the `P` values differ between the docs *for the same mod* (Undergarden 0.94 vs 0.67;
> Eternal Starlight 0.98 vs 0.70; Paradise Lost 0.70 vs 0.44; Ars Nouveau 0.80 vs 0.60) purely
> because of the baseline row above — 12.8 vs 18.0 DPS is a factor of 1.41. **Your players will carry
> Sharpness V.** Doc 01's baseline is the realistic one; this table's is more forgiving to every mod
> it rates.
>
> **What this table is still good for:** the *ordering*, the reward-axis column, and the two ends.
> The ranking is stable under both formulas. Use it to decide what to look at. Use Doc 01 §1.6 to
> decide what to type.

Sorted by **payoff-per-hour, descending**. Power = peak effective combat multiplier vs the netherite baseline (8 dmg / 1.6 spd / 12.8 DPS; 20 armor / 12 toughness / 20 HP), taking whichever of damage or survivability dominates. Hours = time to reach *that* reward, not to 100% the mod. **Top and bottom of this table are both defect zones.** The comfortable band is roughly **0.03–0.10**.

> 🔍 **EVERY VALUE IN THE `Hours` COLUMN IS AN ESTIMATE.** Not one of them was measured; they are
> judgment calls from reading recipe chains and progression gates, and they are the weakest input in
> both documents. `H` is a *divisor* — halving it doubles the verdict. The two docs already disagree
> on several (Artifacts 6 vs 3 · Apotheosis 45 vs 20 · Aether 30 vs 40 · Iron's Spells 50 vs 45 ·
> Undergarden 25 vs 20), and neither number is defended. **Doc 01 §6.5 says how to measure them for
> real, in two weeks, for free. Do that before acting on any 🟡 row.** The 🔴 and 🔵 rows miss by 4×
> or more and survive any plausible `H`.

| Mod | Headline reward | Power vs netherite | Hours | **Payoff/hr** | Reward axis | Band | Verdict |
|---|---|---|---|---|---|---|---|
| **Deeper and Darker** | Resonarium set = 0 damage taken | **∞ (arithmetic bug)** | 20 | **∞** | survivability | broken | datapack |
| **Apothic Spawners** | Echoing III spawner | ~400× loot rate | 6 | **~66×/hr** | economy | broken | config |
| **Antarchy** | Ultimate Armor + free Prot V ×4 | ~4.7× effective HP | 6 | **0.78** | survivability | broken | config |
| **Gateways to Eternity** | Hellish Fortress, 95 wither-skel rolls | 2.4–5.2 skulls per 1 in | 12 | **~0.4×/hr** | economy | broken | datapack |
| **Epic Knights** | Steel jousting plate, 22 armor + **KB immunity** | 1.1× armor + mechanic deletion | 2 | **0.55** | survivability | broken | config |
| **Confluence: Otherworld** | Life Crystals → 60–100 HP | 3–5× HP | 10 | **0.50** | survivability | broken | cut-op |
| **Macabre** | Ferrum → Gargamaw, 108 armor / 60 HP | ~5× | 12 | **0.42** | survivability | broken | cut-op |
| **Artifacts** | Power Glove + Feral Claws | 2.10× DPS *(1.5× if hands = 1 slot — **unverified**)* | 6 | **0.35** | damage | hot | config |
| **The Awakening** | Reaper ×6.2 abilities / Exosavant flight | ~3× | 20 | **0.15** | mixed | hot | config |
| **Simply Bows** | Buzzkill + Chaos rune + 5 frames | ~2× (crowd/CC) | 15 | **0.13** | mobility/CC | hot | gate |
| **Grim and Bleak** | Thunder Sword, 25 base + 10–40 charge | 3.1× base, 5.8× charged **(unverified — closed source)** | 25 | **0.12** | damage | hot | gate |
| **Expanded Combat** | Netherite Dancer's Sword, 22 DPS | 1.72× | 15 | **0.11** | damage | hot | cut-dup |
| **Apotheosis** | Mythic affix stack + Executing | 3.7–5.7× | 45 | **0.10** | damage | band (top) | config |
| **Iron's Spells** | Geared Lightning Lance ~66 dmg | ~3× ranged | 50 | **0.06** | damage (ranged) | band | config |
| **Aether** | Netherite-parity gear + 10 Life Shards (40 HP) | 1.5× (HP) | 30 | **0.05** | survivability | band | config |
| **Apothic Enchanting** | Sharp 9 + Smite 10 stacked | 1.85× vs undead | 40 | **0.046** | damage | band | config |
| **The Undergarden** | Utherium armor (netherite-equal) | 0.94× — weapons **below** netherite | 25 | **0.038** | building/utility | band (low) | keep |
| **Paradise Lost** | Surtrum: 8 dmg, 16 armor / 0 toughness | 0.70× *(Soul Blade outlier, §4.14)* | 20 | **0.035** | exploration | **cold** | cut-dup |
| **Deeper & Darker: Spellbooks** | Warden Mage set, 24 armor / 16 tough | 1.3× | 45 | **0.029** | mixed | band | config |
| **Ars Elemental** | Heavy Elemental, 25 armor / 16 tough | 1.3× | 60 | **0.022** | magic/utility | band (low) | config |
| **Simply Swords** | Awakened Unique + Runic + Omen execute | 1.4× DPS + execute | 80 | **0.018** | damage | **cold** | config |
| **Eternal Starlight** | Moonring Greatsword 12.6 DPS, netherite armor | 0.98× | 55 | **0.018** | exploration/cosmetic | **cold** | config |
| **Twilight Forest** | Fiery / Yeti (netherite parity) | 1.0× | 60 | **0.017** | exploration | **cold** | config |
| **Ars Nouveau** | 19-dmg nuke, 20 armor / **0 toughness** | 0.80× | 60 | **0.013** | automation/utility | **cold** | config |
| **Knaves' Needs** | Warden Katana — **1 damage** (tier stubbed at 0.0) | 0.15× | n/a | **~0** | broken | broken | cut-dup |
| **Better Combat** | 3–5× crowd DPS; single-target = vanilla | n/a — multiplier layer | 0 | n/a | system | — | keep |
| **Simply Tooltips · SS Reforged · Skeleton Uses Custom Bow** | cosmetic / fidelity | 0 | 0 | 0 | none | — | keep |

**Read the two ends, not the middle.** Everything from Deeper and Darker down to Artifacts pays a full track's reward inside one evening. Everything from Simply Swords down pays *less than a netherite sword* for 55–80 hours. Those are the same defect wearing different clothes.

**Reference point for every row:** L_Ender's Cataclysm's endgame Infernal/Void Forge is **13 dmg @ 1.0 = 13.0 DPS**, which does *not* beat a Sharpness V netherite sword (18 DPS) — after 40–60 hours and 8 bosses. That restraint is why the group likes it, and it is the yardstick. **If a track pays more per hour than Cataclysm, it is wrong.**

### 2.1 UNPRICED TRACKS — mods being kept that have no hours estimate at all

The parity table covers 27 tracks. The pack ships ~120 mods. Most of the remainder are genuinely
unpriceable because they have no reward ladder (JEI, Jade, Xaero's, Block Pack, Visual Health, the
resource packs) — those need no `H` and none is invented for them below.

**But these do have a reward ladder, are marked `keep`/`decide`, and were never priced.** Every one
is a hole in the parity claim, and one of them (Aquamirae) is the mod Leyton was *most* excited
about. Listing them honestly beats fabricating hours for them.

| Unpriced track | Why it needs an `H` | How to get one cheaply |
|---|---|---|
| **Aquamirae** | Full dungeon + biome + gear mod. Leyton's top pick (😂). Zero numbers in this audit. | Creative-inspect its gear tooltips; ask Leyton to post his hour count at first Ship-of-Storms clear (§Doc 01 6.5). |
| **Cult of Azazel** | A **boss** mod in the Nether stack. Bosses imply drops; drops imply a rate. Completely unmeasured. | Same. Highest priority of this list — an unmeasured boss mod is exactly how a second Antarchy gets in. |
| **When Dungeons Arise** | The anchor structure mod; drives the whole early loot economy for six players. | Measure loot-per-hour empirically in week one, not from a wiki. |
| **Mowzie's Mobs** | Called "one of the best-behaved tracks on the list" — on vibes. ~15 h appears in §5.4 with no `P` anywhere. | Creative-inspect the Ice Crystal / Sol Visage / Umvuthi drops. |
| **Cobblemon** | 60+ h in §5.4, its own currency, but **absent from Doc 01's rate table and absent from the Track Menu**. If someone picks it they are unpriced against everyone. | Doesn't need a `P` — needs an explicit "this is its own game" line in the menu. |
| **Minecolonies** | 40+ h in §5.4, no rate row, no menu-fair-swap partner besides Epic Knights. Also the #1 TPS risk. | Decide it in or out first; pricing a mod you may cut is wasted work. |
| **Ars Elemental** | Priced in this table (0.022) but **has no row in Doc 01 §1.6 and no Track Menu entry**, despite a 25-armor/16-toughness set that beats netherite. | Add to both, or fold it into the Ars Nouveau track explicitly. |
| **Deeper and Darker (main track)** | Doc 01 prices the *Sonorous Staff* but the D&D **track** never appears in the Track Menu — only "D&D: Spellbooks" does. A 20 h dimension track is invisible at pick time. | Add it to the Campaign tier once §2.1's fixes land. |
| Jurassic Reborn · Fights and Frights · Creature Feature · Primal · Ghosts · Gateway to Doom · Envelope · Fragmentum · Loot Journal · Moog's Voyager · Better Archeology · the five "Integrated" mods | All `decide`, all unaudited. Mostly low-surface, but *unaudited is not the same as safe*. | Batch-audit them in one sitting before freeze, or cut the ones nobody names as a must-have. |
| **Overgrown's Origins** | 🔴 The one that actually matters. Permanent character-creation abilities = The Awakening's structural shape, but granted at **hour zero** with **no `H` to divide by**. A zero-hour reward has an *undefined* rate, which under Rule 1 is an automatic block. | Audit or cut. Do not ship an unaudited origins mod into a rate-parity pack. |

---

## 3. PARITY BANDS

"These tracks are roughly interchangeable, pick what sounds fun." Inside a band that has to be a true statement or the hub premise dies.

### SHORT — 5–15 hours · expected payoff ≈ **1.1–1.3× netherite**
| Track | Actual payoff | Fit |
|---|---|---|
| Aquamirae (dungeon/biome) | insufficient data | assumed fit |
| Goblin Traders · Bountiful · Guard Villagers | economy + QoL | fit |
| Farmer's Delight + Oceans Delight | food/buff economy | fit |
| Better Archeology · Block Pack · Naturalist | cosmetic / ecology | fit |
| Small Ships · Waystones | mobility | fit |
| **Epic Knights (steel plate)** | **KB immunity at 2h** | 🔴 misfit |
| **Macabre (ferrum)** | **beats netherite at 4h** | 🔴 misfit |
| **Antarchy (Ultimate Armor)** | **4.7× at 6h** | 🔴 misfit — 4× the band |
| **Artifacts (Power Glove + Crystal Heart)** | **2.1× at 6h** | 🔴 misfit |
| **Apothic Spawners** | **~400× loot rate at 6h** | 🔴 misfit |
| *Alex's Caves* | **N/A — no 1.21.1 build** | — |

### MEDIUM — 20–40 hours · expected payoff ≈ **1.5–2.0× netherite**
| Track | Actual payoff | Fit |
|---|---|---|
| **L_Ender's Cataclysm (partial)** | ~1.3× + abilities | ✅ **the reference track** |
| Aether (Gold Dungeons + Life Shards) | 1.5× | ✅ fit |
| Twilight Forest (through Snow Queen) | ~1.0× | 🟡 slightly cold — pays in biomes/structures |
| The Undergarden (through Utherium) | 0.94× | 🟡 cold on combat, fine on building |
| When Dungeons Arise · Towns and Towers | loot economy | ✅ fit |
| Minecolonies (functional colony) | economy | ✅ fit, different currency |
| Paradise Lost | 0.70× | 🔵 cold |
| **The Awakening** | **~3×** | 🔴 misfit |
| **Deeper and Darker** | **∞ (Resonarium)** | 🔴 catastrophic misfit |
| **Confluence · Grim and Bleak · Macabre** | 3–5× | 🔴 misfit |

### LONG — 45–90 hours · expected payoff ≈ **2.0–3.0× netherite**
| Track | Actual payoff | Fit |
|---|---|---|
| Apotheosis (to Pinnacle + mythics) | 3.7–5.7× | 🟡 hot, but honestly gated behind Wither + Dragon |
| Iron's Spells (full school kit) | ~3× ranged | ✅ fit |
| Ars Nouveau + Ars Elemental (full) | 1.3× combat, very high utility | 🟡 cold on combat, hot on automation |
| Cobblemon (full team) | collection | ✅ fit, entirely its own currency |
| **L_Ender's Cataclysm (all 8 bosses)** | **~1.3×** | 🔵 **cold — and this is the problem** |
| **Eternal Starlight (full)** | **0.98×** | 🔵 cold — 55h *post-Dragon* for netherite parity |
| **Simply Swords (awakened + socketed)** | **1.4×** | 🔵 cold |

**The loudest structural misfit:** the pack's design anchor (Cataclysm) sits in the *cold* half of the long band. Every generous mod on this list reads as broken specifically because Cataclysm is restrained. You can fix that from either end — nerf the generous mods, or buff Cataclysm's drops. Nerfing is safer here because Cataclysm's restraint is what the group says they like.

---

## 4. PARITY BREAKERS

### 4.1 Deeper and Darker — **OVERPAYS, catastrophically** 🔴
**Direction:** overpay. **Magnitude:** unbounded.

Verified in shipping 1.4.1 source (`DeeperDarkerEvents.livingDamageEvent`):

```java
float reduction = incoming / 4;                    // computed ONCE, outside the loop
for (ItemStack stack : entity.getArmorSlots()) {
    if (... stack.is(DDTags.Items.RESONARIUM_ARMOR)) {
        incoming -= reduction;                     // subtracted once PER PIECE
    }
}
```

No clamp, no piece counter, no break. Four pieces → `incoming − 4×(incoming/4)` = **0**. A separate `ArmorHurtEvent` handler zeroes durability loss on the same set. The only escape hatch is `DamageTypeTags.BYPASSES_ARMOR`.

Acquisition (corrected): **diamond** base gear + a `RESONARIUM_UPGRADE_SMITHING_TEMPLATE` that has no from-scratch recipe and must be found as structure loot, + 16 Resonarium + 16 Scutes. Harder than first reported, still trivially cheap for what it grants. **One counterweight the mod does ship:** `resonarium_excludes` bans Protection, Blast/Fire/Projectile Protection and **Mending** from the set.

Also in this mod:
- **Sonorous Staff** — 50 base / **87 with Volume III**, piercing AoE, 22–51 block range, **1-second cooldown**, 66.7% damage even at max range. Kills a Wither in 4 shots. Uses `sonicBoom`, which *is* in `bypasses_armor` — so it ignores armor entirely and, amusingly, is the one thing that pierces Resonarium.
- **Warden Leggings** — `MOVEMENT_SPEED 0.05 ADD_VALUE` on a 0.1 base = **+50% walk speed**, not the "+5%" every third-party wiki reports.
- **Warden Armor** — 24 armor / 16 toughness / fire-resistant, exceeding Epic Knights' and Simply Swords' intended ceilings.
- **Sculk Transmitter** — remote access to any container or workstation, and as of 1.4 "able to link to other modded containers." Undercuts Waystones and both backpack mods.

**Fix — highest-value single action in this audit:**

```json
// datapack: data/deeperdarker/tags/item/resonarium_armor.json
{ "replace": true, "values": [] }
```

Kills the handler outright; dimension, mobs, structures, Warden gear all survive. **No config option exists** — datapack is the only route. Separately, datapack-remove the Sonorous Staff recipe or accept 87-damage piercing AoE on a 1s cooldown.

### 4.2 Antarchy — **OVERPAYS** 🔴
Config fields are modifiers on the player's 1.0 base, so displayed = config + 1.

- **Ultimate Sword** 35 dmg @ 1.6 = **56 DPS** (4.4×). Netherite-gated — almost defensible.
- **Big Bertha** 63 @ 1.0, 6-block reach, plus undocumented 2.0× strike (~126) and 1.35× AoE spin (~85). **Leave it alone** — it is gated behind ~19 boss/mob drops across three sub-recipes. That is a legitimately earned endgame.
- **Ultimate Armor** = 6+11+9+6 = **32 armor, 18 toughness, 0.6 KB resist**, and `inventoryTick()` re-applies **Protection 5 / Fire Prot 5 / Projectile Prot 5 / Blast Prot 5 every tick**. 20 EPF = the **80% enchant cap**; vanilla-legal max is Prot IV ×4 = 64%. Against a 40-damage boss hit: netherite + Prot IV takes 7.5, Ultimate takes **1.6**.
- **Cost:** 11 uranium + 13 titanium ingots. **Zero netherite, zero bosses, zero dimensions.** Ore is `needs_iron_tool`, uniform Y −64→32, 13 veins/chunk, `discard_chance_on_air_exposure 0.0` (visible in cave walls). ~98 ore blocks with Fortune III.
- **`DuplicatorTreeLogic`** — live, default-on, 10% per random tick, duplicates any full-cube block in the 8-cell ring around a center log. The blacklist protects only technical blocks; **netherite, diamond, uranium and titanium blocks are all valid sources.** AFK-able infinite duplication.

**Claim refuted:** the Hoverboard is *not* flight — `MAX_HOVER_HEIGHT = 5.0` clamps to 5 blocks above terrain at ~22 m/s. It does not threaten Waystones or exploration mods.

**Fix (config only — `AntarchySettings.java` exposes 48 toggles and 407 numeric fields):**
- `ultimateArmorComesEnchanted = false` ← single highest-leverage line
- armor values → 3 / 8 / 6 / 3 (netherite parity)
- `ultimateSwordAttackDamage` 34 → 11 · `ultimateAxeAttackDamage` 42 → 13
- disable the duplicator tree
- **do not touch Big Bertha**

### 4.3 Apothic Spawners + Gateways to Eternity — **OVERPAY, and specifically *together*** 🔴
Vanilla spawner: 4 mobs / ~499.5 ticks = 0.0080 mobs/tick. Fully modified: 16 mobs / 20 ticks = 0.80 = **~100× spawn rate** (exact, verified against vanilla NBT defaults). `Echoing` III adds 3 extra `dropFromLootTable` calls with **`hitByPlayer = true`**, so player-kill-only drops *and* Looting apply to every roll → **~400× loot rate**. Modifier costs — sugar, clocks, fermented spider eyes — are all pre-Nether.

Gateways' `hellish_fortress` pays **95 wither_skeleton entity loot rolls** for a pearl costing **one** wither skeleton skull. At 2.5% base / 5.5% with Looting III that is **2.4–5.2 skulls out per 1 in** — a self-sustaining exponential skull engine, entirely independent of the (probably non-functional, 1.20-era NBT format) Wither Skeleton Spawner reward. Plus 65 blaze rolls for 3 spent rods. Looting applies to gateway entity_loot too, so the enderman gateway's expected value is ~440 pearls for a ~5-pearl input.

**Sibling tracks destroyed:** every exploration mod at once — WDA, Deeper and Darker, Aquamirae, Twilight Forest, Undergarden all sell "go to the dangerous place, get the drop." One silk-touched spawner turns a one-time structure into a permanent factory. Apotheosis' XP-priced economy collapses under infinite XP.

**Mitigation the research undersold:** Apotheosis' Capturing spawn eggs are 0.5%/level to a max of **1.5% per kill** — retyping a spawner to a rare modded elite is a genuine grind, not a formality.

**Fix:**
- `ASConfig.spawnerSilkLevel = -1` — **one line**, removes spawner harvesting entirely. Or keep harvesting and cap `echoing` at max_level 1 via the datapack modifier JSON.
- Gateways: datapack-override `hellish_fortress` reward rolls down ~80%, or strip the wither-skeleton entity_loot entries.
- Also fix **`emerald_grove`**, which *underpays* badly (16 hay bales and some carrots for a 4-wave fight). Farm animals vs an infinite skull engine, same effort — the group's fear reproduced inside one mod.

### 4.4 Epic Knights — **OVERPAYS on a mechanic, UNDERPAYS on damage** 🟡🔴
First-pass research used raw config attack speeds and ignored `− density × sizeFactor`. Corrected: **not one netherite-tier Epic Knights weapon reaches a netherite sword's 12.8 DPS.** Concave-Edged Halberd is 15.41 dmg @ **0.65** = **10.0 DPS**, not the claimed 13.9. Add the default-on two-handed penalty — which triggers whenever the offhand holds *anything*, including a torch or food — and a netherite halberd with a shield is **5.6 DPS**. The weapons are underpowered, not over.

**The break is knockback.** `knockbackResistance` is **0.5 per piece** on knight/gothic/kastenbrust/armet and **1.5 per piece** on jousting/stechhelm. Vanilla clamps at 1.0 = total immunity. **Two pieces of steel plate = permanent 100% knockback immunity.** And the true craftable ceiling is higher than first reported: **jousting + stechhelm are plain steel-plate recipes** (no netherite, no template) = **22 armor / 8.0 toughness / knockback immunity for ~56 iron ingots**. Against a 20-damage hit that is 68% reduction vs full netherite's 64%; at 40 damage they tie.

**Sibling tracks it makes look bad:** Cataclysm (boss knockback phases become non-events; 15h of Ignis for Ignitium vs 2h at a crafting table), Mowzie's Mobs, and vanilla netherite itself.

**Fix — find-and-replace in `armor.json`:** `knockbackResistance` → `0.1f` on knight, gothic, kastenbrust, armet, sallet, grandBascinet, ceremonial, ceremonialArmet, **jousting, stechhelm, maximilian, maximilianHelmet**. Optionally drop jousting/stechhelm defense to 3/6/9→2/5/8. **Leave the weapon numbers alone** — nerfing them deepens the underpay. Ignore any advice about stacking reach: `MedievalWeaponItem.getBonusAttackReach()` returns `0.0f` when Better Combat is installed, so reach bonuses are auto-disabled in this pack.

### 4.5 Artifacts — **OVERPAYS** 🟡
Power Glove +4 flat damage · Feral Claws +40% attack speed · Crystal Heart +10 max HP · Cross Necklace 3× i-frames · Steadfast Spikes 100% knockback resistance. All from **pillager outposts** — `pillager_outpost.json` is a 25%-base injection drawing from a 10-item pool containing *both* Power Glove and Crystal Heart. Findable in hour 2–6 with stone gear.

**Three corrections that matter:**
- The 2.10× figure assumes two Curios "hands" slots. Curios natively defaults to 1 and no `data/curios/slots/` JSONs exist on the Artifacts 1.21.1 branch. **If hands is 1 slot, the real number is 1.5×. (unverified — check in-game.)**
- **Artifacts requires Curios on 1.21.1** despite all deps being marked "optional" — the flags mean "any one of these satisfies it." Ship without it and the mod loads inert. Budget the extra slot.
- **Config is TOML (`config/artifacts/items.toml`), not game rules.** The game-rule docs describe pre-1.20.6.

**The real worst offender is Antidote Vessel, not Power Glove.** Power Glove's flat +4 decays in relative value as the pack's tiers climb (+50% on netherite, +20% on a Cataclysm weapon) — loudest exactly when it matters least. Antidote Vessel caps **every** negative status effect at 5 seconds: categorical immunity to an entire axis of boss design, in an uncontested slot, getting *more* valuable against harder bosses.

**Fix:** `power_glove.attackDamageBonus` 4→2 · `crystal_heart.healthBonus` 10→4 · `antidote_vessel.maxEffectDuration` 5s→30s (or remove from loot) · `steadfast_spikes.knockbackResistance` 10→3 · datapack the pillager-outpost/shipwreck injections to move Power Glove and Crystal Heart into bastion/end-city tables only.

### 4.6 Simply Bows — **OVERPAYS relative to its own sibling** 🔴
The cleanest RATE failure in the audit, because both sides share an author and a pack.

Per-arrow damage is *below* vanilla by design (base 1.5–2.0, arrow speed multiplier 0.48–0.95). The break is acquisition: every `minecraft:chests/*` gets 20% Enchanted Bow String, 20% Reinforced Bow Frame, 3% Rune Etchings, 2% unique bows — **plus 15% boosted rolls for thematic bows in villages, mineshafts, shipwrecks and igloos.** Hour-one content. Frame upgrades multiply ability damage by `1 + level × 0.55`; five levels = **3.75×**, putting Buzzkill's chaos dive at ~60 damage every 0.6 seconds inside a Regeneration aura.

**The sibling it makes look bad is Simply Swords.** Melee: 0.05% baseline Unique → 8 Runic Tablets to awaken → a second Unique to smelt for a gem = **60–120h**. Ranged: walk into a mineshaft, 15% per chest, 20% per chest on upgrades = **10–25h for a maxed kit**. Same author, same currency, one-fifth the cost.

**Unresolved and it matters:** the Echo bow config exposes `painExplosionBaseHpDamage 0.16`, `painExplosionFrameHpDamage 0.06`, `painExplosionMaxDamageRatio 0.55`. The naming implies **percent-of-max-health** explosion damage; the implementation was not found in `EchoBowItem.java`. If it is percent-max-HP it melts every high-HP boss in the pack proportionally and becomes the single worst item audited. **(unverified — test in singleplayer before launch.)**

Also: `enableNonPlayerBowUse` defaults **true** at 50% — skeletons get unique bows and fire abilities at 0.5× damage. A stealth early-game difficulty spike, stacking on Simply Entity Equipment's 3.7–5.3× skeleton health multipliers.

**Fix:** `baseUniqueBowChance` 2.0→0.5 · `boostedBowChance` 15.0→4.0 in village/mineshaft/shipwreck (or restrict boosted rolls to Ancient City / End City) · `damageMultiplierPerFrame` 0.55→0.25.

### 4.7 Confluence: Otherworld — **OVERPAYS, and violates consent** 🔴 CUT
Adamantite/Titanium Sword **36 damage @ 2.4** — verified `SwordItems.java` L94/L96; `BaseSwordItem` applies `rawDamage−1` and `rawSpeed−4` as ADD_VALUE on bases of 1 and 4, so registered values *are* final. 86.4 paper DPS, ~72 effective after i-frames — still **5.6×**. Pre-hardmode peak Night's Edge is 25 @ 2.5 = **62.5 DPS, 4.9× netherite, before the Wall of Flesh.** All `ModTiers.UNBREAKABLE` with `DataComponents.UNBREAKABLE` applied at registration — no durability economy at all. Adamantite armor 29 points / 8 toughness; **Molten armor is 25 points at Hellstone tier**, already past netherite.

**Life Crystals are the real problem.** `EverBeneficialItem` does `MAX_HEALTH += crystals × 4.0` as a permanent modifier, capped at 15 crystals + 20 fruits = **100 HP**. Hardcoded in Java — **no datapack can retune it.** They generate in ordinary Overworld caves with no gate, and they are tradeable. The mod's own event gates (`slimeRainEventRequiredPlayerMaxHealth = 28`) prove the health inflation is load-bearing, not patchable. And `allowsVanillaEntitiesToPerformStageAttributes` defaults **false**, so Confluence's compensating mob scaling does *not* apply to Cataclysm/Aether/Twilight mobs — a 36-damage sword hits them at full value.

**The consent problem:** `HardmodeConvertor implements IGlobalData` and iterates ChunkPos/ChunkMap. Two players kill the Wall of Flesh and **the entire server flips to Hardmode** — six new worldwide ores, spreading Corruption/Crimson/Hallow biomes with block conversion tables that will progressively eat Terralith terrain over months, and raised hostile difficulty. Four players mid-Cataclysm never opted in and cannot opt out.

*(Correction: Rocket Boots are a 1.8-second timed hover with `couldGlide = false`, not true flight. The mobility claim was overstated. Doesn't save it.)*

**Verdict: cut-op.** Hardcoded max-health and an irreversible global world flip are not tunable.

### 4.8 Macabre — **OVERPAYS + breaks other mods mechanically** 🔴 CUT
Full-set totals from `macabrefix-armor-common.toml` — armor / toughness / KB resist:
`ferrum 23/16/1.2` · `symbiotic 35/20/0` · `bloodClot 53/24/4.0` (**villager-purchasable**) · `abhorrent 71/26/4.0` · `baalCursed 91/28/12.0` · `gargamawPutrid 108/26/20.0`. Netherite: 20/12/0.4.

Set bonuses: `morphegorAttackDamage = 11.0` (flat +11 to **any** held weapon — a netherite sword becomes 19 base, ~22.25 with Sharpness V, ~35 DPS), `valamonAttackSpeed = 4.0` (doubles base attack speed, erases the combat cooldown), `gargamawMaxHealthTier2 = 40.0` (+20 hearts), `gomoriaEntityReach = 3.0`.

Entry is an overworld surface Gut Dungeon — no portal fuel, no boss prerequisite. **Ferrum beats netherite at ~4 hours.**

**The mechanical break is worse than the numbers.** The community patch's headline fix is "stopping Macabre's generated full set armor procedure from **resetting player attribute base values every tick**." That silently nulls Curios-sourced stats while worn — Artifacts, Apotheosis affixes, Iron's Spells buffs, Epic Knights modifiers, Awakening relics. On 1.21.1 NeoForge there is no config to turn any of it down.

**Verdict: cut-op.** David's "maybe, seems kinda power creepy" was right by an order of magnitude.

### 4.9 Grim and Bleak — **OVERPAYS + irreversible global state** 🔴 GATE OR CUT
Thunder Sword, from the official changelog verbatim: *"regular damage is nerfed: 30 → 25"* and *"additional damage now scaling with charge, going from 10 to 40."* A later version raised both further. **25 base = 3.1× a netherite sword**, up to ~65 charged, and the charge release also grants scaling **regeneration + resistance**. Carbon Blood Sword: 10 damage + a 20-block teleport + 20% crit Bloodlust.

**Armor values are completely unpublished.** MCreator mod, closed source, no wiki, no source tree. First-party prose claims Heavy Darksteel is "slightly better than netherite in terms of protection" and Carbon Blood has "more protection and toughness than Netherite." **(unverified — must be measured in-game with a tooltip mod before any decision.)**

Portal frame is **Chiseled Deepslate** — a vanilla stonecutter product available in hour one.

**Irreversible:** killing the Gate Guardian triggers Dimensional Breaching, permanently spawning hostile abominations in the Overworld **every night, for all six players, forever**, with no documented revert and no config. Same consent failure as Confluence. Separately, "killing villagers restores your worthiness" turns Minecolonies colonists into a farmable ritual resource.

**Fix if kept:** datapack-remove the Thunder Sword and Carbon Blood Sword recipes; re-gate the Compass of Pains behind a Nether Star. You cannot fix the item damage from a datapack — it is Java-side. **Recommend cut.**

### 4.10 Eternal Starlight — **UNDERPAYS** 🔵
Post-Ender-Dragon gate. 40–70 hours. Ceiling: **Moonring Greatsword 10.5 dmg @ 1.2 = 12.6 DPS** — a netherite sword is 12.8. Unrealium, the mod's own "strongest material," produces a sword of **exactly 8 damage @ 1.6**, byte-identical to netherite. Starlit Diamond armor is **20 armor / 3 toughness / 0.1 KB** — identical to netherite. The mod pays in 22 biomes, 19 music discs, 4 armor trims, tameable moths and machinery.

**Sibling that makes it look bad:** Apotheosis, paying 3.7–5.7× for comparable hours with no dimension gate at all.

**One outlier the other way:** the **Starfall Longbow** fires arrows summoning 9 Aethersent Meteors *directly onto the hit entity*, and natural meteors are documented at **50 damage each, ignoring invulnerability frames**. If summoned meteors share that damage — the wiki says they differ only in dropping no aethersent — that is ~450 single-target burst per arrow, a boss-deleter that skips Cataclysm's, Mowzie's and Cult of Azazel's designed fights. **(composite figure unverified.)** `playerAethersentMeteorDamageScale` is player-scoped and **will not fix it**. Datapack-remove the recipe or verify in-game.

**Ambush hazard:** the Gatekeeper auto-spawns within 50 blocks of Portal Ruins — 5 structure sets at spacing 36 / separation 30 in plains, desert, forest, snowy and jungle, i.e. exactly where people settle — and per the wiki is **undefeatable pre-Dragon**. Six players scouting Waystone and Minecolonies sites *will* run into an invulnerable 175 HP boss. Check `GatekeeperConfig.canAlwaysHurtWhenFighting`.

**Fix — buff, don't nerf:** shorten the gate. Drop the Gatekeeper's Ender Dragon prerequisite to "has visited the End," or hand the track a compensating loot-table reward. A 55-hour track must not end at 0.98×.

### 4.11 The Undergarden — **UNDERPAYS** 🔵
Every weapon at or below a netherite sword. Best sustained is the Utherium sword at **7.5 dmg × 1.6 = 12.0 DPS** (netherite 12.8). Highest single hit is the Forgotten Battleaxe at **11.0 @ 0.6 = 6.6 DPS** — half a netherite sword. The Forgotten and Utherium 1.5× multipliers apply **only to Undergarden entities**, so they cannot be carried into anyone else's boss fight. Utherium armor is netherite-equal on points and toughness but loses knockback resistance and fire immunity.

Its one shortcut: netherite-equivalent defense in ~8–12h with no Nether trip. That is a shortcut, not a break.

**Fix:** either accept it as the building/exploration track and **say so out loud before someone picks it**, or datapack +1.5 attack damage onto the Utherium and Forgotten tiers so 15–30 hours produces at least netherite-parity offense.

### 4.12 Ars Nouveau — **UNDERPAYS on combat; the currency mismatch is the real issue** 🔵
The Enchanter's Sword is `new EnchantersSword(Tiers.NETHERITE, 3, -2.4F)` — **byte-for-byte a netherite sword**. Every damage glyph hard-caps `AugmentAmplify` at 2, so the single-glyph ceiling is Flare at 13 + 6 from a max Spell Damage thread = **19**. And **all three armor sets have 0.0 toughness and 0.0 knockback resistance** — Battlemage is 20 armor / 0 toughness against netherite's 20 / 12.

Two players at 50h in Ars come out as glass cannons who die to one Cataclysm boss hit the melee players shrug off. The mod pays in Drygmy automation, Storage Lecterns, warp portals and Source infrastructure — **a different currency, not a smaller amount of the same one.**

**Fix:** don't buff the damage (the 2-Amplify cap is doing free balance work). Instead:
- Tell the group **before they pick** that Ars is the automation/logistics track and will not produce combat parity.
- Plug the two genuine leaks: **Drygmy Charms** bypass every "kill the mob to get the material" gate in Cataclysm / Mowzie's / Aquamirae (fix: `drygmy_blacklist` datapack), and **Stable Warp Scrolls** make Waystones decorative (fix: `warp_portals.enableWarpPortals = false`).
- Note Ars armor's **enchantability 30** is double netherite's 15 — with Apothic Enchanting's raised caps it is the best enchant substrate in the pack. Check what Apotheosis rolls onto a 30-enchantability chestplate before shipping.

### 4.13 Simply Swords — **UNDERPAYS on stats, breaks bosses on a mechanic** 🟡
Peak is a 14-damage / 0.8-speed greathammer (11.2 DPS, *under* a netherite sword). Highest sustained is a plain netherite Cutlass/Katana/Twinblade at 8–9 dmg × 2.0 = **16–18 DPS**. 60–120h to fully awaken and socket one Unique. **This track underpays.**

But `OmenEffect.java`:

```java
if (pLivingEntity.getHealth() <= pthreshold && pPlayer != null) {
    pLivingEntity.damage(DamageSource.GENERIC, 1000);
}
```

`pthreshold` = 25% of max health, `omen_chance` = 75% per hit. **No boss check, no player check, no health cap.** The Watching Warglaive is chest loot. This deletes the last quarter of every boss in the pack — Cataclysm, Mowzie's, Aether, Twilight Forest, Eternal Starlight, Cult of Azazel, the Wither, the Dragon.

**Fix:** `omen_instantkill_threshold` 0.25 → 0.0 (or `omen_chance` → 0.0). Set `add_weapons_to_loot_tables = false` so it stops diluting Twilight Forest / Undergarden / Cataclysm / WDA chests with a generic weapon lottery — that dulls the reward identity of the exact structure mods the campaign is built on. Then **accept the underpay knowingly**, or shorten the awakening chain from 8 Runic Tablets to 4.

### 4.14 Paradise Lost — **UNDERPAYS, with one uncapped outlier** 🔵
Craftable ceiling: Surtrum sword **8 dmg @ 1.6** (exact netherite parity, 827 durability vs netherite's 2031) and Surtrum armor **16 armor / 0.0 toughness** — below vanilla *diamond*. Olvite armor at 14 points is worse than iron. After 15–25 hours with **no bosses at all**.

The outlier: the **Soul Blade** does `super.getBonusAttackDamage() + soulCount × 0.25F`, one soul per **distinct EntityType** ever killed with it, **uncapped**. Devs balanced for ~50 souls (16 damage, per their own advancement). On a 150-mod pack with Cataclysm, Mowzie's, Jurassic Reborn, Twilight Forest, Undergarden, Deeper and Darker, Aquamirae, Grim and Bleak and Cult of Azazel, the distinct-type count is plausibly 250–500 → **60–90 damage. (count is an estimate, the `× 0.25F` scalar is verified source.)** Its power is literally a function of how many mods you install.

Two important constraints found on verification, both of which *reduce* the threat: the blade has no recipe and no loot table — it comes only from a Sentinel in a Palace at a 12.5% hand-drop chance, and Sentinels never spawn naturally. And souls accrue only to the **wielder's own** kills, so the "teammates feed the blade" scenario is mechanically impossible.

Also missed in the first pass: the **Totem of Levitation** fully cancels any fall damage ≥10 *and* void death, in the Overworld and End, and is farmable from Birdcage tomb chests. That devalues fall-damage risk pack-wide.

**Verdict: cut-dup** — it is a third skylands dimension behind Aether and Twilight Forest, its craftable gear is worse than diamond, and its NeoForge build is a **Sinytra Connector repack of a Fabric jar that has never had a stable release for any MC version**. That is unacceptable on a months-long world.

---

## 5. SECOND-ORDER RISKS

### 5.1 Reward-axis mismatch — equal magnitude, wrong currency
Five distinct currencies turned up. Equal-magnitude payouts in different currencies still read as unfair.

| Axis | Tracks paying in it | Risk profile |
|---|---|---|
| **Raw damage** | Cataclysm, Apotheosis, Simply Swords, Iron's Spells | Legible, comparable, low friction |
| **Survivability** | Epic Knights (KB), Aether (Life Shards), Deeper and Darker, Antarchy, Macabre | Invisible until someone stops dying |
| **Mobility / access** | Iron's Spells (Angel Wings), Awakening (Exosavant), Waystones, Small Ships, Apothic Attributes (Potion of Flying) | Devalues **everyone's** exploration, not just its own |
| **Economy / automation** | Ars Nouveau, Minecolonies, Apothic Spawners, Gateways, Farmer's Delight | Compounds silently; looks weak for 30h, then owns the server |
| **Building / cosmetic** | Undergarden, Block Pack, Eternal Starlight, Better Archeology | Pays nothing the combat players can perceive |

**Worst named pair: Ars Nouveau (automation, 60h, 0.8× combat) vs Apotheosis (raw damage, 45h, 3.7–5.7×).** Both are "long tracks." One player ends with a Drygmy pen and zero armor toughness; the other one-shots things. Neither number is wrong in isolation.

**Second worst: The Undergarden (building, 25h) vs Deeper and Darker (survivability, 20h).** Identical pitch — subterranean dimension, gear ladder. One pays decorative blocks; the other pays invulnerability.

**Third: Eternal Starlight (cosmetic collectathon, 55h) vs Iron's Spells (raw ranged damage, 50h).** If the ES pair are power-motivated rather than explorers, they will feel shorted and no config fixes it.

**Mitigation:** publish the axis alongside the track when people pick. "Ars Nouveau is the automation track; it will not make you hit harder" is a two-sentence fix that prevents a two-month resentment.

### 5.2 Shared-world loot gifting — the divide-by-six problem
This is the axis nobody raised, and it changes the effective cost of half the list.

**FREELY GIFTABLE — effective cost ÷ 6:**
- Antarchy Ultimate Armor (one miner outfits everyone)
- Macabre prophet sets · Grim and Bleak Thunder Swords · Deeper and Darker Resonarium sets and Sonorous Staffs
- **Confluence Life Crystals** — a consumable that permanently rewrites max health. Worst gifting case in the audit.
- Artifacts trinkets (one lucky pillager outpost equips the group)
- **Apothic Attributes' Potion of Flying** — brewable in bulk from a chorus farm; one player's End trip hands unlimited creative flight to all six, obsoleting the Elytra it is gated behind
- **Apothic Enchanting's echo shard 1→4 and XP bottle 1→8 / 1→32 infusions** — one player at eterna 60–100 ends XP scarcity for the server, and ends Deeper and Darker's echo-shard economy
- Every crafted weapon and armor tier on the list

**SOFT-BOUND — transferable, costly to duplicate:**
- Apotheosis mythic gear · Simply Swords Uniques (Runic Tablets are the bottleneck)
- **L_Ender's Cataclysm boss drops** — giftable, which is the important one: the 40–60h track the group most wants to protect is *aggregate-cheap*. One player clears all 8 bosses and arms the whole server. Real group cost is ~8h/player, and every generous mod above is being compared against the wrong number.

**GENUINELY PERSONAL — cost stays × 6:**
- **The Awakening** powers — bound to the player, not an item. The only truly non-transferable reward in the audit.
- Aether **Life Shards** — consumed per player; each player earns their own +20 HP
- Iron's Spells / Ars Nouveau **school progression and affinity** (gear is giftable, progression is not)
- Minecolonies colony ownership

**Rule of thumb:** any track whose capstone is a giftable *item* has its real per-player cost divided by six, making it aggregate-optimal regardless of per-player parity. Weight the parity table accordingly when the group actually splits.

### 5.3 Intra-mod RNG variance — same mod, same hours, different results
Three mods reproduce the group's fear *inside a single track*:

- **The Awakening.** Your power is **assigned at random** at 3 hearts. Reaper caps at ×6.2 ability damage, 40 HP and ×0.7 damage taken. Phytokinetic is a support healer that permanently takes **+50% fire damage**. The mod claims powers are "aimed to be equally powerful"; the numbers say otherwise. Saving grace: Catalyst rerolls cost 4 gold + 3 amethyst + 1 ender pearl. **Make sure everyone knows rerolling is cheap.**
- **Gateways to Eternity.** `hellish_fortress` = an exponential wither-skull engine. `emerald_grove` = 16 hay bales and some carrots. Same 4-wave format, same effort.
- **Apotheosis.** Rarity is a die roll; two players farming the same 20 hours can end 3× apart on weapon damage. Mitigated by the Sigil reforge economy — which is XP-priced, and Apothic Spawners makes XP infinite, converting variance into a time-in-chair grind.

Counter-example worth copying: **Simply Swords' pity counter** guarantees a Unique by the 75th eligible chest. Its 0.05% headline is misleading because the variance is *bounded*. That is good design.

### 5.4 Effort-quality mismatch — 60 hours of bosses ≠ 60 hours of grinding
The parity table's hours column treats these identically. They are not.

| Track | Hours | Effort quality | Note |
|---|---|---|---|
| L_Ender's Cataclysm | 40–60 | **Tense** — 8 designed fights; 600 HP / 25 dmg / 100% KB-resist encounters | Highest-quality effort on the list |
| Mowzie's Mobs | ~15 | **Tense** — handcrafted encounters | |
| Aether (Life Shards) | 40–70 | **Grind** — Life Shard is weight 1 of ~11; 10–20 Gold Dungeon clears | Tense fight, tedious repetition |
| Apotheosis (to mythic) | 45+ | **Grind** — loot RNG + XP economy | Bounded by Summit/Pinnacle gates |
| Ars Nouveau | 60 | **Puzzle / build** — engaging, low threat | Different effort, not lesser |
| Minecolonies | 40+ | **Management** — no threat at all | |
| Eternal Starlight | 55 | **Mixed** — 4 bosses + a 22-biome collectathon tail | The collectathon is the weak half |
| Cobblemon | 60+ | **Collection** — low threat, high time | Entirely its own currency |
| **Antarchy Ultimate Armor** | **6** | **Pure tedium** — ~98 ore blocks | Least tense, biggest payout |
| **Apothic Spawners** | **6** | **AFK — literally none** | |
| **Simply Swords (awakening)** | **60–120** | **Grind** — 8 Runic Tablets + a second Unique to smelt | Long + tedious + underpaid |

**Two squares to act on:** Simply Swords (long, tedious, underpaid — worst square on the board) and Antarchy (short, tedious, massively overpaid — the opposite worst square).

---

## 6. REDUNDANCY DECISIONS

| Category | Candidates | **CALL** | Reasoning |
|---|---|---|---|
| **Backpacks** | Sophisticated Backpacks (DJ), Traveler's Backpack (Dan) | **Sophisticated Backpacks. Cut Traveler's.** | Shares an upgrade system and library (`Sophisticated Core`, build 2026-08-22) with Sophisticated Storage, which DJ also wants. Traveler's adds a second incompatible upgrade economy for zero functional gain. One backpack economy, one library. |
| **Magic mods** | Ars Nouveau (Dan), Ars Elemental (Dan), Iron's Spells (DJ), Ars 'n Spells (David), Ars Elixirum (Leyton), T.O Magic (David), D&D Spellbooks (DJ) | **Keep Ars Nouveau + Ars Elemental + Iron's Spells + D&D Spellbooks. CUT Ars 'n Spells, Ars Elixirum, T.O Magic.** | The two magic mods do genuinely different things — Ars is automation/utility with a hard 2-Amplify damage cap; Iron's is a ranged damage treadmill. Two distinct parallel tracks is the point of a hub. **Ars 'n Spells actively destroys that**: it merges the mana pools and lets Iron's spell-power gear multiply Ars potency up to `spell_power_cap = 3.0`, so one track's effort redeems in two currencies, and `source_jar_synergy_multiplier = 5.0` deletes Iron's mana gate via automatable Ars source. Ars Elixirum's 1.21.1 build is an **alpha from Oct 2024** while the 1.20.1 line advanced to 0.12.0 — 22 months stale. T.O Magic's 1.21.1 is a **March 2025 alpha two major versions behind**, with zero published damage numbers, and it hard-requires **Alex's Caves, which has no 1.21.1 build**. |
| **Biome generation** | Terralith (DJ), Biomes O' Plenty (David), Larion World Generation (Leyton) | **Terralith only. Cut BOP and Larion.** | Terralith is datapack-based and doesn't fight for TerraBlender injection slots. BOP + Terralith is a *known-workable* pair but doubles worldgen cost on a box already measured at 21.6 GB in use with nothing running, and worldgen conflicts produce a *wrong world* rather than a crash — you find out 40 hours in. Larion is unaudited and would be a third injector. |
| **Minimaps** | Xaero's World Map, Xaero's Minimap, Xaero's Waystones Compat (Leyton) | **Keep all three.** | Same author, designed to pair, client-side only, zero server cost, and the Waystones compat is what makes Dan's Waystones pick feel good. Only rule: **no second minimap family.** |
| **Combat overhauls** | Better Combat (David), Expanded Combat (David) | **Better Combat in. Expanded Combat OUT.** | Better Combat is a presentation layer — every bundled preset averages to a **1.00× damage multiplier**, single-target DPS is identical to vanilla, it adds zero items. Its one real cost is `reworked_sweeping` (3–5× crowd DPS), which is a config number. Expanded Combat adds a **parallel weapon ladder unlocking at netherite with no gate** (Dancer's Sword 22 DPS; an *iron* Dagger at 14 DPS already beats a netherite sword), a **+2 flat damage netherite gauntlet in a free Curios hands slot that buffs every weapon in the pack**, and it **ships zero Better Combat data** (`registerTransforms()` is entirely commented out on the neoforge-1.21.1 branch) so its weapons fall through to fallback regexes and reach double-dips. It also collides with Artifacts over the Curios hands slot. **Install exactly one Cataclysm × Better Combat compat pack** — three exist and datapack load order silently picks the winner. |
| **Weapon ladders** | Simply Swords, Epic Knights, Antarchy, Expanded Combat, Knaves' Needs, Simply Bows | **Simply Swords = primary. Epic Knights = armor only, KB nerfed. Cut Knaves' Needs and Expanded Combat. Gate Simply Bows. Config Antarchy hard.** | Five competing weapon-stat ladders with no shared balance authority is precisely how Antarchy-breaks-Cataclysm happens. Simply Swords wins primacy as an official Better Combat partner with hand-tuned combos and reach. **Knaves' Needs is cut on quality, not power** — the shipped 1.21.1 beta stubs the Warden tier at `0.0` attack bonus, producing a **1-damage Warden Katana** against Deeper and Darker's own 14.4-DPS Warden Sword. Beta-only, 5 open bugs, ~2,700 total downloads, source two versions behind the binary, and it registers 520 items on a world meant to last months. |
| **Ocean / water** | Aquamirae (Leyton), Thalassophobia (Leyton), Oceans Delight (DJ), Aquaculture (Dan), Small Ships (Dan) | **Aquamirae + Aquaculture + Small Ships + Oceans Delight. Thalassophobia cut-na.** | Four different axes — dungeon/biome, fishing economy, transport, food. No functional overlap. Thalassophobia has no 1.21.1 build (Leyton's annotation was right). Note Aquamirae and Ars Elixirum share an author (Obscuria); if Elixirum is ever revisited, check for a shared-library version conflict. |
| **Nether content** | Cult of Azazel, Incision, Nether Trials and Chambers (all Leyton), YUNG's Better Nether Fortresses + Cataclysm compat (David) | **YUNG's + Cataclysm compat + Incision + Cult of Azazel. Cut Nether Trials and Chambers.** | YUNG's rebuilds fortresses structurally, Incision adds biomes, Cult of Azazel adds mobs/bosses/structures — three layers that compose. Nether Trials and Chambers is a fourth structure injector in the same dimension: pure density stacking with no new axis, and the Nether is small. |
| **Overworld structures** | When Dungeons Arise, Towns and Towers, Moog's Voyager (Dan), Structory Towers (DJ), Dungeons Enhanced, Brass Amber Battle Towers, Ember's Floating Islands (Leyton) | **WDA + Towns and Towers + Structory Towers + Ember's Floating Islands. Moog's optional. Dungeons Enhanced and Brass Amber cut-na.** | Structure *density* is the hidden cost, not any single mod — four injectors is the ceiling before loot-per-hour goes silly. Ember's Floating Islands is safe (server-only jar, adds zero items, generates in empty sky so it doesn't fight Terralith) but **1.5.1 raised island spawn frequency** and each Flower Island grants a **free Waystone** — datapack that out. Add `Sparse Structures Reforged` and budget spacing globally rather than per-mod. |
| **Mob adders** | Naturalist, Primal, Creature Feature, Fights and Frights, Mowzie's Mobs, Ghosts, Jurassic Reborn, Cobblemon, Primal Frontier | **Mowzie's Mobs + Naturalist + one of {Primal, Creature Feature}. Primal Frontier cut-na. Cobblemon is its own decision.** | Entity density is the #1 TPS cost on a 6-player server across multiple dimensions — six spawn spheres × N dimensions. Every ambient-mob mod is additive tick cost with zero balance payoff. Pick two ecology mods, not five. Cobblemon specifically "spawns several persistent AI entities per player"; Dan's "can feel intrusive, has a ton of mobs" annotation is correct and it is a real TPS risk, not just a taste one. |
| **Enchanting / attributes** | Apotheosis suite (DJ ×4) | **Keep Apotheosis + Apothic Attributes + Apothic Enchanting. Strongly consider dropping Apothic Spawners.** | Apothic Attributes is a hard `required` dependency of Apotheosis 8.7.0, not optional. Enchanting and Spawners became optional as of 8.7.0. Note Apothic Attributes silently **rewrites global armor math** (`a/(a+armor)`; toughness no longer reduces damage at all; Protection 2.5%/point capped at 85% vs vanilla 4%/80%). Full netherite + Prot IV against a 30-damage hit now takes **7.71 instead of 4.75 — +62%**. Every boss HP/damage assumption in Cataclysm and Mowzie's is being evaluated against math their authors never tested. |
| **Loot integration** | Loot Integrations ×4 (David), Loot Journal / Pickup Notifier (David), Fragmentum (David) | **Keep Loot Integrations. Add Lootr (not on any list).** | Loot Integrations makes one loot economy span WDA / Cataclysm / villages / strongholds instead of four disjoint ones. **Lootr** gives per-player loot in shared structure chests, removing the first-to-the-chest race — on 6 players that is worth more than most single content mods. |

---

## 7. AVAILABILITY REALITY CHECK

Every mod the friends flagged, plus the ones they got wrong in the other direction.

| Mod | Their annotation | **Audit found** | Correct? |
|---|---|---|---|
| Aether 2 | 🙁 "Not Supported, could use the Base Aether instead" | **Confirmed.** The Aether II reboot's earliest build targets 1.21.8. Base Aether is fully supported and actively maintained. | ✅ right |
| Street Art (26.3) | 🙁 "Not supported" | **Confirmed.** 26.3 is a 2026 game version; no 1.21.1 build. | ✅ right |
| Crop and Kettle (1.21.8+) | 🙁 "Not supported" | **Confirmed.** | ✅ right |
| Dungeons Enhanced (26.1.2) | 🙁 "Not Supported" | **Confirmed** for 1.21.1. | ✅ right |
| Monster Expansion (1.20.1) | 🙁 "Not Supported" | **Confirmed.** | ✅ right |
| Thalassophobia (1.20.1) | 🙁 "Not supported" | **Confirmed.** | ✅ right |
| Brass Amber: Battle Towers (1.20.1) | 🙁 "Not supported" | **Confirmed.** | ✅ right |
| Primal Frontier (1.20.1) | 🙁 "neoforge counterpart only has 1 mob, rest WIP" | Insufficient data to contradict; consistent with the 1.20.1 tag. Treat as unavailable. | ✅ probably right |
| Stained Lenses (1.20.1) | 🙁 "Not supported" | Insufficient data; 1.20.1 tag is consistent. | ✅ probably right |
| Metus Oblita (1.20.1) | "Not supported" | Insufficient data; 1.20.1 tag is consistent. | ✅ probably right |
| Dark Fantasy: Nordic Tombs | 😨 "Can't find this one" | **Not found in this audit either.** No CurseForge or Modrinth project resolved. | ✅ right |
| Paradise Lost | 🙂 "1.21.1, inspired by the aether, can replace it" | **Wrong in a way that matters.** The NeoForge "build" is a **Sinytra Connector repack of a Fabric jar**, requiring Connector + Forgified Fabric API + Sherds API + Cloth Config. Filtering all 43 versions for `release` returns **zero** — the mod has never had a stable release for *any* MC version. | ❌ **overstated** |
| Skeleton Uses Custom Bows | 🙂 "Could use Simply Entity Equipment instead" | **Not an either/or — they're complementary.** SEE *supplies* modded bows to skeletons; this mod makes them *fire correctly*. Neither replaces the other. Also: this mod is **inert by default** (shipped data files set only `priority`, and `chance` defaults to 0.0). | ❌ **mischaracterized** |
| **Alex's Caves** | *(DJ, no annotation — assumed fine)* | **1.20.1 ONLY.** `alexscaves-2.0.2`, 26 Oct 2024, Modrinth shows "updated 2 years ago." Effectively stalled. **`cut-na`.** It is also a hard dependency of T.O Magic 'n Extras. | ❌ **missed** |
| **Saint's Dragons** | *(David, "Maybe, will have to be balanced")* | **No 1.21.1 build on either platform.** CurseForge shows only 1.20.1 (newest a NeoForge *alpha hotfix*); Modrinth lists 1.20.1 Fabric/Forge only. A search snippet referenced a "1.21.1 test version made for a friend, expect crashes" — not a release. **`cut-na`.** | ❌ **missed** |
| **T.O Magic 'n Extras** | *(David, no annotation)* | 1.21.1 is `Alpha-4.4.0.1` from **March 2025** while the 1.20.1 line reached 6.3.0 in Jan 2026 — 17 months and two major versions behind. Also hard-requires Alex's Caves (no 1.21.1). **`cut-na`.** | ❌ **missed** |
| **Ars Elixirum** | *(Leyton, "Alchemy 1.21.1" 😀)* | 1.21.1 NeoForge is `0.2.2 Alpha`, **Oct 2024**, empty changelog, from a mod the author describes as an unfinished Mod Jam entry — while the 1.20.1 line reached 0.12.0 in May 2026. **`cut-na`.** Also: it is *not* an Ars Nouveau addon; the "Ars" is Latin. | ❌ **missed** |
| Simply Swords Reforged (RP) | 🙁 optional resource pack | **Available but stale.** Single file published 2024-09-03, never updated; Simply Swords is on 1.70.2 (2026-08-27). Uniques added since (Caelestis, Magiscythe, Harbinger, the Relic line…) will render flat or as missing-model cubes. Cosmetic bug, not a balance one. | 🟡 **caveat added** |
| Antarchy | 🙂 "IS Extremely Power Creepy and will reduce the challenge of other mods" | **Confirmed, and understated.** See §4.2. | ✅ right |
| Macabre | "Maybe, seems kinda power creepy" | **Confirmed, and badly understated** — see §4.8. It is the second-worst mod on the lists. | ✅ right, by an order of magnitude |
| The Awakening | 🙂 "May be very Power Creepy" | **Confirmed.** ~3× at 20h plus pre-End flight. Config surface is excellent though. | ✅ right |
| Overgrown's Origins | 🙂 "May be power creepy" | **Insufficient data.** Not audited. Origins-style mods hand out permanent racial abilities at character creation, which is structurally the same shape as The Awakening; audit before shipping. | 🟡 unresolved |
| Cobblemon | 🙂 "can feel intrusive, has a ton of mobs" | **Confirmed as a performance risk, not just taste.** Reference case for entity-heavy packs: several persistent AI entities per player, "ten active players can have hundreds of entities ticking every game tick." | ✅ right |
| Aether 2 → base Aether swap | 🙂 suggested | **Correct call.** Base Aether is well-behaved (netherite-parity ceiling); see §4 note on Life Shards and the Valkyrie Lance. | ✅ right |

---

## 8. VERDICT TABLE

Codes: **keep** = include as-is · **config** = include with config tweak · **datapack** = include with datapack surgery · **gate** = include only if gated · **cut-dup** = cut, redundant · **cut-op** = cut, breaks parity · **cut-na** = cut, not available on 1.21.1 NeoForge · **decide** = needs a human call

### Leyton's list (38)

| Mod | Verdict | One-line |
|---|---|---|
| Xaero's World Map | **keep** | Client-side, zero server cost, pairs with the minimap and waystone compat. |
| Envelope (carrier pigeon delivery) | **decide** | Insufficient data — audit for cross-dimension item transport, which would undercut Waystones and backpacks. |
| Creature Feature | **decide** | Insufficient data. Pick this *or* Primal, not both — entity density is the TPS ceiling. |
| Cult of Azazel | **keep** | Insufficient data on numbers, but it's the mob/boss layer of the Nether stack and composes with YUNG's + Incision. |
| Antarchy | **config** | Ultimate Armor's free Prot V ×4 is the break, not the sword. Disable auto-enchant, halve armor values, kill the duplicator tree, leave Big Bertha alone. §4.2 |
| Block Pack | **keep** | Aesthetic blocks, zero mechanical surface. |
| Aquamirae 7 | **keep** | Insufficient data on numbers; short-band exploration content, author (Obscuria) is competent. Verify no shared-library clash if Ars Elixirum ever returns. |
| Naturalist 2.0 | **keep** | Passive ecology, low tick cost, no power surface. |
| Primal 2.0 | **decide** | Insufficient data. Redundant with Creature Feature — choose one. |
| Mowzie's Mobs | **keep** | Handcrafted mini-bosses, tense effort, restrained rewards. One of the best-behaved tracks on the list. |
| Visual Health | **keep** | Cosmetic. |
| Primal Frontier | **cut-na** | 1.20.1; the NeoForge counterpart is 1 mob and WIP. |
| Fights and Frights | **decide** | Insufficient data — nine mobs, unaudited numbers. |
| Stained Lenses | **cut-na** | 1.20.1. |
| Aether 2 | **cut-na** | Reboot's earliest build is 1.21.8. Use base Aether. |
| Skeleton Uses Custom Bows | **keep** | Fidelity fix; **inert by default** (`chance` defaults 0.0). Never set `chance > 0` on a boss-drop bow — that's how Cataclysm's Wrath of the Desert becomes skeleton-farm loot. |
| Simply Bows | **gate** | Cleanest rate failure in the audit: 10–25h maxed kit vs Simply Swords' 60–120h, same author, same currency. Cut loot chances hard; test the Echo bow's possible %-max-HP explosion. §4.6 |
| Simply Swords | **config** | Underpays on stats (peak 11.2 DPS) but the Omen execute deletes every boss's last 25%. Zero the threshold; disable loot-table injection. §4.13 |
| Gateway to Doom | **decide** | Insufficient data. Do not confuse with Gateways to Eternity. |
| Metus Oblita | **cut-na** | 1.20.1. |
| Incision | **keep** | Two Nether biomes; composes with YUNG's + Cult of Azazel. |
| Street Art | **cut-na** | 26.3 only. |
| Crop and Kettle | **cut-na** | 1.21.8+. |
| Ars Exilirium (→ Ars Elixirum) | **cut-na** | 1.21.1 is an Oct 2024 alpha, 22 months stale, from an unfinished Mod Jam entry. Not fit for a months-long world. |
| Ghosts (tameable/tradeable) | **decide** | Insufficient data. |
| Ember's Floating Islands | **keep** | Server-only jar, zero items, generates in empty sky so it doesn't fight Terralith. **Datapack out the free Waystone on Flower Islands** and dial back the 1.5.1 frequency bump. *(loot tables unverified — closed source, no wiki.)* |
| Dark Fantasy: Nordic Tombs | **cut-na** | Project not found. |
| Paradise Lost | **cut-dup** | Third skylands dimension; craftable gear worse than diamond; NeoForge build is a Sinytra Connector repack with **zero stable releases ever**. §4.14 |
| Eternal Starlight | **config** | Underpays badly — 55h post-Dragon for netherite parity. Shorten the gate. Datapack the Starfall Longbow. Check the pre-Dragon Gatekeeper ambush. §4.10 |
| Dungeons Enhanced | **cut-na** | 26.1.2 only. |
| Larion World Generation | **cut-dup** | Third worldgen injector behind Terralith and BOP. Cut. |
| Nether Trials and Chambers | **cut-dup** | Fourth structure injector in a small dimension; no new axis. |
| Monster Expansion | **cut-na** | 1.20.1. |
| Jurassic Reborn | **decide** | Insufficient data. Entity-heavy — weigh against the TPS budget and against Cobblemon; probably can't afford both. |
| Thalassophobia | **cut-na** | 1.20.1. |
| Confluence: Otherworld | **cut-op** | A second game. 36-dmg unbreakable swords, hardcoded 100 HP Life Crystals, and a Wall of Flesh kill that flips the whole server to Hardmode without consent. §4.7 |
| Grim and Bleak | **gate** *(recommend cut)* | Pre-iron portal → 25-base-damage sword; unpublished armor numbers; irreversible permanent Overworld corruption on the Gate Guardian kill. §4.9 |
| Brass Amber: Battle Towers | **cut-na** | 1.20.1 only; Leyton's annotation was right. Its axis (vertical dungeon towers) is covered by When Dungeons Arise + Structory Towers anyway. |
| Xaero's Minimap & World Map – Waystones Compat | **keep** | Client-side, makes Waystones legible. |

### DJ's list (20)

| Mod | Verdict | One-line |
|---|---|---|
| Sophisticated Backpacks | **keep** | The backpack call. Shares a library with Sophisticated Storage. |
| Artifacts | **config** | 2.1× DPS from two pillager-outpost chest items at hour 6. **Requires Curios despite "optional" flags.** Antidote Vessel is the real offender, not Power Glove. §4.5 |
| Sophisticated Storage | **keep** | Pairs with the backpacks; no power surface. |
| The Twilight Forest | **config** | Well-tuned overall (Fiery/Yeti at netherite parity after 50–90h) but two problems: the **Glass Sword** (40 dmg, 1 durability, enchantability 30 — datapack it out of Apotheosis affix tags before someone makes it unbreakable) and the **Uncrafting Table** (mod-agnostic reverse-crafting; config-disable it — it undercuts Apotheosis, Ars, Iron's Spells and Cataclysm simultaneously). Cheap 1-diamond portal is fine; the internal biome locks do the real gating. |
| Apotheosis | **config** | 3.7–5.7× at 45h, honestly gated behind Wither + Dragon (mythic weight is 0 below Summit tier). **Datapack `apotheosis:melee/attribute/lengthy`** (reach triple-stacks) and **the `Executing` affix** (`setHealth(0)`, no boss check). §4 item 9 |
| Terralith | **keep** | The worldgen call. Datapack-based, no TerraBlender contention. |
| Gateways to Eternity | **datapack** | `hellish_fortress` = 95 wither-skeleton loot rolls for one skull = exponential skull engine. `emerald_grove` underpays for identical effort. §4.3 |
| Goblin Traders | **keep** | Small economy mod, no power surface. |
| Farmers Delight | **keep** | Food/buff economy; well-established. |
| Oceans Delight | **keep** | Addon to the above. |
| Iron's Spells 'n Spellbooks | **config** | ~3× ranged at 50h — fits the long band. **Corrections:** school armor is 20 armor / **0 toughness / 0 KB** (not a strict upgrade over netherite) and Angel Wings is a **50-second glide, not permanent flight**. Real levers: `MAX_UPGRADES` 3→2, thin EPIC/LEGENDARY scroll drops. |
| Alex's Caves | **cut-na** | **1.20.1 only, last updated Oct 2024.** Nobody flagged this. Also breaks T.O Magic. |
| Structory Towers | **keep** | Structure set; counts against the density budget. |
| Apothic Spawners | **config** *(consider cut)* | ~100× spawn rate, ~400× loot with Echoing III, and Echoing rolls pass `hitByPlayer = true` so Looting applies to all four. Optional as of Apotheosis 8.7.0. **`spawnerSilkLevel = -1` is a one-line kill switch.** §4.3 |
| Apothic Attributes | **config** | Hard dependency of Apotheosis — not optional. Silently rewrites global armor math (toughness contributes **zero** damage reduction; Protection 2.5%/pt capped at 85%). Ships a brewable **Potion of Flying** (30 min creative flight, giftable, renewable) — remove the brewing mixes. |
| Apothic Enchanting | **config** | Corrected caps: **Sharpness 9 / Smite 10 / Protection 8**, not 19/25/19. Exclusive-set removal is real (Sharp+Smite stack; Prot stacks with Fire/Blast/Projectile). Cap them in `config/apotheosis/enchantments.cfg`, and **datapack out the echo-shard 1→4 and XP-bottle 1→8/32 infusions** — those are the actual economy breakers. |
| JEI | **keep** | Mandatory. Latest 1.21.1 build published 2026-08-28. |
| Jade | **keep** | Mandatory QoL. |
| Deeper and Darker | **datapack** | 🔴 **Highest-priority fix in the audit.** Empty the `resonarium_armor` item tag or the pack is over on day one. §4.1 |
| Deeper and Darker Spellbooks | **config** | Gear is honestly gated (7–20 Warden kills) and 24 armor / 16 toughness is defensible for it. **But three summon spells override `requiresLearning()` to `false`**, walking around Iron's Spells' longest gate — datapack those back. |

### David's list (23)

| Mod | Verdict | One-line |
|---|---|---|
| Better Combat | **keep** | Presentation layer, not a balance layer. Single-target DPS = vanilla. Set `server_target_range_validation = true` (defaults false — a reach-exploit vector on a 6-player server) and drop `reworked_sweeping_extra_target_count` 4→1–2. |
| Any/all Better Combat compat mods | **config** | **Install exactly one Cataclysm × BC compat pack.** Three exist; datapack load order silently decides which `weapon_attributes` win. |
| Expanded Combat | **cut-dup** | Ungated netherite ladder (22 DPS Dancer's Sword), an *iron* dagger beating a netherite sword, a +2 damage gauntlet in a free Curios slot buffing every weapon in the pack, ships zero BC data. §6 |
| Excalibur (resource pack, optional) | **keep** | Cosmetic. |
| Excalibur: Mowzie's Mobs Support (RP) | **keep** | Cosmetic. |
| Mowzie's Cataclysm | **keep** | Crossover addon; the existence of a hand-made bridge between two boss mods is a good sign, not a risk. |
| Integrated mods (all 5) | **decide** | Insufficient data — need the actual five names before a call. |
| L_Ender's Cataclysm | **keep** | **The reference track.** 13 dmg @ 1.0 endgame weapon that does *not* beat a Sharpness V netherite sword, behind 8 bosses at 600 HP / 25 dmg. Every other mod is measured against this. |
| T.O Magic 'n Extras | **cut-na** | March 2025 alpha, two majors behind, zero published numbers, hard-requires Alex's Caves which has no 1.21.1 build. |
| Loot Integrations (Dungeons, Villages, Strongholds, Cataclysm) | **keep** | Unifies the loot economy across structure mods instead of four disjoint ones. |
| Simply Swords Reforged (RP, optional) | **keep** | Cosmetic. Last updated 2024-09 vs Simply Swords 1.70.2 — expect missing models on newer Uniques. |
| YUNG's Better Nether Fortresses | **keep** | YUNG's API is actively maintained (build 2026-08-21). |
| Cataclysm × YUNG's Better Nether Fortresses Compat | **keep** | Correct pairing. |
| The Undergarden | **keep** | 🔵 **Underpays** — every weapon at or below a netherite sword after 15–30h. Consider a +1.5 damage datapack bump, or bill it honestly as the building track. §4.11 |
| Saint's Dragons | **cut-na** | **No 1.21.1 build on either platform.** Only 1.20.1, newest a NeoForge alpha hotfix. |
| Knaves' Needs | **cut-dup** | **Broken, not overpowered** — the shipped beta stubs the Warden tier at 0.0, giving a 1-damage Warden Katana. Beta-only, ~2,700 downloads, source two versions behind the binary, registers 520 items. |
| Simply Tooltips | **keep** | **Mandatory** — a hard required dependency of both Simply Swords and Simply Bows. Modrinth marks it `server_side: unsupported` but NeoForge will still resolve it server-side; ship the jar on the server or Simply Swords won't load. |
| Simply Entity Equipment | **datapack** | v0.1.0, 5 days old, 576 downloads, 0 GitHub stars, mixins into mob spawning and melee AI on a months-long server — highest-variance component in the batch. Its `max_health` modifiers (`add_multiplied_total` 4.34 = ~107 HP zombies) **stack with Apotheosis' own boss-mob multipliers**; gut the attribute block and let Apotheosis own mob scaling. Also strip its Runefused Gem / rune-etching drops, which make Simply Swords' socket currency spawner-farmable. |
| Fragmentum [NeoForge] | **decide** | Insufficient data. |
| Loot Journal: Pickup Notifier [NeoForge] | **decide** | Insufficient data; presumed pure QoL. |
| Biomes o' Plenty | **cut-dup** | Terralith is the call. Two worldgen injectors doubles cost and risks wrong-world failures you find 40h in. |
| Macabre - Call of False Prophets | **cut-op** | Ferrum beats netherite at 4h; Gargamaw is 108 armor / 60 HP; and its full-set routine resets player attribute base values every tick, breaking every Curios mod in the pack while worn. §4.8 |
| ars-n-spells | **cut-op** | Not a content mod — a *merger*. Collapses Ars Nouveau and Iron's Spells into one shared pool with cross-redeemable gear, which is the exact opposite of the hub design the group is paying for. If kept anyway, `mana_mode = separate`, which removes ~80% of its reason to exist. |

### Dan's list (19)

| Mod | Verdict | One-line |
|---|---|---|
| The Awakening | **config** | ~3× at 20h; Exosavant flight at mastery 7 and Shadow Meld at 5 gut Deeper and Darker and every dark dungeon. **Intra-mod parity is random** (Reaper vs Phytokinetic) — make sure everyone knows Catalyst rerolls are cheap. Excellent config surface: raise `healthThreshold` or disable near-death awakening outright. Rewards are the only truly non-giftable ones in the pack. |
| Waystones | **keep** | Core QoL for a 6-player world. Protect it: disable Ars Nouveau's warp portals, datapack the free Waystone off Ember's Flower Islands, and remove Apothic Attributes' Potion of Flying. |
| Towns and Towers | **keep** | Counts against the structure-density budget. |
| Aquaculture | **keep** | Fishing economy; distinct axis from every other ocean mod. |
| The Twilight Forest *(dup of DJ)* | **config** | See DJ's row — Glass Sword and Uncrafting Table are the two fixes. |
| Moogs Voyager Structures | **decide** | Insufficient data; optional. Fifth structure injector — only add if you cut another. |
| When Dungeons Arise | **keep** | Insufficient data on numbers, but it's the anchor structure mod. Pair with **Lootr** so six players don't race for one chest. |
| Ars Nouveau | **config** | 🔵 **Underpays on combat** — its sword is byte-for-byte a netherite sword and its best armor is 20 armor / **0 toughness**. Keep it as the automation track and *say so out loud*. Two leaks to plug: Drygmy Charms (bypasses every kill-the-mob material gate) and Stable Warp Scrolls (kills Waystones). §4.12 |
| Aether *(dup of Leyton)* | **config** | Fits the medium band at 1.5×. Two items to tune: **Valkyrie Lance** (+3.5 reach from the mod's *densest, first* dungeon — trivializes melee windows for every 3-block-range boss in the pack) and **Phoenix armor's permanent fire immunity** (deletes Ignis' mechanic and every Fire Resistance economy). Life Shards (+20 max HP) are honestly gated and per-player — leave them. |
| Guard Villagers | **keep** | Small, no power surface. |
| Bountiful | **keep** | Quest/bounty economy; a genuinely good fit for a hub pack — it can be datapacked to reward under-paying tracks. |
| Ars Elemental | **config** | Heavy Elemental armor is **25 armor / 16 toughness — beats netherite outright**, so the mage track ends up tankier than Epic Knights. Nerf the heavy tier to 20/12 or accept it. Otherwise a well-gated 60h track (Chimera kill + ~33k source + netherite). Do **not** add Ars Elemancy on top. |
| Better Archeology | **keep** | Insufficient data on numbers; low-risk cosmetic/loot content. |
| Minecolonies | **decide** | 🔴 **The single biggest TPS risk on any of the four lists.** A measured bug report shows its event subscribers at **43,000 µs/tick with 4 players online — 86% of the entire 50,000 µs tick budget**, with CPU and RAM both *low* while TPS collapsed. On a 32GB box that also hosts your game, this is the mod most likely to make the server unplayable. If it goes in, it goes in alone in its slot and you profile with spark after the first real session. |
| Cobblemon | **decide** | Dan's instinct is right on both counts. Entity-heavy (persistent AI entities per player — the reference case for this failure mode), and it is a fully self-contained ~60h collection currency that no other track can be compared to. Fine as a track; expensive as a tick cost. Probably can't run this *and* Jurassic Reborn. |
| Small Ships | **keep** | Transport axis; no combat power surface found. |
| Epic knights armor and weapons | **config** | Weapons are **below** netherite DPS once density is applied (halberd 10.0 DPS, 5.6 with a shield). The break is **0.5–1.5 knockback resistance per piece → permanent immunity from two pieces of iron-age steel**, and a 22-armor jousting set craftable for ~56 iron. Find-and-replace `knockbackResistance` → 0.1f; leave the weapons alone. §4.4 |
| Travelers backpack | **cut-dup** | Sophisticated Backpacks is the call. |
| Overgrown's origins | **decide** | **Insufficient data — audit before shipping.** Origins-style permanent racial abilities granted at character creation are structurally the same shape as The Awakening: zero-hour payoff, non-giftable, and potentially wildly variant between players. Dan's "may be power creepy" flag is the right instinct. |

---

## 9. UNKNOWNS & LOW-CONFIDENCE CLAIMS

**Marked "(unverified)" in the document above — do not act on these without checking:**

| Claim | Why it's uncertain | How to resolve |
|---|---|---|
| **Grim and Bleak's armor values** | Closed-source MCreator mod, no wiki, no repo. Only first-party marketing prose ("slightly better than netherite"). | Measure in-game with a tooltip mod. Until then, treat the mod as unquantifiable — which is itself a reason to cut it. |
| **Grim and Bleak's Thunder Sword current damage** | Changelog says 25 base + 10–40 charge as of v2.0, then v2.5.2 "deals more base damage" and "bigger max charge" with no figures. Shipping version is 2.6.0. | Check the tooltip in-game. |
| **Artifacts' 2.10× DPS figure** | Assumes the Curios "hands" slot has 2 slots. Curios defaults to 1 and no `data/curios/slots/` JSONs exist on the 1.21.1 branch. | Check the Curios inventory screen in-game. If hands = 1, the real number is 1.5× and Artifacts drops out of the "hot" band. |
| **Simply Bows' Echo bow `painExplosion*` keys** | Config exposes `BaseHpDamage 0.16`, `FrameHpDamage 0.06`, `MaxDamageRatio 0.55`. Naming strongly implies percent-of-max-health. Implementation not found in `EchoBowItem.java`. | **Test in singleplayer against a high-HP mob before launch.** If it is %-max-HP, this is the worst item in the audit. |
| **Eternal Starlight's Starfall Longbow composite damage** | The 9-meteors-per-arrow behavior and the 50-damage / i-frame-bypassing meteor stat are each wiki-verified; the *composite* (~450 burst) is inference. | Test against a Cataclysm boss. |
| **Paradise Lost's Soul Blade real ceiling** | The `× 0.25F` uncapped scalar is verified source. The 250–500 distinct-EntityType count on this specific modlist is a projection. | Moot if the mod is cut, which is the recommendation. |
| **Ember's Floating Islands loot tables** | All-rights-reserved, no source, no wiki, no issues URL. Adding zero items bounds the *pool* to vanilla but not the *quantity* or enchantment level. | Unzip the jar and read `data/floating_islands/loot_table/**.json`. |
| **T.O Magic 'n Extras' weapon and armor numbers** | Closed source, no wiki, changelogs only. CurseForge lists weapon names with no stats. | Moot — cut on availability. |
| **Ars Elixirum's power numbers** | Closed source, no repo. | Moot — cut on availability. |
| **Aether II's everything** | No 1.21.1 build exists to inspect. | Moot. |
| **Ars Nouveau per-tier armor thread slot counts** | `ArmorPerkHolder.getSlotsForTier()` delegates to a registry the source doesn't expose; ars.guide publishes no numbers. | Creative-mode check. The gap to Iron's Spells is too large for it to change any conclusion. |
| **Apotheosis affix count per mythic rarity** | Configurable; the shipped rarity JSON was not located. | Read `config/apotheosis/` after first boot. |
| **Whether Cataclysm/Mowzie's/Alex's tag their bosses into `#c:bosses`** | Determines whether Apothic Spawners can farm them. Not verified for any mod. | Try to Capturing-egg a Cataclysm elite in creative. |
| **Deeper and Darker's Sculk Transmitter range/dimension limits** | Source shows no distance check and no chunk force-loading; reads as cross-dimension capable. | Test. It matters for Waystones and both backpack mods. |
| **Eternal Starlight's `GatekeeperConfig.canAlwaysHurtWhenFighting` semantics** | Name implies it's the pre-Dragon ambush toggle; not confirmed. | Read the source or test. |
| **Whether Artifacts' Power Glove applies to ranged weapons** | It's a vanilla `attack_damage` modifier, which is melee-only and cooldown-scaled — but the broader reading wasn't confirmed. | Test with a bow. |

**Structural unknowns, no numbers involved:**

- **"Insufficient data" mods** — Envelope, Creature Feature, Cult of Azazel, Aquamirae, Primal, Fights and Frights, Gateway to Doom, Ghosts, Jurassic Reborn, Moog's Voyager, When Dungeons Arise, Better Archeology, Fragmentum, Loot Journal, the five "Integrated mods", and **Overgrown's Origins**. None of these were audited for power numbers. Overgrown's Origins is the one that actually worries me — permanent character-creation abilities are the same structural shape as The Awakening.
- **Structure Gel API 1.21.1 status** — the Modrinth slug 404s; likely CurseForge-only. Several structure mods depend on it. Verify before freezing the list.
- **Architectury × Apotheosis conflict (issue #592)** — `Conflicting default methods: DeferredSupplier.getKey` vs `IHolderExtension.getKey`, reported on Architectury 13.0.8 / Apotheosis 8.1.2, **still open**. Architectury 13.0.11 is newer and may already fix it. **Test this pairing first, before anything else loads.**
- **Architectury × OmegaConfig** — any mod bundling OmegaConfig can prevent Architectury from initializing, throwing `Mod 'architectury' is not available!` even when Architectury is correctly installed. If you see that error, hunt for a bundled OmegaConfig; don't reinstall Architectury.
- **Curios vs Accessories** — default to **Curios** as the pack spine. Add Accessories only if a mod you want is Accessories-native, and bridge with the Accessories Compatibility Layer (never the deprecated CC Layer, never Curios API Continuation).

---

## 10. IMMEDIATE ACTION LIST

Ordered by leverage, not by section number.

1. **Datapack: empty `deeperdarker:resonarium_armor`.** Five lines. Without it the campaign is over on day one.
2. **Datapack: `apotheosis:melee/ability/executing` and Simply Swords' `omen_instantkill_threshold` → 0.** Two boss-deleting execute mechanics, neither with a boss check.
3. **Cut list, final:** Confluence: Otherworld · Macabre · Grim and Bleak (unless gated) · Expanded Combat · Traveler's Backpack · Biomes O' Plenty · Larion · Knaves' Needs · Ars 'n Spells · Paradise Lost · Nether Trials and Chambers.
4. **cut-na list, final:** Alex's Caves · Saint's Dragons · T.O Magic 'n Extras · Ars Elixirum · Aether 2 · Primal Frontier · Stained Lenses · Metus Oblita · Street Art · Crop and Kettle · Dungeons Enhanced · Monster Expansion · Thalassophobia · Brass Amber Battle Towers · Dark Fantasy: Nordic Tombs.
5. **Config pass, one sitting:** Antarchy (`ultimateArmorComesEnchanted = false` + armor values + duplicator tree) · Epic Knights (`knockbackResistance` → 0.1f, all 12 sets) · Artifacts (`items.toml`) · Apothic Spawners (`spawnerSilkLevel = -1`) · Better Combat (`server_target_range_validation = true`, sweeping 4→2) · Apothic Enchanting (`enchantments.cfg` caps) · Apothic Attributes (remove the Potion of Flying brewing mixes).
6. **Buff pass — don't skip this, it's half the brief:** shorten Eternal Starlight's Ender Dragon gate · +1.5 damage on Undergarden's Utherium/Forgotten tiers · shorten Simply Swords' awakening from 8 tablets to 4 · fix Gateways' `emerald_grove` payout · use **Bountiful** to inject compensating rewards into whichever track the group actually picks and finds thin.
7. **Install the tooling layer on day one, not after the imbalance shows:** KubeJS + LootJS + Paxi + In Control! + AttributeFix + Enchantment Blacklister + **Lootr** + Restricted Portals (optional).
8. **Before the world is created:** test Architectury × Apotheosis, test the Artifacts × Expanded Combat Curios hands slot (moot if EC is cut), confirm Simply Tooltips loads server-side, and **Chunky-pregenerate the Overworld to r=3000 and the Nether to r=400** with `-Dmax.bg.threads` raised, before anyone joins.
9. **Freeze the modlist before pregen.** Adding or removing any biome/structure/worldgen mod afterward leaves permanent chunk-border seams. Order is: assemble → bisect-test → freeze → create world → pregen → campaign.
10. **Tell the group the reward axis of each track before they pick.** "Ars Nouveau is the automation track and will not make you hit harder" is a two-sentence conversation that prevents a two-month resentment. It is the cheapest fix in this entire document.
