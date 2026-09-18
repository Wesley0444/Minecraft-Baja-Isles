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

- **gravestone-x-curios-api-compat** + **baguettelib** are pinned by omission — neither
  `.pw.toml` carries an `[update]` block. The compat mixes into Curios *internals*
  (`top.theillusivec4.curios.common.inventory.CurioStacksHandler`, not the API) and both of its
  mixins are `required: true`, so a version pair that drifts apart is a **hard boot crash**, not
  a warning. Verified as a set against **curios 9.5.1**, **gravestone 1.0.40** and
  **baguettelib 2.0.6** (every mixin target and cross-mod signature resolved by javap against the
  jars we actually run, 2026-09-08). Move any one of the four only after re-checking all four.
- **Iris = `1.8.14-beta.1` (Sodium 0.8 build), 2026-09-09.** Iris is version-locked to Sodium:
  every *release* Iris for 1.21.1 (newest 1.8.12) hard-requires Sodium **0.6.13**, the exact
  version the Supplementaries ban killed. The June-2026 beta is the ONLY Iris that runs on the
  Sodium 0.8.x we ship, and it declares no Sodium version bound at all — so a `packwiz update`
  that ever offers a "newer" release for 1.21.1 must be checked against its Sodium requirement
  first. Client-only, **optional (default off)**: the installer asks each person once; potato
  PCs say no and never load it.
- **EMF 3.3.5 + ETF 7.2.1 move as a SET (2026-09-15).** Same author, and ETF 7.1's changelog says
  EMF must update alongside it; EMF 3.3.0 shipped a one-day 1.21.1 crash fixed in 3.3.1. Both
  stubs keep their `[update]` blocks, so `packwiz update` CAN move them — only ever bump both
  together, and only to a pair whose changelogs mention each other. Client-only, so a bad pair
  breaks clients, not the server.

## `side` status

`client`: Xaero's minimap + world map, Jade, Sodium, LambDynamicLights — the server never
sees them. Also `client`: Iris (optional), the `shaderpacks/` stub, Entity Model Features,
Entity Texture Features and the Boss Refreshed stub under `config/paxi/resourcepacks/`.
`server`: Savage Ender Dragon and YUNG's Better End Island (2026-09-15) — no registries, no
payloads; a client without them joins fine.
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

- **2026-09-18 — Baja Tiers 2.0.0 → 2.1.0 (both sides). Version bump of our own mod, not a
  reopening: no mod added or removed.** Tier math, codec and datapack unchanged. The jar now also
  carries `VisitorStyleGuardMixin`, a client crash guard for MineColonies 1.1.1368: `VisitorCitizen
  .aiStep()` copies the colony view's texture style into the visitor's synced data with no null
  check, and a null there kills the rendering client in `AbstractEntityCitizen.getTexture`
  ("Rendering entity in world", NPE `"s" is null`). Hit Wesley 2026-09-15 (waystone into the colony)
  and Dan 2026-09-18 (nether portal beside the Tavern); upstream PR ldtteam/minecolonies#11828 was
  closed unmerged. The mixin drops the null write. It is **non-required on purpose** (`@Pseudo`,
  config `required:false`, `require = 0`): a MineColonies update that moves the call degrades to
  "no guard", never to a boot crash — and every launch logs **`VisitorStyleGuard=APPLIED`** or
  `NOT APPLIED` (client and server) so that is never silent. **Moving the MineColonies pin ⇒ grep a
  rig boot for that line first.** Stub = `[download]` on GitHub Release `bajatiers-2.1.0`, no
  `[update]` block. A 2.1.0 client joins a 2.0.0 server fine (no payloads, registry codec
  unchanged), so no server bounce was needed; the server picks the jar up at its next sync. Source
  + the full write-up: `mods-src/bajatiers/README.md` ("The passenger").
- **2026-09-15 — Savage Ender Dragon + YUNG's Better End Island (server only), EMF + ETF +
  Boss Refreshed (client only) ADDED. Modlist reopening #7 (David's batch).**
  `mods/savage-ender-dragon.pw.toml` = CurseForge file **6828602** (`dragonfight-1.21-4.7.jar`) —
  the *NeoForge* build; the 4.8 file David linked is Fabric-only and no NeoForge 4.8 exists.
  Server-side (Cupboard dep already shipped); soft mixins on `EnderDragon.hurt`/crystals only, so
  it coexists with Confluence's `aiStep` dragon mixin (both applied clean on PregenRig2). Known
  open upstream bug #72: its HP bonus is a transient modifier, a dragon that unloads re-heals.
  Config `config/dragonfight.json` (defaults: `dragonDifficulty` 2, `antiflightAbility` true —
  flying >35 s below 90 % dragon HP = blindness, forced descent, 90 %-max-HP fall damage; hits
  wings/Aether/Ars/elytra alike). `mods/yungs-better-end-island.pw.toml` = Modrinth 3.1.2, server
  only, `required:true` mixins on `EndDragonFight`/`SpikeFeature`/`ServerLevel`. **The End was
  regenerated for it** (`armed-endboss.ps1`): nobody had ever entered, so the vanilla-baked
  `DIM1` region/entities/poi were parked on H: and Chunky re-baked r=1000 with BEI active —
  pillars at radius 54, no vanilla ring at 42 (`endscan.py` proves it from the region files).
  **Done 2026-09-15 17:01:** 16,129 End chunks in 64 s, scan `vanilla42=0 / bei54=716` (rig
  reference 0 / 717), server back as SYSTEM in 6.2 s, all 7 tag checks green. ⚠ BEI's first boot on
  a world that predates it logs one benign ERROR (`key missing: bei_ExtraDragonFight` + the whole
  level.dat on a single 2.9 MB line) — it writes the key on the next save; never regex that line.
  **Boss Refreshed** is a CEM *model* pack (dragon, wither, warden, elder guardian) and needs
  **Entity Model Features 3.3.5 + Entity Texture Features 7.2.1** on every client, both
  `side="client"`. Its stub lives in `config/paxi/resourcepacks/` so packwiz drops the zip where
  Paxi force-loads it (installer-verified 2026-09-15) — nobody has to enable it by hand. Licence is
  All Rights Reserved but CurseForge/Modrinth third-party distribution is allowed, so a by-hash
  stub is fine; never unzip it into this repo. Server side: 2 jars + the `baja-tag-compat`
  datapack (Confluence prefixes on Simply Swords / Simply Bows / EK bows etc., EK shields
  enchantable). Clients without EMF/ETF can still join; they just see vanilla bosses.
