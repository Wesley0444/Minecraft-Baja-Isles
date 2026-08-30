# 05 — THE WORLD SPLICE (BoP × Terralith, hard seam at X=0)

**Status: VIABLE.** This supersedes `04-PACK-DISTRIBUTION.md §3`'s "the X=0 seam is not
achievable" — that was true *for live worldgen*. It is not true for a pre-baked world.

Wesley's proposal: pregen one world with BoP, another with Terralith, splice them at X=0,
and ship a finite world. It works, and three facts make it far cleaner than it sounds.

---

## 1. WHY THIS WORKS

**1. X=0 is already a chunk and region boundary — you are not carving anything.**
Chunk 0 spans blocks 0–15; chunk −1 spans −16..−1. Region `r.0.z` covers blocks 0–511;
`r.-1.z` covers −512..−1. The seam you want is an existing file seam. You are choosing
which chunks land in one folder, not editing terrain.

**2. Biomes are stored per-chunk, not computed at load.** Since 1.18 the biome palette
lives in each chunk's NBT (`sections[].biomes`). A copied chunk keeps its biomes forever,
regardless of what the live biome source would say. This is the crux — it is why the
splice is permanent rather than being overwritten on next load.

**3. You only pregen half of each world.** Chunky's `corners` command takes an arbitrary
rectangle, so each run generates only the side it contributes. **Total work equals one
full world, not two.**

---

## 2. SIZING

Pick a radius `R`; the world becomes `2R × 2R` and the seam runs the full Z length.

| R | World | Chunks | Pregen @ ~20 ch/s | Region files | Disk (~10 MB/rgn) |
|---|---|---|---|---|---|
| 5000 | 10k × 10k | 390,625 | ~5.5 h | ~380 | ~4 GB |
| **6000** | **12k × 12k** | **562,500** | **~8 h** | **~550** | **~5.5 GB** |
| 8000 | 16k × 16k | 1,000,000 | ~14 h | ~980 | ~10 GB |

**Recommend R = 6000.** 144 km², comfortably above the 10–20k diameter most SMPs run, and
an overnight job. Heavily-modded pregen is 10–40 chunks/s on a 14700KF — the 20 is a
mid-estimate, so treat these as ±50%.

Disk is a non-issue (H: has ~930 GB). Budget ~2× transiently, since both half-worlds exist
before the merge.

> **You are not locked in.** Extending later is the *same procedure* on a new ring: pregen
> the new outer band in two halves with the respective configs, splice, push the border
> out. So do not over-buy radius up front.

---

## 3. PROCEDURE

### Step 0 — freeze the modlist. Non-negotiable.
Both runs must use an **identical mod set and identical NeoForge/MC versions**, differing
*only* in biome config. Different mod sets can mean different block IDs and chunk NBT.
**Nothing worldgen-related may change after this point, ever.** This was already a rule;
the splice makes it absolute.

### Step 1 — Run A: the BoP half
- BoP installed and generating normally.
- **Remove the Terralith datapack** from the world's `datapacks/` folder.
- Pregen only X ≥ 0:
  ```
  /chunky world minecraft:overworld
  /chunky corners 0 -6000 6000 6000
  /chunky start
  ```
- Copy the finished world folder aside as `world-bop`.

### Step 2 — Run B: the Terralith half
- Fresh world, **same seed** (see §5), same mod set.
- **Terralith datapack present.**
- **BoP still installed** — set its TerraBlender region weight to `0` so it registers its
  biomes/blocks but contributes no terrain. ⚠ *Verify 0 is accepted; if the config rejects
  it, use `1` and accept trace BoP on the Terralith side.*
- Pregen only X ≤ 0:
  ```
  /chunky corners -6000 -6000 0 6000
  /chunky start
  ```
- Copy aside as `world-terralith`.

### Step 3 — Splice with MCA Selector
**Back up both worlds first.**

1. Open `world-terralith` (this becomes the target — keep the Terralith half).
2. Select the region X ≥ 0 and delete those chunks.
3. **Tools → Import chunks**, source = `world-bop/region`, **offset 0/0**, overwrite on.
4. Import into the current selection so only X ≥ 0 is touched.

No WorldEdit. A `//copy` across 12,000 × 384 × 12,000 would OOM instantly — this is a
file-level chunk merge and runs in minutes.

> **Bonus:** MCA Selector's selection is arbitrary. The boundary does not have to be a
> straight line — a circle of Terralith inside a BoP sea, a diagonal, a ragged coastline
> all work identically. The straight X=0 line is just the easiest to reason about.

