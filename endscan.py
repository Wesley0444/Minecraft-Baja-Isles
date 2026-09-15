"""
endscan.py -- prove which End-island geometry is on disk, without a player.

usage:  python endscan.py <path-to-DIM1\\region>  [--radius 120]

Reads the Anvil region files around 0,0, counts OBSIDIAN blocks per (x,z) column, and buckets
the columns by horizontal distance from 0,0.  Vanilla places its 10 obsidian spikes at radius
exactly 42; YUNG's Better End Island places its 10 pillars at radius 54 (heights 76-105).  So:
    vanilla42 > 0  and bei54 == 0   -> vanilla island (or BEI added without a regen: BOTH sets)
    vanilla42 == 0 and bei54 >= 8   -> BEI island
Also lists the non-end-stone palette within 20 blocks of 0,0 (BEI's central tower: bells,
bedrock, chiseled/purpur blocks) so a regen with BEI active is visibly different from vanilla.

Last line is machine-readable:  RESULT vanilla42=<n> bei54=<n> obsidian_columns=<n> tower_blocks=<n>
Run it against region files that have been SAVED (save-all [flush]) -- it reads disk, not RAM.
"""
import gzip, math, os, struct, sys, zlib, collections

def parse(b, i, t):
    if t == 0: return None, i
    if t == 1: return b[i], i + 1
    if t == 2: return struct.unpack(">h", b[i:i+2])[0], i + 2
    if t == 3: return struct.unpack(">i", b[i:i+4])[0], i + 4
    if t == 4: return struct.unpack(">q", b[i:i+8])[0], i + 8
    if t == 5: return struct.unpack(">f", b[i:i+4])[0], i + 4
    if t == 6: return struct.unpack(">d", b[i:i+8])[0], i + 8
    if t == 7:
        n = struct.unpack(">i", b[i:i+4])[0]; return b[i+4:i+4+n], i + 4 + n
    if t == 8:
        n = struct.unpack(">H", b[i:i+2])[0]; return b[i+2:i+2+n].decode("utf-8", "replace"), i + 2 + n
    if t == 9:
        et = b[i]; n = struct.unpack(">i", b[i+1:i+5])[0]; i += 5; out = []
        for _ in range(n):
            v, i = parse(b, i, et); out.append(v)
        return out, i
    if t == 10:
        out = {}
        while True:
            tt = b[i]; i += 1
            if tt == 0: return out, i
            n = struct.unpack(">H", b[i:i+2])[0]; name = b[i+2:i+2+n].decode("utf-8", "replace"); i += 2 + n
            v, i = parse(b, i, tt); out[name] = v
    if t == 11:
        n = struct.unpack(">i", b[i:i+4])[0]; return list(struct.unpack(">%di" % n, b[i+4:i+4+4*n])), i + 4 + 4 * n
    if t == 12:
        n = struct.unpack(">i", b[i:i+4])[0]; return list(struct.unpack(">%dq" % n, b[i+4:i+4+8*n])), i + 4 + 8 * n
    raise ValueError("tag %d" % t)

def read_chunk(mca, cx, cz):
    """chunk NBT root for local chunk (cx, cz) in an open region file, or None."""
    idx = 4 * ((cx & 31) + (cz & 31) * 32)
    mca.seek(idx); off = mca.read(4)
    if len(off) < 4: return None
    sector = (off[0] << 16) | (off[1] << 8) | off[2]
    if sector == 0: return None
    mca.seek(sector * 4096); ln = struct.unpack(">i", mca.read(4))[0]; comp = mca.read(1)[0]; raw = mca.read(ln - 1)
    if comp == 1: data = gzip.decompress(raw)
    elif comp == 2: data = zlib.decompress(raw)
    elif comp == 3: data = raw
    else: return None
    root, _ = parse(data, 3 + struct.unpack(">H", data[1:3])[0], 10)
    return root

def section_blocks(sec):
    """yield (x, y, z, name) for every non-air block in a 1.18+ section."""
    bs = sec.get("block_states")
    if not bs: return
    pal = [p["Name"] for p in bs.get("palette", [])]
    data = bs.get("data")
    y0 = sec["Y"] * 16
    if not data:
        if pal and pal[0] != "minecraft:air":
            for i in range(4096):
                yield i & 15, y0 + (i >> 8), (i >> 4) & 15, pal[0]
        return
    bits = max(4, (len(pal) - 1).bit_length())
    per = 64 // bits; mask = (1 << bits) - 1
    i = 0
    for word in data:
        w = word & 0xFFFFFFFFFFFFFFFF
        for _ in range(per):
            if i >= 4096: break
            name = pal[w & mask]
            if name != "minecraft:air":
                yield i & 15, y0 + (i >> 8), (i >> 4) & 15, name
            w >>= bits; i += 1

def main():
    region = sys.argv[1]
    radius = 120
    if "--radius" in sys.argv: radius = int(sys.argv[sys.argv.index("--radius") + 1])
    cr = radius // 16 + 1
    obs = collections.Counter()      # (x,z) -> obsidian count
    tower = collections.Counter()    # block name -> count within 20 blocks of 0,0, non end stone/air
    files = {}
    for cz in range(-cr, cr + 1):
        for cx in range(-cr, cr + 1):
            rx, rz = cx >> 5, cz >> 5
            p = os.path.join(region, "r.%d.%d.mca" % (rx, rz))
            if not os.path.exists(p): continue
            if p not in files: files[p] = open(p, "rb")
            root = read_chunk(files[p], cx, cz)
            if not root: continue
            for sec in root.get("sections", []):
                for x, y, z, name in section_blocks(sec):
                    wx, wz = cx * 16 + x, cz * 16 + z
                    if name == "minecraft:obsidian":
                        obs[(wx, wz)] += 1
                    if abs(wx) <= 20 and abs(wz) <= 20 and name not in ("minecraft:end_stone", "minecraft:air", "minecraft:cave_air", "minecraft:void_air"):
                        tower[name] += 1
    buckets = collections.Counter()
    for (x, z), n in obs.items():
        buckets[int(round(math.hypot(x, z)))] += 1
    print("obsidian columns by radius (r: columns):")
    for r in sorted(buckets):
        print("  %3d: %d" % (r, buckets[r]))
    print("non-end-stone blocks within 20 of 0,0:", dict(tower.most_common(12)))
    v42 = sum(n for r, n in buckets.items() if 40 <= r <= 44)
    b54 = sum(n for r, n in buckets.items() if 50 <= r <= 58)
    print("RESULT vanilla42=%d bei54=%d obsidian_columns=%d tower_blocks=%d" % (v42, b54, sum(buckets.values()), sum(tower.values())))

if __name__ == "__main__":
    main()
