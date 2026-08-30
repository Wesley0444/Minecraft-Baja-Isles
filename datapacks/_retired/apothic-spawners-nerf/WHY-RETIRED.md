# Retired 2026-08-30

Recipe overrides raising the cost of Apothic Spawners' `echoing` / `min_delay` /
`max_delay` / `spawn_count` modifiers.

**Why retired:** Wesley was asked directly whether to cap Apothic Spawners (~400x loot
rate, 16 spawn attempts/sec at max) and chose **"Keep it as-is"** — the group likes farms
and infinite loot is a feature in a kitchen-sink pack. Recorded in
`planning/03-FINAL-DECISIONS.md §5` as an accepted risk, not an oversight.

Restore by moving `data/apothic_spawners/` back into `datapacks/pack-balance/data/`.
