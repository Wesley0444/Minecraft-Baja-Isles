# Minecraft 1.21.1 NeoForge — pack definition

**This repo contains no mod jars.** It contains packwiz TOML pointers (project id, file id,
hash, side). That is what makes it safe to make public: it redistributes nothing.

Setup, rationale and the update workflow: `../planning/04-PACK-DISTRIBUTION.md`
Player onboarding doc to hand out: `../pack-tools/PLAYER-SETUP.md`

## ✅ BUILT 2026-08-30 — 125 stubs, boot-verified

Bootstrapped with packwiz (CI build in `../pack-tools/bin/`, gitignored). MC 1.21.1,
NeoForge 21.1.249. Dual-listed mods sourced from **Modrinth**; the rest pinned CF ids.
Validated end-to-end: `packwiz serve` → `packwiz-installer -g -s server` → NeoForge
boots to `Done` on a fresh world. The five landmines the build hit (hidden deps,
CF-blocked dep, broken "neoforge" jar, the Integrated family cut) are documented in
`../planning/04-PACK-DISTRIBUTION.md §7` — **read that before changing anything here.**

Grew 98 → **125** later the same day, at server build (126 briefly, then the resurrected
`lendercataclysm` dupe stub was re-removed; every addition rode one fresh-world smoke
boot, `Done (16.202s)`, 0 chunk errors):
- **doc 02 §5 server perf stack** (11): lithium, spark, chunky, fastsuite,
  alternate-current, noisium, servercore, paxi = `side=server`; modernfix, ferrite-core,
  clumps = `both`.
- **Alex's Caves** via Raguto's unofficial 1.21.1 port + his Citadel port (Wesley's call;
  balance skim pending at step 5).
- **doc 03 §2's dropped ADD table** (5): gravestone-mod, combat-roll, shield-expansion,
  lootr, sparsestructures (original, `server` side — not the CF "Reforged" fork).
- **The Integrated family reversal** (doc 03 §1): idas + integrated
  cataclysm/stronghold/villages + their Loot Integrations addon, with **Create, Quark,
  Zeta, Supplementaries as deliberate members**.

## ⚠ Version pins — do NOT `packwiz update --all` blindly

- **structory-towers** is pinned to v1.0.15 (version-id `lefqbuOP`). Newer builds target
  the next MC line and crash 1.21.1 ("Missing ModLoader in file"). Re-pin after any bulk
  update.
- **minecolonies** is pinned to the 1.1.1368 STABLE release (CF file-id `8562588`) —
  stay on the stable channel, never snapshots, for a months-long world.
- **waystones** is pinned to 21.1.27 + **balm** 21.0.65 (Modrinth version-id `xMz5Hial`):
  Confluence 1.2.4's Waystones-integration client mixin targets a method newer Waystones
  refactored away → mixin apply fails → mod construction aborts → every client crashes
  before the title screen, **with a crash report that falsely blames Minecolonies**
  (its sound handler trips on the never-loaded configs first). Found in the 2026-08-30
  join test. Confluence 1.2.4 is its newest build; re-check this pairing whenever
  Confluence updates. **A client launch is part of the smoke test for any client-facing
  mod bump — server boots cannot catch client-GUI mixin failures.**

## `side` status

`client`: Xaero's minimap + world map, Jade, JEI — the server never sees them.
**NOT client: the Xaero's↔Waystones bridge (`w2w2`)** — it registers a required network
channel, so a client-side mark makes every join fail with a misleading "Incompatible
client! Please use NeoForge 21.1.249". Found+fixed in the 2026-08-30 join test; it is
`both` now and must stay that way.
**Deliberate deviation:** `simply-tooltips` stays `both` even though it looks client-only —
Simply Bows + Simply Swords declare it a *required* dep, and a `client` mark would strip
it from the server install and risk a boot refusal. Candidates never flipped (unverified,
left `both` on purpose): `visual-health`, `loot-journal-neoforge`, `block-pack`.

To change a side: edit `mods/<mod>.pw.toml` → `side = "both" | "client" | "server"`,
then `packwiz refresh`.
