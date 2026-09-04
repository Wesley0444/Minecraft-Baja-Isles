package baja.tiers;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;

import dev.shadowsoffire.apotheosis.tiers.WorldTier;
import dev.shadowsoffire.apotheosis.tiers.augments.TierAugment;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.ServerLevelAccessor;
import net.neoforged.neoforge.common.util.AttributeTooltipContext;

/**
 * A World Tier augment that carries a percentage and does nothing on its own.
 *
 * The number is applied by {@link BajaTiers#onIncomingDamage} at damage time, keyed off the
 * PLAYER's tier (not the mob's spawn tier). Registering it as a real tier augment means:
 *  - the datapack JSON is the single source of truth (edit, /reload, done);
 *  - it is synced to clients by Placebo like every other augment;
 *  - the World Tier detail screen lists it under Monster Augments in red, next to +8 Armor.
 *
 * JSON (data/[ns]/tier_augments/[tier]/mob_damage.json):
 *   { "type": "bajatiers:mob_damage", "tier": "ascent", "target": "monsters", "percent": 200 }
 */
public record ScalarAugment(Kind kind, WorldTier tier, TierAugment.Target target, int sortIndex, double percent) implements TierAugment {

    public enum Kind {
        /** Mob damage to players, percent of vanilla. damage *= percent/100. */
        MOB_DAMAGE("mob_damage"),
        /** Effective mob health, percent of vanilla. player damage *= 100/percent. */
        MOB_HEALTH("mob_health");

        public final String name;
        public final ResourceLocation id;
        public final String langKey;
        public final Codec<ScalarAugment> codec;

        Kind(String name) {
            this.name = name;
            this.id = ResourceLocation.fromNamespaceAndPath(BajaTiers.MODID, name);
            this.langKey = "augment." + BajaTiers.MODID + "." + name;
            this.codec = RecordCodecBuilder.create(inst -> inst.group(
                WorldTier.CODEC.fieldOf("tier").forGetter(ScalarAugment::tier),
                TierAugment.Target.CODEC.optionalFieldOf("target", TierAugment.Target.MONSTERS).forGetter(ScalarAugment::target),
                Codec.intRange(0, 2000).optionalFieldOf("sort_index", 50).forGetter(ScalarAugment::sortIndex),
                Codec.doubleRange(1, 100000).fieldOf("percent").forGetter(ScalarAugment::percent))
                .apply(inst, (tier, target, sort, pct) -> new ScalarAugment(this, tier, target, sort, pct)));
        }
    }

    @Override
    public Codec<? extends TierAugment> getCodec() {
        return this.kind.codec;
    }

    /** No-op: the effect is applied per hit by the event handler, never baked into an entity. */
    @Override
    public void apply(ServerLevelAccessor level, LivingEntity entity) {}

    @Override
    public void remove(ServerLevelAccessor level, LivingEntity entity) {}

    @Override
    public Component getDescription(AttributeTooltipContext ctx) {
        String pct = this.percent == Math.rint(this.percent) ? String.valueOf((long) this.percent) : String.valueOf(this.percent);
        return Component.translatable(this.kind.langKey, pct);
    }

    /** The damage multiplier this augment stands for. */
    public double multiplier() {
        return this.kind == Kind.MOB_HEALTH ? 100.0 / this.percent : this.percent / 100.0;
    }
}
