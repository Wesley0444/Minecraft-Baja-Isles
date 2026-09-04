# apotheosis-modded-loot

Puts **Simply Swords** (diamond + netherite base weapons) and **Epic Knights**
(diamond + netherite weapons/shields, longbow/heavy crossbow, and the iron-,
diamond- and top-band armor sets) into Apotheosis's **affix loot drop pool**.

Built 2026-09-03 from a player ask ("add Epic Knights / Simply Swords to the
Apotheosis affix config"). Both mods' gear was *already affix-capable* (reforging,
sockets, `/apoth loot_category` says so); only the drop pool was vanilla-only.

* **Generated** by `build.py` -- edit the tables there, rerun, redeploy. Do not
  hand-edit `data/`.
* **Weights** follow one rule: a modded family's combined weight per slot equals
  ONE vanilla analog at that tier (see the docstring). 133 entries; modded share of
  the pool ends up ~22% frontier / 38% ascent / 42% summit / 30% pinnacle.
* **Excluded on purpose**: Simply Bows (loot chances were nerfed 4-40x in the
  balance pass), Simply Swords uniques/runic (own loot track), Epic Knights
  steel/silver/bronze tiers (no iron-plus rung in the pool).
* **Namespace** `baja` -- entries are `baja:simplyswords/<item>` /
  `baja:magistuarmory/<item>`; Apotheosis scans every namespace for
  `affix_loot_entries/`. Each file carries a `neoforge:mod_loaded` condition.
* **Verify on the server**: `/apoth debug weights affix_loot_entries`.