### Step 4 — Ship it
- Final server runs **BoP + Terralith both installed**, forever (see §4).
- Set the border **inside** the pregen edge so nothing generates at the fringe:
  ```
  /worldborder center 0 0
  /worldborder set 11800
  ```
  (11,800 = 2×5,900, leaving a 100-block margin.)
- Verify Nether border behaviour separately — borders are per-dimension and the 8:1 ratio
  is not always applied automatically.
- Only the **Overworld** is spliced and bordered. Twilight Forest, Undergarden, Eternal
  Starlight etc. are untouched and stay effectively unbounded.

### Step 5 — Verify before anyone joins
- Fly the full length of X=0 with the seam in render distance.
- Watch `logs/latest.log` for **missing-registry** or **chunk load failure** warnings.
- Confirm biomes on each side with F3 while crossing the line.

---

## 4. ⚠ THE PERMANENT CONSTRAINT

**Both BoP and Terralith must stay installed for the life of the world.**

Chunk NBT references biomes by ID (`biomesoplenty:*`, `terralith:*`). Remove either and
every chunk on that half references biomes and blocks that no longer exist — that is
data loss, not a crash you can back out of. Terralith is a *datapack*, so it must stay in
the world folder too, not just the mods list.

Write this into the server README. It is the kind of thing that gets forgotten in six
months during a "let's trim the modlist" session.

---

## 5. DECISIONS YOU STILL OWE

**Seed: DIFFERENT — DECIDED 2026-08-30.** Wesley: *"more dramatic, uglier, more absurd
transitions sounds like a feature."* Two genuinely unrelated worlds jammed together.
Expect oceans meeting cliff faces, rivers terminating in walls, and biome pairs that make
no ecological sense. That is the point.

⚠ **Each half keeps its own seed forever.** Record both in the server README — you need
seed A to regenerate the X≥0 ring and seed B for X≤0 when extending (§5.1). Losing them
means the world can never be extended seamlessly again.

### 5.1 PHASED PREGEN — small today, extend overnight
Approved 2026-08-30. Play sooner, grow the map later.

| Phase | Pregen | Border | Chunks | Time @ ~20 ch/s |
|---|---|---|---|---|
| **Today** | R = 3000 | `/worldborder set 5800` (±2900) | ~141k | ~2–4 h |
| **Tonight** | ring 3000 → 6000 | `/worldborder set 11800` | ~422k | ~6 h |

**Use the hard border, not a social rule.** "Don't go past 2000" fails the first time
someone chases a Waystone. Pregen 3000, border 2900, done.

**Extending is the same dance on a ring, not a border push:**
1. Fresh world, **seed A**, BoP-only, same mod set → `/chunky corners 3000 -6000 6000 6000`
   *(plus the −6000..−3000 and 3000..6000 Z bands for X 0..3000 — i.e. the L-shaped ring
   on the positive-X side)*
2. Fresh world, **seed B**, Terralith-only → the mirrored ring on the negative-X side
3. MCA Selector: import both rings into the live world, offset 0/0
4. Push the border to 11800

Player builds inside R=3000 are never touched — you only import chunks outside it.

> 🔴 **The one thing that breaks this: changing a WORLDGEN mod between the two pregens.**
> The ring stitches seamlessly only because a fresh same-seed world with an identical mod
> set generates identical terrain. Touch BoP, Terralith, TerraBlender weights, or any
> noise/biome mod during today's shakedown and you get an unintended seam at R=3000.
> **Removing a crashing non-worldgen mod is safe** — that is the likely day-one fix.
> Structure mods sit in between: safe for terrain continuity, but removing one from a live
> world can leave orphaned blocks.

**Spawn point.** 0,0 sits exactly on the seam — thematically perfect, and arguably the best
possible spawn for this concept. Nudge it a few hundred blocks off if you want a calmer
starting area.

**The underground seam.** Where caves meet solid stone at X=0 you get a flat vertical wall
through the whole 384-block column. Smoothing 12,000 blocks of it is not practical. Accept
it — it is the aesthetic, and it reads as intentional from inside a cave.

---

## 6. HONEST COSTS

- **The world is finite.** ±6000 Overworld. Fine for 6 players with Waystones and eight
  modded dimensions, but it is a real change from vanilla-infinite and worth telling the group.
- **~8 hours of pregen**, plus a merge and a verification pass. One-time, overnight.
- **Modlist freeze lands earlier** than it otherwise would — before pregen instead of before
  launch. Everything in `03-FINAL-DECISIONS.md §6` (the `/attribute` check, the Confluence
  Life Crystal test) must be settled *first*, because they could change the mod set.
- **Structures spanning X=0 get truncated.** Cosmetic; some half-buildings on the line.
  Arguably on-theme.
