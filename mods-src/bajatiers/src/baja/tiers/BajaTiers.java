package baja.tiers;

import org.slf4j.Logger;

import com.mojang.logging.LogUtils;

import dev.shadowsoffire.apotheosis.tiers.WorldTier;
import dev.shadowsoffire.apotheosis.tiers.augments.TierAugment;
import dev.shadowsoffire.apotheosis.tiers.augments.TierAugmentRegistry;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.neoforge.common.ModConfigSpec;
import net.neoforged.neoforge.common.NeoForge;
import net.neoforged.neoforge.common.util.FakePlayer;
import net.neoforged.neoforge.event.entity.living.LivingIncomingDamageEvent;

/**
 * Baja Tiers -- per-player mob damage / mob health keyed off the PLAYER's Apotheosis World Tier.
 *
 * Why not a stock tier_augments datapack on generic.attack_damage: Apotheosis bakes monster
 * augments into the mob at spawn from the NEAREST player's tier, permanently, so in a mixed-tier
 * group the Ascent player's mobs hit the Haven player for Ascent damage, and attack_damage never
 * covers arrows / explosions / spells. This mod scales at damage time instead, by the tier of the
 * player involved, so the same zombie hits a Haven player for 70% and an Ascent player for 200%.
 *
 * The NUMBERS live in the datapack as {@link ScalarAugment} entries of the tier_augments registry
 * (types bajatiers:mob_damage / bajatiers:mob_health, percent of vanilla). That makes the JSON the
 * single source of truth, hot-reloadable with /reload, synced to clients, and listed in the World
 * Tier detail screen under Monster Augments. A tier with no entry is 100% (unchanged).
 *
 * Two mirrored scalings on LivingIncomingDamageEvent:
 *   mob_damage -- victim is a real ServerPlayer, attacker (DamageSource#getEntity, the owner for
 *                 projectiles) is a non-player LivingEntity.            damage *= pct/100
 *   mob_health -- attacker is a real ServerPlayer, victim is any non-player LivingEntity.
 *                 Effective health: health bars still show vanilla.    damage *= 100/pct
 * Fall, lava, drowning, starvation, PvP and block damage are untouched on purpose.
 *
 * Both sides: the client needs the codec to decode the synced registry and to render the screen.
 * Config (config/bajatiers-common.toml) holds only the hit-log toggle.
 */
@Mod(BajaTiers.MODID)
public class BajaTiers {

    public static final String MODID = "bajatiers";
    private static final Logger LOGGER = LogUtils.getLogger();

    static final ModConfigSpec SPEC;
    static final ModConfigSpec.BooleanValue LOG_HITS;

    static {
        ModConfigSpec.Builder b = new ModConfigSpec.Builder();
        LOG_HITS = b.comment(
            "Log every scaled hit at INFO: player (tier) takes from|deals to <mob> via <src>: a -> b (pct% -> xM).",
            "Debug aid; leave off. The multipliers themselves are NOT here -- they are tier_augments datapack",
            "entries of type bajatiers:mob_damage / bajatiers:mob_health (percent of vanilla), /reload to change.")
            .define("log_hits", false);
        SPEC = b.build();
    }

    public BajaTiers(IEventBus modBus, ModContainer container) {
        container.registerConfig(ModConfig.Type.COMMON, SPEC);
        for (ScalarAugment.Kind kind : ScalarAugment.Kind.values()) {
            TierAugmentRegistry.INSTANCE.registerCodec(kind.id, kind.codec);
        }
        NeoForge.EVENT_BUS.addListener(BajaTiers::onIncomingDamage);
        LOGGER.info("Baja Tiers loaded: mob_damage / mob_health tier augments registered; per-player scaling active.");
    }

    static void onIncomingDamage(LivingIncomingDamageEvent event) {
        LivingEntity victim = event.getEntity();
        DamageSource source = event.getSource();
        Entity attacker = source.getEntity();

        // Player taking a hit from a non-player living attacker -> mob_damage by the VICTIM's tier.
        if (victim instanceof ServerPlayer player && !(player instanceof FakePlayer)) {
            if (attacker instanceof LivingEntity && !(attacker instanceof Player)) {
                scale(event, player, ScalarAugment.Kind.MOB_DAMAGE, "takes from", attacker);
            }
            return;
        }

        // Non-player living target hit by a real player -> mob_health by the ATTACKER's tier.
        if (attacker instanceof ServerPlayer player && !(player instanceof FakePlayer) && !(victim instanceof Player)) {
            scale(event, player, ScalarAugment.Kind.MOB_HEALTH, "deals to", victim);
        }
    }

    /** The augment of this kind registered for the tier, or null when the tier has none (= 100%). */
    static ScalarAugment find(WorldTier tier, ScalarAugment.Kind kind) {
        for (TierAugment.Target target : TierAugment.Target.values()) {
            for (TierAugment aug : TierAugmentRegistry.getAugments(tier, target)) {
                if (aug instanceof ScalarAugment s && s.kind() == kind) return s;
            }
        }
        return null;
    }

    private static void scale(LivingIncomingDamageEvent event, ServerPlayer player, ScalarAugment.Kind kind, String verb, Entity other) {
        WorldTier tier = WorldTier.getTier(player);
        ScalarAugment aug = find(tier, kind);
        if (aug == null) return;
        double mult = aug.multiplier();
        if (mult == 1.0) return;

        float before = event.getAmount();
        float after = (float) (before * mult);
        event.setAmount(after);

        if (LOG_HITS.get()) {
            LOGGER.info("[bajatiers] {} ({}) {} {} via {}: {} -> {} ({}% -> x{})",
                player.getScoreboardName(), tier.getSerializedName(), verb,
                other.getType().toShortString(), event.getSource().getMsgId(), before, after, aug.percent(), mult);
        }
    }
}
