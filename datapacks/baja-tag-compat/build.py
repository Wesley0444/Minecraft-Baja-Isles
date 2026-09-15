"""
baja-tag-compat -- generator.  Run:  python build.py   (from this folder; reads the server's
mods/ jars), then deploy-datapacks.ps1.  Never hand-edit data/ -- edit the lists below and rerun.
The generated JSON is committed so the result is reviewable and does not depend on the jars at
deploy time.

WHAT / WHY (2026-09-15, David's batch):
  1. Confluence's prefix (reforge) system is pure item tags, not config:
       confluence:prefix_melee_only  = #minecraft:swords/axes/pickaxes/shovels/hoes + mace
       confluence:prefix_ranged_only = #c:tools/ranged_weapon + trident + #terra_guns:gun
     MELEE gap (rig-proven 2026-09-15: simplyswords:iron_longsword failed the tag test):
       Simply Swords tags its 178 weapons into the legacy `c:swords`, never `minecraft:swords`;
       Mowzie's spear sits only in `c:tools/spear`; Alex's Caves' non-sword weapons only in
       `minecraft:weapons`; Eternal Starlight's scythes/hammers/spears in its own tags.  Epic
       Knights (227), Cataclysm, Aether, Iron's, Aquamirae, TF, DD, Undergarden, Antarchy already
       use `minecraft:swords` and need nothing.  This script RESOLVES the real tag graph from the
       jars and emits, explicitly, every candidate melee item that is not already covered.
     RANGED gap: NeoForge seeds `c:tools/ranged_weapon` with ONLY the vanilla bow/crossbow/trident.
       Simply Bows, EK longbow + heavy crossbow, TF's 4 bows, Mowzie's blowgun, Cataclysm's cursed
       bow and AC's dreadbow ship no entry, so they could never roll Unreal/Deadly/etc.
     Foreign MAGIC items are deliberately NOT tagged: Confluence magic prefixes mutate its own
     mana-cost math, which Iron's/Ars never read.  Confluence's own items are never touched.
  2. Epic Knights' 49 shields extend vanilla ShieldItem (Apotheosis affixes already work) but EK
     ships ZERO tag entries for them.  Every shield enchant in the pack targets `#c:tools/shield`
     (Apothic reflective_defenses / shield_bash, Ars Elemental mirror_shield) and Unbreaking/
     Mending need `#minecraft:enchantable/durability`, so EK shields could take no enchantment.
  Every entry is `required = false`: if a mod ever leaves the pack the tag still loads.
  Tags merge across datapacks (replace = false); item tags sync to clients: server-only change.
"""
import json, os, re, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MODS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mods")
FORMAT = 48

# ---------------------------------------------------------------- ranged (hand-listed) ----
SIMPLY_BOWS = [f"simplybows:{n}_bow/{n}_bow" for n in
               ("vine", "ice", "bubble", "bee", "blossom", "earth", "echo", "cosmic")]
TF_BOWS = [f"twilightforest:{n}_bow" for n in ("triple", "seeker", "ice", "ender")]
BOWS = SIMPLY_BOWS + TF_BOWS + ["magistuarmory:longbow", "alexscaves:dreadbow", "cataclysm:cursed_bow"]
CROSSBOWS = ["magistuarmory:heavy_crossbow"]
OTHER_RANGED = ["mowziesmobs:blowgun"]

# ---------------------------------------------------------------- shields (hand-listed) ---
EK_MATERIALS = ("wood", "stone", "copper", "tin", "bronze", "iron", "silver", "steel",
                "gold", "diamond", "netherite")
EK_TYPES = ("ellipticalshield", "heatershield", "kiteshield", "roundshield")
EK_SHIELDS = ([f"magistuarmory:{m}_{t}" for m in EK_MATERIALS for t in EK_TYPES]
              + [f"magistuarmory:{t}" for t in EK_TYPES]
              + ["magistuarmory:corruptedroundshield"])
assert len(EK_SHIELDS) == 49, len(EK_SHIELDS)

