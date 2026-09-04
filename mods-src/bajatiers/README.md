# bajatiers — per-player mob damage by Apotheosis World Tier

**Server-side only NeoForge mod (1.21.1 / NeoForge 21.1).** No registries, no network
payloads, so clients that don't have it join fine (the Chunky mechanism). Ship it with
`side = "server"` in packwiz; never add it to client instances.

## Why not a `tier_augments` datapack on `generic.attack_damage`?
Apotheosis bakes **monster** augments into a mob at spawn from the **nearest player's**
tier, permanently (`AdventureEvents.applyMissedTierAugments`, jar-verified 8.7.0). In a
mixed-tier group the Ascent player's mobs hit the Haven player for Ascent damage. Also
`attack_damage` only covers melee that reads the attribute — arrows, creepers, blazes,
witches are untouched.

This mod scales on the **receiving end** instead: `LivingIncomingDamageEvent`, victim is a
real `ServerPlayer`, attacker (`DamageSource#getEntity`, the owner for projectiles) is a
non-player `LivingEntity` → multiply by the victim's tier factor. Fall / lava / drowning /
starvation / PvP are deliberately untouched. Runs before armor, enchants and absorption, so
it stacks multiplicatively with the shipped per-tier armor-pierce / prot-pierce ladder.

**Do not also add attack_damage monster augments — they would double-dip.**

## Config — `config/bajatiers-common.toml` (hot-reloads, no restart)
| Tier | default |
|---|---|
| haven | 0.7 |
| frontier | 1.0 |
| ascent | 2.0 |
| summit | 3.0 |
| pinnacle | 4.5 |

`log_hits = true` logs every scaled hit at INFO (`player (tier) hit by <mob> via <src>: a -> b (xM)`)
— the way to prove it live: get tapped by a zombie on Haven, switch to Ascent, get tapped
again, read `logs/latest.log`. Turn it back off after.

## Build
`powershell -File build.ps1` — javac against the server's own runtime jars (patched MC +
NeoForge universal + FML + Apotheosis + Placebo), no Gradle. Output `build/bajatiers-<ver>.jar`
+ `.sha1`. Bump `version` in `resources/META-INF/neoforge.mods.toml` for a new build.

## History
- 1.0.0 — 2026-09-04. Rig smoke test (PregenRig2, `smoketest-apoth` world): loads, config
  generated, Done in 3.5 s, zero related errors. In-game hit test pending Wesley.
