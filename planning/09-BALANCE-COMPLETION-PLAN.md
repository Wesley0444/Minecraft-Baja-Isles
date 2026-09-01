# 09 — BALANCE COMPLETION PLAN (handoff for a fresh session)

**Status: BUILT 2026-08-31 evening — STAGED, awaiting the bounce.** Everything below
is implemented on disk; nothing is live until `balance-bounce.ps1` (server root) runs
in the go window (Wesley's call — Teyters was online). Original plan text kept below
for the record; per-item status + build findings in §8 at the end. Written at the end
of the session that ran the reseed (doc 08) and then diffed doc 00 against everything
downstream (doc 01 §2/§5 tiers, doc 03 decisions, doc 06 applied record, the on-disk
datapacks, live configs). Result: several audit items never received a decision
anywhere, and the deliberately-dropped buff half of the pass is being revived.
**Every verdict below is Wesley's call, made 2026-08-31 in conversation — do not
re-litigate.**

Read first if you're new: doc 03 §0 (the kitchen-sink philosophy — only cheap-strong
gear and mechanic deletions get nerfed; expensive-but-strong is fine), doc 06 (what's
already applied — do NOT re-apply), doc 06 §0 (config/datapack gotchas learned live).

---

## 0. Ground rules for the implementing session

- **All datapack changes** go through the repo `datapacks\` folder → deploy with
  `datapacks\deploy-datapacks.ps1` → they land in `config\paxi\datapacks`. **Read
  deploy-datapacks.ps1 first** to see how it selects packs and whether load order is
  name-dependent before creating any new pack folder. Current load order (later wins):
  `confluence-gate-life-crystal → deeperdarker-parity → apotheosis-parity →
  simplybows-parity → pack-balance`.
- **Attribute ids on 1.21.1 keep the `generic.` prefix** (`minecraft:generic.attack_damage`).
  Dropping it is a 1.21.2+ ism and fails silently. Verified live — doc 03 §6.1.
- **Copy the mod's real JSON, change only what you must.** Doc 01's inline JSONs contain
  guessed reagents/ids (it says so). Extract the shipped file from the jar
  (`[IO.Compression.ZipFile]::OpenRead` + ExtractToFile), then edit.
- **Recipe-result buffs ride item components** — attribute_modifiers baked into the
  crafted item. Tooltips will be correct on clients with no config shipping. Existing
  already-crafted items keep old stats (fine — world is 1 day old).
- **Server bounce procedure:** RCON announce (scratch client pattern: see
  `backup.ps1`'s RCON functions) → graceful `stop` → edit configs → deploy datapacks →
  relaunch via `launch.bat` (as the server currently runs: Wesley-user detached process
  until the box reboots; check port 25565 first, never double-launch) → verify. Check
  `discord-bot\README.md` for the maintenance-lock path so the bot doesn't announce a
  fake outage. Batch EVERYTHING into ONE bounce.
- **Verification per change** is listed inline; doc 01 §6 has the general protocols
  (JEI recipe check, `/attribute` server-truth check, DPS bench).
- ⚠ **The in-game number a tooltip shows can lie** when stats come from server configs
  the client doesn't have (doc 06 §6.4). Component-based buffs (this plan's method)
  don't have that problem; config-based nerfs (Awakening) do — add those configs to
  the step-7 "ship in pack" list (doc 06 §6 item 4).

---

## 1. NERF SIDE — decided misses (Wesley's verdicts 2026-08-31)

### 1.1 The Awakening — global ability nerf  ← the headline miss (see doc 08 context)
The mod fell through every doc: audit priced it hot (~3× at 20h, doc 00 §2), doc 01 §2
never wrote its fix section, so step 5 executed nothing. Live config = all defaults
while everything around it got compressed to netherite parity. David's report verified
against bytecode: Geokinetic's **Great Maul ability lands ~23–32+ damage at zero
investment** (base ~14 × terrain multipliers 1.6–1.7 + pin/grind ticks + splash),
available ~hour 1 (awaken at 3 hearts, Catalyst reroll to any power is cheap).

**Fix (config, `config\awakened-common.toml`):**
- `[abilities] damageMultiplier = 1.0 → 0.5` — applies on top of all mastery/Ability
  Power scaling; the config comment says it exists for exactly this.
- Leave `additiveDamageStacking = true` (already the sane mode).
- Leave Catalyst costs/cooldown alone — cheap rerolls are the mitigation for the
  random-power variance problem (doc 00 §5.3), don't tax them.
- **Follow-up lever, don't use yet:** per-ability `damageOverrides =
  ["<AbilityClassName>=<mult>"]` — exact keys are printed to the server log as
  "Ability balance-override keys". If the Maul still towers after a session at 0.5,
  add `"GreatMaulAbility=0.6"` on top. Watch a real session first.
- Add `awakened-common.toml` to the doc 06 §6 #4 ship-configs list (ability tooltips
  render client-side).

**Verify:** log line "Ability balance-override keys" appears at boot (proves config
parsed); have someone cast on a test mob, damage roughly halves.

### 1.2 Eternal Starlight — Starfall Longbow REMOVED (Wesley: "remove it")
~450 single-target burst per arrow (9 meteors × 50 dmg, i-frame-bypassing) = same
mechanic-deletion class as the Tier-0 executes. `playerAethersentMeteorDamageScale`
is NOT the fix (scoped to damage *to players*) — doc 01 §2.11.

**Fix (datapack, pack-balance):** condition-false override of its recipe at
`data/eternal_starlight/recipe/<id>.json`. ⚠ Get the exact recipe path/id from the ES
jar (search entries for `starfall`); doc 01 guessed names before. **Also grep the
jar's loot tables for the bow** — if it drops anywhere, shadow those entries too, or
the recipe removal is cosmetic.

**Also, same file-drop, the Gatekeeper knobs** (live `config\eternal_starlight.json`,
verified untouched): `enableBossRespawn true → false`, and while there confirm
`bossRespawnCooldown` becomes moot. Structure density was already thinned at step 5
(doc 06 §2) — this closes the farm/ambush half doc 01 §2.11 asked for.

**Verify:** JEI shows no Starfall Longbow recipe; `/give` still works (item exists,
acquisition doesn't).

### 1.3 Aether — Valkyrie Lance out of loot + Altar vanilla repairs off
(Phoenix armor fire immunity: **ACCEPTED as-is** — Wesley 2026-08-31. Behind real
progression, fits §0. Recorded; no action, don't re-raise.)

**Valkyrie Lance** (+3.5 reach is Java-baked, loot removal is the only clean fix):
copy the jar's `data/aether/loot_table/chests/dungeon/bronze/bronze_dungeon_treasure.json`,
delete the `aether:valkyrie_lance` entry, ship as pack-balance override. ⚠ Grep the
jar for `valkyrie_lance` across ALL loot tables first — if silver/gold dungeons also
roll it, decide: bronze-only strip (lance becomes a rarer, later reward — fine under
§0) is the minimum; Wesley's instruction was "remove from bronze loot", so bronze only.

**Altar free vanilla repairs** (undercuts the Apotheosis gear economy): the jar ships
`data/aether/recipe/*_repairing.json` for VANILLA gear (diamond_sword_repairing,
bow_repairing, etc. — doc 01 §2.18). Enumerate them from the jar; condition-false
override each vanilla-item one; **keep every Aether-item repair recipe**.

**Verify:** bronze chest loot rolls (spawn a chest via `/loot` against the table id);
Altar no longer accepts a damaged diamond sword, still repairs Aether gear.

### 1.4 Apothic Enchanting — light touch only (Wesley: "do the light touch")
Caps (Sharp 9/Smite 10/Prot 8) and the exclusive-set stacking: **ACCEPTED** — eterna
60–100 infrastructure isn't "cheap" under §0, and infinite XP was already accepted
via Spawners. Recorded; leave `enchantments.cfg` alone.

**What goes: the infusion economy breakers** (doc 00 called these out specifically):
- echo shard 1→4 infusion (makes D&D's currency infinite)
- XP bottle 1→8 and 1→32 infusions
**Fix (datapack, pack-balance):** condition-false overrides. Find exact paths in the
Apothic Enchanting jar under `data/apothic_enchanting/recipe/` (likely type
`apothic_enchanting:infusion` or `:keep_nbt_infusion`); grep entries for `echo_shard`
and `experience_bottle`.

**Verify:** JEI — infusing an echo shard / XP bottle shows no result.

### 1.5 Simply Swords — kill the generic chest-loot dilution ⚠ THE TRAP ITEM
Wesley: "buff it" — turning SS's chest injection off is doc 01 §2.7's "buff to five
other tracks disguised as a nerf" (structure mods get their reward identity back).

⚠ **DO NOT blindly set `enableLootDrops = false`** in `config\simplyswords\loot.toml`.
The same config block carries `runicLootTableWeight` (Runic Tablets) and
`uniqueLootTableWeight` (Uniques + the pity counter) — those ARE the Simply Swords
progression track (60–120h). If the master switch kills them too, the track dies.
**First determine scope** (read the mod's loot injection code in the jar —
`SimplyswordsChestLootRules`-ish class — or the mod's config docs): 
- If the master switch spares nothing → set `standardLootTableWeight 0.1 → 0` and
  `rareLootTableWeight 0.4 → 0`, keep `runic 0.7` / `unique 0.05` / master `true`.
- If generic weapons have their own toggle → use it.
`enableLootInVillages` is already `false`; leave it.

**Verify:** doc 01 §6.4 loot check — roll a WDA/TF chest table a few times, no generic
SS weapons; confirm the pity-counter/unique path still documented as alive (worst
case: creative-test a chest run).

**~~Optional Wesley decision, parked~~ DECIDED (Wesley, 2026-08-31 late): shorten
the chain.** Build finding: the 8-tablet count is HARDCODED (the Runic Forge block
has 8 awakening slots — in-jar oracle_index book confirms; the only config toggle is
all-or-nothing `enableUniqueWeaponAwakening`). Implemented as the grind-equivalent
rate change instead: `runicLootTableWeight 0.7 → 1.4` + `tabletHardPity 60 → 30`
(both in `loot.toml`, staged in balance-bounce.ps1). Tablets arrive twice as fast →
8 tablets cost what 4 used to; the level-4 ability unlock lands proportionally
earlier too. Same outcome, zero code.

### 1.6 Recorded accepts (so the next auditor doesn't re-find them)
- **Artifacts absent from the pack** — silent manifest drop, nobody decided it, Wesley
  2026-08-31: "odd, but that's ok at this point". It stays out. (If it ever comes
  back: freeze reopening, Wesley-only; post-pregen its campsites will never generate,
  loot injections still work.)
- **Phoenix armor** — accepted (above).
- **D&D Warden Leggings +50% walk speed** — accepted (Java attribute, not
  datapack-fixable without adding AttributeFix/KubeJS; not worth the tooling).
- **Apothic Enchanting caps/stacking** — accepted (above).

---

## 2. BETTER COMBAT FOLLOW-THROUGH (Wesley: "we still need this")

Goal: Cataclysm (and any badly-landed weapon mod) gets real `weapon_attributes`
instead of BC's generic fallback regexes. Doc 03 §3 ordered "exactly one Cataclysm ×
Better Combat compat pack — three exist"; none was ever installed.

**Preferred route — datapack, not mod** (avoids freeze reopening #5 AND the
client-smoke-test requirement *if* BC syncs):
1. **Verify first:** does Better Combat network-sync server datapack
  `weapon_attributes` to clients? (Check BC's docs/source — it syncs its config;
  confirm the data layer.) If clients render animations from their OWN data only,
  the datapack route half-works (server hitboxes right, client anims generic) —
  then fall back to route 2.
2. **Fallback route — add one compat mod as a pack stub** (freeze reopening #5,
  pre-authorized by Wesley for this purpose 2026-08-31): pick the best-maintained of
  the three Cataclysm×BC packs on Modrinth/CF, jar-scan it worldgen-free (chisel-suite
  precedent, doc 03), add stub, packwiz refresh. ⚠ Client-facing pack change → **the
  house rule applies: client launch smoke test via the Prism instance** before calling
  it done.
3. Either way: **audit `config/bettercombat/fallback_config.conf`** against the
  installed weapon mods (Epic Knights, Antarchy, Aquamirae, Simply Swords is
  hand-tuned already) and hand-author `weapon_attributes` JSONs for anything that
  landed on a bad fallback. This surface is also THE tool for buff-pass re-tiering
  (doc 01 §2.19 end — "reach for this first").

---

## 3. BUFF PASS (the revived half — Wesley: "let's aim to complete this")

Deliberately dropped at doc 03 §0.2; being reversed by Wesley 2026-08-31. A half-built
skeleton exists at `datapacks\_retired\parity-underreward\` — **treat it as reference,
not as ready**: doc 01 tier #9's own caveat says its Undergarden override only reaches
0.80× (it *worsens* nothing but fixes nothing). Build a fresh pack (suggested name
that sorts after pack-balance if Paxi order is alphabetical — verify per §0), add it
to the deploy script + doc 06 §1's load-order note.

Mechanism for all sword buffs: copy the mod's shipped recipe JSON, override only the
`result` with `minecraft:attribute_modifiers` components (see doc 01 §2.11's template
for the shape — but take reagents/ids from the real jar file, its `moonring_ingot`
was an explicit guess). Components → correct tooltips everywhere, no config shipping.

| # | Buff | Target | Source | Traps |
|---|---|---|---|---|
| 1 | **Cataclysm Void Forge + Infernal Forge** | ~1.2–1.5× netherite | doc 01 §2.8 (read it — exact numbers there; tier #6 called this the group's stated nightmare: 40h of 600-HP bosses for a DPS downgrade) | The weapons come from boss loot, not recipes — check whether the buff needs a loot-table result override or (if items have fixed components) a different mechanism; §2.8 has the plan |
| 2 | **Undergarden Utherium + Forgotten swords** | 1.2× / 1.4× | doc 01 §2.12; retired pack = reference only | Recompute amounts — retired version hit 0.80×; the 1.5× vs-Undergarden-mobs bonus is separate from base damage, don't double-count |
| 3 | **ES Moonring Greatsword** | 16 dmg @ 1.8 (~1.6×) | doc 01 §2.11 template | ⚠ copy real recipe, verify reagent id |
| 4 | **TF Fiery Sword** | doc 01 §2.10 | retired pack has a version | ⚠ **must re-add the Fire Aspect II component or the buff is a net nerf** (tier #21) |
| 5 | **Gateways `emerald_grove` rewards** | pay comparably to its effort (its sibling paid an infinite skull engine pre-nerf) | doc 00 §4.3; mirror the structure of the (already-nerfed) `hellish_fortress.json` override in pack-balance | Keep it themed (farm/village goods, just *more*), not raw power |
| 6 | **Bountiful board tilt** | inject compensating rewards into thin tracks; doubles as the unequal-hours mitigation (doc 01 #32) | doc 01 §1.10.1 | Design task, not a file edit — fine to defer to step 7 / track-menu work with Wesley |
| 7 | *(only if doc 01 §2.8 lists more Cataclysm drops as cold)* | — | §2.8 | Don't scope-creep; the forges are the named items |

**Verify:** craft each in creative on a test world (or live after deploy — recipes are
server-side), check tooltip damage matches target, one DPS bench per doc 01 §6.3.

---

## 4. CULT OF AZAZEL — audit COMPLETE (2026-08-31, report below)

**Verdict: KEEP** — with a barrel-loot datapack trim, two optional config flips, and
one timing-sensitive decision (Nether structure density) that must be settled
**BEFORE the Nether pregen window**. Note the audit's key finding: the "Nether-only
worldgen" assumption was FALSE — Azazel has overworld structures already baked into
the live world, so the cut window was closed regardless. Happily the verdict is keep
on merit, not just by force.

**Implementing session — fold these into the maintenance bounce:**
1. **Barrel-loot trim (the one near-🔴):** Paxi datapack override of
   `netherman:chests/azazel_barrel` + `azazel_human_barrel` in pack-balance. Copy
   the real JSONs from the jar (§0 rule), keep the gear pools intact, trim materials:
   netherite scrap 12→4 / 20→8, e-gold-apples 4→1 / 10→2 (diamonds analogous, ~25→10 /
   55→20). Rationale: repeatable 800-HP boss refunds 3× its own summon cost per kill.
2. **Config flips** in `config\netherman-common.toml` (server config is global on
   NeoForge 21.1): `azazelArmorBlockBreaking=false` (grief/terrain vector — elytra
   chestplate breaks blocks at speed). `maskFireImmunity` stays TRUE for now —
   consistent with Wesley's Phoenix-armor accept; flip later if it grates.
   ✅ **`azazelArmorBlockBreaking=false` APPLIED 2026-08-31 18:25** during the
   reboot config window (server stopped). Verify live post-boot.
3. **Wesley decision, pre-Nether-pregen:** structure density in
   `config\cristellib\netherman\structure_placement_config.json5` — gast_chamber and
   minor_points at spacing **8/4** is very dense, mansion 45/16. Recommend spacing
   those out (e.g. gast_chamber 8/4 → 24/12, minor_points 8/4 → 16/8) before the bake
   locks them in. Zero datapack needed — json5 edit only, but ONLY effective pre-pregen.
   ✅ **DECIDED (Wesley, 2026-08-31): audit's rec. APPLIED 18:25** — gast_chamber
   24/12, minor_points 16/8, same reboot window. **Nether pregen is no longer
   Azazel-gated**; the only remaining Azazel work is item 1's barrel-loot trim
   (retroactive loot datapack — does not gate the bake).
4. Optional watch item: Totem of Rebirth (2-use death-cancel) sits in *overworld maze*
   chests, pre-Nether. Override `netherman:chests/maze_loot` only if it proves cheap
   in practice — not part of the bounce.

### §4.1 Full audit report (background agent, 2026-08-31)

**Jar:** `mods\cultofazazelneoforge-1.1.4.12.jar` (10.9 MB, Modrinth `tnd2BYam`) ·
**Version:** 1.1.4.12 = latest NeoForge 1.21.1 build (2026-08-15; actively maintained,
~weekly releases) · **Author:** Benj1kus, MIT.

**Build quality: NOT the next Antarchy.** Hand-written NeoForge mod
(`com.benji.netherman`, clean client/common split, GeckoLib) — not MCreator slop.
Boss stats/mechanics are config-driven via `config\netherman-common.toml` (boss HP,
per-attack damage, spawner cooldowns, feature toggles), worldgen placement is
Cristellib-tunable via `config\cristellib\netherman\structure_placement_config.json5`
+ `structure_toggle_config.json5`, all loot is data-driven JSON (datapack-overridable).
Item stats are Java-hardcoded (extracted via javap).

**Bosses** (both summon-triggered, never natural-spawn — already matches post-launch-night
policy):
| Boss | HP | Notes |
|---|---|---|
| The Divine Chariot Azazel | 800 (config) | KB-immune (config), attacks 4–8 + minions, fire ring 8/tick, item→gold "Midas", blackstone prison. Summoned at player-built altar: craftable Blackstone Socle + 4 gold blocks + 4 ancient debris (bytecode-confirmed; appears to consume only the socle) |
| The True Azazel | 1000 (config) | Attacks 10–30, spikes = Wither 5s, phase 2, cutscene. Spawned via multi-stage Cult Scroll quota questline (`QuotaManager`) — long progression; failing quotas applies a penalty attribute |

**Gear** (all from boss reward barrels — zero crafting recipes for gear):
- **Longinus/Judicus** — spear 12 dmg @1.6 (19.2 DPS) ⇄ scythe 20 dmg @1.0 (20 DPS)
  on a timer; projectile ability (5s CD), 4200 durability, ench 22, netherite repair.
  ≈1.5× netherite DPS ≈ Sharpness-V netherite before enchants.
- **Armor set:** 3/8/6/3 = 20 armor (= netherite), toughness 5.0/pc = 20 total (vs 12),
  KB resist 0.4 (=), ench 15. Chestplate is also an elytra with high-speed
  block-breaking (config `azazelArmorBlockBreaking=true`).
- **Aegis of Faith:** 2000-durability shield, RC AoE 8 blocks Wither+Darkness+
  Manipulation 20s, 10s CD.
- **Azazel Mask:** head slot, cancels all fire/lava damage (`maskFireImmunity=true`) +
  auto-totem death-save charges (1 regen / 2 min, mask breaks when depleted; "3 charges"
  per changelog, count not bytecode-confirmed).
- **Totem of Rebirth:** 2-use death-cancel + TP-to-spawnpoint, Curios-slottable; also
  summons a friendly Gehinnom Guard.
- **Staff of Manipulation:** mob mind-control (PvE utility).

**Acquisition + the one real outlier.** Barrel loot gives everything, every kill, no
RNG (`data/netherman/loot_table/chests/`): `azazel_barrel` (800 boss) = mask + 2 rebirth
totems + vanilla totem + staff + **25 diamonds + 12 netherite scrap + 4 e-gold-apples**
+ a free Socle (the re-summon item). `azazel_human_barrel` (1000 boss) = full armor +
spear + 2 shields + mask + 2 totems + **55 diamonds + 20 scrap + 10 e-gold-apples**.
Gear is earned (biggest fights in the mod — §0 says fine). The problem is the
**repeatable material faucet**: the 800-HP boss re-summons for ~1 socle, each kill
refunds 3× the altar's debris cost plus god apples; a 6-man group at ~19 DPS each
melts 800 HP in minutes → netherite/god-apple printer. (Trader 20% nether-star per
netherite ingot = expensive enough to be a non-issue.)

**Worldgen footprint — ⚠ the Nether-only assumption is FALSE:**
| Dimension | Structures | Status |
|---|---|---|
| Overworld | believer_house (64/40), head_altar (taiga 80/30), maze (underground Y −45..−10, all biomes, 80/30), monument (2/world), nether_geyser + pipes (40/20) | **Already baked into the pregenerated world.** Cut = missing-block holes = wipe. Cut window CLOSED. |
| Nether | mansion_nether "Sacred City" mega-dungeon (45/16 — dense for a flagship), gast_chamber (**8/4 — very dense**, crimson/warped), minor_points eye_columns/gehen_statue/trap (**8/4**, wastes/soul sand) — all vanilla-biome-locked, BoP nether biomes stay clean | **NOT yet baked.** Density/toggles tunable RIGHT NOW via the cristellib json5 — only before the Nether pregen window. |

**Flags:** barrel material payouts 🟡 (the only near-🔴 → §4 fix 1); Azazel Mask 🟡
watch (config one-liners exist); chestplate block-breaking flight 🟡 grief vector
(§4 fix 2); armor toughness ✅ earned (in-pack precedent: Cataclysm Ignitium Elytra
Chestplate); Longinus ✅ earned; Totem of Rebirth in overworld maze chests ✅/🟡
(§4 item 4); Nether density 🟡 timing-sensitive (§4 item 3); **mechanic deletions
(executes, player KB-immunity, i-frame bypass): none found ✅.**

**Unverified claims:** mask charge count = 3 (changelog, not bytecode); whether the
altar's gold/debris survive the summon (single `destroyBlock` call, target untraced);
faith-particle farming rate for quota progression (9 `faith_part` → 1 Faith Essence
jar-verified); Crimson Arrow / Manipulation exact mechanics (not decompiled; non-gear
utility); weapon DPS computed from bytecode constants, not live-tested.

Sources: Modrinth `tnd2BYam` (+ versions API), CurseForge cult-of-azazel. Jar unpacked
at scratchpad `azazel\` (session-temporary).

---

## 5. WESLEY'S OWN LANE (not for the implementing session)

Doc 06 §6 open items he's taking himself: Pinnacle-weld framing (a) vs (b), the
Create-gate reversal option (David's vote), Track Menu / house rules post, ship
stat-driving configs in the pack (+ client smoke test) — add `awakened-common.toml`
to that list per §1.1. Plus from this pass: ~~the optional SS awakening-chain
shortening~~ (decided + staged, see §1.5), blessing `world-old-2026-08-31` deletion
(doc 08), and scheduling
the Nether/TF pregen window (~07:00–noon dead time; Azazel gate CLEARED — §4 item 3
decided + applied 2026-08-31 18:25).

## 6. Execution order for the implementing session

1. Read §0. Read deploy-datapacks.ps1. Check §4.1 for appended audit results.
2. Build everything offline: all datapack overrides (§1.2–1.5 nerfs, §3 buffs, §2
   weapon_attributes), config edit list (§1.1 Awakening, §1.2 ES json, §1.5 SS loot).
3. Resolve the two verify-first traps: SS loot key scope (§1.5), BC sync (§2).
4. ONE maintenance bounce: announce → stop → configs → deploy → start → §-by-§ verify.
5. Update this doc's statuses, doc 06 §1 load order, CLAUDE.md registry line.
6. Anything client-facing (BC mod route only) → Prism client smoke test before done.

## 7. UTILITY MOD ADDITIONS (Wesley-CONFIRMED 2026-08-31: all three — freeze reopening, his call)

Three quality-of-life adds to ride the same maintenance bounce. Availability
web-verified 2026-08-31; **jar-scan worldgen-free before adding remains mandatory**
(house rule) even though all are utility-class.

1. **FallingTree** (Modrinth `fallingtree`, 1.21.1-1.21.1.x NeoForge) — chop one log,
   whole tree comes down. **Server-side only** — add as a packwiz stub with
   `side = "server"` so clients never see it (no client smoke test needed for this
   one; chop-speed/enchant extras need the client mod, skip them). Needs the server
   bounce to load — fold into step 4.
2. **Sodium** (Modrinth `sodium`, mc1.21.1-0.6.x official NeoForge builds) — client
   FPS. Packwiz stub `side = "client"` — server untouched.
3. **LambDynamicLights** (Modrinth `lambdynamiclights`, **official 4.x** — multi-loader
   incl. NeoForge 1.21.1; do NOT use the archived unofficial-neoforge port) — held
   torches/glowstone emit light. Packwiz stub `side = "client"`. Lists first-class
   Sodium compat.

Items 2+3 together = ONE client-facing pack change → **mandatory Prism client smoke
test** (registry rule), and this pack is GeckoLib-renderer-heavy (Cataclysm/Azazel/
Ars) so actually look at mobs/spell VFX in the test, not just a boot; also hold a
torch to confirm LDL lights. If anything renders broken: pull the Sodium stub first
(LDL alone is low-risk), make Sodium per-player-optional instead.

---

## 8. BUILD LEDGER — everything below was done 2026-08-31 evening (staged, not live)

**The go button: `balance-bounce.ps1` in the server root** (header documents the full
sequence; idempotent; port-based liveness; `-SkipPush` exists but defeats FallingTree
delivery). Runs: lock → 60s announce → graceful stop → 3 config edits → datapack
deploy → git push → Pages wait → packwiz server sync → `schtasks /Run` → boot-log
verify → lock removed. **Nothing is committed/pushed yet** — the push rides the bounce.

| Item | Status | Where |
|---|---|---|
| §1.1 Awakening 0.5× | staged in bounce script (config edit, match-string verified) | `balance-bounce.ps1` |
| §1.2 Starfall recipe kill | ✅ built — **jar-verified: NO loot-table drops exist**, recipe kill is complete | `pack-balance/data/eternal_starlight/recipe/starfall_longbow.json` |
| §1.2 Gatekeeper respawn off | staged in bounce script | `balance-bounce.ps1` |
| §1.3 Valkyrie Lance | ✅ built — lance was in **two** bronze tables (`_treasure` AND `_reward`), stripped from both, bronze-only per Wesley | `pack-balance/.../bronze/bronze_dungeon_{treasure,reward}.json` |
| §1.3 Altar vanilla repairs | ✅ built — **59** vanilla-target repair recipes condition-falsed, **38** Aether-item repairs kept (gloves are `aether:` items → auto-kept by namespace rule) | `pack-balance/data/aether/recipe/*_repairing.json` |
| §1.4 Apothic infusions | ✅ built — `echo_shard` (1→4), `xp_bottle_2` (→8), `xp_bottle_3` (→32) killed; **`xp_bottle` (→1) kept** — it's a honey-bottle conversion, not a breaker | `pack-balance/data/apothic_enchanting/recipe/infusion/` |
| §1.5 SS loot ⚠trap | **RESOLVED by bytecode** (subagent, high confidence): `enableLootDrops=false` would kill runic tablets + uniques + ALL pity (`PityLootManager.isEligibleChestTable` gates everything). Weights-to-zero is fully safe: generics use loot-pool injection with `randomChance(w/100)`, runic/unique use direct container insertion (Lootr compat included). Staged: `standard 0.1→0.0`, `rare 0.4→0.0`. PLUS chain-shortening (Wesley approved late): `runic 0.7→1.4`, `tabletHardPity 60→30` — see §1.5 for why rate-not-count | `balance-bounce.ps1` |
| §2 Better Combat | **DATAPACK ROUTE VERIFIED VIABLE** (subagent, jar bytecode + BC README): server syncs `weapon_attributes` to clients in the join handshake (config task `bettercombat:weapon_registry`), hitboxes AND animations; datapack beats native jar entries and fallback. NO compat mod needed → **freeze reopening #5 NOT used, no BC client smoke test needed**. ⚠ BC has NO reload listener — weapon_attributes apply at server START only, `/reload` won't do it. Cataclysm 3.33 ships 10 native files; real gap was 3 boss weapons (ravenous_fang = model-only asset, not an item). Built: `meat_shredder→hammer`, `soul_render→halberd`, `khopesh→cutlass` + polish `giant_sword→claymore`, 2× `minotaur_axe→double_axe` (TF), 2× `battleaxe→double_axe` (UG) | `pack-balance/data/{cataclysm,twilightforest,undergarden}/weapon_attributes/` |
| §3.1 Cataclysm forges | ✅ built. Void Forge = recipe override — **codec verified**: `weapon_fusion` result decodes via `ItemStack` codec, components bind. Infernal Forge has NO recipe (Netherite Monstrosity boss drop) → loot-table copy + `minecraft:set_components` on the hammer pool. 16 dmg @1.4 / 15 dmg @1.3 per doc 01 §2.8 | `pack-buffs/data/cataclysm/` |
| §3.2 Undergarden swords | ✅ built — Utherium 11 @2.0; Forgotten = **smithing** override (base is `cloggrum_sword` + forgotten template), 12 @2.1 | `pack-buffs/data/undergarden/recipe/` |
| §3.3 ES Moonring | ✅ built — real reagents are `tenacious_petal`/`tenacious_vine`/`soul_dew` (doc 01's `moonring_ingot` was indeed a wrong guess); 16 dmg @1.8 | `pack-buffs/data/eternal_starlight/recipe/moonring_greatsword.json` |
| §3.4 TF Fiery Sword | ✅ built — 11 dmg @1.7. **⚠ doc 01's Fire-Aspect-II instruction was WRONG for this version**: bytecode shows the 15s ignite is hardcoded in `FierySwordItem.hurtEnemy` (`igniteForSeconds(15.0f)`), no enchantment component involved. Override can't strip it; re-adding FA2 would have DOUBLE-burned. Attributes only; burn survives | `pack-buffs/data/twilightforest/recipe/equipment/fiery_sword.json` |
| §3.5 Gateways emerald_grove | ✅ built — wave rewards ~doubled (hay 48, plants 32s, crops 64s, saplings 32s), final adds **24 emeralds** (it's the EMERALD grove and stock paid zero) + 150 XP; animal summons kept, themed not raw power | `pack-balance/data/gateways/gateways/emerald_grove.json` |
| §3.6 Bountiful tilt | deferred to step 7 / track-menu (per plan — design task) | — |
| §4.1 Azazel barrels | ✅ built — real jar JSONs copied, trims exactly per §4: diamonds 25→10/55→20, scrap 12→4/20→8, e-gold-apples 4→1/10→2; gear/totems/discs/trophies/`nether_spawner` untouched | `pack-balance/data/netherman/loot_table/chests/` |
| §7 utility mods | ✅ stubs added + index refreshed. FallingTree 1.21.1.11 `side="server"` (edited from packwiz's "both"); Sodium **0.6.13** (deliberate pin — battle-tested line; 0.8.13 exists, 3 days old); LDL **4.8.10** official (4.8.11 was hours old). All three jar-scanned worldgen-clean by subagent incl. nested jars, hash-verified, zero extra dependency stubs needed. No embeddium stub in pack (conflict check clean) | `pack/mods/{fallingtree,sodium,lambdynamiclights}.pw.toml` |
| deploy script | ✅ `pack-buffs` added to `$active` (before pack-balance, comment explains) | `datapacks/deploy-datapacks.ps1` |
| doc 06 §1 | ✅ load-order note updated | doc 06 |

**Observed in passing, accepted, for the record:** Cataclysm's Meat Shredder tooltip
says its right-click "damages entities in front (i-frame ignore)" — player-side i-frame
bypass, but on a deep-boss weapon (expensive-but-strong, §0-clean; the Starfall removal
was for i-frame bypass at ~450 burst from a craftable). No action; flagged so nobody
re-discovers it as a "miss".

**Post-bounce manual verification (doc 01 §6 protocols):**
1. Boot log: script auto-greps "Ability balance-override keys" / pack-buffs / fallingtree.
2. JEI: Starfall Longbow recipe gone; echo-shard + xp-bottle-8/32 infusions gone;
   xp-bottle-1 still there; Moonring recipe shows 16 dmg tooltip result.
3. Craft/creative: Fiery Sword tooltip 11 dmg @1.7 AND still ignites; Utherium 11 @2.0.
4. Altar: rejects damaged diamond sword, still repairs zanite/gravitite (+gloves).
5. `/loot give @p loot aether:chests/dungeon/bronze/bronze_dungeon_treasure` a few
   times — no lance.
6. Great Maul damage roughly halved on a test mob.
7. Better Combat: swing Khopesh/Meat Shredder — new combo animations (proves BC sync).
8. **Prism client smoke test for Sodium+LDL** (§7 — the ONLY client-facing change):
   GeckoLib mobs + spell VFX + held-torch light. If broken: pull sodium stub, repush.
