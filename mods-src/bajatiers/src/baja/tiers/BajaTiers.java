package baja.tiers;

import java.util.EnumMap;
import java.util.Map;

import org.slf4j.Logger;

import com.mojang.logging.LogUtils;

import dev.shadowsoffire.apotheosis.tiers.WorldTier;
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
 * Baja Tiers -- per-player mob damage scaling keyed off the VICTIM's Apotheosis World Tier.
 *
 * Why this exists instead of a tier_augments datapack on generic.attack_damage:
 * Apotheosis bakes monster augments into the mob at spawn from the NEAREST player's tier,
 * permanently. In a mixed-tier group the Ascent player's mobs hit the Haven player for
 * Ascent damage. Scaling on the receiving end makes the multiplier truly per-player, and
 * it also covers arrows / explosions / spells that never read attack_damage.
 *
 * Two mirrored scalings on the same event, both keyed off the PLAYER's own tier:
 *   damage_taken -- victim is a real ServerPlayer, attacker (DamageSource#getEntity, i.e. the
 *                   owner for projectiles) is a non-player LivingEntity.
 *   damage_dealt -- attacker is a real ServerPlayer, victim is any non-player LivingEntity.
 * Fall, lava, drowning, starvation, PvP and block damage are untouched on purpose -- Haven
 * should not be lava-proof, and player-vs-player is never scaled either way.
 *
 * Server-side only: no registries, no network payloads, so clients without the jar can
 * join (same mechanism Chunky relies on). Config: config/bajatiers-common.toml, hot-reloads.
 */
@Mod(BajaTiers.MODID)
public class BajaTiers {

    public static final String MODID = "bajatiers";
    private static final Logger LOGGER = LogUtils.getLogger();

    static final ModConfigSpec SPEC;
    static final Map<WorldTier, ModConfigSpec.DoubleValue> DAMAGE_TAKEN = new EnumMap<>(WorldTier.class);
    static final Map<WorldTier, ModConfigSpec.DoubleValue> DAMAGE_DEALT = new EnumMap<>(WorldTier.class);
    static final ModConfigSpec.BooleanValue LOG_HITS;

    static {
        ModConfigSpec.Builder b = new ModConfigSpec.Builder();
        b.comment(
            "Multiplier on damage a player TAKES from a non-player living attacker (mobs, their arrows,",
            "their explosions, their spells), chosen by the VICTIM's Apotheosis World Tier.",
            "1.0 = vanilla. Applied before armor / enchantments / absorption, so it stacks multiplicatively",
            "with the shipped per-tier armor-pierce and prot-pierce monster augments.",
            "Edits hot-reload; no restart needed.")
         .push("damage_taken");
        double[] taken = { 0.7, 1.0, 2.0, 3.0, 4.5 };
        for (WorldTier tier : WorldTier.values()) {
            DAMAGE_TAKEN.put(tier, b.defineInRange(tier.getSerializedName(), taken[tier.ordinal()], 0.0, 100.0));
        }
        b.pop();
        b.comment(
            "Multiplier on damage a player DEALS to any non-player living target (melee, arrows, spells --",
            "anything whose damage source entity is the player), chosen by the ATTACKER's World Tier.",
            "1.0 = vanilla. Applies to passive animals too: 'damage you deal' means all of it.",
            "PvP is never scaled in either direction.")
         .push("damage_dealt");
        double[] dealt = { 1.0, 0.85, 0.7, 0.55, 0.4 };
        for (WorldTier tier : WorldTier.values()) {
            DAMAGE_DEALT.put(tier, b.defineInRange(tier.getSerializedName(), dealt[tier.ordinal()], 0.0, 100.0));
        }
        b.pop();
        LOG_HITS = b.comment("Log every scaled hit at INFO (player, tier, attacker, before -> after). Debug aid; leave off.")
            .define("log_hits", false);
        SPEC = b.build();
    }

    public BajaTiers(IEventBus modBus, ModContainer container) {
        container.registerConfig(ModConfig.Type.COMMON, SPEC);
        NeoForge.EVENT_BUS.addListener(BajaTiers::onIncomingDamage);
        LOGGER.info("Baja Tiers loaded: per-player damage taken/dealt scaling by World Tier is active.");
    }

    static void onIncomingDamage(LivingIncomingDamageEvent event) {
        LivingEntity victim = event.getEntity();
        DamageSource source = event.getSource();
        Entity attacker = source.getEntity();

        // Player taking a hit from a non-player living attacker -> scale by the VICTIM's tier.
        if (victim instanceof ServerPlayer player && !(player instanceof FakePlayer)) {
            if (attacker instanceof LivingEntity && !(attacker instanceof Player)) {
                scale(event, player, DAMAGE_TAKEN, "takes from", attacker);
            }
            return;
        }

        // Non-player living target hit by a real player -> scale by the ATTACKER's tier.
        if (attacker instanceof ServerPlayer player && !(player instanceof FakePlayer) && !(victim instanceof Player)) {
            scale(event, player, DAMAGE_DEALT, "deals to", victim);
        }
    }

    private static void scale(LivingIncomingDamageEvent event, ServerPlayer player,
                              Map<WorldTier, ModConfigSpec.DoubleValue> table, String verb, Entity other) {
        WorldTier tier = WorldTier.getTier(player);
        ModConfigSpec.DoubleValue cfg = table.get(tier);
        if (cfg == null) return;
        double mult = cfg.get();
        if (mult == 1.0) return;

        float before = event.getAmount();
        float after = (float) (before * mult);
        event.setAmount(after);

        if (LOG_HITS.get()) {
            LOGGER.info("[bajatiers] {} ({}) {} {} via {}: {} -> {} (x{})",
                player.getScoreboardName(), tier.getSerializedName(), verb,
                other.getType().toShortString(), event.getSource().getMsgId(), before, after, mult);
        }
    }
}
