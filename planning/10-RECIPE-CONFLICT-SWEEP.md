# 10 — Recipe conflict sweep (2026-09-01)

Triggered by a live report: crafting the Rechiseled chisel produced a Confluence iron
short sword; a same-day datapack moved the short sword and the result became a Simply
Swords iron sai. Whack-a-mole, because the fix was made without enumerating the shape.

## 1. The mechanic

Vanilla has **no recipe priority**. `RecipeManager` stores crafting recipes in a
hash-ordered multimap and returns the **first match it walks into** — deterministic per
version, arbitrary in practice, and not influenceable. Two recipes on the same grid means
one of them is simply uncraftable. The only fix is to make the shapes differ.

Three things make these conflicts hard to see by eye:

1. **Shaped recipes match mirrored.** `ShapedRecipePattern` tries the grid normally *and*
   horizontally flipped, so a diagonal and its anti-diagonal are the **same slot**. You
   cannot dodge a conflict by flipping it.
2. **Equivalent tags read as different strings.** The chisel used `c:rods/wooden`, the sai
   `c:wood_sticks`. Same items, so any text-level search misses the pair.
3. **Empty rows/columns are trimmed before matching.** `["  ", " X", "# "]` and `[" X","# "]`
   are one shape.

## 2. Method

Indexed every `minecraft:crafting_shaped` recipe in all 130 mod jars plus the deployed
datapacks: resolve keys to ingredients, alias equivalent tags, trim, canonicalise for
mirroring, then group. Rules that matter for a re-run:

- **Only `data/<ns>/recipe/` (singular).** 1.21 renamed the folder; a `recipes/` path is
  dead data and produces phantom conflicts (this is what `simplyswords:dreadtide` was).
- **Datapack overrides replace the jar recipe of the same path**, and the last pack in
  `deploy-datapacks.ps1`'s `$active` order wins between datapacks.
- **Evaluate conditions.** A recipe behind a false `zeta:flag` / `supplementaries:flag` /
  `neoforge:false` never loads and is not a conflict. Check the config, don't assume.
- Skip `datapacks\_retired\` — it is not deployed.
- **Index VANILLA too.** Its recipes live in
  `libraries
et\minecraft\server\<ver>\server-<ver>-extra.jar` (634 shaped ones).
  Scanning only mod jars misses every vanilla collision — see §7.
- **Index custom recipe TYPES, not just `minecraft:crafting_shaped`.** Anything that
  resolves in the 3x3 grid competes in the same lookup: `bf_blockpack:crafting_shaped`,
  `sophisticatedstorage:storage_tier_upgrade`, `sophisticatedcore:upgrade_next_tier`,
  `apotheosis:potion_charm_crafting`. Separate stations do NOT compete and must be
  excluded: `create:mechanical_crafting`, `twilightforest:uncrafting`,
  `gateways:gate_recipe`, and Confluence's heavy_work_bench / hardmode_anvil / loom /
  sawmill / solidifier.
- **Known blind spot:** this method finds only EXACT signature matches. Tag-vs-item
  overlaps (`#minecraft:planks` vs `minecraft:oak_planks`) are real in-game collisions
  it does NOT report. 8 oak planks matched three recipes at once for exactly this reason.

## 3. Findings — 11 shape collisions, 8 real

| # | shape shared by | verdict |
|---|---|---|
| 1 | `rechiseled:chisel` · `confluence:iron_short_sword` · `simplyswords:iron_sai` | **3-way**, fixed |
| 2 | `simplyswords:iron_spear` · `structurize:sceptersteel` | real, fixed |
| 3 | `aether:iron_ring` · `awakened:water_canteen` | real, fixed |
| 4 | `quark:gold_bars` · `supplementaries:gold_bars` | real, fixed |
| 5 | `farmersdelight:beetroot_crate` · `quark:beetroot_crate` | real, fixed |
| 6 | `farmersdelight:carrot_crate` · `quark:carrot_crate` | real, fixed |
| 7 | `farmersdelight:potato_crate` · `quark:potato_crate` | real, fixed |
| 8 | `cataclysm:stone_tiles` · `supplementaries:stone_tile` | real, fixed |
| 9 | `simplybows` rune etching ×4 (bounty/chaos/grace/pain) | **self-inflicted**, fixed |
| 10 | `confluence:iron_hammer` · `quark:hammer` | **not real** — `"Enable Hammer" = false` |
| 11 | `confluence:lead_ingot` ×2 | **not real** — same input, same output; harmless |

