# 06 — ADAPTIVE MUSIC (GPU-generated per-zone soundtrack)

**Status: IDEA.** Nothing built, nothing researched beyond a feasibility pass, nothing
locked. Everything below is a suggested direction, not a decision. Captured from a
brainstorm session 2026-08-30 so the thinking isn't lost.

**The pitch:** a private custom mod (server + client halves, shipped inside the pack)
that plays continuously generated ambient music, produced locally on the 3090. Music is
**per-location, shared** — players standing in the same zone hear the same track in
sync. Game state (dimension, biome, depth, time, weather, nearby danger) drifts the
mood over time rather than reacting instantly to individual hits.

Private-use only, never distributed. That constraint is load-bearing — several of the
best tricks below only work because the modlist is fixed and the audience is six people.

---

## 1. WHY THIS IS FEASIBLE NOW

- **Generation is cheap.** [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5)
  (Apache-2.0) generates a full song in <10s on a 3090 in <4GB VRAM, and supports LoRA
  fine-tuning. DiffRhythm runs ~28× realtime on similar hardware. The 3090 is
  overqualified; generation is not the bottleneck.
- **Delivery is the real problem, and the modded pack solves it.** Vanilla clients can
  only play audio baked into resource packs — no new OGGs mid-session without a
  disruptive pack re-apply. But everyone installs the pack anyway, so a client-side
  companion mod can play audio through its own OpenAL channel, bypassing the resource
  system entirely. If the clients were vanilla, this idea would be dead on arrival.

---

## 2. PREGENERATED LIBRARY > REALTIME GENERATION (suggested direction)

Two candidate architectures came up; the library approach looks much stronger:

1. **Quality control.** Pregen gets a retry budget — generate 5×, auto-score, keep the
   best. Realtime gets one shot, and these models occasionally produce something
   unhinged.
2. **GPU contention.** The 3090 is also the gaming GPU on this rig. Realtime gen while
   playing = stutter for the host. Pregen runs overnight.
3. **Zero latency**, no silence-on-failure mode.
4. **Size is a non-issue.** ~3,000 tracks × 2–3 min at 128kbps OGG ≈ 8–20GB, roughly
   one overnight run at ACE-Step speeds. The 250GB budget floated early on is ~10×
   more than needed. The bottleneck is prompt curation, not disk or compute.

**Indexing — measure, don't trust the knobs.** These models only loosely obey prompt
parameters ("calm, 90 BPM, D minor"). So: post-analyze every generated track with
librosa/essentia and index by **measured** BPM, key, onset density, spectral
brightness, loudness dynamics. The intensity/wonder/darkness axes come from measured
features, not from the generation dials that were requested.

**Possible later layers:**
- A low-priority background generator topping up the library, biased toward
  mood-buckets the server actually visits — a radio station that slowly learns the
  server.
- LoRA fine-tune on the tracks the group ends up liking.

---

## 3. THE DEAD IDEA (buried deliberately)

Original thought: same seed + different conditioning knobs → "variants" of one clip at
different intensities, crossfade between variants mid-clip for tight reactivity.

**This does not work with current diffusion models.** Same seed + changed conditioning
gives vibes-adjacent output, not the same song at a new intensity — no preserved tempo,
key, or bar structure, therefore no beat alignment, therefore mid-clip crossfades
between "variants" just smear two songs together. The industry answer (aligned
stems / vertical remixing) isn't supported by these models either.

**Replacement that works:** crossfade between *different* tracks drawn from the same
measured key/BPM bucket. A ~6s crossfade between two D-minor ~90 BPM ambient tracks
sounds intentional. This is ordinary horizontal transition design, and the measured
index from §2 is what makes the bucketing possible.

---

## 4. MOOD ENGINE (server side)

- World divided into zones — suggested: spatial cell + dimension. Cell size TBD.
- Each zone carries a mood vector computed from: biome, depth/Y, time of day, weather,
  nearby mob/boss density, recent combat events.
- Smooth with an EMA + hysteresis so mood **drifts** rather than twitches — getting hit
  once changes nothing; sustained combat, a dimension change, or an hour of farming
  moves it.
- Mood is **shared per zone**, deliberately. The known "conflict": a beekeeper next to
  someone farming bosses gets boss-flavored music from the neighbor's actions. Accepted
  as a feature — it falls straight out of shared zone state and makes the world feel
  like one place.
- Track selection: nearest-neighbor in measured-feature space within the zone's current
  bucket, with a no-repeat window.

**Sync:** server broadcasts `(zone, trackId, startTimestamp, crossfadeMs)`; clients
play from the shared timeline. Suggested delivery: chunk audio over the existing MC
connection via custom payloads — **no new ports** (house rule), and a few MB per track
is nothing.

