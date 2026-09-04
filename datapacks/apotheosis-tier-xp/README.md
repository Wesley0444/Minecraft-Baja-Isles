# apotheosis-tier-xp

Re-anchors the World Tier XP ladder (Wesley's 2026-09-04 table): Haven costs XP, Frontier is
neutral, the upper tiers pay a little less than stock. Files override `data/apotheosis/tier_augments/<tier>/experience.json`
from Apotheosis 8.7.0 (Paxi datapack, hot-loads with `/reload`).

| Tier     | Stock  | Baja   | How |
|----------|--------|--------|-----|
| Haven    | +0%    | -40%   | new file |
| Frontier | +35%   | +0%    | stock file overridden with a `neoforge:false` condition (entry skipped) |
| Ascent   | +55%   | +35%   | override |
| Summit   | +75%   | +55%   | override |
| Pinnacle | +125%  | +100%  | override |

Damage taken / dealt per tier is NOT done here — that is the `bajatiers` server-side mod
(scales incoming damage by the VICTIM's tier, so it stays per-player in mixed groups).
Do not add `generic.attack_damage` monster augments on top: they would double-dip.
The shipped armor / armor-pierce / prot-pierce monster ladder is left as-is.
