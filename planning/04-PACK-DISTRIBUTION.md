# 04 — LAUNCHER & MODPACK DISTRIBUTION

**Written 2026-08-30.** The problem: six people must run a byte-identical ~130-mod pack,
and it will change often (config nerfs, cuts, a mod that turns out to crash). Manual zip
distribution dies on the second update.

---

## 1. RECOMMENDATION

> **packwiz** (pack definition, git-versioned) → hosted on **GitHub Pages** →
> **Prism Launcher** on each player's PC, with `packwiz-installer` as a pre-launch hook.

Players install **once**. After that, every launch silently syncs them to whatever is in
the repo. You push a config change at 2am; they get it next time they click Play. No
"did everyone update?", no version-mismatch disconnects, no zip on Discord.

The server reads the **same** `pack.toml`, so client and server can never drift.

### Why this and not the alternatives

| Option | Verdict |
|---|---|
| **packwiz + Prism** | ✅ **Chosen.** Handles CurseForge *and* Modrinth in one pack (this pack needs both). Git-versioned TOML → real diffs, real rollback. Auto-update on launch. Same source of truth drives the server. One-time setup cost per player. |
| **CurseForge App** | ❌ Cannot install Modrinth-only mods, and a large fraction of this pack is Modrinth-native. Updating a private pack means re-exporting and re-sharing a zip every time. Its one advantage — see §3. |
| **Modrinth App** | ❌ `.mrpack` can only *reference* Modrinth files; CurseForge mods must be physically embedded in `overrides/`, which means you are redistributing other people's jars. Same manual re-share problem on every update. |
| **Manual zip / Dropbox** | ❌ Works exactly once. By update three someone is running a stale pack and crashing the server, and you cannot tell who. |
| **ATLauncher** | 🟡 Supports packwiz natively, so it is a fine fallback for anyone who hates Prism. Not the default because Prism's instance-export flow is cleaner for onboarding. |

---

## 2. HOW IT WORKS

