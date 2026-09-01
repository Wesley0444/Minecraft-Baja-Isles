# 06 — STEP 5: DATAPACKS + CONFIG NERFS — APPLIED RECORD

**Applied 2026-08-30 (step 5).** This is the record of what actually landed on the live
server, and why. It supersedes doc 01 wherever they disagree — doc 01 was written
pre-freeze against guessed ids and the strict-parity brief; everything here was applied
against **real ids read from the installed jars/configs** and filtered through doc 03 §0
(*"kitchen sink with a side of balance — only fix strong gear that is cheap to obtain"*).

⚠ **`config\` is gitignored.** The datapack half of this pass is committed in
`datapacks\`; the config half exists only on the server disk — **this doc is its
reproducible record.** If a config ever regenerates, restore values from §3.

---

## 0. Corrections to the planning docs (learned by doing)

1. **Doc 02 §3.5's SERVER-config trap does not exist on NeoForge 21.1.** Server-scoped
   configs live globally in `config\*-server.toml`; `world\serverconfig\` is only an
   optional per-world *override* (its readme says so). There is no world-creation copy
   step and nothing to pre-seed in `defaultconfigs\`. Edit `config\`, restart, done.
2. **Paxi force-loads the server-root `datapacks\` folder by default** ("Load from base
   'datapacks' directory", CurseForge compat). That silently loaded our repo source
   folder — including the `structure-collision` tooling shell. **Flipped to `false`** in
   `config\paxi-neoforge-1_21.toml`: the only datapack source is now
   `config\paxi\datapacks\`, populated exclusively by `datapacks\deploy-datapacks.ps1`.
3. **Doc 01's ids were guesses; many were wrong.** Real ids used here (from the jars):
   the D&D Spellbooks addon's mod id is **`darkermagic`** (spells `summoned_warden`,
   `summoned_shattered`, `summoned_sculk_centipede`, `summoned_sculk_snapper`);
   Cataclysm bosses are `the_harbinger`/`the_leviathan`/`scylla` (no `the_` on scylla);
   the D&D staff enchant is `reverberation` (not "volume"); Apotheosis 8.x has **no
   affix blacklist tag** — per-item `affix_loot_entries/` files instead; the
   skeleton-bow blacklist tag ships under dead plural `tags/items/` and must be written
   at singular `tags/item/skeleton_do_not_use.json`.

---

## 1. Datapack changes (committed, deployed via Paxi)

Active set + load order (later overrides earlier):
`confluence-gate-life-crystal → deeperdarker-parity → apotheosis-parity →
simplybows-parity → pack-buffs → pack-balance`. Deploy with
`datapacks\deploy-datapacks.ps1` after ANY datapack edit. `structure-collision\`
is tooling, not a loaded pack. (`pack-buffs` added 2026-08-31 by the doc 09
balance-completion pass — the revived under-reward buff half.)

### deeperdarker-parity
- **`tags/item/resonarium_armor.json` → emptied** (was wrongly listing 3 pieces = 75%
  damage reduction). Empty tag = the shipped `incoming/4`-per-piece immunity bug never
  fires; armor keeps its normal stats. **Tier-0 fix #1.**
- (Pre-existing, unchanged: `reverberation` enchant capped at level 1 — the Sonorous
  Staff scaler; `transmittable` block-tag trim.)

### apotheosis-parity
- `affixes/melee/executing.json` — pre-existing, all world-tier weights 0 (execute
  affix never rolls). **Tier-0 fix #3.**
- **NEW `affixes/melee/attribute/piercing.json`** — armor-pierce halved (mythic max
  12 → 6; shipped values were 2–12 flat pierce vs netherite's 20 armor).
- **NEW `rarities/mythic.json`** — the 1% `minecraft:unbreakable` roll replaced with a
  plain 0.45–0.75 durability-bonus rule (kills the unbreakable-Glass-Sword combo).
- **NEW `affix_loot_entries/twilight/glass_sword.json`** — condition-false shadow;
  Glass Sword no longer affix-eligible (insurance vs unbreakable/durability affixes).
- `affixes/armor/attribute/winged.json` — pre-existing: elytra-flight affix gated to
  summit/pinnacle tiers only.

### pack-balance
- `gateways/gateways/hellish_fortress.json` — pre-existing: Wither Skeleton Spawner
  reward already deleted. **Tier-0 fix #4.**
- **NEW `c/tags/entity_type/bosses.json`** — 28 boss ids (Cataclysm ×9, Mowzie's ×4,
  D&D stalker, Eternal Starlight ×4, Twilight Forest ×9, Aquamirae Cornelia), all
  `required:false`. Apothic Spawners' shipped blacklist honors `#c:bosses` → **bosses
  cannot be spawner-farmed** (doc 03 §4.4).
