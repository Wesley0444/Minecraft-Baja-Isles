# 07 — STEP 6 APPLIED RECORD: pregen + world splice

**Status: IN PROGRESS (2026-08-30).** Work order = `05-WORLD-SPLICE.md`; Chunky mechanics =
`02-SERVER-BUILD-PLAN.md §6`. This doc is the applied record — what actually ran, with the
exact seeds and per-run configs needed to extend the world later. **If this file and doc 05
ever disagree about what was done, this file wins.**

---

## 🔴 THE SEEDS — never lose these

Recorded BEFORE either world was generated. Both halves keep their seed forever; ring
extension (doc 05 §5.1) is impossible without them.

| Half | Seed | Side |
|---|---|---|
| **A — BoP** | `2158333272300648890` | X ≥ 0 |
| **B — Terralith** | `-2531613582497795438` | X ≤ 0 |

---

## RUN CONFIGS (the exact worldgen inputs per half)

Baseline for BOTH runs: the frozen modlist (125 pack stubs synced into `mods\`), the
step-5 config set (doc 06 §3), `config\sparsestructures.json5`, and the 5 Paxi datapacks
(`config\paxi\datapacks`, load order per `datapacks\deploy-datapacks.ps1`) — Paxi injects
them into every world, so both pregen worlds carry them automatically.

**Doc 05 correction:** Terralith in this pack is a **jar mod** (`Terralith_1.21.x_v2.5.8.jar`),
not a loose datapack. So "remove the Terralith datapack" (doc 05 step 1) = remove the jar
for Run A. Safe: Terralith adds zero blocks/items (vanilla-block worldgen only), so Run A's
chunk NBT has no reference to it. And "set BoP's TerraBlender weight to 0" (doc 05 step 2)
lives in **BoP's own config**, not terrablender.toml: `config\biomesoplenty\generation.toml`
`[overworld]` weights.

| Input | Run A (BoP half) | Run B (Terralith half) |
|---|---|---|
| `level-seed` | `2158333272300648890` | `-2531613582497795438` |
| `level-name` | `world-bop` | `world-terralith` |
| `Terralith_1.21.x_v2.5.8.jar` | **REMOVED** (parked in `step6-workspace\`) | present |
| BoP `bop_primary_overworld_region_weight` | 10 (stock) | **0** |
| BoP `bop_secondary_overworld_region_weight` | 8 (stock) | **0** |
| BoP `bop_overworld_rare_region_weight` | 2 (stock) | **0** |
| Chunky | `corners 0 -2000 2000 2000` | `corners -2000 -2000 0 2000` |
| `max-tick-time` | -1 (pregen only) | -1 (pregen only) |

**Radius re-plan (2026-08-30, Wesley's call — server up TONIGHT):** phase harder than doc
05 §5.1 — **R=2000 today** (border 3800), overnight ring 2000→6000. Same table, only the
corners change for the ring.

Weight-0 acceptance (doc 05's ⚠) is verified empirically at Run B boot: `locate biome`
for a BoP biome must fail, a Terralith biome must hit. Run A sanity check mirrors it.

**Phase today = R 3000** (border 5800). Tonight's extension = same two configs on the
L-shaped rings (doc 05 §5.1) — reuse this table verbatim, only the corners change.

---

## 🔴 FOUND LIVE: `level-seed` IS DEAD IN THIS PACK (Confluence bug) + THE RESEED FLOW

First Run A boot ignored `level-seed` and created a random world. Root cause (FML debug
log): **Confluence's `org.confluence.mod.mixin.level.WorldOptionsMixin`** injects into
`WorldOptions.withSeed(...)` (`withSecretFlag1/2/3` — its Terraria "secret seed" feature)
and breaks seed application during dedicated-server world creation. The properties file
is read fine (the server even re-saves it with the right value mid-boot) — the parsed
seed is then discarded on the `withSeed` copy. Every fresh world gets a random seed.
Modlist is frozen, so no mod update — instead every world creation in this project uses:

**THE RESEED FLOW (mandatory for run A, run B, and every future ring-extension world):**
1. Boot once; the world is created with a junk random seed. Note it from `/seed`.
2. Graceful stop (RCON `stop`), wait for java to exit.
3. `reseed.ps1`: gunzip `level.dat`, replace the 8-byte big-endian junk-seed value with
   the target seed (expect exactly 1 hit = `WorldGenSettings.seed`), re-gzip.
4. Delete EVERYTHING else in the world folder (region/entities/poi/DIM*/dimensions/data/
   level.dat_old) — spawn chunks were generated with the junk seed and must go.
5. Boot again; verify `/seed` returns the target. Chunk gen seeds itself from level.dat
   at runtime, so all generation from here is on the target seed. (Alex's Caves' seed
   capture also picks up the level.dat value on load — verified in the log.)

Verified live 2026-08-30: junk seed `144735778378989771` → reseeded to seed A,
`/seed` + AC's biome-source log line both confirm `2158333272300648890`.

---

## LOG (filled in as it happens)

- 2026-08-30 — seeds generated + recorded before any generation. Throwaway world
  deleted; step-6 execution started.
- Run A world created → hit the Confluence seed bug (section above) → reseeded to seed A
  + chunk wipe → boot verified: `/seed` = 2158333272300648890, Terralith jar absent
  (`locate biome terralith:*` = unknown element), all 5 Paxi packs enabled.
- Run A attempt #1 (~21:01, `corners 0 -3000 3000 3000`, 71k chunks): Chunky reported
  100% in 50:42 — **but `world-bop\region\` was EMPTY and the server OOM'd** (14.8 GB
  hprof on H:). 🔴 **ROOT CAUSE: Chunky-generated chunks on this modset are NOT flushed
  to disk during generation** — they accumulate in heap until an explicit save. Proven
  empirically: tiny 231-chunk Chunky run wrote NOTHING until `save-all flush`, then
  region files grew 0.7→6.4 MB instantly. Normal (non-Chunky) play saves fine.
  The 30-min backup task was investigated and EXONERATED — it refuses to run before
  `save-off` when `world\level.dat` is missing (log: straight `[FAIL]` entries all night).
  **MANDATORY FIX for every pregen run (incl. ring extensions): run a `save-all flush`
  loop every ~2 min for the duration, and watch region\ MB grow as the health signal.**
  Heap temporarily bumped 10G→16G in launch.bat for backlog headroom — RESTORE TO 10G
  BEFORE SHIP.
- Run A attempt #2 ✅ (22:05–22:27): `corners 0 -2000 2000 2000`, 31,877 chunks in 22:12
  with the flush loop — `world-bop\region` = 62 files / 494 MB, X regions r.0..r.4,
  Z r.-5..r.4 (the r.-1.* files are spawn-square bleed west of the seam; the splice's
  `xPos >= 0` source filter excludes those chunks). Seed re-verified 2158333272300648890
  before start.
- Run B swap: Terralith jar restored, BoP overworld weights → 0/0/0, junk-boot created
  world-terralith with seed 5851080921928443506 → reseed flow → `/seed` verified
  **-2531613582497795438** (seed B).
- ✅ **Doc 05's "verify 0 is accepted" — CONFIRMED ACCEPTED.** With weights 0/0/0:
  `locate biome terralith:alpine_grove` hits (4.5k blocks), `locate biome
  biomesoplenty:seasonal_forest` exhausts with "Could not find" → pure-Terralith half.
- Run B Chunky started ~22:47: `corners -2000 -2000 0 2000`, flush loop armed.

## SPLICE ✅ (2026-08-30 ~23:02, MCA Selector 2.8 headless, MS JDK 21)

Target = **a COPY of world-terralith renamed `world\`** — both source half-worlds stay
pristine in the server root as the seed carriers for ring extension. Tool:
`Minecraft-Step6\mcaselector-2.8.jar` (plain jar, headless mode needs no JavaFX).
Script: scratchpad `splice.ps1`; flow:

1. robocopy world-terralith → world (`/E`)
2. `--mode select --world world-bop --query "xPos >= 0"` → 4665 chunks (also excludes
   world-bop's own west-of-seam spawn bleed)
3. `--mode delete --world world --query "xPos >= 0"` (kills terralith's east bleed)
4. `--mode import --world world --source-world world-bop --source-selection ... --overwrite`
   (region + poi + entities all carried — verified files present)
5. verify: east 4663 / west 4665 chunks. The 2 missing east chunks = the two oversized
   `.mcc` chunks (blocks ~2080,-1040 and 400,2144) — both OUTSIDE the ±1900 border in
   edge-bleed territory; MCA's CLI import skipped them. Accepted: unreachable, regen
   harmlessly if ever loaded.

Result: `world\` = 100 region files, 915 MB.

## SHIP STATE ✅

- Restored: BoP weights 10/2/8, `level-name=world`, `max-tick-time=60000`, launch.bat
  heap back to **10G**. Terralith jar stays in mods\ **forever** (doc 05 §4).
- Ship boot clean: zero chunk-load / biome-registry errors (only the 5 known
  pre-existing IDAS/tag noise lines).
- `worldborder center 0 0` + `set 3800` (±1900, inside the R=2000 pregen edge).
- Spawn: initially 0,80,0; after Wesley's seam scouting flyover, **final spawn =
  `0, 80, -620`** (still on the seam — his pick, 2026-08-30).
- Live `/seed` reports seed B (shipped level.dat is the terralith copy's) — expected.
  ⚠ **`locate` on the live server is meaningless for the baked world**: it queries the
  live MERGED biome source (BoP+Terralith, seed B), not chunk NBT. Splice correctness
  rests on construction-time proof: east half generated with Terralith's registry absent,
  west half with BoP locate-exhausted at weight 0.

## VERIFICATION

- Server-side: boot clean (above). ✅ **Wesley's seam flyover PASSED 2026-08-30** ("seam
  worked") — no chunk tears reported; he scouted the seam line in creative and picked
  the spawn stretch at Z=-620. (Seed itself rated "not amazing" — re-roll declined; a
  full re-roll now costs ~1h15m with the debugged machinery if the group ever wants one
  BEFORE real play starts. After real play it's off the table.)
- PENDING: backup task flips [FAIL]→[OK] at the next :00/:30 mark now that
  world\level.dat exists; presence poller goes UP.

## RING BAKE — SCHEDULED (2026-08-31 02:00, unattended)

Soft launch happened at R=2000 the evening of 08-30; the ring bakes overnight WHILE the
live server keeps serving, on a full clone at `C:\Game Servers\Minecraft-PregenRig\`
(ports 25566/25576, 16G heap, its own mods/config, copies of both source worlds — the
originals in the server root stay pristine). Smoke-tested alongside the live server:
boots, RCON answers, seed A verified, clean stop. ⚠ PS gotcha found: java's
`@argfile` with a spaced path needs the quotes embedded in the token (`'@"' + $path + '"'`)
when launched via `Start-Process -ArgumentList`.

- **Task:** `Minecraft Ring Bake` — one-shot SYSTEM task, 02:00, elevated-verified
  (state Ready). Runs `PregenRig\ring-bake.ps1`: Run A (Terralith jar → hold\, weights
  stock, world-bop, 3 L-bands: `2000 -6000 6000 6000` / `0 -6000 2000 -2000` /
  `0 2000 2000 6000`) → swap → Run B (jar back, weights 0/0/0, world-terralith,
  mirrored bands) → stop. Flush loop every 2 min, seed asserts before each run, stall
  watchdog (16 min no progress = abort), 9.5h global deadline, all java control by PID
  (never touches the live server). Log: `PregenRig\ring-bake.log`; success marker:
  `PregenRig\RING-BAKE-DONE.txt`. ~500k chunks total ≈ 5–7h → done ~07:00–09:00.
- **INSERT (manual, next day, ~30 min downtime):** stop live server → MCA import both
  rings from the PregenRig worlds into `world\` → `worldborder set 11800` → restart.
  🔴 Import selection must take ONLY chunks beyond the old pregen edge (chunk coord
  magnitude > 125, i.e. blocks ±2000) so nothing player-touched is overwritten — the
  ±1900 border means players cannot have modified anything out there. Import took 12s
  for 4.6k chunks → expect ~20–25 min for 500k.
- Nether/End/TF/modded-dimension pregen (doc 02 §6 targets) — do on `world\` during the
  same maintenance window(s).
- Delete `H:\...\heapdumps\java_pid32416.hprof` (14.8 GB) once nothing more to learn.
