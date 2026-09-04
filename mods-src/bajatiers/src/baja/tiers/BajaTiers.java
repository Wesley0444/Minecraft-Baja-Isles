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
 * Two mirrored scalings on the same event, both keyed off the PLAYER's own tier, both expressed
 * from the mob's side of the ledger so the config reads like the announcement:
 *   mob_damage -- percent. Victim is a real ServerPlayer, attacker (DamageSource#getEntity, i.e.
 *                 the owner for projectiles) is a non-player LivingEntity. damage *= pct/100.
 *   mob_health -- percent of EFFECTIVE health. Attacker is a real ServerPlayer, victim is any
 *                 non-player LivingEntity. damage *= 100/pct (143% health == hits land at 70%).
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
    /** Percent of normal damage mobs deal to a player of this tier (100 = vanilla). */
    static final Map<WorldTier, ModConfigSpec.DoubleValue> MOB_DAMAGE = new EnumMap<>(WorldTier.class);
    /** Effective mob health as a percent (100 = vanilla): the player's hits are divided by this. */
    static final Map<WorldTier, ModConfigSpec.DoubleValue> MOB_HEALTH = new EnumMap<>(WorldTier.class);
    static final ModConfigSpec.BooleanValue LOG_HITS;

    static {
        ModConfigSpec.Builder b = new ModConfigSpec.Builder();
        b.comment(
            "Mob damage, as a PERCENT of vanilla (100 = unchanged), chosen by the World Tier of the player",
            "being hit. Covers any non-player living attacker plus its arrows, explosions and spells.",
            "Applied before armor / enchantments / absorption, so it stacks with the shipped per-tier",
            "armor-pierce and prot-pierce monster augments. Fall, lava, drowning, PvP are never scaled.",
            "Edits hot-reload; no restart needed.")
         .push("mob_damage");
        double[] mobDamage = { 70, 100, 200, 300, 450 };
        for (WorldTier tier : WorldTier.values()) {
            MOB_DAMAGE.put(tier, b.defineInRange(tier.getSerializedName(), mobDamage[tier.ordinal()], 0.0, 10000.0));
        }
        b.pop();
        b.comment(
            "Effective mob health, as a PERCENT of vanilla (100 = unchanged), chosen by the World Tier of",
            "the player attacking. Implemented by dividing the player's damage to any non-player living",
            "target by this value (143 = your hits land at 70%). Health bars still show the vanilla number.",
            "Applies to passive animals too. PvP is never scaled.")
         .push("mob_health");
        double[] mobHealth = { 100, 118, 143, 182, 250 };
        for (WorldTier tier : WorldTier.values()) {
            MOB_HEALTH.put(tier, b.defineInRange(tier.getSerializedName(), mobHealth[tier.ordinal()], 1.0, 10000.0));
        }
        b.pop();
        LOG_HITS = b.comment("Log every scaled hit at INFO (player, tier, attacker, before -> after). Debug aid; leave off.")
            .define("log_hits", false);
        SPEC = b.build();
    }

    public BajaTiers(IEventBus modBus, ModContainer container) {
        container.registerConfig(ModConfig.Type.COMMON, SPEC);
        NeoForge.EVENT_BUS.addListener(BajaTiers::onIncomingDamage);
        LOGGER.info("Baja Tiers loaded: per-player mob damage / mob health scaling by World Tier is active.");
    }

    static void onIncomingDamage(LivingIncomingDamageEvent event) {
        LivingEntity victim = event.getEntity();
        DamageSource source = event.getSource();
        Entity attacker = source.getEntity();

        // Player taking a hit from a non-player living attacker -> scale by the VICTIM's tier.
        if (victim instanceof ServerPlayer player && !(player instanceof FakePlayer)) {
            if (attacker instanceof LivingEntity && !(attacker instanceof Player)) {
                scale(event, player, MOB_DAMAGE, false, "takes from", attacker);
            }
            return;
        }

        // Non-player living target hit by a real player -> scale by the ATTACKER's tier.
        if (attacker instanceof ServerPlayer player && !(player instanceof FakePlayer) && !(victim instanceof Player)) {
            scale(event, player, MOB_HEALTH, true, "deals to", victim);
        }
    }

    /** @param invert false: multiplier = pct/100 (mob damage); true: multiplier = 100/pct (mob health). */
    private static void scale(LivingIncomingDamageEvent event, ServerPlayer player,
                              Map<WorldTier, ModConfigSpec.DoubleValue> table, boolean invert, String verb, Entity other) {
        WorldTier tier = WorldTier.getTier(player);
        ModConfigSpec.DoubleValue cfg = table.get(tier);
        if (cfg == null) return;
        double pct = cfg.get();
        if (pct == 100.0) return;
        double mult = invert ? 100.0 / pct : pct / 100.0;

        float before = event.getAmount();
        float after = (float) (before * mult);
        event.setAmount(after);

        if (LOG_HITS.get()) {
            LOGGER.info("[bajatiers] {} ({}) {} {} via {}: {} -> {} ({}% -> x{})",
                player.getScoreboardName(), tier.getSerializedName(), verb,
                other.getType().toShortString(), event.getSource().getMsgId(), before, after, pct, mult);
        }
    }
}
