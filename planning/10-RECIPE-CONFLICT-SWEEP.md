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
