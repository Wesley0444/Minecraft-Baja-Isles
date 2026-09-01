# Baja Isles - Mod Index

Generated 2026-09-01 14:58 by `pack-tools\build-mod-index.ps1`. **Do not hand-edit** - rerun the script.

162 mod ids across 136 jars (134 top-level, 28 shipped inside other jars).

## How to use this file

- `modid` is what appears in crash reports, entity ids (`terra_entity:spiked_slime`), and log lines.
- A mod listed with `<- parent.jar` is **jar-in-jar**: it is not a separate download, it ships inside that parent. Blaming the parent for its behaviour is correct.
- `side: client` mods are not installed on the server at all. A crash in one of those is never a server fault.
- Full dependency detail per mod is in `pack-tools\MOD-DETAIL.md` (grep it, do not read it whole).

> **Coverage gap:** 2 packwiz entries had no jar on this box, so they contribute no metadata below:
> kotlinforforge-5.12.0-all.jar, moogsvoyagerstructures-1.21-5.0.14.jar

## Declared incompatibilities

Every `type="incompatible"` / `type="discouraged"` edge in the pack, in one place.
**Check here before adding or bumping any mod** - an existing mod's ban on a new modid is invisible if you only scan the new jar. That is exactly how the Supplementaries/Sodium break shipped.

```
noisium -> biox  INCOMPATIBLE  range=*  side=BOTH  # Crashes the game during world generation.
sodium -> embeddium  INCOMPATIBLE  range=[0.0.1,)  side=CLIENT  # Sodium and Embeddium cannot be used together. Please remove Embeddium.
cristellib -> expanded_ecosphere  INCOMPATIBLE  range=[0,3.4.3]  side=BOTH
supplementaries -> farmersdelight  INCOMPATIBLE  range=[0,1.3.0)  side=BOTH
geckolib -> geckoanimfix  INCOMPATIBLE  range=*  side=BOTH
antarchy -> infinity  INCOMPATIBLE  range=(,2.7.2)  side=BOTH  # Infinite Dimensions versions below 2.7.2 are no longer supported
irons_lib -> irons_patreon_lib  INCOMPATIBLE  range=*  side=BOTH  # Patreon Lib is superceeded by Iron's Lib! You can safely uninstall it.
supplementaries -> sodium  INCOMPATIBLE  range=[0,0.8.12-beta.1)  side=BOTH
cristellib -> t_and_t  INCOMPATIBLE  range=(,1.13.3]  side=BOTH
```

## Embedded modules (jar-in-jar)

`child modid` <- the jar that actually ships it. This is how you get from a crash-report package name to a downloadable mod.

```
accessories 1.1.0-beta.48+1.21.1 <- aether-1.21.1-1.5.10-neoforge.jar
biolith 3.0.10 <- Quark-4.1-482.jar
codecui 1.21.1-1.3.6 <- moonlight-1.21.1-3.5.2-neoforge.jar
confluence_magic_lib 0.0.8 <- ConfluenceOtherworld-1.2.4-260226.jar
cumulus_menus 2.0.7 <- aether-1.21.1-1.5.10-neoforge.jar
fabric_api_base 0.4.42+d1308ded19 <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_block_view_api_v2 1.0.10+9afaaf8c19 <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_renderer_api_v1 3.4.1+9125b6dc19 <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_rendering_data_attachment_v1 0.3.48+73761d2e19 <- sodium-neoforge-0.8.13+mc1.21.1.jar
flywheel 1.0.6 <- create-1.21.1-6.0.10.jar
infiniverse 2.0.1.0 <- ars_nouveau-1.21.1-5.13.1.jar
kotlinforforge 5.12.0 <- kotlinforforge-5.12.0-all.jar
kuma_api 21.0.8 <- balm-neoforge-1.21.1-21.0.65.jar
lambdynlights_api 4.5.1+1.21.1 <- ars_nouveau-1.21.1-5.13.1.jar
mixinsquared 0.3.7-beta.3 <- supplementaries-1.21.1-3.9.6-neoforge.jar
nitrogen_internals 1.1.25 <- aether-1.21.1-1.5.10-neoforge.jar
nuggets 1.1.0.48 <- ars_nouveau-1.21.1-5.13.1.jar
particlestorm 1.1.4.3 <- ConfluenceOtherworld-1.2.4-260226.jar
ponder 1.0.82+mc1.21.1 <- create-1.21.1-6.0.10.jar
sablecompanion 1.6.0 <- supplementaries-1.21.1-3.9.6-neoforge.jar
sauce 0.0.47.92 <- ars_elemental-1.21.1-0.7.10.1.jar
terra_curio 1.2.0 <- ConfluenceOtherworld-1.2.4-260226.jar
terra_entity 1.2.1 <- ConfluenceOtherworld-1.2.4-260226.jar
terra_furniture 1.21.1-0.0.5 <- ConfluenceOtherworld-1.2.4-260226.jar
terra_guns 1.0 <- ConfluenceOtherworld-1.2.4-260226.jar
the_trackers 1.21.1-0.2.5 <- ConfluenceOtherworld-1.2.4-260226.jar
thr_dim_particle 1.0.5 <- ConfluenceOtherworld-1.2.4-260226.jar
xaerolib 1.7.1 <- xaerominimap-neoforge-1.21.1-26.4.2.jar
```

