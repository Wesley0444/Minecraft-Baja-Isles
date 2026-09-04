# bajatiers — per-player mob damage / mob health by Apotheosis World Tier

**Both-sides NeoForge mod (1.21.1 / NeoForge 21.1), ~10 KB.** Since 2.0.0 the numbers are
`tier_augments` registry entries of two new types (`bajatiers:mob_damage`, `bajatiers:mob_health`)
that Placebo syncs to clients and the World Tier detail screen lists under Monster Augments, so the
client needs the codec. packwiz `side = "both"`, jar as a GitHub Release asset.

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

## Where the numbers live
`datapacks/apotheosis-world-tiers/data/baja/tier_augments/<tier>/{mob_damage,mob_health}.json`:
```json
{ "type": "bajatiers:mob_damage", "tier": "ascent", "target": "monsters", "sort_index": 40, "percent": 200 }
```
Percent of vanilla; a tier with no file is 100%. `/reload` applies. `ScalarAugment.apply/remove`
are no-ops — the handler looks the entry up per hit via `TierAugmentRegistry.getAugments`.

`config/bajatiers-common.toml` holds only `log_hits` (INFO line per scaled hit:
`player (tier) takes from|deals to <mob> via <src>: a -> b (pct% -> xM)`). Leave it off.

## Build
`powershell -File build.ps1` — javac against the server's own runtime jars (patched MC +
NeoForge universal + FML + Apotheosis + Placebo), no Gradle. Output `build/bajatiers-<ver>.jar`
+ `.sha1`. Bump `version` in `resources/META-INF/neoforge.mods.toml` for a new build.

## History
- 2.0.0 — 2026-09-04. Both sides. Multipliers moved out of the toml into datapack `tier_augments`
  entries (new types), shown in the World Tier screen. GitHub Release `bajatiers-2.0.0`.
- 1.2.0 — 2026-09-04. Config reworded to `mob_damage` / `mob_health` percents (same math as 1.1.0's
  0.7×…4.5× taken and 1.0×…0.4× dealt; "you do less damage" is a terrible sentence to hand gamers,
  "mobs have more health" is the same number). Old `[damage_taken]`/`[damage_dealt]` sections are
  ignored if left in the toml.
- 1.1.0 — 2026-09-04. Added damage-dealt scaling. Live-verified via hit log 15:05.
- 1.0.0 — 2026-09-04. Rig smoke test (PregenRig2, `smoketest-apoth` world): loads, config
  generated, Done in 3.5 s, zero related errors. In-game hit test pending Wesley.
