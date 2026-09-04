#!/usr/bin/env python3
"""
build.py -- generate the apotheosis-modded-loot datapack.

WHAT:  writes one `apotheosis:affix_loot_entry` JSON per item under
       data/baja/affix_loot_entries/<mod>/<item>.json so Simply Swords and
       Epic Knights gear can DROP as Apotheosis affix loot (chests, bosses,
       gateways).  Being *affix-capable* (reforging, sockets) never needed
       this -- Apotheosis 8.x resolves the loot category from the item
       class, and every weapon/armor in both mods extends the vanilla
       classes.  Only the DROP POOL was vanilla-only.

WEIGHTS -- the budget rule (keep it when you edit the tables):
       Apotheosis's own pool (50 entries) puts each vanilla piece at
         haven    stone/leather 25 · chainmail 10 · golden 5
         frontier iron 25 (q1) · chainmail 10 · golden 10
         ascent   diamond 25 · iron 10 · golden 5
         summit   diamond 25 · iron 10 · netherite 5 (q1)
         pinnacle netherite 25 (q2) · diamond 5
       Every modded FAMILY here (e.g. "the 15 Simply Swords diamond
       weapons", "the 4 Epic Knights diamond-band chestplates") gets a
       COMBINED weight roughly equal to ONE vanilla analog at that tier,
       split evenly across its members (integer, min 1).  Result: no
       modded item is ever likelier than the vanilla piece it mirrors,
       and the pool's material ladder is unchanged.

DELIBERATELY EXCLUDED (planning/06 §, planning/09 §1.5):
       * Simply Bows -- its 8 bows are loot-only and the balance pass cut
         their chest chances 20/20/2/15 -> 5/5/0.5/2 on purpose.  Putting
         them in this pool would re-open that faucet.  They reforge fine.
       * Simply Swords uniques/runic -- they have their own loot track
         (tablets, pity counter); affix loot on top is the ATM combo the
         balance pass explicitly avoided.  Reforge-capable regardless.
       * Epic Knights steel/silver/bronze/tin/copper tiers -- steel is the
         mod's real mid-game (pre-Nether), but the pool has no "iron-plus"
         rung; adding steel next to iron at frontier is the overpay
         direction doc 03 forbids.  Diamond + netherite only.

RUN:   python build.py        (from this folder; rewrites data/ from scratch)
       then  deploy-datapacks.ps1 (parent folder)  and a /reload or restart.
VERIFY on the running server (server truth, no client):
       /apoth debug weights affix_loot_entries   -- modded ids in the dump
       /apoth loot_category                      -- with a modded item held
"""
import json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'data', 'baja', 'affix_loot_entries')

SS = 'simplyswords'
EK = 'magistuarmory'   # Epic Knights' real namespace

SS_TYPES = ['chakram', 'claymore', 'cutlass', 'glaive', 'greataxe', 'greathammer',
            'halberd', 'katana', 'longsword', 'rapier', 'sai', 'scythe', 'spear',
            'twinblade', 'warglaive']                                        # 15
EK_WEAPONS = ['ahlspiess', 'bastardsword', 'chainmorgenstern', 'chivalrylance',
              'claymore', 'concavehalberd', 'estoc', 'flamebladedsword', 'guisarme',
              'heavymace', 'heavywarhammer', 'katzbalger', 'lochaberaxe',
              'lucernhammer', 'morgenstern', 'pike', 'ranseur', 'shortsword',
              'stylet', 'zweihander']                                        # 20
EK_SHIELDS = ['buckler', 'ellipticalshield', 'heatershield', 'kiteshield', 'pavese',
              'rondache', 'roundshield', 'target', 'tartsche']                # 9

# (tier, weight, quality) helpers
def W(**tiers):
    """tiers: haven=(w,q) ... ; q omitted => 0."""
    out = {}
    for t, v in tiers.items():
        w, q = (v if isinstance(v, tuple) else (v, 0))
        out[t] = {'weight': int(w)} if not q else {'weight': int(w), 'quality': float(q)}
    return out

# ---------------------------------------------------------------- tables
# Each row: (mod, item_id, weights)
ENTRIES = []

# Simply Swords base weapons. diamond family (15) ~ diamond_sword 25 @ asc/sum.
# netherite family (15) ~ netherite_sword 25 @ pinnacle (q2). No summit leak.
for t in SS_TYPES:
    ENTRIES.append((SS, f'diamond_{t}',   W(ascent=2, summit=2)))
    ENTRIES.append((SS, f'netherite_{t}', W(pinnacle=(2, 2.0))))

# Epic Knights weapons. 20 per material -> 1 each (=20 ~ 25).
for t in EK_WEAPONS:
    ENTRIES.append((EK, f'diamond_{t}',   W(ascent=1, summit=1)))
    ENTRIES.append((EK, f'netherite_{t}', W(pinnacle=(1, 2.0))))

# Epic Knights shields. vanilla shield = 10 (q1) at every tier; 9 per material.
for s in EK_SHIELDS:
    ENTRIES.append((EK, f'diamond_{s}',   W(ascent=(1, 1.0), summit=(1, 1.0))))
    ENTRIES.append((EK, f'netherite_{s}', W(pinnacle=(1, 2.0))))