- **NEW `apothic_spawners/tags/entity_type/blacklisted_from_spawners.json`** — same
  list merged directly (belt + suspenders).
- **NEW `ars_nouveau/tags/entity_type/drygmy_blacklist.json`** — same list; **Drygmys
  cannot passively farm boss drops** (the ÷6 problem's purest case).
- **NEW `skeletonusescustombow/tags/item/skeleton_do_not_use.json`** — endgame bows
  (Cataclysm wrath/cursed, TF triple/seeker/ender/ice, Aether phoenix) blacklisted
  from skeleton use, `required:false`. Day-one insurance per doc 01 §2.20.
- **NEW `minecraft/recipe/trident.json`** — condition-false disable of **Primal's
  craftable trident** (doc 03 §6.4b; deletes the drowned-drop gate). Its notch-apple
  fritter checked and left alone — it *consumes* a real enchanted golden apple.
- **NEW `apothic_attributes/brewing_mixes/flying_from_levitation.json`** — Potion of
  Flying ingredient re-pointed **popped chorus fruit → NETHER STAR**. Flight stays in
  the pack as a real reward (kitchen-sink-friendly) instead of a renewable freebie;
  the long/extra-long extensions still work on an already-brewed bottle.
- **NEW `cataclysm/recipe/` ×6** — `laser_gatling`, `wither_assault_shoulder_weapon`,
  `meat_shredder`, `the_incinerator`, `mech_eye`, `mechanical_fusion_anvil`: **base
  L_Ender's Cataclysm recipes restored**, overriding `integrated_cataclysm`'s
  replacements which hard-gated all six behind Create Mechanical Crafters (no loot
  fallback — verified across every loot table). This enforces doc 03 obligation #3:
  *"Create is an economy track, not a gear gate."* The weapons stay gated by
  witherite/ignitium boss materials. **To re-Create-gate them: delete these 6 files
  and redeploy** (2-minute revert; not worldgen; David gets a vote — see §6).

---

## 2. Structure density (config, pre-pregen — LOCKED at step 6)

`config\sparsestructures.json5` (source of truth committed at
`datapacks\structure-collision\sparsestructures.json5` — **edit there, copy over**):
global `spreadFactor 2.5`, vanilla pinned 1.0, **plus ~75 pins added from the live
`/dumpstructuresets` output (255 sets)** under five rules documented in the file:
other-dimension sets → 1.0 · progression/boss-track sets → 1.0–1.2 · natively-rare
sets → 1.0 (a ×2.5 thin on a finite 12.8k world can starve a set to zero) · headline
raid content (WDA/IDAS/T&T…) → 1.2–1.8 · ambient filler → global 2.5.
**Three sets deliberately left thinned as balance nerfs:** Aether bronze +
silver/gold dungeons (doc 01 §2.18 — farmable Valkyrie Lance density), Eternal
Starlight portal ruins (§2.11 — pre-dragon Gatekeeper ambushes), Apotheosis towers.
`structurify` stays installed but inert (empty config) — fallback surface for
per-structure disables if ever needed.

---

## 3. Config changes — the full key list (NOT in git; this table is the record)

| File | Key | Was → Now | Why (doc ref) |
|---|---|---|---|
| `simplyswords/unique_effects.toml` | `omenInstantKillThreshold` | 0.25 → **0.0** | Omen 75%-per-hit execute below 25% HP, no boss check. Tier-0 #2 (01 §2.7) |
| `simplyswords/weapon_attributes.toml` | `katana/twinblade/cutlass_attackSpeed` | -2.0 → **-2.4** | kills the free +25% DPS over longsword at every tier (01 §2.13) |
| `antarchy/antarchy_tools.toml` | `[ultimateTools] sword/axe/pickaxe/shovel/hoe AttackDamage` | 30/38/22/24/8 → **11/13/8/7/2** | ultimate kit → netherite parity (03 §4.2; hoe was 8dmg @ 4.0 speed = 32 DPS, worst in kit) |
| ″ | `[ultimateArmor] comesEnchanted` | true → **false** | free quad-Protection-at-cap auto-enchant — the single highest-leverage line (03 §4.2) |
| ″ | `[ultimateArmor] helmet/chest/leggings/boots Armor` | 4/9/7/4 → **3/8/6/3** | netherite parity (toughness already 3.0/pc, KB 0.1/pc) |
| ″ | `[ultimateBow] attackDamage` | 18 → **8** | vanilla bow ≈ 6; same cheap-ore kit |
| `antarchy/antarchy_misc.toml` | `duplicatorTreeEnabled` | true → **false** | AFK-able block duplication incl. netherite (03 §4.2). Big Bertha untouched (boss-drop-gated, verified); Battle Axe rides the nerfed ultimate components; minersDream left ON (group likes automation — same call as keeping Apothic Spawners) |
| `apotheosis/apotheosis.cfg` | `Curse Boss Items` | false → **true** | mod's own "less overpowered bosses" switch (01 §2.5). Upgrade/Reroll costs and Manual World Tiers left at default — see §5 |
| `twilightforest-common.toml` | `disableUncrafting` | false → **true** | pack-wide recipe-graph reversal + documented dupe bugs; special uncrafting recipes survive (01 §2.10) |
| ″ | `multiplayerFightAdjuster` | NONE → **MORE_HEALTH** | +20 hearts per nearby player; NOT more loot (÷6) |
| `bettercombat/server.json5` | `reworked_sweeping_extra_target_count` | 4 → **2** | 3–5× crowd-DPS compression of every wave mod (01 §2.19) |
| ″ | `server_target_range_validation` | false → **true** | server validates claimed hits |
| ″ | `dual_wielding_off_hand_damage_multiplier` | 1.0 → **0.6** | off-hand dagger stacking |
| `minecolonies-server.toml` | `maxcitizenpercolony` / `forceloadcolony` | 250/true → **40/false** | worst tick cost on the list + documented ticket leak (02 §1c) |
| `guardvillagers-common.toml` | `Range` / guards-per-village | 50→**24** / 6→**3** | every-tick radius scan per guard (02 §1c) |
| `irons_spellbooks-server.toml` | `maxUpgrades` | 3 → **2** | best global power dial (01 §2.9) |
| ″ | `manaRegenMultiplier` | 1.0 → **0.7** | mana as a real resource |
| ″ | `additionalWanderingTraderTrades` | true → **false** | hour-one shortcut into magic gear |
| ″ | `scrollMerging` | true → **false** | junk-scroll laundering |
| ″ | `priestHouseWeight` | 4 → **0** | documented TPS collapse (#795/#833) |
| ″ | Tyros / Dead King `additionalHealth` | 0 → **+500 / +250** | 1000/500 HP bosses vs 6 players (assumes 3–4 present; tune after first kill) |
| `irons_spellbooks_spell_config/irons_spellbooks/` | `angel_wings.json` NEW | maxlvl 2 · cd 400s · power 0.6 | uptime > cooldown = permanent flight, Rule-3 deletion (01 §2.9) |
| ″ | `portal.json` / `recall.json` NEW | min_rarity **legendary** | Waystones is the pack's teleport economy |
| ″ | `summon_ender_chest.json` NEW | min_rarity **epic** | guts backpack economies |
| `irons_spellbooks_spell_config/darkermagic/` | `summoned_shattered/_sculk_centipede/_sculk_snapper.json` NEW | allow_crafting false · min_rarity legendary | D&D spells override `requiresLearning()`, skipping Iron's Eldritch gate (01 §2.1 d3) |
| ″ | `summoned_warden.json` NEW | power 0.5 · cd 600s | ~416HP/38dmg pet with permanent uptime (01 §2.1 d4) |
| `ars_nouveau-common.toml` | `spawnBook` / `spawnTomes` | true → **false** | free entry item / pre-made tomes in WDA loot (01 §2.14) |
| ″ | `drygmyUniqueBonus` / `ManaCost` / `MaxProgress` | 2/1000/20 → **0/3000/40** | passive mob-drop farming rate (01 §2.14) |
| `ars_nouveau-server.toml` | `enableWarpPortals` | true → **false** | pure overlap with Waystones — pick one (01 §2.14) |
| `ars_n_spells-server.toml` | `mana_unification_mode` | iss_primary → **separate** | stops the two magic tracks collapsing into one pool (03 §3) |
| ″ | `source_jar_synergy_multiplier` | 5.0 → **1.0** | automatable Ars source fed Iron's mana gate (03 §3) |
| `deeperdarker-common.toml` | `soulElytraCooldown` | 600 → **-1** | free rocket-less elytra boost off |
| ″ | `snapperDropLimit` | 8 → **1** | enchanted-book faucet feeding Apotheosis |
| `simplybows/config.toml` | `[loot] string/frame/uniqueBow/boostedBow chances` | 20/20/2/15 → **5/5/0.5/2** | maxed ranged kit in 10–25h from chests (01 §2.7) |
| ″ | `damageMultiplierPerFrame` | 0.55 → **0.25** | ″ |
| ″ | `enableNonPlayerBowUse` | true → **false** | 3-mod compounding: homing echo arrows at hour 3 |
| ″ | `[echoBow] painExplosion Base/Frame/MaxRatio` | 0.16/0.06/0.55 → **0.05/0.02/0.25** | **confirmed %-of-max-HP damage** — melts 600HP bosses (doc 01's 🔍 flag verified true) |
| ″ | `chaosBlackHolePullStrength` | 0.09 → **0.03** | ″ |
| `primal-common.toml` | 5× `*ModelChange` + 3× `*IncreasesHealth` | true → **false** | Naturalist wins the shared vanilla mobs (03 §3) |
| ″ | all 22 `*ExtraBiomes` | [] → **populated** | BoP+Terralith ids so the spliced world gets Primal wildlife/flora (03 §6.4a). Animal lists are runtime-tunable; FLORA lists bake at pregen |
| `epicknights/armor.json5` | `knockbackResistance` all plate sets | 0.5/pc → **0.1**; stechhelm+jousting 1.5 → **0.0** | 2 pieces = 100% KB immunity at hour 2, a mechanic deletion (01 §2.16). Defense values left alone (~diamond-tier = not egregious) |
| `alexscaves-general.toml` | `sugar_rush_slows_time` | true → **false** | hour-2 candy = server-side slow-mo tick bubble; the +70% speed part survives (§4 skim) |
| `paxi-neoforge-1_21.toml` | `Load from base 'datapacks' directory` | true → **false** | see §0.2 |

---

## 4. Alex's Caves gear skim — DONE (doc 03 §1 obligation closed)

Verdict: **the port's own progression does the balancing** — every AC biome is
tablet-gated (witch hut/mansion/jungle temple/bastion/ruins/suspicious sand), ~2000
blocks apart, and most AC weapon DPS is *below* the Sharp-V netherite baseline. Raygun
≈10 DPS ranged sidegrade; Hazmat = biome-key immunity at *worse-than-iron* armor;
Resistor Shield/Extinction Spear/Cloak of Darkness all boss-gated. **One nerf applied**
(Sugar Rush tick-slow, table above). **Watch list** (levers on file, no action):
**Dreadbow** (i-frame-bypassing 30-arrow volley — expensive-but-strong today; kill
switch = datapack override of `data/alexscaves/recipe/dreadbow.json`, its only
acquisition path) · **Totem of Possession works on PLAYERS** in this build
(`totem_of_possession_works_on_players`, left on — trusted friends, but know the
switch) · **nuclear bomb** (griefing tool; social rule, config levers exist).

## 5. Considered and deliberately SKIPPED (do not re-litigate without cause)

- **All doc 01 buffs** (Cataclysm Void Forge, TF Fiery Sword, Undergarden, Eternal
  Starlight, Gateways emerald_grove) — doc 03 §0.2 dropped the under-reward half.
- **Apothic Spawners caps/silk-touch** — kept as-is per doc 03 §5 (Wesley: farms are a
  feature). Only the `#c:bosses` fence was added.
- **Gateways lives/spacing/AFK rules** — same spirit; the spawner *reward* was the
  actual defect and is already gone.
- **Apotheosis `Upgrade Level Cost` 225→50** — doc 01's argument was "the only
  affordable path is spawner farms", but spawner farms are now an accepted feature;
  cutting the cost is a net power buff. Left at default.
- **`Enable Manual World Tier Changes` → false** — the config's own comment warns
  tiers then never advance without custom automation. Trap; left true.
- **Epic Knights defense trim / steel Nether-gate; Undergarden catalyst Nether-gate**
  — not egregious under §0 (≈diamond parity, netherite-parity-without-Nether). KB
  immunity was the real defect and is fixed.
- **Simply Entity Equipment** — kept as shipped (34 elite-mob entries, +150–478% HP).
  Armor never drops, uniques only drop on 2 low-tier entries, and with
  `enableNonPlayerBowUse=false` its bow skeletons fire plain shots. It's hard-mode
  spice, same acceptance class as spawners. First suspect if cave trash feels unfair.
- **Mowzie's/Naturalist spawn weights** — no config surface (data-driven); global
  tuning deferred to the 6-player soak (doc 02 stage 9). ServerCore + sim-distance 6
  are the active guards. **In Control! stays out** (would reopen the freeze).
- **Aquamirae** (doc 01 §5 #34 audit): skimmed — saber/fang bonuses cap at +1.5–2,
  Cornelia 300HP, all deep-frozen-ocean-gated. Fine as-is.
- **Quark worldgen module (the step-5/6 BLOCKER — DECIDED): all 17 world modules stay
  ON** (defaults). Kitchen-sink call; none are gear; permanence already accepted since
  Quark is on the never-remove list either way. Wesley can trim modules in
  `quark-common.toml [world]` any time **before pregen**, not after.

## 6. OPEN — needs Wesley (not blockers for step 6)

1. **Apotheosis Pinnacle weld** (doc 01 §5 #17): welding the Pinnacle world tier to a
   Cataclysm boss kill is high-value but is serial gating — doc 01's own caveat says
   pick framing (a) merged track or (b) any-capstone-counts, and disclose in the Track
   Menu *before* anyone picks. Not applied. Decide before onboarding (step 7).
2. **Create-gate reversal option** (§1): if David preferred the Create-gated Cataclysm
   super-weapons, delete `pack-balance/data/cataclysm/recipe/*` + redeploy.
3. **Track Menu / House Rules paste** (doc 01 §4): death rule is now settled
   (GraveStone), but rules 5–7 (unequal hours, PvP-on, shared gear chest) still need
   Wesley's edit + Discord post at step 7.
4. **Ship stat-driving configs in the packwiz pack** (step 7, found during the in-game
   verify): add `config/antarchy/*.toml`, `config/epicknights/*.json5`,
   `config/simplyswords/*.toml` (+ any other config whose values bake into item
   stats/tooltips) to `pack/` so clients bake the same numbers — kills the lying
   tooltips and the creative-menu pre-enchanted-item quirk. **Client-facing pack
   change → requires the client-launch smoke test** per the house rule.

## 7. Verification (2026-08-30)

- Fresh-world boot with all changes: **Done (22.308s)**, zero new errors (all ERROR
  lines = pre-existing known noise: IDAS ice-and-fire loot refs, IDAS spawner-list
  parse, shieldexp absent-mod recipe, darkermagic's own `whispers_staff` tag typo).
- `/datapack list`: all 5 balance packs enabled `(paxi)`.
- Malformed-file canary: shieldexp's broken recipe DID log a parse error; our
  condition-false files (trident, glass_sword) logged nothing = parsed + honored.
- Configs re-serialized by the server with our values intact (Epic Knights KB,
  Better Combat, Antarchy).
- Second boot after Paxi base-dir fix + spacing pins: exactly the 5 balance packs
  enabled `(paxi)`, `structure-collision` no longer loaded, zero parse errors from the
  pinned `sparsestructures.json5`. Both stops graceful via RCON; server left DOWN.

### In-game checklist — ✅ RUN BY WESLEY 2026-08-30, ALL PASS
Results: (1) Resonarium `/damage` hit landed at full force — immunity dead;
(2) Ultimate Chestplate = **8.0 armor server-side** via `/attribute` (see the
client-tooltip caveat below); (3) no trident recipe in JEI; (4) Epic Knights knight
chest+legs = **0.2 knockback resistance** (was 1.0 = immune); (5) Potion of Flying
shows nether star; (6) laser gatling = plain crafting grid + witherite (base
Cataclysm recipe, still boss-gated).

⚠ **Client-config caveat found during the test:** mods that bake item stats from
config at startup (Antarchy, Epic Knights, Simply Swords…) render TOOLTIPS from the
**client's own default config**, and creative-menu grabs fabricate stacks from client
defaults too (Wesley pulled a pre-enchanted 9-armor Ultimate Chestplate that the
server can no longer craft). Gameplay math is server-authoritative and correct;
tooltips lie until the configs ship to clients. **Fix queued as §6 item 4.**

The original checklist, for re-runs:
1. **Resonarium** (the big one): wear full Resonarium set, `/damage @s 20 minecraft:generic`
   → health MUST drop.
2. Craft/give an Antarchy Ultimate Chestplate → must be UNenchanted, 8 armor.
3. `/give @s minecraft:trident` recipe check: JEI shows **no** trident recipe.
4. Epic Knights: 2 pieces of steel plate → `/attribute @s minecraft:generic.knockback_resistance get`
   → **0.2**, not 1.0.
5. JEI: Potion of Flying uses = nether star. Cataclysm laser gatling recipe = plain
   crafting table (not Mechanical Crafter).
6. Simply Swords Omen warglaive vs 600HP dummy → no instant kill below 25%.
