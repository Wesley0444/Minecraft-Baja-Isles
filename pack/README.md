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

- **alexs-caves-unofficial-port** is no longer sourced from CurseForge. It is a locally
  patched build — `alexscaves-2.0.10-nomagnet.jar`, sha1 `c25c483598a3d3f98f9cd94e07ed8bf1b10eaf8d`
  — served from this repo's GitHub Release **`ac-nomagnet-2.0.10`** (patch source + rationale
  there). The three per-entity magnet block scans in `MagnetUtil` return empty: they cost
  **~19% of the server thread** at 4 players (spark `p6VYeVzLLm`, 2026-09-02) on a world
  where nobody was near a magnet. Magnets no longer pull/attach; everything else in AC is
  untouched. Its `.pw.toml` deliberately has **no `[update]` block**, so `packwiz update`
  cannot revert it to the CF build. If upstream ever fixes it, re-apply or drop the patch
  consciously — never by bulk update.

## `side` status

`client`: Xaero's minimap + world map, Jade, Sodium, LambDynamicLights — the server never
sees them.
**NOT client: JEI** — flipped to `both` 2026-09-01. JEI 19.51 no longer reads the
vanilla-synced recipe manager: with no server-side JEI to push recipes, `JeiStarter` falls back to
`VanillaClientRecipeLoader` (rebuilds from the *client's own jars*) and then calls
`RecipeManager.replaceRecipes` on the client. Result: JEI showed **mod-default** recipes and every
`pack-balance` / `pack-buffs` datapack override was invisible, the vanilla recipe book was wrong
too, and the recipe-transfer **+** button was dead (`jei.tooltip.error.recipe.transfer.no.server`).
Symptom is a chat warning on join, not a crash — which is why this hid longer than `w2w2` below.
Server-side JEI adds no content; cheat mode stays gated to creative/op.
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

## Post-freeze modlist changes

- **2026-09-01 — Block Pack (`bf_blockpack`) REMOVED.** Collided with ~70 vanilla recipes.
- **2026-09-03 — Naturalist REMOVED.** 12.4% of the server thread for ambient animals
  (bass 6.2%, bird 4.7%, butterfly 2.2%); nothing depends on it; its only worldgen was two
  ant-hill features. Bass are vanilla-cost fish — the saving is that they spawned in swamps
  and wetlands where vanilla puts none; birds/butterflies were genuinely pricier than the bats
  that replace them (bats did not register in the profile at all).
- **2026-09-03 — Alex's Caves swapped for the `ac-nomagnet` patched build** (see pins above).
- **2026-09-04 — Baja Tiers (`bajatiers`) ADDED, both sides.** Our own ~10 KB mod, source in
  `mods-src/bajatiers/`, jar as a GitHub Release asset (`[download] url=` stub, no `[update]`
  block). World Tiers become a per-player difficulty dial: mob damage 70/100/200/300/450% and
  effective mob health 100/118/143/182/250% by the PLAYER's tier, plus XP -40/0/+35/+55/+100%
  (`datapacks/apotheosis-world-tiers`, the single source of truth). Needs the client because the
  numbers are `tier_augments` registry entries of a new type, synced by Placebo and listed in the
  World Tier screen under Monster Augments. No worldgen, no Minecraft registries.