# ---------------------------------------------------------------- melee (resolved) --------
# Tags whose members are melee weapons by their own mod's declaration.  Anything in these that
# the resolved confluence:prefix_melee_only does not already contain gets added explicitly.
MELEE_SOURCE_TAGS = [
    "c:swords",                    # Simply Swords (all 178 registered weapons), Antarchy
    "c:tools/spear",               # Mowzie's spear, Cataclysm coral spear, Eternal Starlight spears
    "mowziesmobs:hand_weapons",    # earthrend gauntlet
    "eternal_starlight:scythes", "eternal_starlight:hammers", "eternal_starlight:greatswords",
]
# NOT used as sources, on purpose: `simplyswords:swords` (451 ids, mostly Mythic Metals compat
# items that are never registered here) and `minecraft:weapons` (Alex's Caves lumps its raygun,
# conch, sea staff, resistor shield and totem in there -- none of them melee).
MELEE_EXTRA = ["alexscaves:primitive_club"]
# never add these, whatever the source tags say
MELEE_EXCLUDE_NS = ("confluence", "terra_entity", "terra_curio", "terra_guns", "minecraft")
MELEE_EXCLUDE_TAGS = ["confluence:prefix_ranged_only", "confluence:unable_to_apply_prefix",
                      "confluence:prefix_magic_only", "confluence:prefix_universal_only"]

def load_all_item_tags():
    """tag id -> list of raw entries (strings, '#tag' refs, or {id,required} objects), merged
    across every jar exactly as the game merges them (replace=true is honoured)."""
    tags = {}
    pat = re.compile(r"data/([^/]+)/tags/item/(.+)\.json$")
    jars = sorted(f for f in os.listdir(MODS) if f.endswith(".jar"))
    # vanilla + neoforge data live in libraries, not mods
    lib = os.path.join(os.path.dirname(MODS), "libraries")
    for root, _, files in os.walk(lib):
        for f in files:
            if (f.endswith("-extra.jar") and "minecraft/server" in root.replace(os.sep, "/")) or \
               (f.endswith("-universal.jar") and "neoforged/neoforge" in root.replace(os.sep, "/")):
                jars.append(os.path.join(root, f))
    for j in jars:
        p = j if os.path.isabs(j) else os.path.join(MODS, j)
        try:
            z = zipfile.ZipFile(p)
        except zipfile.BadZipFile:
            continue
        for n in z.namelist():
            m = pat.match(n)
            if not m:
                continue
            try:
                d = json.loads(z.read(n).decode("utf-8-sig"))
            except Exception:
                continue
            tid = f"{m.group(1)}:{m.group(2)}"
            if d.get("replace"):
                tags[tid] = []
            tags.setdefault(tid, []).extend(d.get("values", []))
    return tags

def resolve(tags, tid, seen=None):
    seen = seen or set()
    if tid in seen:
        return set()
    seen.add(tid)
    out = set()
    for v in tags.get(tid, []):
        ent = v if isinstance(v, str) else v.get("id", "")
        if ent.startswith("#"):
            out |= resolve(tags, ent[1:], seen)
        elif ent:
            out.add(ent)
    return out

def melee_additions():
    tags = load_all_item_tags()
    have = resolve(tags, "confluence:prefix_melee_only")
    excluded = set()
    for t in MELEE_EXCLUDE_TAGS:
        excluded |= resolve(tags, t)
    cands = set()
    for t in MELEE_SOURCE_TAGS:
        got = resolve(tags, t)
        print(f"  source {t}: {len(got)} items")
        cands |= got
    cands |= set(MELEE_EXTRA)
    add = sorted(i for i in cands
                 if i not in have and i not in excluded
                 and i.split(":", 1)[0] not in MELEE_EXCLUDE_NS)
    by_ns = {}
    for i in add:
        by_ns.setdefault(i.split(":", 1)[0], 0)
        by_ns[i.split(":", 1)[0]] += 1
    print(f"  prefix_melee_only already covers {len(have)} items; adding {len(add)}: {by_ns}")
    return add

def write(rel, obj):
    p = os.path.join(HERE, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:   # BOM-less, LF
        json.dump(obj, f, indent=2)
        f.write("\n")

if __name__ == "__main__":
    print("resolving melee candidates from", MODS)
    melee = melee_additions()
    TAGS = {
        "data/c/tags/item/tools/ranged_weapon.json": BOWS + CROSSBOWS + OTHER_RANGED,
        "data/c/tags/item/tools/bow.json": BOWS,
        "data/c/tags/item/tools/crossbow.json": CROSSBOWS,
        "data/c/tags/item/tools/shield.json": EK_SHIELDS,
        "data/minecraft/tags/item/enchantable/durability.json": EK_SHIELDS,
        "data/confluence/tags/item/prefix_melee_only.json": melee,
    }
    write("pack.mcmeta", {"pack": {"pack_format": FORMAT, "description":
          "Baja tag compat: modded melee/ranged weapons into Confluence's prefix tags; "
          "Epic Knights shields into c:tools/shield + enchantable/durability. 1.21.1."}})
    for rel, ids in TAGS.items():
        write(rel, {"replace": False, "values": [{"id": i, "required": False} for i in ids]})
        print(f"{rel}: {len(ids)} entries")
    print("OK")
