package baja.tiers.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

import baja.tiers.VisitorStyleGuard;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.world.entity.Entity;

/**
 * Stops a MineColonies Tavern visitor from crashing the CLIENT that renders it.
 *
 * VisitorCitizen.aiStep(), client branch, every 20 ticks:
 *     getEntityData().set(DATA_STYLE, colonyView.getTextureStyleId());
 * with no null check. When the colony view has no texture style yet, DATA_STYLE becomes null on
 * that client, and the next render frame dies in AbstractEntityCitizen.getTexture() line 281:
 *     texture.getPath().contains(getEntityData().get(DATA_STYLE))   -> NPE, "s" is null
 * = crash "Rendering entity in world". Regular citizens are covered by
 * EntityCitizen.onSyncedDataUpdated; visitors extend AbstractEntityCitizen directly and are not.
 * Seen 2026-09-15 (Wesley, waystone into the colony) and 2026-09-18 (Dan, nether portal next to
 * the tavern): arriving beside a Tavern from far away. Bytecode-verified on minecolonies
 * 1.1.1368; the same line is unguarded at the head of every upstream 1.21 branch, and upstream
 * PR ldtteam/minecolonies#11828 was closed unmerged 2026-09-16.
 *
 * The redirect drops a null write and lets everything else through. Nothing is lost: the server
 * already synced the right style into DATA_STYLE (CitizenData.initEntityValues), so the visitor
 * keeps that until the view catches up 20 ticks later. aiStep has exactly one
 * SynchedEntityData.set call; should a later MineColonies add more, null is never a legal synced
 * value, so skipping it stays correct.
 *
 * String target + @Pseudo: no compile dependency on MineColonies, and a pack without it just
 * skips this mixin. The config is required:false and the injector require = 0 on purpose -- if a
 * MineColonies update moves the call, the guard silently stops applying (back to today's
 * behaviour) instead of hard-crashing every client at boot. {@link VisitorStyleGuard#report}
 * logs APPLIED / NOT APPLIED on every launch so that never goes unnoticed.
 */
@Pseudo
@Mixin(targets = "com.minecolonies.core.entity.visitor.VisitorCitizen", remap = false)
public abstract class VisitorStyleGuardMixin {

    @Redirect(method = "aiStep",
              at = @At(value = "INVOKE",
                       target = "Lnet/minecraft/network/syncher/SynchedEntityData;set(Lnet/minecraft/network/syncher/EntityDataAccessor;Ljava/lang/Object;)V",
                       remap = false),
              require = 0)
    private <T> void bajatiers$skipNullStyle(SynchedEntityData data, EntityDataAccessor<T> key, T value) {
        if (value == null) {
            VisitorStyleGuard.noteSkip((Entity) (Object) this);
            return;
        }
        data.set(key, value);
    }
}
