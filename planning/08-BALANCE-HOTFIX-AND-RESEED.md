# 08 — APPLIED RECORD: overworld-difficulty hotfix + world-factory day (2026-08-31)

**Status: IN PROGRESS (2026-08-31).** Triggered by launch night: ~96 player deaths in
5.5 h (00:02–05:29), DJ rage-quit, David/Zander asking to drop Confluence and restart.
Group verdict relayed by Wesley: *overworld must be relatively safe; crazy difficulty
must be rare or opt-in.* This doc records what was diagnosed, what was changed, and the
new-world pipeline run while Wesley was at work. Doc 07 stays the worldgen/splice
authority; this doc owns the balance hotfix + the 08-31 reseed campaign.

---

## 1. Death forensics (log-verified, not bot-guessed)

`logs/latest.log` 00:02–05:29, 96 player deaths. The Discord bot's earlier breakdown had
the right counts but **fabricated the mod attribution** (it guessed from mob names).
Jar-lang-scan ground truth:

| Source | Deaths | Notes |
|---|---|---|
| **Confluence** (`terra_entity` module) | **63 (66%)** | Snatcher 19, Crimera 11, Face Monster 6, Blood Crawler 5, Demon Eye/EoC 5, jungle set (Hornet/Jungle Bat/Goblin Scout/slimes/Flying Fish) 15, misc 2 |
| Awakened (Cordon Overseer/Sentinel/Stalker) | 7 | Cataclysm addon; no spawn config exists; left alone, monitor |
| Vanilla | 17 | Zombie 9, Skeleton 5, misc 3 — normal pressure |
| Environment | 9 | lava 4, fire 2, fall 2, explosion 1 |

The "Primal" mod the bot blamed is **innocent** — every "Primal jungle mob" lives in
Confluence's bundled `org.confluence.terra_entity-1.2.1.jar`. L_Ender's Cataclysm proper
killed nobody.

**Biome factor (analyzer-verified):** Confluence injects 12 worldgen biomes via
TerraBlender — Crimson ×3, Corruption ×3, Hallow ×3, ash ×2, glowing_mushroom. In the
R=2000 live world: Crimson = 1509 chunks on the Terralith side hugging the seam
(X −496..0, Z −1776..1328), **nearest Crimson chunk 4 blocks from the shipped spawn
(0,−624 vs spawn 0,80,−620)** — spawn was set on the Crimson's doorstep. Corruption =
1426 chunks SW (nearest ~1.5 k). BoP side had zero Confluence biomes in R2000.
42 of the 96 deaths (44%) were Crimson-locked mobs; ~10 more jungle-locked.

## 2. Config hotfix (applied 2026-08-31 ~09:45, server stopped first)

`config\terra_entity-server.toml`:
- `spawn_without_light` **true → false** — Confluence mobs now respect light level
  (this was why torch-lit areas felt unsafe: they ignored light entirely).
- `monster_attributes_multiplier_damage` **1.0 → 0.5** — the "24 damage through full
  iron" trash-mob problem, halved at the source.
- `enemy_spawn_chance` **1.0 → 0.7** — volume trim for the dogpiling.
- `boss_no_physics` **true → false** — bosses collide with terrain instead of phasing
  through stone into houses/mines.
- `boss_leave_on_day` **false → true** — dawn ends boss encounters (Terraria-authentic).

`config\confluence-common.toml`:
- `eyeOfCthulhuNatureSpawning` **true → false**, `deerclopsNatureSpawning` **true →
  false** — bosses are now **summon-only** = difficulty is opt-in, exactly the group ask.
  (Blood Moon / Goblin Army / Slime Rain events remain, gated on player max-HP/armor
  thresholds — they arrive with progression; knobs exist in the same file if needed.)

Also available if the global 0.5 isn't enough: `config\terra_entity\attribute_config.json`
does per-entity attribute overrides at max priority (e.g. Snatcher-specific nerf).

