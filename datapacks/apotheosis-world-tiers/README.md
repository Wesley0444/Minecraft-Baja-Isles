# apotheosis-world-tiers

World Tiers as a per-player difficulty dial. Paxi datapack, hot-loads with `/reload`.
Overrides `data/apotheosis/tier_augments/<tier>/experience.json` (Apotheosis 8.7.0) and adds
`data/baja/tier_augments/<tier>/{mob_damage,mob_health}.json`, whose types come from the
`bajatiers` mod (both sides). **This folder is the single source of truth for the numbers** —
the mod reads them from the registry at hit time and the World Tier screen lists them under
Monster Augments. A tier with no file = 100% (unchanged), so those files are simply omitted.

| Tier     | Mob damage | Mob health (effective) | XP     | XP stock |
|----------|-----------:|-----------------------:|-------:|---------:|
| Haven    | 70%        | 100%                   | -40%   | +0%      |
| Frontier | 100%       | 118%                   | +0%    | +35% (stock file overridden with a `neoforge:false` condition = entry skipped) |
| Ascent   | 200%       | 143%                   | +35%   | +55%     |
| Summit   | 300%       | 182%                   | +55%   | +75%     |
| Pinnacle | 450%       | 250%                   | +100%  | +125%    |

Semantics (see `mods-src/bajatiers`): mob_damage multiplies damage a player takes from a
non-player living attacker (+ its arrows/explosions/spells) by `pct/100`, keyed off the VICTIM's
tier. mob_health divides damage a player deals to any non-player living target by `pct/100`,
keyed off the ATTACKER's tier — effective health; health bars still show vanilla. Fall/lava/PvP
untouched. Do NOT add `generic.attack_damage` monster augments on top (double-dip). The shipped
armor / armor-pierce / prot-pierce / toughness monster ladder is left as-is.