## All mods

```
modid | version | side | jar
accessories | 1.1.0-beta.48+1.21.1 | both | accessories-neoforge-1.1.0-beta.48+1.21.1.jar <- aether-1.21.1-1.5.10-neoforge.jar
aether | 1.5.10 | both | aether-1.21.1-1.5.10-neoforge.jar
alexscaves | 2.0.10 | both | alexscaves-2.0.10.jar
alternate_current | 1.9.0 | server | alternate_current-mc1.21-1.9.0.jar
antarchy | 1.1.1+neoforge-1.21.1 | both | antarchy-1.1.1+1.21.1-neoforge.jar
apotheosis | 8.7.0 | both | Apotheosis-1.21.1-8.7.0.jar
apothic_attributes | 2.10.1 | both | ApothicAttributes-1.21.1-2.10.1.jar
apothic_enchanting | 1.6.1 | both | ApothicEnchanting-1.21.1-1.6.1.jar
apothic_spawners | 1.4.0 | both | ApothicSpawners-1.21.1-1.4.0.jar
aquamirae | 7.2.3 | both | aquamirae-neoforge-1.21.1-7.2.3.jar
architectury | 13.0.11 | both | architectury-13.0.11-neoforge.jar
ars_elemental | 0.7.10.1 | both | ars_elemental-1.21.1-0.7.10.1.jar
ars_n_spells | 3.2.2 | both | ars_n_spells-3.2.2.jar
ars_nouveau | 5.13.1 | both | ars_nouveau-1.21.1-5.13.1.jar
athena | 4.0.6 | both | athena-neoforge-1.21.1-4.0.6.jar
awakened | 1.10.3 | both | awakened-1.10.3+1.21.1.jar
balm | 21.0.65 | both | balm-neoforge-1.21.1-21.0.65.jar
betterarcheology | 1.21.1-1.3.8 | both | betterarcheology-neoforge-1.21.1-1.3.8.jar
bettercombat | 2.4.0+1.21.1 | both | bettercombat-neoforge-2.4.0+1.21.1.jar
betterfortresses | 1.21.1-NeoForge-3.1.5 | both | YungsBetterNetherFortresses-1.21.1-NeoForge-3.1.5.jar
bf_blockpack | 1.1.2 | both | bf_blockpack-neoforge-1.21.1-1.1.2.jar
biolith | 3.0.10 | both | biolith-neoforge-3.0.10.jar <- Quark-4.1-482.jar
biomesoplenty | 21.1.0.14 | both | BiomesOPlenty-neoforge-1.21.1-21.1.0.14.jar
blockui | 1.0.211-1.21.1-snapshot | both | blockui-1.0.211-1.21.1-snapshot.jar
cataclysm | 3.33 | both | L_Ender's Cataclysm 1.21.1-3.33.jar
cataclysmfortresses | 1.21.1 | both | cataclysmfortresses-1.21.1-NeoForge.jar
chipped | 4.0.2 | both | chipped-neoforge-1.21.1-4.0.2.jar
chunky | 1.4.23 | server | Chunky-NeoForge-1.4.23.jar
citadel | 2.7.6 | both | citadel-1.21.1-2.7.6.jar
cloth_config | 15.0.140 | both | cloth-config-15.0.140-neoforge.jar
clumps | 19.0.0.1 | both | Clumps-neoforge-1.21.1-19.0.0.1.jar
codecui | 1.21.1-1.3.6 | both | codecui-neoforge-1.21.1-1.3.6.jar <- moonlight-1.21.1-3.5.2-neoforge.jar
combat_roll | 2.0.6+1.21.1 | both | combat_roll-neoforge-2.0.6+1.21.1.jar
confluence | 1.2.4 | both | ConfluenceOtherworld-1.2.4-260226.jar
confluence_magic_lib | 0.0.8 | both | org.confluence.lib.confluence_magic_lib-0.0.8.jar <- ConfluenceOtherworld-1.2.4-260226.jar
create | 6.0.10 | both | create-1.21.1-6.0.10.jar
cristellib | 3.1.7 | both | cristellib-neoforge-1.21.1-3.1.7.jar
cumulus_menus | 2.0.7 | both | cumulus_menus-1.21.1-2.0.7-neoforge.jar <- aether-1.21.1-1.5.10-neoforge.jar
cupboard | 4.1 | both | cupboard-1.21.1-4.1.jar
curios | 9.5.1+1.21.1 | both | curios-neoforge-9.5.1+1.21.1.jar
darkermagic | 1.3.3-1.21.1 | both | darkermagic-1.3.3-1.21.1-ver.b.jar
deeperdarker | 1.4.1 | both | deeperdarker-neoforge-1.21.1-1.4.1.jar
domum_ornamentum | 1.0.234-snapshot | both | domum-ornamentum-1.0.234-snapshot-main.jar
dungeons_arise | 2.1.68 | both | DungeonsArise-1.21.1-2.1.68-release.jar
envelope | 0.7.5 | both | envelope-neoforge-1.21.1-0.7.5.jar
eternal_starlight | 0.9.0+1.21.1+neoforge | both | eternalstarlight-0.9.0+1.21.1+neoforge.jar
fabric_api_base | 0.4.42+d1308ded19 | client | fabric-api-base-0.4.42+d1308ded19.jar <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_block_view_api_v2 | 1.0.10+9afaaf8c19 | client | fabric-block-view-api-v2-1.0.10+9afaaf8c19.jar <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_renderer_api_v1 | 3.4.1+9125b6dc19 | client | fabric-renderer-api-v1-3.4.1+9125b6dc19.jar <- sodium-neoforge-0.8.13+mc1.21.1.jar
fabric_rendering_data_attachment_v1 | 0.3.48+73761d2e19 | client | fabric-rendering-data-attachment-v1-0.3.48+73761d2e19.jar <- sodium-neoforge-0.8.13+mc1.21.1.jar
fallingtree | 1.21.1.11 | server | FallingTree-1.21.1-1.21.1.11.jar
farmersdelight | 1.3.4 | both | FarmersDelight-1.21.1-1.3.4.jar
fastsuite | 6.0.7 | server | FastSuite-1.21.1-6.0.7.jar
ferritecore | 7.0.3 | both | ferritecore-7.0.3-neoforge.jar
floating_islands | 1.5.3-1.21.1-neoforge | server | floating_islands-1.5.3-1.21.1-neoforge.jar
flywheel | 1.0.6 | both | flywheel-neoforge-1.21.1-1.0.6.jar <- create-1.21.1-6.0.10.jar
fragmentum | 2.4.4 | both | fragmentum-neoforge-1.21.1-2.4.4.jar
framework | 0.13.11 | both | framework-neoforge-1.21.1-0.13.11.jar
fusion | 1.3.14+a | both | fusion-1.3.14a-neoforge-mc1.21.1.jar
fzzy_config | 0.7.6+1.21+neoforge | both | fzzy_config-0.7.6+1.21+neoforge.jar
gateway_of_doom | 2.2.0 | both | gatewayofdoom-neoforge-1.21.1-2.2.0.jar
gateways | 5.1.0 | both | GatewaysToEternity-1.21.1-5.1.0.jar
geckolib | 4.9.2 | both | geckolib-neoforge-1.21.1-4.9.2.jar
glitchcore | 2.1.0.2 | both | GlitchCore-neoforge-1.21.1-2.1.0.2.jar
goblintraders | 1.11.2 | both | goblintraders-neoforge-1.21.1-1.11.2.jar
gravestone | 1.21.1-1.0.40 | both | gravestone-neoforge-1.21.1-1.0.40.jar
guardvillagers | 2.4.12 | both | guardvillagers-2.4.12-1.21.1.jar
idas | 1.13.7+1.21.1-neoforge | both | idas-1.13.7+1.21.1-neoforge.jar
infiniverse | 2.0.1.0 | both | infiniverse-568341-5486311.jar <- ars_nouveau-1.21.1-5.13.1.jar
integrated_api | 1.8.0 | both | integrated_api-neoforge-1.21.1-1.8.0.jar
integrated_cataclysm | 1.0.6+1.21.1-neoforge | both | integrated_cataclysm-1.0.6+1.21.1-neoforge.jar
integrated_stronghold | 1.1.4+1.21.1-neoforge | both | integrated_stronghold-1.1.4+1.21.1-neoforge.jar
integrated_villages | 1.3.3+1.21.1-neoforge | both | integrated_villages-1.3.3+1.21.1-neoforge.jar
irons_lib | 1.21.1-2.1.0 | both | irons_lib-1.21.1-2.1.0.jar
irons_spellbooks | 1.21.1-3.16.3 | both | irons_spellbooks-1.21.1-3.16.3.jar
jade | 15.10.6+neoforge | client | Jade-1.21.1-NeoForge-15.10.6.jar
jei | 19.51.0.417 | both | jei-1.21.1-neoforge-19.51.0.417.jar
kotlinforforge | 5.12.0 | both | thedarkcolour.kffmod-5.12.0.jar <- kotlinforforge-5.12.0-all.jar
kuma_api | 21.0.8 | both | kuma-api-neoforge-21.0.8+1.21.jar <- balm-neoforge-1.21.1-21.0.65.jar
lambdynlights | 4.8.10+1.21.1 | client | lambdynamiclights-4.8.10+1.21.1.jar
lambdynlights_api | 4.5.1+1.21.1 | both | lambdynamiclights-api-4.5.1+1.21.1-mojmap.jar <- ars_nouveau-1.21.1-5.13.1.jar
lionfishapi | 3.1 | both | lionfishapi-3.1.jar
lithium | 0.15.4+mc1.21.1 | server | lithium-neoforge-0.15.4+mc1.21.1.jar
loot_journal | 6.2.1 | both | loot_journal-neoforge-1.21.1-6.2.1.jar
lootintegration_wda | 1 | both | lootintegration_wda-1.8.jar
lootintegrations | 4.7 | both | lootintegrations-1.21.1-4.7.jar
lootintegrations_cataclysm | 1 | both | lootintegrations_cataclysm-1.2.jar
lootintegrations_integrated | 1 | both | lootintegrations_integrated-1.5.jar
lootintegrations_vanilla | 1 | both | lootintegrations_vanilla-1.7.jar
lootr | 1.21.1-1.11.38.124 | both | lootr-neoforge-1.21.1-1.11.38.124.jar
magistuarmory | 10.12 | both | epic-knights-1.21.1-neoforge-10.12.jar
minecolonies | 1.1.1368-1.21.1 | both | minecolonies-1.1.1368-1.21.1.jar
mixinsquared | 0.3.7-beta.3 | both | mixinsquared-forge-0.3.7-beta.3.jar <- supplementaries-1.21.1-3.9.6-neoforge.jar
modernfix | 5.27.23+mc1.21.1 | both | modernfix-neoforge-5.27.23+mc1.21.1.jar
moogs_structures | 3.1.2 | server | MoogsStructureLib-neoforge-1.21.1-3.1.2.jar
moonlight | 1.21.1-3.5.2 | both | moonlight-1.21.1-3.5.2-neoforge.jar
mowzies_cataclysm | 1.2.2 | both | mowzies_cataclysm-1.2.2.jar
mowziesmobs | 1.8.2 | both | mowziesmobs-1.21.1-1.8.2.jar
multipiston | 1.2.58-1.21.1 | both | multipiston-1.2.58-1.21.1.jar
naturalist | 2.0.3 | both | naturalist-2.0.3-neoforge-1.21.1.jar
netherman | 1.1.4.12 | both | cultofazazelneoforge-1.1.4.12.jar
nitrogen_internals | 1.1.25 | both | nitrogen_internals-1.21.1-1.1.25-neoforge.jar <- aether-1.21.1-1.5.10-neoforge.jar
noisium | 2.3.0+mc1.21-1.21.1 | server | noisium-neoforge-2.3.0+mc1.21-1.21.1.jar
nuggets | 1.1.0.48 | both | nuggets-neoforge-1.21.1-1.1.0.48.jar <- ars_nouveau-1.21.1-5.13.1.jar
oceansdelight | 1.0.4 | both | oceansdelight-neoforge-1.0.4-1.21.1.jar
owo | 0.12.15.5-beta.1+1.21 | both | owo-lib-neoforge-0.12.15.5-beta.1+1.21.jar
particlestorm | 1.1.4.3 | both | ParticleStorm-1.1.4.3.jar <- ConfluenceOtherworld-1.2.4-260226.jar
patchouli | 1.21.1-93-NEOFORGE | both | Patchouli-1.21.1-93-NEOFORGE.jar
paxi | 1.21.1-NeoForge-5.1.3 | both | Paxi-1.21.1-NeoForge-5.1.3.jar
placebo | 9.9.2 | both | Placebo-1.21.1-9.9.2.jar
player_animation_library | 1.1.6+mc.1.21.1 | both | PlayerAnimationLibNeoforge-1.1.6+mc.1.21.1.jar
playeranimator | 2.0.4+1.21.1 | both | player-animation-lib-forge-2.0.4+1.21.1.jar
ponder | 1.0.82+mc1.21.1 | both | ponder-neoforge-1.0.82+mc1.21.1.jar <- create-1.21.1-6.0.10.jar
primal | 1.1.6 | both | primal-1.1.6+1.21.jar
quark | 4.1-482 | both | Quark-4.1-482.jar
rechiseled | 1.2.5 | both | rechiseled-1.2.5-neoforge-mc1.21.jar
rechiseled_chipped | 1.3 | both | rechiseled_chipped-2.0-1.21.1.jar
resourcefulconfig | 3.0.11 | both | resourcefulconfig-neoforge-1.21-3.0.11.jar
resourcefullib | 3.0.12 | both | resourcefullib-neoforge-1.21-3.0.12.jar
sablecompanion | 1.6.0 | both | sable-companion-common-1.21.1-1.6.0.jar <- supplementaries-1.21.1-3.9.6-neoforge.jar
sauce | 0.0.47.92 | both | sauce-1.21.1-0.0.47.92.jar <- ars_elemental-1.21.1-0.7.10.1.jar
servercore | 1.5.19+1.21.1 | server | servercore-neoforge-1.5.19+1.21.1.jar
shieldexp | 1.4.1 | both | shieldexp-neoforge-1.21.1-1.4.1.jar
simplybows | 0.1.4 | both | SimplyBows-neoforge-0.1.4-1.21.1.jar
simplyentityequipment | 0.1.0-1.21.1 | both | simplyentityequipment-neoforge-0.1.0-1.21.1.jar
simplyswords | 1.70.2-1.21.1 | both | simplyswords-neoforge-1.70.2-1.21.1.jar
simplytooltips | 0.1.5 | both | SimplyTooltips-neoforge-0.1.5.jar
sizeable_foliage | 1.2.1 | both | sizeable_foliage-neoforge-1.21.1-1.2.1.jar
skeletonusescustombow | 1.1.0-neoforge-1.21.1 | both | skeletonusescustombow-1.1.0-neoforge-1.21.1.jar
sodium | 0.8.13+mc1.21.1 | client | sodium-neoforge-0.8.13+mc1.21.1.jar
sophisticatedbackpacks | 3.25.78 | both | sophisticatedbackpacks-1.21.1-3.25.78.2107.jar
sophisticatedcore | 1.4.90 | both | sophisticatedcore-1.21.1-1.4.90.2299.jar
sophisticatedstorage | 1.5.91 | both | sophisticatedstorage-1.21.1-1.5.91.2127.jar
spark | 1.10.124 | server | spark-1.10.124-neoforge.jar
sparsestructures | 3.0 | server | sparsestructures-neoforge-1.21.1-3.0.jar
structory_towers | 1.0.15 | both | Structory_Towers_1.21.x_v1.0.15.jar
structurify | 2.0.34 | both | structurify-neoforge-2.0.34+mc1.21.1.jar
structurize | 1.0.832-1.21.1 | both | structurize-1.0.832-1.21.1.jar
supermartijn642configlib | 1.1.8 | both | supermartijn642configlib-1.1.8-neoforge-mc1.21.jar
supermartijn642corelib | 1.1.24 | both | supermartijn642corelib-1.1.24-neoforge-mc1.21.jar
supplementaries | 1.21.1-3.9.6 | both | supplementaries-1.21.1-3.9.6-neoforge.jar
t_and_t | 1.13.11 | both | t_and_t-fabric-neoforge-1.13.11.jar
terra_curio | 1.2.0 | both | org.confluence.terra_curio-1.2.0.jar <- ConfluenceOtherworld-1.2.4-260226.jar
terra_entity | 1.2.1 | both | org.confluence.terra_entity-1.2.1.jar <- ConfluenceOtherworld-1.2.4-260226.jar
terra_furniture | 1.21.1-0.0.5 | both | org.confluence.terra_furniture.terra_furniture-1.21.1-0.0.5.jar <- ConfluenceOtherworld-1.2.4-260226.jar
terra_guns | 1.0 | both | org.confluence.terra_guns-1.21.1-1.0.jar <- ConfluenceOtherworld-1.2.4-260226.jar
terrablender | 4.1.0.8 | both | TerraBlender-neoforge-1.21.1-4.1.0.8.jar
terralith | 2.5.8 | both | Terralith_1.21.x_v2.5.8.jar
the_trackers | 1.21.1-0.2.5 | both | nowebsite.makertechno.the_trackers.the_trackers-1.21.1-0.2.5.jar <- ConfluenceOtherworld-1.2.4-260226.jar
thr_dim_particle | 1.0.5 | both | ThreeDimensionParticle-core-1.0.5.jar <- ConfluenceOtherworld-1.2.4-260226.jar
towntalk | 1.2.0 | both | towntalk-1.2.0.jar
twilightforest | 4.8.3345 | both | twilightforest-1.21.1-4.8.3345-universal.jar
undergarden | 0.9.6 | both | The_Undergarden-1.21.1-0.9.6.jar
visual_health | 1.21.1-2.0.2 | both | visualhealth-neoforge-1.21.1-2.0.2.jar
w2w2 | 2.1.0 | both | xaeros_waystones_compatibility-NeoForge-1.21.1-2.1.0.jar
waystones | 21.1.27 | both | waystones-neoforge-1.21.1-21.1.27.jar
xaerolib | 1.7.1 | client | xaerolib-neoforge-1.21.1-1.7.1.jar <- xaerominimap-neoforge-1.21.1-26.4.2.jar
xaerominimap | 26.4.2 | client | xaerominimap-neoforge-1.21.1-26.4.2.jar
xaeroworldmap | 1.45.0 | client | xaeroworldmap-neoforge-1.21.1-1.45.0.jar
yet_another_config_lib_v3 | 3.8.2+1.21.1-neoforge | both | yet_another_config_lib_v3-3.8.2+1.21.1-neoforge.jar
yungsapi | 1.21.1-NeoForge-5.1.8 | both | YungsApi-1.21.1-NeoForge-5.1.8.jar
zeta | 1.1-40 | both | Zeta-1.1-40.jar
```
