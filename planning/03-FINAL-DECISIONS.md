# 03 — FINAL MODLIST DECISIONS

**Locked 2026-08-30.** Supersedes the redundancy calls in `00-MODLIST-AUDIT.md §6` and `§10`
wherever the two disagree. Docs 00/01/02 remain valid for *reasoning*, numbers, and config
keys — this file is the *decision record*.

---

## 0. PHILOSOPHY CHANGE — read this first, it invalidates a lot of doc 00

The audit was commissioned under a **strict parity** brief ("equal effort, equal reward
across parallel tracks"). Wesley revised this on 2026-08-30 after an hour with the list:

> "big kitchen sink with a side of balance. The things we want to balance are really good
> armor or weapons being really easy to get. We don't have to bring everything to Cataclysm
> level. Just look for egregious outliers and give them a datapack nerf."

**Consequences — these are deliberate, do not "re-fix" them:**

1. **Only the OVERPAY direction is in scope.** Specifically: *strong gear that is cheap to
   obtain*. Expensive-but-strong is fine. Big numbers are fine if earned.
2. **The UNDER-reward half of the audit is dropped entirely.** Undergarden, Eternal
   Starlight, Ars Nouveau and Simply Swords get **no buffs**. Rationale: under-reward was a
   defect only because the parity framing treated tracks as *exclusive choices*. In a
   kitchen-sink pack where everyone plays everything and gear is freely giftable, an
   under-paying mod is content you do for fun while your gear comes from elsewhere. It is
   not a trap. Doc 01's Rule 2 (rate floor) is **void**.
3. **The hub-vs-spine argument is void.** Any recommendation justified by "this collapses
   two parallel tracks into one" no longer holds. This is why Ars 'n Spells is back in.
4. **`R = (P−1)/(H × T)` is no longer the governing metric.** Use it as a triage sort to
   find outliers, not as a target to tune toward.

---

## 1. CUT

| Mod | Reason |
|---|---|
| **Macabre - Call of False Prophets** | Armor reaches 108/26/20 vs netherite's 20/12/0.4; its *second* ore tier beats netherite at hour 4; the armor routine resets player attribute bases every tick, silently breaking every Curios mod worn alongside it. |
| **Grim and Bleak** | Pre-iron portal (chiseled deepslate) to a 25-base-damage charge-scaling sword. **No config file exists in any of its nine published versions** — MCreator, closed source, no wiki. Unfixable by design. Wesley's stated ground: nightly Overworld spawns. |
| **Knaves' Needs** | Broken, not overpowered. The shipped 1.21.1 beta stubs the Warden tier at `0.0` attack bonus → a **1-damage** Warden Katana. Beta-only, 5 open bugs, registers 520 items. |
| **Expanded Combat** | An *iron* Dagger at 14 DPS already beats a netherite sword; a +2 flat-damage gauntlet sits in a free Curios hands slot buffing every weapon in the pack; ships **zero** Better Combat data (`registerTransforms()` commented out) so its weapons fall through to fallback regexes and double-dip on reach. Also collides with Artifacts over the Curios hands slot. |
| **Alex's Caves** | No 1.21.1 build exists. (Also kills T.O Magic 'n Extras — hard dependency.) |
| **Saint's Dragons** | No 1.21.1 build exists (three independent confirmations). |
| **Cobblemon** | TPS. Persistent AI entities per player × 6 players × 8+ dimensions. MC's game loop is single-threaded, so 64GB does not help. Also a parallel combat system that makes gear irrelevant while in use. |
| **Jurassic Reborn** | 164 MB jar (largest on the list), 108 GeckoLib models, open crash issue #82 with VintageFix. Highest per-entity cost of any mob adder. |
| **Ghosts** | **Defect, not balance.** Every owned ghost force-loads its chunk every tick and **never releases the force on entity removal** (source-verified). A progressive chunk-loading leak on a months-long world. No config exposes it. |
| **Fights and Frights** | MCreator-generated, per-tick procedure triggers, explicit author compatibility disclaimer, audit confidence LOW. Same grounds as Grim and Bleak. |
| **Traveler's Backpack** | Second incompatible upgrade economy alongside Sophisticated. See §3. |
| *Confluence: Otherworld* | ~~CONDITIONAL~~ → **IN (test passed 2026-08-30)** — Life Crystal worldgen test §4.3 passed; entry-gated via `confluence-gate-life-crystal` datapack. |
| **The Integrated family** (IDAS, Integrated Cataclysm, Integrated Stronghold, Integrated Villages + their Loot Integrations addon; the `integrated-api` lib itself STAYS — Antarchy hard-requires it) | **CUT 2026-08-30 (Wesley's call at pack-build; freeze reopened + reclosed same day).** The entire family hard-requires **Create + Quark + Zeta + Supplementaries** at the NeoForge `mods.toml` level — boot-verified both ways on a throwaway server (with the four: `Done (12.3s)`; without: ModSorter refuses to load). Their structures are literally built from those mods' blocks, so there is no partial option. Doc 02 predicted exactly this (risk register #6: "a Create pack by side effect"); doc 00 had all five as **"decide — insufficient data"** and the batch-audit never happened, so they slid onto the frozen list unadjudicated. Wesley chose cutting 4 structure mods over admitting 4 unaudited content mods (incl. a full tech economy + 3 new permanent worldgen sources) into a frozen roster. Bonus evidence: IDAS loot tables here referenced Ice & Fire and BYG items this pack never had — it is tuned for a different universe. |

**Cut on availability** (no 1.21.1 NeoForge build): T.O Magic 'n Extras · Ars Elixirum ·
Aether 2 · Primal Frontier · Stained Lenses · Metus Oblita · Street Art · Crop and Kettle ·
Dungeons Enhanced · Monster Expansion · Thalassophobia · Brass Amber Battle Towers ·
Dark Fantasy: Nordic Tombs · Paradise Lost (Sinytra repack only, zero stable releases ever).

---

## 2. ADD — not on anyone's original list

| Mod | Why |
|---|---|
| **GraveStone Mod** (`neoforge-1.21.1-1.0.21`) | The grave mod. Plain: places a gravestone holding your inventory. **Deliberately NOT Corail Tombstone** — Tombstone 9.3.1 is on 1.21.1 NeoForge, but ships a full death-magic progression (knowledge points, perks, soulbound gear, teleport scrolls), i.e. a fifth reward track smuggled in through a QoL decision. |
| **Combat Roll** | Dodge roll. Half of the Beyond Depth combat feel. Zero weapons, zero stats. |
| **Shield Expansion** | The parry mechanic Beyond Depth actually advertised. Zero weapons, zero stats. |
| **Lootr** | Per-player loot in shared structure chests. Removes the first-to-the-chest race, which on 6 players is worth more than most content mods. |
| **Sparse Structures Reforged** | Global structure spacing budget. Four structure injectors are in the pack; density is the hidden cost, not any single mod. |

> **Beyond Depth correction.** It ran Better Combat + Combat Roll + Shield Expansion +
> Cataclysmic Combat. It **never ran Expanded Combat**. Beyond Depth is also **1.20.1 Forge
> only** — there has never been a 1.21.1 or NeoForge build of it, or of any Beyond-* pack.

---

## 3. REDUNDANCY — final calls

- **Better Combat IN, Expanded Combat OUT**, plus Combat Roll + Shield Expansion.
  Install **exactly one** Cataclysm × Better Combat compat pack — three exist, and datapack
  load order silently picks the winner.

- **Sophisticated Backpacks IN, Traveler's OUT.** Not a feature-superiority call: Traveler's
  has a fluid tank and sleeping bag that Sophisticated lacks. The tiebreaker is that
  Sophisticated Backpacks shares `Sophisticated Core` with **Sophisticated Storage**, which
  DJ also wants. Running Traveler's means two incompatible upgrade economies for zero gain.
  *If Sophisticated Storage is ever cut, revisit this.*

- **Ars Nouveau + Iron's Spells + Ars 'n Spells ALL IN** ← reversed from doc 00.
  The cut reason was "merging two tracks defeats the hub design", which §0 voided.
  **But config two values** — these are genuine cheap-power outliers:
  - `source_jar_synergy_multiplier = 5.0` — automatable Ars source deletes Iron's mana gate
  - `spell_power_cap = 3.0` — Iron's spell-power gear triples Ars potency

- **Terralith + Biomes O' Plenty BOTH IN** ← reversed from doc 00. Lower BoP's
  **TerraBlender region weight** so it is sprinkled through Terralith rather than competing
  for share. **Pregen after setting the weight** — changing it post-gen fragments chunks.
  - ⚠ **The X=0 seam is impossible via LIVE worldgen.** Vanilla has four biome sources
    (`multi_noise`, `fixed`, `checkerboard`, `the_end`) and none can condition on raw X.
    TerraBlender cannot either — "Replace biomes conditionally per region instance" is an
    **open feature request** (Glitchfiend/TerraBlender issue #226). A live seam needs a
    custom `BiomeSource` in Java.
  - ✅ **It IS achievable as a PRE-BAKED WORLD SPLICE → see `05-WORLD-SPLICE.md`.**
    Pregen each half with one mod, merge the chunk files at X=0 (already a chunk/region
    boundary), ship a finite bordered world. Biomes are stored per-chunk since 1.18, so the
    split is permanent. **If the splice is used, the weight-tuning above does not apply** —
    each half is generated by one mod alone, and BoP's weight is zeroed only during the
    Terralith pregen run. ⚠ The splice moves the **modlist freeze earlier** (before pregen,
    not before launch) and makes both mods permanently un-removable.

- **Mob adders:** keep **Naturalist 2.0 + Primal 2.0 + Creature Feature + Mowzie's Mobs**,
  spawn weights tuned down globally. Cut Jurassic Reborn, Ghosts, Fights and Frights.
  - ✅ **NATURALIST WINS THE SHARED VANILLA MOBS — decided 2026-08-30.**
    Both mods touch vanilla fox, rabbit, wolf, polar bear and dolphin: Primal *remodels and
    buffs the vanilla mobs*, Naturalist *ships its own variants* (`forest_fox`,
    `forest_rabbit`). Naturalist owns them; Primal's overrides get switched off.

    **Config-only fix — 8 keys in `config/primal-*.toml`, all → `false`:**
    ```
    foxModelChange          = false
    rabbitModelChange       = false
    wolfModelChange         = false
    polarBearModelChange    = false
    dolphinModelChange      = false
    foxIncreasesHealth      = false
    wolfIncreasesHealth     = false
    polarBearIncreasesHealth = false
    ```
    **Naturalist needs no change** — leave its `*_removed` keys at default so
    `forest_fox_removed` / `forest_rabbit_removed` stay `false` and its variants survive.
    Do **not** solve this from the Naturalist side; removing its variants throws away the
    mod's own content to keep a remodel of a vanilla mob.

    *Why this direction:* Naturalist's variants are new entities with their own loot,
    behaviour and spawn rules — real content. Primal's are cosmetic remodels plus a health
    buff on mobs that already exist. Turning off a skin costs less than deleting a mob. It
    also keeps Primal's 9 Brain-AI animals, which are its actual contribution.

  - ⚠ **Primal's `<x>ExtraBiomes` keys are load-bearing for the spliced world.** Every
    Primal spawn entry has an `<x>ExtraBiomes` String list, and that is the hook for
    non-vanilla biomes. With BoP on one half and Terralith on the other
    (`05-WORLD-SPLICE.md`), Primal's animals will spawn **only in vanilla biomes** unless
    both mods' biome IDs are added to these lists. Populate them for BOTH biome sets or
    half the map gets no Primal wildlife. Affected entries: `bearSingle`, `bearGroup`,
    `crocodileNormal`, `crocodileWarm`, `sharkSingle`, `sharkGroup`, `walrusCoast`,
    `walrusOcean`, `lionSavanna`, `lionSnowy`, `snake`, `deerForest`, `deerSnowy`,
    `dolphinCold`, `rabbitBadlands`.

  - 🔴 **Primal ships a craftable `minecraft:trident`** at `data/minecraft/recipe/trident.json`.
    Tridents are normally drowned-drop-only; a recipe deletes that whole acquisition gate,
    and with Loyalty/Riptide it is a strong weapon obtained cheaply. **This is squarely an
    §0 "egregious outlier" — nerf it.** One-line datapack: override that path with an
    impossible/empty recipe. Zero side effects. Also check
    `data/primal/recipe/enchanted_golden_apple_fritter.json` — Strength II on a notch apple.
  - Creature Feature ships **multipart entities** (`MindsEntityPart`, `CanaryPart`) which are
    individually ticked and collision-checked — a known tracker/desync source. Acceptable,
    but it is the first thing to suspect if entity desync appears.

- **Minimaps:** keep all three Xaero's (same author, client-side, zero server cost).
  Rule: no second minimap family.

---

## 4. KEEP + FIX — the four tuning jobs

### 4.1 Deeper and Darker — DO THIS BEFORE ANYONE JOINS
Resonarium armor grants **literal 100% damage immunity**. Confirmed arithmetic bug:
`reduction = incoming/4` is computed **outside** the per-piece loop. Diamond-tier gear, fully
giftable, no binding. Fix is emptying one item tag — see `01-BALANCE-PLAYBOOK.md §2.1`.
**Highest-priority change in the entire pack.**

### 4.2 Antarchy — KEEP, config only, no datapack needed
`AntarchySettings.java` exposes **48 toggles and 407 numeric fields**. Config values are
modifiers on the player's 1.0 base, so displayed = config + 1.

- `ultimateArmorComesEnchanted = false` — **highest-leverage single line.** The armor's
  `inventoryTick()` re-applies Protection 5 / Fire Prot 5 / Projectile Prot 5 / Blast Prot 5
  **every tick** = 20 EPF = the **80% enchant cap**. Vanilla-legal max is Prot IV ×4 = 64%.
- Ultimate Armor values → **3 / 8 / 6 / 3** (netherite parity). Currently 32 armor / 18
  toughness / 0.6 KB resist for **11 uranium + 13 titanium — zero netherite, zero bosses,
  zero dimensions.** Ore is `needs_iron_tool`, uniform Y −64→32, 13 veins/chunk.
- `ultimateSwordAttackDamage` 34 → 11 · `ultimateAxeAttackDamage` 42 → 13
- **Disable `DuplicatorTreeLogic`** — default-on, 10% per random tick, duplicates any full
  cube in the 8-cell ring around a center log. Netherite, diamond, uranium and titanium
  blocks are all valid sources. AFK-able infinite duplication.
- **DO NOT touch Big Bertha.** 63 dmg @ 1.0 with 6-block reach, but gated behind ~19
  boss/mob drops across three sub-recipes. Legitimately earned endgame.
- *Refuted:* the Hoverboard is **not** flight — `MAX_HOVER_HEIGHT = 5.0` clamps it to 5
  blocks above terrain. No threat to Waystones or exploration mods.

### 4.3 Confluence: Otherworld — CONDITIONAL KEEP, gate don't nerf
Hardmode consent is a non-issue: the group plays Hardmode anyway.

**Do NOT nerf the gear.** `allowsVanillaEntitiesToPerformStageAttributes` defaults **false**,
so Confluence's compensating mob scaling does not apply to other mods' mobs. Nerfing its gear
makes Confluence's own bosses harder while fixing nothing else. Wesley's instinct was correct.

**The blocker is Life Crystals.** `EverBeneficialItem` does `MAX_HEALTH += crystals × 4.0` as
a permanent modifier, capped at 15 crystals + 20 fruits = **100 HP**. Hardcoded in Java —
**no datapack can retune the number.** They generate in ordinary Overworld caves with no gate,
and they are tradeable.

**THE TEST — run before committing.** The *number* is Java, but *ore generation is worldgen*,
which datapacks own. Try stripping Life Crystal ore from Overworld cave generation so it only
spawns inside Confluence's own dimension. That converts an ungated hour-one freebie into a
reward for entering the mod.

- **Test passes** → Confluence is IN, entry-gated, gear untouched.
- **Test fails** → Confluence is **CUT**. An ungated, tradeable, hardcoded +100 max HP
  available from hour-one caving is exactly the "great power, no effort" case §0 says to kill.

**✅ TEST PASSED — 2026-08-30. Confluence is IN.** Empirical, on a throwaway headless
NeoForge 21.1.249 server (Confluence 1.2.4-260226), two worlds, same seed, 3,364 chunks
region-scanned each:
- **Control** (no datapack): `confluence:life_crystal_block` in **131 chunks**.
- **Override** (datapack active): **0 chunks** — and the canary held (`demon_altar` still
  generated, 129 chunks), proving the modifier was *replaced*, not disabled.
- **Mechanism:** fully data-driven. `confluence:overworld_ud` is a `neoforge:add_features`
  biome modifier on `#c:is_overworld` adding 20 features. The shipped datapack
  **`datapacks/confluence-gate-life-crystal`** overrides that one file with the same list
  minus `confluence:life_crystal` — the other 19 (gem trees, **Crimson/Demon altars**,
  traps, detonator veins) are progression-critical and untouched. Do NOT "simplify" it to
  `neoforge:none`.
- **Corrections to the premise:** Confluence has **no custom dimension** — its biomes
  (corruption/crimson via world presets, `glowing_mushroom` via bundled TerraBlender)
  inject into the Overworld. The gate is therefore *biome*-gated, not dimension-gated:
  the `glowing_mushroom` cave biome carries its own `glowing_mushroom_life_crystal`
  feature (6/chunk, deliberately untouched), so crystals = find a glowing mushroom cave.
  Second path: golden/titanium **fishing crates** roll a life crystal at 10/80 (12.5%) —
  a slow trickle, acceptable.
- **Side findings:** (1) Confluence hard-requires **Curios ≥9.5.1** — Modrinth metadata
  falsely says zero deps; server crashes at boot without it. `curios` added to
  modlist-modrinth.txt. (2) Confluence bundles **TerraBlender 4.1.0.8** jar-in-jar — BoP
  also uses TerraBlender; jar-in-jar resolves highest version, but watch it at pack-build.

### 4.4 Boss-check datapacks — approved
Apply the `#c:bosses` tagging so Apothic Spawners cannot farm Cataclysm / Mowzie's elites.
(The Alex's Caves leg is moot — that mod is now cut.)

---

## 5. ACCEPTED RISKS — decided, not overlooked

- **Apothic Spawners kept as-is.** ~400× loot rate; a maxed spawner attempts **16 spawns per
  second** with a 32-alive cap. Highest entity-tick cost of anything in the pack. Wesley's
  call: the group likes farms, and infinite loot is a feature here.
  - ⚠ The TPS budget freed by cutting Cobblemon is partly spent here.
  - ⚠ **Apothic Spawners and Gateways to Eternity both mixin the vanilla spawner**
    (`SpawnerBlock` / `SpawnerBlockEntity`). Both are in. **Test this pairing early.**

- **Apothic Attributes armor math left alone.** It silently rewrites global armor to
  `a/(a+armor)`; **toughness no longer reduces damage at all**; Protection becomes 2.5%/point
  capped at 85% (vanilla: 4%/80%). Full netherite + Prot IV against a 30-damage hit takes
  **7.71 instead of 4.75 — +62%**. Every Cataclysm and Mowzie's boss will hit meaningfully
  harder than its author ever tested. Wesley's call: that is a feature.

---

## 6. STILL OPEN

1. ✅ **`01 §0.1` attribute-prefix question — RESOLVED 2026-08-30, audit confirmed.**
   Headless vanilla 1.21.1 server test: `minecraft:generic.max_health` /
   `minecraft:generic.attack_damage` resolve and return values; the unprefixed forms fail with
   *"Can't find element … of type 'minecraft:attribute'"*. The `generic.` drop is 1.21.2+.
   Every on-disk datapack already uses `generic.` — **change nothing**; doc 00's "fix" would
   have broken them silently.
2. ✅ **The Confluence Life Crystal worldgen test — RESOLVED 2026-08-30, PASSED.**
   Confluence is IN, entry-gated by `datapacks/confluence-gate-life-crystal` (full results
   in §4.3). All three freeze-gating tests are now complete, and the **modlist was FROZEN
   the same day** (Wesley's call, 2026-08-30).
3. **Every `Hours` figure in doc 00 §2 is estimated, not measured.** Acceptable under §0
   (triage sort, not tuning target) — but do not quote them as fact.
4. ~~Naturalist vs Primal~~ — **RESOLVED 2026-08-30.** Naturalist wins; 8 keys off in
   `config/primal-*.toml`. See §3. Two follow-ups it surfaced are still open:
   **(a)** populate Primal's `<x>ExtraBiomes` lists with BoP *and* Terralith biome IDs, or
   half the spliced map gets no Primal wildlife;
   **(b)** datapack out Primal's craftable `minecraft:trident`.
5. **12 "insufficient data" mods** were never audited for power numbers (`00 §9`). Under §0
   this is lower-stakes: re-open only if one turns out to hand out cheap strong gear.
6. ✅ **Creature Features — CUT (Wesley confirmed 2026-08-30).** Surfaced by the
   distribution scan: **no 1.21.1 build exists anywhere.** Its only file ever is
   `creature_features-1.0.0.jar` (1.20.1 **Forge**, CF id 1640797); not on Modrinth at all.
   Same category as Alex's Caves — unavailable, not cut-by-judgment. Removed from
   `modlist-curseforge.txt`. *(Scan side-results, already applied:
   `ars-n-spells` + `structory-towers` block third-party CF downloads → moved to the
   Modrinth list, both with proper neoforge-1.21.1 builds; every other slug verified
   downloadable — 65 CF pinned `slug:id` + 25 Modrinth.)*
