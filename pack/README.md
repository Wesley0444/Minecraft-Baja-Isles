# Minecraft 1.21.1 NeoForge — pack definition

**This repo contains no mod jars.** It contains packwiz TOML pointers (project id, file id,
hash, side). That is what makes it safe to make public: it redistributes nothing.

Setup, rationale and the update workflow: `../planning/04-PACK-DISTRIBUTION.md`
Player onboarding doc to hand out: `../pack-tools/PLAYER-SETUP.md`

## ✅ BUILT 2026-08-30 — 98 stubs, boot-verified

Bootstrapped with packwiz (CI build in `../pack-tools/bin/`, gitignored). MC 1.21.1,
NeoForge 21.1.249. Dual-listed mods sourced from **Modrinth**; the rest pinned CF ids.
Validated end-to-end: `packwiz serve` → `packwiz-installer -g -s server` → NeoForge
boots to `Done` on a fresh world. The five landmines the build hit (hidden deps,
CF-blocked dep, broken "neoforge" jar, the Integrated family cut) are documented in
`../planning/04-PACK-DISTRIBUTION.md §7` — **read that before changing anything here.**

## ⚠ Version pins — do NOT `packwiz update --all` blindly

- **structory-towers** is pinned to v1.0.15 (version-id `lefqbuOP`). Newer builds target
  the next MC line and crash 1.21.1 ("Missing ModLoader in file"). Re-pin after any bulk
  update.

## `side` status

`client`: Xaero's ×3, Jade, JEI — the server never sees them.
**Deliberate deviation:** `simply-tooltips` stays `both` even though it looks client-only —
Simply Bows + Simply Swords declare it a *required* dep, and a `client` mark would strip
it from the server install and risk a boot refusal. Candidates never flipped (unverified,
left `both` on purpose): `visual-health`, `loot-journal-neoforge`, `block-pack`.

To change a side: edit `mods/<mod>.pw.toml` → `side = "both" | "client" | "server"`,
then `packwiz refresh`.