---

## 5. AUDIO ARBITER (client side) — coexisting with mod music

Rather than removing other mods' boss music, **duck ours and let theirs play** —
preserves each mod's musical intent and sidesteps the fact that open models are still
mid at high-intensity boss music (they're strongest in the ambient/wonder/dread range,
which is conveniently 90% of Minecraft).

Detection hinges on one fact: every client-side sound from any source funnels through
the sound engine, and NeoForge fires
[`PlaySoundEvent`](https://docs.neoforged.net/docs/1.21.1/resources/client/sounds/)
before each one plays — regardless of how the mod triggered it (looping instance,
playsound packet, music-manager hijack). Detection is reliable; *classification* is
where the jank lives. Suggested layered stack, each layer catching what the previous
missed:

1. **Vanilla music mute:** cancel only `minecraft:music.*` IDs — NOT a blanket
   MUSIC-channel mute, which would nuke exactly the modded boss music being preserved.
2. **Category rule:** any foreign MUSIC or RECORDS sound → duck. RECORDS for free
   covers jukeboxes/music discs (someone drops a Pigstep, our stream steps aside).
3. **Audit config list** for mods that put boss themes in the wrong category
   (MASTER/NEUTRAL/HOSTILE): build a debug mode that logs every sound ID + category,
   spawn each boss in a test world, add offenders to a per-pack config. One boring
   evening per pack revision. Only viable because the modlist is fixed — the
   private-pack superpower.
4. **Heuristic net under the audit** (because the audit only covers what gets
   triggered in testing — one-off cinematics won't be):
   - *Stream flag, free:* `sounds.json` marks long audio `"stream": true` (modders
     nearly always do — non-streamed long files cause a load lag-spike), readable at
     event time via `Sound#shouldStream()`.
   - *Duration index, ~30 lines:* the engine never knows duration at play time, but
     OGG duration = last page granule position ÷ sample rate. Scan all mod-jar sound
     files at client startup (async, cached), key the cache on the **resolved file**
     (one sound event can own multiple weighted files of differing lengths).
   - Rule: streamed OR >~30s, in MASTER/NEUTRAL/HOSTILE → duck. **Do not extend to
     AMBIENT** — ambience mods play multi-minute drone beds there and it would duck
     the music into permanent silence underground.
   - False positives are usually *correct anyway*: a long dramatic sound (collapse
     rumble, scripted cinematic) is exactly when generated ambience should shut up.
5. **Never-duck override list** on top, and **log every heuristic duck**
   (`ducked 74s for cataclysm:sound.x [HOSTILE, streamed]`) — the log does the audit
   live during real sessions, and any dumb duck becomes a one-line config fix.

Mechanics that will bite if skipped:
- **Fade-back grace window (~8–10s).** Some boss themes are one long looping instance
  (easy: poll `isActive`); others re-fire song-by-song, and an instant fade-back shoves
  ambient music into the gap between their tracks.
- **Ducking is client-local, and that's correct.** Boss mods only play music near the
  boss; only those clients duck. The zone stream keeps its synced timeline, so a client
  fades back in *at the current stream position*, right back alongside everyone else.
- **Skipped on purpose:** boss-bar packets as a pre-duck signal. Plenty of minibosses
  have bars and no music → ducks into silence. The sound-event path reacts within a
  frame of the music actually starting, which is fast enough.

---

## 6. ROUGH SHAPE OF AN MVP (if this ever gets built)

1. Overnight generation run + feature-analysis/indexing script (Python; weekend-sized).
2. Client mod: vanilla-music mute, receive/decode/crossfade tracks, the arbiter stack.
3. Server mod: zones, mood EMA, bucketed track selection.
4. Sync broadcast + audio transfer over the MC connection (weekend-sized).

The two mod halves are the real work, but nothing exotic — no cursed mixins, no
threading nightmares.

## 7. OPEN QUESTIONS (unresolved, in no order)

- Model bake-off: ACE-Step 1.5 vs DiffRhythm vs MusicGen for *instrumental ambient*
  specifically — quality per prompt-effort, not per benchmark.
- Zone cell size, and what happens at zone borders (crossfade between adjacent zones'
  streams? hard handoff?).
- Prompt corpus design — how many mood buckets, what taxonomy (per-biome? per-tag?).
- Mix levels: how loud is the stream vs game SFX; per-player volume control UI.
- Do Nether/End get dedicated buckets vs just extreme ends of the mood axes?
- No-repeat window length for a 6-player group over a months-long campaign.