# Epic Knights ranged (one material each). vanilla bow 15 / crossbow 10, all tiers.
ENTRIES.append((EK, 'longbow',        W(haven=(5, 1.0), frontier=(5, 1.0), ascent=(5, 1.0), summit=(5, 1.0), pinnacle=(5, 1.0))))
ENTRIES.append((EK, 'heavy_crossbow', W(haven=(4, 1.0), frontier=(4, 1.0), ascent=(4, 1.0), summit=(4, 1.0), pinnacle=(4, 1.0))))

# Epic Knights armor -- bands from config/epicknights/armor.json5 (defense/toughness):
#   iron band    (def <= vanilla iron 2/6/5/2, tough <= 0.6)   ~ iron:    frontier 25 q1 · asc 10 · sum 10
#   diamond band (8/5/2 + 3 helm, tough 1.25, kb 0.1)          ~ diamond: asc 25 · sum 25 · pin 5
#   top band     (maximilian 4/9/6/3 t1.8 · jousting 9/6/3 t2 · stechhelm 4 t2)
#                diamond-plus defense, below netherite toughness -> sits between the two.
IRON_BAND = {
    'chest':  ['crusader_chestplate', 'platemail_chestplate', 'cuirassier_chestplate',
               'wingedhussar_chestplate', 'halfarmor_chestplate', 'lamellar_chestplate'],   # 6
    'helmet': ['greathelm', 'kettlehat', 'barbute', 'norman_helmet', 'shishak',
               'cuirassier_helmet'],                                                       # 6
    'legs':   ['crusader_leggings', 'platemail_leggings', 'cuirassier_leggings'],           # 3
    'boots':  ['crusader_boots', 'platemail_boots', 'cuirassier_boots', 'lamellar_boots'],  # 4
}
DIAMOND_BAND = {
    'chest':  ['knight_chestplate', 'gothic_chestplate', 'kastenbrust_chestplate', 'xivcenturyknight_chestplate'],
    'helmet': ['armet', 'sallet', 'grand_bascinet', 'bascinet'],
    'legs':   ['knight_leggings', 'gothic_leggings', 'kastenbrust_leggings', 'xivcenturyknight_leggings'],
    'boots':  ['knight_boots', 'gothic_boots', 'kastenbrust_boots', 'xivcenturyknight_boots'],
}
TOP_BAND = {
    'chest':  ['maximilian_chestplate', 'jousting_chestplate'],
    'helmet': ['maximilian_helmet', 'stechhelm'],
    'legs':   ['maximilian_leggings', 'jousting_leggings'],
    'boots':  ['maximilian_boots', 'jousting_boots'],
}

def split(total, n, floor=1):
    return max(floor, round(total / n))

for slot, items in IRON_BAND.items():
    n = len(items)
    for it in items:
        ENTRIES.append((EK, it, W(frontier=(split(25, n), 1.0), ascent=split(10, n), summit=split(10, n))))
for slot, items in DIAMOND_BAND.items():
    n = len(items)
    for it in items:
        ENTRIES.append((EK, it, W(ascent=split(25, n), summit=split(25, n), pinnacle=split(5, n))))
for slot, items in TOP_BAND.items():
    n = len(items)
    for it in items:
        # between diamond (asc 25/sum 25/pin 5) and netherite (sum 5/pin 25):
        # family total asc 5 · sum 15 (q1) · pin 10 (q1)
        ENTRIES.append((EK, it, W(ascent=split(5, n), summit=(split(15, n), 1.0), pinnacle=(split(10, n), 1.0))))

# ---------------------------------------------------------------- emit
def main():
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    seen = set()
    for mod, item, weights in ENTRIES:
        key = (mod, item)
        if key in seen:
            sys.exit(f'duplicate entry {mod}:{item}')
        seen.add(key)
        d = os.path.join(OUT, mod)
        os.makedirs(d, exist_ok=True)
        doc = {
            'type': 'apotheosis:affix_loot_entry',
            'neoforge:conditions': [{'type': 'neoforge:mod_loaded', 'modid': mod}],
            'stack': {'id': f'{mod}:{item}', 'count': 1},
            'weights': weights,
        }
        with open(os.path.join(d, item + '.json'), 'w', encoding='utf-8', newline='\n') as f:   # no BOM
            json.dump(doc, f, indent=4)
            f.write('\n')
    # per-tier totals, for the record
    tiers = ['haven', 'frontier', 'ascent', 'summit', 'pinnacle']
    tot = {t: 0 for t in tiers}
    per = {}
    for mod, item, w in ENTRIES:
        for t, v in w.items():
            tot[t] += v['weight']
            per.setdefault(mod, {t: 0 for t in tiers})[t] += v['weight']
    print(f'{len(ENTRIES)} entries written to {OUT}')
    print('added weight per tier  :', ' '.join(f'{t}={tot[t]}' for t in tiers))
    for mod, m in per.items():
        print(f'  {mod:14s}:', ' '.join(f'{t}={m[t]}' for t in tiers))
    print('vanilla pool per tier  : haven=322 frontier=362 ascent=367 summit=369 pinnacle=289  (50 entries, see README)')

if __name__ == '__main__':
    main()