Plus one phantom from the old folder name: `simplyswords:dreadtide` appears twice only
because the jar still ships a dead `recipes/` (plural) copy.

**#9 is the one worth remembering.** All four Simply Bows rune etchings in
`simplybows-parity` were written with the identical `GEG / ESE / GEG` pattern, so three of
the four upgrades were uncraftable from the day that pack shipped. A datapack can collide
with *itself*; run the index over `datapacks\` too, not just the jars.

## 4. Changes applied

All in `datapacks\pack-balance\` (loads last, so it wins) unless noted.

| recipe | new shape | why this side moved |
|---|---|---|
| `rechiseled:chisel` | `iron _ stick` (one row, gap) | Rechiseled has one chisel; the Simply Swords sai family shares its shape across ~20 metals |
| `structurize:sceptersteel` | iron / stick / stick (vertical) | same — spear family vs. a single item |
| `awakened:water_canteen` | 2×2 iron | Aether's ring is the more iconic recipe |
| `supplementaries:gold_bars` | two vertical columns of 3 | Quark keeps `["###","###"]`, the intuitive parallel to vanilla iron bars |
| `cataclysm:stone_tiles` | four corners of a 3×3 | Supplementaries is the decoration mod; Cataclysm's tile is incidental |
| `farmersdelight:{beetroot,carrot,potato}_crate` | **disabled** via `neoforge:false` | see below |
| `simplybows:rune_etching_{chaos,grace,pain}` | three distinct 3×3s, same ingredient cost | in `simplybows-parity`; `bounty` keeps the original |

**Why the crates were disabled rather than moved:** nine identical items have exactly one
possible arrangement in a 3×3 grid, so there is no second shape to move them to. Making one
shapeless does not help either — shaped and shapeless are both `RecipeType.CRAFTING` and
compete in the same lookup. Farmer's Delight's three were dropped because Quark's crate
family also covers apple / golden apple / golden carrot, which do not collide; killing
Quark's three would have split the family across two mods. `neoforge:false` removes only the
**recipe** — the crate blocks stay registered, so nothing placed in the world breaks.

The mod-idiomatic alternative is `farmersdelight-common.toml` → `enableVanillaCropCrates =
false`. Deliberately not used: `config\` is gitignored and the server was live, so a datapack
override keeps the change tracked, atomic with the rest, and safe to apply without a stop.

**`supplementaries:gold_bars` keeps its `supplementaries:flag` condition.** Dropping the
condition from an override would make the recipe load even with the module turned off.

## 5. Result

5,375 live shaped recipes across 5,374 distinct shapes. One collision remains — the
harmless Confluence lead-ingot duplicate above.

## 6. Re-running this

Re-run the index after any modlist change, pack update, or new recipe datapack. A conflict
is silent: no log line, no crash, just a player getting the wrong item and assuming they
misremembered the recipe.

---

## 7. CORRECTION (same day, 2026-09-01) — the numbers above were wrong

Sections 3–5 came from a scanner that indexed **only mod jars** and **only
`minecraft:crafting_shaped`**. Both limits were wrong, and §5's "5374 distinct shapes,
1 remaining collision" was badly understated.

| scan scope | collisions found |
|---|---|
| mod jars, vanilla recipe type only (§3) | 11 |
| + custom grid recipe types | 61 |
| + vanilla's own 634 recipes | **130** |
| after removing Block Pack | **7** |

**Block Pack was the whole story.** `bf_blockpack` accounted for ~120 of the 130. It
duplicated Quark's decorative blocks wholesale, collided with *itself* (`X_roof` vs
`X_roof_small`, four copper guardrails), and — the serious part — collided with roughly
**70 vanilla recipes**, including `iron_chestplate`, `iron_boots`, `minecart`, `rail`,
`white_wool`, `lantern`, `stone_bricks`, and every wooden fence / trapdoor / slab /
chiseled-copper variant. Which side won each was arbitrary hash order, so core
progression items were silently uncraftable.

Removed from the pack (commit `0daafd9`), delivered 2026-09-01 14:29. Cost was measured
first, across 752 region files and 1109 entity files with zero decompression errors:
**1** placed block (`bf_blockpack:workbench`), **43** wandering-trader entities, **0**
items in any player inventory, ender chest, or container. Those traders carried
`PersistenceRequired` with no spawn config anywhere — an unbounded entity leak, reason
enough on its own.

### 7.1 A regression this sweep introduced

§4 moved `awakened:water_canteen` onto a 2×2 iron square. That is the **vanilla
`minecraft:iron_trapdoor` recipe**, so one of the two has been uncraftable ever since.
The scanner could not see it because vanilla was not indexed. Corrected to the 3×3
corners shape (`I I` / `   ` / `I I`), verified free against all 6102 grid recipes.

**This is the whole point of the document: verify a replacement shape against vanilla +
mods + datapacks + custom types, or you just move the bug.** While picking the
replacement, the natural-looking `I.I / .I.` turned out to be `minecraft:bucket`.

### 7.2 The 7 that remain

- **Real:** `minecraft:chiseled_polished_blackstone` vs `cataclysm:blackstone_pillar`;
  `minecraft:stone_pressure_plate` vs `confluence:stone_pressure_plate`
- **Harmless** (two recipes, one output): `spectral_arrow`, `cake`, `leather`
  (Naturalist duplicates of vanilla), `confluence:lead_ingot` (two ids, same result)
- **Fixed, pending a `/reload` or restart:** `awakened:water_canteen`

### 7.3 Not a collision

`sophisticatedstorage:chest` was reported in-game as losing to `quark:oak_chest`. It is
not a collision: **all 24 recipes producing an SS chest require a lever in the centre
slot** (`PPP/PLP/PPP`), while Quark's chests are the empty-centre vanilla shape from
planks or logs. They never competed. The genuine contention on 8 oak planks was
vanilla's `#planks` chest vs `quark:oak_chest` vs `bf_blockpack:empty_crate` — a
tag-vs-item overlap the scanner cannot report (§2).