- **2026-09-09 — Iris (optional, default OFF) + Complementary Reimagined r5.9 ADDED, client only.**
  Modlist reopening #6. Shaders for the group on the same pack, opt-in per person. `mods/iris.pw.toml`
  carries `[option] optional = true, default = false` — the packwiz installer asks once and remembers;
  say no on a weak PC and Iris is never loaded (not "loaded but off"). `shaderpacks/complementary-reimagined
  .pw.toml` drops the 540 KB zip for everyone (harmless without Iris). `config/iris.properties` ships
  `enableShaders=false` + `shaderPack=ComplementaryReimagined_r5.9.zip` with **`preserve = true`** in
  the index, so it installs once and a re-sync never flips someone's shader choice back. Why
  Complementary: one pack with a Potato→Ultra profile ladder (same files, different budget), the
  largest modded-block emissive list of any shader, Modrinth-hosted, modpack-friendly license.
  ⚠ Iris is a BETA (see pins) and it is the same Sodium+outline family as the 2026-09-05 GeckoLib
  glow crash (Iris #2866) — expect that crash to get *more* likely, not less, for people who opt in.
  Alex's Caves has its own post-processing; some cave effects will look wrong under any shader.
  Server side: nothing (both stubs `client`), no bounce.

- **2026-09-01 — Block Pack (`bf_blockpack`) REMOVED.** Collided with ~70 vanilla recipes.
- **2026-09-03 — Naturalist REMOVED.** 12.4% of the server thread for ambient animals
  (bass 6.2%, bird 4.7%, butterfly 2.2%); nothing depends on it; its only worldgen was two
  ant-hill features. Bass are vanilla-cost fish — the saving is that they spawned in swamps
  and wetlands where vanilla puts none; birds/butterflies were genuinely pricier than the bats
  that replace them (bats did not register in the profile at all).
- **2026-09-03 — Alex's Caves swapped for the `ac-nomagnet` patched build** (see pins above).
- **2026-09-04 — Baja Tiers (`bajatiers`) ADDED, both sides.** Our own ~10 KB mod, source in
  `mods-src/bajatiers/`, jar as a GitHub Release asset (`[download] url=` stub, no `[update]`
  block). World Tiers become a per-player difficulty dial: mob damage 50/100/150/225/300% and
  effective mob health 100/120/150/180/225% by the PLAYER's tier (retuned 2026-09-05 from
  70/100/200/300/450 and 100/118/143/182/250 after a Rare invader one-shot at Ascent), plus XP -40/0/+35/+55/+100%
  (`datapacks/apotheosis-world-tiers`, the single source of truth). Needs the client because the
  numbers are `tier_augments` registry entries of a new type, synced by Placebo and listed in the
  World Tier screen under Monster Augments. No worldgen, no Minecraft registries.

- **2026-09-08 — Gravestone x Curios API Compat + BaguetteLib ADDED, both sides.** Fixes
  "the grave hands your accessories back as loose inventory junk". Our Gravestone jar contains
  **zero** Curios code, so every one of this pack's ~19 curios slot types (Cataclysm, Ars Nouveau,
  Ars Elemental, Awakened, Iron's Spellbooks, Confluence, plus Curios' own 10) had to be
  re-equipped by hand after every death. The addon tags each equipped/cosmetic curio at death with
  its `(slotType, slotIndex, cosmetic)` as a data component, then restores it to that exact slot
  when the grave is broken — with a delayed second pass for curios that *grant* slots, so a belt
  is equipped before the pouches it unlocks. Overflow falls back to inventory, then the floor.
  Honours Curios' own `keepCurios`; has an item blacklist + a Curse-of-Binding toggle.
  **Swapping to Corpse was considered and rejected:** Corpse does not restore curios either (same
  author, same shared `corelib`) — the fix is the addon, and its author ships the identical one
  for both mods from one codebase (the Gravestone build's classes are still in package
  `com.leclowndu93150.corpsecurioscompat`). Staying on Gravestone means the **52 graves already
  in the world keep working** instead of being deleted with the block id. Client-facing because
  BaguetteLib registers into the synced `DATA_COMPONENT_TYPE` registry. Graves that already exist
  restore the old way — their items were never tagged — so no regression, and it self-heals from
  the next death onward.
