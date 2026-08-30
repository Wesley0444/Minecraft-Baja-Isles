#!/usr/bin/env node
/**
 * check-cf-distribution.mjs
 *
 * Finds CurseForge mods whose author disabled third-party distribution.
 * Those mods CANNOT be auto-downloaded by packwiz / Prism / any non-CF launcher —
 * the API returns no download URL and the player's install fails on their machine.
 *
 * Run this BEFORE bulk-adding mods and before onboarding anyone.
 *
 * Usage:
 *   set CF_API_KEY=...            (Windows cmd)    or  $env:CF_API_KEY="..."  (PowerShell)
 *   node check-cf-distribution.mjs modlist.txt
 *
 * modlist.txt = one CurseForge slug per line. Blank lines and #comments ignored.
 * A line may be `slug:projectId` (e.g. `aquamirae:536254`) to pin the project id and
 * skip slug resolution entirely — needed for valid slugs CFWidget wrongly 404s on.
 * Get a free API key at https://console.curseforge.com/  (Core API → API Keys)
 *
 * ⚠ Console-issued keys may be locked out of /v1/mods/search (403 "API Key missing or
 * invalid" on that endpoint only — every other endpoint works). When that happens the
 * slug→id lookup falls back to the public CFWidget mirror (api.cfwidget.com); the
 * distribution + file checks always come from the official API.
 *
 * Exit code 1 if any blocked mod is found, so it can gate a build step.
 */

const API = 'https://api.curseforge.com/v1';
const GAME_ID = 432;          // Minecraft
const LOADER_NEOFORGE = 6;    // CurseForge modLoaderType enum
const MC_VERSION = '1.21.1';

const key = process.env.CF_API_KEY;
if (!key) {
  console.error('ERROR: CF_API_KEY is not set. Get one at https://console.curseforge.com/');
  process.exit(2);
}

const listPath = process.argv[2];
if (!listPath) {
  console.error('Usage: node check-cf-distribution.mjs <modlist.txt>');
  process.exit(2);
}

const fs = await import('node:fs');
const entries = fs.readFileSync(listPath, 'utf8')
  .split('\n')
  .map(s => s.trim())
  .filter(s => s && !s.startsWith('#'))
  .map(line => {
    const [slug, id] = line.split(':');
    return { slug, forcedId: id ? Number(id) : null };
  });

const headers = { 'x-api-key': key, Accept: 'application/json' };

async function get(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const r = await fetch(url, { headers });
      if (r.status === 429) {                       // rate limited — back off
        await new Promise(res => setTimeout(res, 2000 * (attempt + 1)));
        continue;
      }
      if (!r.ok) return { __error: `HTTP ${r.status}` };
      return await r.json();
    } catch (e) {
      if (attempt === 2) return { __error: String(e.message || e) };
      await new Promise(res => setTimeout(res, 1000));
    }
  }
  return { __error: 'retries exhausted' };
}

// slug → project id via CFWidget, for keys that 403 on the official search endpoint.
// 202 = cfwidget hasn't cached the project yet and queued a fetch — wait and retry.
async function cfwidgetId(slug) {
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const r = await fetch(`https://api.cfwidget.com/minecraft/mc-mods/${encodeURIComponent(slug)}`);
      if (r.status === 200) return { id: (await r.json()).id };
      if (r.status === 404) return { notFound: true };
      if (r.status === 202 || r.status === 429) {
        await new Promise(res => setTimeout(res, 3000));
        continue;
      }
      return { error: `cfwidget HTTP ${r.status}` };
    } catch (e) {
      if (attempt === 3) return { error: String(e.message || e) };
      await new Promise(res => setTimeout(res, 1000));
    }
  }
  return { error: 'cfwidget retries exhausted (still queued?)' };
}

const blocked = [], ok = [], notFound = [], noBuild = [], errored = [];
let searchLocked = false;

for (const { slug, forcedId } of entries) {
  let mod;

  if (forcedId) {
    const direct = await get(`${API}/mods/${forcedId}`);
    if (direct.__error) { errored.push([slug, direct.__error]); continue; }
    mod = direct?.data;
  } else {
    const search = searchLocked
      ? { __error: 'HTTP 403' }
      : await get(`${API}/mods/search?gameId=${GAME_ID}&slug=${encodeURIComponent(slug)}`);

    if (search.__error === 'HTTP 403') {
      if (!searchLocked) {
        searchLocked = true;
        console.error('NOTE: /v1/mods/search is 403 for this key — resolving slugs via CFWidget instead.');
      }
      const res = await cfwidgetId(slug);
      if (res.error) { errored.push([slug, res.error]); continue; }
      if (res.notFound) { notFound.push(slug); continue; }
      const direct = await get(`${API}/mods/${res.id}`);
      if (direct.__error) { errored.push([slug, direct.__error]); continue; }
      mod = direct?.data;
    } else if (search.__error) {
      errored.push([slug, search.__error]); continue;
    } else {
      mod = search?.data?.[0];
    }
  }

  if (!mod) { notFound.push(slug); continue; }

  // allowModDistribution === false is the author's explicit opt-out.
  // null/undefined is treated as allowed (the field is not always populated).
  if (mod.allowModDistribution === false) {
    blocked.push({ slug, name: mod.name, id: mod.id });
    continue;
  }

  // Even when allowed, confirm a 1.21.1 NeoForge file actually exists AND carries a
  // downloadUrl — the two failure modes are independent.
  const files = await get(
    `${API}/mods/${mod.id}/files?gameVersion=${MC_VERSION}&modLoaderType=${LOADER_NEOFORGE}&pageSize=5`
  );
  if (files.__error) { errored.push([slug, files.__error]); continue; }

  const list = files?.data ?? [];
  if (!list.length) { noBuild.push({ slug, name: mod.name }); continue; }
  if (list.every(f => !f.downloadUrl)) {
    blocked.push({ slug, name: mod.name, id: mod.id, note: 'files exist but downloadUrl is null' });
    continue;
  }
  ok.push({ slug, name: mod.name });
}

const line = (n = 78) => '-'.repeat(n);
console.log(`\nChecked ${entries.length} CurseForge slugs against MC ${MC_VERSION} / NeoForge\n${line()}`);

if (blocked.length) {
  console.log(`\n### BLOCKED — third-party distribution disabled (${blocked.length})`);
  console.log('    packwiz CANNOT download these. Drop them, find them on Modrinth, or');
  console.log('    have players sideload manually. Do NOT self-host the jar.\n');
  for (const m of blocked) console.log(`  - ${m.name}  (${m.slug})${m.note ? '  [' + m.note + ']' : ''}`);
}
if (noBuild.length) {
  console.log(`\n### NO 1.21.1 NEOFORGE FILE (${noBuild.length})`);
  console.log('    Distribution is fine, but no matching build exists. Check Modrinth too.\n');
  for (const m of noBuild) console.log(`  - ${m.name}  (${m.slug})`);
}
if (notFound.length) {
  console.log(`\n### SLUG NOT FOUND (${notFound.length}) — likely a typo or a renamed project\n`);
  for (const s of notFound) console.log(`  - ${s}`);
}
if (errored.length) {
  console.log(`\n### API ERRORS (${errored.length}) — re-run these, result is unknown\n`);
  for (const [s, e] of errored) console.log(`  - ${s}: ${e}`);
}
console.log(`\n${line()}`);
console.log(`OK: ${ok.length}   BLOCKED: ${blocked.length}   NO-BUILD: ${noBuild.length}   NOT-FOUND: ${notFound.length}   ERRORS: ${errored.length}\n`);

process.exit(blocked.length ? 1 : 0);
