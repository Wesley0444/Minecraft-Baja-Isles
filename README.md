# Minecraft 1.21.1 NeoForge — server project

**Entry point. Start here.** Planning is COMPLETE as of 2026-08-30, all three
modlist-gating tests **PASSED** (same day), and the **MODLIST IS FROZEN as of 2026-08-30 —
FOR GOOD** (reopened three times that day: Integrated family cut at pack-build → Alex's
Caves + perf stack + doc 03's dropped ADD table at server build → Integrated family
REVERSAL on David's vote — all in doc 03 §1. Next reopening request gets refused by
default and escalated to Wesley in person). Nothing worldgen-related may change
post-pregen, ever. The **packwiz pack is BUILT (125 stubs), boot-verified, and LIVE on
GitHub Pages** — see `planning/04-PACK-DISTRIBUTION.md §7` for the landmines.
Pack URL: <https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml>.
**The server is BUILT and boot-verified (step 4 complete, 2026-08-30):** NeoForge
21.1.249 in this folder, four ops scripts live, firewall hardened (explicit RCON block —
the Palworld lesson), SYSTEM boot task + backup/presence tasks elevated-verified.
Next: datapacks + config nerfs (step 5) — **Quark's worldgen module config is a
step-5/6 BLOCKER** (doc 03 §1 obligations block).

- **Who:** Wesley (host) + Leyton, DJ, David, Dan +1. Six players.
- **What:** long shared campaign, months-long world, ~130 mods.
- **Design rule:** *kitchen sink with a side of balance.* Only fix **strong gear that is
  cheap to get**. Expensive-but-strong is fine. Big numbers are fine if earned.

---

## ✅ THE THREE GATES — all passed 2026-08-30

Each could have changed the modlist, and **the modlist must be frozen before pregen** (the
world splice makes that absolute). All three are done; nothing blocks the freeze.

| # | Test | Why it blocks | Time |
|---|---|---|---|
| 1 | ✅ **`/attribute` prefix check — DONE 2026-08-30.** Verified on a headless vanilla 1.21.1 server: `generic.` prefix **required**; unprefixed IDs error. Audit was right — on-disk overrides are already correct, **change nothing**. `01-BALANCE-PLAYBOOK.md §0.1`. | done |
| 2 | ✅ **Confluence Life Crystal worldgen test — PASSED 2026-08-30.** Confluence is **IN**, entry-gated. Empirical A/B on a throwaway NeoForge server, same seed: 131 chunks with life crystals → **0** with the `confluence-gate-life-crystal` datapack (now in `datapacks/`), other 19 overworld features intact. Full results + corrections (no custom dimension; biome-gated; Curios dep) in `03-FINAL-DECISIONS.md §4.3`. | done |
| 3 | ✅ **Blocked-mod scan — DONE 2026-08-30.** All 65 CF + 25 Modrinth entries verified downloadable for 1.21.1 NeoForge. `ars-n-spells` + `structory-towers` blocked CF downloads → **moved to the Modrinth list** (proper builds there). `creature-features` = **CUT** (confirmed) — no 1.21.1 build exists anywhere (doc 03 §6.6). | done |

