# Minecraft 1.21.1 NeoForge — SERVER BUILD PLAN

**Target:** `C:\Game Servers\Minecraft` · Minecraft **1.21.1** · NeoForge **21.1.249** · Java **21** · ~150 mods · 6 players · 8+ dimensions
**Box:** WESLEY-PC — i7-14700KF (20C/28T), Windows 11, **64 GB after the pending RAM swap**, dual-purpose (this machine is also the owner's gaming rig and he plays on it while hosting).
**Written:** 2026-08-29. Version numbers marked ✅ were verified live today; everything marked ⚠ came from the recon brief and must be re-checked at build time.

---

## ⛔ GATE 0 — THE RAM SWAP AND XMP STABILITY PROOF HAPPEN FIRST

**Nothing in Sections 3 onward begins until this gate is signed off.** Not "mostly done." Signed off, with a date and test results written into the server registry.

### Why this is a gate and not a chore

A marginal DIMM and a mod conflict produce **the same symptoms**: random crashes with no pattern, `EXCEPTION_ACCESS_VIOLATION`, JVM `SIGSEGV` / hs_err crash dumps, garbage stack traces that point at whatever class happened to be resident, corrupted chunk data, and worlds that fail to reload. There is no way to tell them apart from a log.

Bisecting a 150-mod list assumes that **removing the bad jar makes the crash stop**. If the real cause is memory, removing a random jar changes the allocation pattern and the crash *appears* to stop — for a while. You will "fix" it five times, ship it, and it will crash again in month two with six people online. The modlist becomes un-bisectable because your test signal is lying to you.

So: one variable at a time. Memory first, proven, then mods.

### Current state and what changes

| | Now | After |
|---|---|---|
| Capacity | 32 GB (2×16) | **64 GB (2×32 G.Skill DDR5)** |
| Speed | **4800 MT/s JEDEC — XMP is OFF** | 6000 MT/s CL30 (EXPO/XMP) — **untested on this board** |
| Sticks | 2 | 2 (good — keep it at two, do not mix in the old 16 GB pair) |

**The box has never run XMP.** It has been on JEDEC 4800 its whole life. Two 32 GB dual-rank DDR5 modules at 6000 are a *materially* heavier load on the 14700KF's memory controller than two 16 GB single-rank modules at 4800. Do not assume it will POST at EXPO, and do not assume that POSTing means stable.

### The procedure

1. **Physical swap.** Both new sticks in the board's primary channel slots (A2/B2 on almost every consumer board — check the manual, not the slot nearest the CPU). Old pair goes in a bag, labelled, not in the machine.
2. **Boot at stock/JEDEC first.** EXPO/XMP **off**. Confirm the box POSTs, sees 64 GB, boots Windows, and idles. This proves the DIMMs and the seating before XMP is introduced as a second variable.
3. **Memtest86 at JEDEC** — bootable USB, the full default pass set (4 passes). ~2–4 hours for 64 GB. **Zero errors required.** A single error here is a dead kit or a dead slot; RMA, do not proceed.
4. **Enable EXPO/XMP → 6000 CL30.** Reboot. If it does not POST, clear CMOS and go to step 8.
5. **Memtest86 again at 6000**, full pass set. Zero errors.
6. **TestMem5 with the `anta777 Extreme` config, 3 cycles**, inside Windows. This is the DDR5 community standard and it finds errors Memtest86 does not. Zero errors.
7. **OCCT — Memory test 1 hour, then CPU+RAM combined 1 hour.** The combined run matters here specifically: this box lives in an enclosed cubby that recirculates heat, and memory instability frequently only appears once the DIMMs and IMC are hot. Watch DIMM temps in LibreHardwareMonitor (`:8085`) — target under ~50 °C, and note the number for later.
8. **If anything errors:** back off, in this order — (a) 5600 CL30, (b) 6000 with a small VDD/VDDQ bump and a looser tRFC, (c) **just run JEDEC 4800 and move on.** A stable 4800 server beats an unstable 6000 one every single time. Minecraft's tick loop is not memory-bandwidth-bound; 6000 vs 4800 is worth low single-digit percent to the game loop. XMP's real value on this box is for the *gaming* half, not the server half. Do not trade server stability for it.
9. **Write it down.** Date, final memory settings, which tests passed, peak DIMM temp — into the server registry entry in `CLAUDE.md`. In month three when something crashes, you need to be able to say "memory was proven stable on 2026-XX-XX" instead of re-litigating it.

**Sign-off line to add to the registry:** `RAM: 2×32 DDR5-6000 CL30 (EXPO), proven stable <date> — Memtest86 4 pass ×2, TM5 anta777 Extreme ×3, OCCT MEM 1h + CPU+MEM 1h, all clean. Peak DIMM <NN>°C.`

---

## 1. RAM MATH — sizing for a 64 GB box

### 1a. Server heap — the arithmetic

Work out the **live set** (what the server actually needs resident at peak), then add GC headroom.

| Component | Estimate | Reasoning |
|---|---|---|
| Static registries, tags, recipes, loot tables, datapack + mod data for ~150 mods | **2.5 – 3.5 GB** | This is the floor that never gets collected. Content-heavy mods here are unusually registry-fat: Epic Knights alone is 1,500+ item entries, Knaves' Needs 520+, Block Pack ~1,200 blocks, Cobblemon ~1,000 species datasets. |
| Live chunk cache | **0.5 – 1.0 GB** | At `view-distance=8`, each player holds ~361 chunk columns. 6 players fully spread with no overlap = ~2,200 columns. A modded chunk column with a fat block-state palette is ~150–250 KB resident. Plus spawn chunks and any force-loads. |
| Per-dimension `ServerLevel` overhead | **0.8 – 2.0 GB** | Every *loaded* dimension carries its own chunk map, entity tracker, POI store, structure cache and block-entity tick list — roughly 100–250 MB each. With 8+ dimensions and 6 people who will absolutely be in 4–5 different ones at once, budget for 6–8 live at peak. |
| Entities | **0.5 – 1.0 GB** | Heavy: persistent Cobblemon spawns, Minecolonies citizens, Naturalist/Primal fauna, GeckoLib mobs, Iron's Spells summons. |
| **Live set at peak** | **≈ 6.5 GB** | |
| G1 headroom (~50%) | **+3.5 GB** | G1 needs meaningful free heap or it starts doing full GCs and humongous-allocation dances, which show up as multi-second tick stalls. |
| **→ `-Xmx` / `-Xms`** | **10 GB** | 12 GB is the ceiling if spark shows real pressure. |

**Do not go bigger than 12 GB "because we have 64."** Minecraft's tick loop is latency-sensitive, not throughput-sensitive: a larger G1 heap means longer pause times per collection. 10 GB with Aikar's flags is the sweet spot for a pack this size; more heap actively makes stutter worse past a point.

**Process RSS ≠ Xmx.** The JVM's off-heap cost on top of a 10 GB heap:

| Off-heap | Estimate |
|---|---|
| Metaspace (150 mods + libs = a *lot* of loaded classes) | ~0.8 – 1.0 GB |
| JIT code cache | ~0.3 GB |
| G1 internal structures (card table, remembered sets ≈ 8–10% of heap) | ~1.0 GB |
| Thread stacks (~200 threads × 1 MB) | ~0.2 GB |
| Netty direct byte buffers | ~0.2 GB |
| **Total off-heap** | **≈ 2.5 – 3.0 GB** |
| **Server process RSS** | **≈ 13 GB. Budget 14 GB.** |

(Memory-mapped region files come out of the OS page cache, not the process — that's free real estate on a 64 GB box and it's *why* the extra RAM makes chunk I/O feel faster even though it doesn't touch the heap.)

### 1b. The whole-box budget

| Consumer | Budget |
|---|---|
| **Minecraft server** (10 GB heap + JVM overhead) | **14.0 GB** |
| Windows 11 + services + Defender | 5.0 GB |
| **Minecraft client** — same 150-mod pack, 6 GB heap, textures/models/GPU staging | **10.0 GB** |
| Discord (hardware accel, in a call) | 1.5 GB |
| Browser (~20 tabs) | 4.0 GB |
| Claude Code / terminals / editors | 2.0 GB |
| Steam client + overlay | 0.5 GB |
| **Total committed** | **37.0 GB** |
| **Free on 64 GB** | **27 GB** — page cache for region files, plus real headroom |
| **Free on 32 GB** | **−5 GB. It does not fit.** |

**That last row is the entire justification for the upgrade.** This pack, hosted on this box while its owner plays on it, does not fit in 32 GB — before OBS, before a second browser window, before anything goes wrong. It is not a nice-to-have.

With 64 GB you also get the option to run the server at 12 GB heap (→ 39 GB committed, 25 GB free) if profiling justifies it, and enough slack that a memory leak in one mod shows up as a slow climb you can catch rather than an OOM at 11 PM.

### 1c. The CPU ceiling — 64 GB does NOT fix TPS

**Say this out loud to the group before launch, because it is the thing everyone gets wrong.**

Minecraft's main game loop is **single-threaded**. Chunk *generation*, lighting, and chunk I/O run on worker pools; everything else does not. On the main thread, every tick, in series:

- every ticking entity's AI, pathfinding, and movement
- every ticking block entity
- mob spawning passes for every loaded dimension
- redstone, fluid ticks, random ticks
- **every mod's tick handler, for all 150 mods**

That has a **50 ms budget per tick** at 20 TPS. It runs on **one core**. The 14700KF's P-cores are about as fast as consumer single-thread gets — which means this box is close to the best case available, and the ceiling is still one core. Adding 32 GB of DDR5 raises the memory ceiling and does **nothing whatsoever** to the tick ceiling.

**Where the tick budget actually goes on this modlist:**

| Mod | What it costs | Severity |
|---|---|---|
| **Minecolonies** | Persistent, never-despawning citizens with `BASE_PATHFINDING_RANGE = 100`; `maxcitizenpercolony` defaults to **250** (hard cap 500); `forceloadcolony` defaults **true** with a documented ticket leak (ldtteam #6850). Documented in the wild: 20 TPS → 4–7 TPS when a player enters a colony (ldtteam #6366, ATM-6 #615). | **Worst on the list.** |
| **Cobblemon** | Persistent, chunk-saved entities on Brain AI with its *own* spawner independent of vanilla weights. Defaults: `pokemonPerChunk=1.0`, `pokeSnackPokemonPerChunk=2.0`, `maximumSpawnsPerPass=8`, `ticksBetweenSpawnAttempts=20`. Dan already flagged it as "intrusive, has a ton of mobs." | **Severe.** |
| **Jurassic Reborn** | 108 GeckoLib creatures with 17×5×3 to 23×7×4 hitboxes — very expensive pathfinders. Also **fights the perf stack**: open issues #82 (VintageFix dynamic resources → crash/high RAM) and #89 (ModernFix dynamic resources → `ModelMissingException`). | **Severe + conflicts with §5.** |
| **Naturalist / Primal / Creature Feature** | Three mods filling the same ambient-fauna niche, each with spawn weights tuned as if it were alone. Naturalist adds 40+ types incl. large-hitbox Mammoth/Whale/Great White; Primal runs 9 mobs on **Brain AI** (villager-class cost per entity); Creature Feature adds 23 spawn entries plus **multipart entities**. | **Compounding.** |
| **Guard Villagers** | `GuardVillagerHelpRange` default **50.0** is an every-tick radius scan per guard; 6 guards/village × every village anyone has found. | Moderate, cheap to fix. |
| **Iron's Spells** | Documented Priest-entity TPS collapse (#795, #833) — reporters resolved it by killing every priest. | Moderate, one-config fix. |

**Protecting the tick budget — the numbers:**

| Setting | Value | Why |
|---|---|---|
| `simulation-distance` | **6** (from default 10) | **The single highest-leverage number in this entire document.** Entity ticking, mob spawning and block-entity ticking scale with the *square* of this. 10 → 6 cuts the ticking area from 441 to 169 chunk columns per player — a **62% cut** — and players cannot perceive it. |
| `view-distance` | **8** | Render only. Clients can render further locally; this governs what the server sends. |
| `entity-broadcast-range-percentage` | **75** | Cuts entity-tracking packet volume, which is the dominant network cost with 300 dinosaurs and a Cobblemon field on screen. |
| `max-tick-time` | **60000** | High enough that a heavy chunkgen burst doesn't watchdog-kill the server, low enough that a genuinely hung server still restarts. Set to `-1` **only** during the Chunky pregen run, then put it back. |
| `sync-chunk-writes` | **false** | Default `true` on Windows costs real I/O stall. The box is on a UPS and backs up every 30 min — take the trade. |
| `network-compression-threshold` | **256** | |
| `spawn-protection` | **0** | Six friends, nobody to protect against. |
| `max-players` | **8** | 6 + slack. |
| gamerule `maxEntityCramming` | **12** (from 24) | |
| gamerule `randomTickSpeed` | **3** (leave alone) | Raising it is a common and terrible idea. |
| gamerule `doInsomnia` | `false` if phantoms annoy anyone | |

**Mob caps and spawn weights — the honest version.** ⚠ Vanilla NeoForge does **not** expose the per-`MobCategory` spawn caps (MONSTER 70, CREATURE 10, AMBIENT 15, WATER_CREATURE 5, etc.) in `server.properties`, and I could not verify a NeoForge config that does. The levers that definitely exist are:

1. **`simulation-distance`** — the real global cap, because caps scale with loaded-chunk count.
2. **ServerCore** — dynamic mob-cap and chunk-tick throttling that kicks in when MSPT rises. Ship it.
3. **In Control!** — a JSON rules engine for *which* mob spawns *where*, at what light level, at what difficulty. This is how you shape pressure by hand instead of with a global multiplier. Beyond Depth uses exactly this and it is the correct tool.
4. **Per-mod spawn weight configs** — every mob mod on this list exposes them. **Halve every added mob's weight as a blanket rule**, then tune up. Concretely: Fights and Frights ships Scowl at weight **60** (vanilla zombie is 95) — one mod claiming that much of the hostile pool is exactly the stacking failure.
5. **A datapack biome modifier** for anything that doesn't expose config.

**Per-mod settings to change on day one:**

| Mod | Key | From → To |
|---|---|---|
| Cobblemon | `pokemonPerChunk` | 1.0 → **0.4** |
| Cobblemon | `pokeSnackPokemonPerChunk` | 2.0 → **0.5** |
| Cobblemon | `maximumSpawnsPerPass` | 8 → **4** |
| Cobblemon | `ticksBetweenSpawnAttempts` | 20 → **40** |
| Minecolonies | `forceloadcolony` | true → **false** |
| Minecolonies | `maxcitizenpercolony` | 250 → **40** |
| Minecolonies | `pathNodeLimitMultiplier` | → **1** |
| Guard Villagers | `GuardVillagerHelpRange` | 50.0 → **24.0** |
| Guard Villagers | `guardSpawnInVillage` | 6 → **3** |
| Guard Villagers | `guardPatrolVillageAi` | leave **false** (author's own lag warning) |
| Iron's Spells | `priestHouseWeight` | 4 → **0** |
| Jurassic Reborn | natural spawning | leave **OFF**, and do **not** install the Natural Spawning Addon |
| Ghosts | — | ⚠ **audit or cut** — its ghosts call `setChunkForced` every tick and never release on removal. A months-long world accumulates orphaned permanently-ticking chunks with no upper bound. |
| Deeper and Darker | Sludges | Splitting mobs farmed deliberately for Resonarium — the classic entity blowup. Watch it. |

**Cuts I would make on tick grounds alone, before any balance argument:** Cobblemon, Minecolonies, Jurassic Reborn, two of the three ambient-fauna mods, and Ghosts. That is not a balance opinion — those five are where your 50 ms goes.

---

## 2. JVM FLAGS

**Java 21 (LTS).** Minecraft 1.21.1 requires it; NeoForge 21.1.x is built against it. Use **Eclipse Temurin 21** or **Microsoft OpenJDK 21**. Do **not** run Java 22/23/24 — the 1.21.1-era Mixin/ASM toolchain has known trouble with newer class-file versions, and there is zero upside. Pin the JDK for the life of the campaign the same way you pin mods.

### The pastable string (10 GB heap, G1)

This is Aikar's flag set (the standard <12 GB variant) plus four additions specific to this build. Everything on one line in `launch.bat`:

```
-Xms10G -Xmx10G
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40
-XX:G1HeapRegionSize=8M
-XX:G1ReservePercent=20
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:SurvivorRatio=32
-XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1
-XX:-OmitStackTraceInFastThrow
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=H:\Game Server Backups\Minecraft\heapdumps
-Dfile.encoding=UTF-8
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
```

**The four non-Aikar additions, and why:**

- **`-XX:-OmitStackTraceInFastThrow`** — the most important line here for this project. By default, once the JIT has seen the same exception a few times it stops building stack traces and throws a pre-allocated one, so your log fills with `java.lang.NullPointerException` and *no trace at all*. That is precisely the "useless stack traces" failure mode you are trying to avoid while bisecting 150 mods. Turning it off costs nothing measurable and keeps every trace intact.
- **`-XX:+HeapDumpOnOutOfMemoryError` + `-XX:HeapDumpPath=...`** — if the heap ceiling is ever actually hit, you get a dump instead of a mystery. **Note it will be a ~10 GB file** — that is why the path is on `H:` (930 GB free), not `C:`.
- **`-Dfile.encoding=UTF-8`** — Windows defaults to a legacy codepage and mod logs with non-ASCII characters get mangled, which makes crash triage harder than it needs to be.
- **`-Xms` = `-Xmx` + `AlwaysPreTouch`** — commits and touches the whole 10 GB at startup. Costs a few extra seconds of boot and eliminates heap-growth pauses entirely. On a 64 GB box this is free.

**If you move to 12 GB**, switch to Aikar's >12 GB variant values: `G1NewSizePercent=40`, `G1MaxNewSizePercent=50`, `G1HeapRegionSize=16M`, `G1ReservePercent=15`, `InitiatingHeapOccupancyPercent=20`.

### The ZGC option (do not start here)

Generational ZGC (Java 21+) gives sub-millisecond pauses at the cost of ~10–15% throughput and more heap overhead. For a 6-player server where the complaint is *stutter*, that's arguably the better trade. But G1+Aikar's is the path the entire community has debugged, and you want the well-trodden road while you're also debugging a modlist.

**Rule: start on G1. Only try ZGC if spark's profiler shows GC pause time — not mod tick handlers — as the source of tick spikes.** If you do, it's a full swap, not a mix:

```
-Xms12G -Xmx12G -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch
-XX:-OmitStackTraceInFastThrow -Dfile.encoding=UTF-8
```

Bump to 12 GB because ZGC wants more headroom. Change one thing, measure, keep or revert.

---

## 3. INSTALL SEQUENCE

### 3.1 Java

Install **Eclipse Temurin 21 (LTS)**. Verify:

```bat
"C:\Program Files\Eclipse Adoptium\jdk-21\bin\java.exe" -version
```

Must report `21.x`. ⚠ Note the exact path — it goes into `launch.bat` **as an absolute path** (see §7 for why: the SYSTEM account's `PATH` is not your `PATH`).

### 3.2 NeoForge server

NeoForge **21.1.249** is the current 1.21.1 build ✅ (verified against `maven.neoforged.net` today; the 21.1 line runs from 21.1.2 to 21.1.249 and is still incrementing).

```bat
mkdir "C:\Game Servers\Minecraft"
cd /d "C:\Game Servers\Minecraft"

curl -L -o neoforge-21.1.249-installer.jar ^
  "https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.249/neoforge-21.1.249-installer.jar"

"C:\Program Files\Eclipse Adoptium\jdk-21\bin\java.exe" ^
  -jar neoforge-21.1.249-installer.jar --installServer "C:\Game Servers\Minecraft"
```

Expected output (⚠ **verify the exact paths after running** — the `win_args.txt` path string is what `launch.bat` depends on):

```
C:\Game Servers\Minecraft\
  run.bat  run.sh
  user_jvm_args.txt
  libraries\
    net\minecraft\server\...            (vanilla server jar, fetched by the installer)
    net\neoforged\neoforge\21.1.249\
      win_args.txt                      <-- the @argfile launch.bat references
      unix_args.txt
```

We do **not** use the stock `run.bat` — it reads `user_jvm_args.txt`, which is a second place for flags to hide. `launch.bat` (§7) puts the flags inline and calls the argfile directly, so there is exactly one source of truth.

### 3.3 EULA and the first two boots

**Boot 1** — run `launch.bat`. It will exit immediately having written `eula.txt`.

**Wesley accepts Mojang's EULA** by setting `eula=true` in `C:\Game Servers\Minecraft\eula.txt`. That is his agreement to make, not a step to automate.

**Boot 2** — the server starts, writes `server.properties`, and **generates a throwaway world**. Let it finish, stop it, and **delete `world\` entirely.** Do not build on this world. It was generated with zero mods.

### 3.4 server.properties

Edit before anything else (values from §1c):

```properties
level-name=world
level-seed=
gamemode=survival
difficulty=hard
hardcore=false
pvp=true
online-mode=true
max-players=8
motd=\u00A76The Well \u00A78| \u00A7f1.21.1 NeoForge
view-distance=8
simulation-distance=6
entity-broadcast-range-percentage=75
max-tick-time=60000
sync-chunk-writes=false
network-compression-threshold=256
spawn-protection=0
allow-flight=true
enable-command-block=true
enable-rcon=true
rcon.port=25575
rcon.password=<long random string>
broadcast-rcon-to-ops=false
enable-query=false
server-port=25565
```

`allow-flight=true` is mandatory — a dozen mods on this list grant flight and the vanilla anticheat will kick players otherwise.

> ⚠ **`difficulty=hard` + `pvp=true` + no `keepInventory` + no grave mod = three balance decisions
> made by inheriting defaults.** These are not server-ops settings; they are the largest untuned
> balance levers in the whole build, and they sit outside every table in
> `01-BALANCE-PLAYBOOK.md §1.6`. Full-loss-on-death **systematically taxes the gear tracks** (Epic
> Knights, Undergarden, Twilight Forest, Antarchy, D&D, Aether gear) while **completely exempting
> the knowledge tracks** (Ars glyphs, Iron's Spells research, Apotheosis world tiers, Minecolonies)
> — in the same direction as several nerfs in that document, which risks double-dipping. It also
> determines whether the group ever seriously attempts a 600 HP / 25-damage / knockback-immune
> Cataclysm boss, and the *entire parity anchor `R*` is derived from that fight*.
> **See `01-BALANCE-PLAYBOOK.md §1.10.2` and decide it before Tier 0. If a grave mod is chosen, it
> is a `mods/` addition and therefore a Stage-5 item — add it before the freeze, not after.**

⚠ **RCON has no bind-address property in vanilla.** It listens on `0.0.0.0:25575`. This is the *exact* Palworld REST-API-on-8212 situation repeating itself. **The firewall BLOCK rule in §7 is the only thing keeping RCON off the LAN.** Do not skip it, and do not believe "there's no allow rule so it's closed."

### 3.5 mods/ assembly and the config first-run cycle

`mods\` does not exist until you make it. Then, for **every** stage in §4:

1. Drop that stage's jars into `mods\`.
2. Boot. The server writes each mod's **default config** into `config\`. Many mods crash on this first boot if a dependency is missing — that's the point of staging.
3. **Stop the server.**
4. Edit `config\*.toml` / `*.json5`.
5. Boot again and verify the value took.

**⚠ THE CONFIG PRECEDENCE TRAP — this will bite you.** NeoForge has three config scopes:

| Scope | Location | Behaviour |
|---|---|---|
| `COMMON` / `CLIENT` | `config\` | Read at load. Edit here, restart, done. |
| **`SERVER`** | **`world\serverconfig\`** | **Copied from defaults at world creation, then the world's copy wins forever.** |

Once the real world exists, editing `config\foo-server.toml` **does nothing**. Iron's Spells' `priestHouseWeight`, Minecolonies' colony settings, Apotheosis' generation whitelist and most balance knobs are SERVER-scoped. You must edit `world\serverconfig\`. To genuinely reset a mod to defaults, delete its file from `world\serverconfig\` and reboot.

Corollary: **do as much config work as possible on throwaway worlds during Stages 1–4**, so that when the real world is created it inherits a `serverconfig` you already like.

### 3.6 Datapacks

Two places, and they behave differently:

- `world\datapacks\*.zip` — per-world. Dies with the world.
- `config\paxi\datapacks\*.zip` — **Paxi** auto-loads these into *every* world, with explicit ordering via `datapack_load_order.json`.

**Use Paxi.** Your structure-spacing datapack (§4 Stage 3), loot overrides, and balance datapacks all belong there so they survive every world reset during assembly and are one folder to version-control. Paxi is confirmed on 1.20–1.21.1+ Forge/NeoForge.

---

## 4. ASSEMBLY DISCIPLINE — staged, so a crash is bisectable

**The rule at every stage:** add the stage's jars → boot → **read the entire log, not just "did it start"** → `/spark profiler --timeout 120` → `/spark heapsummary` → record the numbers → only then move on. Most of what eventually kills a pack is currently a warning line nobody read.

**Keep `C:\Game Servers\Minecraft\MODLIST.md`.** For every jar: exact filename, version, source platform (CurseForge vs Modrinth — several of these mods exist on only one, and several have *different newest versions* on each), install date, and one line on why it's in. In month three "which mod did we add the day it started crashing" needs to be a lookup, not an archaeology project.

**Why staging makes it bisectable:** a crash bisects first to a stage (≤9 possibilities), then binary-search within that stage's jars by halving the folder. Worst case ~8 boots. Without stages you are bisecting 150 jars from scratch, every time.

### Stage 0 — Bare NeoForge
No mods. Confirm: boots to `Done (Xs)!`, you can join, RCON answers, `backup.ps1` runs clean, the boot task fires after a reboot. **Get the operational plumbing working before mods exist**, so that when mods break things you know the plumbing isn't the cause.

### Stage 1 — Libraries only
Architectury API · Cloth Config · **Curios API** · GeckoLib · Balm · Moonlight Lib · YUNG's API · Puzzles Lib · Collective · Kotlin for Forge · Bookshelf · Placebo · Resourceful Lib · Fzzy Config · Cristel Lib · Lionfish API · Blueprint · Citadel · Fragmentum · Sophisticated Core · ⚠ Structure Gel API (CurseForge-only, Modrinth slug 404s) · Cupboard.

Boots with nothing to do — that's fine. The point is to surface JiJ (jar-in-jar) version conflicts at 20 mods instead of 150.

**Known landmines to check here:**
- **Architectury vs OmegaConfig.** If you ever see `IllegalStateException: Mod 'architectury' is not available!` with Architectury clearly present, go hunt for a mod bundling OmegaConfig. Do not reinstall Architectury.
- **Architectury vs Apotheosis** — issue #592, open as of the report against Architectury 13.0.8. 13.0.11 may fix it. **Verify, don't assume** — test the pair the moment Apotheosis lands in Stage 6.
- **Ars Nouveau jar-in-jars Curios.** NeoForge resolves JiJ by highest version. Install standalone Curios at ≥ the version Ars bundles (the 9.3.1+1.21.1 line) or Ars's copy silently wins.
- **Pin one Architectury build for the whole campaign.** Cloth Config routes through it; a silent bump is how a months-old world stops booting.

**Decision to make here and never revisit: Curios is the accessory spine.** Cataclysm, Expanded Combat, Iron's Spells and Ars Nouveau all hard-require it. Accessories satisfies none of them. ⚠ The Aether *embeds* Accessories — if The Aether stays, you will have both loaded; use the **Accessories Compatibility Layer**, never the deprecated "Curios Compat Layer."

### Stage 2 — Performance + tooling
The §5 stack, plus JEI, Jade, **Paxi**, In Control!, and (if you're scripting balance) KubeJS + LootJS.

**Get spark in early.** A profile of a nearly-empty server is your baseline; without it, every later number is meaningless.

### Stage 3 — 🔒 WORLDGEN — THE LOCKED SET
> ### DO NOT CREATE THE REAL WORLD UNTIL THIS STAGE IS SIGNED OFF.
>
> **Adding** a worldgen mod after world creation: new biomes and structures appear only in *newly generated* chunks. You get a visible seam at the frontier, no Terralith anywhere near spawn, and structures that only exist 2,000 blocks out.
>
> **Removing** one is worse: saved chunks hold references to biome and structure registry entries that no longer exist. You get `Unknown biome` errors, chunks that fail to load, or NeoForge silently remapping everything to plains. There is no clean recovery on a months-old world.
>
> Every Stage-3 test happens on a **throwaway world**, generated fresh each time, deleted after. When the set is final, write `WORLDGEN FROZEN <date>` at the top of `MODLIST.md`, and only then generate the real one.

**The decision that has to be made here: Terralith OR Biomes O' Plenty. Not both.**

Biomes O' Plenty *requires* TerraBlender. Terralith's own README says: *"technically compatible with... Biomes O' Plenty; but it requires Terrablender, which screws with the biome distribution."* Once TerraBlender is present it seizes the overworld biome source and both mods get injected as weighted regions — Terralith's signature biomes become rare, terrain shaping goes inconsistent across region boundaries, and transitions get harsh. **Nothing errors.** You find out in week three, and by then it's unfixable.

**Recommendation: Terralith 2.5.8 alone.** It declares zero dependencies (2.6.x requires Lithostitched — take the older line specifically for that reason), so it removes TerraBlender, GlitchCore and Lithostitched from the pack entirely and shrinks the worldgen collision surface to near zero. BoP's main edge is block/wood variety, which Block Pack and the structure mods largely cover.

⚠ **Do not mix Lithostitched and TerraBlender.** Two competing worldgen-modifier frameworks in one world is the worst possible configuration.

**Structure mods** (When Dungeons Arise, Towns and Towers, Structory, Structory Towers, Moog's Voyager, Aquamirae, YUNG's Better Nether Fortresses, Nether Trials and Chambers, Incision, Ember's Floating Islands, Fragmentum, Cult of Azazel, …) all land here too — **and so does the datapack that arbitrates between them.**

> **Write the structure-spacing datapack in this stage.** Eleven-plus mods each ship `structure_set` JSONs tuned as if they were the only structure mod installed. Stack them and you get a Towns & Towers village generated inside a When Dungeons Arise keep. IDAS's own docs tell you to do this: *"add structures to the 'structure set to avoid' list."*
>
> One Paxi datapack that: (a) overrides the `structure_set` for every added structure mod, (b) gives each a **distinct salt** — identical salts cause correlated placement, which is why things stack on top of each other — (c) widens `spacing`/`separation` so total density across all mods lands around **vanilla +30%**, not vanilla ×11, and (d) uses avoid-lists between the biggest offenders. This is the single highest-value datapack in the pack.

**Nether authority.** YUNG's Better Nether Fortresses *replaces* the vanilla fortress structure. Anything that spawns relative to vanilla fortresses breaks — Cataclysm's `berserker_spawn` is a confirmed break, which is exactly why a "Cataclysm × YUNG's BNF Compat" mod exists. ⚠ Cult of Azazel, Incision and Nether Trials & Chambers also claim Nether space and have **no** equivalent compat mods. Either BNF owns the Nether and you accept unknown interactions with those three, or you drop BNF.

**Cut on structural grounds:** ⚠ **IDAS (Integrated Dungeons and Structures)** hard-requires **Create + Quark + Supplementaries**. One decision drags in six mods, turns a vanilla-plus adventure pack into a Create pack by side effect, and Quark's worldgen tweaks fight Terralith. Cut it and its Loot Integrations addon.

### Stage 4 — 🔒 DIMENSIONS (nearly as locked)
Twilight Forest · The Undergarden · Deeper and Darker · The Aether **or** Paradise Lost (not both) · Eternal Starlight · Grim & Bleak · Confluence · Antarchy · …

Adding a dimension later is *survivable* (new dimension = new folder). **Removing one is not** — it strands every item and build in it and can hard-crash a player on login if their last position was there. Treat the set as frozen at launch.

Add **one at a time** and record the `/spark heapsummary` delta for each. That number is what tells you when to stop. **Cap the set at 5–6.** The recon counted 9–12 candidates before Twilight Forest and The Awakening were even confirmed; on a box where 6 players will be in 5 different dimensions simultaneously, dimension count *is* the RAM and tick budget.

Free cut Leyton already identified: Paradise Lost is explicitly Aether-inspired and replaces it. ⚠ But Paradise Lost's NeoForge build requires **Sinytra Connector + Forgified Fabric API** — a Fabric→NeoForge translation layer that is beta-only on 1.21.1 (LTS branch, 274 open issues) sitting *underneath* a mixin-heavy 150-mod pack. **Take The Aether, cut Paradise Lost.** Do not put Connector under this world.

### Stage 5 — CONTENT
Mobs, farming (Farmer's Delight + addons), storage, Waystones, Artifacts, backpacks (**pick one**: Sophisticated or Traveler's), decoration.

### Stage 6 — COMBAT — **one mod at a time, boot between each**
Better Combat → Epic Knights → Expanded Combat → Simply Swords → Apotheosis + Apothic Attributes → L_Ender's Cataclysm → Mowzie's Mobs.

All of these write to `attack_damage`, `attack_speed` and `entity_interaction_range`, and **Apothic Attributes replaces vanilla's armor and protection damage-reduction formulas outright** — meaning every armor value in the pack is silently rebalanced the moment it loads. Attribute collisions do not crash. They produce weapons doing zero damage, values stacking to nonsense, and duplicate-modifier spam.

**After every single combat mod: hit a test mob with an unenchanted netherite sword and read the damage number.** If it isn't 8, something upstream just changed the math and you know exactly which jar did it. Bisecting four combat mods added together is genuinely miserable; adding them one at a time costs six extra reboots.

### Stage 7 — MAGIC
Ars Nouveau → Ars Elemental → Iron's Spells (**set `priestHouseWeight=0` immediately**) → Ars 'n Spells bridge.

⚠ **Cut T.O Magic 'n Extras** — the 1.21.1 build is a March-2025 *alpha* (~20% content, Alex's Caves stripped) while the 1.20.1 line has since gone to 6.3.0. Seventeen months of API drift against Iron's Spells, which is now at 3.16.3. It will not load, or it will load and the spells will be dead. ⚠ **Cut Ars Elixirum** — 1.21.1 stuck at 0.2.2 *alpha* from Oct 2024 while 1.20.1 is at 0.12.0.

### Stage 8 — QoL, cosmetics, client-only
Xaero's (+ the Waystones bridge — **pick exactly one** of the two bridge mods, installing both duplicates every waypoint), Visual Health, Loot Journal, Simply Tooltips, tooltip/HUD mods. Mark these **client-only** in packwiz so they never reach the server.

### Stage 9 — 6-player soak
Two-plus hours, all six online, deliberately spread across four different dimensions, with spark running. This is the only test that reproduces the actual failure mode. Watch MSPT, heap, and DIMM/CPU temps together.

---

## 5. SERVER-SIDE PERFORMANCE STACK

| Mod | Version | Verified | Notes |
|---|---|---|---|
| **Lithium** | `mc1.21.1-0.15.4-neoforge` | ✅ 2026-06-27 | Tick-loop optimisation. **Native NeoForge builds now exist** — this obsoletes the old forks. |
| **spark** | `1.10.124-neoforge-1.21.1` | ✅ 2025-02-23 | CPU profiler, heap inspection, TPS/GC reporting. **Non-negotiable.** This is how you find the one bad tick handler. |
| **Chunky** | `Chunky-NeoForge-1.4.23.jar` | ✅ 2025-04-04 | Pregeneration. See §6. |
| **ModernFix** | `5.27.20+mc1.21.1` | ⚠ recon | Load time + memory. **Leave dynamic-resources OFF** — it breaks Jurassic Reborn (#89). |
| **FerriteCore** | `7.0.3-neoforge` | ⚠ recon | Memory-layout dedup. Pairs with ModernFix, no overlap. |
| **FastSuite** | `1.21.1-6.0.7` | ⚠ recon | 2–4.5× faster recipe matching; the win scales with modlist size, so it matters more here than usual. |
| **Alternate Current** | `neoforge-mc1.21-1.9.0` | ⚠ recon | Redstone dust rewrite. **Server jar only — client-side unsupported.** |
| **Noisium** | `2.3.0+mc1.21-1.21.1` | ⚠ recon | Worldgen speed. Compatible with Lithium. |
| **ServerCore** | `1.5.19+1.21.1` | ⚠ recon | Dynamic tick/mob-cap throttling — your automatic safety valve. |
| **Clumps** | `19.0.0.1` | ⚠ recon | Merges XP orbs. Small mod, disproportionate win on a mob-heavy pack. |
| **In Control!** | ⚠ | ⚠ recon | Rules-engine spawn control. Shape *which* mob spawns *where*, instead of a global multiplier. |

**Do not install:**
- **Radium** — an unofficial Lithium fork. Same mixins, guaranteed conflict. Native Lithium is 21 months newer.
- **Canary** — no NeoForge 1.21.1 build exists.
- **Krypton, ThreadTweak, MemoryLeakFix, LetMeDespawn** — no NeoForge 1.21.1 builds.
- **ScalableLux** — still alpha, and it touches the lighting engine on a world you intend to keep for months. Revisit only if spark blames lighting.

⚠ **C2ME — unresolved contradiction in the recon.** One pass reported "no NeoForge 1.21.1 build"; another reported a separate NeoForge release exists. **Check `c2me-neoforge` on Modrinth directly before relying on it.** My recommendation regardless: **skip it.** C2ME threads chunk generation, and if §6 is done properly your chunks are already generated. A worldgen-threading mod on a months-long world is risk you don't need to take.

**If Lithium breaks a mod, do not remove Lithium** — disable the specific optimisation in `config/lithium.properties`.

**Profile before you tune.** After the first real session run `/spark profiler --timeout 300` and `/spark heapsummary`. On a pack this size the bottleneck is either (a) one badly-behaved mod's tick handler or (b) heap pressure from registries. ModernFix and FerriteCore address (b). **Nothing addresses (a) except finding it**, and spark is the only thing that will.

---

## 6. PREGENERATION WITH CHUNKY

### Why — the argument, not just the instruction

Chunk generation is the most expensive thing a modded server does, and this pack makes it dramatically worse: Terralith's custom density functions plus 11 structure mods means every generated chunk runs dozens of structure-placement checks on top of heavy noise math. Then multiply by the worst case for chunkgen — **six players exploring in six different directions at once**, six independent generation frontiers, zero shared work.

Pregenerating moves that entire cost from *"why is it lagging every time we go somewhere new"* (during the session, with an audience) to *"the box was busy Tuesday night"* (offline, with nobody watching). It is the single largest source of first-week complaints on any modded server and it is completely avoidable.

Second benefit: it front-loads the disk allocation. You find out **now** that the world is 25 GB — while you can still adjust radii and the backup design — rather than in month two when the nightly Google Drive upload stops finishing.

### What to pregen

| Dimension | Radius | Chunks (approx) | Why |
|---|---|---|---|
| Overworld | **3,000** | ~562,000 | 6 km × 6 km. Covers realistic group exploration for months. Set a world border at ±8,000 afterward so people *can* go further; those chunks just generate live. |
| The Nether | **1,000** | ~62,500 | 8:1 ratio — 1,000 Nether blocks covers 8,000 overworld blocks of travel. Also where BNF + Nether Trials + Incision + Cult of Azazel all generate expensive structures. High value per chunk. |
| The End | **1,000** | ~62,500 | Central island plus enough outer islands for a few End cities. |
| Twilight Forest | **1,500** | ~35,000 | A full exploration dimension with very large hand-authored structures. Cheap to pregen, painful not to. |
| The Undergarden | **1,000** | ~15,600 | |
| Otherside (Deeper and Darker) | **1,000** | ~15,600 | |
| The Aether | **1,000** | ~15,600 | |
| Eternal Starlight | **1,000** | ~15,600 | 22 biomes, "completely overhauled" worldgen — the most expensive per-chunk of the extra dimensions. |
| **Total** | | **~785,000 chunks** | One-time, offline. Expect 8–15 hours wall clock and 20–40 GB on disk. |

### How

**Before starting:**
1. Nobody online.
2. Temporarily set `max-tick-time=-1` in `server.properties` so the watchdog doesn't kill the server during a long generation tick. **Put it back to 60000 afterward.**
3. **Disable the backup scheduled task** for the duration — you do not want a 30-minute snapshot fighting a pregen for disk I/O.
4. Chunky persists progress across restarts, so a reboot mid-run is fine.

**Commands** (from the server console — no leading slash on console; in-game they need `/` and op):

```
chunky quiet 30
chunky world minecraft:overworld
chunky center 0 0
chunky shape square
chunky radius 3000
chunky start
```

Then per dimension, repeating `world` / `center` / `radius` / `start`. Other commands you'll want:

| Command | What it does |
|---|---|
| `chunky pause [world]` | Suspend, keeping progress |
| `chunky continue [world]` | Resume a paused or saved task |
| `chunky cancel [world]` | Stop permanently (generated chunks stay) |
| `chunky spawn` | Set center to world spawn |
| `chunky worldborder [world]` | Set center + radius from the active world border |
| `chunky corners <x1> <z1> <x2> <z2>` | Derive center + radius from two corners |
| `chunky radius 3k` / `375c` | Radius accepts `k` (blocks ×1000) and `c` (chunks) suffixes |
| `chunky trim ...` | **Dangerous.** Deletes chunks. Back up first. |

⚠ **Modded dimension IDs — verify, do not guess.** `minecraft:overworld` / `minecraft:the_nether` / `minecraft:the_end` are certain. The rest are not: it's `twilightforest:twilight_forest`, and Deeper and Darker's is `deeperdarker:otherside` while The Undergarden's is its own namespace — but these vary and a wrong ID either errors or silently pregens nothing. **Get each one from tab-completion on `/execute in <TAB>`, or read the mod's `dimension` JSON.** Confirm the chunk counter is actually moving before walking away.

**After the run:** set the border (`/worldborder set 16000` = ±8,000), restore `max-tick-time=60000`, re-enable the backup task, and take a manual full archive as the pristine "launch day" baseline.

---

## 7. THE FOUR SCRIPTS

> ✅ **BUILT 2026-08-30 — the live scripts in the server root are now the source of
> truth, not the drafts below.** The build found and fixed **three real defects in these
> drafts** (details live as comments in the scripts themselves):
> 1. `-RepetitionDuration ([TimeSpan]::MaxValue)` on repeating triggers → out-of-range
>    task XML (0x80041318); Register-ScheduledTask THROWS. Omit the parameter (omitted =
>    indefinite; the proven Palworld setup does the same).
> 2. `backup.ps1`'s `$OFFSITE` config variable collides with its `[switch]$Offsite`
>    parameter (PS vars are case-insensitive) → binding explosion on every invocation.
>    Renamed `$OFFSITE_DIR`.
> 3. Snapshot robocopy dies on `world\session.lock` — the running server holds a
>    byte-range lock on it (that IS the vanilla session lock). `/XF session.lock`.
> Also changed at build: `update.bat` self-elevates (SYSTEM task /Run needs it), its
> wait-loop matches the server's command line instead of any `java.exe` (this box also
> runs Wesley's CLIENT java), and the manual jar-swap pause became the packwiz sync from
> doc 04 §2. Java is the Microsoft JDK 21.0.4 already on the box, not a new Temurin.

1. **`update.bat` does not auto-update.** The house standard is "SteamCMD patches in place." There is no SteamCMD here, and more importantly **auto-updating a modded server mid-campaign is how you brick a months-old world.** Every mod version is pinned deliberately (§4); a silent bump reintroduces the Architectury/OmegaConfig and Architectury/Apotheosis conflicts the recon documented. So `update.bat` is a *controlled maintenance bounce*: announce → flush → graceful stop → archive → **stop and wait for the operator to swap jars by hand** → restart. It refuses to touch a jar on its own. That is a feature.

2. **`backup.ps1` is two-tier, not "zip every 15 minutes."** A pregenerated modded world is 20–40 GB. `Compress-Archive` on 30 GB takes 20+ minutes and pegs a core — it cannot run every 30 minutes. Instead: fast differential **file snapshots** into rotating slots every 30 min, and **one zip per night made from a quiesced slot, not from the live world.** That last detail directly fixes the documented Palworld defect where ~9% of backups failed because `Compress-Archive` was racing the server's own writes.

3. **No external RCON binary.** `backup.ps1` speaks the RCON protocol natively in PowerShell. One fewer downloaded executable, one fewer thing to keep on PATH for the SYSTEM account.

4. **Backup slots live on `H:`**, not `C:`. 930 GB free, and it keeps the sustained backup write load off the drive holding the live world.

---

### `launch.bat`

```bat
@echo off
REM ============================================================================
REM  launch.bat  --  Minecraft 1.21.1 / NeoForge 21.1.249 dedicated server
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    Starts the server in the foreground of whatever process calls it. The
REM    Task Scheduler boot task runs this as SYSTEM with no window, so the
REM    server runs headless from boot before anyone logs in.
REM
REM  WHY IT IS WRITTEN THIS WAY
REM    * ABSOLUTE PATH TO java.exe. The SYSTEM account does not inherit the
REM      interactive user's PATH. Bare "java" works when you double-click this
REM      and fails silently at boot. This is the #1 way a SYSTEM game-server
REM      task looks "registered but never runs".
REM    * We do NOT use NeoForge's stock run.bat. That reads user_jvm_args.txt,
REM      giving flags a second place to hide. All JVM flags live here, once.
REM    * -XX:-OmitStackTraceInFastThrow keeps stack traces intact after the JIT
REM      warms up. Without it, repeated exceptions log with NO trace at all --
REM      exactly the "useless stack trace" problem we are trying to avoid while
REM      bisecting 150 mods.
REM    * Heap dumps go to H: because a 10GB heap makes a 10GB dump file.
REM
REM  OPERATING
REM    Start now without rebooting : schtasks /Run /TN "Minecraft Dedicated Server"
REM    Stop                        : schtasks /End /TN "Minecraft Dedicated Server"
REM    Graceful stop with warning  : update.bat
REM ============================================================================

setlocal
set "SRV=C:\Game Servers\Minecraft"
set "JAVA=C:\Program Files\Eclipse Adoptium\jdk-21\bin\java.exe"
set "NFARGS=%SRV%\libraries\net\neoforged\neoforge\21.1.249\win_args.txt"
set "DUMPS=H:\Game Server Backups\Minecraft\heapdumps"

if not exist "%JAVA%" (
  echo [launch] FATAL: java.exe not found at "%JAVA%"
  exit /b 1
)
if not exist "%NFARGS%" (
  echo [launch] FATAL: NeoForge argfile not found at "%NFARGS%"
  echo [launch] Re-run the NeoForge installer, or fix the version in this script.
  exit /b 1
)
if not exist "%DUMPS%" mkdir "%DUMPS%"

cd /d "%SRV%"

"%JAVA%" ^
  -Xms10G -Xmx10G ^
  -XX:+UseG1GC ^
  -XX:+ParallelRefProcEnabled ^
  -XX:MaxGCPauseMillis=200 ^
  -XX:+UnlockExperimentalVMOptions ^
  -XX:+DisableExplicitGC ^
  -XX:+AlwaysPreTouch ^
  -XX:G1NewSizePercent=30 ^
  -XX:G1MaxNewSizePercent=40 ^
  -XX:G1HeapRegionSize=8M ^
  -XX:G1ReservePercent=20 ^
  -XX:G1HeapWastePercent=5 ^
  -XX:G1MixedGCCountTarget=4 ^
  -XX:InitiatingHeapOccupancyPercent=15 ^
  -XX:G1MixedGCLiveThresholdPercent=90 ^
  -XX:G1RSetUpdatingPauseTimePercent=5 ^
  -XX:SurvivorRatio=32 ^
  -XX:+PerfDisableSharedMem ^
  -XX:MaxTenuringThreshold=1 ^
  -XX:-OmitStackTraceInFastThrow ^
  -XX:+HeapDumpOnOutOfMemoryError ^
  -XX:HeapDumpPath="%DUMPS%" ^
  -Dfile.encoding=UTF-8 ^
  -Dusing.aikars.flags=https://mcflags.emc.gs ^
  -Daikars.new.flags=true ^
  @"%NFARGS%" nogui

endlocal
```

---

### `update.bat`

```bat
@echo off
REM ============================================================================
REM  update.bat  --  controlled maintenance bounce
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    1. Drops a maintenance lock so the backup script logs [SKIP], not [DOWN].
REM    2. RCON: announces a 60s warning, then save-all flush, then stop.
REM    3. Waits for the java process to fully exit (NOT taskkill -- a modded
REM       world killed mid-write is a chunk-corruption event).
REM    4. Takes a full archive backup of the now-quiesced world.
REM    5. PAUSES so the operator can swap jars by hand.
REM    6. Restarts via the boot task and clears the lock.
REM
REM  WHY IT DOES NOT AUTO-UPDATE ANYTHING
REM    The house convention assumes SteamCMD patching in place. There is no
REM    SteamCMD here, and auto-updating a modded server is actively dangerous:
REM    every mod version in this pack is pinned on purpose, and a silent library
REM    bump is exactly how the documented Architectury/OmegaConfig and
REM    Architectury/Apotheosis conflicts reappear on a months-old world that
REM    then refuses to boot. Jar changes are a human decision, made deliberately,
REM    recorded in MODLIST.md. This script only creates a SAFE WINDOW to make one.
REM
REM  ORDER MATTERS: announce -> flush -> stop -> backup -> change -> start.
REM  Never back up before the flush; never change jars before the process exits.
REM ============================================================================

setlocal
set "SRV=C:\Game Servers\Minecraft"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "TASK=Minecraft Dedicated Server"

echo [update] Setting maintenance lock...
echo %DATE% %TIME% > "%SRV%\maintenance.lock"

echo [update] Announcing and flushing via RCON...
%PS% -File "%SRV%\backup.ps1" -Mode Announce -Message "Server restarting for maintenance in 60 seconds."
timeout /t 60 /nobreak

echo [update] Graceful stop...
%PS% -File "%SRV%\backup.ps1" -Mode Stop

echo [update] Waiting for the server process to exit...
:waitloop
tasklist /FI "IMAGENAME eq java.exe" 2>nul | find /I "java.exe" >nul
if not errorlevel 1 (
  timeout /t 5 /nobreak >nul
  goto waitloop
)
echo [update] Process exited cleanly.

echo [update] Archiving the quiesced world...
%PS% -File "%SRV%\backup.ps1" -Mode Archive

echo.
echo ============================================================
echo  SERVER IS DOWN AND BACKED UP.
echo  Swap jars in "%SRV%\mods" now, if that is what you are here for.
echo  UPDATE MODLIST.md WITH WHAT YOU CHANGED AND WHY.
echo  Reminder: one change at a time, so a crash stays bisectable.
echo ============================================================
echo.
pause

echo [update] Starting the server...
schtasks /Run /TN "%TASK%"

del "%SRV%\maintenance.lock" 2>nul
echo [update] Done. Watch the log; a config or mod change may not survive boot.
endlocal
```

---

### `admin_setup.bat` + `setup-tasks.ps1`

```bat
@echo off
REM ============================================================================
REM  admin_setup.bat  --  RUN ONCE AS ADMIN, BEFORE THE FIRST EVER SERVER BOOT
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    Self-elevates and hands off to setup-tasks.ps1, which:
REM      1. Deletes any stray program-scoped "Query User" firewall rules for
REM         java.exe / javaw.exe.
REM      2. Adds ALLOW inbound TCP 25565 and UDP 25565 (the game port, only).
REM      3. Adds an explicit BLOCK inbound on TCP 25575 (RCON).
REM      4. Registers the SYSTEM boot task and the backup tasks.
REM      5. SELF-VERIFIES while still elevated and writes the result to a log.
REM
REM  WHY IT MUST RUN BEFORE THE FIRST BOOT  ***READ THIS***
REM    The first time java.exe binds a port, Windows pops the Firewall dialog.
REM    Clicking "Allow access" creates a PROGRAM-SCOPED rule with LocalPort=Any,
REM    which allows EVERY port that exe ever listens on -- including RCON 25575.
REM    That silently defeats "we only opened the game port". This exact thing
REM    happened on the Palworld server: four "Query User" rules scoped to the
REM    exe with LocalPort=Any left the admin API LAN-reachable for 19 days.
REM    Create the rules FIRST. If the dialog appears anyway, click CANCEL.
REM    And note: vanilla Minecraft has no rcon bind-address setting -- RCON
REM    listens on 0.0.0.0:25575. The BLOCK rule is the ONLY thing closing it.
REM    Block beats Allow in Windows Firewall, so a future stray "Allow" click
REM    cannot silently reopen it. Loopback is unaffected (127.0.0.1 never
REM    traverses the firewall), so backup.ps1 still reaches RCON.
REM
REM  AND: NEVER AUDIT THE FIREWALL OR SCHEDULED TASKS FROM A NORMAL SHELL.
REM    Get-NetFirewallPortFilter throws Access Denied partway through bulk
REM    enumeration and returns a PARTIAL LIST instead of failing -- it will
REM    silently drop rules and tell you they do not exist. Same trap as
REM    SYSTEM-owned scheduled tasks, which Get-ScheduledTask silently omits and
REM    schtasks /query reports as "Access is denied" (which is NOT "missing" --
REM    a genuinely absent task says "cannot find the file"). setup-tasks.ps1
REM    self-verifies while elevated; THAT output is the source of truth.
REM ============================================================================

net session >nul 2>&1
if errorlevel 1 (
  echo [admin_setup] Elevating...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Game Servers\Minecraft\setup-tasks.ps1"
pause
```

```powershell
# =============================================================================
#  setup-tasks.ps1  --  firewall + scheduled tasks, elevated, self-verifying
#  Called by admin_setup.bat. Do not run this non-elevated; it will lie to you.
# =============================================================================

$ErrorActionPreference = 'Stop'
$SRV  = 'C:\Game Servers\Minecraft'
$LOG  = 'H:\Game Server Backups\Minecraft\setup-tasks.log'
New-Item -ItemType Directory -Force -Path (Split-Path $LOG) | Out-Null
function Log($m) { $l = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m"; Write-Host $l; Add-Content -Path $LOG -Value $l -Encoding utf8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Not elevated. Run admin_setup.bat, not this script directly."
}
Log "=== setup-tasks.ps1 START (elevated) ==="

# --- [1/6] purge stray program-scoped popup rules for java -------------------
Log "[1/6] Removing any 'Query User' / program-scoped java firewall rules..."
$killed = 0
foreach ($r in (Get-NetFirewallRule -Direction Inbound -ErrorAction SilentlyContinue)) {
  $app = $null
  try { $app = ($r | Get-NetFirewallApplicationFilter -ErrorAction Stop).Program } catch { continue }
  if ($app -and ($app -match 'java\.exe$' -or $app -match 'javaw\.exe$')) {
    Log "        DELETE: '$($r.DisplayName)'  action=$($r.Action)  program=$app"
    Remove-NetFirewallRule -Name $r.Name -ErrorAction SilentlyContinue
    $killed++
  }
}
Log "        removed $killed program-scoped java rule(s)."

# --- [2/6] allow the game port, and ONLY the game port ----------------------
Log "[2/6] Firewall ALLOW: TCP 25565, UDP 25565"
foreach ($p in @(@{n='Minecraft (TCP 25565)';x='TCP'}, @{n='Minecraft (UDP 25565)';x='UDP'})) {
  Remove-NetFirewallRule -DisplayName $p.n -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $p.n -Direction Inbound -Action Allow `
    -Protocol $p.x -LocalPort 25565 -Profile Any -Enabled True | Out-Null
}

# --- [3/6] explicitly BLOCK RCON --------------------------------------------
Log "[3/6] Firewall BLOCK: TCP 25575 (RCON). Block beats Allow; loopback unaffected."
Remove-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -Direction Inbound `
  -Action Block -Protocol TCP -LocalPort 25575 -Profile Any -Enabled True | Out-Null

# --- [4/6] boot task (SYSTEM) ------------------------------------------------
Log "[4/6] Registering boot task 'Minecraft Dedicated Server' (SYSTEM, ONSTART)"
$a = New-ScheduledTaskAction -Execute "$SRV\launch.bat" -WorkingDirectory $SRV
$t = New-ScheduledTaskTrigger -AtStartup
$p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
       -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'Minecraft Dedicated Server' -Action $a -Trigger $t `
  -Principal $p -Settings $s -Force | Out-Null

# --- [5/6] backup tasks ------------------------------------------------------
Log "[5/6] Registering 'Minecraft Backup' (every 30 min, SYSTEM)"
$a2 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Snapshot" -WorkingDirectory $SRV
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName 'Minecraft Backup' -Action $a2 -Trigger $t2 `
  -Principal $p -Settings $s -Force | Out-Null

# Offsite runs under the INTERACTIVE user: F:\Google Drive is a per-user mount
# and SYSTEM cannot see it. Same lesson as the Palworld offsite task.
Log "[5/6] Registering 'Minecraft Backup Offsite' (nightly 04:15, INTERACTIVE user)"
$a3 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Archive -Offsite" -WorkingDirectory $SRV
$t3 = New-ScheduledTaskTrigger -Daily -At '04:15'
$p3 = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'Minecraft Backup Offsite' -Action $a3 -Trigger $t3 `
  -Principal $p3 -Settings $s -Force | Out-Null

# Optional but strongly recommended: presence poller. See notes below.
Log "[5/6] Registering 'Minecraft Presence' (every 5 min, SYSTEM)"
$a4 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Presence" -WorkingDirectory $SRV
$t4 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName 'Minecraft Presence' -Action $a4 -Trigger $t4 `
  -Principal $p -Settings $s -Force | Out-Null

# --- [6/6] SELF-VERIFY WHILE STILL ELEVATED. This output is the truth. -------
Log "[6/6] VERIFY (elevated) --------------------------------------------------"
foreach ($n in 'Minecraft (TCP 25565)','Minecraft (UDP 25565)','Minecraft RCON BLOCK (TCP 25575)') {
  # Resolve BY NAME. Bulk enumeration is what returns partial lists.
  $r = Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue
  if ($r) {
    $pf = $r | Get-NetFirewallPortFilter
    Log ("        FW  {0,-38} Enabled={1} Action={2} {3}/{4}" -f $n,$r.Enabled,$r.Action,$pf.Protocol,$pf.LocalPort)
  } else { Log "        FW  $n  *** MISSING ***" }
}
foreach ($n in 'Minecraft Dedicated Server','Minecraft Backup','Minecraft Backup Offsite','Minecraft Presence') {
  $tk = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($tk) { Log ("        TASK {0,-30} State={1} User={2}" -f $n,$tk.State,$tk.Principal.UserId) }
  else     { Log "        TASK $n  *** MISSING ***" }
}
Log "=== setup-tasks.ps1 DONE. Log: $LOG ==="
```

**Presence poller** — `-Mode Presence` RCONs `list` every 5 minutes and appends `timestamp,count,names` to a CSV. It is ten lines of code and it turns *"when did anyone last play?"* into a one-second `tail`. The Palworld entry says this in as many words: answering that question without one took an afternoon of forensics, and its own recommendation was *"if Palworld returns, add a presence poller first."* Do it on day one this time.

---

### `backup.ps1`

```powershell
<#
=============================================================================
 backup.ps1  --  Minecraft 1.21.1 NeoForge : flush, snapshot, archive, offsite
-----------------------------------------------------------------------------
 WHAT IT DOES

   -Mode Snapshot   (every 30 min, SYSTEM)
       RCON save-off -> save-all flush -> save-on, then robocopy the world into
       a ROTATING SLOT. Slots are numbered 0..11, giving 6 hours of 30-minute
       granularity. Each slot is an independent full copy, but writing one only
       costs the delta since that slot was last used, so a 25GB world snapshots
       in seconds instead of minutes.

   -Mode Archive    (nightly 04:15, and from update.bat)
       Compress the NEWEST SLOT -- not the live world -- to a timestamped zip.
       Prune to the last 14. With -Offsite, copy the newest zip to Google Drive.

   -Mode Announce / Stop / Presence
       RCON helpers used by update.bat and the presence poller.

-----------------------------------------------------------------------------
 WHY IT IS BUILT THIS WAY

  * ZIP A QUIESCED COPY, NEVER THE LIVE WORLD.
      The Palworld backup script zipped the live save and ~9% of 4,565 runs
      failed -- Compress-Archive racing the server's own writes. Here the zip
      is made from a slot that nothing is writing to, so that race cannot
      happen. (Palworld's own mothball archive was clean for exactly this
      reason: it zipped only after the process exited.)

  * ROBOCOPY /E, NOT /MIR, NOT /PURGE.
      House rule: never mirror a live save. A mirror will happily delete your
      good copy to match a bad source. /E only adds and updates. The cost is
      that a slot can retain a region file that was later deleted upstream --
      an acceptable trade, since region files are essentially never deleted in
      a growing world (only by an explicit Chunky trim).

  * SLOTS LIVE ON H:.
      930GB free, and it keeps sustained backup writes off the drive holding
      the live world.

  * FLUSH BEFORE COPY, ALWAYS.
      save-off stops the world-save thread, save-all flush forces everything to
      disk and blocks until done, save-on resumes. Copying without this gives
      you a torn snapshot that looks fine until you try to restore it.
      save-on is in a finally block: if anything throws mid-backup, autosave
      MUST come back on or the server silently stops saving forever.

  * NO EXTERNAL RCON BINARY.
      The protocol is 3 int32s and a null-terminated string. Implementing it
      inline means one less downloaded exe on the SYSTEM account's PATH.

  * LOG STATUSES mirror the harmonium/Palworld convention:
      [OK]   flushed and copied
      [SKIP] maintenance.lock present -- planned downtime
      [DOWN] server unreachable and NOT planned -- snapshot taken UNFLUSHED
      [FAIL] the copy or zip itself threw

 USAGE
   powershell -NoProfile -ExecutionPolicy Bypass -File backup.ps1 -Mode Snapshot
=============================================================================
#>

[CmdletBinding()]
param(
  [ValidateSet('Snapshot','Archive','Announce','Stop','Presence')]
  [string]$Mode = 'Snapshot',
  [string]$Message = '',
  [switch]$Offsite
)

$ErrorActionPreference = 'Stop'

# --- configuration -----------------------------------------------------------
$SRV        = 'C:\Game Servers\Minecraft'
$WORLD      = Join-Path $SRV 'world'
$LOCK       = Join-Path $SRV 'maintenance.lock'
$BAK        = 'H:\Game Server Backups\Minecraft'
$SLOTS      = Join-Path $BAK 'slots'
$ARCHIVES   = Join-Path $BAK 'archives'
$OFFSITE    = 'F:\Google Drive\My Drive\Game Server Backups\Minecraft'
$LOG        = Join-Path $BAK 'backup.log'
$PRESENCE   = Join-Path $BAK 'presence.csv'
$SLOT_COUNT = 12          # 12 x 30min = 6h of rolling 30-minute granularity
$KEEP_ZIPS  = 14          # nightly archives kept locally
$RCON_HOST  = '127.0.0.1'
$RCON_PORT  = 25575
$LOCK_STALE_MIN = 10

New-Item -ItemType Directory -Force -Path $BAK,$SLOTS,$ARCHIVES | Out-Null

function Write-Log { param([string]$Status,[string]$Text)
  $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $Status, $Text
  Write-Host $line
  Add-Content -Path $LOG -Value $line -Encoding utf8
}

function Get-RconPassword {
  $p = (Select-String -Path (Join-Path $SRV 'server.properties') -Pattern '^rcon\.password=(.*)$').Matches[0].Groups[1].Value
  if ([string]::IsNullOrWhiteSpace($p)) { throw 'rcon.password is empty in server.properties' }
  return $p
}

# --- minimal RCON client (Source RCON protocol, as used by vanilla MC) --------
function Invoke-Rcon {
  param([string[]]$Commands,[int]$TimeoutMs = 8000)
  $pw = Get-RconPassword
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($RCON_HOST,$RCON_PORT,$null,$null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw 'RCON connect timeout' }
    $client.EndConnect($iar)
    $s = $client.GetStream(); $s.ReadTimeout = $TimeoutMs; $s.WriteTimeout = $TimeoutMs

    function Send-Packet($id,$type,$body) {
      $b  = [Text.Encoding]::ASCII.GetBytes($body)
      $ms = New-Object IO.MemoryStream
      $bw = New-Object IO.BinaryWriter($ms)
      $bw.Write([int](4 + 4 + $b.Length + 2)); $bw.Write([int]$id); $bw.Write([int]$type)
      $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Flush()
      $out = $ms.ToArray(); $s.Write($out,0,$out.Length); $s.Flush()
    }
    function Read-Packet {
      $hdr = New-Object byte[] 4; $n = 0
      while ($n -lt 4) { $r = $s.Read($hdr,$n,4-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      $len = [BitConverter]::ToInt32($hdr,0)
      $buf = New-Object byte[] $len; $n = 0
      while ($n -lt $len) { $r = $s.Read($buf,$n,$len-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      [pscustomobject]@{
        Id   = [BitConverter]::ToInt32($buf,0)
        Type = [BitConverter]::ToInt32($buf,4)
        Body = [Text.Encoding]::ASCII.GetString($buf,8,$len-10)
      }
    }

    Send-Packet 1 3 $pw                       # 3 = SERVERDATA_AUTH
    $auth = Read-Packet
    if ($auth.Type -ne 2) { $auth = Read-Packet }   # tolerate a leading empty packet
    if ($auth.Id -eq -1)  { throw 'RCON auth failed (wrong password)' }

    $results = @(); $i = 2
    foreach ($c in $Commands) { Send-Packet $i 2 $c; $results += (Read-Packet).Body; $i++ }
    return $results
  } finally { $client.Close() }
}

function Test-ServerUp { try { Invoke-Rcon -Commands @('list') -TimeoutMs 4000 | Out-Null; $true } catch { $false } }

function Test-Maintenance {
  if (-not (Test-Path $LOCK)) { return $false }
  if (((Get-Date) - (Get-Item $LOCK).LastWriteTime).TotalMinutes -gt $LOCK_STALE_MIN) {
    Write-Log 'OK' 'stale maintenance.lock ignored (>10 min)'; return $false
  }
  return $true
}

function Format-Size { param([long]$b) '{0:N2} GB' -f ($b / 1GB) }

# =============================================================================
switch ($Mode) {

  'Announce' { Invoke-Rcon -Commands @("say $Message") | Out-Null; break }

  'Stop' {
    Invoke-Rcon -Commands @('save-all flush','stop') | Out-Null
    Write-Log 'OK' 'graceful stop issued via RCON'
    break
  }

  'Presence' {
    if (-not (Test-Path $PRESENCE)) { Add-Content $PRESENCE 'timestamp,count,names' -Encoding utf8 }
    try {
      $r = (Invoke-Rcon -Commands @('list'))[0]
      # "There are N of a max of M players online: a, b, c"
      $count = 0; $names = ''
      if ($r -match 'There are (\d+) of a max of \d+ players online:?\s*(.*)$') {
        $count = [int]$Matches[1]; $names = ($Matches[2] -replace ',\s*',';').Trim()
      }
      Add-Content $PRESENCE ('{0},{1},{2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'),$count,$names) -Encoding utf8
    } catch {
      Add-Content $PRESENCE ('{0},-1,DOWN' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss')) -Encoding utf8
    }
    break
  }

  'Snapshot' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $slot = Join-Path $SLOTS ('slot{0:d2}' -f ([int]((Get-Date).ToFileTimeUtc() / 18000000000) % $SLOT_COUNT))
    $status = 'OK'; $flushed = $false

    if (-not (Test-Path (Join-Path $WORLD 'level.dat'))) {
      Write-Log 'FAIL' 'world\level.dat missing -- refusing to snapshot'; break
    }

    if (Test-Maintenance) {
      $status = 'SKIP'
      Write-Log 'SKIP' 'maintenance lock present -- planned downtime, snapshot skipped'
      break
    }

    if (Test-ServerUp) {
      try {
        Invoke-Rcon -Commands @('save-off','save-all flush') | Out-Null
        Start-Sleep -Seconds 3
        $flushed = $true
      } catch { Write-Log 'FAIL' "flush failed: $($_.Exception.Message)"; $status = 'FAIL' }
    } else {
      $status = 'DOWN'    # unplanned outage: still snapshot, but flag it unflushed
    }

    try {
      New-Item -ItemType Directory -Force -Path $slot | Out-Null
      # /E   copy subdirs incl. empty     /XO  skip older      /MT:16 multithreaded
      # NO /MIR AND NO /PURGE -- see header. We never delete from a snapshot slot.
      $rc = Start-Process robocopy -ArgumentList @(
              "`"$WORLD`"", "`"$slot`"", '/E','/XO','/R:1','/W:1','/MT:16',
              '/NFL','/NDL','/NP','/NJH','/NJS'
            ) -NoNewWindow -Wait -PassThru
      if ($rc.ExitCode -ge 8) { throw "robocopy exit $($rc.ExitCode)" }
      if ($status -ne 'DOWN' -and $status -ne 'FAIL') { $status = 'OK' }
    } catch {
      $status = 'FAIL'; Write-Log 'FAIL' "snapshot copy failed: $($_.Exception.Message)"
    } finally {
      # AUTOSAVE MUST COME BACK ON NO MATTER WHAT.
      if ($flushed) { try { Invoke-Rcon -Commands @('save-on') | Out-Null } catch { Write-Log 'FAIL' 'save-on FAILED -- AUTOSAVE IS OFF, INTERVENE NOW' } }
    }

    $sw.Stop()
    $size = (Get-ChildItem $slot -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum).Sum
    if ($status -in 'OK','DOWN') {
      Write-Log $status ('{0}  {1:mm\:ss}  slot={2}  flushed={3}' -f (Format-Size $size), $sw.Elapsed, (Split-Path $slot -Leaf), $flushed)
    }
    break
  }

  'Archive' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $newest = Get-ChildItem $SLOTS -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { Write-Log 'FAIL' 'no snapshot slot to archive'; break }

    $zip = Join-Path $ARCHIVES ('Minecraft-{0}.zip' -f (Get-Date -f 'yyyy-MM-dd_HH-mm'))
    try {
      # Zipping a QUIESCED SLOT, not the live world. This is the fix for the
      # ~9% Compress-Archive failure rate the Palworld backup suffered.
      Compress-Archive -Path (Join-Path $newest.FullName '*') -DestinationPath $zip -CompressionLevel Optimal
    } catch {
      $sw.Stop(); Write-Log 'FAIL' "archive failed: $($_.Exception.Message)"; break
    }

    Get-ChildItem $ARCHIVES -Filter 'Minecraft-*.zip' | Sort-Object LastWriteTime -Descending |
      Select-Object -Skip $KEEP_ZIPS | Remove-Item -Force -ErrorAction SilentlyContinue

    if ($Offsite) {
      if (Test-Path (Split-Path $OFFSITE -Parent)) {
        New-Item -ItemType Directory -Force -Path $OFFSITE | Out-Null
        # Plain copy of ONE file. Never robocopy /MIR into the offsite folder.
        Copy-Item $zip -Destination $OFFSITE -Force
      } else {
        Write-Log 'FAIL' 'offsite path unavailable -- is Google Drive mounted for this user?'
      }
    }

    $sw.Stop()
    Write-Log 'OK' ('{0}  {1:hh\:mm\:ss}  archive={2}  offsite={3}' -f (Format-Size (Get-Item $zip).Length), $sw.Elapsed, (Split-Path $zip -Leaf), [bool]$Offsite)
    break
  }
}
```

**Backup design notes:**

- **All modded dimensions live under `world\dimensions\<namespace>\<path>\`** in modern Minecraft, so zipping/copying `world\` alone captures every dimension. One folder, no split-save complexity — unlike DST.
- **Restore procedure:** stop the server, rename `world` → `world.broken`, robocopy the chosen slot (or extract the chosen zip) to `world`, start. Test this **before** launch, on a throwaway. A backup you have never restored is a hypothesis.
- ⚠ **Offsite bandwidth is a real risk.** A compressed modded world will be **3–8 GB**. Uploading that nightly may not fit the connection's overnight window. If it doesn't: switch to **weekly full offsite**, plus a **nightly small-payload offsite** of `world\level.dat`, `world\playerdata\`, `world\data\` and `world\serverconfig\` — a few MB that covers everything irreplaceable except the region files.
- **Disk budget:** 12 slots × ~25 GB = ~300 GB on `H:` (930 GB free). Archives: 14 × ~5 GB = ~70 GB. Comfortable. Re-check after the pregen tells you the real world size.

---

## 8. CLIENT-SIDE — how the other five get the matching modlist

### Recommendation: **packwiz + Prism Launcher**

**The reasoning, which is entirely about the second month, not the first day.**

Every option can deliver the pack once. The question is what happens the **twentieth** time you change it — and you will change it twenty times during assembly and several more during the campaign.

| Option | The problem |
|---|---|
| **CurseForge modpack export** | Only mods with a CurseForge project ID can be manifest-referenced. Several mods here are Modrinth-only, and several (Mowzie's Cataclysm, Loot Integrations, Macabre) are CurseForge-only with *no* Modrinth listing. Anything unavailable has to go in `overrides/` as a raw jar — which is **redistribution**, and a large fraction of these mods are All Rights Reserved. |
| **Modrinth `.mrpack`** | Same shape, opposite coverage gap. Doesn't cover the CF-only mods. |
| **Prism/MultiMC instance export (bundled jars)** | Dead simple for the friends — download zip, drag into Prism. But it bundles the actual jars, so it's redistribution of ARR mods. Nobody in a six-person friend group is going to sue, but you should know you're doing it. Worse operationally: **every modlist change means everyone re-downloads ~800 MB and re-imports**, and you have no way to tell who is stale. |
| **packwiz** | ✅ |

**Why packwiz wins for a group of six:**

1. **Updates are the entire problem, and packwiz is the only option that solves them.** The pack is a manifest (`pack.toml` + one `.pw.toml` per mod, each holding an exact file ID and hash). Clients run `packwiz-installer-bootstrap.jar` as a **pre-launch command** in Prism; on every launch it diffs the manifest and downloads only what changed, straight from the CurseForge/Modrinth CDNs. For your friends the update experience is *"click Launch."* Over months with six people, that is the difference between a working server and a support hotline.
2. **No licensing problem.** You distribute hashes and URLs. Every jar comes from its author's own host. Nothing is redistributed.
3. **It kills the #1 modded-multiplayer bug class.** packwiz tags each mod `client` / `server` / `both`, and the server's `mods\` folder is generated from the *same manifest*. "The server has Cataclysm 3.32 and Leyton has 3.33" simply cannot happen. It also means the ~15 client-only mods (Xaero's, Visual Health, Simply Tooltips, Loot Journal) never touch the server, and the server-only mods (Alternate Current, When Dungeons Arise, Ember's Floating Islands, Loot Integrations) never touch the clients.
4. **Version pinning is first-class.** Every entry records an exact file and SHA. Nothing auto-bumps. The recon's single loudest instruction — *"pin every library version at pack-freeze and never auto-update mid-campaign"* — is enforced by the tool rather than by discipline.
5. **It's a git repo.** Every modlist change is a commit. *"Which mod did we add the day it started crashing"* becomes `git log`, which is exactly the artifact §4's bisection discipline needs.

**Setup cost, honestly:** one afternoon for you (`packwiz init`, then `packwiz cf add <slug>` / `packwiz mr add <slug>` per mod — this is also a natural forcing function to record every version), and about **five minutes, once** for each friend:

1. Install **Prism Launcher**.
2. New instance → Minecraft **1.21.1** → NeoForge **21.1.249**.
3. Instance Settings → Custom Commands → Pre-launch command:
   `"$INST_JAVA" -jar packwiz-installer-bootstrap.jar <URL to pack.toml>`
4. Instance Settings → Memory → **8192 MB** (not the 4 GB default — a 150-mod client will thrash at 4).
5. Launch. Everything else is automatic, forever.

**Hosting the manifest:** it needs to be HTTP-reachable by all five. Use a **GitHub repo + GitHub Pages** (or raw.githubusercontent). Free, versioned, and — importantly — it does **not** add a port forward or any attack surface to the game box. The repo contains no jars and must contain **no RCON password and no server IP**.

**Fallback if someone refuses to install Prism:** a Prism instance-export zip in Discord, with a version number in the filename so you can tell at a glance who's stale. Re-issue on every change. Accept the licensing caveat and the update tax.

**Client-side notes to pass along:**
- **8 GB heap minimum.** JEI alone builds a full ingredient index over ~150 mods' item registries at world join.
- **A renderer is mandatory**, not optional, at this mod count. ⚠ **Verify which:** Sodium 0.6+ ships NeoForge builds, and Embeddium is the legacy Forge-lineage fork. Check which one the pack's other client mods (Iris/Oculus for shaders) actually agree with on 1.21.1 before committing the group.
- ⚠ **Shader warnings from recon:** Creature Feature mixes into `GameRenderer` and `PostChain` for Saint Solis (its `fixsas` config exists precisely because that depth pass breaks with shaders — set it true preemptively). Epic Knights' own page states OptiFine 1.20+ glitches with it. **Nobody runs OptiFine.**
- Warn them about **map storage**: Xaero's world-map tiles across eight dimensions over a months-long campaign will reach multiple GB per person. Keep `xaero\world-map\` off a nearly-full SSD.

---

## 9. RISK REGISTER

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | **Memory instability read as mod conflicts.** Marginal DIMM = identical symptoms to a mod conflict; bisection silently gives false results. | Med | **Critical** | Gate 0. Memtest86 ×2 + TM5 anta777 + OCCT combined, *before* mods. Fall back to 4800 JEDEC rather than ship an unstable 6000. |
| 2 | **The tick ceiling, not the memory ceiling.** 64 GB buys zero TPS. | **High** | High | `simulation-distance=6`, halve every added spawn weight, ServerCore + In Control!, cut Cobblemon/Minecolonies/Jurassic natural spawns. spark before tuning. |
| 3 | **Worldgen mod added or removed after world creation** → chunk seams, `Unknown biome`, unloadable chunks. Unrecoverable on a months-old world. | Med | **Critical** | Stage 3 lock. Throwaway worlds only. `WORLDGEN FROZEN <date>` in MODLIST.md before the real world exists. |
| 4 | **Terralith + Biomes O' Plenty.** TerraBlender seizes the biome source; Terralith's distribution silently degrades. **Nothing errors.** Discovered in week three; unfixable by then. | **High** if both installed | High | Pick one. **Terralith 2.5.8 alone** (zero deps — also removes TerraBlender, GlitchCore and Lithostitched from the pack). |
| 5 | **Structure density collision.** 11+ mods each tuned as if alone → interpenetrating buildings, correlated placement from identical salts. | **High** | Med | The Stage-3 Paxi datapack: distinct salt per set, widened spacing, avoid-lists. Target vanilla +30%, not vanilla ×11. |
| 6 | **IDAS drags in Create + Quark + Supplementaries.** One pick becomes six mods; Quark fights Terralith; the pack becomes a Create pack by accident. | High if kept | High | Cut IDAS and its Loot Integrations addon. |
| 7 | **Windows Firewall popup on first java launch** creates a program-scoped ANY-PORT allow rule that silently exposes RCON. *This exact thing happened on Palworld — 19 days of LAN-reachable admin API.* | **High** | High | Run `admin_setup.bat` **before the first boot**. Click **Cancel**, never Allow. Explicit BLOCK on TCP 25575. Re-audit elevated after boot 1. |
| 8 | **SYSTEM task invisibility.** Non-elevated `schtasks`/`Get-ScheduledTask` reports Access Denied or silently omits — which is *not* "missing". | Med | Med | `setup-tasks.ps1` self-verifies while elevated and logs. That log is the source of truth. Never diagnose from a normal shell. |
| 9 | **Non-elevated firewall audit returns a partial list** instead of failing. | Med | Med | Resolve rules **by DisplayName**, never bulk-enumerate; audit elevated only. |
| 10 | **`java` not on SYSTEM's PATH** → boot task registered, verified, and never actually runs. | Med | High | Absolute path to `java.exe` in `launch.bat`, with an existence check that fails loudly. |
| 11 | **Backup design doesn't scale.** A 25 GB world cannot be zipped every 30 min; the Palworld pattern breaks outright here. | Certain if copied naively | High | Two-tier: robocopy slots every 30 min, one nightly zip **from a quiesced slot**. |
| 12 | **Zipping a live world** — the documented Palworld defect, ~9% of 4,565 runs failed. | Certain if repeated | Med | Structurally impossible here: `Archive` mode only ever reads a slot. |
| 13 | **Offsite upload can't keep up.** 3–8 GB nightly to Google Drive. | Med | Med | Weekly full offsite + nightly small-payload (`level.dat`, `playerdata`, `data`, `serverconfig`). |
| 14 | **Config precedence trap.** `world\serverconfig\` wins over `config\` forever; edits to `config\` silently do nothing. | **High** | Med | Documented in §3.5. Do config work on throwaway worlds pre-freeze; after freeze, edit the world copy. |
| 15 | **Library version drift.** Architectury/OmegaConfig and Architectury/Apotheosis conflicts are version-specific; a silent bump stops a months-old world booting. | Med | **Critical** | packwiz pins exact file IDs. Never auto-update. MODLIST.md. |
| 16 | **Client/server mod mismatch.** | High without tooling | Med | packwiz single source of truth with client/server side flags. |
| 17 | **Curios vs Accessories.** Four mods hard-require Curios; The Aether *embeds* Accessories. | Med | Med | Curios is the spine. If The Aether stays, run the **Accessories Compatibility Layer** (never the deprecated one). |
| 18 | **Sinytra Connector under the pack.** Beta-only on 1.21.1, LTS branch, 274 open issues, sitting beneath a mixin-heavy 150-mod pack. | High if used | **Critical** | Do not use it. Cut Paradise Lost (keep The Aether) and Dark Fantasy: Nordic Tombs. |
| 19 | **Mods that fight the perf stack.** Jurassic Reborn vs ModernFix (#89) and VintageFix (#82) dynamic resources. | Med | Med | Leave ModernFix dynamic resources OFF; better, cut Jurassic Reborn. |
| 20 | **Disk.** World + 12 slots + 14 archives could exceed 400 GB. | Med | Med | Slots and archives on `H:` (930 GB free). Re-measure right after pregen. |
| 21 | **Thermals.** Enclosed cubby + 24/7 server + gaming load + DDR5 at ~1.35–1.4 V. | Med | Med | LHM `:8085`. Baseline DIMM/CPU/VRM temps during Gate 0 stress; re-check daily for the first week post-launch. |
| 22 | **UPS runtime is ~20 min.** A modded server killed mid-write is a chunk-corruption event. | Low | High | Boot task restores service. Nice-to-have: a UPS low-battery trigger that RCONs `save-all flush` + `stop`. |
| 23 | **Snapshot-only Minecolonies on 1.21.1** — no stable channel build; snapshot data formats change between builds and rollback is often impossible. | Med | High | Cut it. If kept: pin one snapshot for the entire campaign, one shared colony, never update. |
| 24 | **Nobody plays it.** The Palworld outcome: hardened, automated, mothballed at four weeks. Spend three months assembling and the rotation moves on before launch. | **Med-High** | High | Set a launch date and build to it. Ship at ~120 mods rather than gold-plating to 150. And add the presence poller on **day one** — the Palworld entry's own recommendation. |
| 25 | **RCON password in plaintext** in `server.properties`. | Low | Med | Firewall BLOCK is the only real control (vanilla has no RCON bind-address). Long random password; never commit it to the packwiz repo. |
| 26 | **Death penalty left on the inherited default** (`difficulty=hard`, no `keepInventory`, no grave mod). Systematically taxes gear tracks, exempts knowledge tracks, and discourages the group from ever fighting the boss the entire parity anchor is derived from. | **Certain if not decided** | High | Decide before Tier 0 — `01-BALANCE-PLAYBOOK.md §1.10.2`. A grave mod is a `mods/` addition and must land **before the Stage-5 freeze**. |
| 27 | **Unequal playtime between the six.** A zero-defect pack still ships a **2.2× power spread** between a 120 h host and a 20 h player — larger than the worst rate mismatch in the balance doc, and unfixable by any datapack. Historically this, not imbalance, is what ends a group campaign. | **High** | High | `01-BALANCE-PLAYBOOK.md §1.10.1`: House Rule 5 disclosure + a shared gear chest at spawn (free), Bountiful boards tilted toward low-hour players (1 loot file). Pairs with the presence poller in Risk 24 — it gives you the hour counts to act on. |

---

## Appendix — verification status

**✅ Verified live 2026-08-29:**
- NeoForge **21.1.249** is the newest 1.21.1 build (`maven.neoforged.net` version API).
- Chunky **1.4.23** / `Chunky-NeoForge-1.4.23.jar`, published 2025-04-04, is the newest NeoForge 1.21.1 build (Modrinth API).
- Chunky command syntax (`start`/`pause`/`continue`/`cancel`/`world`/`center`/`radius`/`shape`/`spawn`/`worldborder`/`corners`/`quiet`/`trim`) — Chunky wiki.
- Lithium **`mc1.21.1-0.15.4-neoforge`**, 2026-06-27 (Modrinth API).
- spark **`1.10.124-neoforge-1.21.1`**, 2025-02-23 (Modrinth API).

**⚠ Carried from the recon brief — re-verify at build time:**
ModernFix 5.27.20 · FerriteCore 7.0.3 · FastSuite 1.21.1-6.0.7 · Alternate Current 1.9.0 · Noisium 2.3.0 · ServerCore 1.5.19 · Clumps 19.0.0.1 · every content-mod version in the modlist audit.

**⚠ Explicitly unresolved / must be checked before relying on:**
- The exact `libraries\net\neoforged\neoforge\21.1.249\win_args.txt` path — confirm after running the installer; `launch.bat` depends on the literal string.
- Whether a **C2ME NeoForge 1.21.1** build exists (the recon contradicts itself). Recommendation is to skip it regardless.
- Whether NeoForge exposes per-`MobCategory` spawn caps anywhere (I found none; the plan routes around it via simulation-distance + ServerCore + In Control! + per-mod weights).
- The exact **dimension IDs** for every modded dimension you pregen. Get them from tab-completion, not from memory.
- **Structure Gel API**'s 1.21.1 NeoForge status (CurseForge-only; the Modrinth slug 404s).
- Which renderer (Sodium NeoForge vs Embeddium) the client pack should standardise on.

*(Web-search budget for this session was exhausted; all ✅ items above came from direct API/doc fetches.)*