**CONFIRMED IN-GAME by Wesley, 2026-09-03: both craft correctly, no fix shipped.**

SS additionally ships its own escape hatches, so a quark or vanilla chest is never
stranded inventory:

| recipe | type | input |
| --- | --- | --- |
| `<wood>_chest` | shaped | 8 planks of that wood + **lever in the centre** |
| `<wood>_chest_from_quark_<wood>_chest` | **shapeless** | quark chest + lever, anywhere in the grid |
| `oak_chest_from_vanilla_chest` | **shapeless** | vanilla chest + lever |
| `generic_chest` | `sophisticatedstorage:generic_wood_storage` | `#minecraft:planks` + lever; derives wood type from the planks used |

24 = 11 woods x (direct + from_quark) + `generic_chest` + `oak_chest_from_vanilla_chest`.
`copper_chest` (`CCC/CSC/CCC`, type `sophisticatedstorage:storage_tier_upgrade`) accepts
**only** `sophisticatedstorage:chest` in the centre — that is correct, not a bug; convert
first. Item enablement is config, not data: `sophisticatedcore-common.toml` ->
`enabledItems` -> `sophisticatedstorage:chest|true`.

### 7.4 Verifying a recipe on the RUNNING server

A jar read proves what *should* load; a datapack read proves what *should* override. Only
the live server knows what actually registered. There is no vanilla read-only recipe query,
but `recipe give` is one by side effect:

```
recipe give @a sophisticatedstorage:oak_chest   ->  "No new recipes were learned"   (exists)
recipe give @a sophisticatedstorage:not_a_thing ->  "Unknown recipe: ..."           (absent)
```

It parses the recipe id **before** it resolves targets, so it works with zero players
online and mutates nothing when the players already know the recipe.

**Always send a known-bad id in the same batch as a control.** Without one you are matching
against a response string you never calibrated, which is how a silently-renamed recipe reads
as present. Do not substitute JEI: it renders client-side, and before 2026-09-01 it was
rebuilding recipes from client jars entirely (see playbook 01 §6.2).