```bash
node "C:/Game Servers/Minecraft/pack-tools/check-cf-distribution.mjs" "C:/Game Servers/Minecraft/pack-tools/modlist-curseforge.txt"
```
Needs `CF_API_KEY` (free, <https://console.curseforge.com/>). ⚠ Console keys are locked out
of `/v1/mods/search`, so the modlist pins every entry as `slug:projectId` — keep it that way.

---

## Suggested order of operations

1. ✅ **Run the three tests above** — all passed 2026-08-30.
2. ✅ **MODLIST FROZEN — 2026-08-30 (Wesley's call).** Everything downstream depends on
   this. Nothing worldgen-related may change afterwards, ever. The frozen manifest =
   `pack-tools/modlist-curseforge.txt` (65) + `pack-tools/modlist-modrinth.txt` (26).
   *(After the three build-day reopenings — doc 03 §1 — the closed-for-good manifest is
   73 CF + 43 Modrinth active entries.)*
3. ✅ **Pack BUILT — 2026-08-30.** packwiz (CI build, `pack-tools/bin/`, gitignored) →
   98 stubs in `pack/` (dual-listed mods sourced from Modrinth), validated end-to-end:
   `packwiz serve` → `packwiz-installer -s server` → NeoForge boots to `Done`. Five
   landmines found by boot testing, incl. the **Integrated family cut** (freeze
   reopened + reclosed, Wesley's call) and a **Structory Towers version pin** that
   `packwiz update --all` would break. All in `planning/04-PACK-DISTRIBUTION.md §7`.
   Pushed + **LIVE**: <https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml>
   (installer verified against the live URL same day).
4. ✅ **Server BUILT — 2026-08-30.** NeoForge 21.1.249 installed at repo root (runtime is
   gitignored; the ops scripts are committed). Stage-0 vanilla boot `Done (7.577s)` via
   the SYSTEM boot task; full 126-stub modded boot `Done (16.202s)`, fresh world, 0 chunk
   errors. Firewall: allow 25565 only + **explicit BLOCK on RCON 25575** (it binds
   0.0.0.0 — the block rule is the only thing keeping it off the LAN, and setup purged
   10 stray program-scoped java rules incl. two for this very JDK). Backup chain proven
   live: RCON flush → robocopy slot on H: → zip from the quiesced slot. Three defects in
   doc 02's script drafts found+fixed (banner at doc 02 §7). Server syncs mods via
   `update.bat` → packwiz-installer → the live Pages URL.
   → `planning/02-SERVER-BUILD-PLAN.md` (house conventions in `../CLAUDE.md`)
5. **Apply the datapacks + config nerfs.** Deeper and Darker's Resonarium fix is the single
   highest-priority change and must land **before anyone joins**.
   → `planning/03-FINAL-DECISIONS.md §4`
6. **Pregen + splice** (R=3000 today, extend to 6000 overnight).
   → `planning/05-WORLD-SPLICE.md`
7. **Onboard players.** Export a Prism instance zip, drop it in `pack-tools/instance/`,
   and send the group <https://cards.archidicks.com/guides/mc-setup> — the cards site
   renders `pack-tools/PLAYER-SETUP.md` live (auth-gated, edits show immediately) and
   serves the newest zip in `instance/` as its download button. Can run in parallel
   with step 6.

---

## Document map

| File | What it is |
|---|---|
| `planning/03-FINAL-DECISIONS.md` | ⭐ **The decision record. Read this first.** Cuts, adds, tuning jobs, accepted risks. Supersedes doc 00 wherever they disagree. |
| `planning/05-WORLD-SPLICE.md` | The BoP × Terralith hard seam at X=0. Procedure, sizing, phased pregen. |
| `planning/04-PACK-DISTRIBUTION.md` | packwiz → GitHub Pages → Prism. Launcher choice and why. |
| `planning/02-SERVER-BUILD-PLAN.md` | RAM math, JVM flags, install sequence, the four scripts, risk register. |
| `planning/01-BALANCE-PLAYBOOK.md` | Config keys and pastable JSON per mod. 52 fenced blocks. |
| `planning/00-MODLIST-AUDIT.md` | The full audit. 110 mods, parity table, 101-row verdict table. **Its §6/§10 redundancy calls are partly superseded by doc 03.** |
| `pack-tools/PLAYER-SETUP.md` | Player onboarding. Served live at <https://cards.archidicks.com/guides/mc-setup> (auth-gated) — edit the file, page updates. |
| `pack-tools/modlist-*.txt` | 73 CurseForge (pinned `slug:id`) + 43 Modrinth slugs after build day: Integrated family cut → REVERSED same day (Create/Quark/Zeta/Supplementaries now deliberate members); Alex's Caves via unofficial port; doc 02 §5 perf stack; doc 03 §2's dropped ADD table; boot-breaking hidden deps explicit (`curios`, `cupboard`, `integrated-api`, `sizeable-foliage` — Modrinth dep metadata lies). Other libraries still auto-added by packwiz at install. |
| `pack/` | ⭐ **The built packwiz pack** (source of truth for client + server): `pack.toml` (MC 1.21.1, NeoForge 21.1.249) + 125 mod stubs. Boot-verified 2026-08-30 (incl. the reversal roster). Serve locally with `pack-tools/bin/packwiz.exe serve`. |
| `datapacks/` | 6 active datapacks, all `pack_format 48`, all valid JSON. Newest: `confluence-gate-life-crystal` (test-2 verdict, empirically verified). |
| `datapacks/_retired/` | Datapacks retired by later decisions, each with a WHY note. Not deleted. |

⚠ **Docs 00 and 01 use different formulas and different baselines and reach different
numbers for the same mod.** Doc 00 §2 carries a banner explaining the reconciliation. Under
the philosophy change both are triage tools, not tuning targets — do not try to reconcile
individual cells.

---

## Standing constraints — violate these and you lose the world

1. **Java 21, not 23.** `JAVA_HOME` already points at JDK 21, but bare `java` on PATH
   resolves to **23**. NeoForge 1.21.1 targets 21; mismatches look like mod bugs. The launch
   script must use the absolute JDK 21 path.
2. **BoP and Terralith can never be removed** once the world is spliced. Chunk NBT
   references their biome IDs; removing either is data loss, not a recoverable crash.
   Terralith is a *datapack* — it must stay in the world folder too. **Post-reversal,
   the never-remove list also includes: Alex's Caves (5 underground biomes), the
   Integrated family, and Create + Quark + Supplementaries** (zinc veins, Quark biomes/
   structures if left on, wild flax / way signs — all in chunk data once pregen runs).
3. **Record both seeds.** The splice uses a different seed per half. Without them the world
   can never be extended seamlessly.
4. **Never change worldgen mods after generation.** Fragments chunks, and you find out
   40 hours in.
5. **Every `Hours` figure in the audit is estimated, not measured.** Fine as triage; do not
   quote as fact.

---

## Hardware context

i7-14700KF · **64 GB DDR5 @ 5600** (6000 was unstable — dual-rank IMC limit, see the
`server-box-ram-profile` memory) · RTX 3090 · UPS.

⚠ **This box is also Wesley's gaming rig.** He plays on it while hosting. Budget accordingly
— doc 02 derives a **12 GB heap**, not 24. And Minecraft's game loop is single-threaded, so
64 GB fixes memory and does nothing for TPS; entity-heavy mods are the tick budget.
