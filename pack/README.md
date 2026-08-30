# Minecraft 1.21.1 NeoForge — pack definition

**This repo contains no mod jars.** It contains packwiz TOML pointers (project id, file id,
hash, side). That is what makes it safe to make public: it redistributes nothing.

Setup, rationale and the update workflow: `../planning/04-PACK-DISTRIBUTION.md`
Player onboarding doc to hand out: `../pack-tools/PLAYER-SETUP.md`

## Bootstrap (run once, needs packwiz on PATH)

    packwiz init          # MC 1.21.1, NeoForge
    packwiz cf add <slug> # CurseForge mods   — see ../pack-tools/modlist-curseforge.txt
    packwiz mr add <slug> # Modrinth mods     — see ../pack-tools/modlist-modrinth.txt
    packwiz refresh
    git init && git add -A && git commit -m "initial pack"

## Before bulk-adding — run the blocked-mod scan

    node ../pack-tools/check-cf-distribution.mjs ../pack-tools/modlist-curseforge.txt

Any mod it reports as BLOCKED cannot be auto-downloaded by Prism/packwiz. Resolve those
first — see `04-PACK-DISTRIBUTION.md §3`. Finding out after you have shipped the instance
to five people means redoing onboarding.

## Set `side` on every mod

    packwiz cf add jei
    # then edit mods/jei.pw.toml -> side = "both" | "client" | "server"

Client-only (Xaero's ×3, Jade, Simply Tooltips, JEI, resource packs) must be `client`, or
the server drags them into its tick loop for nothing.