**NOT yet re-tested under players.** First real session on these values decides whether
0.5/0.7 is right.

## 3. World-factory day (Wesley at work; all runs non-elevated, UAC unavailable)

Constraint: SYSTEM tasks untouchable → live server + all pregen ran as Wesley-user
processes (java needs no elevation; RCON stop/start; port checks via netstat).

- **02:00 scheduled ring bake FAILED in 90 s** — `Invoke-Rcon` returned a 1-element
  array which PowerShell unrolled to a bare string; `Assert-Seed`'s `[0]` then read the
  first *character* ('S' of "Seed: [...]"). Fixed with `return ,$out` in
  `PregenRig\ring-bake.ps1`. (The pre-flight smoke test passed because multi-command
  calls return real arrays — single-command calls were never exercised.)
- **Ring bake re-run 09:51** on PregenRig (16G heap): extends BOTH carriers to R=6000
  (three L-bands per half, flush loop every 2 min per doc 07's OOM law). Target: seam
  line grows 4,000 → 12,000 blocks (Z ±6000), depth ±6000.
- **Fresh fallback pairs on PregenRig2** (new clone, ports 25567/25577,
  `fresh-pairs.ps1`): two full R=2000 pairs, same recipe as the live world.
  **No reseed flow needed** — the Confluence seed bug hands every fresh world a random
  seed, which for *candidate* worlds is fine; `/seed` is recorded instead of forced:
  | world | seed |
  |---|---|
  | fresh1-bop | -3735755492918603877 |
  | fresh1-terralith | 6785415588856243605 |
  | fresh2-bop | 8193699134830949519 |
  | fresh2-terralith | 8995405613269779217 |
- ⚠ **Locate-assert lesson (cost one aborted run 10:40):** to verify a jar swap took,
  test **registry presence** — "Can't find element" = registry absent (jar off);
  "Could not find … within reasonable distance" = registry PRESENT (jar on), locate just
  missed on that seed. Never require a nearby locate *hit* of one specific biome.
- **Analyzer built** (`mca_biomes.py`, scratchpad): pure-Python region→per-chunk biome
  palettes + MOTION_BLOCKING height stats, selective NBT parse, ~30 s per R2000 world.
  ⚠ Python gotcha that cost an hour: `r.o += 8 * r.i4()` loads `r.o` BEFORE evaluating
  the RHS — the reader's own 4-byte advance inside `i4()` is lost. Augmented assignment
  with side-effectful RHS = never again. Also: MCA Selector 2.8 CLI can't query modded
  biomes (single-quote syntax unsupported in CLI; double quotes validate against the
  vanilla registry) — hence the custom analyzer.
  Discovered in passing: sections carry a Confluence `backup_biome` tag = **evil biomes
  convert/spread and remember the original biome**. Spread mechanics unexamined.
- **Seam scorer** (`seam_report.py`): per-seam-Z quality 0–100 from evil-biome distance
  (45 pts), ocean fraction (20), core flatness (25), jungle pressure (10) + 1px/chunk
  PNG maps. Scores: current R2000 seam tops out at **46.7** (Crimson-poisoned);
  fresh1 best **70.2** (Z=−368); fresh2 best **79.4** (Z=1808).
- **Also done:** 14.8 GB hprof on H: deleted (doc 07 tail item); old world left LIVE
  for daytime goofing (Wesley's call; world is condemned, wiped at reseed tonight).

## 3b. Afternoon completion (13:35–14:00)

- **Ring bake COMPLETE 13:35** (started 09:51; ~3.5 h with the live server up):
  both carriers 364 regions, X/Z ±6000, ~3.8 GB each. All six bands + seed asserts clean.
- Extended-seam analysis (564k chunks): 27,477 evil chunks (4.9%). **Top stretches:
  Z=−3568 → 87.6** (evil 1,539 blocks, 3% ocean, flat 11.3, no jungle), **Z=−2944 → 86.6**
  (zero ocean; supports border up to ±3000 — bigger than the old ±1900), Z=−3968 → 82.0,
  Z=−4624 → 82.0, Z=+4864 → 76.0. Fresh2 best 79.4 (Z=1808, 43% ocean, needs edge top-up
  bake); fresh1 best 70.2; old-world seam best 46.7 — the scores quantify launch night.
- **Decision artifact (maps + shortlist):**
  <https://claude.ai/code/artifact/3b73b6b7-4b32-4060-8e08-945015000881>
- **Splice runbook pre-written:** `C:\Game Servers\Minecraft-Step6\splice-world.ps1`
  (param: -BopWorld/-TerralithWorld/-OutWorld; doc-07 flow; verifies east/west counts).
  On pick: run splice (~25 min), stop live server, archive old `world\`, move new world in,
  boot, `worldborder center 0 <Zc>` + size, `setworldspawn`, flip Backup/Presence green.

## 5. SWAP EXECUTED (2026-08-31 ~15:00, Wesley's go; ~4 min downtime)

Wesley picked: extended current seeds, **full border** (his call — center 0,0 size
**11,800**, the doc-07 endgame border, NOT spawn-centered), provisional spawn at
candidate A. Sequence run: announce → graceful stop → `world` → `world-old-2026-08-31`
(kept on disk) → playerdata/advancements/stats copied into the splice (7 players) →
**all 7 player .dats offline-patched** to `8.5, 93, -3560.5` + Dimension forced
overworld (byte-splice of root Pos, verified by re-parse + full structure walk;
tool = scratchpad `patch_players.py`) → gamerule diff old-vs-new: **none** → swap →
boot 30 s → `worldborder center 0 0` + `set 11800` + `setworldspawn 8 92 -3560`.
Spawn chunk (0,-223) = plains, ha 91, relief 3, river across the seam. Boot log:
only known data-noise (loot/rechiseled), zero chunk/biome-registry errors.
Old-world chest contents did NOT carry (pristine splice) — players were warned to
pocket valuables. Bed spawns dangle (world spawn until re-bed).
**Config-nerf validation:** day-1 session on nerfed configs = 6 deaths / ~5.5 h
(vs 96 launch night). Teyters25 creative-scout watcher armed for the A/B/C/D flyover;
final `setworldspawn` + survival revert after his pick.
**FINAL SPAWN (Teyters-scouted, Wesley-locked ~15:30): candidate B — `0, 63, -2944`.**
Spawn chunk = biomesoplenty:orchard, ha 62, relief 0, ars_nouveau archwood forest across
the seam. All 6 offline .dats re-patched A→B (Teyters skipped — online, TP'd live);
Teyters reverted to survival at B. Reseed campaign CLOSED except cleanup queue below.
**Cleanup queue:** delete `world-old-2026-08-31` once the group blesses the new world;
root `world-bop`/`world-terralith` R2000 carriers are superseded by the R6000 rig
copies (PregenRig) — reconcile so exactly one blessed carrier set exists; PregenRig2
fresh pairs can be deleted or kept as spare seeds; Nether/TF/dimension pregen
(doc 07 tail) still pending — schedule as a maintenance window.

## 4. Decision queue for Wesley (tonight)

1. Pick the world: extended current seeds (12 km seam, pick a clean stretch) vs fresh1
   vs fresh2 — map artifact + shortlist built after the ring bake lands.
2. Confirm splice + wipe of `world\` (group already blessed restart).
3. First-session watch: are 0.5×/0.7 Confluence numbers right; Cordon mobs; whether
   evil-biome *spread* needs attention.
4. Deferred: Sodium/LambDynamicLights as side=client stubs + Tschipcraft server-side
   dynamic lights / ScalableLux as phase-2 after config verdict (see conversation
   2026-08-31; freeze-reopening decision is Wesley-only).