**Your side (once):**
1. `C:\Game Servers\Minecraft\pack\` is a git repo containing `pack.toml`, `index.toml`,
   and a `mods/*.pw.toml` metadata stub per mod (name, side, project/file IDs, hash).
   **No jars are stored** — just pointers.
2. Push to GitHub, serve via GitHub Pages → `https://<user>.github.io/<repo>/pack.toml`.

**Player side (once):** import a Prism instance you export for them. It already contains
the modloader, the Java setting, and this pre-launch command:

```
"$INST_JAVA" -jar packwiz-installer-bootstrap.jar https://<user>.github.io/<repo>/pack.toml
```

**Player side (forever after):** click Play. The hook diffs their `mods/` against the
manifest, downloads what changed, deletes what you removed, and launches.

**Server side:**

```
java -jar packwiz-installer-bootstrap.jar -g -s server https://<user>.github.io/<repo>/pack.toml
```

`-g` disables the GUI, `-s server` installs only mods marked `server` or `both` — so
client-only mods (Xaero's, Jade, Simply Tooltips, the resource packs) never touch the
server. Wire this into `update.bat` and the server self-syncs on restart.

> **Set the `side` field on every mod as you add it.** It is the difference between a
> clean server and one carrying 30 pointless client mods into its tick loop.

---

## 3. ⚠ THE ONE REAL LANDMINE — CurseForge third-party distribution

CurseForge lets an author toggle off third-party distribution. When they do, the API
returns **no download URL**, and packwiz/Prism simply cannot fetch that mod. The failure
is ugly and arrives on the *player's* machine, not yours.

**This will affect some mods in a ~130-mod pack. Find out before onboarding anyone, not during.**

- `tools/check-cf-distribution.mjs` (written, see §5) checks every CF mod in the list and
  reports which ones are blocked. Needs a free CurseForge API key.
- For each blocked mod, pick one:
  1. **Drop it** if it isn't load-bearing. Cheapest fix by far.
  2. **Find it on Modrinth** — many authors dual-publish and only blocked CF.
  3. **Manual sideload** — players download that jar themselves once and drop it in.
     packwiz can carry a note. Annoying but legal.
- ❌ **Do NOT self-host the blocked jar** to "fix" it. That is redistributing against the
  author's explicit opt-out, on a public GitHub Pages site with your name on it. The
  entire reason the flag exists is to say no.

*(This is the CurseForge App's one genuine advantage — as a first-party client it can
download blocked mods. Not enough to outweigh losing every Modrinth mod.)*

---

## 4. JAVA — pin it, don't inherit it

This box has **both** JDK 21 and JDK 23 installed:

- `JAVA_HOME` → `C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\` ✅
- bare `java` on PATH → **JDK 23** ⚠
- also present: `C:\Program Files\Eclipse Adoptium\jre-21.0.4.7-hotspot`

**NeoForge 1.21.1 targets Java 21 LTS.** Java 23 often works and then mysteriously does
not — mixin failures that look like mod conflicts. Do not spend a night bisecting mods
over a JVM version.

- **Server:** launch script must call the **absolute JDK 21 path**, never bare `java`.
- **Players:** set Java explicitly per-instance in Prism (it auto-detects, but verify).

---

## 5. WHAT IS ALREADY BUILT vs WHAT NEEDS YOU

**Built (no input needed):**
- `pack/` skeleton + `.gitignore`
- `tools/check-cf-distribution.mjs` — blocked-mod scanner
- `PLAYER-SETUP.md` — the onboarding doc to hand your friends

**Needs you at the keyboard:**

| Step | Why it needs you |
|---|---|
| Install packwiz | Prebuilt binary from GitHub releases → put on PATH. No Go toolchain needed. |
| Create the GitHub repo | Your account, your auth. Public repo is fine — it holds pointers, not jars. |
| Enable GitHub Pages | Repo Settings → Pages → branch. Gives you the URL everything else keys off. |
| CurseForge API key | Free, tied to your account. Needed for the blocked-mod scan and for packwiz CF adds. |
| Add the ~130 mods | `packwiz cf add <slug>` / `packwiz mr add <slug>`. Mostly mechanical; I can script the list once the final roster is frozen. |
| Export the Prism instance | Build one instance, set the pre-launch hook, export zip → that zip is what your friends import. |

**Ordering note:** do §3's blocked-mod scan *before* the bulk add. Finding out mod #94 is
undistributable after you have built and shared the instance means redoing onboarding.

---

## 6. UPDATE WORKFLOW, once it is running

```
packwiz update <mod>       # or: packwiz update --all
packwiz refresh            # rebuild index + hashes
git commit -am "bump X"; git push
```

Players get it next launch. Server gets it next restart.

**Rules that keep this from hurting:**
1. **Never push a worldgen change after the world is generated.** Adding or removing a
   biome/structure mod mid-world fragments chunks — you get a broken world, not a crash,
   and you find out 40 hours in.
2. **Announce restarts.** The server pulls on restart; a player who launched 10 minutes
   earlier is on the old manifest until they relaunch.
3. **Tag a commit before every risky change** (`git tag pre-<change>`). Rollback is then
   one command instead of an archaeology session.
4. **Datapacks are server-side** — they live in the world folder, not the pack. They do
   **not** ride along with packwiz. Version them separately (they already are, under
   `Minecraft/datapacks/`).
5. **⚠ `packwiz update --all` will re-break Structory Towers.** It is pinned to v1.0.15
   (the last 1.21.x build); 1.0.16+ target the next MC line and ship a `neoforge.mods.toml`
   with no `modLoader` header, which 1.21.1's loader rejects. Update mods individually, or
   re-pin after a bulk update (version-id `lefqbuOP`).

---

## 7. WHAT THE 2026-08-30 PACK BUILD ACTUALLY HIT — read before touching the pack

The pack was built this day (98 stubs: 66 CF + 32 Modrinth incl. auto-deps; dual-listed
mods sourced from **Modrinth** — open API, immune to future CF distribution-flag flips).
*(Later the same day, at server build, it grew to **126 stubs**: the doc-02 §5 perf stack,
Alex's Caves via the unofficial port, doc 03 §2's dropped ADD table, and the Integrated
family reversal — see item 5 below and doc 03 §1. All boot-verified together.)*
Validated end-to-end: `packwiz serve` → `packwiz-installer -g -s server` → NeoForge
21.1.249 boots to `Done` on a throwaway server. Five landmines found, all by **boot
testing**, none by metadata inspection:

1. **packwiz does NOT resolve deps-of-deps.** Loot Integrations entered the pack as a dep
   of its addons; *its* dep (Cupboard) was never prompted for → boot crash. If a mod only
   arrives as a dependency, ITS dependencies are your problem.
2. **Modrinth version metadata lies about dependencies.** Confirmed on three mods:
   Confluence (hid curios), Antarchy (hid sizeable_foliage AND integrated_api). The only
   dependency oracle that counts is NeoForge's ModSorter at boot.
3. **A CF-blocked mod can hide in a dependency.** `player-animation-library` (dep of The
   Awakening) is excluded from the CF API — the §3 scan only covered the modlist, not
   deps. It never fails at `packwiz add` (metadata works); it fails at *install*. It was
   re-sourced from Modrinth (same author, same jar). Run the installer once before
   onboarding anyone.
4. **A "neoforge"-tagged Modrinth file can be a broken build** (Structory Towers 1.0.17,
   see rule 5 above). Loader tags on Modrinth versions are author-supplied claims.
5. **The Integrated family hard-required Create+Quark+Zeta+Supplementaries** (NeoForge
   level, boot-proven both ways) → cut per doc 03 §1. `integrated-api` alone stays
   (Antarchy needs it). **⟳ REVERSED later the same day** (David weighed in, Wesley
   approved): family back in, the four deps admitted as deliberate roster members.
   The landmine itself stands — the point was that CF metadata never disclosed the
   dependency, and only boot testing did.

**The moral, twice-earned:** the pack's true dependency graph is only discoverable by
booting a server against the built pack. That smoke test (serve + install + boot) is now
the mandatory last step of any pack change bigger than a config tweak.
