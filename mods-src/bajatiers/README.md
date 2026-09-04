# bajatiers — per-player mob damage / mob health by Apotheosis World Tier

**Server-side only NeoForge mod (1.21.1 / NeoForge 21.1).** No registries, no network
payloads, so clients that don't have it join fine (the Chunky mechanism). Ship it with
`side = "server"` in packwiz; never add it to client instances.

## Why not a `tier_augments` datapack on `generic.attack_damage`?
Apotheosis bakes **monster** augments into a mob at spawn from the **nearest player's**
tier, permanently (`AdventureEvents.applyMissedTierAugments`, jar-verified 8.7.0). In a
mixed-tier group the Ascent player's mobs hit the Haven player for Ascent damage. Also
`attack_damage` only covers melee that reads the attribute — arrows, creepers, blazes,
witches are untouched.

This mod scales on the **player's side** instead, on `LivingIncomingDamageEvent`, but the config
is written from the mob's side of the ledger so it reads like the announcement:

- `mob_damage` (percent): victim is a real `ServerPlayer`, attacker (`DamageSource#getEntity`, the
  owner for projectiles) is a non-player `LivingEntity` → `damage *= pct/100`.
- `mob_health` (percent, *effective*): attacker is a real `ServerPlayer`, victim is any non-player
  `LivingEntity` → `damage *= 100/pct`. 143% health == your hits land at 70%. Health bars still
  show the vanilla number; the mob just takes that many more hits.

Fall / lava / drowning / starvation / PvP are deliberately untouched. Runs before armor, enchants
and absorption, so it stacks multiplicatively with the shipped per-tier pierce ladder.

**Do not also add attack_damage monster augments — they would double-dip.**

## Config — `config/bajatiers-common.toml` (hot-reloads, no restart)
| Tier | mob_damage | mob_health |
|---|---|---|
| haven | 70 | 100 |
| frontier | 100 | 118 |
| ascent | 200 | 143 |
| summit | 300 | 182 |
| pinnacle | 450 | 250 |

`log_hits = true` logs every scaled hit at INFO (`player (tier) takes from|deals to <mob> via <src>:
a -> b (pct% -> xM)`) — the way to prove it live: get tapped by a zombie on Haven, switch to Ascent,
get tapped again, read `logs/latest.log`. Turn it back off after.

## Build
`powershell -File build.ps1` — javac against the server's own runtime jars (patched MC +
NeoForge universal + FML + Apotheosis + Placebo), no Gradle. Output `build/bajatiers-<ver>.jar`
+ `.sha1`. Bump `version` in `resources/META-INF/neoforge.mods.toml` for a new build.

## History
- 1.2.0 — 2026-09-04. Config reworded to `mob_damage` / `mob_health` percents (same math as 1.1.0's
  0.7×…4.5× taken and 1.0×…0.4× dealt; "you do less damage" is a terrible sentence to hand gamers,
  "mobs have more health" is the same number). Old `[damage_taken]`/`[damage_dealt]` sections are
  ignored if left in the toml.
- 1.1.0 — 2026-09-04. Added damage-dealt scaling. Live-verified via hit log 15:05.
- 1.0.0 — 2026-09-04. Rig smoke test (PregenRig2, `smoketest-apoth` world): loads, config
  generated, Done in 3.5 s, zero related errors. In-game hit test pending Wesley.
